import XCTest
@testable import SkidmarkApp

/// Property-based tests for roast cache storage operations
/// Tests round-trip persistence, overwrite semantics, and deletion behavior
final class RoastCachePropertyTests: XCTestCase {

    private var storageService: DefaultStorageService!

    override func setUp() {
        super.setUp()
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        storageService = DefaultStorageService(userDefaults: testDefaults)
    }

    override func tearDown() {
        // Clean up any roast cache files written during tests
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let contents = try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil) {
            for url in contents where url.lastPathComponent.hasPrefix("league_") && url.lastPathComponent.contains("_roasts_week_") {
                try? FileManager.default.removeItem(at: url)
            }
        }
        super.tearDown()
    }

    // MARK: - Property 1: Roast cache round-trip

    /// For any valid WeeklyRoastCache, save then load returns equivalent object
    /// Feature: roast-enhancements, Property 1: Roast cache round-trip
    /// **Validates: Requirements 1.1, 1.2**
    func testRoastCacheRoundTrip() {
        let iterations = 100

        for iteration in 0..<iterations {
            let original = generateRandomRoastCache()

            do {
                try storageService.saveWeeklyRoasts(original)
                guard let loaded = try storageService.loadWeeklyRoasts(forLeagueId: original.leagueId, week: original.weekNumber) else {
                    XCTFail("Iteration \(iteration): Failed to load saved roast cache")
                    continue
                }

                XCTAssertEqual(loaded.leagueId, original.leagueId,
                              "Iteration \(iteration): leagueId should match")
                XCTAssertEqual(loaded.weekNumber, original.weekNumber,
                              "Iteration \(iteration): weekNumber should match")

                let timeDiff = abs(loaded.generatedAt.timeIntervalSince(original.generatedAt))
                XCTAssertLessThan(timeDiff, 1.0,
                                 "Iteration \(iteration): generatedAt should match within 1 second")

                XCTAssertEqual(loaded.roasts, original.roasts,
                              "Iteration \(iteration): roasts dictionary should match")

                // Clean up
                try storageService.deleteAllRoasts(forLeagueId: original.leagueId)
            } catch {
                XCTFail("Iteration \(iteration): Round-trip failed with error: \(error)")
            }
        }
    }

    // MARK: - Property 2: Roast cache overwrite

    /// For any league+week, saving twice returns only the second entry
    /// Feature: roast-enhancements, Property 2: Roast cache overwrite
    /// **Validates: Requirements 1.3**
    func testRoastCacheOverwrite() {
        let iterations = 100

        for iteration in 0..<iterations {
            let leagueId = "league_\(UUID().uuidString)"
            let weekNumber = Int.random(in: 1...18)

            let first = WeeklyRoastCache(
                leagueId: leagueId,
                weekNumber: weekNumber,
                generatedAt: Date().addingTimeInterval(Double.random(in: -86400...0)),
                roasts: generateRandomRoasts()
            )

            let second = WeeklyRoastCache(
                leagueId: leagueId,
                weekNumber: weekNumber,
                generatedAt: Date(),
                roasts: generateRandomRoasts()
            )

            do {
                try storageService.saveWeeklyRoasts(first)
                try storageService.saveWeeklyRoasts(second)

                guard let loaded = try storageService.loadWeeklyRoasts(forLeagueId: leagueId, week: weekNumber) else {
                    XCTFail("Iteration \(iteration): Failed to load after overwrite")
                    continue
                }

                XCTAssertEqual(loaded.roasts, second.roasts,
                              "Iteration \(iteration): Should return the second (overwritten) roasts")

                let timeDiff = abs(loaded.generatedAt.timeIntervalSince(second.generatedAt))
                XCTAssertLessThan(timeDiff, 1.0,
                                 "Iteration \(iteration): generatedAt should match the second save")

                XCTAssertNotEqual(first.roasts, second.roasts,
                                 "Iteration \(iteration): Test precondition -- first and second roasts should differ")

                // Clean up
                try storageService.deleteAllRoasts(forLeagueId: leagueId)
            } catch {
                XCTFail("Iteration \(iteration): Overwrite test failed with error: \(error)")
            }
        }
    }

    // MARK: - Property 3: Roast cache deletion

    /// For any league with roasts across multiple weeks, deleteAllRoasts clears all
    /// Feature: roast-enhancements, Property 3: Roast cache deletion
    /// **Validates: Requirements 1.4**
    func testRoastCacheDeletion() {
        let iterations = 100

        for iteration in 0..<iterations {
            let leagueId = "league_\(UUID().uuidString)"
            let weekCount = Int.random(in: 1...10)
            let weeks = Array(Set((0..<weekCount).map { _ in Int.random(in: 1...18) }))

            do {
                // Save roasts for multiple weeks
                for week in weeks {
                    let cache = WeeklyRoastCache(
                        leagueId: leagueId,
                        weekNumber: week,
                        generatedAt: Date(),
                        roasts: generateRandomRoasts()
                    )
                    try storageService.saveWeeklyRoasts(cache)
                }

                // Verify they exist
                let availableBefore = try storageService.availableRoastWeeks(forLeagueId: leagueId)
                XCTAssertEqual(Set(availableBefore), Set(weeks),
                              "Iteration \(iteration): All saved weeks should be available before deletion")

                // Delete all roasts
                try storageService.deleteAllRoasts(forLeagueId: leagueId)

                // Verify all are gone
                for week in weeks {
                    let loaded = try storageService.loadWeeklyRoasts(forLeagueId: leagueId, week: week)
                    XCTAssertNil(loaded,
                                "Iteration \(iteration): Week \(week) should be nil after deleteAllRoasts")
                }

                let availableAfter = try storageService.availableRoastWeeks(forLeagueId: leagueId)
                XCTAssertTrue(availableAfter.isEmpty,
                             "Iteration \(iteration): No weeks should be available after deletion")
            } catch {
                XCTFail("Iteration \(iteration): Deletion test failed with error: \(error)")
            }
        }
    }

    // MARK: - Generators

    private func generateRandomRoastCache() -> WeeklyRoastCache {
        WeeklyRoastCache(
            leagueId: "league_\(UUID().uuidString)",
            weekNumber: Int.random(in: 1...18),
            generatedAt: Date().addingTimeInterval(Double.random(in: -604800...0)),
            roasts: generateRandomRoasts()
        )
    }

    private func generateRandomRoasts() -> [String: String] {
        let teamCount = Int.random(in: 1...14)
        var roasts: [String: String] = [:]
        for i in 0..<teamCount {
            roasts["team_\(i)_\(UUID().uuidString)"] = randomString(length: Int.random(in: 20...200))
        }
        return roasts
    }

    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
