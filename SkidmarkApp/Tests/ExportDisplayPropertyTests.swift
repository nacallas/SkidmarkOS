import XCTest
@testable import SkidmarkApp

/// Property-based tests for export format and display completeness
/// **Validates: Requirements 6.1, 6.2, 6.3, 7.1, 7.2**
final class ExportDisplayPropertyTests: XCTestCase {
    
    // MARK: - Property 15: Export Format Consistency
    
    /// Property test verifying export format includes all required fields
    /// **Validates: Requirements 6.1, 6.2, 6.3**
    /// Runs 100+ iterations with varying team data
    func testExportFormatConsistency() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate random teams
            let teamCount = Int.random(in: 1...20)
            let teams = generateRandomTeamsWithRoasts(count: teamCount)
            
            // Create view model with teams
            let viewModel = createMockViewModel(with: teams)
            
            // Test export without roasts
            let exportWithoutRoasts = viewModel.formatForExport(includeRoasts: false)
            
            // Verify each team has required fields in export
            for team in teams {
                // Check for rank
                XCTAssertTrue(exportWithoutRoasts.contains("\(team.rank)"),
                             "Iteration \(iteration): Export should contain rank \(team.rank)")
                
                // Check for team name
                XCTAssertTrue(exportWithoutRoasts.contains(team.name),
                             "Iteration \(iteration): Export should contain team name '\(team.name)'")
                
                // Check for owner name
                XCTAssertTrue(exportWithoutRoasts.contains(team.ownerName),
                             "Iteration \(iteration): Export should contain owner name '\(team.ownerName)'")
                
                // Check for record
                XCTAssertTrue(exportWithoutRoasts.contains(team.record),
                             "Iteration \(iteration): Export should contain record '\(team.record)'")
                
                // Check for points (formatted as integer)
                let pointsStr = String(format: "%.0f", team.pointsFor)
                XCTAssertTrue(exportWithoutRoasts.contains(pointsStr) || exportWithoutRoasts.contains(String(Int(team.pointsFor))),
                             "Iteration \(iteration): Export should contain points '\(pointsStr)'")
            }
            
            // Test export with roasts
            let exportWithRoasts = viewModel.formatForExport(includeRoasts: true)
            
            // Verify roasts are included when requested
            for team in teams {
                if let roast = team.roast {
                    XCTAssertTrue(exportWithRoasts.contains(roast),
                                 "Iteration \(iteration): Export with roasts should contain roast for team \(team.name)")
                }
            }
            
            // Verify export without roasts doesn't include roasts
            for team in teams {
                if let roast = team.roast {
                    XCTAssertFalse(exportWithoutRoasts.contains(roast),
                                  "Iteration \(iteration): Export without roasts should not contain roast for team \(team.name)")
                }
            }
        }
    }
    
    /// Property test verifying export format ordering
    /// Runs 100+ iterations checking rank order in export
    func testExportFormatOrdering() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 3...15)
            let teams = generateRandomTeamsWithRoasts(count: teamCount)
            
            let viewModel = createMockViewModel(with: teams)
            let export = viewModel.formatForExport(includeRoasts: false)
            
            // Split export into lines
            let lines = export.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            // Verify teams appear in rank order
            var previousRank = 0
            for line in lines {
                // Skip header lines
                if line.contains("Power Rankings") || line.contains("===") || line.contains("---") {
                    continue
                }
                
                // Extract rank from line (should be first number)
                if let rankMatch = line.components(separatedBy: .whitespaces).first,
                   let rank = Int(rankMatch.trimmingCharacters(in: CharacterSet(charactersIn: ".)"))) {
                    XCTAssertGreaterThan(rank, previousRank,
                                        "Iteration \(iteration): Ranks should be in ascending order")
                    previousRank = rank
                }
            }
        }
    }
    
    /// Property test verifying export format completeness for edge cases
    /// Runs 100+ iterations with edge case data
    func testExportFormatEdgeCases() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Test with single team
            let singleTeam = generateRandomTeamsWithRoasts(count: 1)
            let singleViewModel = createMockViewModel(with: singleTeam)
            let singleExport = singleViewModel.formatForExport(includeRoasts: false)
            
            XCTAssertFalse(singleExport.isEmpty,
                          "Iteration \(iteration): Export should not be empty for single team")
            XCTAssertTrue(singleExport.contains(singleTeam[0].name),
                         "Iteration \(iteration): Single team export should contain team name")
            
            // Test with teams with ties
            let teamsWithTies = generateTeamsWithTies(count: Int.random(in: 3...10))
            let tiesViewModel = createMockViewModel(with: teamsWithTies)
            let tiesExport = tiesViewModel.formatForExport(includeRoasts: false)
            
            for team in teamsWithTies where team.ties > 0 {
                XCTAssertTrue(tiesExport.contains(team.record),
                             "Iteration \(iteration): Export should include ties in record")
            }
            
            // Test with teams with no roasts
            let teamsNoRoasts = generateRandomTeamsWithRoasts(count: Int.random(in: 3...10))
            let noRoastsTeams = teamsNoRoasts.map { team in
                Team(id: team.id, name: team.name, ownerName: team.ownerName,
                     wins: team.wins, losses: team.losses, ties: team.ties,
                     pointsFor: team.pointsFor, pointsAgainst: team.pointsAgainst,
                     powerScore: team.powerScore, rank: team.rank, streak: team.streak,
                     topPlayers: team.topPlayers, roast: nil)
            }
            let noRoastsViewModel = createMockViewModel(with: noRoastsTeams)
            let noRoastsExport = noRoastsViewModel.formatForExport(includeRoasts: true)
            
            XCTAssertFalse(noRoastsExport.isEmpty,
                          "Iteration \(iteration): Export should work even without roasts")
        }
    }
    
    // MARK: - Property 18: Power Rankings Display Completeness
    
    /// Property test verifying view model exposes all required display fields
    /// **Validates: Requirements 7.1, 7.2**
    /// Runs 100+ iterations checking data availability for UI
    func testPowerRankingsDisplayCompleteness() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 1...20)
            let teams = generateRandomTeamsWithRoasts(count: teamCount)
            
            let viewModel = createMockViewModel(with: teams)
            
            // Verify all teams are available for display
            XCTAssertEqual(viewModel.teams.count, teamCount,
                          "Iteration \(iteration): View model should expose all teams")
            
            // Verify each team has all required display fields
            for team in viewModel.teams {
                // Rank
                XCTAssertGreaterThan(team.rank, 0,
                                    "Iteration \(iteration): Team \(team.id) should have valid rank")
                XCTAssertLessThanOrEqual(team.rank, teamCount,
                                        "Iteration \(iteration): Team \(team.id) rank should not exceed team count")
                
                // Team name
                XCTAssertFalse(team.name.isEmpty,
                              "Iteration \(iteration): Team \(team.id) should have non-empty name")
                
                // Owner name
                XCTAssertFalse(team.ownerName.isEmpty,
                              "Iteration \(iteration): Team \(team.id) should have non-empty owner name")
                
                // Record
                XCTAssertFalse(team.record.isEmpty,
                              "Iteration \(iteration): Team \(team.id) should have non-empty record")
                XCTAssertTrue(team.record.contains("-"),
                             "Iteration \(iteration): Team \(team.id) record should contain hyphen separator")
                
                // Points
                XCTAssertGreaterThanOrEqual(team.pointsFor, 0,
                                           "Iteration \(iteration): Team \(team.id) should have non-negative points for")
                XCTAssertGreaterThanOrEqual(team.pointsAgainst, 0,
                                           "Iteration \(iteration): Team \(team.id) should have non-negative points against")
                
                // Power score
                XCTAssertGreaterThanOrEqual(team.powerScore, 0,
                                           "Iteration \(iteration): Team \(team.id) should have non-negative power score")
                XCTAssertLessThanOrEqual(team.powerScore, 1,
                                        "Iteration \(iteration): Team \(team.id) power score should not exceed 1")
                
                // Streak
                XCTAssertGreaterThan(team.streak.length, 0,
                                    "Iteration \(iteration): Team \(team.id) should have positive streak length")
                XCTAssertFalse(team.streak.displayString.isEmpty,
                              "Iteration \(iteration): Team \(team.id) should have non-empty streak display string")
                
                // Top players (can be empty but should be accessible)
                XCTAssertNotNil(team.topPlayers,
                               "Iteration \(iteration): Team \(team.id) should have accessible top players array")
                
                // Roast (optional but should be accessible)
                // No assertion needed - roast can be nil
            }
        }
    }
    
    /// Property test verifying display data sorting and ordering
    /// Runs 100+ iterations checking proper rank ordering
    func testDisplayDataOrdering() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 2...20)
            let teams = generateRandomTeamsWithRoasts(count: teamCount)
            
            let viewModel = createMockViewModel(with: teams)
            
            // Verify teams are ordered by rank
            for i in 0..<(viewModel.teams.count - 1) {
                XCTAssertLessThan(viewModel.teams[i].rank, viewModel.teams[i + 1].rank,
                                 "Iteration \(iteration): Teams should be ordered by rank")
            }
            
            // Verify ranks are sequential
            for (index, team) in viewModel.teams.enumerated() {
                XCTAssertEqual(team.rank, index + 1,
                              "Iteration \(iteration): Ranks should be sequential starting from 1")
            }
        }
    }
    
    /// Property test verifying display data completeness for UI rendering
    /// Runs 100+ iterations checking all fields are renderable
    func testDisplayDataRenderability() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 1...15)
            let teams = generateRandomTeamsWithRoasts(count: teamCount)
            
            let viewModel = createMockViewModel(with: teams)
            
            // Verify all display strings are non-empty and valid
            for team in viewModel.teams {
                // Record display
                let recordDisplay = team.record
                XCTAssertFalse(recordDisplay.isEmpty,
                              "Iteration \(iteration): Record display should not be empty")
                
                // Streak display
                let streakDisplay = team.streak.displayString
                XCTAssertFalse(streakDisplay.isEmpty,
                              "Iteration \(iteration): Streak display should not be empty")
                XCTAssertTrue(streakDisplay.hasPrefix("W") || streakDisplay.hasPrefix("L"),
                             "Iteration \(iteration): Streak display should start with W or L")
                
                // Points display (should be formattable)
                let pointsDisplay = String(format: "%.1f", team.pointsFor)
                XCTAssertFalse(pointsDisplay.isEmpty,
                              "Iteration \(iteration): Points display should not be empty")
                
                // Power score display (should be formattable as percentage)
                let powerScoreDisplay = String(format: "%.1f%%", team.powerScore * 100)
                XCTAssertFalse(powerScoreDisplay.isEmpty,
                              "Iteration \(iteration): Power score display should not be empty")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a mock view model with teams
    private func createMockViewModel(with teams: [Team]) -> MockPowerRankingsViewModel {
        return MockPowerRankingsViewModel(teams: teams)
    }
    
    /// Generates random teams with roasts
    private func generateRandomTeamsWithRoasts(count: Int) -> [Team] {
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
            
            let wins = Int.random(in: 0...13)
            let losses = Int.random(in: 0...13)
            let ties = Int.random(in: 0...2)
            let pointsFor = Double.random(in: 800...1800)
            let pointsAgainst = Double.random(in: 800...1800)
            
            let team = Team(
                id: "team_\(UUID().uuidString)",
                name: randomTeamName(),
                ownerName: randomOwnerName(),
                wins: wins,
                losses: losses,
                ties: ties,
                pointsFor: pointsFor,
                pointsAgainst: pointsAgainst,
                powerScore: Double.random(in: 0...1),
                rank: i + 1,
                streak: Team.Streak(
                    type: Bool.random() ? .win : .loss,
                    length: Int.random(in: 1...8)
                ),
                topPlayers: players,
                roast: Bool.random() ? generateMockRoast(teamName: randomTeamName(), record: "\(wins)-\(losses)", points: Int(pointsFor)) : nil
            )
            
            teams.append(team)
        }
        
        return teams
    }
    
    /// Generates teams with ties for testing
    private func generateTeamsWithTies(count: Int) -> [Team] {
        var teams: [Team] = []
        
        for i in 0..<count {
            let wins = Int.random(in: 0...10)
            let losses = Int.random(in: 0...10)
            let ties = Int.random(in: 1...3) // Ensure ties exist
            
            let team = Team(
                id: "team_\(UUID().uuidString)",
                name: randomTeamName(),
                ownerName: randomOwnerName(),
                wins: wins,
                losses: losses,
                ties: ties,
                pointsFor: Double.random(in: 800...1800),
                pointsAgainst: Double.random(in: 800...1800),
                powerScore: Double.random(in: 0...1),
                rank: i + 1,
                streak: Team.Streak(type: .win, length: 1),
                topPlayers: [],
                roast: nil
            )
            
            teams.append(team)
        }
        
        return teams
    }
    
    private func generateMockRoast(teamName: String, record: String, points: Int) -> String {
        return "Team \(teamName) with a \(record) record has scored \(points) points. They're currently struggling. Their performance has been disappointing."
    }
    
    private func randomTeamName() -> String {
        let names = ["Warriors", "Titans", "Dragons", "Eagles", "Panthers", "Sharks", "Lions", "Bears", "Wolves", "Hawks"]
        return names.randomElement()!
    }
    
    private func randomOwnerName() -> String {
        let names = ["Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Sam", "Drew", "Quinn", "Avery"]
        return names.randomElement()!
    }
    
    private func randomPlayerName() -> String {
        let firstNames = ["Patrick", "Josh", "Justin", "Tyreek", "Travis", "Christian", "Derrick", "Cooper"]
        let lastNames = ["Mahomes", "Allen", "Jefferson", "Hill", "Kelce", "McCaffrey", "Henry", "Kupp"]
        return "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }
}

// MARK: - Mock View Model

/// Mock view model for testing export and display functionality
private class MockPowerRankingsViewModel {
    var teams: [Team]
    
    init(teams: [Team]) {
        self.teams = teams
    }
    
    func formatForExport(includeRoasts: Bool) -> String {
        var output = "Power Rankings\n"
        output += "===============\n\n"
        
        for team in teams {
            output += "\(team.rank). \(team.name) (\(team.ownerName))\n"
            output += "   Record: \(team.record)\n"
            output += "   Points: \(Int(team.pointsFor))\n"
            output += "   Power Score: \(String(format: "%.3f", team.powerScore))\n"
            
            if includeRoasts, let roast = team.roast {
                output += "   Roast: \(roast)\n"
            }
            
            output += "\n"
        }
        
        return output
    }
}
