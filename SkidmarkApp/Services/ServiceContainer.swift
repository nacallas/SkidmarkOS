import Foundation
import SwiftUI

/// Container that manages all service instances and their dependencies
/// Provides a centralized place for dependency injection throughout the app
class ServiceContainer: ObservableObject {
    // MARK: - Service Instances
    
    let keychainService: KeychainService
    let storageService: StorageService
    let authenticationService: ESPNAuthenticationService
    let networkMonitor: NetworkMonitor
    let espnService: ESPNService
    let sleeperService: LeagueDataService
    let backendService: BackendService
    
    // MARK: - Initialization
    
    /// Creates a service container with default production implementations
    init() {
        // Initialize base services
        self.keychainService = DefaultKeychainService()
        self.storageService = DefaultStorageService()
        self.authenticationService = ESPNAuthenticationService(keychainService: keychainService)
        self.networkMonitor = NetworkMonitor()
        
        // Initialize API services with dependencies
        let espnServiceInstance = ESPNService(keychainService: keychainService, networkMonitor: networkMonitor)
        self.espnService = espnServiceInstance
        self.sleeperService = SleeperService(networkMonitor: networkMonitor)
        self.backendService = AWSBackendService(networkMonitor: networkMonitor)
        
        // Wire up credential expiration callback
        // When ESPN credentials expire, we'll need to notify the UI to prompt re-authentication
        // This will be handled by posting a notification that views can observe
        espnServiceInstance.onCredentialsExpired = { leagueId in
            NotificationCenter.default.post(
                name: .espnCredentialsExpired,
                object: nil,
                userInfo: ["leagueId": leagueId]
            )
        }
    }
    
    /// Creates a service container with custom service implementations (for testing)
    init(
        keychainService: KeychainService,
        storageService: StorageService,
        authenticationService: ESPNAuthenticationService,
        networkMonitor: NetworkMonitor,
        espnService: ESPNService,
        sleeperService: LeagueDataService,
        backendService: BackendService
    ) {
        self.keychainService = keychainService
        self.storageService = storageService
        self.authenticationService = authenticationService
        self.networkMonitor = networkMonitor
        self.espnService = espnService
        self.sleeperService = sleeperService
        self.backendService = backendService
    }
    
    // MARK: - View Model Factories
    
    /// Creates a LeagueListViewModel with injected dependencies
    @MainActor
    func makeLeagueListViewModel() -> LeagueListViewModel {
        LeagueListViewModel(
            storageService: storageService,
            keychainService: keychainService,
            networkMonitor: networkMonitor
        )
    }
    
    /// Creates a PowerRankingsViewModel with injected dependencies
    @MainActor
    func makePowerRankingsViewModel() -> PowerRankingsViewModel {
        PowerRankingsViewModel(
            espnService: espnService,
            sleeperService: sleeperService,
            backendService: backendService,
            storageService: storageService,
            networkMonitor: networkMonitor
        )
    }
    
    /// Creates a LeagueContextViewModel with injected dependencies
    @MainActor
    func makeLeagueContextViewModel() -> LeagueContextViewModel {
        LeagueContextViewModel(storageService: storageService)
    }
}

// MARK: - Environment Key

/// Environment key for accessing the service container
private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer()
}

extension EnvironmentValues {
    /// Access the service container from the SwiftUI environment
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects the service container into the environment
    /// - Parameter container: The service container to inject
    /// - Returns: A view with the service container in its environment
    func serviceContainer(_ container: ServiceContainer) -> some View {
        environment(\.serviceContainer, container)
    }
}


// MARK: - Notification Names

extension Notification.Name {
    /// Posted when ESPN credentials expire and need to be refreshed
    /// UserInfo contains "leagueId" key with the league ID string
    static let espnCredentialsExpired = Notification.Name("espnCredentialsExpired")
}
