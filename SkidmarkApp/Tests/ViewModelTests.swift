import XCTest
@testable import SkidmarkApp

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Unit tests for view models
@MainActor
final class ViewModelTests: XCTestCase {
    
    // MARK: - LeagueListViewModel Tests
    
    func testLeagueListViewModel_FetchLeagues_Success() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        
        // Setup mock data
        let connection = LeagueConnection(
            id: "1",
            leagueId: "123",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        mockStorage.leagueConnections = [connection]
        
        // Execute
        viewModel.fetchLeagues()
        
        // Verify
        XCTAssertEqual(viewModel.leagues.count, 1)
        XCTAssertEqual(viewModel.leagues.first?.leagueName, "Test League")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLeagueListViewModel_AddLeague_Success() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        
        let connection = LeagueConnection(
            id: "1",
            leagueId: "123",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        // Execute
        viewModel.addLeague(connection)
        
        // Verify
        XCTAssertEqual(viewModel.leagues.count, 1)
        XCTAssertEqual(mockStorage.savedConnections?.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLeagueListViewModel_AddLeague_Duplicate() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        
        let connection = LeagueConnection(
            id: "1",
            leagueId: "123",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        // Add first time
        viewModel.addLeague(connection)
        
        // Try to add duplicate
        viewModel.addLeague(connection)
        
        // Verify
        XCTAssertEqual(viewModel.leagues.count, 1)
        XCTAssertEqual(viewModel.errorMessage, "This league is already connected")
    }
    
    func testLeagueListViewModel_RemoveLeague_Success() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        
        let connection = LeagueConnection(
            id: "1",
            leagueId: "123",
            platform: .espn,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: true
        )
        
        viewModel.addLeague(connection)
        XCTAssertEqual(viewModel.leagues.count, 1)
        
        // Execute
        viewModel.removeLeague(connection)
        
        // Verify
        XCTAssertEqual(viewModel.leagues.count, 0)
        XCTAssertTrue(mockStorage.clearedLeagueIds.contains("123"))
        XCTAssertTrue(mockKeychain.deletedLeagueIds.contains("123"))
    }
    
    func testLeagueListViewModel_SelectLeague() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        
        let connection = LeagueConnection(
            id: "1",
            leagueId: "123",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        // Execute
        viewModel.selectLeague(connection)
        
        // Verify
        XCTAssertEqual(viewModel.selectedLeague?.id, connection.id)
    }
    
    // MARK: - PowerRankingsViewModel Tests
    
    func testPowerRankingsViewModel_FetchLeagueData_Success() async {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Setup mock data
        let teams = [
            Team(
                id: "1", name: "Team A", ownerName: "Owner A",
                wins: 5, losses: 2, ties: 0,
                pointsFor: 1000, pointsAgainst: 800,
                powerScore: 0, rank: 0,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [], roast: nil
            ),
            Team(
                id: "2", name: "Team B", ownerName: "Owner B",
                wins: 3, losses: 4, ties: 0,
                pointsFor: 900, pointsAgainst: 950,
                powerScore: 0, rank: 0,
                streak: Team.Streak(type: .loss, length: 1),
                topPlayers: [], roast: nil
            )
        ]
        mockSleeper.teamsToReturn = teams
        
        let connection = LeagueConnection(
            id: "1",
            leagueId: "123",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        // Execute
        await viewModel.fetchLeagueData(for: connection)
        
        // Verify
        XCTAssertEqual(viewModel.teams.count, 2)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.lastUpdated)
        XCTAssertEqual(viewModel.teams.first?.rank, 1)
    }
    
    func testPowerRankingsViewModel_CalculateRankings() {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Setup teams
        viewModel.teams = [
            Team(
                id: "1", name: "Team A", ownerName: "Owner A",
                wins: 5, losses: 2, ties: 0,
                pointsFor: 1000, pointsAgainst: 800,
                powerScore: 0, rank: 0,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [], roast: nil
            ),
            Team(
                id: "2", name: "Team B", ownerName: "Owner B",
                wins: 3, losses: 4, ties: 0,
                pointsFor: 900, pointsAgainst: 950,
                powerScore: 0, rank: 0,
                streak: Team.Streak(type: .loss, length: 1),
                topPlayers: [], roast: nil
            )
        ]
        
        // Execute
        viewModel.calculateRankings()
        
        // Verify rankings are assigned
        XCTAssertEqual(viewModel.teams.first?.rank, 1)
        XCTAssertEqual(viewModel.teams.last?.rank, 2)
    }
    
    func testPowerRankingsViewModel_GenerateRoasts_Success() async {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Setup teams
        viewModel.teams = [
            Team(
                id: "1", name: "Team A", ownerName: "Owner A",
                wins: 5, losses: 2, ties: 0,
                pointsFor: 1000, pointsAgainst: 800,
                powerScore: 0, rank: 0,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [], roast: nil
            )
        ]
        
        // Setup mock roasts
        mockBackend.roastsToReturn = ["1": "This is a roast"]
        
        let context = LeagueContext.empty
        
        // Execute
        await viewModel.generateRoasts(context: context)
        
        // Verify
        XCTAssertEqual(viewModel.teams.first?.roast, "This is a roast")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testPowerRankingsViewModel_ToggleRoasts() {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Initial state
        XCTAssertTrue(viewModel.roastsEnabled)
        
        // Toggle off
        viewModel.toggleRoasts()
        XCTAssertFalse(viewModel.roastsEnabled)
        
        // Toggle on
        viewModel.toggleRoasts()
        XCTAssertTrue(viewModel.roastsEnabled)
    }
    
    func testPowerRankingsViewModel_FormatForExport_WithoutRoasts() {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Setup teams with roasts
        viewModel.teams = [
            Team(
                id: "1", name: "Team A", ownerName: "Owner A",
                wins: 5, losses: 2, ties: 0,
                pointsFor: 1000.5, pointsAgainst: 800,
                powerScore: 0.75, rank: 1,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [], roast: "This is a roast"
            ),
            Team(
                id: "2", name: "Team B", ownerName: "Owner B",
                wins: 3, losses: 4, ties: 0,
                pointsFor: 900.2, pointsAgainst: 950,
                powerScore: 0.45, rank: 2,
                streak: Team.Streak(type: .loss, length: 1),
                topPlayers: [], roast: "Another roast"
            )
        ]
        
        // Execute
        let output = viewModel.formatForExport(includeRoasts: false)
        
        // Verify
        XCTAssertTrue(output.contains("Power Rankings"))
        XCTAssertTrue(output.contains("1. Team A"))
        XCTAssertTrue(output.contains("Owner: Owner A"))
        XCTAssertTrue(output.contains("Record: 5-2"))
        XCTAssertTrue(output.contains("Points: 1000.5"))
        XCTAssertTrue(output.contains("2. Team B"))
        XCTAssertTrue(output.contains("Owner: Owner B"))
        XCTAssertTrue(output.contains("Record: 3-4"))
        XCTAssertTrue(output.contains("Points: 900.2"))
        XCTAssertFalse(output.contains("This is a roast"))
        XCTAssertFalse(output.contains("Another roast"))
    }
    
    func testPowerRankingsViewModel_FormatForExport_WithRoasts() {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Setup teams with roasts
        viewModel.teams = [
            Team(
                id: "1", name: "Team A", ownerName: "Owner A",
                wins: 5, losses: 2, ties: 0,
                pointsFor: 1000.5, pointsAgainst: 800,
                powerScore: 0.75, rank: 1,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [], roast: "This is a roast"
            )
        ]
        
        // Execute
        let output = viewModel.formatForExport(includeRoasts: true)
        
        // Verify
        XCTAssertTrue(output.contains("Power Rankings"))
        XCTAssertTrue(output.contains("1. Team A"))
        XCTAssertTrue(output.contains("This is a roast"))
    }
    
    func testPowerRankingsViewModel_FormatForExport_EmptyTeams() {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Execute with no teams
        let output = viewModel.formatForExport(includeRoasts: false)
        
        // Verify
        XCTAssertEqual(output, "No rankings available")
    }
    
    func testPowerRankingsViewModel_CopyToClipboard() {
        let mockESPN = MockLeagueDataService()
        let mockSleeper = MockLeagueDataService()
        let mockBackend = MockBackendService()
        let mockStorage = MockStorageService()
        
        let viewModel = PowerRankingsViewModel(
            espnService: mockESPN,
            sleeperService: mockSleeper,
            backendService: mockBackend,
            storageService: mockStorage
        )
        
        // Setup teams
        viewModel.teams = [
            Team(
                id: "1", name: "Team A", ownerName: "Owner A",
                wins: 5, losses: 2, ties: 0,
                pointsFor: 1000.5, pointsAgainst: 800,
                powerScore: 0.75, rank: 1,
                streak: Team.Streak(type: .win, length: 2),
                topPlayers: [], roast: "This is a roast"
            )
        ]
        
        // Execute
        let success = viewModel.copyToClipboard(includeRoasts: false)
        
        // Verify
        XCTAssertTrue(success)
        
        // Verify clipboard content (platform-specific)
        #if os(iOS)
        let clipboardContent = UIPasteboard.general.string
        XCTAssertNotNil(clipboardContent)
        XCTAssertTrue(clipboardContent?.contains("Team A") ?? false)
        #elseif os(macOS)
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(clipboardContent)
        XCTAssertTrue(clipboardContent?.contains("Team A") ?? false)
        #endif
    }
    
    // MARK: - LeagueContextViewModel Tests
    
    func testLeagueContextViewModel_LoadContext_Success() {
        let mockStorage = MockStorageService()
        let viewModel = LeagueContextViewModel(storageService: mockStorage)
        
        // Setup mock context
        let context = LeagueContext(
            insideJokes: [LeagueContext.InsideJoke(id: UUID(), term: "Test", explanation: "Explanation")],
            personalities: [LeagueContext.PlayerPersonality(id: UUID(), playerName: "Player", description: "Description")],
            sackoPunishment: "Punishment",
            cultureNotes: "Notes"
        )
        mockStorage.contextByLeagueId["123"] = context
        
        // Execute
        viewModel.loadContext(forLeagueId: "123")
        
        // Verify
        XCTAssertEqual(viewModel.insideJokes.count, 1)
        XCTAssertEqual(viewModel.personalities.count, 1)
        XCTAssertEqual(viewModel.sackoPunishment, "Punishment")
        XCTAssertEqual(viewModel.cultureNotes, "Notes")
    }
    
    func testLeagueContextViewModel_AddInsideJoke() {
        let mockStorage = MockStorageService()
        let viewModel = LeagueContextViewModel(storageService: mockStorage)
        
        // Execute
        viewModel.addInsideJoke(term: "Test", explanation: "Explanation")
        
        // Verify
        XCTAssertEqual(viewModel.insideJokes.count, 1)
        XCTAssertEqual(viewModel.insideJokes.first?.term, "Test")
        XCTAssertEqual(viewModel.insideJokes.first?.explanation, "Explanation")
    }
    
    func testLeagueContextViewModel_EditInsideJoke() {
        let mockStorage = MockStorageService()
        let viewModel = LeagueContextViewModel(storageService: mockStorage)
        
        viewModel.addInsideJoke(term: "Test", explanation: "Explanation")
        let jokeId = viewModel.insideJokes.first!.id
        
        // Execute
        viewModel.editInsideJoke(id: jokeId, term: "Updated", explanation: "New Explanation")
        
        // Verify
        XCTAssertEqual(viewModel.insideJokes.first?.term, "Updated")
        XCTAssertEqual(viewModel.insideJokes.first?.explanation, "New Explanation")
    }
    
    func testLeagueContextViewModel_RemoveInsideJoke() {
        let mockStorage = MockStorageService()
        let viewModel = LeagueContextViewModel(storageService: mockStorage)
        
        viewModel.addInsideJoke(term: "Test", explanation: "Explanation")
        let jokeId = viewModel.insideJokes.first!.id
        
        // Execute
        viewModel.removeInsideJoke(id: jokeId)
        
        // Verify
        XCTAssertEqual(viewModel.insideJokes.count, 0)
    }
    
    func testLeagueContextViewModel_AddPersonality() {
        let mockStorage = MockStorageService()
        let viewModel = LeagueContextViewModel(storageService: mockStorage)
        
        // Execute
        viewModel.addPersonality(playerName: "Player", description: "Description")
        
        // Verify
        XCTAssertEqual(viewModel.personalities.count, 1)
        XCTAssertEqual(viewModel.personalities.first?.playerName, "Player")
        XCTAssertEqual(viewModel.personalities.first?.description, "Description")
    }
    
    func testLeagueContextViewModel_SaveContext() {
        let mockStorage = MockStorageService()
        let viewModel = LeagueContextViewModel(storageService: mockStorage)
        
        viewModel.loadContext(forLeagueId: "123")
        viewModel.addInsideJoke(term: "Test", explanation: "Explanation")
        viewModel.updateSacko("Punishment")
        
        // Execute
        viewModel.saveContext()
        
        // Verify
        XCTAssertNotNil(mockStorage.savedContextByLeagueId["123"])
        XCTAssertEqual(mockStorage.savedContextByLeagueId["123"]?.insideJokes.count, 1)
        XCTAssertEqual(mockStorage.savedContextByLeagueId["123"]?.sackoPunishment, "Punishment")
    }
}

// MARK: - Mock Services

class MockStorageService: StorageService {
    var leagueConnections: [LeagueConnection] = []
    var savedConnections: [LeagueConnection]?
    var contextByLeagueId: [String: LeagueContext] = [:]
    var savedContextByLeagueId: [String: LeagueContext] = [:]
    var cachedDataByLeagueId: [String: (teams: [Team], timestamp: Date, roastHash: Int?)] = [:]
    var clearedLeagueIds: [String] = []
    var lastViewedLeagueId: String?
    var shouldThrowError = false
    
    func saveLeagueConnections(_ connections: [LeagueConnection]) throws {
        if shouldThrowError { throw StorageError.encodingFailed(NSError(domain: "test", code: 1)) }
        savedConnections = connections
    }
    
    func loadLeagueConnections() throws -> [LeagueConnection] {
        if shouldThrowError { throw StorageError.decodingFailed(NSError(domain: "test", code: 1)) }
        return leagueConnections
    }
    
    func saveLeagueContext(_ context: LeagueContext, forLeagueId leagueId: String) throws {
        if shouldThrowError { throw StorageError.encodingFailed(NSError(domain: "test", code: 1)) }
        savedContextByLeagueId[leagueId] = context
    }
    
    func loadLeagueContext(forLeagueId leagueId: String) throws -> LeagueContext? {
        if shouldThrowError { throw StorageError.decodingFailed(NSError(domain: "test", code: 1)) }
        return contextByLeagueId[leagueId]
    }
    
    func saveCachedLeagueData(_ teams: [Team], forLeagueId leagueId: String, roastHash: Int?) throws {
        if shouldThrowError { throw StorageError.encodingFailed(NSError(domain: "test", code: 1)) }
        cachedDataByLeagueId[leagueId] = (teams: teams, timestamp: Date(), roastHash: roastHash)
    }
    
    func loadCachedLeagueData(forLeagueId leagueId: String) throws -> (teams: [Team], timestamp: Date, roastHash: Int?)? {
        if shouldThrowError { throw StorageError.decodingFailed(NSError(domain: "test", code: 1)) }
        return cachedDataByLeagueId[leagueId]
    }
    
    func isCacheStale(forLeagueId leagueId: String) -> Bool {
        return cachedDataByLeagueId[leagueId] == nil
    }
    
    func getCacheAge(forLeagueId leagueId: String) -> TimeInterval? {
        guard let cached = cachedDataByLeagueId[leagueId] else { return nil }
        return Date().timeIntervalSince(cached.timestamp)
    }
    
    func saveLastViewedLeagueId(_ leagueId: String) {
        lastViewedLeagueId = leagueId
    }
    
    func loadLastViewedLeagueId() -> String? {
        return lastViewedLeagueId
    }
    
    func clearDataForLeague(leagueId: String) throws {
        if shouldThrowError { throw StorageError.fileOperationFailed(NSError(domain: "test", code: 1)) }
        clearedLeagueIds.append(leagueId)
    }
    
    // Weekly Roast Cache
    var roastCacheByKey: [String: WeeklyRoastCache] = [:]
    
    func saveWeeklyRoasts(_ cache: WeeklyRoastCache) throws {
        if shouldThrowError { throw StorageError.encodingFailed(NSError(domain: "test", code: 1)) }
        roastCacheByKey["\(cache.leagueId)_\(cache.weekNumber)"] = cache
    }
    
    func loadWeeklyRoasts(forLeagueId leagueId: String, week: Int) throws -> WeeklyRoastCache? {
        if shouldThrowError { throw StorageError.decodingFailed(NSError(domain: "test", code: 1)) }
        return roastCacheByKey["\(leagueId)_\(week)"]
    }
    
    func deleteAllRoasts(forLeagueId leagueId: String) throws {
        if shouldThrowError { throw StorageError.fileOperationFailed(NSError(domain: "test", code: 1)) }
        roastCacheByKey = roastCacheByKey.filter { !$0.key.hasPrefix("\(leagueId)_") }
    }
    
    func availableRoastWeeks(forLeagueId leagueId: String) throws -> [Int] {
        if shouldThrowError { throw StorageError.fileOperationFailed(NSError(domain: "test", code: 1)) }
        return roastCacheByKey.keys
            .filter { $0.hasPrefix("\(leagueId)_") }
            .compactMap { Int($0.dropFirst("\(leagueId)_".count)) }
            .sorted()
    }
}

class MockKeychainServiceForViewModels: KeychainService {
    var credentialsByLeagueId: [String: ESPNCredentials] = [:]
    var deletedLeagueIds: [String] = []
    var shouldFail = false
    
    func saveESPNCredentials(espnS2: String, swid: String, forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        if shouldFail { return .failure(.saveFailed(0)) }
        credentialsByLeagueId[leagueId] = ESPNCredentials(espnS2: espnS2, swid: swid)
        return .success(())
    }
    
    func retrieveESPNCredentials(forLeagueId leagueId: String) -> Result<ESPNCredentials, KeychainError> {
        if shouldFail { return .failure(.retrievalFailed(0)) }
        if let credentials = credentialsByLeagueId[leagueId] {
            return .success(credentials)
        }
        return .failure(.credentialsNotFound)
    }
    
    func deleteESPNCredentials(forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        if shouldFail { return .failure(.deletionFailed(0)) }
        deletedLeagueIds.append(leagueId)
        credentialsByLeagueId.removeValue(forKey: leagueId)
        return .success(())
    }
    
    func hasESPNCredentials(forLeagueId leagueId: String) -> Bool {
        return credentialsByLeagueId[leagueId] != nil
    }
}

class MockLeagueDataService: LeagueDataService {
    var teamsToReturn: [Team] = []
    var shouldThrowError = false
    var errorToThrow: LeagueDataError = .networkError(NSError(domain: "test", code: 1))
    
    func fetchLeagueData(leagueId: String, season: Int) async throws -> [Team] {
        if shouldThrowError { throw errorToThrow }
        return teamsToReturn
    }
}

class MockBackendService: BackendService {
    var roastsToReturn: [String: String] = [:]
    var shouldThrowError = false
    var errorToThrow: BackendError = .networkError(NSError(domain: "test", code: 1))
    
    func generateRoasts(teams: [Team], context: LeagueContext) async throws -> [String: String] {
        if shouldThrowError { throw errorToThrow }
        return roastsToReturn
    }

    func generateRoasts(
        teams: [Team],
        context: LeagueContext,
        matchups: [WeeklyMatchup],
        weekNumber: Int,
        seasonPhase: SeasonPhase,
        playoffBracket: [PlayoffBracketEntry]?
    ) async throws -> [String: String] {
        if shouldThrowError { throw errorToThrow }
        return roastsToReturn
    }
}

    // MARK: - Last Viewed League Tests
    
    @MainActor
    func testLeagueListViewModel_SavesLastViewedLeagueOnSelect() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        
        let league = LeagueConnection(
            id: "league-1",
            leagueId: "12345",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        viewModel.selectLeague(league)
        
        XCTAssertEqual(mockStorage.lastViewedLeagueId, "league-1")
    }
    
    @MainActor
    func testLeagueListViewModel_AutoLoadsLastViewedLeague() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        
        let league1 = LeagueConnection(
            id: "league-1",
            leagueId: "12345",
            platform: .sleeper,
            leagueName: "Test League 1",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        let league2 = LeagueConnection(
            id: "league-2",
            leagueId: "67890",
            platform: .espn,
            leagueName: "Test League 2",
            lastUpdated: Date(),
            hasAuthentication: true
        )
        
        mockStorage.leagueConnections = [league1, league2]
        mockStorage.lastViewedLeagueId = "league-2"
        
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        viewModel.fetchLeagues()
        
        XCTAssertEqual(viewModel.selectedLeague?.id, "league-2")
        XCTAssertTrue(viewModel.shouldNavigateToLastViewed)
    }
    
    @MainActor
    func testLeagueListViewModel_NoAutoLoadWhenNoLastViewed() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        
        let league = LeagueConnection(
            id: "league-1",
            leagueId: "12345",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        mockStorage.leagueConnections = [league]
        mockStorage.lastViewedLeagueId = nil
        
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        viewModel.fetchLeagues()
        
        XCTAssertNil(viewModel.selectedLeague)
        XCTAssertFalse(viewModel.shouldNavigateToLastViewed)
    }
    
    @MainActor
    func testLeagueListViewModel_ClearsNavigationFlag() {
        let mockStorage = MockStorageService()
        let mockKeychain = MockKeychainServiceForViewModels()
        let viewModel = LeagueListViewModel(storageService: mockStorage, keychainService: mockKeychain)
        
        let league = LeagueConnection(
            id: "league-1",
            leagueId: "12345",
            platform: .sleeper,
            leagueName: "Test League",
            lastUpdated: Date(),
            hasAuthentication: false
        )
        
        mockStorage.leagueConnections = [league]
        mockStorage.lastViewedLeagueId = "league-1"
        
        viewModel.fetchLeagues()
        XCTAssertTrue(viewModel.shouldNavigateToLastViewed)
        
        viewModel.clearNavigationFlag()
        XCTAssertFalse(viewModel.shouldNavigateToLastViewed)
    }
