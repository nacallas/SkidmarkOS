import Foundation

/// Computes cumulative team standings from matchup results through a given week.
/// Used for the "time machine" feature: reconstructing historical records
/// when neither ESPN nor Sleeper provide a historical standings endpoint.
enum StandingsCalculator {
    
    /// A team's cumulative record through a given week.
    struct TeamRecord {
        var wins: Int = 0
        var losses: Int = 0
        var ties: Int = 0
        var pointsFor: Double = 0
        var pointsAgainst: Double = 0
    }
    
    /// Computes cumulative records for all teams through the target week.
    /// Iterates matchups from week 1 through `throughWeek`, tallying W/L/T and points.
    static func computeStandings(
        allMatchups: [Int: [WeeklyMatchup]],
        throughWeek: Int
    ) -> [String: TeamRecord] {
        var records: [String: TeamRecord] = [:]
        
        for week in 1...throughWeek {
            guard let matchups = allMatchups[week] else { continue }
            
            for matchup in matchups {
                let homeId = matchup.homeTeamId
                let awayId = matchup.awayTeamId
                
                // Accumulate points
                records[homeId, default: TeamRecord()].pointsFor += matchup.homeScore
                records[homeId, default: TeamRecord()].pointsAgainst += matchup.awayScore
                records[awayId, default: TeamRecord()].pointsFor += matchup.awayScore
                records[awayId, default: TeamRecord()].pointsAgainst += matchup.homeScore
                
                // Determine winner
                if matchup.homeScore > matchup.awayScore {
                    records[homeId, default: TeamRecord()].wins += 1
                    records[awayId, default: TeamRecord()].losses += 1
                } else if matchup.awayScore > matchup.homeScore {
                    records[awayId, default: TeamRecord()].wins += 1
                    records[homeId, default: TeamRecord()].losses += 1
                } else {
                    records[homeId, default: TeamRecord()].ties += 1
                    records[awayId, default: TeamRecord()].ties += 1
                }
            }
        }
        
        return records
    }

    /// Applies computed historical records to an existing team array, replacing
    /// their current-season records with the cumulative records through the target week.
    /// Also recalculates power rankings based on the historical data.
    static func applyHistoricalRecords(
        to teams: [Team],
        records: [String: TeamRecord]
    ) -> [Team] {
        var updated = teams.map { team -> Team in
            guard let record = records[team.id] else { return team }
            return Team(
                id: team.id,
                name: team.name,
                ownerName: team.ownerName,
                wins: record.wins,
                losses: record.losses,
                ties: record.ties,
                pointsFor: record.pointsFor,
                pointsAgainst: record.pointsAgainst,
                powerScore: team.powerScore,
                rank: team.rank,
                streak: team.streak,
                topPlayers: team.topPlayers,
                roast: team.roast
            )
        }
        // Recalculate power rankings with historical records
        updated = PowerRankingsCalculator.calculatePowerRankings(teams: updated)
        return updated
    }
}
