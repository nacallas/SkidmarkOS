import SwiftUI

/// Settings screen with app info and preferences
struct SettingsView: View {
    @Environment(\.serviceContainer) private var serviceContainer
    @State private var showingCredentialManager = false
    @State private var leagues: [LeagueConnection] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Skidmark")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("Fantasy Football Power Rankings")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Credentials") {
                    ForEach(leagues.filter { $0.platform == .espn }) { league in
                        NavigationLink {
                            ESPNCredentialManagementView(
                                leagueId: league.leagueId,
                                leagueName: league.leagueName
                            )
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(league.leagueName)
                                        .font(.system(size: 15, weight: .medium))
                                    Text("ESPN Credentials")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    if leagues.filter({ $0.platform == .espn }).isEmpty {
                        Text("No ESPN leagues connected")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Platform Target")
                        Spacer()
                        Text("iOS 18+")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                leagues = (try? serviceContainer.storageService.loadLeagueConnections()) ?? []
            }
        }
    }
}
