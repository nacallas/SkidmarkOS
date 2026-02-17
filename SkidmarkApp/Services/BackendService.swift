import Foundation

/// Protocol defining the interface for backend AI roast generation
protocol BackendService {
    /// Generates AI-powered roasts for fantasy teams
    /// - Parameters:
    ///   - teams: Array of teams to generate roasts for
    ///   - context: League context including inside jokes, personalities, etc.
    /// - Returns: Dictionary mapping team ID to roast text
    /// - Throws: BackendError for various failure scenarios
    func generateRoasts(teams: [Team], context: LeagueContext) async throws -> [String: String]

    /// Generates AI-powered roasts with matchup data, season phase, and optional playoff bracket
    func generateRoasts(
        teams: [Team],
        context: LeagueContext,
        matchups: [WeeklyMatchup],
        weekNumber: Int,
        seasonPhase: SeasonPhase,
        playoffBracket: [PlayoffBracketEntry]?
    ) async throws -> [String: String]
}

/// Errors that can occur when communicating with the backend service
enum BackendError: LocalizedError {
    case networkError(Error)
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case invalidResponse
    case parsingError(String)
    case missingRoasts([String])
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .timeout:
            return "Roast generation timed out. Please try again."
        case .serverError(let statusCode):
            return "Server error (status code: \(statusCode)). Please try again later."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .parsingError(let details):
            return "Failed to parse response: \(details)"
        case .missingRoasts(let teamIds):
            return "Missing roasts for teams: \(teamIds.joined(separator: ", "))"
        case .invalidURL:
            return "Invalid backend URL configuration."
        }
    }
}

/// Implementation of BackendService for AWS Bedrock integration
class AWSBackendService: BackendService {
    private let baseURL: String
    private let session: URLSessionProtocol
    private let timeout: TimeInterval
    private let retryService: RetryableService
    
    /// Initialize the backend service
    /// - Parameters:
    ///   - baseURL: The base URL for the backend API (defaults to production endpoint)
    ///   - timeout: Request timeout in seconds (defaults to 30)
    ///   - session: URLSessionProtocol to use for requests (defaults to shared session)
    ///   - networkMonitor: Optional network monitor for connectivity checks
    init(baseURL: String = "https://4kmztnypnd.execute-api.us-west-2.amazonaws.com", timeout: TimeInterval = 30, session: URLSessionProtocol = URLSession.shared, networkMonitor: NetworkMonitor? = nil) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
        self.retryService = RetryableService(policy: .default, networkMonitor: networkMonitor)
    }
    
    /// Convenience method that delegates to the enhanced version with empty matchups and regular-season defaults
    func generateRoasts(teams: [Team], context: LeagueContext) async throws -> [String: String] {
        return try await generateRoasts(
            teams: teams,
            context: context,
            matchups: [],
            weekNumber: 0,
            seasonPhase: .regularSeason,
            playoffBracket: nil
        )
    }

    func generateRoasts(
        teams: [Team],
        context: LeagueContext,
        matchups: [WeeklyMatchup],
        weekNumber: Int,
        seasonPhase: SeasonPhase,
        playoffBracket: [PlayoffBracketEntry]?
    ) async throws -> [String: String] {
        return try await retryService.execute {
            try await self.performRoastGeneration(
                teams: teams,
                context: context,
                matchups: matchups,
                weekNumber: weekNumber,
                seasonPhase: seasonPhase,
                playoffBracket: playoffBracket
            )
        }
    }

    private func performRoastGeneration(
        teams: [Team],
        context: LeagueContext,
        matchups: [WeeklyMatchup],
        weekNumber: Int,
        seasonPhase: SeasonPhase,
        playoffBracket: [PlayoffBracketEntry]?
    ) async throws -> [String: String] {
        // Construct the endpoint URL
        guard let url = URL(string: "\(baseURL)/roasts/generate") else {
            throw BackendError.invalidURL
        }
        
        // Build the expanded request body
        let requestBody = EnhancedRoastRequest(
            teams: teams,
            context: context,
            matchups: matchups,
            weekNumber: weekNumber,
            seasonPhase: seasonPhase,
            playoffBracket: playoffBracket
        )
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        // Encode the request body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        do {
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            throw BackendError.parsingError("Failed to encode request: \(error.localizedDescription)")
        }
        
        // Send the request
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as NSError {
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                    throw BackendError.noConnection
                case NSURLErrorTimedOut:
                    throw BackendError.timeout
                default:
                    throw BackendError.networkError(error)
                }
            }
            throw BackendError.networkError(error)
        }
        
        // Check HTTP status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let roastResponse: RoastResponse
        do {
            roastResponse = try decoder.decode(RoastResponse.self, from: data)
        } catch {
            throw BackendError.parsingError("Failed to decode response: \(error.localizedDescription)")
        }
        
        // Verify all teams have roasts
        let teamIds = Set(teams.map { $0.id })
        let roastIds = Set(roastResponse.roasts.keys)
        let missingIds = teamIds.subtracting(roastIds)
        
        if !missingIds.isEmpty {
            throw BackendError.missingRoasts(Array(missingIds))
        }
        
        return roastResponse.roasts
    }
}

// MARK: - Request/Response Models

/// Enhanced request body for roast generation with matchup data and season phase
private struct EnhancedRoastRequest: Codable {
    let teams: [TeamData]
    let context: ContextData
    let matchups: [MatchupData]
    let weekNumber: Int
    let seasonPhase: String
    let playoffBracket: [BracketEntryData]?

    init(
        teams: [Team],
        context: LeagueContext,
        matchups: [WeeklyMatchup],
        weekNumber: Int,
        seasonPhase: SeasonPhase,
        playoffBracket: [PlayoffBracketEntry]?
    ) {
        self.teams = teams.map { TeamData(team: $0) }
        self.context = ContextData(context: context)
        self.matchups = matchups.map { MatchupData(matchup: $0) }
        self.weekNumber = weekNumber
        self.seasonPhase = seasonPhase == .playoffs ? "playoffs" : "regular_season"
        self.playoffBracket = playoffBracket?.map { BracketEntryData(entry: $0) }
    }
}

/// Matchup data for the roast generation request
private struct MatchupData: Codable {
    let homeTeamId: String
    let awayTeamId: String
    let homeScore: Double
    let awayScore: Double
    let homePlayers: [MatchupPlayerData]
    let awayPlayers: [MatchupPlayerData]

    init(matchup: WeeklyMatchup) {
        self.homeTeamId = matchup.homeTeamId
        self.awayTeamId = matchup.awayTeamId
        self.homeScore = matchup.homeScore
        self.awayScore = matchup.awayScore
        self.homePlayers = matchup.homePlayers.map { MatchupPlayerData(stats: $0) }
        self.awayPlayers = matchup.awayPlayers.map { MatchupPlayerData(stats: $0) }
    }
}

/// Player stats within a matchup for the roast generation request
private struct MatchupPlayerData: Codable {
    let name: String
    let position: String
    let points: Double
    let isStarter: Bool

    init(stats: WeeklyPlayerStats) {
        self.name = stats.name
        self.position = stats.position
        self.points = stats.points
        self.isStarter = stats.isStarter
    }
}

/// Playoff bracket entry for the roast generation request
private struct BracketEntryData: Codable {
    let teamId: String
    let seed: Int
    let currentRound: Int
    let opponentTeamId: String?
    let isEliminated: Bool
    let isConsolation: Bool
    let isChampionship: Bool

    init(entry: PlayoffBracketEntry) {
        self.teamId = entry.teamId
        self.seed = entry.seed
        self.currentRound = entry.currentRound
        self.opponentTeamId = entry.opponentTeamId
        self.isEliminated = entry.isEliminated
        self.isConsolation = entry.isConsolation
        self.isChampionship = entry.isChampionship
    }
}

/// Team data for roast generation request
private struct TeamData: Codable {
    let id: String
    let name: String
    let owner: String
    let record: String
    let pointsFor: Double
    let pointsAgainst: Double
    let streak: String
    let topPlayers: [PlayerData]
    
    init(team: Team) {
        self.id = team.id
        self.name = team.name
        self.owner = team.ownerName
        self.record = team.record
        self.pointsFor = team.pointsFor
        self.pointsAgainst = team.pointsAgainst
        self.streak = team.streak.displayString
        self.topPlayers = team.topPlayers.map { PlayerData(player: $0) }
    }
}

/// Player data for roast generation request
private struct PlayerData: Codable {
    let name: String
    let position: String
    let points: Double
    
    init(player: Player) {
        self.name = player.name
        self.position = player.position
        self.points = player.points
    }
}

/// Context data for roast generation request
private struct ContextData: Codable {
    let insideJokes: [InsideJokeData]
    let personalities: [PersonalityData]
    let sackoPunishment: String
    let cultureNotes: String
    
    init(context: LeagueContext) {
        self.insideJokes = context.insideJokes.map { InsideJokeData(joke: $0) }
        self.personalities = context.personalities.map { PersonalityData(personality: $0) }
        self.sackoPunishment = context.sackoPunishment
        self.cultureNotes = context.cultureNotes
    }
}

/// Inside joke data for roast generation request
private struct InsideJokeData: Codable {
    let term: String
    let explanation: String
    
    init(joke: LeagueContext.InsideJoke) {
        self.term = joke.term
        self.explanation = joke.explanation
    }
}

/// Personality data for roast generation request
private struct PersonalityData: Codable {
    let playerName: String
    let description: String
    
    init(personality: LeagueContext.PlayerPersonality) {
        self.playerName = personality.playerName
        self.description = personality.description
    }
}

/// Response from roast generation endpoint
private struct RoastResponse: Codable {
    let roasts: [String: String]
}
