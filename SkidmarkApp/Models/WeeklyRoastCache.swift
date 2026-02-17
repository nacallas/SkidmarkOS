import Foundation

struct WeeklyRoastCache: Codable {
    let leagueId: String
    let weekNumber: Int
    let generatedAt: Date
    let roasts: [String: String]
}
