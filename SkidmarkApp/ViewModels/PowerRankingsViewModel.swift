import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// View model managing power rankings display and roast generation
@MainActor @Observable
class PowerRankingsViewModel {
    // MARK: - Published Properties
    
    var teams: [Team] = []
    var isLoading: Bool = false
    var roastsEnabled: Bool = true
    var lastUpdated: Date?
    var errorMessage: String?
    var isCacheStale: Bool = false
    var usingCachedData: Bool = false
    
    // MARK: - Week Navigation State
    
    /// The week currently being viewed
    var selectedWeek: Int = 1
    /// The latest week from league settings
    var currentWeek: Int = 1
    /// Weeks that have cached roasts available
    var availableWeeks: [Int] = []
    /// Matchups for the selected week
    var weeklyMatchups: [WeeklyMatchup] = []
    /// Current season phase (regular season or playoffs)
    var seasonPhase: SeasonPhase = .regularSeason
    /// Playoff bracket data (non-nil only during playoffs)
    var playoffBracket: [PlayoffBracketEntry]?
    
    // MARK: - Dependencies
    
    private let espnService: LeagueDataService
    private let sleeperService: LeagueDataService
    private let backendService: BackendService
    private let storageService: StorageService
    private let networkMonitor: NetworkMonitor?
    
    // MARK: - Private State
    
    private var currentLeague: LeagueConnection?
    private var lastRoastHash: Int?
    
    // MARK: - Initialization
    
    /// Convenience initializer with default service implementations
    convenience init() {
        let keychainService = DefaultKeychainService()
        let networkMonitor = NetworkMonitor()
        self.init(
            espnService: ESPNService(keychainService: keychainService, networkMonitor: networkMonitor),
            sleeperService: SleeperService(networkMonitor: networkMonitor),
            backendService: AWSBackendService(networkMonitor: networkMonitor),
            storageService: DefaultStorageService(),
            networkMonitor: networkMonitor
        )
    }
    
    /// Designated initializer for dependency injection (primarily for testing)
    init(
        espnService: LeagueDataService,
        sleeperService: LeagueDataService,
        backendService: BackendService = AWSBackendService(),
        storageService: StorageService = DefaultStorageService(),
        networkMonitor: NetworkMonitor? = nil
    ) {
        self.espnService = espnService
        self.sleeperService = sleeperService
        self.backendService = backendService
        self.storageService = storageService
        self.networkMonitor = networkMonitor
    }
    
    // MARK: - Public Methods
    
    /// Fetches league data for the specified league connection
    /// - Parameter league: The league connection to fetch data for
    func fetchLeagueData(for league: LeagueConnection) async {
        // Check network connectivity first
        if let monitor = networkMonitor, !monitor.isConnected {
            errorMessage = "No internet connection. Using cached data if available."
            usingCachedData = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        usingCachedData = false
        currentLeague = league
        
        do {
            // Select the appropriate service based on platform
            let service = league.platform == .espn ? espnService : sleeperService
            
            // Determine the correct season year
            let season = SeasonHelper.currentFantasyFootballSeason()
            
            // Fetch league data
            let fetchedTeams = try await service.fetchLeagueData(
                leagueId: league.leagueId,
                season: season
            )
            
            // Calculate rankings
            let newTeams = PowerRankingsCalculator.calculatePowerRankings(teams: fetchedTeams)
            
            // Build a stable fingerprint of the new data (excludes roast/rank)
            let oldFingerprint = teams.map { "\($0.id)|\($0.wins)|\($0.losses)|\($0.ties)|\($0.pointsFor)|\($0.pointsAgainst)|\($0.powerScore)" }.joined()
            let newFingerprint = newTeams.map { "\($0.id)|\($0.wins)|\($0.losses)|\($0.ties)|\($0.pointsFor)|\($0.pointsAgainst)|\($0.powerScore)" }.joined()
            
            if oldFingerprint != newFingerprint {
                // Data changed - carry over existing roasts by team ID, clear hash
                let roastsByTeamId = Dictionary(uniqueKeysWithValues: teams.compactMap { t in
                    t.roast.map { (t.id, $0) }
                })
                teams = newTeams.map { newTeam in
                    var t = newTeam
                    t.roast = roastsByTeamId[newTeam.id]
                    return t
                }
                lastRoastHash = nil
            }
            // If data unchanged, keep existing teams array intact (preserves roasts and hash)
            
            lastUpdated = Date()
            
            // Fetch league settings to determine current week and season phase
            do {
                let settings = try await service.fetchLeagueSettings(
                    leagueId: league.leagueId,
                    season: season
                )
                currentWeek = max(1, settings.currentWeek)
                selectedWeek = currentWeek
                
                // Detect season phase from league settings
                seasonPhase = SeasonPhaseDetector.detect(
                    currentWeek: settings.currentWeek,
                    playoffStartWeek: settings.playoffStartWeek
                )
                
                // Fetch playoff bracket if in playoffs
                if seasonPhase == .playoffs {
                    do {
                        playoffBracket = try await service.fetchPlayoffBracket(
                            leagueId: league.leagueId,
                            season: season,
                            week: settings.currentWeek
                        )
                    } catch {
                        // Bracket fetch failed -- fall back to regular season per Req 7.5
                        playoffBracket = nil
                        seasonPhase = .regularSeason
                    }
                } else {
                    playoffBracket = nil
                }
            } catch {
                // If settings unavailable, default to regular season
                seasonPhase = .regularSeason
                playoffBracket = nil
            }
            
            // Load available roast weeks from cache
            refreshAvailableWeeks()
            
            // Cache the data with current hash
            try? storageService.saveCachedLeagueData(teams, forLeagueId: league.leagueId, roastHash: lastRoastHash)
            
            isLoading = false
        } catch is CancellationError {
            // SwiftUI task cancelled (e.g. view dismissed or refresh interrupted) -- ignore silently
            isLoading = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            isLoading = false
        } catch {
            errorMessage = formatErrorMessage(error)
            isLoading = false
        }
    }
    
    /// Calculates power rankings for the current teams
    func calculateRankings() {
        guard !teams.isEmpty else { return }
        teams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
    }
    
    /// Generates AI roasts for all teams using league context
    /// - Parameters:
    ///   - context: The league context to use for roast generation
    ///   - forceRegenerate: If true, bypasses cache and regenerates roasts
    func generateRoasts(context: LeagueContext, forceRegenerate: Bool = false) async {
        guard !teams.isEmpty else {
            errorMessage = "No teams to generate roasts for"
            return
        }
        
        // Check network connectivity first
        if let monitor = networkMonitor, !monitor.isConnected {
            errorMessage = "No internet connection. Roasts require network access to generate."
            return
        }
        
        // Compute hash of current input data
        let currentHash = computeRoastHash(teams: teams, context: context)
        
        // Check if we can use cached roasts
        if !forceRegenerate, 
           let lastHash = lastRoastHash,
           lastHash == currentHash,
           teams.allSatisfy({ $0.roast != nil }) {
            // Data unchanged and roasts exist - skip regeneration
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch matchup data for the selected week
            var matchups: [WeeklyMatchup] = []
            if let league = currentLeague, selectedWeek > 0 {
                let service = league.platform == .espn ? espnService : sleeperService
                let season = SeasonHelper.currentFantasyFootballSeason()
                do {
                    matchups = try await service.fetchMatchupData(
                        leagueId: league.leagueId,
                        season: season,
                        week: selectedWeek
                    )
                    weeklyMatchups = matchups
                } catch {
                    // Matchup fetch failed -- proceed without matchup data (Req 4.6 fallback)
                    matchups = []
                    weeklyMatchups = []
                }
            }
            
            let roasts = try await backendService.generateRoasts(
                teams: teams,
                context: context,
                matchups: matchups,
                weekNumber: selectedWeek,
                seasonPhase: seasonPhase,
                playoffBracket: playoffBracket
            )
            
            // Update teams with roasts
            teams = teams.map { team in
                var updatedTeam = team
                updatedTeam.roast = roasts[team.id]
                return updatedTeam
            }
            
            // Store the hash for future comparisons
            lastRoastHash = currentHash
            
            // Save to cache with hash
            if let leagueId = currentLeague?.leagueId {
                try? storageService.saveCachedLeagueData(teams, forLeagueId: leagueId, roastHash: currentHash)
                
                // Persist roasts to weekly cache for history navigation
                let weeklyCache = WeeklyRoastCache(
                    leagueId: leagueId,
                    weekNumber: selectedWeek,
                    generatedAt: Date(),
                    roasts: roasts,
                    teamSnapshot: teams
                )
                try? storageService.saveWeeklyRoasts(weeklyCache)
                refreshAvailableWeeks()
            }
            
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            isLoading = false
        } catch {
            errorMessage = formatErrorMessage(error)
            isLoading = false
        }
    }
    
    /// Computes a stable fingerprint of the roast input data (teams + context).
    /// Uses a string-based approach instead of Hasher, which is randomized per process.
    private func computeRoastHash(teams: [Team], context: LeagueContext) -> Int {
        var parts: [String] = []
        for t in teams {
            parts.append("\(t.id)|\(t.name)|\(t.ownerName)|\(t.wins)-\(t.losses)-\(t.ties)|\(t.pointsFor)|\(t.pointsAgainst)|\(t.powerScore)|\(t.streak.type.rawValue)\(t.streak.length)")
            for p in t.topPlayers {
                parts.append("\(p.name)|\(p.position)|\(p.points)")
            }
        }
        for j in context.insideJokes { parts.append("j:\(j.term)|\(j.explanation)") }
        for p in context.personalities { parts.append("p:\(p.playerName)|\(p.description)") }
        parts.append("s:\(context.sackoPunishment)")
        parts.append("c:\(context.cultureNotes)")
        
        // Use a simple deterministic hash (djb2)
        let combined = parts.joined(separator: "||")
        var hash = 5381
        for byte in combined.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ Int(byte)
        }
        return hash
    }
    
    // MARK: - Week Navigation
    
    /// Navigates to the specified week, loading cached roasts or clearing for fresh generation
    /// - Parameter week: The target week number (clamped to 1...currentWeek)
    func navigateToWeek(_ week: Int) {
        let clampedWeek = max(1, min(week, currentWeek))
        selectedWeek = clampedWeek
        weeklyMatchups = []
        
        // Try to load cached roasts for this week
        guard let leagueId = currentLeague?.leagueId else { return }
        
        do {
            if let cached = try storageService.loadWeeklyRoasts(forLeagueId: leagueId, week: clampedWeek) {
                if let snapshot = cached.teamSnapshot {
                    // Restore full team snapshot with roasts applied
                    teams = snapshot.map { team in
                        var t = team
                        t.roast = cached.roasts[team.id]
                        return t
                    }
                } else {
                    // Legacy cache without snapshot -- apply roasts to current teams
                    teams = teams.map { team in
                        var t = team
                        t.roast = cached.roasts[team.id]
                        return t
                    }
                }
            } else {
                // No cached roasts for this week -- clear roasts so UI shows "Generate Roasts"
                teams = teams.map { team in
                    var t = team
                    t.roast = nil
                    return t
                }
            }
        } catch {
            // Cache load failure is non-fatal; clear roasts and let user regenerate
            teams = teams.map { team in
                var t = team
                t.roast = nil
                return t
            }
        }
    }
    
    /// Refreshes the list of weeks that have cached roasts for the current league
    func refreshAvailableWeeks() {
        guard let leagueId = currentLeague?.leagueId else {
            availableWeeks = []
            return
        }
        availableWeeks = (try? storageService.availableRoastWeeks(forLeagueId: leagueId)) ?? []
    }
    
    /// Refreshes league data by re-fetching from the API
    func refresh() async {
        guard let league = currentLeague else {
            errorMessage = "No league selected"
            return
        }
        
        // Preserve existing roasts and hash - they'll be cleared only if data actually changes
        await fetchLeagueData(for: league)
    }
    
    /// Toggles the display of roasts on/off
    func toggleRoasts() {
        roastsEnabled.toggle()
    }
    
    /// Loads cached league data if available
    /// - Parameter leagueId: The league ID to load cached data for
    func loadCachedData(forLeagueId leagueId: String) {
        do {
            if let cached = try storageService.loadCachedLeagueData(forLeagueId: leagueId) {
                teams = cached.teams
                lastUpdated = cached.timestamp
                lastRoastHash = cached.roastHash
                
                // Check cache staleness
                isCacheStale = storageService.isCacheStale(forLeagueId: leagueId)
                usingCachedData = true
            }
        } catch {
            // Silently fail for cache loading
            print("Failed to load cached data: \(error.localizedDescription)")
        }
    }
    
    /// Gets the age of cached data in hours
    func getCacheAgeInHours(forLeagueId leagueId: String) -> Int? {
        guard let age = storageService.getCacheAge(forLeagueId: leagueId) else {
            return nil
        }
        return Int(age / 3600) // Convert seconds to hours
    }
    
    /// Formats power rankings and roasts for export
    /// - Parameter includeRoasts: Whether to include roast text in the export
    /// - Returns: Formatted plain text string
    func formatForExport(includeRoasts: Bool) -> String {
        guard !teams.isEmpty else {
            return "No rankings available"
        }
        
        var output = "Power Rankings\n"
        output += "==============\n\n"
        
        for team in teams {
            // Rank and team info
            output += "\(team.rank). \(team.name)\n"
            output += "   Owner: \(team.ownerName)\n"
            output += "   Record: \(team.record)\n"
            output += "   Points: \(String(format: "%.1f", team.pointsFor))\n"
            
            // Include roast if requested and available
            if includeRoasts, let roast = team.roast {
                output += "\n   \(roast)\n"
            }
            
            output += "\n"
        }
        
        // Add timestamp
        if let lastUpdated = lastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            output += "Last updated: \(formatter.string(from: lastUpdated))\n"
        }
        
        return output
    }
    
    /// Copies formatted rankings to clipboard
    /// - Parameter includeRoasts: Whether to include roast text
    /// - Returns: True if copy was successful
    @discardableResult
    func copyToClipboard(includeRoasts: Bool) -> Bool {
        let text = formatForExport(includeRoasts: includeRoasts)
        
        #if os(iOS)
        UIPasteboard.general.string = text
        return true
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
        #else
        return false
        #endif
    }
    
    // MARK: - Error Formatting
    
    /// Formats error messages with specific recovery actions
    private func formatErrorMessage(_ error: Error) -> String {
        if let backendError = error as? BackendError {
            switch backendError {
            case .noConnection:
                return "No internet connection. Check your network settings and try again."
            case .timeout:
                return "Request timed out. Check your connection and try again."
            case .serverError(let statusCode) where statusCode == 429:
                return "Too many requests. Please wait a moment and try again."
            case .serverError(let statusCode) where statusCode >= 500:
                return "Server error (\(statusCode)). The service may be temporarily unavailable."
            case .invalidResponse, .parsingError:
                return "Received invalid data from server. Please try again."
            default:
                return backendError.localizedDescription
            }
        }
        
        if let leagueError = error as? LeagueDataError {
            switch leagueError {
            case .noConnection:
                return "No internet connection. Check your network settings and try again."
            case .timeout:
                return "Request timed out. Check your connection and try again."
            case .authenticationRequired:
                return "Authentication required. Please re-enter your ESPN credentials."
            case .invalidCredentials:
                return "Invalid credentials. Please update your ESPN login information."
            case .leagueNotFound:
                return "League not found. Verify your league ID is correct."
            case .serverError(let statusCode) where statusCode == 429:
                return "Too many requests. Please wait a moment and try again."
            case .serverError(let statusCode) where statusCode >= 500:
                return "Server error (\(statusCode)). The service may be temporarily unavailable."
            default:
                return leagueError.localizedDescription
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Check your network settings and try again."
            case .timedOut:
                return "Request timed out. Check your connection and try again."
            case .cannotFindHost, .cannotConnectToHost:
                return "Cannot reach server. Check your connection and try again."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        
        return error.localizedDescription
    }
    

}
