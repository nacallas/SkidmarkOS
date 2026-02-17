import Foundation

struct WeeklyMatchup: Codable, Hashable {
    let weekNumber: Int
    let homeTeamId: String
    let awayTeamId: String
    let homeScore: Double
    let awayScore: Double
    let homePlayers: [WeeklyPlayerStats]
    let awayPlayers: [WeeklyPlayerStats]
}

struct WeeklyPlayerStats: Codable, Hashable {
    let playerId: String
    let name: String
    let position: String
    let points: Double
    let isStarter: Bool
}
