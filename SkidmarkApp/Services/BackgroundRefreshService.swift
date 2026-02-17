import Foundation

#if canImport(UIKit)
import BackgroundTasks

/// Service managing background refresh tasks for league data
@available(iOS 13.0, *)
final class BackgroundRefreshService {
    // Background task identifier
    static let refreshTaskIdentifier = "com.skidmark.refresh"
    
    private let storageService: StorageService
    private let espnService: LeagueDataService
    private let sleeperService: LeagueDataService
    
    init(
        storageService: StorageService,
        espnService: LeagueDataService,
        sleeperService: LeagueDataService
    ) {
        self.storageService = storageService
        self.espnService = espnService
        self.sleeperService = sleeperService
    }
    
    /// Registers background refresh task with the system
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    /// Schedules the next background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        
        // Schedule refresh for 4 hours from now (system will run when appropriate)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled successfully")
        } catch {
            print("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    /// Handles background refresh task execution
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleBackgroundRefresh()
        
        // Create task to refresh league data
        let refreshTask = Task {
            await refreshLeagueData()
        }
        
        // Handle task expiration
        task.expirationHandler = {
            refreshTask.cancel()
        }
        
        // Mark task as complete when done
        Task {
            await refreshTask.value
            task.setTaskCompleted(success: true)
        }
    }
    
    /// Refreshes data for all connected leagues
    private func refreshLeagueData() async {
        do {
            let connections = try storageService.loadLeagueConnections()
            
            for connection in connections {
                // Only refresh if cache is stale
                guard storageService.isCacheStale(forLeagueId: connection.leagueId) else {
                    continue
                }
                
                // Select appropriate service
                let service = connection.platform == .espn ? espnService : sleeperService
                
                // Determine the correct season year
                let season = SeasonHelper.currentFantasyFootballSeason()
                
                // Fetch fresh data
                let teams = try await service.fetchLeagueData(
                    leagueId: connection.leagueId,
                    season: season
                )
                
                // Calculate rankings
                let rankedTeams = PowerRankingsCalculator.calculatePowerRankings(teams: teams)
                
                // Save to cache
                try storageService.saveCachedLeagueData(
                    rankedTeams,
                    forLeagueId: connection.leagueId,
                    roastHash: nil
                )
                
                print("Background refresh completed for league: \(connection.leagueName)")
            }
        } catch {
            print("Background refresh failed: \(error.localizedDescription)")
        }
    }
    

}
#endif