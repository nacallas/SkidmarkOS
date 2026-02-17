import XCTest
@testable import SkidmarkApp

final class KeychainServiceTests: XCTestCase {
    var keychainService: DefaultKeychainService!
    let testLeagueId = "test_league_\(UUID().uuidString)"
    
    override func setUp() {
        super.setUp()
        keychainService = DefaultKeychainService()
        // Clean up any existing test data
        _ = keychainService.deleteESPNCredentials(forLeagueId: testLeagueId)
    }
    
    override func tearDown() {
        // Clean up test data
        _ = keychainService.deleteESPNCredentials(forLeagueId: testLeagueId)
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Save Credentials Tests
    
    func testSaveCredentials_Success() {
        let espnS2 = "test_espn_s2_cookie_value"
        let swid = "{TEST-SWID-VALUE}"
        
        let result = keychainService.saveESPNCredentials(
            espnS2: espnS2,
            swid: swid,
            forLeagueId: testLeagueId
        )
        
        XCTAssertTrue(result.isSuccess, "Should successfully save credentials")
    }
    
    func testSaveCredentials_UpdateExisting() {
        let espnS2Original = "original_espn_s2"
        let swidOriginal = "{ORIGINAL-SWID}"
        
        // Save initial credentials
        _ = keychainService.saveESPNCredentials(
            espnS2: espnS2Original,
            swid: swidOriginal,
            forLeagueId: testLeagueId
        )
        
        // Update with new credentials
        let espnS2Updated = "updated_espn_s2"
        let swidUpdated = "{UPDATED-SWID}"
        
        let result = keychainService.saveESPNCredentials(
            espnS2: espnS2Updated,
            swid: swidUpdated,
            forLeagueId: testLeagueId
        )
        
        XCTAssertTrue(result.isSuccess, "Should successfully update credentials")
        
        // Verify updated credentials
        let retrieveResult = keychainService.retrieveESPNCredentials(forLeagueId: testLeagueId)
        if case .success(let credentials) = retrieveResult {
            XCTAssertEqual(credentials.espnS2, espnS2Updated)
            XCTAssertEqual(credentials.swid, swidUpdated)
        } else {
            XCTFail("Should retrieve updated credentials")
        }
    }
    
    // MARK: - Retrieve Credentials Tests
    
    func testRetrieveCredentials_Success() {
        let espnS2 = "test_espn_s2_cookie_value"
        let swid = "{TEST-SWID-VALUE}"
        
        // Save credentials first
        _ = keychainService.saveESPNCredentials(
            espnS2: espnS2,
            swid: swid,
            forLeagueId: testLeagueId
        )
        
        // Retrieve credentials
        let result = keychainService.retrieveESPNCredentials(forLeagueId: testLeagueId)
        
        switch result {
        case .success(let credentials):
            XCTAssertEqual(credentials.espnS2, espnS2)
            XCTAssertEqual(credentials.swid, swid)
        case .failure(let error):
            XCTFail("Should successfully retrieve credentials, got error: \(error)")
        }
    }
    
    func testRetrieveCredentials_NotFound() {
        let nonExistentLeagueId = "non_existent_league_\(UUID().uuidString)"
        
        let result = keychainService.retrieveESPNCredentials(forLeagueId: nonExistentLeagueId)
        
        switch result {
        case .success:
            XCTFail("Should not find credentials for non-existent league")
        case .failure(let error):
            if case .credentialsNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected credentialsNotFound error, got: \(error)")
            }
        }
    }
    
    // MARK: - Delete Credentials Tests
    
    func testDeleteCredentials_Success() {
        let espnS2 = "test_espn_s2_cookie_value"
        let swid = "{TEST-SWID-VALUE}"
        
        // Save credentials first
        _ = keychainService.saveESPNCredentials(
            espnS2: espnS2,
            swid: swid,
            forLeagueId: testLeagueId
        )
        
        // Verify credentials exist
        XCTAssertTrue(keychainService.hasESPNCredentials(forLeagueId: testLeagueId))
        
        // Delete credentials
        let result = keychainService.deleteESPNCredentials(forLeagueId: testLeagueId)
        
        XCTAssertTrue(result.isSuccess, "Should successfully delete credentials")
        
        // Verify credentials no longer exist
        XCTAssertFalse(keychainService.hasESPNCredentials(forLeagueId: testLeagueId))
    }
    
    func testDeleteCredentials_NonExistent() {
        let nonExistentLeagueId = "non_existent_league_\(UUID().uuidString)"
        
        // Deleting non-existent credentials should succeed (idempotent)
        let result = keychainService.deleteESPNCredentials(forLeagueId: nonExistentLeagueId)
        
        XCTAssertTrue(result.isSuccess, "Deleting non-existent credentials should succeed")
    }
    
    // MARK: - Has Credentials Tests
    
    func testHasCredentials_True() {
        let espnS2 = "test_espn_s2_cookie_value"
        let swid = "{TEST-SWID-VALUE}"
        
        // Save credentials
        _ = keychainService.saveESPNCredentials(
            espnS2: espnS2,
            swid: swid,
            forLeagueId: testLeagueId
        )
        
        XCTAssertTrue(keychainService.hasESPNCredentials(forLeagueId: testLeagueId))
    }
    
    func testHasCredentials_False() {
        let nonExistentLeagueId = "non_existent_league_\(UUID().uuidString)"
        
        XCTAssertFalse(keychainService.hasESPNCredentials(forLeagueId: nonExistentLeagueId))
    }
    
    // MARK: - Isolation Tests
    
    func testCredentials_IsolatedByLeagueId() {
        let league1 = "league_1_\(UUID().uuidString)"
        let league2 = "league_2_\(UUID().uuidString)"
        
        let espnS2_1 = "espn_s2_league_1"
        let swid_1 = "{SWID-LEAGUE-1}"
        
        let espnS2_2 = "espn_s2_league_2"
        let swid_2 = "{SWID-LEAGUE-2}"
        
        // Save credentials for both leagues
        _ = keychainService.saveESPNCredentials(espnS2: espnS2_1, swid: swid_1, forLeagueId: league1)
        _ = keychainService.saveESPNCredentials(espnS2: espnS2_2, swid: swid_2, forLeagueId: league2)
        
        // Retrieve and verify league 1 credentials
        if case .success(let creds1) = keychainService.retrieveESPNCredentials(forLeagueId: league1) {
            XCTAssertEqual(creds1.espnS2, espnS2_1)
            XCTAssertEqual(creds1.swid, swid_1)
        } else {
            XCTFail("Should retrieve league 1 credentials")
        }
        
        // Retrieve and verify league 2 credentials
        if case .success(let creds2) = keychainService.retrieveESPNCredentials(forLeagueId: league2) {
            XCTAssertEqual(creds2.espnS2, espnS2_2)
            XCTAssertEqual(creds2.swid, swid_2)
        } else {
            XCTFail("Should retrieve league 2 credentials")
        }
        
        // Clean up
        _ = keychainService.deleteESPNCredentials(forLeagueId: league1)
        _ = keychainService.deleteESPNCredentials(forLeagueId: league2)
    }
    
    // MARK: - Round-Trip Tests
    
    func testCredentials_RoundTrip() {
        let testCases: [(espnS2: String, swid: String)] = [
            ("short", "{S}"),
            ("very_long_espn_s2_cookie_value_with_many_characters_" + String(repeating: "x", count: 200), "{LONG-SWID-VALUE}"),
            ("special!@#$%^&*()chars", "{SPECIAL-CHARS-!@#$}"),
            ("", ""),
            ("espn_s2_with_spaces", "{SWID WITH SPACES}")
        ]
        
        for (index, testCase) in testCases.enumerated() {
            let leagueId = "test_league_\(index)_\(UUID().uuidString)"
            
            // Save
            let saveResult = keychainService.saveESPNCredentials(
                espnS2: testCase.espnS2,
                swid: testCase.swid,
                forLeagueId: leagueId
            )
            XCTAssertTrue(saveResult.isSuccess, "Should save credentials for test case \(index)")
            
            // Retrieve
            let retrieveResult = keychainService.retrieveESPNCredentials(forLeagueId: leagueId)
            if case .success(let credentials) = retrieveResult {
                XCTAssertEqual(credentials.espnS2, testCase.espnS2, "ESPN_S2 should match for test case \(index)")
                XCTAssertEqual(credentials.swid, testCase.swid, "SWID should match for test case \(index)")
            } else {
                XCTFail("Should retrieve credentials for test case \(index)")
            }
            
            // Clean up
            _ = keychainService.deleteESPNCredentials(forLeagueId: leagueId)
        }
    }
}

// MARK: - Result Extension for Testing

extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
}
