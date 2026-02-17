import XCTest
@testable import SkidmarkApp

final class ESPNServiceTests: XCTestCase {
    
    // MARK: - Authentication Tests
    
    func testFetchLeagueDataIncludesAuthenticationHeader() async throws {
        // Given: Valid credentials in keychain and mock session
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "test_espn_s2_cookie", swid: "{TEST-SWID}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        // Mock successful response
        let mockResponse = createMockESPNResponse()
        await mockSession.setMockESPNResponse(
            leagueId: "12345",
            season: 2024,
            response: MockURLSession.MockResponse(data: mockResponse, statusCode: 200)
        )
        
        // When: Fetching league data
        _ = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
        
        // Then: Request should include Cookie header with credentials
        let lastRequest = await mockSession.getLastRequest()
        XCTAssertNotNil(lastRequest)
        let cookieHeader = lastRequest?.value(forHTTPHeaderField: "Cookie")
        XCTAssertNotNil(cookieHeader)
        XCTAssertTrue(cookieHeader?.contains("espn_s2=test_espn_s2_cookie") ?? false)
        XCTAssertTrue(cookieHeader?.contains("SWID={TEST-SWID}") ?? false)
    }
    
    func testFetchLeagueDataThrowsAuthenticationRequiredWhenNoCredentials() async {
        // Given: No credentials in keychain
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        mockKeychainService.credentialsToReturn = .failure(.credentialsNotFound)
        
        // When/Then: Should throw authentication required error
        do {
            _ = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
            XCTFail("Expected authenticationRequired error")
        } catch let error as LeagueDataError {
            if case .authenticationRequired = error {
                // Success
            } else {
                XCTFail("Expected authenticationRequired, got \(error)")
            }
        } catch {
            XCTFail("Expected LeagueDataError, got \(error)")
        }
    }
    
    func testFetchLeagueDataClearsCredentialsOn401Response() async {
        // Given: Valid credentials but server returns 401
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "invalid_cookie", swid: "{INVALID}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        await mockSession.setMockESPNResponse(
            leagueId: "12345",
            season: 2024,
            response: MockURLSession.MockResponse(data: Data(), statusCode: 401)
        )
        
        // When: Fetching league data
        do {
            _ = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
            XCTFail("Expected invalidCredentials error")
        } catch let error as LeagueDataError {
            // Then: Should throw invalid credentials error
            if case .invalidCredentials = error {
                // And credentials should be deleted
                XCTAssertTrue(mockKeychainService.deleteWasCalled)
                XCTAssertEqual(mockKeychainService.lastDeletedLeagueId, "12345")
            } else {
                XCTFail("Expected invalidCredentials, got \(error)")
            }
        } catch {
            XCTFail("Expected LeagueDataError, got \(error)")
        }
    }
    
    func testFetchLeagueDataClearsCredentialsOn403Response() async {
        // Given: Valid credentials but server returns 403
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "forbidden_cookie", swid: "{FORBIDDEN}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        await mockSession.setMockESPNResponse(
            leagueId: "12345",
            season: 2024,
            response: MockURLSession.MockResponse(data: Data(), statusCode: 403)
        )
        
        // When: Fetching league data
        do {
            _ = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
            XCTFail("Expected invalidCredentials error")
        } catch let error as LeagueDataError {
            // Then: Should throw invalid credentials error and delete credentials
            if case .invalidCredentials = error {
                XCTAssertTrue(mockKeychainService.deleteWasCalled)
            } else {
                XCTFail("Expected invalidCredentials, got \(error)")
            }
        } catch {
            XCTFail("Expected LeagueDataError, got \(error)")
        }
    }
    
    // MARK: - Data Transformation Tests
    
    func testSuccessfulLeagueDataFetchProducesValidTeams() async throws {
        // Given: Valid credentials and mock ESPN response
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "valid_cookie", swid: "{VALID}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        let mockResponse = createMockESPNResponse()
        await mockSession.setMockESPNResponse(
            leagueId: "12345",
            season: 2024,
            response: MockURLSession.MockResponse(data: mockResponse, statusCode: 200)
        )
        
        // When: Fetching league data
        let teams = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
        
        // Then: Should produce valid Team models
        XCTAssertEqual(teams.count, 2)
        
        let team1 = teams[0]
        XCTAssertEqual(team1.id, "1")
        XCTAssertEqual(team1.name, "Richard Buttana")
        XCTAssertEqual(team1.ownerName, "Thomas Wilde")
        XCTAssertEqual(team1.wins, 3)
        XCTAssertEqual(team1.losses, 0)
        XCTAssertEqual(team1.ties, 0)
        XCTAssertEqual(team1.pointsFor, 302.29, accuracy: 0.01)
        XCTAssertEqual(team1.pointsAgainst, 215.28, accuracy: 0.01)
        XCTAssertEqual(team1.streak.type, .win)
        XCTAssertEqual(team1.streak.length, 3)
        
        let team2 = teams[1]
        XCTAssertEqual(team2.id, "2")
        XCTAssertEqual(team2.name, "The Champs")
        XCTAssertEqual(team2.ownerName, "Jane Smith")
    }
    
    func testTeamNamePrefersNameFieldOverLocationNickname() async throws {
        // Given: Response where "name" field differs from location+nickname
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "valid_cookie", swid: "{VALID}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        let json: [String: Any] = [
            "teams": [
                [
                    "id": 1,
                    "name": "My Custom Name",
                    "location": "Different",
                    "nickname": "Values",
                    "abbrev": "MCN",
                    "primaryOwner": "GUID-1",
                    "record": ["overall": ["wins": 1, "losses": 0, "ties": 0, "pointsFor": 100.0, "pointsAgainst": 90.0, "streakLength": 1, "streakType": "WIN"]]
                ]
            ],
            "members": [["id": "GUID-1", "firstName": "Test", "lastName": "User"]]
        ]
        let mockResponse = try! JSONSerialization.data(withJSONObject: json)
        await mockSession.setMockESPNResponse(
            leagueId: "12345", season: 2024,
            response: MockURLSession.MockResponse(data: mockResponse, statusCode: 200)
        )
        
        // When
        let teams = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
        
        // Then: "name" field should take priority
        XCTAssertEqual(teams[0].name, "My Custom Name")
    }
    
    func testTeamNameFallsBackToAbbrevWhenNameAndLocationNicknameEmpty() async throws {
        // Given: Response with no name, empty location/nickname, but abbrev present
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "valid_cookie", swid: "{VALID}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        let json: [String: Any] = [
            "teams": [
                [
                    "id": 5,
                    "location": "",
                    "nickname": "",
                    "abbrev": "ABCD",
                    "primaryOwner": "GUID-1",
                    "record": ["overall": ["wins": 0, "losses": 0, "ties": 0, "pointsFor": 0.0, "pointsAgainst": 0.0, "streakLength": 1, "streakType": "LOSS"]]
                ]
            ],
            "members": [["id": "GUID-1", "firstName": "Test", "lastName": "User"]]
        ]
        let mockResponse = try! JSONSerialization.data(withJSONObject: json)
        await mockSession.setMockESPNResponse(
            leagueId: "12345", season: 2024,
            response: MockURLSession.MockResponse(data: mockResponse, statusCode: 200)
        )
        
        // When
        let teams = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
        
        // Then: should fall back to abbrev
        XCTAssertEqual(teams[0].name, "ABCD")
    }
    
    func testTeamNameFallsBackToTeamIdWhenAllFieldsEmpty() async throws {
        // Given: Response with all name fields empty
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "valid_cookie", swid: "{VALID}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        let json: [String: Any] = [
            "teams": [
                [
                    "id": 7,
                    "location": "",
                    "nickname": "",
                    "abbrev": "",
                    "primaryOwner": "GUID-1",
                    "record": ["overall": ["wins": 0, "losses": 0, "ties": 0, "pointsFor": 0.0, "pointsAgainst": 0.0, "streakLength": 1, "streakType": "LOSS"]]
                ]
            ],
            "members": [["id": "GUID-1", "firstName": "Test", "lastName": "User"]]
        ]
        let mockResponse = try! JSONSerialization.data(withJSONObject: json)
        await mockSession.setMockESPNResponse(
            leagueId: "12345", season: 2024,
            response: MockURLSession.MockResponse(data: mockResponse, statusCode: 200)
        )
        
        // When
        let teams = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
        
        // Then: should fall back to "Team {id}"
        XCTAssertEqual(teams[0].name, "Team 7")
    }
    
    func testDataTransformationHandlesMissingOwnerData() async throws {
        // Given: Response with missing owner information
        let mockSession = MockURLSession()
        let mockKeychainService = MockKeychainService()
        let espnService = ESPNService(session: mockSession, keychainService: mockKeychainService)
        
        let credentials = ESPNCredentials(espnS2: "valid_cookie", swid: "{VALID}")
        mockKeychainService.credentialsToReturn = .success(credentials)
        
        let mockResponse = createMockESPNResponseWithMissingOwner()
        await mockSession.setMockESPNResponse(
            leagueId: "12345",
            season: 2024,
            response: MockURLSession.MockResponse(data: mockResponse, statusCode: 200)
        )
        
        // When: Fetching league data
        let teams = try await espnService.fetchLeagueData(leagueId: "12345", season: 2024)
        
        // Then: Should use fallback owner name
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams[0].ownerName, "Unknown Owner")
    }
    
    // MARK: - Helper Methods
    
    private func createMockESPNResponse() -> Data {
        let json: [String: Any] = [
            "teams": [
                [
                    "id": 1,
                    "name": "Richard Buttana",
                    "location": "Richard",
                    "nickname": "Buttana",
                    "abbrev": "DICK",
                    "primaryOwner": "GUID-1",
                    "record": [
                        "overall": [
                            "wins": 3,
                            "losses": 0,
                            "ties": 0,
                            "pointsFor": 302.29,
                            "pointsAgainst": 215.28,
                            "streakLength": 3,
                            "streakType": "WIN"
                        ]
                    ],
                    "roster": [
                        "entries": [
                            [
                                "lineupSlotId": 0,
                                "playerPoolEntry": [
                                    "player": [
                                        "id": 15847,
                                        "fullName": "Travis Kelce",
                                        "defaultPositionId": 4,
                                        "stats": [
                                            ["appliedTotal": 18.5]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                [
                    "id": 2,
                    "name": "The Champs",
                    "location": "The",
                    "nickname": "Champs",
                    "abbrev": "TC",
                    "primaryOwner": "GUID-2",
                    "record": [
                        "overall": [
                            "wins": 2,
                            "losses": 1,
                            "ties": 0,
                            "pointsFor": 250.0,
                            "pointsAgainst": 240.0,
                            "streakLength": 1,
                            "streakType": "LOSS"
                        ]
                    ],
                    "roster": [
                        "entries": []
                    ]
                ]
            ],
            "members": [
                [
                    "id": "GUID-1",
                    "firstName": "Thomas",
                    "lastName": "Wilde",
                    "displayName": "Wildebeast214"
                ],
                [
                    "id": "GUID-2",
                    "firstName": "Jane",
                    "lastName": "Smith",
                    "displayName": "JSmith"
                ]
            ]
        ]
        
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func createMockESPNResponseWithMissingOwner() -> Data {
        let json: [String: Any] = [
            "teams": [
                [
                    "id": 1,
                    "location": "Test",
                    "nickname": "Team",
                    "primaryOwner": "MISSING-GUID",
                    "record": [
                        "overall": [
                            "wins": 1,
                            "losses": 0,
                            "ties": 0,
                            "pointsFor": 100.0,
                            "pointsAgainst": 90.0,
                            "streakLength": 1,
                            "streakType": "WIN"
                        ]
                    ],
                    "roster": [
                        "entries": []
                    ]
                ]
            ],
            "members": []
        ]
        
        return try! JSONSerialization.data(withJSONObject: json)
    }
}

// MARK: - Mock Classes

class MockKeychainService: KeychainService {
    var credentialsToReturn: Result<ESPNCredentials, KeychainError> = .failure(.credentialsNotFound)
    var deleteWasCalled = false
    var lastDeletedLeagueId: String?
    
    func saveESPNCredentials(espnS2: String, swid: String, forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        return .success(())
    }
    
    func retrieveESPNCredentials(forLeagueId leagueId: String) -> Result<ESPNCredentials, KeychainError> {
        return credentialsToReturn
    }
    
    func deleteESPNCredentials(forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        deleteWasCalled = true
        lastDeletedLeagueId = leagueId
        return .success(())
    }
    
    func hasESPNCredentials(forLeagueId leagueId: String) -> Bool {
        if case .success = credentialsToReturn {
            return true
        }
        return false
    }
}
