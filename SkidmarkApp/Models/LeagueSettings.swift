import Foundation

struct LeagueSettings: Codable {
    let playoffStartWeek: Int
    let playoffTeamCount: Int
    let currentWeek: Int
    let totalRegularSeasonWeeks: Int
}
