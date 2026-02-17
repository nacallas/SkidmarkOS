import Foundation
@testable import SkidmarkApp

// MARK: - Mock URLSession

actor MockURLSession: URLSessionProtocol {
    struct MockResponse {
        let data: Data
        let statusCode: Int
    }
    
    private var mockResponsesByURL: [String: MockResponse] = [:]
    private var lastRequest: URLRequest?
    
    func setMockResponse(url: String, response: MockResponse) {
        mockResponsesByURL[url] = response
    }
    
    func setMockResponses(league: MockResponse, rosters: MockResponse, users: MockResponse, leagueId: String) {
        mockResponsesByURL["https://api.sleeper.app/v1/league/\(leagueId)"] = league
        mockResponsesByURL["https://api.sleeper.app/v1/league/\(leagueId)/rosters"] = rosters
        mockResponsesByURL["https://api.sleeper.app/v1/league/\(leagueId)/users"] = users
    }
    
    func setMockESPNResponse(leagueId: String, season: Int, response: MockResponse) {
        // ESPN URL pattern with query parameters
        let baseURL = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(season)/segments/0/leagues/\(leagueId)"
        mockResponsesByURL[baseURL] = response
    }
    
    func getLastRequest() -> URLRequest? {
        return lastRequest
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        
        // Try exact match first
        var urlString = url.absoluteString
        
        // For ESPN URLs, strip query parameters for matching
        if urlString.contains("lm-api-reads.fantasy.espn.com") {
            if let baseURL = urlString.components(separatedBy: "?").first {
                urlString = baseURL
            }
        }
        
        guard let mockResponse = mockResponsesByURL[urlString] else {
            throw URLError(.badServerResponse)
        }
        
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: mockResponse.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (mockResponse.data, httpResponse)
    }
}
