import XCTest
@testable import SkidmarkApp

final class TeamTests: XCTestCase {
    func testTeamRecordWithoutTies() {
        let team = Team(
            id: "1",
            name: "Test Team",
            ownerName: "Test Owner",
            wins: 5,
            losses: 3,
            ties: 0,
            pointsFor: 1000.0,
            pointsAgainst: 900.0,
            powerScore: 0.0,
            rank: 0,
            streak: Team.Streak(type: .win, length: 2),
            topPlayers: [],
            roast: nil
        )
        
        XCTAssertEqual(team.record, "5-3")
    }
    
    func testTeamRecordWithTies() {
        let team = Team(
            id: "1",
            name: "Test Team",
            ownerName: "Test Owner",
            wins: 5,
            losses: 3,
            ties: 1,
            pointsFor: 1000.0,
            pointsAgainst: 900.0,
            powerScore: 0.0,
            rank: 0,
            streak: Team.Streak(type: .win, length: 2),
            topPlayers: [],
            roast: nil
        )
        
        XCTAssertEqual(team.record, "5-3-1")
    }
    
    func testWinPercentageWithoutTies() {
        let team = Team(
            id: "1",
            name: "Test Team",
            ownerName: "Test Owner",
            wins: 6,
            losses: 4,
            ties: 0,
            pointsFor: 1000.0,
            pointsAgainst: 900.0,
            powerScore: 0.0,
            rank: 0,
            streak: Team.Streak(type: .win, length: 2),
            topPlayers: [],
            roast: nil
        )
        
        XCTAssertEqual(team.winPercentage, 0.6, accuracy: 0.001)
    }
    
    func testWinPercentageWithTies() {
        let team = Team(
            id: "1",
            name: "Test Team",
            ownerName: "Test Owner",
            wins: 5,
            losses: 3,
            ties: 2,
            pointsFor: 1000.0,
            pointsAgainst: 900.0,
            powerScore: 0.0,
            rank: 0,
            streak: Team.Streak(type: .win, length: 2),
            topPlayers: [],
            roast: nil
        )
        
        // 5 wins + (2 ties * 0.5) = 6 / 10 games = 0.6
        XCTAssertEqual(team.winPercentage, 0.6, accuracy: 0.001)
    }
    
    func testStreakDisplayString() {
        let winStreak = Team.Streak(type: .win, length: 3)
        XCTAssertEqual(winStreak.displayString, "W3")
        
        let lossStreak = Team.Streak(type: .loss, length: 2)
        XCTAssertEqual(lossStreak.displayString, "L2")
    }
}
