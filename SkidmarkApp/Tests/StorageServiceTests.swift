import XCTest
@testable import SkidmarkApp

final class StorageServiceTests: XCTestCase {
    var storageService: DefaultStorageService!
    var testUserDefaults: UserDefaults!
    var testFileManager: FileManager!
    
    override func setUp() {
        super.setUp()
        
        // Use a test suite name to isolate test data
        testUserDefaults = UserDefaults(suiteName: "test.skidmark.storage")!
        testFileManager = FileManager.default
        
        storageService = DefaultStorageService(
            userDefaults: testUserDefaults,
            fileManager: testFileManager
        )
    }
    
    override func tearDown() {
        // Clean up test data
        testUserDefaults.removePersistentDomain(forName: "test.skidmark.storage")
        
        // Clean up any test files
        let documentsDirectory = testFileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testFiles = try? testFileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
        testFiles?.forEach { url in
            if url.lastPathComponent.hasPrefix("league_") {
                try? testFileManager.removeItem(at: url)
            }
        }
        
        super.tearDown()
    }
    
    // MARK: - League Connections Tests
    
    func testSaveAndLoadLeagueConnections() throws {
        let connections = [
            LeagueConnection(
                id: "1",
                leagueId: "123",
                platform: .espn,
                leagueName: "Test League",
                lastUpdated: Date(),
                hasAuthentication: true
            ),
            LeagueConnection(
                id: "2",
                leagueId: "456",
                platform: .sleeper,
                leagueName: "Another League",
                lastUpdated: Date(),
                hasAuthentication: false
            )
        ]
        
        try storageService.saveLeagueConnections(connections)
        let loaded = try storageService.loadLeagueConnections()
        
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, "1")
        XCTAssertEqual(loaded[0].leagueId, "123")
        XCTAssertEqual(loaded[0].platform, .espn)
        XCTAssertEqual(loaded[1].id, "2")
        XCTAssertEqual(loaded[1].platform, .sleeper)
    }
    
    func testLoadLeagueConnectionsWhenEmpty() throws {
        let loaded = try storageService.loadLeagueConnections()
        XCTAssertEqual(loaded.count, 0)
    }
    
    func testOverwriteLeagueConnections() throws {
        let firstConnections = [
            LeagueConnection(
                id: "1",
                leagueId: "123",
                platform: .espn,
                leagueName: "First",
                lastUpdated: Date(),
                hasAuthentication: true
            )
        ]
        
        try storageService.saveLeagueConnections(firstConnections)
        
        let secondConnections = [
            LeagueConnection(
                id: "2",
                leagueId: "456",
                platform: .sleeper,
                leagueName: "Second",
                lastUpdated: Date(),
                hasAuthentication: false
            )
        ]
        
        try storageService.saveLeagueConnections(secondConnections)
        let loaded = try storageService.loadLeagueConnections()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "2")
    }
    
    // MARK: - League Context Tests
    
    func testSaveAndLoadLeagueContext() throws {
        let context = LeagueContext(
            insideJokes: [
                LeagueContext.InsideJoke(id: UUID(), term: "Taco", explanation: "Last place punishment")
            ],
            personalities: [
                LeagueContext.PlayerPersonality(id: UUID(), playerName: "John", description: "Always trades")
            ],
            sackoPunishment: "Wear a costume",
            cultureNotes: "Very competitive league"
        )
        
        try storageService.saveLeagueContext(context, forLeagueId: "test123")
        let loaded = try storageService.loadLeagueContext(forLeagueId: "test123")
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.insideJokes.count, 1)
        XCTAssertEqual(loaded?.insideJokes[0].term, "Taco")
        XCTAssertEqual(loaded?.personalities.count, 1)
        XCTAssertEqual(loaded?.personalities[0].playerName, "John")
        XCTAssertEqual(loaded?.sackoPunishment, "Wear a costume")
        XCTAssertEqual(loaded?.cultureNotes, "Very competitive league")
    }
    
    func testLoadLeagueContextWhenNotExists() throws {
        let loaded = try storageService.loadLeagueContext(forLeagueId: "nonexistent")
        XCTAssertNil(loaded)
    }
    
    func testLeagueContextIsolation() throws {
        let context1 = LeagueContext(
            insideJokes: [
                LeagueContext.InsideJoke(id: UUID(), term: "League1", explanation: "First league")
            ],
            personalities: [],
            sackoPunishment: "Punishment 1",
            cultureNotes: "Notes 1"
        )
        
        let context2 = LeagueContext(
            insideJokes: [
                LeagueContext.InsideJoke(id: UUID(), term: "League2", explanation: "Second league")
            ],
            personalities: [],
            sackoPunishment: "Punishment 2",
            cultureNotes: "Notes 2"
        )
        
        try storageService.saveLeagueContext(context1, forLeagueId: "league1")
        try storageService.saveLeagueContext(context2, forLeagueId: "league2")
        
        let loaded1 = try storageService.loadLeagueContext(forLeagueId: "league1")
        let loaded2 = try storageService.loadLeagueContext(forLeagueId: "league2")
        
        XCTAssertEqual(loaded1?.insideJokes[0].term, "League1")
        XCTAssertEqual(loaded2?.insideJokes[0].term, "League2")
    }
    
    // MARK: - Cached League Data Tests
    
    func testSaveAndLoadCachedLeagueData() throws {
        let teams = [
            Team(
                id: "1",
                name: "Team A",
                ownerName: "Owner A",
                wins: 5,
                losses: 3,
                ties: 0,
                pointsFor: 1200.5,
                pointsAgainst: 1100.0,
                powerScore: 0.75,
                rank: 1,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [],
                roast: nil
            )
        ]
        
        try storageService.saveCachedLeagueData(teams, forLeagueId: "test123", roastHash: nil)
        let loaded = try storageService.loadCachedLeagueData(forLeagueId: "test123")
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.0.count, 1)
        XCTAssertEqual(loaded?.0[0].name, "Team A")
        XCTAssertEqual(loaded?.0[0].wins, 5)
        XCTAssertNotNil(loaded?.1)
    }
    
    func testLoadCachedLeagueDataWhenNotExists() throws {
        let loaded = try storageService.loadCachedLeagueData(forLeagueId: "nonexistent")
        XCTAssertNil(loaded)
    }
    
    func testCachedDataTimestamp() throws {
        let teams = [
            Team(
                id: "1",
                name: "Team A",
                ownerName: "Owner A",
                wins: 5,
                losses: 3,
                ties: 0,
                pointsFor: 1200.5,
                pointsAgainst: 1100.0,
                powerScore: 0.75,
                rank: 1,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [],
                roast: nil
            )
        ]
        
        let beforeSave = Date()
        try storageService.saveCachedLeagueData(teams, forLeagueId: "test123", roastHash: nil)
        
        let loaded = try storageService.loadCachedLeagueData(forLeagueId: "test123")
        
        XCTAssertNotNil(loaded?.1)
        // Verify timestamp is recent (within 2 seconds of beforeSave)
        let timeDifference = abs(loaded!.1.timeIntervalSince(beforeSave))
        XCTAssertLessThan(timeDifference, 2.0, "Timestamp should be within 2 seconds of save time")
    }
    
    // MARK: - Data Cleanup Tests
    
    func testClearDataForLeague() throws {
        let context = LeagueContext.empty
        let teams = [
            Team(
                id: "1",
                name: "Team A",
                ownerName: "Owner A",
                wins: 5,
                losses: 3,
                ties: 0,
                pointsFor: 1200.5,
                pointsAgainst: 1100.0,
                powerScore: 0.75,
                rank: 1,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [],
                roast: nil
            )
        ]
        
        try storageService.saveLeagueContext(context, forLeagueId: "test123")
        try storageService.saveCachedLeagueData(teams, forLeagueId: "test123", roastHash: nil)
        
        // Verify data exists
        XCTAssertNotNil(try storageService.loadLeagueContext(forLeagueId: "test123"))
        XCTAssertNotNil(try storageService.loadCachedLeagueData(forLeagueId: "test123"))
        
        // Clear data
        try storageService.clearDataForLeague(leagueId: "test123")
        
        // Verify data is gone
        XCTAssertNil(try storageService.loadLeagueContext(forLeagueId: "test123"))
        XCTAssertNil(try storageService.loadCachedLeagueData(forLeagueId: "test123"))
    }
    
    func testClearDataForLeagueWhenNoDataExists() throws {
        // Should not throw error when clearing non-existent data
        XCTAssertNoThrow(try storageService.clearDataForLeague(leagueId: "nonexistent"))
    }
    
    func testClearDataDoesNotAffectOtherLeagues() throws {
        let context1 = LeagueContext.empty
        let context2 = LeagueContext.empty
        
        try storageService.saveLeagueContext(context1, forLeagueId: "league1")
        try storageService.saveLeagueContext(context2, forLeagueId: "league2")
        
        try storageService.clearDataForLeague(leagueId: "league1")
        
        XCTAssertNil(try storageService.loadLeagueContext(forLeagueId: "league1"))
        XCTAssertNotNil(try storageService.loadLeagueContext(forLeagueId: "league2"))
    }
}
