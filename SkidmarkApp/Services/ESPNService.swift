import Foundation

/// Service for fetching fantasy league data from ESPN API
/// ESPN API requires authentication via ESPN_S2 and SWID cookies
/// Includes automatic token refresh detection and re-authentication prompts
class ESPNService: LeagueDataService {
    private let baseURL = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons"
    private let session: URLSessionProtocol
    private let keychainService: KeychainService
    private let retryService: RetryableService
    
    /// Callback for when credentials need to be refreshed
    /// The app should prompt the user to re-authenticate
    var onCredentialsExpired: ((String) -> Void)?
    
    init(session: URLSessionProtocol = URLSession.shared, keychainService: KeychainService = DefaultKeychainService(), networkMonitor: NetworkMonitor? = nil) {
        self.session = session
        self.keychainService = keychainService
        self.retryService = RetryableService(policy: .default, networkMonitor: networkMonitor)
    }
    
    func fetchLeagueData(leagueId: String, season: Int) async throws -> [Team] {
        return try await retryService.execute {
            try await self.performFetch(leagueId: leagueId, season: season)
        }
    }
    
    private func performFetch(leagueId: String, season: Int) async throws -> [Team] {
        // Retrieve credentials from keychain
        let credentialsResult = keychainService.retrieveESPNCredentials(forLeagueId: leagueId)
        
        guard case .success(let credentials) = credentialsResult else {
            throw LeagueDataError.authenticationRequired
        }
        
        // Construct ESPN API URL
        let urlString = "\(baseURL)/\(season)/segments/0/leagues/\(leagueId)"
        print("[ESPN Debug] API URL: \(urlString)")
        guard var urlComponents = URLComponents(string: urlString) else {
            throw LeagueDataError.invalidResponse
        }
        
        // Add query parameters for team data
        urlComponents.queryItems = [
            URLQueryItem(name: "view", value: "mTeam"),
            URLQueryItem(name: "view", value: "mRoster"),
            URLQueryItem(name: "view", value: "mMatchup"),
            URLQueryItem(name: "view", value: "mSettings")
        ]
        
        guard let url = urlComponents.url else {
            throw LeagueDataError.invalidResponse
        }
        
        // Create request with authentication cookies
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("espn_s2=\(credentials.espnS2); SWID=\(credentials.swid)", forHTTPHeaderField: "Cookie")
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeagueDataError.invalidResponse
        }
        
        print("[ESPN Debug] Response Status: \(httpResponse.statusCode)")
        
        // Handle authentication errors by clearing credentials
        switch httpResponse.statusCode {
        case 200...299:
            // Success - parse and transform data
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LeagueDataError.parsingError("Failed to parse JSON response")
            }
            
            // Debug: log top-level keys and first team's name-related fields
            print("[ESPN Debug] Response top-level keys: \(Array(json.keys).sorted())")
            if let teams = json["teams"] as? [[String: Any]] {
                print("[ESPN Debug] Team count: \(teams.count)")
                if let first = teams.first {
                    let nameKeys = ["name", "location", "nickname", "abbrev", "primaryOwner"]
                    let nameValues = nameKeys.map { "\($0): \(first[$0] ?? "nil")" }.joined(separator: ", ")
                    print("[ESPN Debug] First team fields: \(nameValues)")
                    print("[ESPN Debug] First team all keys: \(Array(first.keys).sorted())")
                }
            }
            
            return try transformToTeams(json: json)
            
        case 401, 403:
            // Authentication failed - clear credentials and notify for refresh
            _ = keychainService.deleteESPNCredentials(forLeagueId: leagueId)
            
            // Notify that credentials need to be refreshed
            onCredentialsExpired?(leagueId)
            
            throw LeagueDataError.invalidCredentials
            
        case 404:
            throw LeagueDataError.leagueNotFound
            
        case 500...599:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
            
        default:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Matchup Data
    
    func fetchMatchupData(leagueId: String, season: Int, week: Int) async throws -> [WeeklyMatchup] {
        return try await retryService.execute {
            try await self.performMatchupFetch(leagueId: leagueId, season: season, week: week)
        }
    }
    
    private func performMatchupFetch(leagueId: String, season: Int, week: Int) async throws -> [WeeklyMatchup] {
        let credentialsResult = keychainService.retrieveESPNCredentials(forLeagueId: leagueId)
        guard case .success(let credentials) = credentialsResult else {
            throw LeagueDataError.authenticationRequired
        }
        
        let urlString = "\(baseURL)/\(season)/segments/0/leagues/\(leagueId)"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw LeagueDataError.invalidResponse
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "view", value: "mMatchup"),
            URLQueryItem(name: "scoringPeriodId", value: String(week))
        ]
        
        guard let url = urlComponents.url else {
            throw LeagueDataError.invalidResponse
        }
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("espn_s2=\(credentials.espnS2); SWID=\(credentials.swid)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeagueDataError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LeagueDataError.parsingError("Failed to parse matchup JSON response")
            }
            return try parseMatchups(json: json, week: week)
            
        case 401, 403:
            _ = keychainService.deleteESPNCredentials(forLeagueId: leagueId)
            onCredentialsExpired?(leagueId)
            throw LeagueDataError.invalidCredentials
            
        case 404:
            throw LeagueDataError.leagueNotFound
            
        default:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Parses the ESPN `mMatchup` response into `[WeeklyMatchup]`.
    /// The schedule array contains one entry per matchup per scoring period.
    /// Each entry has `home` and `away` objects with team IDs, scores, and roster data.
    private func parseMatchups(json: [String: Any], week: Int) throws -> [WeeklyMatchup] {
        guard let schedule = json["schedule"] as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Missing schedule array in matchup response")
        }
        
        var matchups: [WeeklyMatchup] = []
        
        for entry in schedule {
            // Filter to the requested scoring period
            guard let matchupPeriodId = entry["matchupPeriodId"] as? Int,
                  matchupPeriodId == week else {
                continue
            }
            
            guard let home = entry["home"] as? [String: Any],
                  let homeTeamId = home["teamId"] as? Int else {
                continue
            }
            
            let homeScore = home["totalPoints"] as? Double ?? 0.0
            let homePlayers = parseRosterPlayers(from: home)
            
            // Away can be nil for bye weeks
            var awayTeamId = 0
            var awayScore = 0.0
            var awayPlayers: [WeeklyPlayerStats] = []
            
            if let away = entry["away"] as? [String: Any] {
                awayTeamId = away["teamId"] as? Int ?? 0
                awayScore = away["totalPoints"] as? Double ?? 0.0
                awayPlayers = parseRosterPlayers(from: away)
            }
            
            // Skip bye-week entries where there is no opponent
            guard awayTeamId != 0 else { continue }
            
            let matchup = WeeklyMatchup(
                weekNumber: week,
                homeTeamId: String(homeTeamId),
                awayTeamId: String(awayTeamId),
                homeScore: homeScore,
                awayScore: awayScore,
                homePlayers: homePlayers,
                awayPlayers: awayPlayers
            )
            matchups.append(matchup)
        }
        
        return matchups
    }
    
    /// Extracts player stats from a team's roster in the matchup response.
    /// ESPN nests roster data under `rosterForCurrentScoringPeriod` or `rosterForMatchupPeriod`.
    private func parseRosterPlayers(from teamEntry: [String: Any]) -> [WeeklyPlayerStats] {
        // ESPN may use either key depending on the scoring period context
        let roster = teamEntry["rosterForCurrentScoringPeriod"] as? [String: Any]
            ?? teamEntry["rosterForMatchupPeriod"] as? [String: Any]
        
        guard let entries = roster?["entries"] as? [[String: Any]] else {
            return []
        }
        
        var players: [WeeklyPlayerStats] = []
        
        for entry in entries {
            let lineupSlotId = entry["lineupSlotId"] as? Int ?? 20
            // Bench = 20, IR = 21
            let isStarter = lineupSlotId != 20 && lineupSlotId != 21
            
            guard let playerPoolEntry = entry["playerPoolEntry"] as? [String: Any],
                  let player = playerPoolEntry["player"] as? [String: Any],
                  let playerId = player["id"] as? Int,
                  let fullName = player["fullName"] as? String else {
                continue
            }
            
            let positionId = player["defaultPositionId"] as? Int ?? 0
            let position = mapPositionId(positionId)
            let points = extractPlayerPoints(from: player)
            
            players.append(WeeklyPlayerStats(
                playerId: String(playerId),
                name: fullName,
                position: position,
                points: points,
                isStarter: isStarter
            ))
        }
        
        return players
    }
    
    // MARK: - Playoff Bracket
    
    func fetchPlayoffBracket(leagueId: String, season: Int, week: Int) async throws -> [PlayoffBracketEntry] {
        return try await retryService.execute {
            try await self.performPlayoffBracketFetch(leagueId: leagueId, season: season, week: week)
        }
    }
    
    private func performPlayoffBracketFetch(leagueId: String, season: Int, week: Int) async throws -> [PlayoffBracketEntry] {
        let credentialsResult = keychainService.retrieveESPNCredentials(forLeagueId: leagueId)
        guard case .success(let credentials) = credentialsResult else {
            throw LeagueDataError.authenticationRequired
        }
        
        let urlString = "\(baseURL)/\(season)/segments/0/leagues/\(leagueId)"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw LeagueDataError.invalidResponse
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "view", value: "mMatchup"),
            URLQueryItem(name: "scoringPeriodId", value: String(week))
        ]
        
        guard let url = urlComponents.url else {
            throw LeagueDataError.invalidResponse
        }
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("espn_s2=\(credentials.espnS2); SWID=\(credentials.swid)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeagueDataError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LeagueDataError.parsingError("Failed to parse playoff bracket JSON response")
            }
            return try parsePlayoffBracket(json: json, week: week)
            
        case 401, 403:
            _ = keychainService.deleteESPNCredentials(forLeagueId: leagueId)
            onCredentialsExpired?(leagueId)
            throw LeagueDataError.invalidCredentials
            
        case 404:
            throw LeagueDataError.leagueNotFound
            
        default:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Parses playoff bracket data from the ESPN `mMatchup` schedule response.
    /// During playoffs, schedule entries include a `playoffTierType` field indicating
    /// the bracket tier (e.g., WINNERS_BRACKET, LOSERS_BRACKET). Regular-season entries
    /// have this set to "NONE" or omit it entirely.
    private func parsePlayoffBracket(json: [String: Any], week: Int) throws -> [PlayoffBracketEntry] {
        guard let schedule = json["schedule"] as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Missing schedule array in playoff bracket response")
        }
        
        var entries: [PlayoffBracketEntry] = []
        // Track teams already processed to avoid duplicates (a team appears in both home and away)
        var processedTeamIds: Set<String> = []
        
        for entry in schedule {
            guard let matchupPeriodId = entry["matchupPeriodId"] as? Int,
                  matchupPeriodId == week else {
                continue
            }
            
            // Only include entries with a playoff tier type that isn't NONE
            let playoffTierType = entry["playoffTierType"] as? String ?? "NONE"
            guard playoffTierType != "NONE" else { continue }
            
            let isConsolation = playoffTierType == "LOSERS_BRACKET"
            
            guard let home = entry["home"] as? [String: Any],
                  let homeTeamId = home["teamId"] as? Int else {
                continue
            }
            
            let homeId = String(homeTeamId)
            let homeSeed = home["playoffSeed"] as? Int ?? 0
            
            // Away can be nil if a team has a bye in the bracket
            var awayId: String? = nil
            var awaySeed: Int = 0
            if let away = entry["away"] as? [String: Any],
               let awayTeamId = away["teamId"] as? Int, awayTeamId != 0 {
                awayId = String(awayTeamId)
                awaySeed = away["playoffSeed"] as? Int ?? 0
            }
            
            // Determine winner if the matchup is decided
            let winner = entry["winner"] as? String // "HOME", "AWAY", or "UNDECIDED"
            let homeWon = winner == "HOME"
            let awayWon = winner == "AWAY"
            let isDecided = homeWon || awayWon
            
            let isChampionship = playoffTierType == "WINNERS_BRACKET"
                && isChampionshipRound(schedule: schedule, week: week)
            
            // Create entry for home team
            if !processedTeamIds.contains(homeId) {
                processedTeamIds.insert(homeId)
                entries.append(PlayoffBracketEntry(
                    teamId: homeId,
                    seed: homeSeed,
                    currentRound: matchupPeriodId,
                    opponentTeamId: awayId,
                    isEliminated: isDecided && !homeWon && !isConsolation,
                    isConsolation: isConsolation,
                    isChampionship: isChampionship && !isConsolation
                ))
            }
            
            // Create entry for away team
            if let awayId = awayId, !processedTeamIds.contains(awayId) {
                processedTeamIds.insert(awayId)
                entries.append(PlayoffBracketEntry(
                    teamId: awayId,
                    seed: awaySeed,
                    currentRound: matchupPeriodId,
                    opponentTeamId: homeId,
                    isEliminated: isDecided && !awayWon && !isConsolation,
                    isConsolation: isConsolation,
                    isChampionship: isChampionship && !isConsolation
                ))
            }
        }
        
        return entries
    }
    
    /// Determines if the given week is the championship round by checking whether
    /// it is the last week with WINNERS_BRACKET entries in the schedule.
    private func isChampionshipRound(schedule: [[String: Any]], week: Int) -> Bool {
        var maxWinnersBracketWeek = 0
        for entry in schedule {
            let tier = entry["playoffTierType"] as? String ?? "NONE"
            if tier == "WINNERS_BRACKET",
               let period = entry["matchupPeriodId"] as? Int {
                maxWinnersBracketWeek = max(maxWinnersBracketWeek, period)
            }
        }
        return week == maxWinnersBracketWeek
    }
    
    // MARK: - League Settings
    
    func fetchLeagueSettings(leagueId: String, season: Int) async throws -> LeagueSettings {
        return try await retryService.execute {
            try await self.performSettingsFetch(leagueId: leagueId, season: season)
        }
    }
    
    private func performSettingsFetch(leagueId: String, season: Int) async throws -> LeagueSettings {
        let credentialsResult = keychainService.retrieveESPNCredentials(forLeagueId: leagueId)
        guard case .success(let credentials) = credentialsResult else {
            throw LeagueDataError.authenticationRequired
        }
        
        let urlString = "\(baseURL)/\(season)/segments/0/leagues/\(leagueId)"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw LeagueDataError.invalidResponse
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "view", value: "mSettings")
        ]
        
        guard let url = urlComponents.url else {
            throw LeagueDataError.invalidResponse
        }
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("espn_s2=\(credentials.espnS2); SWID=\(credentials.swid)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeagueDataError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LeagueDataError.parsingError("Failed to parse settings JSON response")
            }
            return try parseLeagueSettings(json: json)
            
        case 401, 403:
            _ = keychainService.deleteESPNCredentials(forLeagueId: leagueId)
            onCredentialsExpired?(leagueId)
            throw LeagueDataError.invalidCredentials
            
        case 404:
            throw LeagueDataError.leagueNotFound
            
        default:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Parses the ESPN `mSettings` response into `LeagueSettings`.
    /// Extracts playoff configuration from `settings.scheduleSettings` and
    /// current week from `status.currentMatchupPeriod`.
    private func parseLeagueSettings(json: [String: Any]) throws -> LeagueSettings {
        guard let settings = json["settings"] as? [String: Any],
              let scheduleSettings = settings["scheduleSettings"] as? [String: Any] else {
            throw LeagueDataError.parsingError("Missing settings.scheduleSettings in response")
        }
        
        guard let matchupPeriodCount = scheduleSettings["matchupPeriodCount"] as? Int else {
            throw LeagueDataError.missingRequiredField("matchupPeriodCount")
        }
        
        guard let playoffTeamCount = scheduleSettings["playoffTeamCount"] as? Int else {
            throw LeagueDataError.missingRequiredField("playoffTeamCount")
        }
        
        // Playoff start week is the week after the last regular season matchup period
        let playoffStartWeek = matchupPeriodCount + 1
        
        // Current week comes from the status object
        guard let status = json["status"] as? [String: Any],
              let currentMatchupPeriod = status["currentMatchupPeriod"] as? Int else {
            throw LeagueDataError.missingRequiredField("currentMatchupPeriod")
        }
        
        return LeagueSettings(
            playoffStartWeek: playoffStartWeek,
            playoffTeamCount: playoffTeamCount,
            currentWeek: currentMatchupPeriod,
            totalRegularSeasonWeeks: matchupPeriodCount
        )
    }
    
    // MARK: - Data Transformation
    
    private func transformToTeams(json: [String: Any]) throws -> [Team] {
        guard let teamsArray = json["teams"] as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Missing or invalid teams array")
        }
        
        // Build owner lookup from members array
        let ownerLookup = buildOwnerLookup(from: json)
        
        // Build team name lookup from settings if available (some league configs
        // store team display names in the settings object)
        let settingsTeamNames = extractTeamNamesFromSettings(json: json)
        
        var teams: [Team] = []
        
        for teamData in teamsArray {
            guard let teamId = teamData["id"] as? Int else {
                continue
            }
            
            // Cascading name resolution:
            // 1. "name" field from mTeam view (pre-concatenated full name)
            // 2. "location" + "nickname" combined
            // 3. "abbrev" field
            // 4. Settings-based team name (if mSettings returned team info)
            // 5. Owner name as display name
            // 6. "Team {id}" fallback
            let nameField = (teamData["name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let location = (teamData["location"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let nickname = (teamData["nickname"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let abbrev = (teamData["abbrev"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            
            let combinedName: String = {
                if !location.isEmpty && !nickname.isEmpty { return "\(location) \(nickname)" }
                if !location.isEmpty { return location }
                if !nickname.isEmpty { return nickname }
                return ""
            }()
            
            // Extract owner name from owners array
            let ownerName = extractOwnerName(from: teamData, ownerLookup: ownerLookup)
            
            let teamName: String = {
                if !nameField.isEmpty { return nameField }
                if !combinedName.isEmpty { return combinedName }
                if !abbrev.isEmpty { return abbrev }
                if let settingsName = settingsTeamNames[teamId], !settingsName.isEmpty { return settingsName }
                // Use owner name as a reasonable display name before generic fallback
                if ownerName != "Unknown Owner" { return "Team \(ownerName)" }
                return "Team \(teamId)"
            }()
            
            // Extract record data
            guard let record = teamData["record"] as? [String: Any],
                  let overall = record["overall"] as? [String: Any] else {
                continue
            }
            
            let wins = overall["wins"] as? Int ?? 0
            let losses = overall["losses"] as? Int ?? 0
            let ties = overall["ties"] as? Int ?? 0
            let pointsFor = overall["pointsFor"] as? Double ?? 0.0
            let pointsAgainst = overall["pointsAgainst"] as? Double ?? 0.0
            
            // Extract streak data
            let streak = extractStreak(from: overall)
            
            // Extract top players from roster (basic implementation)
            let topPlayers = extractTopPlayers(from: teamData)
            
            let team = Team(
                id: String(teamId),
                name: teamName,
                ownerName: ownerName,
                wins: wins,
                losses: losses,
                ties: ties,
                pointsFor: pointsFor,
                pointsAgainst: pointsAgainst,
                powerScore: 0.0,
                rank: 0,
                streak: streak,
                topPlayers: topPlayers,
                roast: nil
            )
            
            teams.append(team)
        }
        
        return teams
    }
    
    private func buildOwnerLookup(from json: [String: Any]) -> [String: [String: Any]] {
        guard let members = json["members"] as? [[String: Any]] else {
            return [:]
        }
        
        var lookup: [String: [String: Any]] = [:]
        for member in members {
            if let id = member["id"] as? String {
                lookup[id] = member
            }
        }
        return lookup
    }
    
    /// Attempts to extract team names from the settings object.
    /// Some league configurations include team metadata in settings.
    private func extractTeamNamesFromSettings(json: [String: Any]) -> [Int: String] {
        guard let settings = json["settings"] as? [String: Any],
              let teamsSettings = settings["teams"] as? [[String: Any]] else {
            return [:]
        }
        var names: [Int: String] = [:]
        for teamSetting in teamsSettings {
            if let id = teamSetting["id"] as? Int,
               let name = teamSetting["name"] as? String,
               !name.trimmingCharacters(in: .whitespaces).isEmpty {
                names[id] = name.trimmingCharacters(in: .whitespaces)
            }
        }
        return names
    }
    
    private func extractOwnerName(from teamData: [String: Any], ownerLookup: [String: [String: Any]]) -> String {
        // Get primary owner or first owner from owners array
        var ownerId: String?
        
        if let primaryOwner = teamData["primaryOwner"] as? String {
            ownerId = primaryOwner
        } else if let owners = teamData["owners"] as? [String], let firstOwner = owners.first {
            ownerId = firstOwner
        }
        
        guard let id = ownerId, let owner = ownerLookup[id] else {
            return "Unknown Owner"
        }
        
        let firstName = owner["firstName"] as? String ?? ""
        let lastName = owner["lastName"] as? String ?? ""
        
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? (owner["displayName"] as? String ?? "Unknown Owner") : fullName
    }
    
    private func extractStreak(from overall: [String: Any]) -> Team.Streak {
        let streakLength = overall["streakLength"] as? Int ?? 1
        let streakType = overall["streakType"] as? String ?? "NONE"
        
        let type: Team.Streak.StreakType
        if streakType == "WIN" {
            type = .win
        } else {
            type = .loss
        }
        
        return Team.Streak(type: type, length: max(1, streakLength))
    }
    
    private func extractTopPlayers(from teamData: [String: Any]) -> [Player] {
        guard let roster = teamData["roster"] as? [String: Any],
              let entries = roster["entries"] as? [[String: Any]] else {
            return []
        }
        
        var players: [Player] = []
        
        for entry in entries {
            // Filter out bench (20) and IR (21) players
            let lineupSlotId = entry["lineupSlotId"] as? Int ?? 20
            guard lineupSlotId != 20 && lineupSlotId != 21 else {
                continue
            }
            
            guard let playerPoolEntry = entry["playerPoolEntry"] as? [String: Any],
                  let player = playerPoolEntry["player"] as? [String: Any],
                  let playerId = player["id"] as? Int,
                  let fullName = player["fullName"] as? String else {
                continue
            }
            
            // Extract position (simplified)
            let positionId = player["defaultPositionId"] as? Int ?? 0
            let position = mapPositionId(positionId)
            
            // Extract points (simplified - using applied stat total if available)
            let points = extractPlayerPoints(from: player)
            
            let playerModel = Player(
                id: String(playerId),
                name: fullName,
                position: position,
                points: points
            )
            
            players.append(playerModel)
        }
        
        // Sort by points and take top 5
        return Array(players.sorted { $0.points > $1.points }.prefix(5))
    }
    
    private func mapPositionId(_ positionId: Int) -> String {
        switch positionId {
        case 1: return "QB"
        case 2: return "RB"
        case 3: return "WR"
        case 4: return "TE"
        case 5: return "K"
        case 16: return "D/ST"
        default: return "FLEX"
        }
    }
    
    private func extractPlayerPoints(from player: [String: Any]) -> Double {
        guard let stats = player["stats"] as? [[String: Any]] else {
            return 0.0
        }
        
        // Find the most recent stat entry with applied total
        for stat in stats {
            if let appliedTotal = stat["appliedTotal"] as? Double {
                return appliedTotal
            }
        }
        
        return 0.0
    }
    
    // MARK: - All Matchups (Time Machine)
    
    func fetchAllMatchups(leagueId: String, season: Int, throughWeek: Int) async throws -> [Int: [WeeklyMatchup]] {
        return try await retryService.execute {
            try await self.performAllMatchupsFetch(leagueId: leagueId, season: season, throughWeek: throughWeek)
        }
    }
    
    private func performAllMatchupsFetch(leagueId: String, season: Int, throughWeek: Int) async throws -> [Int: [WeeklyMatchup]] {
        let credentialsResult = keychainService.retrieveESPNCredentials(forLeagueId: leagueId)
        guard case .success(let credentials) = credentialsResult else {
            throw LeagueDataError.authenticationRequired
        }
        
        let urlString = "\(baseURL)/\(season)/segments/0/leagues/\(leagueId)"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw LeagueDataError.invalidResponse
        }
        
        // Fetch mMatchup without scoringPeriodId to get ALL weeks
        urlComponents.queryItems = [
            URLQueryItem(name: "view", value: "mMatchup")
        ]
        
        guard let url = urlComponents.url else {
            throw LeagueDataError.invalidResponse
        }
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("espn_s2=\(credentials.espnS2); SWID=\(credentials.swid)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeagueDataError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LeagueDataError.parsingError("Failed to parse all-matchups JSON response")
            }
            return try parseAllMatchups(json: json, throughWeek: throughWeek)
            
        case 401, 403:
            _ = keychainService.deleteESPNCredentials(forLeagueId: leagueId)
            onCredentialsExpired?(leagueId)
            throw LeagueDataError.invalidCredentials
            
        case 404:
            throw LeagueDataError.leagueNotFound
            
        default:
            throw LeagueDataError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Parses ALL matchups from the ESPN schedule, grouped by week, through the given week.
    private func parseAllMatchups(json: [String: Any], throughWeek: Int) throws -> [Int: [WeeklyMatchup]] {
        guard let schedule = json["schedule"] as? [[String: Any]] else {
            throw LeagueDataError.parsingError("Missing schedule array in matchup response")
        }
        
        var result: [Int: [WeeklyMatchup]] = [:]
        
        for entry in schedule {
            guard let matchupPeriodId = entry["matchupPeriodId"] as? Int,
                  matchupPeriodId >= 1 && matchupPeriodId <= throughWeek else {
                continue
            }
            
            guard let home = entry["home"] as? [String: Any],
                  let homeTeamId = home["teamId"] as? Int else {
                continue
            }
            
            let homeScore = home["totalPoints"] as? Double ?? 0.0
            let homePlayers = parseRosterPlayers(from: home)
            
            var awayTeamId = 0
            var awayScore = 0.0
            var awayPlayers: [WeeklyPlayerStats] = []
            
            if let away = entry["away"] as? [String: Any] {
                awayTeamId = away["teamId"] as? Int ?? 0
                awayScore = away["totalPoints"] as? Double ?? 0.0
                awayPlayers = parseRosterPlayers(from: away)
            }
            
            guard awayTeamId != 0 else { continue }
            
            let matchup = WeeklyMatchup(
                weekNumber: matchupPeriodId,
                homeTeamId: String(homeTeamId),
                awayTeamId: String(awayTeamId),
                homeScore: homeScore,
                awayScore: awayScore,
                homePlayers: homePlayers,
                awayPlayers: awayPlayers
            )
            result[matchupPeriodId, default: []].append(matchup)
        }
        
        return result
    }
}
