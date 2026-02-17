import Foundation

/// View model managing the list of connected fantasy leagues
@MainActor @Observable
class LeagueListViewModel {
    // MARK: - Published Properties
    
    var leagues: [LeagueConnection] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedLeague: LeagueConnection?
    var shouldNavigateToLastViewed: Bool = false
    
    // MARK: - Dependencies
    
    private let storageService: StorageService
    private let keychainService: KeychainService
    private let networkMonitor: NetworkMonitor?
    
    // MARK: - Initialization
    
    init(
        storageService: StorageService = DefaultStorageService(),
        keychainService: KeychainService = DefaultKeychainService(),
        networkMonitor: NetworkMonitor? = nil
    ) {
        self.storageService = storageService
        self.keychainService = keychainService
        self.networkMonitor = networkMonitor
    }
    
    // MARK: - Public Methods
    
    /// Fetches all connected leagues from storage
    func fetchLeagues() {
        isLoading = true
        errorMessage = nil
        
        do {
            leagues = try storageService.loadLeagueConnections()
            isLoading = false
            
            // Auto-load last viewed league if available
            loadLastViewedLeague()
        } catch {
            errorMessage = "Failed to load leagues: \(error.localizedDescription)"
            leagues = []
            isLoading = false
        }
    }
    
    /// Loads and selects the last viewed league for auto-navigation
    private func loadLastViewedLeague() {
        guard let lastViewedId = storageService.loadLastViewedLeagueId(),
              let league = leagues.first(where: { $0.id == lastViewedId }) else {
            return
        }
        
        selectedLeague = league
        shouldNavigateToLastViewed = true
    }
    
    /// Adds a new league connection and saves it to storage
    /// - Parameter connection: The league connection to add
    func addLeague(_ connection: LeagueConnection) {
        errorMessage = nil
        
        // Check if league already exists
        if leagues.contains(where: { $0.leagueId == connection.leagueId && $0.platform == connection.platform }) {
            errorMessage = "This league is already connected"
            return
        }
        
        // Add to local array
        leagues.append(connection)
        
        // Save to storage
        do {
            try storageService.saveLeagueConnections(leagues)
        } catch {
            // Rollback on failure
            leagues.removeLast()
            errorMessage = "Failed to save league: \(error.localizedDescription)"
        }
    }
    
    /// Removes a league connection and cleans up all associated data
    /// - Parameter connection: The league connection to remove
    func removeLeague(_ connection: LeagueConnection) {
        errorMessage = nil
        
        // Remove from local array
        guard let index = leagues.firstIndex(where: { $0.id == connection.id }) else {
            errorMessage = "League not found"
            return
        }
        
        let removedLeague = leagues.remove(at: index)
        
        // Save updated connections list
        do {
            try storageService.saveLeagueConnections(leagues)
        } catch {
            // Rollback on failure
            leagues.insert(removedLeague, at: index)
            errorMessage = "Failed to remove league: \(error.localizedDescription)"
            return
        }
        
        // Clean up associated data
        do {
            try storageService.clearDataForLeague(leagueId: connection.leagueId)
        } catch {
            // Log error but don't rollback since connection is already removed
            print("Warning: Failed to clear data for league \(connection.leagueId): \(error.localizedDescription)")
        }
        
        // Delete ESPN credentials if applicable
        if connection.platform == .espn && connection.hasAuthentication {
            let result = keychainService.deleteESPNCredentials(forLeagueId: connection.leagueId)
            if case .failure(let error) = result {
                // Log error but don't rollback
                print("Warning: Failed to delete credentials for league \(connection.leagueId): \(error.localizedDescription)")
            }
        }
        
        // Clear selection if the removed league was selected
        if selectedLeague?.id == connection.id {
            selectedLeague = nil
        }
    }
    
    /// Selects a league for viewing
    /// - Parameter connection: The league connection to select
    func selectLeague(_ connection: LeagueConnection) {
        selectedLeague = connection
        storageService.saveLastViewedLeagueId(connection.id)
    }
    
    /// Resets the navigation flag after auto-navigation completes
    func clearNavigationFlag() {
        shouldNavigateToLastViewed = false
    }
}
