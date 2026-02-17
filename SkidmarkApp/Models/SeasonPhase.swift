import Foundation

enum SeasonPhase: String, Codable {
    case regularSeason
    case playoffs
    case offseason
}

enum SeasonPhaseDetector {
    /// Detects the current season phase using league settings and the real-world date.
    /// During the NFL offseason (roughly Feb through early Sep), returns `.offseason`
    /// regardless of what the API reports for currentWeek, since those values are stale
    /// from the previous completed season.
    static func detect(currentWeek: Int, playoffStartWeek: Int, now: Date = Date()) -> SeasonPhase {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        
        // NFL offseason: February through August
        // September onward is active season
        if month >= 2 && month <= 8 {
            return .offseason
        }
        
        return currentWeek >= playoffStartWeek ? .playoffs : .regularSeason
    }
}
