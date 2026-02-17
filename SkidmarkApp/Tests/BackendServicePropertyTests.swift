import XCTest
@testable import SkidmarkApp

/// Property-based tests for BackendService enhanced request serialization.
/// Verifies that the JSON request body sent to the roast generation endpoint
/// contains all required keys for matchups, week number, season phase, and
/// (when present) playoff bracket data.
final class BackendServicePropertyTests: XCTestCase {

    // MARK: - Property 8: Enhanced request serialization includes all fields

    // Feature: roast-enhancements, Property 8: Enhanced request serialization includes all fields
    // Validates: Requirements 3.5, 5.5, 7.4

    /// For any roast generation request containing teams, context, matchups, week number,
    /// season phase, and an optional playoff bracket, the JSON-serialized request body should
    /// contain keys for `matchups`, `week_number`, `season_phase`, and (when bracket is non-nil)
    /// `playoff_bracket`.
    /// **Validates: Requirements 3.5, 5.5, 7.4**
    func testEnhancedRequestSerializationIncludesAllFields() async throws {
        let iterations = 100

        for iteration in 0..<iterations {
            // Generate random inputs
            let teams = generateRandomTeams(count: Int.random(in: 1...10))
            let context = generateRandomLeagueContext()
            let matchups = generateRandomMatchups(count: Int.random(in: 0...6))
            let weekNumber = Int.random(in: 1...18)
            let seasonPhase: SeasonPhase = Bool.random() ? .regularSeason : .playoffs
            let includeBracket = Bool.random()
            let playoffBracket: [PlayoffBracketEntry]? = includeBracket
                ? generateRandomBracketEntries(count: Int.random(in: 1...8))
                : nil

            // Set up mock session with a valid roast response
            let mockSession = MockURLSession()
            let roastResponse = buildMockRoastResponse(for: teams)
            let responseData = try JSONSerialization.data(withJSONObject: roastResponse)
            await mockSession.setMockResponse(
                url: "https://4kmztnypnd.execute-api.us-west-2.amazonaws.com/roasts/generate",
                response: MockURLSession.MockResponse(data: responseData, statusCode: 200)
            )

            let service = AWSBackendService(session: mockSession)

            // Call the enhanced generateRoasts
            _ = try await service.generateRoasts(
                teams: teams,
                context: context,
                matchups: matchups,
                weekNumber: weekNumber,
                seasonPhase: seasonPhase,
                playoffBracket: playoffBracket
            )

            // Capture and parse the serialized request body
            guard let request = await mockSession.getLastRequest(),
                  let body = request.httpBody else {
                XCTFail("Iteration \(iteration): No request body captured")
                continue
            }

            guard let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                XCTFail("Iteration \(iteration): Request body is not a JSON dictionary")
                continue
            }

            // Verify required keys are present
            XCTAssertNotNil(json["matchups"],
                "Iteration \(iteration): JSON must contain 'matchups' key")
            XCTAssertNotNil(json["week_number"],
                "Iteration \(iteration): JSON must contain 'week_number' key")
            XCTAssertNotNil(json["season_phase"],
                "Iteration \(iteration): JSON must contain 'season_phase' key")

            // Verify matchups is an array
            XCTAssertTrue(json["matchups"] is [Any],
                "Iteration \(iteration): 'matchups' should be an array")

            // Verify week_number value matches input
            if let serializedWeek = json["week_number"] as? Int {
                XCTAssertEqual(serializedWeek, weekNumber,
                    "Iteration \(iteration): week_number should match input")
            }

            // Verify season_phase value is a valid string
            if let serializedPhase = json["season_phase"] as? String {
                let validPhases = ["regular_season", "playoffs"]
                XCTAssertTrue(validPhases.contains(serializedPhase),
                    "Iteration \(iteration): season_phase '\(serializedPhase)' should be one of \(validPhases)")
            }

            // When playoff bracket is non-nil, verify playoff_bracket key is present
            if playoffBracket != nil {
                XCTAssertNotNil(json["playoff_bracket"],
                    "Iteration \(iteration): JSON must contain 'playoff_bracket' when bracket is non-nil")
                XCTAssertTrue(json["playoff_bracket"] is [Any],
                    "Iteration \(iteration): 'playoff_bracket' should be an array")
            }
        }
    }

    // MARK: - Generators

    private func generateRandomTeams(count: Int) -> [Team] {
        (0..<count).map { i in
            let playerCount = Int.random(in: 0...3)
            let players = (0..<playerCount).map { j in
                Player(
                    id: "p\(i)_\(j)",
                    name: ["Mahomes", "Allen", "Hill", "Kelce", "Henry"].randomElement()!,
                    position: ["QB", "RB", "WR", "TE", "K"].randomElement()!,
                    points: Double.random(in: 0...40)
                )
            }
            return Team(
                id: "team_\(i)",
                name: "Team \(i)",
                ownerName: "Owner \(i)",
                wins: Int.random(in: 0...13),
                losses: Int.random(in: 0...13),
                ties: Int.random(in: 0...2),
                pointsFor: Double.random(in: 500...2000),
                pointsAgainst: Double.random(in: 500...2000),
                powerScore: Double.random(in: 0...1),
                rank: i + 1,
                streak: Team.Streak(type: Bool.random() ? .win : .loss, length: Int.random(in: 1...8)),
                topPlayers: players,
                roast: nil
            )
        }
    }

    private func generateRandomLeagueContext() -> LeagueContext {
        LeagueContext(
            insideJokes: (0..<Int.random(in: 0...2)).map { _ in
                LeagueContext.InsideJoke(
                    id: UUID(),
                    term: randomString(length: Int.random(in: 3...10)),
                    explanation: randomString(length: Int.random(in: 5...20))
                )
            },
            personalities: (0..<Int.random(in: 0...2)).map { _ in
                LeagueContext.PlayerPersonality(
                    id: UUID(),
                    playerName: randomString(length: Int.random(in: 3...10)),
                    description: randomString(length: Int.random(in: 5...20))
                )
            },
            sackoPunishment: randomString(length: Int.random(in: 0...20)),
            cultureNotes: randomString(length: Int.random(in: 0...30))
        )
    }

    private func generateRandomMatchups(count: Int) -> [WeeklyMatchup] {
        (0..<count).map { _ in
            WeeklyMatchup(
                weekNumber: Int.random(in: 1...18),
                homeTeamId: "team_\(Int.random(in: 0...19))",
                awayTeamId: "team_\(Int.random(in: 0...19))",
                homeScore: Double.random(in: 50...200),
                awayScore: Double.random(in: 50...200),
                homePlayers: generateRandomPlayerStats(count: Int.random(in: 0...5)),
                awayPlayers: generateRandomPlayerStats(count: Int.random(in: 0...5))
            )
        }
    }

    private func generateRandomPlayerStats(count: Int) -> [WeeklyPlayerStats] {
        (0..<count).map { i in
            WeeklyPlayerStats(
                playerId: "player_\(i)_\(Int.random(in: 100...999))",
                name: ["Mahomes", "Allen", "Hill", "Kelce", "Henry", "Chase"].randomElement()!,
                position: ["QB", "RB", "WR", "TE"].randomElement()!,
                points: Double.random(in: 0...40),
                isStarter: Bool.random()
            )
        }
    }

    private func generateRandomBracketEntries(count: Int) -> [PlayoffBracketEntry] {
        (0..<count).map { i in
            let isConsolation = Bool.random()
            return PlayoffBracketEntry(
                teamId: "team_\(i)",
                seed: Int.random(in: 1...8),
                currentRound: Int.random(in: 1...3),
                opponentTeamId: Bool.random() ? "team_\(Int.random(in: 0...19))" : nil,
                isEliminated: Bool.random(),
                isConsolation: isConsolation,
                isChampionship: isConsolation ? false : Bool.random()
            )
        }
    }

    /// Builds a mock roast response JSON matching the expected response format.
    private func buildMockRoastResponse(for teams: [Team]) -> [String: Any] {
        var roasts: [String: String] = [:]
        for team in teams {
            roasts[team.id] = "Mock roast for \(team.name)"
        }
        return ["roasts": roasts]
    }

    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz "
        return String((0..<max(1, length)).map { _ in letters.randomElement()! })
    }
}
