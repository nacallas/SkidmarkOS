import Foundation

struct League: Identifiable, Codable {
    let id: String
    let name: String
    let platform: Platform
    let seasonYear: Int
    let teamCount: Int
    
    enum Platform: String, Codable {
        case espn = "ESPN"
        case sleeper = "Sleeper"
    }
}

struct LeagueConnection: Identifiable, Codable, Hashable {
    let id: String
    let leagueId: String
    let platform: League.Platform
    let leagueName: String
    let lastUpdated: Date
    let hasAuthentication: Bool
}
