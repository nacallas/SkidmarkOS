import Foundation

/// Utility for calculating power rankings for fantasy football teams
enum PowerRankingsCalculator {
    
    /// Calculates power rankings for an array of teams
    /// - Parameter teams: Array of teams to rank
    /// - Returns: Array of teams with updated powerScore and rank properties, sorted by power score descending
    ///
    /// The power ranking algorithm uses the following formula:
    /// - Win percentage: 60% weight (ties count as 0.5 wins)
    /// - Points for (normalized): 30% weight
    /// - Points against (normalized): 10% weight
    ///
    /// Points for are normalized by dividing by the league maximum.
    /// Points against are normalized as 1 - (PA / max PA).
    static func calculatePowerRankings(teams: [Team]) -> [Team] {
        guard !teams.isEmpty else { return [] }
        
        // Find maximum values for normalization
        let maxPointsFor = teams.map { $0.pointsFor }.max() ?? 1.0
        let maxPointsAgainst = teams.map { $0.pointsAgainst }.max() ?? 1.0
        
        // Calculate power scores for each team
        var rankedTeams = teams.map { team -> Team in
            var mutableTeam = team
            
            // Win percentage (already calculated in Team model)
            let winPct = team.winPercentage
            
            // Normalize points for by dividing by league maximum
            let pfNormalized = team.pointsFor / maxPointsFor
            
            // Normalize points against as 1 - (PA / max PA)
            let paNormalized = 1.0 - (team.pointsAgainst / maxPointsAgainst)
            
            // Calculate power score: (winPct * 0.6) + (pfNorm * 0.3) + (paNorm * 0.1)
            mutableTeam.powerScore = (winPct * 0.6) + (pfNormalized * 0.3) + (paNormalized * 0.1)
            
            return mutableTeam
        }
        
        // Sort teams by power score in descending order
        rankedTeams.sort { $0.powerScore > $1.powerScore }
        
        // Assign ranks from 1 to N
        for (index, _) in rankedTeams.enumerated() {
            rankedTeams[index].rank = index + 1
        }
        
        return rankedTeams
    }
}
