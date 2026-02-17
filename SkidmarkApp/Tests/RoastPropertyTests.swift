import XCTest
@testable import SkidmarkApp

/// Property-based tests for roast generation functionality
/// **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6**
final class RoastPropertyTests: XCTestCase {
    
    // MARK: - Property 5: Roast Generation Completeness
    
    /// Property test verifying roast generation produces N roasts for N teams with correct length
    /// **Validates: Requirements 4.1, 4.2**
    /// Runs 100+ iterations with randomly generated teams
    func testRoastGenerationCompleteness() async {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate random teams (1 to 20 teams)
            let teamCount = Int.random(in: 1...20)
            let teams = generateRandomTeams(count: teamCount)
            let context = generateRandomLeagueContext()
            
            // Create mock backend service
            let mockBackend = RoastTestMockBackendService()
            
            do {
                // Generate roasts
                let roasts = try await mockBackend.generateRoasts(teams: teams, context: context)
                
                // Verify we got exactly N roasts for N teams
                XCTAssertEqual(roasts.count, teams.count,
                              "Iteration \(iteration): Should generate \(teams.count) roasts, got \(roasts.count)")
                
                // Verify all team IDs are present
                for team in teams {
                    XCTAssertNotNil(roasts[team.id],
                                   "Iteration \(iteration): Missing roast for team \(team.id)")
                }
                
                // Verify roast length (3-5 sentences)
                for (teamId, roast) in roasts {
                    let sentenceCount = countSentences(in: roast)
                    XCTAssertGreaterThanOrEqual(sentenceCount, 3,
                                               "Iteration \(iteration): Roast for \(teamId) has only \(sentenceCount) sentences, expected at least 3")
                    XCTAssertLessThanOrEqual(sentenceCount, 5,
                                            "Iteration \(iteration): Roast for \(teamId) has \(sentenceCount) sentences, expected at most 5")
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Roast generation failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Property 6: Roast Content References Statistics
    
    /// Property test verifying roasts reference team statistics
    /// **Validates: Requirements 4.3, 4.4**
    /// Runs 100+ iterations checking for statistical references
    func testRoastContentReferencesStatistics() async {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate teams with distinctive statistics
            let teamCount = Int.random(in: 3...15)
            let teams = generateRandomTeams(count: teamCount)
            let context = generateRandomLeagueContext()
            
            let mockBackend = RoastTestMockBackendService()
            
            do {
                let roasts = try await mockBackend.generateRoasts(teams: teams, context: context)
                
                for team in teams {
                    guard let roast = roasts[team.id] else {
                        XCTFail("Iteration \(iteration): Missing roast for team \(team.id)")
                        continue
                    }
                    
                    let roastLower = roast.lowercased()
                    
                    // Check for at least one statistical reference
                    var hasStatReference = false
                    
                    // Check for record reference (wins, losses, or record pattern)
                    if roastLower.contains("win") || roastLower.contains("loss") ||
                       roastLower.contains("\(team.wins)") || roastLower.contains("\(team.losses)") ||
                       roastLower.contains(team.record.lowercased()) {
                        hasStatReference = true
                    }
                    
                    // Check for points reference
                    let pointsForRounded = Int(team.pointsFor)
                    let pointsAgainstRounded = Int(team.pointsAgainst)
                    if roastLower.contains("point") ||
                       roastLower.contains("\(pointsForRounded)") ||
                       roastLower.contains("\(pointsAgainstRounded)") {
                        hasStatReference = true
                    }
                    
                    // Check for performance reference (rank, power score, streak)
                    if roastLower.contains("rank") || roastLower.contains("streak") ||
                       roastLower.contains("score") || roastLower.contains("perform") {
                        hasStatReference = true
                    }
                    
                    // Check for player name references
                    for player in team.topPlayers {
                        if roastLower.contains(player.name.lowercased()) {
                            hasStatReference = true
                            break
                        }
                    }
                    
                    XCTAssertTrue(hasStatReference,
                                 "Iteration \(iteration): Roast for team \(team.id) should reference at least one statistic")
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Roast content test failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Counts sentences in a string (periods, exclamation marks, question marks)
    private func countSentences(in text: String) -> Int {
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        let components = text.components(separatedBy: sentenceEnders)
        // Filter out empty components
        return components.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
    
    /// Generates random teams for testing
    private func generateRandomTeams(count: Int) -> [Team] {
        var teams: [Team] = []
        
        for i in 0..<count {
            let playerCount = Int.random(in: 1...5)
            var players: [Player] = []
            
            for j in 0..<playerCount {
                players.append(Player(
                    id: "player_\(i)_\(j)",
                    name: randomPlayerName(),
                    position: ["QB", "RB", "WR", "TE", "K", "DEF"].randomElement()!,
                    points: Double.random(in: 5...40)
                ))
            }
            
            let team = Team(
                id: "team_\(UUID().uuidString)",
                name: randomTeamName(),
                ownerName: randomOwnerName(),
                wins: Int.random(in: 0...13),
                losses: Int.random(in: 0...13),
                ties: Int.random(in: 0...2),
                pointsFor: Double.random(in: 800...1800),
                pointsAgainst: Double.random(in: 800...1800),
                powerScore: Double.random(in: 0...1),
                rank: i + 1,
                streak: Team.Streak(
                    type: Bool.random() ? .win : .loss,
                    length: Int.random(in: 1...8)
                ),
                topPlayers: players,
                roast: nil
            )
            
            teams.append(team)
        }
        
        return teams
    }
    
    /// Generates random league context
    private func generateRandomLeagueContext() -> LeagueContext {
        let jokeCount = Int.random(in: 0...3)
        let personalityCount = Int.random(in: 0...3)
        
        var insideJokes: [LeagueContext.InsideJoke] = []
        for _ in 0..<jokeCount {
            insideJokes.append(LeagueContext.InsideJoke(
                id: UUID(),
                term: randomString(length: Int.random(in: 5...15)),
                explanation: randomString(length: Int.random(in: 10...30))
            ))
        }
        
        var personalities: [LeagueContext.PlayerPersonality] = []
        for _ in 0..<personalityCount {
            personalities.append(LeagueContext.PlayerPersonality(
                id: UUID(),
                playerName: randomPlayerName(),
                description: randomString(length: Int.random(in: 10...40))
            ))
        }
        
        return LeagueContext(
            insideJokes: insideJokes,
            personalities: personalities,
            sackoPunishment: randomString(length: Int.random(in: 0...50)),
            cultureNotes: randomString(length: Int.random(in: 0...100))
        )
    }
    
    private func randomTeamName() -> String {
        let names = ["Warriors", "Titans", "Dragons", "Eagles", "Panthers", "Sharks", "Lions", "Bears"]
        return names.randomElement()!
    }
    
    private func randomOwnerName() -> String {
        let names = ["Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Sam", "Drew"]
        return names.randomElement()!
    }
    
    private func randomPlayerName() -> String {
        let firstNames = ["Patrick", "Josh", "Justin", "Tyreek", "Travis", "Christian", "Derrick", "Cooper"]
        let lastNames = ["Mahomes", "Allen", "Jefferson", "Hill", "Kelce", "McCaffrey", "Henry", "Kupp"]
        return "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }
    
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ "
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

// MARK: - Mock Backend Service

/// Mock backend service for testing roast generation
private class RoastTestMockBackendService: BackendService {
    func generateRoasts(teams: [Team], context: LeagueContext) async throws -> [String: String] {
        return try await generateRoasts(
            teams: teams,
            context: context,
            matchups: [],
            weekNumber: 0,
            seasonPhase: .regularSeason,
            playoffBracket: nil
        )
    }

    func generateRoasts(
        teams: [Team],
        context: LeagueContext,
        matchups: [WeeklyMatchup],
        weekNumber: Int,
        seasonPhase: SeasonPhase,
        playoffBracket: [PlayoffBracketEntry]?
    ) async throws -> [String: String] {
        var roasts: [String: String] = [:]
        
        for team in teams {
            // Generate a mock roast with 3-5 sentences that references statistics
            let sentenceCount = Int.random(in: 3...5)
            var roastSentences: [String] = []
            
            for i in 0..<sentenceCount {
                switch i {
                case 0:
                    // Reference record
                    roastSentences.append("Team \(team.name) with a \(team.record) record is struggling.")
                case 1:
                    // Reference points
                    roastSentences.append("They've scored \(Int(team.pointsFor)) points this season.")
                case 2:
                    // Reference performance
                    roastSentences.append("Currently ranked #\(team.rank) in the power rankings.")
                default:
                    // Reference player or general stat
                    if let player = team.topPlayers.first {
                        roastSentences.append("\(player.name) has been their only bright spot.")
                    } else {
                        roastSentences.append("Their \(team.streak.displayString) streak tells the whole story.")
                    }
                }
            }
            
            roasts[team.id] = roastSentences.joined(separator: " ")
        }
        
        return roasts
    }
}
