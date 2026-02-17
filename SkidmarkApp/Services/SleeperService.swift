import Foundation

/// Protocol for network session to enable testing
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Extension to make URLSession conform to the protocol
extension URLSession: URLSessionProtocol {}

/// Service for fetching fantasy league data from Sleeper API
/// Sleeper API is public and does not require authentication
class SleeperService: LeagueDataService {
    private let baseURL = "https://api.sleeper.app/v1"
    private let session: URLSessionProtocol
    private let retryService: RetryableService
    
    /// Cached NFL player map: playerId -> (fullName, position)
    /// Fetched once from Sleeper's /players/nfl endpoint and reused across calls.
    private var playerMapCache: [String: (name: String, position: String)]?
    
    init(session: URLSessionProtocol = URLSession.shared, networkMonitor: NetworkMonitor? = nil) {
        self.session = session
        self.retryService = RetryableService(policy: .default, networkMonitor: networkMonitor)
    }
    
    func fetchLeagueData(leagueId: String, season: Int) async throws -> [Team] {
        return try await retryService.execute {
            try await self.performFetch(leagueId: leagueId, season: season)
        }
    }
    
    private func performFetch(leagueId: String, season: Int) async throws -> [Team] {
        // Fetch data from multiple endpoints in parallel
        async let leagueData = fetchLeague(leagueId: leagueId)
        async let rostersData = fetchRosters(leagueId: leagueId)
        async let usersData = fetchUsers(leagueId: leagueId)
        
        // Wait for all requests to complete
        let (league, rosters, users) = try await (leagueData, rostersData, usersData)
        
        // Transform the combined data into Team models
        return try transformToTeams(league: league, rosters: rosters, users: users)
    }
    
    // MARK: - Matchup Data
    
    func fetchMatchupData(leagueId: String, season: Int, week: Int) async throws -> [WeeklyMatchup] {
        return try await retryService.execute {
            try await self.performMatchupFetch(leagueId: leagueId, season: season, week: week)
        }
    }
    
    private func performMatchupFetch(leagueId: String, season: Int, week: Int) async throws -> [WeeklyMatchup] {
        // Fetch matchups and player map in parallel
        async let matchupsData = fetchMatchups(leagueId: leagueId, week: week)
        async let playerMap = getPlayerMap()
        
        let (rosters, players) = try await (matchupsData, playerMap)
        
        return buildMatchups(from: rosters, playerMap: players, week: week)
    }
    
    private func fetchMatchups(leagueId: String, week: Int) async throws -> [[String: Any]] {
        let url = URL(string: "\(baseURL)/league/\(leagueId)/matchups/\(week)")!
        let data = try await performRequest(url: url)
        
        guard let rosters = data as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Expected array of matchup rosters")
        }
        
        return rosters
    }
    
    /// Returns the cached player map, fetching from Sleeper's /players/nfl endpoint on first call.
    private func getPlayerMap() async throws -> [String: (name: String, position: String)] {
        if let cached = playerMapCache {
            return cached
        }
        
        let url = URL(string: "\(baseURL)/players/nfl")!
        let data = try await performRequest(url: url)
        
        guard let playersDict = data as? [String: Any] else {
            throw LeagueDataError.parsingError("Expected dictionary for players/nfl response")
        }
        
        var map: [String: (name: String, position: String)] = [:]
        for (playerId, value) in playersDict {
            guard let info = value as? [String: Any] else { continue }
            let firstName = info["first_name"] as? String ?? ""
            let lastName = info["last_name"] as? String ?? ""
            let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            let position = info["position"] as? String ?? "FLEX"
            if !fullName.isEmpty {
                map[playerId] = (name: fullName, position: position)
            }
        }
        
        playerMapCache = map
        return map
    }
    
    /// Groups roster entries by matchup_id and pairs them into WeeklyMatchup objects.
    /// The first roster encountered for a matchup_id becomes "home", the second becomes "away".
    private func buildMatchups(
        from rosters: [[String: Any]],
        playerMap: [String: (name: String, position: String)],
        week: Int
    ) -> [WeeklyMatchup] {
        // Group rosters by matchup_id
        var grouped: [Int: [[String: Any]]] = [:]
        for roster in rosters {
            guard let matchupId = roster["matchup_id"] as? Int else { continue }
            grouped[matchupId, default: []].append(roster)
        }
        
        var matchups: [WeeklyMatchup] = []
        
        for (_, pair) in grouped.sorted(by: { $0.key < $1.key }) {
            guard pair.count == 2 else { continue }
            
            let home = pair[0]
            let away = pair[1]
            
            let homeRosterId = home["roster_id"] as? Int ?? 0
            let awayRosterId = away["roster_id"] as? Int ?? 0
            let homeScore = extractPoints(from: home)
            let awayScore = extractPoints(from: away)
            
            let homePlayers = extractPlayerStats(from: home, playerMap: playerMap)
            let awayPlayers = extractPlayerStats(from: away, playerMap: playerMap)
            
            matchups.append(WeeklyMatchup(
                weekNumber: week,
                homeTeamId: String(homeRosterId),
                awayTeamId: String(awayRosterId),
                homeScore: homeScore,
                awayScore: awayScore,
                homePlayers: homePlayers,
                awayPlayers: awayPlayers
            ))
        }
        
        return matchups
    }
    
    /// Extracts the total points from a Sleeper roster entry.
    /// Sleeper provides points as a top-level field or as the sum of players_points.
    private func extractPoints(from roster: [String: Any]) -> Double {
        if let points = roster["points"] as? Double {
            return points
        }
        if let points = roster["points"] as? Int {
            return Double(points)
        }
        return 0.0
    }
    
    /// Builds WeeklyPlayerStats for all players on a roster, marking starters.
    private func extractPlayerStats(
        from roster: [String: Any],
        playerMap: [String: (name: String, position: String)]
    ) -> [WeeklyPlayerStats] {
        let starters = Set(roster["starters"] as? [String] ?? [])
        let allPlayers = roster["players"] as? [String] ?? []
        let playersPoints = roster["players_points"] as? [String: Any] ?? [:]
        
        return allPlayers.compactMap { playerId in
            let info = playerMap[playerId]
            let name = info?.name ?? playerId
            let position = info?.position ?? "FLEX"
            
            let points: Double
            if let p = playersPoints[playerId] as? Double {
                points = p
            } else if let p = playersPoints[playerId] as? Int {
                points = Double(p)
            } else {
                points = 0.0
            }
            
            return WeeklyPlayerStats(
                playerId: playerId,
                name: name,
                position: position,
                points: points,
                isStarter: starters.contains(playerId)
            )
        }
    }
    
    // MARK: - Playoff Bracket
    
    func fetchPlayoffBracket(leagueId: String, season: Int, week: Int) async throws -> [PlayoffBracketEntry] {
        return try await retryService.execute {
            try await self.performPlayoffBracketFetch(leagueId: leagueId, week: week)
        }
    }
    
    private func performPlayoffBracketFetch(leagueId: String, week: Int) async throws -> [PlayoffBracketEntry] {
        // Fetch both brackets in parallel
        async let winnersData = fetchBracket(leagueId: leagueId, type: "winners_bracket")
        async let losersData = fetchBracket(leagueId: leagueId, type: "losers_bracket")
        
        let (winners, losers) = try await (winnersData, losersData)
        
        let maxWinnersRound = winners.reduce(0) { max($0, $1["r"] as? Int ?? 0) }
        
        var entries: [PlayoffBracketEntry] = []
        var processedTeamIds: Set<String> = []
        
        // Process winners bracket
        for matchup in winners {
            let newEntries = buildBracketEntries(
                from: matchup,
                isConsolation: false,
                isChampionshipRound: (matchup["r"] as? Int ?? 0) == maxWinnersRound,
                processedTeamIds: &processedTeamIds
            )
            entries.append(contentsOf: newEntries)
        }
        
        // Process losers bracket
        for matchup in losers {
            let newEntries = buildBracketEntries(
                from: matchup,
                isConsolation: true,
                isChampionshipRound: false,
                processedTeamIds: &processedTeamIds
            )
            entries.append(contentsOf: newEntries)
        }
        
        return entries
    }
    
    private func fetchBracket(leagueId: String, type: String) async throws -> [[String: Any]] {
        let url = URL(string: "\(baseURL)/league/\(leagueId)/\(type)")!
        let data = try await performRequest(url: url)
        
        guard let bracket = data as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Expected array for \(type) response")
        }
        
        return bracket
    }
    
    /// Builds PlayoffBracketEntry objects from a single Sleeper bracket matchup.
    /// Sleeper bracket matchups have: r (round), m (matchup id), t1/t2 (roster ids),
    /// w (winner roster id), l (loser roster id).
    private func buildBracketEntries(
        from matchup: [String: Any],
        isConsolation: Bool,
        isChampionshipRound: Bool,
        processedTeamIds: inout Set<String>
    ) -> [PlayoffBracketEntry] {
        let round = matchup["r"] as? Int ?? 1
        let winner = matchup["w"] as? Int
        let loser = matchup["l"] as? Int
        
        let t1 = matchup["t1"] as? Int
        let t2 = matchup["t2"] as? Int
        
        var entries: [PlayoffBracketEntry] = []
        
        if let t1 = t1 {
            let teamId = String(t1)
            if !processedTeamIds.contains(teamId) {
                processedTeamIds.insert(teamId)
                let isEliminated = !isConsolation && loser != nil && loser == t1
                entries.append(PlayoffBracketEntry(
                    teamId: teamId,
                    seed: t1,
                    currentRound: round,
                    opponentTeamId: t2.map { String($0) },
                    isEliminated: isEliminated,
                    isConsolation: isConsolation,
                    isChampionship: isChampionshipRound && !isConsolation
                ))
            }
        }
        
        if let t2 = t2 {
            let teamId = String(t2)
            if !processedTeamIds.contains(teamId) {
                processedTeamIds.insert(teamId)
                let isEliminated = !isConsolation && loser != nil && loser == t2
                entries.append(PlayoffBracketEntry(
                    teamId: teamId,
                    seed: t2,
                    currentRound: round,
                    opponentTeamId: t1.map { String($0) },
                    isEliminated: isEliminated,
                    isConsolation: isConsolation,
                    isChampionship: isChampionshipRound && !isConsolation
                ))
            }
        }
        
        return entries
    }
    
    // MARK: - Private API Methods
    
    private func fetchLeague(leagueId: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/league/\(leagueId)")!
        let data = try await performRequest(url: url)
        
        guard let league = data as? [String: Any] else {
            throw LeagueDataError.parsingError("Expected dictionary for league data")
        }
        
        return league
    }
    
    private func fetchRosters(leagueId: String) async throws -> [[String: Any]] {
        let url = URL(string: "\(baseURL)/league/\(leagueId)/rosters")!
        let data = try await performRequest(url: url)
        
        guard let rosters = data as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Expected array of rosters")
        }
        
        return rosters
    }
    
    private func fetchUsers(leagueId: String) async throws -> [[String: Any]] {
        let url = URL(string: "\(baseURL)/league/\(leagueId)/users")!
        let data = try await performRequest(url: url)
        
        guard let users = data as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Expected array of users")
        }
        
        return users
    }
    
    // MARK: - League Settings
    
    func fetchLeagueSettings(leagueId: String, season: Int) async throws -> LeagueSettings {
        return try await retryService.execute {
            try await self.performSettingsFetch(leagueId: leagueId)
        }
    }
    
    private func performSettingsFetch(leagueId: String) async throws -> LeagueSettings {
        // Reuse the existing fetchLeague call that hits /league/{id}
        let league = try await fetchLeague(leagueId: leagueId)
        return try parseLeagueSettings(league: league)
    }
    
    /// Parses Sleeper's `/league/{id}` response into `LeagueSettings`.
    /// Extracts playoff config from `settings.playoff_week_start` and `settings.playoff_teams`,
    /// and the current week from the top-level `settings.leg` field.
    private func parseLeagueSettings(league: [String: Any]) throws -> LeagueSettings {
        guard let settings = league["settings"] as? [String: Any] else {
            throw LeagueDataError.parsingError("Missing settings in Sleeper league response")
        }
        
        guard let playoffWeekStart = settings["playoff_week_start"] as? Int, playoffWeekStart > 0 else {
            throw LeagueDataError.missingRequiredField("playoff_week_start")
        }
        
        guard let playoffTeams = settings["playoff_teams"] as? Int, playoffTeams > 0 else {
            throw LeagueDataError.missingRequiredField("playoff_teams")
        }
        
        // Sleeper uses "leg" in settings for the current matchup period
        let currentWeek: Int
        if let leg = settings["leg"] as? Int, leg >= 1 {
            currentWeek = leg
        } else if let leg = league["leg"] as? Int, leg >= 1 {
            // Some Sleeper responses put leg at the top level
            currentWeek = leg
        } else {
            throw LeagueDataError.missingRequiredField("leg (current week)")
        }
        
        // Total regular season weeks is one less than the playoff start week
        let totalRegularSeasonWeeks = playoffWeekStart - 1
        
        return LeagueSettings(
            playoffStartWeek: playoffWeekStart,
            playoffTeamCount: playoffTeams,
            currentWeek: currentWeek,
            totalRegularSeasonWeeks: totalRegularSeasonWeeks
        )
    }
    
    // MARK: - Network Helper
    
    private func performRequest(url: URL) async throws -> Any {
        let request = URLRequest(url: url, timeoutInterval: 30)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeagueDataError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Success - parse JSON
            guard let json = try? JSONSerialization.jsonObject(with: data) else {
                throw LeagueDataError.parsingError("Failed to parse JSON response")
            }
            return json
            
        case 404:
            throw LeagueDataError.leagueNotFound
            
        case 500...599:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
            
        default:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Data Transformation
    
    private func transformToTeams(league: [String: Any], rosters: [[String: Any]], users: [[String: Any]]) throws -> [Team] {
        var teams: [Team] = []
        
        // Create a lookup dictionary for users by user_id
        var userLookup: [String: [String: Any]] = [:]
        for user in users {
            if let userId = user["user_id"] as? String {
                userLookup[userId] = user
            }
        }
        
        // Transform each roster into a Team
        for roster in rosters {
            guard let rosterId = roster["roster_id"] as? Int,
                  let ownerId = roster["owner_id"] as? String,
                  let settings = roster["settings"] as? [String: Any] else {
                continue
            }
            
            // Extract win/loss/tie data
            let wins = settings["wins"] as? Int ?? 0
            let losses = settings["losses"] as? Int ?? 0
            let ties = settings["ties"] as? Int ?? 0
            
            // Extract points data (convert to Double if needed)
            let pointsFor: Double
            if let fpts = settings["fpts"] as? Double {
                pointsFor = fpts
            } else if let fpts = settings["fpts"] as? Int {
                pointsFor = Double(fpts)
            } else {
                pointsFor = 0.0
            }
            
            let pointsAgainst: Double
            if let fptsAgainst = settings["fpts_against"] as? Double {
                pointsAgainst = fptsAgainst
            } else if let fptsAgainst = settings["fpts_against"] as? Int {
                pointsAgainst = Double(fptsAgainst)
            } else {
                pointsAgainst = 0.0
            }
            
            // Get user data for this roster
            let user = userLookup[ownerId]
            
            // Extract team name with fallback priority: metadata.team_name -> display_name -> username
            let teamName: String
            if let metadata = user?["metadata"] as? [String: Any],
               let customTeamName = metadata["team_name"] as? String, !customTeamName.isEmpty {
                teamName = customTeamName
            } else if let displayName = user?["display_name"] as? String, !displayName.isEmpty {
                teamName = displayName
            } else if let username = user?["username"] as? String, !username.isEmpty {
                teamName = username
            } else {
                teamName = "Team \(rosterId)"
            }
            
            // Extract owner name (use display_name or username)
            let ownerName: String
            if let displayName = user?["display_name"] as? String, !displayName.isEmpty {
                ownerName = displayName
            } else if let username = user?["username"] as? String, !username.isEmpty {
                ownerName = username
            } else {
                ownerName = "Owner \(rosterId)"
            }
            
            // Calculate basic streak (simplified version - can be enhanced later)
            let streak = calculateStreak(wins: wins, losses: losses, ties: ties)
            
            // Create Team model with sensible defaults for optional fields
            let team = Team(
                id: String(rosterId),
                name: teamName,
                ownerName: ownerName,
                wins: wins,
                losses: losses,
                ties: ties,
                pointsFor: pointsFor,
                pointsAgainst: pointsAgainst,
                powerScore: 0.0, // Will be calculated by PowerRankingsCalculator
                rank: 0, // Will be assigned by PowerRankingsCalculator
                streak: streak,
                topPlayers: [], // Basic implementation - can be enhanced later with player data
                roast: nil
            )
            
            teams.append(team)
        }
        
        return teams
    }
    
    /// Calculates a basic streak based on win/loss record
    /// This is a simplified implementation - can be enhanced with matchup history
    private func calculateStreak(wins: Int, losses: Int, ties: Int) -> Team.Streak {
        // Basic heuristic: if more wins than losses, assume win streak, otherwise loss streak
        // Length is simplified to 1 for now - proper implementation would need matchup history
        if wins > losses {
            return Team.Streak(type: .win, length: 1)
        } else {
            return Team.Streak(type: .loss, length: 1)
        }
    }
}
