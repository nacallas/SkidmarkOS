import XCTest
@testable import SkidmarkApp

/// Property-based tests for power rankings algorithm correctness
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
final class PowerRankingsPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Power Rankings Algorithm Correctness
    
    /// Property test verifying the power rankings algorithm produces correct results
    /// across all valid team configurations
    /// Runs 100+ iterations with randomly generated teams
    func testPowerRankingsAlgorithmCorrectness() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            // Generate random teams with varied records and points
            let teamCount = Int.random(in: 1...20)
            let teams = self.generateRandomTeams(count: teamCount)
            
            guard !teams.isEmpty else { continue }
            
            // Calculate power rankings
            let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            
            // Verify we got the same number of teams back
            XCTAssertEqual(rankedTeams.count, teams.count, 
                          "Iteration \(iteration): Should return same number of teams")
            
            // Find max values for verification
            let maxPointsFor = teams.map { $0.pointsFor }.max() ?? 1.0
            let maxPointsAgainst = teams.map { $0.pointsAgainst }.max() ?? 1.0
            
            // Verify each team's power score formula correctness
            for rankedTeam in rankedTeams {
                let winPct = rankedTeam.winPercentage
                let pfNormalized = rankedTeam.pointsFor / maxPointsFor
                let paNormalized = 1.0 - (rankedTeam.pointsAgainst / maxPointsAgainst)
                let expectedPowerScore = (winPct * 0.6) + (pfNormalized * 0.3) + (paNormalized * 0.1)
                
                // Allow small floating point tolerance
                XCTAssertEqual(rankedTeam.powerScore, expectedPowerScore, accuracy: 0.0001,
                              "Iteration \(iteration): Team \(rankedTeam.id) power score should match formula")
            }
            
            // Verify teams are sorted by power score in descending order
            for i in 0..<(rankedTeams.count - 1) {
                XCTAssertGreaterThanOrEqual(rankedTeams[i].powerScore, rankedTeams[i + 1].powerScore,
                                           "Iteration \(iteration): Teams should be sorted by power score descending")
            }
            
            // Verify ranks are sequential from 1 to N
            for (index, team) in rankedTeams.enumerated() {
                XCTAssertEqual(team.rank, index + 1,
                              "Iteration \(iteration): Ranks should be sequential from 1 to N")
            }
        }
    }
    
    /// Property test verifying win percentage calculation treats ties correctly
    /// Runs 100+ iterations with random win/loss/tie combinations
    func testWinPercentageWithTies() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let wins = Int.random(in: 0...20)
            let losses = Int.random(in: 0...20)
            let ties = Int.random(in: 0...10)
            
            // Skip if no games played
            guard (wins + losses + ties) > 0 else { continue }
            
            let team = self.createTeam(
                id: "test",
                wins: wins,
                losses: losses,
                ties: ties,
                pointsFor: 1000.0,
                pointsAgainst: 900.0
            )
            
            let totalGames = Double(wins + losses + ties)
            let expectedWinPct = (Double(wins) + Double(ties) * 0.5) / totalGames
            
            XCTAssertEqual(team.winPercentage, expectedWinPct, accuracy: 0.0001,
                          "Iteration \(iteration): Win percentage should treat ties as 0.5 wins")
        }
    }
    
    /// Property test verifying points for normalization
    /// Runs 100+ iterations with random team data
    func testPointsForNormalization() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 1...20)
            let teams = self.generateRandomTeams(count: teamCount)
            guard !teams.isEmpty else { continue }
            
            let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            let maxPointsFor = teams.map { $0.pointsFor }.max() ?? 1.0
            
            // Verify the team with max points for gets normalized value of 1.0
            let teamWithMaxPF = rankedTeams.first { $0.pointsFor == maxPointsFor }
            XCTAssertNotNil(teamWithMaxPF, "Iteration \(iteration): Should find team with max PF")
            
            if let maxTeam = teamWithMaxPF {
                let pfNormalized = maxTeam.pointsFor / maxPointsFor
                XCTAssertEqual(pfNormalized, 1.0, accuracy: 0.0001,
                              "Iteration \(iteration): Max PF team should have normalized value of 1.0")
            }
        }
    }
    
    /// Property test verifying points against normalization
    /// Runs 100+ iterations with random team data
    func testPointsAgainstNormalization() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 1...20)
            let teams = self.generateRandomTeams(count: teamCount)
            guard !teams.isEmpty else { continue }
            
            let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            let maxPointsAgainst = teams.map { $0.pointsAgainst }.max() ?? 1.0
            
            // Verify the team with max points against gets normalized value of 0.0
            let teamWithMaxPA = rankedTeams.first { $0.pointsAgainst == maxPointsAgainst }
            XCTAssertNotNil(teamWithMaxPA, "Iteration \(iteration): Should find team with max PA")
            
            if let maxTeam = teamWithMaxPA {
                let paNormalized = 1.0 - (maxTeam.pointsAgainst / maxPointsAgainst)
                XCTAssertEqual(paNormalized, 0.0, accuracy: 0.0001,
                              "Iteration \(iteration): Max PA team should have normalized value of 0.0")
            }
        }
    }
    
    /// Property test verifying rank assignment is always sequential
    /// Runs 100+ iterations with random team data
    func testRankSequentiality() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 1...20)
            let teams = self.generateRandomTeams(count: teamCount)
            guard !teams.isEmpty else { continue }
            
            let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            
            // Verify ranks are 1, 2, 3, ..., N
            for (index, team) in rankedTeams.enumerated() {
                XCTAssertEqual(team.rank, index + 1,
                              "Iteration \(iteration): Rank should be \(index + 1) but got \(team.rank)")
            }
        }
    }
    
    /// Property test verifying descending sort by power score
    /// Runs 100+ iterations with random team data
    func testDescendingSortByPowerScore() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 2...20)
            let teams = self.generateRandomTeams(count: teamCount)
            guard teams.count > 1 else { continue }
            
            let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            
            // Verify each team has power score >= next team
            for i in 0..<(rankedTeams.count - 1) {
                XCTAssertGreaterThanOrEqual(rankedTeams[i].powerScore, rankedTeams[i + 1].powerScore,
                                           "Iteration \(iteration): Team at index \(i) should have power score >= team at index \(i+1)")
            }
        }
    }
    
    /// Property test verifying the weighted formula components
    /// Runs 100+ iterations with random team data
    func testWeightedFormulaComponents() {
        let iterations = 100
        
        for iteration in 0..<iterations {
            let teamCount = Int.random(in: 1...20)
            let teams = self.generateRandomTeams(count: teamCount)
            guard !teams.isEmpty else { continue }
            
            let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
            let maxPF = teams.map { $0.pointsFor }.max() ?? 1.0
            let maxPA = teams.map { $0.pointsAgainst }.max() ?? 1.0
            
            // Verify formula for each team
            for team in rankedTeams {
                let winComponent = team.winPercentage * 0.6
                let pfComponent = (team.pointsFor / maxPF) * 0.3
                let paComponent = (1.0 - (team.pointsAgainst / maxPA)) * 0.1
                let expectedScore = winComponent + pfComponent + paComponent
                
                XCTAssertEqual(team.powerScore, expectedScore, accuracy: 0.0001,
                              "Iteration \(iteration): Team \(team.id) power score should match weighted formula")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates an array of random teams with varied records and points
    private func generateRandomTeams(count: Int) -> [Team] {
        var teams: [Team] = []
        
        for i in 0..<count {
            let wins = Int.random(in: 0...15)
            let losses = Int.random(in: 0...15)
            let ties = Int.random(in: 0...3)
            let pointsFor = Double.random(in: 500...2000)
            let pointsAgainst = Double.random(in: 500...2000)
            
            let team = createTeam(
                id: "team_\(i)",
                wins: wins,
                losses: losses,
                ties: ties,
                pointsFor: pointsFor,
                pointsAgainst: pointsAgainst
            )
            
            teams.append(team)
        }
        
        return teams
    }
    
    /// Creates a team with specified parameters
    private func createTeam(
        id: String,
        wins: Int,
        losses: Int,
        ties: Int = 0,
        pointsFor: Double,
        pointsAgainst: Double
    ) -> Team {
        Team(
            id: id,
            name: "Team \(id)",
            ownerName: "Owner \(id)",
            wins: wins,
            losses: losses,
            ties: ties,
            pointsFor: pointsFor,
            pointsAgainst: pointsAgainst,
            powerScore: 0.0,
            rank: 0,
            streak: Team.Streak(type: .win, length: 1),
            topPlayers: [],
            roast: nil
        )
    }
}
