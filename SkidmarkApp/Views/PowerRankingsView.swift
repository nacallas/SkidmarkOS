import SwiftUI

/// Power rankings view with scroll-driven animations and tier-based team cards.
/// View models are created lazily from the environment ServiceContainer
/// so they share the canonical service instances with the rest of the app.
struct PowerRankingsView: View {
    let league: LeagueConnection

    @Environment(\.serviceContainer) private var serviceContainer
    @State private var viewModel: PowerRankingsViewModel?
    @State private var contextViewModel: LeagueContextViewModel?

    @State private var showingError = false
    @State private var showingContextEditor = false
    @State private var showingExportOptions = false
    @State private var showingCopyConfirmation = false

    // Convenience accessors that fall back to safe defaults when VMs aren't ready
    private var vm: PowerRankingsViewModel? { viewModel }
    private var cvm: LeagueContextViewModel? { contextViewModel }

    private var hasAnyRoasts: Bool {
        vm?.teams.contains { $0.roast != nil } ?? false
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                loadedBody(vm)
            } else {
                loadingView
            }
        }
        .navigationTitle(league.leagueName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            // Create VMs from the environment container exactly once
            if viewModel == nil {
                viewModel = serviceContainer.makePowerRankingsViewModel()
                contextViewModel = serviceContainer.makeLeagueContextViewModel()
            }
            await initialLoad()
        }
        .confirmationDialog("Copy to Clipboard", isPresented: $showingExportOptions) {
            copyDialogButtons
        } message: { Text("Choose what to copy") }
        .alert("Copied!", isPresented: $showingCopyConfirmation) {
            Button("OK") { showingCopyConfirmation = false }
        } message: { Text("Rankings copied to clipboard") }
    }

    // MARK: - Loaded Body (only rendered when VMs exist)

    @ViewBuilder
    private func loadedBody(_ vm: PowerRankingsViewModel) -> some View {
        mainContent(vm)
            .toolbar { toolbarContent(vm) }
            .refreshable {
                await vm.fetchLeagueData(for: league)
                guard !Task.isCancelled else { return }
                if vm.errorMessage == nil && !vm.teams.isEmpty {
                    await generateRoasts()
                }
            }
            .sheet(isPresented: $showingContextEditor) {
                if let cvm = contextViewModel {
                    LeagueContextView(league: league, viewModel: cvm)
                }
            }
            .onChange(of: vm.errorMessage) { _, newValue in
                showingError = newValue != nil
            }
            .alert("Error", isPresented: $showingError, presenting: vm.errorMessage) { _ in
                Button("Retry") { Task { await retryFetch() } }
                Button("Cancel", role: .cancel) { vm.errorMessage = nil }
            } message: { Text($0) }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(_ vm: PowerRankingsViewModel) -> some View {
        ZStack {
            #if os(iOS)
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            #else
            Color.gray.opacity(0.1).ignoresSafeArea()
            #endif

            if vm.isLoading && vm.teams.isEmpty {
                loadingView
            } else if vm.teams.isEmpty {
                emptyStateView
            } else {
                rankingsScrollView(vm)
            }
        }
    }

    @ViewBuilder
    private var copyDialogButtons: some View {
        if let vm = viewModel {
            Button("Copy Rankings Only") {
                if vm.copyToClipboard(includeRoasts: false) { showingCopyConfirmation = true }
            }
            Button("Copy Rankings + Roasts") {
                if vm.copyToClipboard(includeRoasts: true) { showingCopyConfirmation = true }
            }
            .disabled(!hasAnyRoasts)
        }
        Button("Cancel", role: .cancel) {}
    }

    private func initialLoad() async {
        guard let vm = viewModel, let cvm = contextViewModel else { return }
        vm.loadCachedData(forLeagueId: league.leagueId)
        cvm.loadContext(forLeagueId: league.leagueId)
        await vm.fetchLeagueData(for: league)
        guard !Task.isCancelled else { return }
        if vm.errorMessage == nil && !vm.teams.isEmpty {
            await generateRoasts()
        }
    }

    private func retryFetch() async {
        guard let vm = viewModel else { return }
        await vm.fetchLeagueData(for: league)
        if vm.errorMessage == nil && !vm.teams.isEmpty {
            await generateRoasts()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(_ vm: PowerRankingsViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: { vm.toggleRoasts() }) {
                    Label(
                        vm.roastsEnabled ? "Hide Roasts" : "Show Roasts",
                        systemImage: vm.roastsEnabled ? "eye.slash" : "eye"
                    )
                }
                Divider()
                Button(action: { showingExportOptions = true }) {
                    Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                }
                .disabled(vm.teams.isEmpty)
                ShareLink(
                    item: vm.formatForExport(includeRoasts: vm.roastsEnabled),
                    subject: Text("\(league.leagueName) Power Rankings"),
                    message: Text("Check out the latest power rankings!")
                ) {
                    Label("Share Rankings", systemImage: "square.and.arrow.up")
                }
                .disabled(vm.teams.isEmpty)
                Divider()
                Button(action: { showingContextEditor = true }) {
                    Label("Edit League Context", systemImage: "pencil")
                }
                Button(action: { Task { await generateRoasts() } }) {
                    Label("Generate Roasts", systemImage: "sparkles")
                }
                .disabled(vm.isLoading)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Week Selector Bar

    @ViewBuilder
    private func weekSelectorBar(_ vm: PowerRankingsViewModel) -> some View {
        VStack(spacing: 10) {
            // Season phase badge
            if vm.seasonPhase == .offseason {
                Text("🏈 Offseason — Final Standings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            
            HStack(spacing: 16) {
                Button {
                    Task {
                        await vm.navigateToWeek(vm.selectedWeek - 1)
                        guard !Task.isCancelled else { return }
                        if !hasAnyRoasts { await generateRoasts() }
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(vm.selectedWeek <= 1 ? .gray.opacity(0.3) : .orange)
                }
                .disabled(vm.selectedWeek <= 1)

                VStack(spacing: 4) {
                    Text(weekLabel(vm))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    
                    if vm.seasonPhase != .offseason {
                        if vm.selectedWeek == vm.currentWeek {
                            Text("Current Week")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                        } else {
                            Text("Past Week")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Dot indicators for cached weeks
                    if vm.currentWeek > 1 {
                        weekDots(vm)
                    }
                }

                Button {
                    Task {
                        await vm.navigateToWeek(vm.selectedWeek + 1)
                        guard !Task.isCancelled else { return }
                        if !hasAnyRoasts { await generateRoasts() }
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(vm.selectedWeek >= vm.currentWeek ? .gray.opacity(0.3) : .orange)
                }
                .disabled(vm.selectedWeek >= vm.currentWeek)
            }

            if !hasAnyRoasts && !vm.isLoading {
                Button {
                    Task { await generateRoasts() }
                } label: {
                    Label("Generate Roasts", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.orange, in: Capsule())
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func weekDots(_ vm: PowerRankingsViewModel) -> some View {
        let maxDotsVisible = 10
        let totalWeeks = vm.currentWeek
        let showDots = totalWeeks <= maxDotsVisible
        
        if showDots {
            HStack(spacing: 4) {
                ForEach(1...totalWeeks, id: \.self) { week in
                    Circle()
                        .fill(dotColor(week: week, selected: vm.selectedWeek, available: vm.availableWeeks))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 2)
        } else {
            Text("\(vm.selectedWeek) of \(totalWeeks)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func dotColor(week: Int, selected: Int, available: [Int]) -> Color {
        if week == selected {
            return .orange
        } else if available.contains(week) {
            return .orange.opacity(0.4)
        } else {
            return .gray.opacity(0.3)
        }
    }

    private func weekLabel(_ vm: PowerRankingsViewModel) -> String {
        if vm.seasonPhase == .offseason {
            return "Offseason"
        }
        let base = "Week \(vm.selectedWeek)"
        return vm.seasonPhase == .playoffs ? "\(base) — Playoffs" : base
    }

    // MARK: - Rankings Scroll View

    private func rankingsScrollView(_ vm: PowerRankingsViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                weekSelectorBar(vm)

                statusBanners(vm)

                if let lastUpdated = vm.lastUpdated {
                    timestampView(lastUpdated, vm: vm)
                }

                if vm.isLoading && !vm.teams.isEmpty {
                    roastLoadingBanner
                }

                ForEach(vm.teams) { team in
                    TeamCardView(team: team, showRoast: vm.roastsEnabled)
                        .scrollTransition(.animated(.spring(duration: 0.4))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.4)
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .offset(y: phase.isIdentity ? 0 : 30)
                                .blur(radius: phase.isIdentity ? 0 : 2)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Status Banners

    @ViewBuilder
    private func statusBanners(_ vm: PowerRankingsViewModel) -> some View {
        if !serviceContainer.networkMonitor.isConnected {
            StatusBanner(
                icon: "wifi.slash",
                message: "No Internet Connection",
                gradient: [Color.orange, Color.orange.opacity(0.8)]
            )
        }

        if let error = vm.errorMessage {
            StatusBanner(
                icon: "exclamationmark.triangle.fill",
                message: error,
                gradient: [Color.red, Color.red.opacity(0.8)],
                action: ("Retry", { Task { await retryFetch() } })
            )
        }

        if vm.isCacheStale && vm.usingCachedData {
            StatusBanner(
                icon: "clock.badge.exclamationmark",
                message: "Data is stale. Pull to refresh.",
                gradient: [Color.yellow.opacity(0.8), Color.orange.opacity(0.7)]
            )
        }
    }

    private func timestampView(_ date: Date, vm: PowerRankingsViewModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Updated \(formattedDate(date))")
                .font(.system(size: 12, weight: .medium))
            if let age = vm.getCacheAgeInHours(forLeagueId: league.leagueId), age > 0 {
                Text("(\(age)h ago)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(age >= 24 ? .orange : .secondary)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var roastLoadingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(.orange)
            Text("Generating roasts...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty / Loading States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.orange)
            Text("Loading rankings...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(.orange.opacity(0.5))
                .symbolEffect(.wiggle, options: .repeating.speed(0.3))

            Text("No Rankings Available")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Pull to refresh or check your connection")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                Task { await retryFetch() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.orange, in: Capsule())
            }
        }
        .padding(32)
    }

    // MARK: - Helpers

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func generateRoasts() async {
        guard let vm = viewModel, let cvm = contextViewModel else { return }
        await vm.generateRoasts(context: cvm.context)
    }
}

// MARK: - Status Banner Component

struct StatusBanner: View {
    let icon: String
    let message: String
    let gradient: [Color]
    var action: (String, () -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            if let (label, handler) = action {
                Button(action: handler) {
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.25), in: Capsule())
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}
