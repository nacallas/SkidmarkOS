import Foundation

struct Team: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let ownerName: String
    let wins: Int
    let losses: Int
    let ties: Int
    let pointsFor: Double
    let pointsAgainst: Double
    var powerScore: Double
    var rank: Int
    let streak: Streak
    let topPlayers: [Player]
    var roast: String?
    
    struct Streak: Codable, Hashable {
        let type: StreakType
        let length: Int
        
        enum StreakType: String, Codable {
            case win = "W"
            case loss = "L"
        }
        
        var displayString: String {
            "\(type.rawValue)\(length)"
        }
    }
    
    var record: String {
        ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)"
    }
    
    var winPercentage: Double {
        let totalGames = Double(wins + losses + ties)
        guard totalGames > 0 else { return 0 }
        return (Double(wins) + Double(ties) * 0.5) / totalGames
    }
    
    // Custom hash that excludes roast and rank (which change independently)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(ownerName)
        hasher.combine(wins)
        hasher.combine(losses)
        hasher.combine(ties)
        hasher.combine(pointsFor)
        hasher.combine(pointsAgainst)
        hasher.combine(powerScore)
        hasher.combine(streak)
        hasher.combine(topPlayers)
    }
    
    // Custom equality that excludes roast and rank
    static func == (lhs: Team, rhs: Team) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.ownerName == rhs.ownerName &&
        lhs.wins == rhs.wins &&
        lhs.losses == rhs.losses &&
        lhs.ties == rhs.ties &&
        lhs.pointsFor == rhs.pointsFor &&
        lhs.pointsAgainst == rhs.pointsAgainst &&
        lhs.powerScore == rhs.powerScore &&
        lhs.streak == rhs.streak &&
        lhs.topPlayers == rhs.topPlayers
    }
}

struct Player: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let position: String
    let points: Double
}
