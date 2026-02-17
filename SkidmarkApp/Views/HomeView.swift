import SwiftUI

/// Dashboard home screen with animated mesh gradient hero, league summaries, and AI insights
struct HomeView: View {
    @Environment(\.serviceContainer) private var serviceContainer
    @State private var leagues: [LeagueConnection] = []
    @State private var leagueTeams: [String: [Team]] = [:]
    @State private var isLoading = true
    @State private var animationPhase: CGFloat = 0
    @State private var selectedLeague: LeagueConnection?
    @State private var navigationPath: [LeagueConnection] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    
                    if isLoading {
                        loadingState
                    } else if leagues.isEmpty {
                        emptyState
                    } else {
                        dashboardContent
                    }
                }
            }
            #if os(iOS)
            .background(Color(uiColor: .systemGroupedBackground))
            #else
            .background(Color.gray.opacity(0.1))
            #endif
            .navigationDestination(for: LeagueConnection.self) { league in
                PowerRankingsView(league: league)
            }
            .task {
                await loadDashboardData()
            }
            .refreshable {
                await loadDashboardData()
            }
        }
    }
    
    // MARK: - Hero Header with Animated MeshGradient
    
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Animated mesh gradient background
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0.0, 0.0], [Float(0.5 + 0.1 * sin(t * 0.7)), 0.0], [1.0, 0.0],
                        [0.0, 0.5], [Float(0.5 + 0.15 * cos(t * 0.5)), Float(0.5 + 0.1 * sin(t * 0.8))], [1.0, 0.5],
                        [0.0, 1.0], [Float(0.5 + 0.1 * cos(t * 0.6)), 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        .black, Color(red: 0.15, green: 0.05, blue: 0.0), .black,
                        Color(red: 0.3, green: 0.1, blue: 0.0), Color(red: 0.9, green: 0.4, blue: 0.0), Color(red: 0.2, green: 0.05, blue: 0.0),
                        .black, Color(red: 0.1, green: 0.05, blue: 0.0), .black
                    ]
                )
            }
            .frame(height: 220)
            .ignoresSafeArea(edges: .top)
            
            // Content overlay
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.orange)
                        .symbolEffect(.breathe.pulse, options: .repeating)
                    
                    Text("Skidmark")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                Text(greetingText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let count = leagues.count
        let leagueWord = count == 1 ? "league" : "leagues"
        switch hour {
        case 0..<12: return "Good morning. \(count) \(leagueWord) tracked."
        case 12..<17: return "Good afternoon. \(count) \(leagueWord) tracked."
        default: return "Good evening. \(count) \(leagueWord) tracked."
        }
    }
    
    // MARK: - Dashboard Content
    
    private var dashboardContent: some View {
        VStack(spacing: 24) {
            // Quick stats row
            quickStatsRow
                .padding(.top, 20)
            
            // League summary cards
            ForEach(leagues) { league in
                leagueSummaryCard(league)
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.6)
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                            .offset(y: phase.isIdentity ? 0 : 20)
                    }
            }
            
            // AI insight card
            if let topInsight = generateTopInsight() {
                aiInsightCard(topInsight)
            }
            
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsRow: some View {
        let allTeams = leagueTeams.values.flatMap { $0 }
        let bestTeam = allTeams.max(by: { $0.powerScore < $1.powerScore })
        let totalPoints = allTeams.reduce(0.0) { $0 + $1.pointsFor }
        
        return HStack(spacing: 12) {
            quickStatPill(
                icon: "trophy.fill",
                label: "Top Team",
                value: bestTeam?.name ?? "--",
                color: .orange
            )
            quickStatPill(
                icon: "bolt.fill",
                label: "Total PF",
                value: String(format: "%.0f", totalPoints),
                color: .cyan
            )
        }
    }
    
    private func quickStatPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - League Summary Card
    
    private func leagueSummaryCard(_ league: LeagueConnection) -> some View {
        Button {
            navigationPath = [league]
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(league.leagueName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            platformBadge(league.platform)
                            Text("Updated \(relativeDate(league.lastUpdated))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                
                // Top 3 teams preview
                if let teams = leagueTeams[league.leagueId], !teams.isEmpty {
                    Divider()
                    
                    VStack(spacing: 8) {
                        ForEach(teams.prefix(3)) { team in
                            miniTeamRow(team)
                        }
                    }
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
    
    private func miniTeamRow(_ team: Team) -> some View {
        HStack(spacing: 12) {
            // Rank circle
            Text("\(team.rank)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(tierGradient(for: team.rank))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(team.ownerName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(team.record)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            
            // Streak
            HStack(spacing: 3) {
                Image(systemName: team.streak.type == .win ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(team.streak.displayString)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(team.streak.type == .win ? .green : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(
                    (team.streak.type == .win ? Color.green : Color.red).opacity(0.15)
                )
            )
        }
    }
    
    private func platformBadge(_ platform: League.Platform) -> some View {
        Text(platform.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(platform == .espn
                    ? Color(red: 0.8, green: 0.1, blue: 0.1)
                    : Color(red: 0.2, green: 0.5, blue: 0.9))
            )
    }
    
    // MARK: - AI Insight Card
    
    private func aiInsightCard(_ insight: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.breathe.pulse, options: .repeating)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("AI Insight")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                Text(insight)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.purple.opacity(0.4), .orange.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.5)
                .scaleEffect(phase.isIdentity ? 1 : 0.92)
        }
    }
    
    // MARK: - States
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.orange)
            Text("Loading your leagues...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.orange.opacity(0.5))
                .symbolEffect(.wiggle, options: .repeating.speed(0.3))
            
            Text("No leagues yet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            
            Text("Head to the Leagues tab to connect your first league.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .padding(.top, 40)
    }
    
    // MARK: - Helpers
    
    private func tierGradient(for rank: Int) -> LinearGradient {
        let colors: [Color] = switch rank {
        case 1...3: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.3)]
        case 4...6: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)]
        case 7...9: [Color(red: 1.0, green: 0.7, blue: 0.2), Color(red: 0.9, green: 0.5, blue: 0.1)]
        default: [Color(red: 1.0, green: 0.4, blue: 0.3), Color(red: 0.8, green: 0.2, blue: 0.2)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
    
    private func relativeDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Generates a quick AI-style insight from the data without a network call.
    /// Uses local heuristics to surface interesting patterns.
    private func generateTopInsight() -> String? {
        let allTeams = leagueTeams.values.flatMap { $0 }
        guard !allTeams.isEmpty else { return nil }
        
        // Find the hottest streak
        if let hottest = allTeams.filter({ $0.streak.type == .win }).max(by: { $0.streak.length < $1.streak.length }),
           hottest.streak.length >= 3 {
            return "\(hottest.name) is on a \(hottest.streak.length)-game win streak. They're the hottest team across your leagues right now."
        }
        
        // Find biggest points differential
        if let dominant = allTeams.max(by: { ($0.pointsFor - $0.pointsAgainst) < ($1.pointsFor - $1.pointsAgainst) }) {
            let diff = dominant.pointsFor - dominant.pointsAgainst
            if diff > 100 {
                return "\(dominant.name) has a +\(String(format: "%.0f", diff)) point differential. That's dominant."
            }
        }
        
        // Find a team punching above their weight
        if let underdog = allTeams.first(where: { $0.rank <= 3 && $0.pointsFor < allTeams.map(\.pointsFor).reduce(0, +) / Double(allTeams.count) }) {
            return "\(underdog.name) is ranked #\(underdog.rank) despite below-average scoring. Lucky or strategic?"
        }
        
        // Default insight
        if let leader = allTeams.min(by: { $0.rank < $1.rank }) {
            return "\(leader.name) leads the pack with a \(leader.record) record and \(String(format: "%.1f", leader.pointsFor)) total points."
        }
        
        return nil
    }
    
    // MARK: - Data Loading
    
    private func loadDashboardData() async {
        isLoading = true
        do {
            leagues = try serviceContainer.storageService.loadLeagueConnections()
            
            // Load cached team data for each league
            for league in leagues {
                if let cached = try? serviceContainer.storageService.loadCachedLeagueData(forLeagueId: league.leagueId) {
                    leagueTeams[league.leagueId] = cached.teams
                }
            }
        } catch {
            leagues = []
        }
        isLoading = false
    }
}
