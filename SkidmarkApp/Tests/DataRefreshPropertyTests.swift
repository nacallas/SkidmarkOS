import XCTest
@testable import SkidmarkApp

/// Property-based tests for data refresh and recalculation
/// **Validates: Requirements 3.1, 3.2, 3.3, 8.1, 8.2**
final class DataRefreshPropertyTests: XCTestCase {
    
    // MARK: - Property 14: Data Refresh Triggers Recalculation
    
    /// Property test verifying data refresh recalculates power scores correctly
    /// **Validates: Requirements 3.1, 3.2, 3.3, 8.1, 8.2**
    /// Runs 100+ iterations with different team data changes
    func testDataRefreshTriggersRecalculation() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate initial teams
            let teamCount = Int.random(in: 5...20)
            let initialTeams = generateRandomTeams(count: teamCount)
            
            // Calculate initial power rankings
            let initialRankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: initialTeams)
            
            // Store initial power scores
            var initialPowerScores: [String: Double] = [:]
            for team in initialRankedTeams {
                initialPowerScores[team.id] = team.powerScore
            }
            
            // Simulate data refresh by modifying team statistics
            let refreshedTeams = modifyTeamStatistics(teams: initialTeams)
            
            // Recalculate power rankings after refresh
            let refreshedRankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: refreshedTeams)
            
            // Verify power scores were recalculated
            var powerScoresChanged = false
            for team in refreshedRankedTeams {
                if let initialScore = initialPowerScores[team.id] {
                    // Check if the underlying data changed
                    let originalTeam = initialTeams.first { $0.id == team.id }!
                    let refreshedTeam = refreshedTeams.first { $0.id == team.id }!
                    
                    let dataChanged = originalTeam.wins != refreshedTeam.wins ||
                                     originalTeam.losses != refreshedTeam.losses ||
                                     originalTeam.ties != refreshedTeam.ties ||
                                     abs(originalTeam.pointsFor - refreshedTeam.pointsFor) > 0.01 ||
                                     abs(originalTeam.pointsAgainst - refreshedTeam.pointsAgainst) > 0.01
                    
                    if dataChanged {
                        // Power score should have changed
                        XCTAssertNotEqual(team.powerScore, initialScore, accuracy: 0.0001,
                                         "Iteration \(iteration): Power score for team \(team.id) should change when data changes")
                        powerScoresChanged = true
                    }
                }
            }
            
            // At least some power scores should have changed (since we modified data)
            XCTAssertTrue(powerScoresChanged,
                         "Iteration \(iteration): At least some power scores should change after data refresh")
            
            // Verify power scores are still correctly calculated
            let maxPF = refreshedTeams.map { $0.pointsFor }.max() ?? 1.0
            let maxPA = refreshedTeams.map { $0.pointsAgainst }.max() ?? 1.0
            
            for team in refreshedRankedTeams {
                let winPct = team.winPercentage
                let pfNormalized = team.pointsFor / maxPF
                let paNormalized = 1.0 - (team.pointsAgainst / maxPA)
                let expectedScore = (winPct * 0.6) + (pfNormalized * 0.3) + (paNormalized * 0.1)
                
                XCTAssertEqual(team.powerScore, expectedScore, accuracy: 0.0001,
                              "Iteration \(iteration): Recalculated power score should match formula")
            }
            
            // Verify ranks are recalculated (sequential from 1 to N)
            for (index, team) in refreshedRankedTeams.enumerated() {
                XCTAssertEqual(team.rank, index + 1,
                              "Iteration \(iteration): Ranks should be recalculated sequentially")
            }
        }
    }
    
    /// Property test verifying refresh maintains data integrity
    /// Runs 100+ iterations checking that refresh doesn't corrupt data
    func testDataRefreshMaintainsIntegrity() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 3...15)
            let teams = generateRandomTeams(count: teamCount)
            
            // Calculate rankings
            let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            
            // Verify all original data is preserved
            for (index, rankedTeam) in rankedTeams.enumerated() {
                let originalTeam = teams.first { $0.id == rankedTeam.id }!
                
                XCTAssertEqual(rankedTeam.id, originalTeam.id,
                              "Iteration \(iteration): Team ID should be preserved")
                XCTAssertEqual(rankedTeam.name, originalTeam.name,
                              "Iteration \(iteration): Team name should be preserved")
                XCTAssertEqual(rankedTeam.ownerName, originalTeam.ownerName,
                              "Iteration \(iteration): Owner name should be preserved")
                XCTAssertEqual(rankedTeam.wins, originalTeam.wins,
                              "Iteration \(iteration): Wins should be preserved")
                XCTAssertEqual(rankedTeam.losses, originalTeam.losses,
                              "Iteration \(iteration): Losses should be preserved")
                XCTAssertEqual(rankedTeam.ties, originalTeam.ties,
                              "Iteration \(iteration): Ties should be preserved")
                XCTAssertEqual(rankedTeam.pointsFor, originalTeam.pointsFor, accuracy: 0.01,
                              "Iteration \(iteration): Points for should be preserved")
                XCTAssertEqual(rankedTeam.pointsAgainst, originalTeam.pointsAgainst, accuracy: 0.01,
                              "Iteration \(iteration): Points against should be preserved")
                XCTAssertEqual(rankedTeam.topPlayers.count, originalTeam.topPlayers.count,
                              "Iteration \(iteration): Top players should be preserved")
            }
        }
    }
    
    /// Property test verifying multiple consecutive refreshes produce consistent results
    /// Runs 100+ iterations with multiple refresh cycles
    func testMultipleRefreshesConsistency() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 5...15)
            let teams = generateRandomTeams(count: teamCount)
            
            // Perform multiple refresh cycles
            let refreshCount = Int.random(in: 2...5)
            var previousRankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            
            for refreshCycle in 1...refreshCount {
                // Recalculate (simulating a refresh with same data)
                let currentRankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
                
                // Verify results are consistent across refreshes
                XCTAssertEqual(currentRankedTeams.count, previousRankedTeams.count,
                              "Iteration \(iteration), Refresh \(refreshCycle): Team count should be consistent")
                
                for (current, previous) in zip(currentRankedTeams, previousRankedTeams) {
                    XCTAssertEqual(current.id, previous.id,
                                  "Iteration \(iteration), Refresh \(refreshCycle): Team order should be consistent")
                    XCTAssertEqual(current.powerScore, previous.powerScore, accuracy: 0.0001,
                                  "Iteration \(iteration), Refresh \(refreshCycle): Power scores should be consistent")
                    XCTAssertEqual(current.rank, previous.rank,
                                  "Iteration \(iteration), Refresh \(refreshCycle): Ranks should be consistent")
                }
                
                previousRankedTeams = currentRankedTeams
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates random teams for testing
    private func generateRandomTeams(count: Int) -> [Team] {
        var teams: [Team] = []
        
        for i in 0..<count {
            let playerCount = Int.random(in: 1...5)
            var players: [Player] = []
            
            for j in 0..<playerCount {
                players.append(Player(
                    id: "player_\(i)_\(j)",
                    name: randomString(length: Int.random(in: 5...15)),
                    position: ["QB", "RB", "WR", "TE", "K", "DEF"].randomElement()!,
                    points: Double.random(in: 5...40)
                ))
            }
            
            let team = Team(
                id: "team_\(UUID().uuidString)",
                name: randomString(length: Int.random(in: 5...20)),
                ownerName: randomString(length: Int.random(in: 5...15)),
                wins: Int.random(in: 0...13),
                losses: Int.random(in: 0...13),
                ties: Int.random(in: 0...2),
                pointsFor: Double.random(in: 800...1800),
                pointsAgainst: Double.random(in: 800...1800),
                powerScore: 0.0,
                rank: 0,
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
    
    /// Modifies team statistics to simulate a data refresh
    private func modifyTeamStatistics(teams: [Team]) -> [Team] {
        return teams.map { team in
            // Randomly modify some statistics
            let shouldModify = Bool.random()
            
            if shouldModify {
                let winsChange = Int.random(in: -1...1)
                let lossesChange = Int.random(in: -1...1)
                let pointsChange = Double.random(in: -100...100)
                
                return Team(
                    id: team.id,
                    name: team.name,
                    ownerName: team.ownerName,
                    wins: max(0, team.wins + winsChange),
                    losses: max(0, team.losses + lossesChange),
                    ties: team.ties,
                    pointsFor: max(0, team.pointsFor + pointsChange),
                    pointsAgainst: max(0, team.pointsAgainst + pointsChange),
                    powerScore: 0.0,
                    rank: 0,
                    streak: team.streak,
                    topPlayers: team.topPlayers,
                    roast: team.roast
                )
            } else {
                return team
            }
        }
    }
    
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ "
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
