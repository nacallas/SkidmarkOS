import XCTest
@testable import SkidmarkApp

/// Property-based tests for multiple league support and data management
/// **Validates: Requirements 5.8, 10.2, 10.5**
final class MultiLeaguePropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 12: Multiple League Support
    
    /// Property test verifying storage and retrieval of 1 to N leagues
    /// **Validates: Requirements 5.8, 10.2**
    /// Runs 100+ iterations with varying league counts
    func testMultipleLeagueSupport() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate 1 to N league connections
            let leagueCount = Int.random(in: 1...20)
            let connections = generateRandomLeagueConnections(count: leagueCount)
            
            do {
                // Save all league connections
                try storageService.saveLeagueConnections(connections)
                
                // Load league connections
                let loadedConnections = try storageService.loadLeagueConnections()
                
                // Verify count matches
                XCTAssertEqual(loadedConnections.count, leagueCount,
                              "Iteration \(iteration): Should store and load \(leagueCount) leagues")
                
                // Verify all league IDs are present
                let originalIds = Set(connections.map { $0.id })
                let loadedIds = Set(loadedConnections.map { $0.id })
                XCTAssertEqual(loadedIds, originalIds,
                              "Iteration \(iteration): All league IDs should be preserved")
                
                // Save context and cached data for each league
                for connection in connections {
                    let context = generateRandomLeagueContext()
                    let teams = generateRandomTeams(count: Int.random(in: 4...12))
                    
                    try storageService.saveLeagueContext(context, forLeagueId: connection.leagueId)
                    try storageService.saveCachedLeagueData(teams, forLeagueId: connection.leagueId, roastHash: nil)
                }
                
                // Verify each league's data can be loaded independently
                for connection in connections {
                    let loadedContext = try storageService.loadLeagueContext(forLeagueId: connection.leagueId)
                    XCTAssertNotNil(loadedContext,
                                   "Iteration \(iteration): Context for league \(connection.leagueId) should be loadable")
                    
                    let loadedCache = try storageService.loadCachedLeagueData(forLeagueId: connection.leagueId)
                    XCTAssertNotNil(loadedCache,
                                   "Iteration \(iteration): Cache for league \(connection.leagueId) should be loadable")
                }
                
                // Clean up all leagues
                for connection in connections {
                    try storageService.clearDataForLeague(leagueId: connection.leagueId)
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Multiple league support test failed with error: \(error)")
            }
        }
    }
    
    /// Property test verifying league data isolation with concurrent operations
    /// Runs 100+ iterations with multiple leagues being modified simultaneously
    func testMultipleLeagueIsolation() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let leagueCount = Int.random(in: 2...10)
            var leagueData: [(id: String, context: LeagueContext, teams: [Team])] = []
            
            do {
                // Create data for multiple leagues
                for i in 0..<leagueCount {
                    let leagueId = "league_\(i)_\(UUID().uuidString)"
                    let context = generateRandomLeagueContext()
                    let teams = generateRandomTeams(count: Int.random(in: 5...10))
                    leagueData.append((leagueId, context, teams))
                    
                    // Save data
                    try storageService.saveLeagueContext(context, forLeagueId: leagueId)
                    try storageService.saveCachedLeagueData(teams, forLeagueId: leagueId, roastHash: nil)
                }
                
                // Verify each league's data is isolated
                for (index, data) in leagueData.enumerated() {
                    guard let loadedContext = try storageService.loadLeagueContext(forLeagueId: data.id) else {
                        XCTFail("Iteration \(iteration): Failed to load context for league \(index)")
                        continue
                    }
                    
                    guard let (loadedTeams, _, _) = try storageService.loadCachedLeagueData(forLeagueId: data.id) else {
                        XCTFail("Iteration \(iteration): Failed to load teams for league \(index)")
                        continue
                    }
                    
                    // Verify data matches original
                    XCTAssertEqual(loadedContext.insideJokes.count, data.context.insideJokes.count,
                                  "Iteration \(iteration): League \(index) context should match")
                    XCTAssertEqual(loadedTeams.count, data.teams.count,
                                  "Iteration \(iteration): League \(index) teams should match")
                    
                    // Verify data doesn't match other leagues
                    for (otherIndex, otherData) in leagueData.enumerated() where otherIndex != index {
                        if data.teams.count != otherData.teams.count {
                            XCTAssertNotEqual(loadedTeams.count, otherData.teams.count,
                                            "Iteration \(iteration): League \(index) should not have league \(otherIndex)'s team count")
                        }
                    }
                }
                
                // Clean up
                for data in leagueData {
                    try storageService.clearDataForLeague(leagueId: data.id)
                }
                
            } catch {
                XCTFail("Iteration \(iteration): League isolation test failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Property 13: League Removal Cleanup
    
    /// Property test verifying complete data deletion when removing a league
    /// **Validates: Requirements 10.5**
    /// Runs 100+ iterations verifying all associated data is deleted
    func testLeagueRemovalCleanup() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let leagueId = "league_\(UUID().uuidString)"
            
            do {
                // Create comprehensive league data
                let context = generateRandomLeagueContext()
                let teams = generateRandomTeams(count: Int.random(in: 5...15))
                let roastHash = Int.random(in: 1000...9999)
                
                // Save all data types
                try storageService.saveLeagueContext(context, forLeagueId: leagueId)
                try storageService.saveCachedLeagueData(teams, forLeagueId: leagueId, roastHash: roastHash)
                
                // Verify data exists before deletion
                let contextBeforeDelete = try storageService.loadLeagueContext(forLeagueId: leagueId)
                XCTAssertNotNil(contextBeforeDelete,
                               "Iteration \(iteration): Context should exist before deletion")
                
                let cacheBeforeDelete = try storageService.loadCachedLeagueData(forLeagueId: leagueId)
                XCTAssertNotNil(cacheBeforeDelete,
                               "Iteration \(iteration): Cache should exist before deletion")
                
                // Delete league data
                try storageService.clearDataForLeague(leagueId: leagueId)
                
                // Verify all data is deleted
                let contextAfterDelete = try storageService.loadLeagueContext(forLeagueId: leagueId)
                XCTAssertNil(contextAfterDelete,
                            "Iteration \(iteration): Context should be deleted")
                
                let cacheAfterDelete = try storageService.loadCachedLeagueData(forLeagueId: leagueId)
                XCTAssertNil(cacheAfterDelete,
                            "Iteration \(iteration): Cache should be deleted")
                
                // Verify cache age returns nil (no cache exists)
                let cacheAge = storageService.getCacheAge(forLeagueId: leagueId)
                XCTAssertNil(cacheAge,
                            "Iteration \(iteration): Cache age should be nil after deletion")
                
                // Verify cache is considered stale (no cache exists)
                let isStale = storageService.isCacheStale(forLeagueId: leagueId)
                XCTAssertTrue(isStale,
                             "Iteration \(iteration): Deleted cache should be considered stale")
                
            } catch {
                XCTFail("Iteration \(iteration): League removal cleanup test failed with error: \(error)")
            }
        }
    }
    
    /// Property test verifying deletion of one league doesn't affect others
    /// Runs 100+ iterations with multiple leagues
    func testLeagueRemovalIsolation() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let leagueIdToDelete = "league_delete_\(UUID().uuidString)"
            let leagueIdToKeep = "league_keep_\(UUID().uuidString)"
            
            do {
                // Create data for both leagues
                let contextToDelete = generateRandomLeagueContext()
                let contextToKeep = generateRandomLeagueContext()
                let teamsToDelete = generateRandomTeams(count: Int.random(in: 5...10))
                let teamsToKeep = generateRandomTeams(count: Int.random(in: 5...10))
                
                // Save both leagues
                try storageService.saveLeagueContext(contextToDelete, forLeagueId: leagueIdToDelete)
                try storageService.saveLeagueContext(contextToKeep, forLeagueId: leagueIdToKeep)
                try storageService.saveCachedLeagueData(teamsToDelete, forLeagueId: leagueIdToDelete, roastHash: nil)
                try storageService.saveCachedLeagueData(teamsToKeep, forLeagueId: leagueIdToKeep, roastHash: nil)
                
                // Delete one league
                try storageService.clearDataForLeague(leagueId: leagueIdToDelete)
                
                // Verify deleted league is gone
                let deletedContext = try storageService.loadLeagueContext(forLeagueId: leagueIdToDelete)
                XCTAssertNil(deletedContext,
                            "Iteration \(iteration): Deleted league context should be nil")
                
                let deletedCache = try storageService.loadCachedLeagueData(forLeagueId: leagueIdToDelete)
                XCTAssertNil(deletedCache,
                            "Iteration \(iteration): Deleted league cache should be nil")
                
                // Verify kept league still exists
                guard let keptContext = try storageService.loadLeagueContext(forLeagueId: leagueIdToKeep) else {
                    XCTFail("Iteration \(iteration): Kept league context should still exist")
                    continue
                }
                
                guard let (keptTeams, _, _) = try storageService.loadCachedLeagueData(forLeagueId: leagueIdToKeep) else {
                    XCTFail("Iteration \(iteration): Kept league cache should still exist")
                    continue
                }
                
                // Verify kept league data is unchanged
                XCTAssertEqual(keptContext.insideJokes.count, contextToKeep.insideJokes.count,
                              "Iteration \(iteration): Kept league context should be unchanged")
                XCTAssertEqual(keptTeams.count, teamsToKeep.count,
                              "Iteration \(iteration): Kept league teams should be unchanged")
                
                // Clean up
                try storageService.clearDataForLeague(leagueId: leagueIdToKeep)
                
            } catch {
                XCTFail("Iteration \(iteration): League removal isolation test failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomLeagueConnections(count: Int) -> [LeagueConnection] {
        var connections: [LeagueConnection] = []
        
        for i in 0..<count {
            let platform: League.Platform = Bool.random() ? .espn : .sleeper
            let connection = LeagueConnection(
                id: UUID().uuidString,
                leagueId: "league_\(i)_\(UUID().uuidString)",
                platform: platform,
                leagueName: "League \(i)",
                lastUpdated: Date().addingTimeInterval(Double.random(in: -86400...0)),
                hasAuthentication: Bool.random()
            )
            connections.append(connection)
        }
        
        return connections
    }
    
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
    
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
