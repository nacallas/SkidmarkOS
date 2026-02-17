import XCTest
@testable import SkidmarkApp

/// Property-based tests for storage service data persistence round-trip
/// **Validates: Requirements 1.6, 1.7, 5.5, 8.7, 10.1, 10.3, 10.4**
final class StoragePropertyTests: XCTestCase {
    
    private var storageService: DefaultStorageService!
    private var testDocumentsDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create a temporary directory for test files
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        testDocumentsDirectory = tempDir
        
        // Create storage service with test UserDefaults
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        storageService = DefaultStorageService(userDefaults: testDefaults)
    }
    
    override func tearDown() {
        // Clean up test files
        if let testDir = testDocumentsDirectory {
            try? FileManager.default.removeItem(at: testDir)
        }
        super.tearDown()
    }
    
    // MARK: - Property 2: Data Persistence Round-Trip
    
    /// Property test verifying LeagueConnection data persists correctly through save/load cycle
    /// Runs 100+ iterations with randomly generated league connections
    func testLeagueConnectionRoundTrip() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate random league connections
            let connectionCount = Int.random(in: 1...10)
            let originalConnections = generateRandomLeagueConnections(count: connectionCount)
            
            do {
                // Save connections
                try storageService.saveLeagueConnections(originalConnections)
                
                // Load connections
                let loadedConnections = try storageService.loadLeagueConnections()
                
                // Verify count matches
                XCTAssertEqual(loadedConnections.count, originalConnections.count,
                              "Iteration \(iteration): Should load same number of connections")
                
                // Verify each connection is preserved
                for (index, original) in originalConnections.enumerated() {
                    let loaded = loadedConnections[index]
                    
                    XCTAssertEqual(loaded.id, original.id,
                                  "Iteration \(iteration): Connection \(index) id should match")
                    XCTAssertEqual(loaded.leagueId, original.leagueId,
                                  "Iteration \(iteration): Connection \(index) leagueId should match")
                    XCTAssertEqual(loaded.platform, original.platform,
                                  "Iteration \(iteration): Connection \(index) platform should match")
                    XCTAssertEqual(loaded.leagueName, original.leagueName,
                                  "Iteration \(iteration): Connection \(index) leagueName should match")
                    XCTAssertEqual(loaded.hasAuthentication, original.hasAuthentication,
                                  "Iteration \(iteration): Connection \(index) hasAuthentication should match")
                    
                    // Date comparison with tolerance for encoding/decoding precision
                    let timeDifference = abs(loaded.lastUpdated.timeIntervalSince(original.lastUpdated))
                    XCTAssertLessThan(timeDifference, 1.0,
                                     "Iteration \(iteration): Connection \(index) lastUpdated should match within 1 second")
                }
            } catch {
                XCTFail("Iteration \(iteration): Round-trip failed with error: \(error)")
            }
        }
    }
    
    /// Property test verifying LeagueContext data persists correctly through save/load cycle
    /// Runs 100+ iterations with randomly generated league contexts
    func testLeagueContextRoundTrip() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate random league context
            let leagueId = "league_\(UUID().uuidString)"
            let originalContext = generateRandomLeagueContext()
            
            do {
                // Save context
                try storageService.saveLeagueContext(originalContext, forLeagueId: leagueId)
                
                // Load context
                guard let loadedContext = try storageService.loadLeagueContext(forLeagueId: leagueId) else {
                    XCTFail("Iteration \(iteration): Failed to load saved context")
                    continue
                }
                
                // Verify inside jokes
                XCTAssertEqual(loadedContext.insideJokes.count, originalContext.insideJokes.count,
                              "Iteration \(iteration): Inside jokes count should match")
                
                for (index, original) in originalContext.insideJokes.enumerated() {
                    let loaded = loadedContext.insideJokes[index]
                    XCTAssertEqual(loaded.id, original.id,
                                  "Iteration \(iteration): Inside joke \(index) id should match")
                    XCTAssertEqual(loaded.term, original.term,
                                  "Iteration \(iteration): Inside joke \(index) term should match")
                    XCTAssertEqual(loaded.explanation, original.explanation,
                                  "Iteration \(iteration): Inside joke \(index) explanation should match")
                }
                
                // Verify personalities
                XCTAssertEqual(loadedContext.personalities.count, originalContext.personalities.count,
                              "Iteration \(iteration): Personalities count should match")
                
                for (index, original) in originalContext.personalities.enumerated() {
                    let loaded = loadedContext.personalities[index]
                    XCTAssertEqual(loaded.id, original.id,
                                  "Iteration \(iteration): Personality \(index) id should match")
                    XCTAssertEqual(loaded.playerName, original.playerName,
                                  "Iteration \(iteration): Personality \(index) playerName should match")
                    XCTAssertEqual(loaded.description, original.description,
                                  "Iteration \(iteration): Personality \(index) description should match")
                }
                
                // Verify sacko punishment
                XCTAssertEqual(loadedContext.sackoPunishment, originalContext.sackoPunishment,
                              "Iteration \(iteration): Sacko punishment should match")
                
                // Verify culture notes
                XCTAssertEqual(loadedContext.cultureNotes, originalContext.cultureNotes,
                              "Iteration \(iteration): Culture notes should match")
                
                // Clean up
                try storageService.clearDataForLeague(leagueId: leagueId)
            } catch {
                XCTFail("Iteration \(iteration): Round-trip failed with error: \(error)")
            }
        }
    }

    /// Property test verifying cached league data persists correctly through save/load cycle
    /// Runs 100+ iterations with randomly generated team arrays
    func testCachedLeagueDataRoundTrip() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate random teams
            let leagueId = "league_\(UUID().uuidString)"
            let teamCount = Int.random(in: 1...20)
            let originalTeams = generateRandomTeams(count: teamCount)
            let saveTime = Date()
            
            do {
                // Save cached data
                try storageService.saveCachedLeagueData(originalTeams, forLeagueId: leagueId, roastHash: nil)
                
                // Load cached data
                guard let (loadedTeams, timestamp, _) = try storageService.loadCachedLeagueData(forLeagueId: leagueId) else {
                    XCTFail("Iteration \(iteration): Failed to load saved cached data")
                    continue
                }
                
                // Verify team count
                XCTAssertEqual(loadedTeams.count, originalTeams.count,
                              "Iteration \(iteration): Should load same number of teams")
                
                // Verify timestamp is close to save time
                let timeDifference = abs(timestamp.timeIntervalSince(saveTime))
                XCTAssertLessThan(timeDifference, 2.0,
                                 "Iteration \(iteration): Timestamp should be within 2 seconds of save time")
                
                // Verify each team is preserved
                for (index, original) in originalTeams.enumerated() {
                    let loaded = loadedTeams[index]
                    
                    XCTAssertEqual(loaded.id, original.id,
                                  "Iteration \(iteration): Team \(index) id should match")
                    XCTAssertEqual(loaded.name, original.name,
                                  "Iteration \(iteration): Team \(index) name should match")
                    XCTAssertEqual(loaded.ownerName, original.ownerName,
                                  "Iteration \(iteration): Team \(index) ownerName should match")
                    XCTAssertEqual(loaded.wins, original.wins,
                                  "Iteration \(iteration): Team \(index) wins should match")
                    XCTAssertEqual(loaded.losses, original.losses,
                                  "Iteration \(iteration): Team \(index) losses should match")
                    XCTAssertEqual(loaded.ties, original.ties,
                                  "Iteration \(iteration): Team \(index) ties should match")
                    XCTAssertEqual(loaded.pointsFor, original.pointsFor, accuracy: 0.01,
                                  "Iteration \(iteration): Team \(index) pointsFor should match")
                    XCTAssertEqual(loaded.pointsAgainst, original.pointsAgainst, accuracy: 0.01,
                                  "Iteration \(iteration): Team \(index) pointsAgainst should match")
                    XCTAssertEqual(loaded.powerScore, original.powerScore, accuracy: 0.0001,
                                  "Iteration \(iteration): Team \(index) powerScore should match")
                    XCTAssertEqual(loaded.rank, original.rank,
                                  "Iteration \(iteration): Team \(index) rank should match")
                    XCTAssertEqual(loaded.streak.type, original.streak.type,
                                  "Iteration \(iteration): Team \(index) streak type should match")
                    XCTAssertEqual(loaded.streak.length, original.streak.length,
                                  "Iteration \(iteration): Team \(index) streak length should match")
                    XCTAssertEqual(loaded.roast, original.roast,
                                  "Iteration \(iteration): Team \(index) roast should match")
                    
                    // Verify top players
                    XCTAssertEqual(loaded.topPlayers.count, original.topPlayers.count,
                                  "Iteration \(iteration): Team \(index) should have same number of players")
                    
                    for (playerIndex, originalPlayer) in original.topPlayers.enumerated() {
                        let loadedPlayer = loaded.topPlayers[playerIndex]
                        XCTAssertEqual(loadedPlayer.id, originalPlayer.id,
                                      "Iteration \(iteration): Team \(index) player \(playerIndex) id should match")
                        XCTAssertEqual(loadedPlayer.name, originalPlayer.name,
                                      "Iteration \(iteration): Team \(index) player \(playerIndex) name should match")
                        XCTAssertEqual(loadedPlayer.position, originalPlayer.position,
                                      "Iteration \(iteration): Team \(index) player \(playerIndex) position should match")
                        XCTAssertEqual(loadedPlayer.points, originalPlayer.points, accuracy: 0.01,
                                      "Iteration \(iteration): Team \(index) player \(playerIndex) points should match")
                    }
                }
                
                // Clean up
                try storageService.clearDataForLeague(leagueId: leagueId)
            } catch {
                XCTFail("Iteration \(iteration): Round-trip failed with error: \(error)")
            }
        }
    }
    
    /// Property test verifying empty data structures persist correctly
    /// Runs 100+ iterations with empty or minimal data
    func testEmptyDataRoundTrip() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let leagueId = "league_\(UUID().uuidString)"
            
            do {
                // Test empty league connections
                try storageService.saveLeagueConnections([])
                let loadedConnections = try storageService.loadLeagueConnections()
                XCTAssertEqual(loadedConnections.count, 0,
                              "Iteration \(iteration): Empty connections should load as empty")
                
                // Test empty league context
                let emptyContext = LeagueContext.empty
                try storageService.saveLeagueContext(emptyContext, forLeagueId: leagueId)
                guard let loadedContext = try storageService.loadLeagueContext(forLeagueId: leagueId) else {
                    XCTFail("Iteration \(iteration): Failed to load empty context")
                    continue
                }
                XCTAssertEqual(loadedContext.insideJokes.count, 0,
                              "Iteration \(iteration): Empty inside jokes should persist")
                XCTAssertEqual(loadedContext.personalities.count, 0,
                              "Iteration \(iteration): Empty personalities should persist")
                XCTAssertEqual(loadedContext.sackoPunishment, "",
                              "Iteration \(iteration): Empty sacko should persist")
                XCTAssertEqual(loadedContext.cultureNotes, "",
                              "Iteration \(iteration): Empty culture notes should persist")
                
                // Test empty team array
                try storageService.saveCachedLeagueData([], forLeagueId: leagueId, roastHash: nil)
                guard let (loadedTeams, _, _) = try storageService.loadCachedLeagueData(forLeagueId: leagueId) else {
                    XCTFail("Iteration \(iteration): Failed to load empty teams")
                    continue
                }
                XCTAssertEqual(loadedTeams.count, 0,
                              "Iteration \(iteration): Empty teams should persist")
                
                // Clean up
                try storageService.clearDataForLeague(leagueId: leagueId)
            } catch {
                XCTFail("Iteration \(iteration): Empty data round-trip failed with error: \(error)")
            }
        }
    }
    
    /// Property test verifying data with special characters persists correctly
    /// Runs 100+ iterations with strings containing special characters
    func testSpecialCharactersRoundTrip() {
        let iterations = 100
        let specialCharacters = ["emoji 🏈", "quotes \"test\"", "newlines\n\ntest", "unicode 日本語", "symbols @#$%"]
        
        for iteration in 0..<iterations {
            let leagueId = "league_\(UUID().uuidString)"
            
            // Create context with special characters
            let context = LeagueContext(
                insideJokes: [
                    LeagueContext.InsideJoke(
                        id: UUID(),
                        term: specialCharacters.randomElement()!,
                        explanation: specialCharacters.randomElement()!
                    )
                ],
                personalities: [
                    LeagueContext.PlayerPersonality(
                        id: UUID(),
                        playerName: specialCharacters.randomElement()!,
                        description: specialCharacters.randomElement()!
                    )
                ],
                sackoPunishment: specialCharacters.randomElement()!,
                cultureNotes: specialCharacters.randomElement()!
            )
            
            do {
                // Save and load
                try storageService.saveLeagueContext(context, forLeagueId: leagueId)
                guard let loaded = try storageService.loadLeagueContext(forLeagueId: leagueId) else {
                    XCTFail("Iteration \(iteration): Failed to load context with special characters")
                    continue
                }
                
                // Verify special characters preserved
                XCTAssertEqual(loaded.insideJokes[0].term, context.insideJokes[0].term,
                              "Iteration \(iteration): Special characters in term should persist")
                XCTAssertEqual(loaded.personalities[0].playerName, context.personalities[0].playerName,
                              "Iteration \(iteration): Special characters in player name should persist")
                XCTAssertEqual(loaded.sackoPunishment, context.sackoPunishment,
                              "Iteration \(iteration): Special characters in sacko should persist")
                
                // Clean up
                try storageService.clearDataForLeague(leagueId: leagueId)
            } catch {
                XCTFail("Iteration \(iteration): Special characters round-trip failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Property 11: League Connection Isolation
    
    /// Property test verifying that saving context or cached data for one league does not affect another league
    /// **Validates: Requirements 5.8**
    /// Runs 100+ iterations with varied league IDs and data
    func testLeagueConnectionIsolation() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate two different league IDs
            let leagueIdA = "league_A_\(UUID().uuidString)"
            let leagueIdB = "league_B_\(UUID().uuidString)"
            
            // Generate different contexts for each league
            let contextA = generateRandomLeagueContext()
            let contextB = generateRandomLeagueContext()
            
            // Generate different cached data for each league
            let teamsA = generateRandomTeams(count: Int.random(in: 5...15))
            let teamsB = generateRandomTeams(count: Int.random(in: 5...15))
            
            do {
                // Save context for both leagues
                try storageService.saveLeagueContext(contextA, forLeagueId: leagueIdA)
                try storageService.saveLeagueContext(contextB, forLeagueId: leagueIdB)
                
                // Save cached data for both leagues
                try storageService.saveCachedLeagueData(teamsA, forLeagueId: leagueIdA, roastHash: nil)
                try storageService.saveCachedLeagueData(teamsB, forLeagueId: leagueIdB, roastHash: nil)
                
                // Load context for league A and verify it matches original A data
                guard let loadedContextA = try storageService.loadLeagueContext(forLeagueId: leagueIdA) else {
                    XCTFail("Iteration \(iteration): Failed to load context for league A")
                    continue
                }
                
                // Verify league A context matches original
                XCTAssertEqual(loadedContextA.insideJokes.count, contextA.insideJokes.count,
                              "Iteration \(iteration): League A inside jokes count should match")
                XCTAssertEqual(loadedContextA.personalities.count, contextA.personalities.count,
                              "Iteration \(iteration): League A personalities count should match")
                XCTAssertEqual(loadedContextA.sackoPunishment, contextA.sackoPunishment,
                              "Iteration \(iteration): League A sacko should match")
                XCTAssertEqual(loadedContextA.cultureNotes, contextA.cultureNotes,
                              "Iteration \(iteration): League A culture notes should match")
                
                // Verify league A context does NOT match league B data
                if contextA.sackoPunishment != contextB.sackoPunishment {
                    XCTAssertNotEqual(loadedContextA.sackoPunishment, contextB.sackoPunishment,
                                     "Iteration \(iteration): League A should not have league B's sacko")
                }
                if contextA.cultureNotes != contextB.cultureNotes {
                    XCTAssertNotEqual(loadedContextA.cultureNotes, contextB.cultureNotes,
                                     "Iteration \(iteration): League A should not have league B's culture notes")
                }
                
                // Load context for league B and verify it matches original B data
                guard let loadedContextB = try storageService.loadLeagueContext(forLeagueId: leagueIdB) else {
                    XCTFail("Iteration \(iteration): Failed to load context for league B")
                    continue
                }
                
                // Verify league B context matches original
                XCTAssertEqual(loadedContextB.insideJokes.count, contextB.insideJokes.count,
                              "Iteration \(iteration): League B inside jokes count should match")
                XCTAssertEqual(loadedContextB.personalities.count, contextB.personalities.count,
                              "Iteration \(iteration): League B personalities count should match")
                XCTAssertEqual(loadedContextB.sackoPunishment, contextB.sackoPunishment,
                              "Iteration \(iteration): League B sacko should match")
                XCTAssertEqual(loadedContextB.cultureNotes, contextB.cultureNotes,
                              "Iteration \(iteration): League B culture notes should match")
                
                // Verify league B context does NOT match league A data
                if contextB.sackoPunishment != contextA.sackoPunishment {
                    XCTAssertNotEqual(loadedContextB.sackoPunishment, contextA.sackoPunishment,
                                     "Iteration \(iteration): League B should not have league A's sacko")
                }
                if contextB.cultureNotes != contextA.cultureNotes {
                    XCTAssertNotEqual(loadedContextB.cultureNotes, contextA.cultureNotes,
                                     "Iteration \(iteration): League B should not have league A's culture notes")
                }
                
                // Load cached data for league A and verify it matches original A data
                guard let (loadedTeamsA, _, _) = try storageService.loadCachedLeagueData(forLeagueId: leagueIdA) else {
                    XCTFail("Iteration \(iteration): Failed to load cached data for league A")
                    continue
                }
                
                // Verify league A cached data matches original
                XCTAssertEqual(loadedTeamsA.count, teamsA.count,
                              "Iteration \(iteration): League A should have correct team count")
                XCTAssertEqual(loadedTeamsA.map { $0.id }, teamsA.map { $0.id },
                              "Iteration \(iteration): League A should have correct team IDs")
                
                // Verify league A cached data does NOT match league B data (isolation check)
                XCTAssertNotEqual(loadedTeamsA.map { $0.id }, teamsB.map { $0.id },
                                 "Iteration \(iteration): League A should not have league B's team IDs")
                
                // Load cached data for league B and verify it matches original B data
                guard let (loadedTeamsB, _, _) = try storageService.loadCachedLeagueData(forLeagueId: leagueIdB) else {
                    XCTFail("Iteration \(iteration): Failed to load cached data for league B")
                    continue
                }
                
                // Verify league B cached data matches original
                XCTAssertEqual(loadedTeamsB.count, teamsB.count,
                              "Iteration \(iteration): League B should have correct team count")
                XCTAssertEqual(loadedTeamsB.map { $0.id }, teamsB.map { $0.id },
                              "Iteration \(iteration): League B should have correct team IDs")
                
                // Verify league B cached data does NOT match league A data (isolation check)
                XCTAssertNotEqual(loadedTeamsB.map { $0.id }, teamsA.map { $0.id },
                                 "Iteration \(iteration): League B should not have league A's team IDs")
                
                // Clean up both leagues
                try storageService.clearDataForLeague(leagueId: leagueIdA)
                try storageService.clearDataForLeague(leagueId: leagueIdB)
                
            } catch {
                XCTFail("Iteration \(iteration): League isolation test failed with error: \(error)")
            }
        }
    }
    
    /// Property test verifying that modifying one league's data does not affect another league
    /// Runs 100+ iterations with sequential modifications
    func testLeagueIsolationWithModifications() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let leagueIdA = "league_A_\(UUID().uuidString)"
            let leagueIdB = "league_B_\(UUID().uuidString)"
            
            do {
                // Save initial data for both leagues
                let initialContextA = generateRandomLeagueContext()
                let initialContextB = generateRandomLeagueContext()
                
                try storageService.saveLeagueContext(initialContextA, forLeagueId: leagueIdA)
                try storageService.saveLeagueContext(initialContextB, forLeagueId: leagueIdB)
                
                // Modify league A's context
                let modifiedContextA = generateRandomLeagueContext()
                try storageService.saveLeagueContext(modifiedContextA, forLeagueId: leagueIdA)
                
                // Verify league B's context is unchanged
                guard let loadedContextB = try storageService.loadLeagueContext(forLeagueId: leagueIdB) else {
                    XCTFail("Iteration \(iteration): Failed to load context for league B after modifying A")
                    continue
                }
                
                XCTAssertEqual(loadedContextB.insideJokes.count, initialContextB.insideJokes.count,
                              "Iteration \(iteration): League B context should be unchanged after modifying A")
                XCTAssertEqual(loadedContextB.sackoPunishment, initialContextB.sackoPunishment,
                              "Iteration \(iteration): League B sacko should be unchanged after modifying A")
                
                // Verify league A has the modified context
                guard let loadedContextA = try storageService.loadLeagueContext(forLeagueId: leagueIdA) else {
                    XCTFail("Iteration \(iteration): Failed to load modified context for league A")
                    continue
                }
                
                XCTAssertEqual(loadedContextA.insideJokes.count, modifiedContextA.insideJokes.count,
                              "Iteration \(iteration): League A should have modified context")
                XCTAssertEqual(loadedContextA.sackoPunishment, modifiedContextA.sackoPunishment,
                              "Iteration \(iteration): League A should have modified sacko")
                
                // Clean up
                try storageService.clearDataForLeague(leagueId: leagueIdA)
                try storageService.clearDataForLeague(leagueId: leagueIdB)
                
            } catch {
                XCTFail("Iteration \(iteration): League isolation with modifications failed with error: \(error)")
            }
        }
    }
    
    /// Property test verifying that deleting one league's data does not affect another league
    /// Runs 100+ iterations with deletion operations
    func testLeagueIsolationWithDeletion() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let leagueIdA = "league_A_\(UUID().uuidString)"
            let leagueIdB = "league_B_\(UUID().uuidString)"
            
            do {
                // Save data for both leagues
                let contextA = generateRandomLeagueContext()
                let contextB = generateRandomLeagueContext()
                let teamsA = generateRandomTeams(count: Int.random(in: 3...10))
                let teamsB = generateRandomTeams(count: Int.random(in: 3...10))
                
                try storageService.saveLeagueContext(contextA, forLeagueId: leagueIdA)
                try storageService.saveLeagueContext(contextB, forLeagueId: leagueIdB)
                try storageService.saveCachedLeagueData(teamsA, forLeagueId: leagueIdA, roastHash: nil)
                try storageService.saveCachedLeagueData(teamsB, forLeagueId: leagueIdB, roastHash: nil)
                
                // Delete league A's data
                try storageService.clearDataForLeague(leagueId: leagueIdA)
                
                // Verify league A's data is deleted
                let deletedContextA = try storageService.loadLeagueContext(forLeagueId: leagueIdA)
                XCTAssertNil(deletedContextA,
                            "Iteration \(iteration): League A context should be deleted")
                
                let deletedTeamsA = try storageService.loadCachedLeagueData(forLeagueId: leagueIdA)
                XCTAssertNil(deletedTeamsA,
                            "Iteration \(iteration): League A cached data should be deleted")
                
                // Verify league B's data still exists and is unchanged
                guard let loadedContextB = try storageService.loadLeagueContext(forLeagueId: leagueIdB) else {
                    XCTFail("Iteration \(iteration): League B context should still exist after deleting A")
                    continue
                }
                
                XCTAssertEqual(loadedContextB.insideJokes.count, contextB.insideJokes.count,
                              "Iteration \(iteration): League B context should be unchanged after deleting A")
                XCTAssertEqual(loadedContextB.sackoPunishment, contextB.sackoPunishment,
                              "Iteration \(iteration): League B sacko should be unchanged after deleting A")
                
                guard let (loadedTeamsB, _, _) = try storageService.loadCachedLeagueData(forLeagueId: leagueIdB) else {
                    XCTFail("Iteration \(iteration): League B cached data should still exist after deleting A")
                    continue
                }
                
                XCTAssertEqual(loadedTeamsB.count, teamsB.count,
                              "Iteration \(iteration): League B teams should be unchanged after deleting A")
                
                // Clean up league B
                try storageService.clearDataForLeague(leagueId: leagueIdB)
                
            } catch {
                XCTFail("Iteration \(iteration): League isolation with deletion failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates random league connections for testing
    private func generateRandomLeagueConnections(count: Int) -> [LeagueConnection] {
        var connections: [LeagueConnection] = []
        
        for i in 0..<count {
            let platform: League.Platform = Bool.random() ? .espn : .sleeper
            let connection = LeagueConnection(
                id: UUID().uuidString,
                leagueId: "league_\(i)_\(UUID().uuidString)",
                platform: platform,
                leagueName: "League \(i) \(randomString(length: 10))",
                lastUpdated: Date().addingTimeInterval(Double.random(in: -86400...0)),
                hasAuthentication: Bool.random()
            )
            connections.append(connection)
        }
        
        return connections
    }
    
    /// Generates random league context for testing
    private func generateRandomLeagueContext() -> LeagueContext {
        let jokeCount = Int.random(in: 0...5)
        let personalityCount = Int.random(in: 0...5)
        
        var insideJokes: [LeagueContext.InsideJoke] = []
        for _ in 0..<jokeCount {
            insideJokes.append(LeagueContext.InsideJoke(
                id: UUID(),
                term: randomString(length: Int.random(in: 5...20)),
                explanation: randomString(length: Int.random(in: 10...50))
            ))
        }
        
        var personalities: [LeagueContext.PlayerPersonality] = []
        for _ in 0..<personalityCount {
            personalities.append(LeagueContext.PlayerPersonality(
                id: UUID(),
                playerName: randomString(length: Int.random(in: 5...20)),
                description: randomString(length: Int.random(in: 10...50))
            ))
        }
        
        return LeagueContext(
            insideJokes: insideJokes,
            personalities: personalities,
            sackoPunishment: randomString(length: Int.random(in: 0...100)),
            cultureNotes: randomString(length: Int.random(in: 0...200))
        )
    }
    
    /// Generates random teams for testing
    private func generateRandomTeams(count: Int) -> [Team] {
        var teams: [Team] = []
        
        for i in 0..<count {
            let playerCount = Int.random(in: 0...5)
            var players: [Player] = []
            
            for j in 0..<playerCount {
                players.append(Player(
                    id: "player_\(i)_\(j)",
                    name: randomString(length: Int.random(in: 5...15)),
                    position: ["QB", "RB", "WR", "TE", "K", "DEF"].randomElement()!,
                    points: Double.random(in: 0...50)
                ))
            }
            
            let team = Team(
                id: "team_\(UUID().uuidString)",
                name: randomString(length: Int.random(in: 5...20)),
                ownerName: randomString(length: Int.random(in: 5...15)),
                wins: Int.random(in: 0...15),
                losses: Int.random(in: 0...15),
                ties: Int.random(in: 0...3),
                pointsFor: Double.random(in: 500...2000),
                pointsAgainst: Double.random(in: 500...2000),
                powerScore: Double.random(in: 0...1),
                rank: i + 1,
                streak: Team.Streak(
                    type: Bool.random() ? .win : .loss,
                    length: Int.random(in: 1...10)
                ),
                topPlayers: players,
                roast: Bool.random() ? randomString(length: Int.random(in: 50...200)) : nil
            )
            
            teams.append(team)
        }
        
        return teams
    }
    
    /// Generates a random string of specified length
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
