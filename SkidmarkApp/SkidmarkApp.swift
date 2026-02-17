import SwiftUI

#if canImport(UIKit)
import BackgroundTasks
#endif

@main
struct SkidmarkAppMain: App {
    @StateObject private var serviceContainer = ServiceContainer()
    
    #if canImport(UIKit)
    private var backgroundRefreshService: BackgroundRefreshService?
    #endif
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCompletedInitialSetup = false
    
    init() {
        #if canImport(UIKit)
        if #available(iOS 13.0, *) {
            let keychainService = DefaultKeychainService()
            let networkMonitor = NetworkMonitor()
            let storageService = DefaultStorageService()
            let service = BackgroundRefreshService(
                storageService: storageService,
                espnService: ESPNService(keychainService: keychainService, networkMonitor: networkMonitor),
                sleeperService: SleeperService(networkMonitor: networkMonitor)
            )
            service.registerBackgroundTasks()
            self.backgroundRefreshService = service
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .serviceContainer(serviceContainer)
                .onAppear { performInitialSetup() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func performInitialSetup() {
        guard !hasCompletedInitialSetup else { return }
        hasCompletedInitialSetup = true
        #if canImport(UIKit)
        if #available(iOS 13.0, *) {
            backgroundRefreshService?.scheduleBackgroundRefresh()
        }
        #endif
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            #if canImport(UIKit)
            if #available(iOS 13.0, *) {
                backgroundRefreshService?.scheduleBackgroundRefresh()
            }
            #endif
        default:
            break
        }
    }
}
