import XCTest
import SwiftCheck
@testable import SkidmarkApp

final class DataPersistencePropertyTests: XCTestCase {
    
    // MARK: - Property 2: Data Persistence Round-Trip
    // **Validates: Requirements 1.6, 1.7, 5.5, 8.7, 10.1, 10.3, 10.4**
    
    func testLeagueConnectionRoundTrip() {
        property("LeagueConnection encodes and decodes without data loss") <- forAll { (connection: LeagueConnection) in
            guard let encoded = try? JSONEncoder().encode(connection),
                  let decoded = try? JSONDecoder().decode(LeagueConnection.self, from: encoded) else {
                return false
            }
            
            return connection.id == decoded.id &&
                   connection.leagueId == decoded.leagueId &&
                   connection.platform == decoded.platform &&
                   connection.leagueName == decoded.leagueName &&
                   abs(connection.lastUpdated.timeIntervalSince1970 - decoded.lastUpdated.timeIntervalSince1970) < 0.001 &&
                   connection.hasAuthentication == decoded.hasAuthentication
        }
    }
    
    func testLeagueContextRoundTrip() {
        property("LeagueContext encodes and decodes without data loss") <- forAll { (context: LeagueContext) in
            guard let encoded = try? JSONEncoder().encode(context),
                  let decoded = try? JSONDecoder().decode(LeagueContext.self, from: encoded) else {
                return false
            }
            
            return context.insideJokes.count == decoded.insideJokes.count &&
                   context.personalities.count == decoded.personalities.count &&
                   context.sackoPunishment == decoded.sackoPunishment &&
                   context.cultureNotes == decoded.cultureNotes &&
                   zip(context.insideJokes, decoded.insideJokes).allSatisfy { original, decoded in
                       original.id == decoded.id &&
                       original.term == decoded.term &&
                       original.explanation == decoded.explanation
                   } &&
                   zip(context.personalities, decoded.personalities).allSatisfy { original, decoded in
                       original.id == decoded.id &&
                       original.playerName == decoded.playerName &&
                       original.description == decoded.description
                   }
        }
    }
    
    func testTeamArrayRoundTrip() {
        property("Team array encodes and decodes without data loss") <- forAll { (teams: [Team]) in
            guard let encoded = try? JSONEncoder().encode(teams),
                  let decoded = try? JSONDecoder().decode([Team].self, from: encoded) else {
                return false
            }
            
            guard teams.count == decoded.count else { return false }
            
            return zip(teams, decoded).allSatisfy { original, decoded in
                original.id == decoded.id &&
                original.name == decoded.name &&
                original.ownerName == decoded.ownerName &&
                original.wins == decoded.wins &&
                original.losses == decoded.losses &&
                original.ties == decoded.ties &&
                abs(original.pointsFor - decoded.pointsFor) < 0.001 &&
                abs(original.pointsAgainst - decoded.pointsAgainst) < 0.001 &&
                abs(original.powerScore - decoded.powerScore) < 0.001 &&
                original.rank == decoded.rank &&
                original.streak.type == decoded.streak.type &&
                original.streak.length == decoded.streak.length &&
                original.topPlayers.count == decoded.topPlayers.count &&
                original.roast == decoded.roast &&
                zip(original.topPlayers, decoded.topPlayers).allSatisfy { origPlayer, decodedPlayer in
                    origPlayer.id == decodedPlayer.id &&
                    origPlayer.name == decodedPlayer.name &&
                    origPlayer.position == decodedPlayer.position &&
                    abs(origPlayer.points - decodedPlayer.points) < 0.001
                }
            }
        }
    }
}

// MARK: - SwiftCheck Arbitrary Generators

extension LeagueConnection: Arbitrary {
    public static var arbitrary: Gen<LeagueConnection> {
        Gen.compose { c in
            LeagueConnection(
                id: c.generate(),
                leagueId: c.generate(),
                platform: c.generate(),
                leagueName: c.generate(),
                lastUpdated: Date(timeIntervalSince1970: Double(c.generate(using: Int.arbitrary.suchThat { $0 > 0 && $0 < Int.max / 1000 }))),
                hasAuthentication: c.generate()
            )
        }
    }
}

extension League.Platform: Arbitrary {
    public static var arbitrary: Gen<League.Platform> {
        Gen.fromElements(of: [.espn, .sleeper])
    }
}

extension LeagueContext: Arbitrary {
    public static var arbitrary: Gen<LeagueContext> {
        Gen.compose { c in
            LeagueContext(
                insideJokes: c.generate(),
                personalities: c.generate(),
                sackoPunishment: c.generate(),
                cultureNotes: c.generate()
            )
        }
    }
}

extension LeagueContext.InsideJoke: Arbitrary {
    public static var arbitrary: Gen<LeagueContext.InsideJoke> {
        Gen.compose { c in
            LeagueContext.InsideJoke(
                id: UUID(),
                term: c.generate(),
                explanation: c.generate()
            )
        }
    }
}

extension LeagueContext.PlayerPersonality: Arbitrary {
    public static var arbitrary: Gen<LeagueContext.PlayerPersonality> {
        Gen.compose { c in
            LeagueContext.PlayerPersonality(
                id: UUID(),
                playerName: c.generate(),
                description: c.generate()
            )
        }
    }
}

extension Team: Arbitrary {
    public static var arbitrary: Gen<Team> {
        Gen.compose { c in
            Team(
                id: c.generate(),
                name: c.generate(),
                ownerName: c.generate(),
                wins: c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 20 }),
                losses: c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 20 }),
                ties: c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 5 }),
                pointsFor: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 3000 }),
                pointsAgainst: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 3000 }),
                powerScore: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 1 }),
                rank: c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 20 }),
                streak: c.generate(),
                topPlayers: c.generate(),
                roast: c.generate(using: Gen.frequency([
                    (1, Gen.pure(nil)),
                    (3, String.arbitrary.map { Optional($0) })
                ]))
            )
        }
    }
}

extension Team.Streak: Arbitrary {
    public static var arbitrary: Gen<Team.Streak> {
        Gen.compose { c in
            Team.Streak(
                type: c.generate(),
                length: c.generate(using: Int.arbitrary.suchThat { $0 >= 1 && $0 <= 10 })
            )
        }
    }
}

extension Team.Streak.StreakType: Arbitrary {
    public static var arbitrary: Gen<Team.Streak.StreakType> {
        Gen.fromElements(of: [.win, .loss])
    }
}

extension Player: Arbitrary {
    public static var arbitrary: Gen<Player> {
        Gen.compose { c in
            Player(
                id: c.generate(),
                name: c.generate(),
                position: c.generate(using: Gen.fromElements(of: ["QB", "RB", "WR", "TE", "K", "DEF"])),
                points: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 50 })
            )
        }
    }
}
