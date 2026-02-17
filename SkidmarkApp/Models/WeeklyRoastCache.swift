import Foundation

struct WeeklyRoastCache: Codable {
    let leagueId: String
    let weekNumber: Int
    let generatedAt: Date
    let roasts: [String: String]
    /// Snapshot of team data at the time roasts were generated, enabling
    /// accurate record display when navigating to past weeks.
    let teamSnapshot: [Team]?
    /// The roast input hash at generation time, used to skip redundant regeneration
    let roastHash: Int?
    
    /// Backward-compatible initializer that defaults teamSnapshot and roastHash to nil
    init(leagueId: String, weekNumber: Int, generatedAt: Date, roasts: [String: String], teamSnapshot: [Team]? = nil, roastHash: Int? = nil) {
        self.leagueId = leagueId
        self.weekNumber = weekNumber
        self.generatedAt = generatedAt
        self.roasts = roasts
        self.teamSnapshot = teamSnapshot
        self.roastHash = roastHash
    }
}
