import Foundation

/// Centralized fantasy football season year calculation.
/// ESPN keys seasons by the year the NFL season starts (e.g. the 2025-2026 season is "2025").
/// Before the new season begins in September, we reference the previous year's season.
enum SeasonHelper {
    /// Returns the correct ESPN fantasy football season year for the current date.
    static func currentFantasyFootballSeason(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        // Off-season: January through August → use previous year's season
        if month < 9 {
            return year - 1
        }
        return year
    }
}
