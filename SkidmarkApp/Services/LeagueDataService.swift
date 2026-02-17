import Foundation

/// Protocol defining the interface for fetching fantasy league data from various platforms
protocol LeagueDataService {
    /// Fetches league data including teams, rosters, and standings
    /// - Parameters:
    ///   - leagueId: The unique identifier for the league on the platform
    ///   - season: The season year (e.g., 2024)
    /// - Returns: Array of Team models with complete data
    /// - Throws: LeagueDataError for various failure scenarios
    func fetchLeagueData(leagueId: String, season: Int) async throws -> [Team]

    /// Fetches head-to-head matchup data for a specific week
    func fetchMatchupData(leagueId: String, season: Int, week: Int) async throws -> [WeeklyMatchup]

    /// Fetches league configuration including playoff settings and current week
    func fetchLeagueSettings(leagueId: String, season: Int) async throws -> LeagueSettings

    /// Fetches playoff bracket data for a specific week
    func fetchPlayoffBracket(leagueId: String, season: Int, week: Int) async throws -> [PlayoffBracketEntry]

    /// Fetches matchup results for all weeks up through the given week.
    /// Returns a dictionary keyed by week number.
    func fetchAllMatchups(leagueId: String, season: Int, throughWeek: Int) async throws -> [Int: [WeeklyMatchup]]
}

// MARK: - Default Implementations

extension LeagueDataService {
    func fetchMatchupData(leagueId: String, season: Int, week: Int) async throws -> [WeeklyMatchup] {
        throw LeagueDataError.notSupported("fetchMatchupData")
    }

    func fetchLeagueSettings(leagueId: String, season: Int) async throws -> LeagueSettings {
        throw LeagueDataError.notSupported("fetchLeagueSettings")
    }

    func fetchPlayoffBracket(leagueId: String, season: Int, week: Int) async throws -> [PlayoffBracketEntry] {
        throw LeagueDataError.notSupported("fetchPlayoffBracket")
    }

    func fetchAllMatchups(leagueId: String, season: Int, throughWeek: Int) async throws -> [Int: [WeeklyMatchup]] {
        throw LeagueDataError.notSupported("fetchAllMatchups")
    }
}

/// Errors that can occur when fetching league data
enum LeagueDataError: LocalizedError {
    case networkError(Error)
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case authenticationRequired
    case invalidCredentials
    case forbidden
    case leagueNotFound
    case invalidResponse
    case parsingError(String)
    case missingRequiredField(String)
    case notSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .timeout:
            return "Request timed out. Please try again."
        case .serverError(let statusCode):
            return "Server error (status code: \(statusCode)). Please try again later."
        case .authenticationRequired:
            return "Authentication required. Please provide credentials."
        case .invalidCredentials:
            return "Invalid credentials. Please check your login information."
        case .forbidden:
            return "Access forbidden. You may not have permission to view this league."
        case .leagueNotFound:
            return "League not found. Please verify your league ID."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .parsingError(let details):
            return "Failed to parse response: \(details)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .notSupported(let method):
            return "\(method) is not supported by this service"
        }
    }
}
