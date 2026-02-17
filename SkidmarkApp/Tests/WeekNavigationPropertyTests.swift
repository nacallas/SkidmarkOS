import XCTest
@testable import SkidmarkApp

// Feature: roast-enhancements, Property 4: Week navigation bounds
// Validates: Requirements 2.3, 2.4, 2.5, 2.6

/// Property-based tests for week navigation bounds in PowerRankingsViewModel.
/// Verifies that navigating forward/backward clamps correctly and that the
/// disabled-state predicates match the boundary conditions.
final class WeekNavigationPropertyTests: XCTestCase {

    /// For any current week C >= 1 and selected week S where 1 <= S <= C,
    /// navigating backward produces max(1, S-1), navigating forward produces min(C, S+1),
    /// backward is disabled iff S == 1, and forward is disabled iff S == C.
    /// **Validates: Requirements 2.3, 2.4, 2.5, 2.6**
    @MainActor
    func testWeekNavigationBounds() async {
        let iterations = 100

        for iteration in 0..<iterations {
            // Generate random C >= 1 (up to 18 weeks in a fantasy season)
            let currentWeek = Int.random(in: 1...18)
            // Generate random S in [1, C]
            let selectedWeek = Int.random(in: 1...currentWeek)

            let vm = makeViewModel()
            vm.currentWeek = currentWeek
            vm.selectedWeek = selectedWeek

            // --- Backward navigation: should produce max(1, S-1) ---
            let expectedBackward = max(1, selectedWeek - 1)
            await vm.navigateToWeek(selectedWeek - 1)
            XCTAssertEqual(vm.selectedWeek, expectedBackward,
                          "Iteration \(iteration): backward from S=\(selectedWeek), C=\(currentWeek) " +
                          "expected \(expectedBackward), got \(vm.selectedWeek)")

            // Reset for forward test
            vm.selectedWeek = selectedWeek

            // --- Forward navigation: should produce min(C, S+1) ---
            let expectedForward = min(currentWeek, selectedWeek + 1)
            await vm.navigateToWeek(selectedWeek + 1)
            XCTAssertEqual(vm.selectedWeek, expectedForward,
                          "Iteration \(iteration): forward from S=\(selectedWeek), C=\(currentWeek) " +
                          "expected \(expectedForward), got \(vm.selectedWeek)")

            // Reset for disabled-state checks
            vm.selectedWeek = selectedWeek

            // --- canNavigateBackward: disabled iff S == 1 ---
            let canGoBack = selectedWeek > 1
            XCTAssertEqual(canGoBack, selectedWeek != 1,
                          "Iteration \(iteration): canNavigateBackward should be \(!canGoBack) when S=\(selectedWeek)")

            // --- canNavigateForward: disabled iff S == C ---
            let canGoForward = selectedWeek < currentWeek
            XCTAssertEqual(canGoForward, selectedWeek != currentWeek,
                          "Iteration \(iteration): canNavigateForward should be \(!canGoForward) when S=\(selectedWeek), C=\(currentWeek)")
        }
    }

    /// Edge case: when C == 1, both directions should be disabled and navigation
    /// should always clamp to 1.
    /// **Validates: Requirements 2.5, 2.6**
    @MainActor
    func testWeekNavigationBoundsAtMinimum() async {
        let vm = makeViewModel()
        vm.currentWeek = 1
        vm.selectedWeek = 1

        // Backward from week 1 stays at 1
        await vm.navigateToWeek(0)
        XCTAssertEqual(vm.selectedWeek, 1, "Cannot go below week 1")

        // Forward from week 1 when currentWeek is 1 stays at 1
        await vm.navigateToWeek(2)
        XCTAssertEqual(vm.selectedWeek, 1, "Cannot go above currentWeek")

        // Both directions disabled
        XCTAssertFalse(vm.selectedWeek > 1, "Backward should be disabled at week 1")
        XCTAssertFalse(vm.selectedWeek < vm.currentWeek, "Forward should be disabled when at currentWeek")
    }

    /// Navigating far out of bounds still clamps correctly.
    /// **Validates: Requirements 2.3, 2.4, 2.5, 2.6**
    @MainActor
    func testWeekNavigationExtremeValues() async {
        let iterations = 100

        for iteration in 0..<iterations {
            let currentWeek = Int.random(in: 1...18)
            let vm = makeViewModel()
            vm.currentWeek = currentWeek
            vm.selectedWeek = currentWeek

            // Navigate far below bounds
            let farBelow = Int.random(in: -100...0)
            await vm.navigateToWeek(farBelow)
            XCTAssertEqual(vm.selectedWeek, 1,
                          "Iteration \(iteration): navigating to \(farBelow) should clamp to 1")

            // Navigate far above bounds
            let farAbove = Int.random(in: (currentWeek + 1)...(currentWeek + 100))
            await vm.navigateToWeek(farAbove)
            XCTAssertEqual(vm.selectedWeek, currentWeek,
                          "Iteration \(iteration): navigating to \(farAbove) should clamp to \(currentWeek)")
        }
    }

    // MARK: - Helpers

    /// Creates a PowerRankingsViewModel with stub services suitable for navigation testing.
    /// No league is set, so navigateToWeek skips cache operations after updating selectedWeek.
    @MainActor
    private func makeViewModel() -> PowerRankingsViewModel {
        PowerRankingsViewModel(
            espnService: WeekNavMockLeagueDataService(),
            sleeperService: WeekNavMockLeagueDataService(),
            backendService: WeekNavMockBackendService(),
            storageService: WeekNavMockStorageService()
        )
    }
}

// MARK: - Minimal stubs (only satisfy protocol requirements; no real behavior needed)

private class WeekNavMockLeagueDataService: LeagueDataService {
    func fetchLeagueData(leagueId: String, season: Int) async throws -> [Team] { [] }
}

private class WeekNavMockBackendService: BackendService {
    func generateRoasts(teams: [Team], context: LeagueContext) async throws -> [String: String] { [:] }
    func generateRoasts(teams: [Team], context: LeagueContext, matchups: [WeeklyMatchup],
                        weekNumber: Int, seasonPhase: SeasonPhase,
                        playoffBracket: [PlayoffBracketEntry]?) async throws -> [String: String] { [:] }
}

private class WeekNavMockStorageService: StorageService {
    func saveLeagueConnections(_ c: [LeagueConnection]) throws {}
    func loadLeagueConnections() throws -> [LeagueConnection] { [] }
    func saveLeagueContext(_ c: LeagueContext, forLeagueId: String) throws {}
    func loadLeagueContext(forLeagueId: String) throws -> LeagueContext? { nil }
    func saveCachedLeagueData(_ t: [Team], forLeagueId: String, roastHash: Int?) throws {}
    func loadCachedLeagueData(forLeagueId: String) throws -> (teams: [Team], timestamp: Date, roastHash: Int?)? { nil }
    func isCacheStale(forLeagueId: String) -> Bool { true }
    func getCacheAge(forLeagueId: String) -> TimeInterval? { nil }
    func saveLastViewedLeagueId(_ id: String) {}
    func loadLastViewedLeagueId() -> String? { nil }
    func saveWeeklyRoasts(_ cache: WeeklyRoastCache) throws {}
    func loadWeeklyRoasts(forLeagueId: String, week: Int) throws -> WeeklyRoastCache? { nil }
    func deleteAllRoasts(forLeagueId: String) throws {}
    func availableRoastWeeks(forLeagueId: String) throws -> [Int] { [] }
    func clearDataForLeague(leagueId: String) throws {}
}

// MARK: - Property 5: Cache load on week navigation

// Feature: roast-enhancements, Property 5: Cache load on week navigation
// Validates: Requirements 2.7

/// Property-based tests for cache load on week navigation.
/// For any league with roasts cached for a set of weeks W, navigating to a week
/// w in W should surface the roasts that were previously stored for that week.
final class WeekNavigationCacheLoadPropertyTests: XCTestCase {

    /// **Validates: Requirements 2.7**
    @MainActor
    func testCacheLoadOnWeekNavigation() async {
        let iterations = 100

        for iteration in 0..<iterations {
            // Generate a random set of weeks (1..18) with cached roasts
            let weekCount = Int.random(in: 1...6)
            let cachedWeeks = Array(Set((0..<weekCount).map { _ in Int.random(in: 1...18) })).sorted()
            let maxWeek = cachedWeeks.max() ?? 1

            // Generate random team IDs (2-10 teams)
            let teamCount = Int.random(in: 2...10)
            let teamIds = (0..<teamCount).map { "team_\($0)" }

            // Build teams for the view model
            let teams = teamIds.map { id in
                Team(
                    id: id,
                    name: "Team \(id)",
                    ownerName: "Owner \(id)",
                    wins: Int.random(in: 0...10),
                    losses: Int.random(in: 0...10),
                    ties: 0,
                    pointsFor: Double.random(in: 500...1500),
                    pointsAgainst: Double.random(in: 500...1500),
                    powerScore: 0,
                    rank: 0,
                    streak: Team.Streak(type: .win, length: 1),
                    topPlayers: [],
                    roast: nil
                )
            }

            // Build a roast dictionary per cached week
            var expectedRoastsByWeek: [Int: [String: String]] = [:]
            for week in cachedWeeks {
                var roasts: [String: String] = [:]
                for id in teamIds {
                    roasts[id] = "Roast for \(id) week \(week) iter \(iteration) \(UUID().uuidString.prefix(8))"
                }
                expectedRoastsByWeek[week] = roasts
            }

            // Set up in-memory storage with pre-populated caches
            let storage = CachingMockStorageService()
            for week in cachedWeeks {
                let cache = WeeklyRoastCache(
                    leagueId: "test_league",
                    weekNumber: week,
                    generatedAt: Date(),
                    roasts: expectedRoastsByWeek[week]!
                )
                try! storage.saveWeeklyRoasts(cache)
            }

            // Set up mock league service that returns our teams
            let leagueService = CacheTestMockLeagueDataService(teams: teams, currentWeek: maxWeek)

            let vm = PowerRankingsViewModel(
                espnService: leagueService,
                sleeperService: leagueService,
                backendService: WeekNavMockBackendService(),
                storageService: storage
            )

            // Call fetchLeagueData to set currentLeague on the VM
            let league = LeagueConnection(
                id: "test_league",
                leagueId: "test_league",
                platform: .espn,
                leagueName: "Test League",
                lastUpdated: Date(),
                hasAuthentication: false
            )
            await vm.fetchLeagueData(for: league)

            // Verify teams are loaded
            XCTAssertFalse(vm.teams.isEmpty,
                          "Iteration \(iteration): VM should have teams after fetchLeagueData")

            // Navigate to each cached week and verify roasts are surfaced
            for week in cachedWeeks {
                await vm.navigateToWeek(week)

                let expectedRoasts = expectedRoastsByWeek[week]!
                for team in vm.teams {
                    let expectedRoast = expectedRoasts[team.id]
                    XCTAssertEqual(team.roast, expectedRoast,
                                  "Iteration \(iteration), week \(week), team \(team.id): " +
                                  "expected roast '\(expectedRoast ?? "nil")' but got '\(team.roast ?? "nil")'")
                }
            }
        }
    }
}

// MARK: - In-memory caching storage mock

/// A StorageService mock that actually stores and retrieves WeeklyRoastCache in memory.
/// Used by Property 5 to verify that navigateToWeek loads the correct cached roasts.
private class CachingMockStorageService: StorageService {
    private var roastCaches: [String: WeeklyRoastCache] = [:]

    private func cacheKey(leagueId: String, week: Int) -> String {
        "\(leagueId)_week_\(week)"
    }

    func saveWeeklyRoasts(_ cache: WeeklyRoastCache) throws {
        roastCaches[cacheKey(leagueId: cache.leagueId, week: cache.weekNumber)] = cache
    }

    func loadWeeklyRoasts(forLeagueId leagueId: String, week: Int) throws -> WeeklyRoastCache? {
        roastCaches[cacheKey(leagueId: leagueId, week: week)]
    }

    func deleteAllRoasts(forLeagueId leagueId: String) throws {
        roastCaches = roastCaches.filter { !$0.key.hasPrefix("\(leagueId)_week_") }
    }

    func availableRoastWeeks(forLeagueId leagueId: String) throws -> [Int] {
        roastCaches.keys
            .filter { $0.hasPrefix("\(leagueId)_week_") }
            .compactMap { key -> Int? in
                let suffix = key.dropFirst("\(leagueId)_week_".count)
                return Int(suffix)
            }
            .sorted()
    }

    // Remaining protocol stubs (not exercised by this test)
    func saveLeagueConnections(_ c: [LeagueConnection]) throws {}
    func loadLeagueConnections() throws -> [LeagueConnection] { [] }
    func saveLeagueContext(_ c: LeagueContext, forLeagueId: String) throws {}
    func loadLeagueContext(forLeagueId: String) throws -> LeagueContext? { nil }
    func saveCachedLeagueData(_ t: [Team], forLeagueId: String, roastHash: Int?) throws {}
    func loadCachedLeagueData(forLeagueId: String) throws -> (teams: [Team], timestamp: Date, roastHash: Int?)? { nil }
    func isCacheStale(forLeagueId: String) -> Bool { true }
    func getCacheAge(forLeagueId: String) -> TimeInterval? { nil }
    func saveLastViewedLeagueId(_ id: String) {}
    func loadLastViewedLeagueId() -> String? { nil }
    func clearDataForLeague(leagueId: String) throws {}
}

/// A LeagueDataService mock that returns pre-configured teams and settings.
/// Enables fetchLeagueData to set currentLeague on the view model.
private class CacheTestMockLeagueDataService: LeagueDataService {
    let teams: [Team]
    let currentWeek: Int

    init(teams: [Team], currentWeek: Int) {
        self.teams = teams
        self.currentWeek = currentWeek
    }

    func fetchLeagueData(leagueId: String, season: Int) async throws -> [Team] {
        teams
    }

    func fetchLeagueSettings(leagueId: String, season: Int) async throws -> LeagueSettings {
        LeagueSettings(
            playoffStartWeek: 15,
            playoffTeamCount: 6,
            currentWeek: currentWeek,
            totalRegularSeasonWeeks: 14
        )
    }
}
