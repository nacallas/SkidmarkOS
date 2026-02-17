import Foundation

enum SeasonPhase: String, Codable {
    case regularSeason
    case playoffs
}

enum SeasonPhaseDetector {
    static func detect(currentWeek: Int, playoffStartWeek: Int) -> SeasonPhase {
        currentWeek >= playoffStartWeek ? .playoffs : .regularSeason
    }
}
