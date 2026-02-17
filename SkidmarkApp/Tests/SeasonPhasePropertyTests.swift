import XCTest
@testable import SkidmarkApp

// Feature: roast-enhancements, Property 13: Season phase detection
// **Validates: Requirements 5.3, 5.4**

/// Property-based test for SeasonPhaseDetector.
/// For any (currentWeek, playoffStartWeek) pair where both >= 1,
/// detect returns .regularSeason iff currentWeek < playoffStartWeek.
final class SeasonPhasePropertyTests: XCTestCase {

    func testSeasonPhaseDetection() {
        let iterations = 200

        for _ in 0..<iterations {
            let currentWeek = Int.random(in: 1...30)
            let playoffStartWeek = Int.random(in: 1...30)

            let result = SeasonPhaseDetector.detect(
                currentWeek: currentWeek,
                playoffStartWeek: playoffStartWeek
            )

            if currentWeek < playoffStartWeek {
                XCTAssertEqual(result, .regularSeason,
                    "currentWeek=\(currentWeek) < playoffStartWeek=\(playoffStartWeek) should be .regularSeason, got \(result)")
            } else {
                XCTAssertEqual(result, .playoffs,
                    "currentWeek=\(currentWeek) >= playoffStartWeek=\(playoffStartWeek) should be .playoffs, got \(result)")
            }
        }
    }

    /// Boundary: when currentWeek == playoffStartWeek, result is .playoffs
    func testBoundaryCurrentWeekEqualsPlayoffStart() {
        for week in 1...20 {
            let result = SeasonPhaseDetector.detect(currentWeek: week, playoffStartWeek: week)
            XCTAssertEqual(result, .playoffs,
                "currentWeek == playoffStartWeek (\(week)) should be .playoffs")
        }
    }

    /// Boundary: week just before playoffs is regular season
    func testBoundaryOneWeekBeforePlayoffs() {
        for playoffStart in 2...20 {
            let result = SeasonPhaseDetector.detect(currentWeek: playoffStart - 1, playoffStartWeek: playoffStart)
            XCTAssertEqual(result, .regularSeason,
                "currentWeek=\(playoffStart - 1) should be .regularSeason when playoffStartWeek=\(playoffStart)")
        }
    }
}
