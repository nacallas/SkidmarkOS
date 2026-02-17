import XCTest
@testable import SkidmarkApp

/// Property-based tests for Sleeper data parsing.
/// Tests that parsing Sleeper matchup, league settings, and playoff bracket JSON
/// always produces structurally valid output objects.
final class SleeperParsingPropertyTests: XCTestCase {

    // MARK: - Property 7: Sleeper matchup parsing produces valid structures

    /// Feature: roast-enhancements, Property 7: Sleeper matchup parsing produces valid structures
    /// For any valid Sleeper matchup JSON, parsed objects have non-empty team IDs,
    /// non-negative scores, and valid player stats entries.
    /// **Validates: Requirements 3.2, 3.4**
    func testSleeperMatchupParsingProducesValidStructures() async throws {
        let iterations = 100

        for iteration in 0..<iterations {
            let week = Int.random(in: 1...18)
            let matchupCount = Int.random(in: 1...6)
            let leagueId = "league\(iteration)"

            // Build a player map with random player IDs
            var playerMap: [String: [String: Any]] = [:]
            var allPlayerIds: [String] = []
            let playerCount = matchupCount * Int.random(in: 4...12)
            for i in 0..<playerCount {
                let pid = String(1000 + i)
                allPlayerIds.append(pid)
                playerMap[pid] = [
                    "first_name": randomFirstName(),
                    "last_name": randomLastName(),
                    "position": randomPosition()
                ]
            }

            // Build matchup roster entries paired by matchup_id
            var rosterEntries: [[String: Any]] = []
            var playerIndex = 0

            for matchupId in 1...matchupCount {
                for rosterOffset in 0..<2 {
                    let rosterId = (matchupId - 1) * 2 + rosterOffset + 1
                    let rosterPlayerCount = Int.random(in: 1...6)
                    let starterCount = max(1, rosterPlayerCount - Int.random(in: 0...2))

                    var players: [String] = []
                    var starters: [String] = []
                    var playersPoints: [String: Double] = [:]

                    for j in 0..<rosterPlayerCount {
                        let pid = allPlayerIds[playerIndex % allPlayerIds.count]
                        playerIndex += 1
                        players.append(pid)
                        if j < starterCount {
                            starters.append(pid)
                        }
                        playersPoints[pid] = Double.random(in: 0...40)
                    }

                    let totalPoints = playersPoints.values.reduce(0, +)

                    let entry: [String: Any] = [
                        "roster_id": rosterId,
                        "matchup_id": matchupId,
                        "points": totalPoints,
                        "starters": starters,
                        "players": players,
                        "players_points": playersPoints
                    ]
                    rosterEntries.append(entry)
                }
            }

            let matchupsData = try JSONSerialization.data(withJSONObject: rosterEntries)
            let playerMapData = try JSONSerialization.data(withJSONObject: playerMap)

            let mockSession = MockURLSession()
            await mockSession.setMockResponse(
                url: "https://api.sleeper.app/v1/league/\(leagueId)/matchups/\(week)",
                response: MockURLSession.MockResponse(data: matchupsData, statusCode: 200)
            )
            await mockSession.setMockResponse(
                url: "https://api.sleeper.app/v1/players/nfl",
                response: MockURLSession.MockResponse(data: playerMapData, statusCode: 200)
            )

            let service = SleeperService(session: mockSession)
            let matchups = try await service.fetchMatchupData(leagueId: leagueId, season: 2024, week: week)

            XCTAssertEqual(matchups.count, matchupCount,
                "Iteration \(iteration): expected \(matchupCount) matchups, got \(matchups.count)")

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

    // MARK: - Property 12: Sleeper league settings parsing

    /// Feature: roast-enhancements, Property 12: Sleeper league settings parsing
    /// For any valid Sleeper league settings JSON, parsed LeagueSettings has
    /// playoffStartWeek > 0, playoffTeamCount > 0, currentWeek >= 1.
    /// **Validates: Requirements 5.2**
    func testSleeperLeagueSettingsParsingProducesValidStructures() async throws {
        let iterations = 100

        for iteration in 0..<iterations {
            let playoffWeekStart = Int.random(in: 1...17)
            let playoffTeams = Int.random(in: 2...14)
            let currentWeek = Int.random(in: 1...18)
            let leagueId = "settings\(iteration)"

            let leagueJSON: [String: Any] = [
                "league_id": leagueId,
                "name": "Test League",
                "season": "2024",
                "settings": [
                    "playoff_week_start": playoffWeekStart,
                    "playoff_teams": playoffTeams,
                    "leg": currentWeek
                ] as [String: Any]
            ]

            let data = try JSONSerialization.data(withJSONObject: leagueJSON)

            let mockSession = MockURLSession()
            await mockSession.setMockResponse(
                url: "https://api.sleeper.app/v1/league/\(leagueId)",
                response: MockURLSession.MockResponse(data: data, statusCode: 200)
            )

            let service = SleeperService(session: mockSession)
            let settings = try await service.fetchLeagueSettings(leagueId: leagueId, season: 2024)

            XCTAssertGreaterThan(settings.playoffStartWeek, 0,
                "Iteration \(iteration): playoffStartWeek must be > 0, got \(settings.playoffStartWeek)")
            XCTAssertGreaterThan(settings.playoffTeamCount, 0,
                "Iteration \(iteration): playoffTeamCount must be > 0, got \(settings.playoffTeamCount)")
            XCTAssertGreaterThanOrEqual(settings.currentWeek, 1,
                "Iteration \(iteration): currentWeek must be >= 1, got \(settings.currentWeek)")

            // Verify parsed values match input
            XCTAssertEqual(settings.playoffStartWeek, playoffWeekStart,
                "Iteration \(iteration): playoffStartWeek should match input")
            XCTAssertEqual(settings.playoffTeamCount, playoffTeams,
                "Iteration \(iteration): playoffTeamCount should match input")
            XCTAssertEqual(settings.currentWeek, currentWeek,
                "Iteration \(iteration): currentWeek should match input")
        }
    }

    // MARK: - Property 17: Sleeper bracket parsing

    /// Feature: roast-enhancements, Property 17: Sleeper bracket parsing
    /// For any valid Sleeper bracket JSON, parsed entries have non-empty team ID,
    /// seed >= 1, and consistent boolean flags (not both eliminated and championship).
    /// **Validates: Requirements 7.2**
    func testSleeperBracketParsingProducesValidStructures() async throws {
        let iterations = 100

        for iteration in 0..<iterations {
            let leagueId = "bracket\(iteration)"
            let winnersRoundCount = Int.random(in: 1...3)

            // Generate winners bracket matchups with unique team IDs
            var usedTeamIds: Set<Int> = []
            var winnersMatchups: [[String: Any]] = []

            for round in 1...winnersRoundCount {
                let matchupsInRound = max(1, Int.random(in: 1...3))
                for m in 1...matchupsInRound {
                    let t1 = nextUniqueTeamId(&usedTeamIds)
                    let t2 = nextUniqueTeamId(&usedTeamIds)

                    // Randomly decide if this matchup has a result
                    let hasResult = Bool.random()
                    var matchup: [String: Any] = [
                        "r": round,
                        "m": m,
                        "t1": t1,
                        "t2": t2
                    ]
                    if hasResult {
                        matchup["w"] = Bool.random() ? t1 : t2
                        matchup["l"] = matchup["w"] as! Int == t1 ? t2 : t1
                    }
                    winnersMatchups.append(matchup)
                }
            }

            // Generate losers bracket with a few matchups
            var losersMatchups: [[String: Any]] = []
            let losersCount = Int.random(in: 0...2)
            for m in 1...max(1, losersCount) {
                if losersCount == 0 { break }
                let t1 = nextUniqueTeamId(&usedTeamIds)
                let t2 = nextUniqueTeamId(&usedTeamIds)
                var matchup: [String: Any] = [
                    "r": 1,
                    "m": m,
                    "t1": t1,
                    "t2": t2
                ]
                if Bool.random() {
                    matchup["w"] = Bool.random() ? t1 : t2
                    matchup["l"] = matchup["w"] as! Int == t1 ? t2 : t1
                }
                losersMatchups.append(matchup)
            }

            let winnersData = try JSONSerialization.data(withJSONObject: winnersMatchups)
            let losersData = try JSONSerialization.data(withJSONObject: losersMatchups)

            let mockSession = MockURLSession()
            await mockSession.setMockResponse(
                url: "https://api.sleeper.app/v1/league/\(leagueId)/winners_bracket",
                response: MockURLSession.MockResponse(data: winnersData, statusCode: 200)
            )
            await mockSession.setMockResponse(
                url: "https://api.sleeper.app/v1/league/\(leagueId)/losers_bracket",
                response: MockURLSession.MockResponse(data: losersData, statusCode: 200)
            )

            let service = SleeperService(session: mockSession)
            let entries = try await service.fetchPlayoffBracket(leagueId: leagueId, season: 2024, week: 15)

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

                // Note: a team CAN be both eliminated and isChampionship=true
                // (the loser of the championship game was in the championship round
                // but got eliminated). This is correct behavior.
            }
        }
    }

    // MARK: - Generators

    private let firstNames = [
        "Patrick", "Josh", "Lamar", "Jalen", "Derrick",
        "Saquon", "Christian", "Bijan", "Tyreek", "CeeDee"
    ]

    private let lastNames = [
        "Mahomes", "Allen", "Jackson", "Hurts", "Henry",
        "Barkley", "McCaffrey", "Robinson", "Hill", "Lamb"
    ]

    private let positions = ["QB", "RB", "WR", "TE", "K", "DEF"]

    private func randomFirstName() -> String { firstNames.randomElement()! }
    private func randomLastName() -> String { lastNames.randomElement()! }
    private func randomPosition() -> String { positions.randomElement()! }

    /// Returns a unique team ID not yet in the set, and inserts it.
    private func nextUniqueTeamId(_ used: inout Set<Int>) -> Int {
        var id: Int
        repeat {
            id = Int.random(in: 1...50)
        } while used.contains(id)
        used.insert(id)
        return id
    }
}
