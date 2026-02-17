import Foundation

struct LeagueContext: Codable, Hashable {
    var insideJokes: [InsideJoke]
    var personalities: [PlayerPersonality]
    var sackoPunishment: String
    var cultureNotes: String
    
    struct InsideJoke: Identifiable, Codable, Hashable {
        let id: UUID
        var term: String
        var explanation: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(term)
            hasher.combine(explanation)
        }
        
        static func == (lhs: InsideJoke, rhs: InsideJoke) -> Bool {
            lhs.term == rhs.term && lhs.explanation == rhs.explanation
        }
    }
    
    struct PlayerPersonality: Identifiable, Codable, Hashable {
        let id: UUID
        var playerName: String
        var description: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(playerName)
            hasher.combine(description)
        }
        
        static func == (lhs: PlayerPersonality, rhs: PlayerPersonality) -> Bool {
            lhs.playerName == rhs.playerName && lhs.description == rhs.description
        }
    }
    
    static var empty: LeagueContext {
        LeagueContext(
            insideJokes: [],
            personalities: [],
            sackoPunishment: "",
            cultureNotes: ""
        )
    }
}
