import SwiftUI

/// Root tab navigation with animated tab bar
struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    
    enum AppTab: String, CaseIterable {
        case home, leagues, settings
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .leagues: return "Leagues"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "flame.fill"
            case .leagues: return "trophy.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: .home) {
                HomeView()
            }
            Tab(AppTab.leagues.title, systemImage: AppTab.leagues.icon, value: .leagues) {
                LeagueListView()
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.icon, value: .settings) {
                SettingsView()
            }
        }
        .tint(.orange)
    }
}
