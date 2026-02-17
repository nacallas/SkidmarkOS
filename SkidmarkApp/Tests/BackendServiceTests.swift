import XCTest
@testable import SkidmarkApp

final class BackendServiceTests: XCTestCase {
    var mockSession: MockURLSession!
    var service: AWSBackendService!
    
    override func setUp() async throws {
        mockSession = MockURLSession()
        service = AWSBackendService(
            baseURL: "https://api.skidmark.app",
            timeout: 30,
            session: mockSession
        )
    }
    
    override func tearDown() {
        mockSession = nil
        service = nil
    }
    
    // MARK: - Test Successful Roast Generation
    
    func testGenerateRoasts_Success() async throws {
        // Given: Teams and context
        let teams = createMockTeams()
        let context = createMockContext()
        
        // Mock successful response
        let roasts = [
            "team1": "This is a roast for team 1. It's 3-5 sentences long. Great performance this week. Keep it up champ. You're crushing it.",
            "team2": "This is a roast for team 2. Not doing so well. Maybe next week will be better. Don't give up hope. The season isn't over yet."
        ]
        
        let responseData = try JSONEncoder().encode(["roasts": roasts])
        await mockSession.setMockResponse(
            url: "https://api.skidmark.app/roasts/generate",
            response: MockURLSession.MockResponse(data: responseData, statusCode: 200)
        )
        
        // When: Generate roasts
        let result = try await service.generateRoasts(teams: teams, context: context)
        
        // Then: Should return roasts for all teams
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["team1"], roasts["team1"])
        XCTAssertEqual(result["team2"], roasts["team2"])
    }
    
    func testGenerateRoasts_IncludesTeamData() async throws {
        // Given: Teams with specific data
        let teams = createMockTeams()
        let context = createMockContext()
        
        let roasts = ["team1": "Roast 1", "team2": "Roast 2"]
        let responseData = try JSONEncoder().encode(["roasts": roasts])
        await mockSession.setMockResponse(
            url: "https://api.skidmark.app/roasts/generate",
            response: MockURLSession.MockResponse(data: responseData, statusCode: 200)
        )
        
        // When: Generate roasts
        _ = try await service.generateRoasts(teams: teams, context: context)
        
        // Then: Request should include team data
        let request = await mockSession.getLastRequest()
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        
        // Verify request body contains team data
        if let body = request?.httpBody {
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertNotNil(json)
            
            let teamsArray = json?["teams"] as? [[String: Any]]
            XCTAssertEqual(teamsArray?.count, 2)
            
            let firstTeam = teamsArray?.first
            XCTAssertEqual(firstTeam?["id"] as? String, "team1")
            XCTAssertEqual(firstTeam?["name"] as? String, "Team One")
            XCTAssertEqual(firstTeam?["owner"] as? String, "Owner One")
        }
    }
    
    func testGenerateRoasts_IncludesContext() async throws {
        // Given: Context with inside jokes and personalities
        let teams = createMockTeams()
        let context = LeagueContext(
            insideJokes: [
                LeagueContext.InsideJoke(id: UUID(), term: "Taco", explanation: "The worst player")
            ],
            personalities: [
                LeagueContext.PlayerPersonality(id: UUID(), playerName: "John", description: "Always trades too much")
            ],
            sackoPunishment: "Wear a dress",
            cultureNotes: "Very competitive league"
        )
        
        let roasts = ["team1": "Roast 1", "team2": "Roast 2"]
        let responseData = try JSONEncoder().encode(["roasts": roasts])
        await mockSession.setMockResponse(
            url: "https://api.skidmark.app/roasts/generate",
            response: MockURLSession.MockResponse(data: responseData, statusCode: 200)
        )
        
        // When: Generate roasts
        _ = try await service.generateRoasts(teams: teams, context: context)
        
        // Then: Request should include context data
        let request = await mockSession.getLastRequest()
        if let body = request?.httpBody {
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            let contextData = json?["context"] as? [String: Any]
            
            XCTAssertNotNil(contextData)
            XCTAssertEqual(contextData?["sacko_punishment"] as? String, "Wear a dress")
            XCTAssertEqual(contextData?["culture_notes"] as? String, "Very competitive league")
            
            let jokes = contextData?["inside_jokes"] as? [[String: Any]]
            XCTAssertEqual(jokes?.count, 1)
            XCTAssertEqual(jokes?.first?["term"] as? String, "Taco")
            
            let personalities = contextData?["personalities"] as? [[String: Any]]
            XCTAssertEqual(personalities?.count, 1)
            XCTAssertEqual(personalities?.first?["player_name"] as? String, "John")
        }
    }
    
    // MARK: - Test Timeout
    
    func testGenerateRoasts_Timeout() async throws {
        // Given: Teams and context
        let teams = createMockTeams()
        let context = createMockContext()
        
        // Mock timeout error
        let service = AWSBackendService(
            baseURL: "https://api.skidmark.app",
            timeout: 0.001, // Very short timeout
            session: URLSession.shared // Use real session to trigger timeout
        )
        
        // When/Then: Should throw timeout error
        do {
            _ = try await service.generateRoasts(teams: teams, context: context)
            XCTFail("Expected timeout error")
        } catch let error as BackendError {
            switch error {
            case .timeout, .networkError:
                // Expected - either timeout or network error is acceptable
                break
            default:
                XCTFail("Expected timeout or network error, got \(error)")
            }
        }
    }
    
    // MARK: - Test Malformed Response
    
    func testGenerateRoasts_MalformedResponse() async throws {
        // Given: Teams and context
        let teams = createMockTeams()
        let context = createMockContext()
        
        // Mock malformed response (invalid JSON)
        let responseData = "not valid json".data(using: .utf8)!
        await mockSession.setMockResponse(
            url: "https://api.skidmark.app/roasts/generate",
            response: MockURLSession.MockResponse(data: responseData, statusCode: 200)
        )
        
        // When/Then: Should throw parsing error
        do {
            _ = try await service.generateRoasts(teams: teams, context: context)
            XCTFail("Expected parsing error")
        } catch let error as BackendError {
            switch error {
            case .parsingError:
                // Expected
                break
            default:
                XCTFail("Expected parsing error, got \(error)")
            }
        }
    }
    
    func testGenerateRoasts_MissingRoasts() async throws {
        // Given: Teams and context
        let teams = createMockTeams()
        let context = createMockContext()
        
        // Mock response with missing roasts for some teams
        let roasts = ["team1": "Only one roast"]
        let responseData = try JSONEncoder().encode(["roasts": roasts])
        await mockSession.setMockResponse(
            url: "https://api.skidmark.app/roasts/generate",
            response: MockURLSession.MockResponse(data: responseData, statusCode: 200)
        )
        
        // When/Then: Should throw missing roasts error
        do {
            _ = try await service.generateRoasts(teams: teams, context: context)
            XCTFail("Expected missing roasts error")
        } catch let error as BackendError {
            switch error {
            case .missingRoasts(let teamIds):
                XCTAssertTrue(teamIds.contains("team2"))
            default:
                XCTFail("Expected missing roasts error, got \(error)")
            }
        }
    }
    
    // MARK: - Test Server Errors
    
    func testGenerateRoasts_ServerError() async throws {
        // Given: Teams and context
        let teams = createMockTeams()
        let context = createMockContext()
        
        // Mock server error response
        let responseData = Data()
        await mockSession.setMockResponse(
            url: "https://api.skidmark.app/roasts/generate",
            response: MockURLSession.MockResponse(data: responseData, statusCode: 500)
        )
        
        // When/Then: Should throw server error
        do {
            _ = try await service.generateRoasts(teams: teams, context: context)
            XCTFail("Expected server error")
        } catch let error as BackendError {
            switch error {
            case .serverError(let statusCode):
                XCTAssertEqual(statusCode, 500)
            default:
                XCTFail("Expected server error, got \(error)")
            }
        }
    }
    
    func testGenerateRoasts_BadRequest() async throws {
        // Given: Teams and context
        let teams = createMockTeams()
        let context = createMockContext()
        
        // Mock bad request response
        let responseData = Data()
        await mockSession.setMockResponse(
            url: "https://api.skidmark.app/roasts/generate",
            response: MockURLSession.MockResponse(data: responseData, statusCode: 400)
        )
        
        // When/Then: Should throw server error
        do {
            _ = try await service.generateRoasts(teams: teams, context: context)
            XCTFail("Expected server error")
        } catch let error as BackendError {
            switch error {
            case .serverError(let statusCode):
                XCTAssertEqual(statusCode, 400)
            default:
                XCTFail("Expected server error, got \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockTeams() -> [Team] {
        return [
            Team(
                id: "team1",
                name: "Team One",
                ownerName: "Owner One",
                wins: 5,
                losses: 3,
                ties: 0,
                pointsFor: 1200.5,
                pointsAgainst: 1100.0,
                powerScore: 0.0,
                rank: 0,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [
                    Player(id: "p1", name: "Player 1", position: "QB", points: 25.5)
                ],
                roast: nil
            ),
            Team(
                id: "team2",
                name: "Team Two",
                ownerName: "Owner Two",
                wins: 3,
                losses: 5,
                ties: 0,
                pointsFor: 1000.0,
                pointsAgainst: 1150.0,
                powerScore: 0.0,
                rank: 0,
                streak: Team.Streak(type: .loss, length: 1),
                topPlayers: [
                    Player(id: "p2", name: "Player 2", position: "RB", points: 18.0)
                ],
                roast: nil
            )
        ]
    }
    
    private func createMockContext() -> LeagueContext {
        return LeagueContext.empty
    }
}
