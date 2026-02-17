import XCTest
@testable import SkidmarkApp

class SleeperServiceTests: XCTestCase {
    
    // MARK: - Successful Data Fetch Tests
    
    func testFetchLeagueDataSuccess() async throws {
        let mockSession = MockURLSession()
        let service = SleeperService(session: mockSession)
        
        // Mock league response
        let leagueJSON: [String: Any] = [
            "league_id": "123456",
            "name": "Test League",
            "total_rosters": 2,
            "season": "2024"
        ]
        
        // Mock rosters response
        let rostersJSON: [[String: Any]] = [
            [
                "roster_id": 1,
                "owner_id": "user1",
                "settings": [
                    "wins": 8,
                    "losses": 5,
                    "ties": 0,
                    "fpts": 1250,
                    "fpts_against": 1100
                ]
            ],
            [
                "roster_id": 2,
                "owner_id": "user2",
                "settings": [
                    "wins": 5,
                    "losses": 8,
                    "ties": 0,
                    "fpts": 1100,
                    "fpts_against": 1250
                ]
            ]
        ]
        
        // Mock users response
        let usersJSON: [[String: Any]] = [
            [
                "user_id": "user1",
                "username": "player1",
                "display_name": "Player One",
                "metadata": [
                    "team_name": "Team Alpha"
                ]
            ],
            [
                "user_id": "user2",
                "username": "player2",
                "display_name": "Player Two",
                "metadata": [:]
            ]
        ]
        
        // Set up mock responses by URL
        await mockSession.setMockResponses(
            league: MockURLSession.MockResponse(data: try! JSONSerialization.data(withJSONObject: leagueJSON), statusCode: 200),
            rosters: MockURLSession.MockResponse(data: try! JSONSerialization.data(withJSONObject: rostersJSON), statusCode: 200),
            users: MockURLSession.MockResponse(data: try! JSONSerialization.data(withJSONObject: usersJSON), statusCode: 200),
            leagueId: "123456"
        )
        
        let teams = try await service.fetchLeagueData(leagueId: "123456", season: 2024)
        
        XCTAssertEqual(teams.count, 2)
        
        // Verify first team
        let team1 = teams.first { $0.id == "1" }
        XCTAssertNotNil(team1)
        XCTAssertEqual(team1?.name, "Team Alpha")
        XCTAssertEqual(team1?.ownerName, "Player One")
        XCTAssertEqual(team1?.wins, 8)
        XCTAssertEqual(team1?.losses, 5)
        XCTAssertEqual(team1?.ties, 0)
        XCTAssertEqual(team1?.pointsFor, 1250.0)
        XCTAssertEqual(team1?.pointsAgainst, 1100.0)
        
        // Verify second team (no custom team name, should use display_name)
        let team2 = teams.first { $0.id == "2" }
        XCTAssertNotNil(team2)
        XCTAssertEqual(team2?.name, "Player Two")
        XCTAssertEqual(team2?.ownerName, "Player Two")
    }
    
    // MARK: - Data Transformation Tests
    
    func testDataTransformationProducesValidTeamModels() async throws {
        let mockSession = MockURLSession()
        let service = SleeperService(session: mockSession)
        
        let leagueJSON: [String: Any] = ["league_id": "123", "name": "Test", "season": "2024"]
        let rostersJSON: [[String: Any]] = [
            [
                "roster_id": 1,
                "owner_id": "user1",
                "settings": ["wins": 10, "losses": 3, "ties": 0, "fpts": 1500, "fpts_against": 1200]
            ]
        ]
        let usersJSON: [[String: Any]] = [
            ["user_id": "user1", "username": "testuser", "display_name": "Test User", "metadata": [:]]
        ]
        
        await mockSession.setMockResponses(
            league: MockURLSession.MockResponse(data: try! JSONSerialization.data(withJSONObject: leagueJSON), statusCode: 200),
            rosters: MockURLSession.MockResponse(data: try! JSONSerialization.data(withJSONObject: rostersJSON), statusCode: 200),
            users: MockURLSession.MockResponse(data: try! JSONSerialization.data(withJSONObject: usersJSON), statusCode: 200),
            leagueId: "123"
        )
        
        let teams = try await service.fetchLeagueData(leagueId: "123", season: 2024)
        
        XCTAssertEqual(teams.count, 1)
        let team = teams[0]
        
        // Verify all required Team fields are populated
        XCTAssertFalse(team.id.isEmpty)
        XCTAssertFalse(team.name.isEmpty)
        XCTAssertFalse(team.ownerName.isEmpty)
        XCTAssertGreaterThanOrEqual(team.wins, 0)
        XCTAssertGreaterThanOrEqual(team.losses, 0)
        XCTAssertGreaterThanOrEqual(team.ties, 0)
        XCTAssertGreaterThanOrEqual(team.pointsFor, 0)
        XCTAssertGreaterThanOrEqual(team.pointsAgainst, 0)
        XCTAssertNotNil(team.streak)
        XCTAssertNotNil(team.topPlayers)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidLeagueIdReturns404() async {
        let mockSession = MockURLSession()
        let service = SleeperService(session: mockSession)
        
        await mockSession.setMockResponse(
            url: "https://api.sleeper.app/v1/league/invalid",
            response: MockURLSession.MockResponse(data: Data(), statusCode: 404)
        )
        
        do {
            _ = try await service.fetchLeagueData(leagueId: "invalid", season: 2024)
            XCTFail("Expected leagueNotFound error")
        } catch let error as LeagueDataError {
            if case .leagueNotFound = error {
                // Success - correct error thrown
            } else {
                XCTFail("Expected leagueNotFound error, got \(error)")
            }
        } catch {
            XCTFail("Expected LeagueDataError, got \(error)")
        }
    }
    
    func testNetworkFailureHandling() async {
        let mockSession = MockURLSession()
        let service = SleeperService(session: mockSession)
        
        await mockSession.setMockResponse(
            url: "https://api.sleeper.app/v1/league/123",
            response: MockURLSession.MockResponse(data: Data(), statusCode: 500)
        )
        
        do {
            _ = try await service.fetchLeagueData(leagueId: "123", season: 2024)
            XCTFail("Expected serverError")
        } catch let error as LeagueDataError {
            if case .serverError(let statusCode) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Expected LeagueDataError, got \(error)")
        }
    }
}
