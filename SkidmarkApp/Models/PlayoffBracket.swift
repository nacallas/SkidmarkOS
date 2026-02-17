import Foundation

struct PlayoffBracketEntry: Codable, Hashable {
    let teamId: String
    let seed: Int
    let currentRound: Int
    let opponentTeamId: String?
    let isEliminated: Bool
    let isConsolation: Bool
    let isChampionship: Bool
}
