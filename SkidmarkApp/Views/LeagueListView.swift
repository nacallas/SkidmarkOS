import SwiftUI

struct LeagueListView: View {
    @Environment(\.serviceContainer) private var serviceContainer
    @State private var viewModel: LeagueListViewModel?
    @State private var showingAddLeague = false
    @State private var showingError = false
    @State private var navigationPath: [LeagueConnection] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let viewModel = viewModel {
                    loadedBody(viewModel)
                } else {
                    ProgressView("Loading leagues...")
                }
            }
            .navigationTitle("My Leagues")
            .navigationDestination(for: LeagueConnection.self) { league in
                PowerRankingsView(league: league)
                    .onAppear {
                        viewModel?.selectLeague(league)
                    }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddLeague = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLeague) {
                if let viewModel = viewModel {
                    AddLeagueView(
                        viewModel: viewModel,
                        keychainService: serviceContainer.keychainService,
                        espnService: serviceContainer.espnService,
                        sleeperService: serviceContainer.sleeperService
                    )
                }
            }
            .alert("Error", isPresented: $showingError, presenting: viewModel?.errorMessage) { _ in
                Button("OK") {
                    viewModel?.errorMessage = nil
                }
            } message: { errorMessage in
                Text(errorMessage)
            }
            .task {
                if viewModel == nil {
                    viewModel = serviceContainer.makeLeagueListViewModel()
                }
                viewModel?.fetchLeagues()
            }
            .onChange(of: viewModel?.errorMessage) { _, newValue in
                showingError = newValue != nil
            }
            .onChange(of: viewModel?.shouldNavigateToLastViewed) { _, shouldNavigate in
                if shouldNavigate == true, let league = viewModel?.selectedLeague {
                    navigationPath = [league]
                    viewModel?.clearNavigationFlag()
                }
            }
        }
    }
    
    @ViewBuilder
    private func loadedBody(_ viewModel: LeagueListViewModel) -> some View {
        VStack(spacing: 0) {
            if !serviceContainer.networkMonitor.isConnected {
                networkStatusBanner
            }
            
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading leagues...")
                } else if viewModel.leagues.isEmpty {
                    emptyStateView
                } else {
                    leagueListContent(viewModel)
                }
            }
        }
    }
    
    private var networkStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text("No Internet Connection")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.0),
                    Color(red: 0.9, green: 0.5, blue: 0.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.2),
                                Color.accentColor.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text("No Leagues Connected")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Add your first fantasy league to get started")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddLeague = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add League")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(32)
    }
    
    private func leagueListContent(_ viewModel: LeagueListViewModel) -> some View {
        List {
            ForEach(viewModel.leagues) { league in
                NavigationLink(value: league) {
                    LeagueRowView(league: league)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    let league = viewModel.leagues[index]
                    viewModel.removeLeague(league)
                }
            }
        }
    }
}

struct LeagueRowView: View {
    let league: LeagueConnection
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Platform icon badge
            ZStack {
                Circle()
                    .fill(platformGradient)
                    .frame(width: 48, height: 48)
                    .shadow(color: platformColor.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: platformIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(league.leagueName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(league.platform.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 12)
    }
    
    private var platformIcon: String {
        switch league.platform {
        case .espn:
            return "e.circle.fill"
        case .sleeper:
            return "moon.zzz.fill"
        }
    }
    
    private var platformColor: Color {
        switch league.platform {
        case .espn:
            return Color(red: 0.8, green: 0.1, blue: 0.1)
        case .sleeper:
            return Color(red: 0.2, green: 0.6, blue: 1.0)
        }
    }
    
    private var platformGradient: LinearGradient {
        switch league.platform {
        case .espn:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.9, green: 0.2, blue: 0.2),
                    Color(red: 0.7, green: 0.1, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sleeper:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.3, green: 0.7, blue: 1.0),
                    Color(red: 0.1, green: 0.5, blue: 0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
    
    private var formattedDate: String {
        Self.relativeDateFormatter.localizedString(for: league.lastUpdated, relativeTo: Date())
    }
}

struct AddLeagueView: View {
    var viewModel: LeagueListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlatform: League.Platform = .sleeper
    @State private var leagueId: String = ""
    @State private var isConnecting: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingWebAuth: Bool = false
    @State private var espnAuthenticated: Bool = false
    
    private let keychainService: KeychainService
    private let authService: ESPNAuthenticationService
    private let espnService: LeagueDataService
    private let sleeperService: LeagueDataService
    
    init(viewModel: LeagueListViewModel, 
         keychainService: KeychainService = DefaultKeychainService(),
         espnService: LeagueDataService = ESPNService(),
         sleeperService: LeagueDataService = SleeperService()) {
        self.viewModel = viewModel
        self.keychainService = keychainService
        self.authService = ESPNAuthenticationService(keychainService: keychainService)
        self.espnService = espnService
        self.sleeperService = sleeperService
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Platform")) {
                    Picker("Platform", selection: $selectedPlatform) {
                        Text("Sleeper").tag(League.Platform.sleeper)
                        Text("ESPN").tag(League.Platform.espn)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("League Information")) {
                    TextField("League ID", text: $leagueId)
                        .autocorrectionDisabled()
                }
                
                if selectedPlatform == .espn {
                    Section(header: Text("ESPN Authentication"),
                           footer: Text("Enter your ESPN cookies to access private leagues. Your credentials are stored securely in the device keychain.")) {
                        Button(action: { showingWebAuth = true }) {
                            HStack {
                                Image(systemName: espnAuthenticated ? "checkmark.circle.fill" : "key")
                                    .foregroundColor(espnAuthenticated ? .green : .accentColor)
                                Text(espnAuthenticated ? "Credentials Saved" : "Enter ESPN Credentials")
                                Spacer()
                                if !espnAuthenticated {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: connectLeague) {
                        if isConnecting {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Connecting...")
                            }
                        } else {
                            Text("Connect League")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isConnecting)
                }
            }
            .navigationTitle("Add League")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isConnecting)
                }
            }
            .alert("Connection Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingWebAuth) {
                NavigationView {
                    ESPNAuthOptionsView(
                        leagueId: leagueId.trimmingCharacters(in: .whitespaces),
                        authService: authService,
                        onSuccess: {
                            espnAuthenticated = true
                        }
                    )
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        guard !leagueId.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        
        if selectedPlatform == .espn {
            return espnAuthenticated
        }
        
        return true
    }
    
    private func connectLeague() {
        isConnecting = true
        errorMessage = ""
        
        Task {
            do {
                let trimmedLeagueId = leagueId.trimmingCharacters(in: .whitespaces)
                
                // Fetch league data to validate connection
                let season = SeasonHelper.currentFantasyFootballSeason()
                let service: LeagueDataService = selectedPlatform == .espn ? espnService : sleeperService
                let teams = try await service.fetchLeagueData(leagueId: trimmedLeagueId, season: season)
                
                // Extract league name from first team or use default
                let leagueName = teams.isEmpty ? "League \(trimmedLeagueId)" : "League"
                
                // Create league connection
                let connection = LeagueConnection(
                    id: UUID().uuidString,
                    leagueId: trimmedLeagueId,
                    platform: selectedPlatform,
                    leagueName: leagueName,
                    lastUpdated: Date(),
                    hasAuthentication: selectedPlatform == .espn
                )
                
                // Add to view model
                await MainActor.run {
                    viewModel.addLeague(connection)
                    
                    // Check if there was an error adding the league
                    if viewModel.errorMessage != nil {
                        errorMessage = viewModel.errorMessage ?? "Failed to add league"
                        showingError = true
                        isConnecting = false
                    } else {
                        // Success - dismiss the view
                        isConnecting = false
                        dismiss()
                    }
                }
                
            } catch let error as LeagueDataError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    showingError = true
                    isConnecting = false
                }
            }
        }
    }
}



struct LeagueListView_Previews: PreviewProvider {
    static var previews: some View {
        LeagueListView()
    }
}
