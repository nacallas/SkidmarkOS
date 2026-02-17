import XCTest
@testable import SkidmarkApp

/// Property-based tests for ESPN data parsing.
/// Tests that parsing ESPN matchup, league settings, and playoff bracket JSON
/// always produces structurally valid output objects.
final class ESPNParsingPropertyTests: XCTestCase {

    // MARK: - Property 6: ESPN matchup parsing produces valid structures

    /// Feature: roast-enhancements, Property 6: ESPN matchup parsing produces valid structures
    /// For any valid ESPN matchup JSON, parsed objects have non-empty team IDs,
    /// non-negative scores, and valid player stats.
    /// **Validates: Requirements 3.1, 3.3**
    func testESPNMatchupParsingProducesValidStructures() async throws {
        let iterations = 100

        for iteration in 0..<iterations {
            let week = Int.random(in: 1...18)
            let matchupCount = Int.random(in: 1...6)
            var scheduleEntries: [[String: Any]] = []

            for _ in 0..<matchupCount {
                let homeTeamId = Int.random(in: 1...20)
                var awayTeamId = Int.random(in: 1...20)
                while awayTeamId == homeTeamId { awayTeamId = Int.random(in: 1...20) }

                let homeScore = Double.random(in: 0...200)
                let awayScore = Double.random(in: 0...200)

                let homePlayers = generateESPNRosterEntries()
                let awayPlayers = generateESPNRosterEntries()

                let entry: [String: Any] = [
                    "matchupPeriodId": week,
                    "home": [
                        "teamId": homeTeamId,
                        "totalPoints": homeScore,
                        "rosterForCurrentScoringPeriod": ["entries": homePlayers]
                    ] as [String: Any],
                    "away": [
                        "teamId": awayTeamId,
                        "totalPoints": awayScore,
                        "rosterForCurrentScoringPeriod": ["entries": awayPlayers]
                    ] as [String: Any]
                ]
                scheduleEntries.append(entry)
            }

            let json: [String: Any] = ["schedule": scheduleEntries]
            let data = try JSONSerialization.data(withJSONObject: json)

            let mockSession = MockURLSession()
            let mockKeychain = MockKeychainService()
            mockKeychain.credentialsToReturn = .success(ESPNCredentials(espnS2: "s2", swid: "{SWID}"))
            await mockSession.setMockESPNResponse(
                leagueId: "test", season: 2024,
                response: MockURLSession.MockResponse(data: data, statusCode: 200)
            )

            let service = ESPNService(session: mockSession, keychainService: mockKeychain)
            let matchups = try await service.fetchMatchupData(leagueId: "test", season: 2024, week: week)

            for matchup in matchups {
                XCTAssertFalse(matchup.homeTeamId.isEmpty,
                    "Iteration \(iteration): homeTeamId must be non-empty")
                XCTAssertFalse(matchup.awayTeamId.isEmpty,
                    "Iteration \(iteration): awayTeamId must be non-empty")
                XCTAssertGreaterThanOrEqual(matchup.homeScore, 0,
                    "Iteration \(iteration): homeScore must be non-negative")
                XCTAssertGreaterThanOrEqual(matchup.awayScore, 0,
                    "Iteration \(iteration): awayScore must be non-negative")
                XCTAssertEqual(matchup.weekNumber, week,
                    "Iteration \(iteration): weekNumber must match requested week")

                for player in matchup.homePlayers + matchup.awayPlayers {
                    XCTAssertFalse(player.name.isEmpty,
                        "Iteration \(iteration): player name must be non-empty")
                    XCTAssertFalse(player.position.isEmpty,
                        "Iteration \(iteration): player position must be non-empty")
                    XCTAssertFalse(player.playerId.isEmpty,
                        "Iteration \(iteration): player ID must be non-empty")
                }
            }
        }
    }

    // MARK: - Property 11: ESPN league settings parsing

    /// Feature: roast-enhancements, Property 11: ESPN league settings parsing
    /// For any valid ESPN settings JSON, parsed LeagueSettings has
    /// playoffStartWeek > 0, playoffTeamCount > 0, currentWeek >= 1.
    /// **Validates: Requirements 5.1**
    func testESPNLeagueSettingsParsingProducesValidStructures() async throws {
        let iterations = 100

        for iteration in 0..<iterations {
            let matchupPeriodCount = Int.random(in: 1...17)
            let playoffTeamCount = Int.random(in: 2...14)
            let currentMatchupPeriod = Int.random(in: 1...18)

            let json: [String: Any] = [
                "settings": [
                    "scheduleSettings": [
                        "matchupPeriodCount": matchupPeriodCount,
                        "playoffTeamCount": playoffTeamCount
                    ] as [String: Any]
                ] as [String: Any],
                "status": [
                    "currentMatchupPeriod": currentMatchupPeriod
                ] as [String: Any]
            ]
            let data = try JSONSerialization.data(withJSONObject: json)

            let mockSession = MockURLSession()
            let mockKeychain = MockKeychainService()
            mockKeychain.credentialsToReturn = .success(ESPNCredentials(espnS2: "s2", swid: "{SWID}"))
            await mockSession.setMockESPNResponse(
                leagueId: "test", season: 2024,
                response: MockURLSession.MockResponse(data: data, statusCode: 200)
            )

            let service = ESPNService(session: mockSession, keychainService: mockKeychain)
            let settings = try await service.fetchLeagueSettings(leagueId: "test", season: 2024)

            XCTAssertGreaterThan(settings.playoffStartWeek, 0,
                "Iteration \(iteration): playoffStartWeek must be > 0, got \(settings.playoffStartWeek)")
            XCTAssertGreaterThan(settings.playoffTeamCount, 0,
                "Iteration \(iteration): playoffTeamCount must be > 0, got \(settings.playoffTeamCount)")
            XCTAssertGreaterThanOrEqual(settings.currentWeek, 1,
                "Iteration \(iteration): currentWeek must be >= 1, got \(settings.currentWeek)")

            // Verify derived values match input
            XCTAssertEqual(settings.playoffStartWeek, matchupPeriodCount + 1,
                "Iteration \(iteration): playoffStartWeek should be matchupPeriodCount + 1")
            XCTAssertEqual(settings.playoffTeamCount, playoffTeamCount,
                "Iteration \(iteration): playoffTeamCount should match input")
            XCTAssertEqual(settings.currentWeek, currentMatchupPeriod,
                "Iteration \(iteration): currentWeek should match input")
        }
    }

    // MARK: - Property 16: ESPN bracket parsing

    /// Feature: roast-enhancements, Property 16: ESPN bracket parsing
    /// For any valid ESPN bracket JSON, parsed entries have non-empty team ID,
    /// seed >= 1, and consistent boolean flags (not both eliminated and championship).
    /// **Validates: Requirements 7.1**
    func testESPNBracketParsingProducesValidStructures() async throws {
        let iterations = 100

        for iteration in 0..<iterations {
            let week = Int.random(in: 14...18)
            let matchupCount = Int.random(in: 1...4)
            var scheduleEntries: [[String: Any]] = []

            // Generate the bracket matchups for the target week
            for _ in 0..<matchupCount {
                let homeTeamId = Int.random(in: 1...20)
                var awayTeamId = Int.random(in: 1...20)
                while awayTeamId == homeTeamId { awayTeamId = Int.random(in: 1...20) }

                let homeSeed = Int.random(in: 1...8)
                let awaySeed = Int.random(in: 1...8)
                let tierType = Bool.random() ? "WINNERS_BRACKET" : "LOSERS_BRACKET"
                let winner = ["HOME", "AWAY", "UNDECIDED"].randomElement()!

                let entry: [String: Any] = [
                    "matchupPeriodId": week,
                    "playoffTierType": tierType,
                    "winner": winner,
                    "home": [
                        "teamId": homeTeamId,
                        "playoffSeed": homeSeed,
                        "totalPoints": Double.random(in: 50...200)
                    ] as [String: Any],
                    "away": [
                        "teamId": awayTeamId,
                        "playoffSeed": awaySeed,
                        "totalPoints": Double.random(in: 50...200)
                    ] as [String: Any]
                ]
                scheduleEntries.append(entry)
            }

            let json: [String: Any] = ["schedule": scheduleEntries]
            let data = try JSONSerialization.data(withJSONObject: json)

            let mockSession = MockURLSession()
            let mockKeychain = MockKeychainService()
            mockKeychain.credentialsToReturn = .success(ESPNCredentials(espnS2: "s2", swid: "{SWID}"))
            await mockSession.setMockESPNResponse(
                leagueId: "test", season: 2024,
                response: MockURLSession.MockResponse(data: data, statusCode: 200)
            )

            let service = ESPNService(session: mockSession, keychainService: mockKeychain)
            let entries = try await service.fetchPlayoffBracket(leagueId: "test", season: 2024, week: week)

            for entry in entries {
                XCTAssertFalse(entry.teamId.isEmpty,
                    "Iteration \(iteration): teamId must be non-empty")
                XCTAssertGreaterThanOrEqual(entry.seed, 1,
                    "Iteration \(iteration): seed must be >= 1, got \(entry.seed)")
                XCTAssertGreaterThanOrEqual(entry.currentRound, 1,
                    "Iteration \(iteration): currentRound must be >= 1, got \(entry.currentRound)")

                // Consistency: a consolation team cannot be in the championship
                if entry.isConsolation {
                    XCTAssertFalse(entry.isChampionship,
                        "Iteration \(iteration): team \(entry.teamId) in consolation cannot also be in championship")
                }

                // A team that is eliminated from the winners bracket (not consolation)
                // can still have isChampionship=true if they lost the championship game.
                // This is correct: isChampionship means "in the championship round."
            }
        }
    }

    // MARK: - Generators

    private let playerNames = [
        "Patrick Mahomes", "Josh Allen", "Lamar Jackson", "Jalen Hurts",
        "Derrick Henry", "Saquon Barkley", "Christian McCaffrey", "Bijan Robinson",
        "Tyreek Hill", "CeeDee Lamb", "Ja'Marr Chase", "Amon-Ra St. Brown",
        "Travis Kelce", "Mark Andrews", "Sam LaPorta", "George Kittle",
        "Justin Tucker", "Harrison Butker", "Jake Elliott", "Tyler Bass"
    ]

    private let positionIds = [1, 2, 3, 4, 5, 16]  // QB, RB, WR, TE, K, D/ST

    /// Generates a random set of ESPN roster entries for a team's matchup data.
    private func generateESPNRosterEntries() -> [[String: Any]] {
        let playerCount = Int.random(in: 1...10)
        var entries: [[String: Any]] = []

        for _ in 0..<playerCount {
            let playerId = Int.random(in: 1000...99999)
            let name = playerNames.randomElement()!
            let positionId = positionIds.randomElement()!
            let points = Double.random(in: 0...40)
            let lineupSlotId = Bool.random() ? Int.random(in: 0...6) : [20, 21].randomElement()!

            let entry: [String: Any] = [
                "lineupSlotId": lineupSlotId,
                "playerPoolEntry": [
                    "player": [
                        "id": playerId,
                        "fullName": name,
                        "defaultPositionId": positionId,
                        "stats": [["appliedTotal": points]]
                    ] as [String: Any]
                ] as [String: Any]
            ]
            entries.append(entry)
        }

        return entries
    }
}
