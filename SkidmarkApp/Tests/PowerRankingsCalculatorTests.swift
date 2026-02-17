import XCTest
@testable import SkidmarkApp

final class PowerRankingsCalculatorTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testEmptyTeamArray() {
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [])
        XCTAssertTrue(result.isEmpty, "Empty input should return empty array")
    }
    
    func testSingleTeam() {
        let team = createTeam(id: "1", wins: 5, losses: 3, pointsFor: 1000, pointsAgainst: 900)
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [team])
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].rank, 1, "Single team should have rank 1")
        XCTAssertGreaterThan(result[0].powerScore, 0, "Power score should be calculated")
    }
    
    func testTeamsWithIdenticalRecords() {
        let team1 = createTeam(id: "1", wins: 5, losses: 3, pointsFor: 1200, pointsAgainst: 900)
        let team2 = createTeam(id: "2", wins: 5, losses: 3, pointsFor: 1000, pointsAgainst: 900)
        
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [team1, team2])
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, "1", "Team with more points should rank higher")
        XCTAssertEqual(result[0].rank, 1)
        XCTAssertEqual(result[1].rank, 2)
    }
    
    func testTeamsWithTies() {
        let team1 = createTeam(id: "1", wins: 5, losses: 2, ties: 1, pointsFor: 1000, pointsAgainst: 900)
        let team2 = createTeam(id: "2", wins: 5, losses: 3, ties: 0, pointsFor: 1000, pointsAgainst: 900)
        
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [team1, team2])
        
        XCTAssertEqual(result.count, 2)
        // Team1 has 5.5 wins (5 + 0.5 for tie) vs Team2 with 5 wins
        XCTAssertEqual(result[0].id, "1", "Team with tie should rank higher than team with same wins but more losses")
        XCTAssertGreaterThan(result[0].powerScore, result[1].powerScore)
    }
    
    // MARK: - Algorithm Correctness Tests
    
    func testPowerScoreFormula() {
        let team = createTeam(id: "1", wins: 6, losses: 2, pointsFor: 1000, pointsAgainst: 800)
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [team])
        
        let expectedWinPct = 6.0 / 8.0  // 0.75
        let expectedPfNorm = 1.0  // 1000 / 1000 (max)
        let expectedPaNorm = 1.0 - (800.0 / 800.0)  // 0.0
        let expectedPowerScore = (expectedWinPct * 0.6) + (expectedPfNorm * 0.3) + (expectedPaNorm * 0.1)
        
        XCTAssertEqual(result[0].powerScore, expectedPowerScore, accuracy: 0.001)
    }
    
    func testNormalizationWithMultipleTeams() {
        let team1 = createTeam(id: "1", wins: 7, losses: 1, pointsFor: 1200, pointsAgainst: 800)
        let team2 = createTeam(id: "2", wins: 5, losses: 3, pointsFor: 1000, pointsAgainst: 900)
        let team3 = createTeam(id: "3", wins: 2, losses: 6, pointsFor: 800, pointsAgainst: 1100)
        
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [team1, team2, team3])
        
        // Verify normalization
        let maxPF = 1200.0
        let maxPA = 1100.0
        
        // Team 1 calculations
        let team1WinPct = 7.0 / 8.0
        let team1PfNorm = 1200.0 / maxPF
        let team1PaNorm = 1.0 - (800.0 / maxPA)
        let team1Expected = (team1WinPct * 0.6) + (team1PfNorm * 0.3) + (team1PaNorm * 0.1)
        
        XCTAssertEqual(result[0].powerScore, team1Expected, accuracy: 0.001)
        XCTAssertEqual(result[0].id, "1", "Team 1 should rank first")
    }
    
    func testRankAssignment() {
        let team1 = createTeam(id: "1", wins: 7, losses: 1, pointsFor: 1200, pointsAgainst: 800)
        let team2 = createTeam(id: "2", wins: 5, losses: 3, pointsFor: 1000, pointsAgainst: 900)
        let team3 = createTeam(id: "3", wins: 4, losses: 4, pointsFor: 950, pointsAgainst: 950)
        let team4 = createTeam(id: "4", wins: 2, losses: 6, pointsFor: 800, pointsAgainst: 1100)
        
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [team1, team2, team3, team4])
        
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0].rank, 1)
        XCTAssertEqual(result[1].rank, 2)
        XCTAssertEqual(result[2].rank, 3)
        XCTAssertEqual(result[3].rank, 4)
        
        // Verify descending order by power score
        XCTAssertGreaterThan(result[0].powerScore, result[1].powerScore)
        XCTAssertGreaterThan(result[1].powerScore, result[2].powerScore)
        XCTAssertGreaterThan(result[2].powerScore, result[3].powerScore)
    }
    
    func testPointsAgainstNormalization() {
        // Team with lower points against should get higher normalized score
        let team1 = createTeam(id: "1", wins: 5, losses: 3, pointsFor: 1000, pointsAgainst: 700)
        let team2 = createTeam(id: "2", wins: 5, losses: 3, pointsFor: 1000, pointsAgainst: 1000)
        
        let result = PowerRankingsCalculator.calculatePowerRankings(teams: [team1, team2])
        
        // Team 1 should rank higher due to lower points against
        XCTAssertEqual(result[0].id, "1")
        XCTAssertGreaterThan(result[0].powerScore, result[1].powerScore)
    }
    
    // MARK: - Helper Methods
    
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
