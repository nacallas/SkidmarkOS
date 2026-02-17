import SwiftUI

/// Individual team card with tier-based styling, stats, and optional roast
struct TeamCardView: View {
    let team: Team
    let showRoast: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row: rank badge, team info, streak
            HStack(alignment: .top, spacing: 14) {
                rankBadge
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(tierTextColor)
                        .lineLimit(1)
                    
                    Text(team.ownerName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                streakBadge
            }
            
            // Stats row
            HStack(spacing: 20) {
                statItem(label: "Record", value: team.record)
                statItem(label: "Points", value: String(format: "%.1f", team.pointsFor))
                statItem(label: "Power", value: String(format: "%.3f", team.powerScore))
            }
            .padding(.top, 2)
            
            // Roast
            if showRoast, let roast = team.roast {
                Divider()
                    .overlay(tierAccentColor.opacity(0.2))
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(roast)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(tierAccentColor.opacity(tierBorderOpacity), lineWidth: 1.5)
        )
        .shadow(color: tierAccentColor.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 6, y: 3)
    }
    
    // MARK: - Rank Badge
    
    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: tierGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .shadow(color: tierAccentColor.opacity(0.35), radius: 4, y: 2)
            
            Text("\(team.rank)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Streak Badge
    
    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: team.streak.type == .win ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(team.streak.displayString)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(streakColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(streakColor.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Capsule())
    }
    
    // MARK: - Stat Item
    
    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some ShapeStyle {
        #if os(iOS)
        if colorScheme == .dark {
            return AnyShapeStyle(.ultraThinMaterial)
        } else {
            return AnyShapeStyle(Color(UIColor.systemBackground))
        }
        #else
        return AnyShapeStyle(Color(NSColor.controlBackgroundColor))
        #endif
    }
    
    // MARK: - Tier System
    
    private enum Tier { case elite, strong, middle, bottom }
    
    private var tier: Tier {
        switch team.rank {
        case 1...3: .elite
        case 4...6: .strong
        case 7...9: .middle
        default: .bottom
        }
    }
    
    private var tierGradientColors: [Color] {
        switch tier {
        case .elite: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.3)]
        case .strong: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)]
        case .middle: [Color(red: 1.0, green: 0.7, blue: 0.2), Color(red: 0.9, green: 0.5, blue: 0.1)]
        case .bottom: [Color(red: 1.0, green: 0.4, blue: 0.3), Color(red: 0.8, green: 0.2, blue: 0.2)]
        }
    }
    
    private var tierAccentColor: Color {
        switch tier {
        case .elite: Color(red: 0.2, green: 0.8, blue: 0.4)
        case .strong: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .middle: Color(red: 1.0, green: 0.7, blue: 0.2)
        case .bottom: Color(red: 1.0, green: 0.4, blue: 0.3)
        }
    }
    
    private var tierTextColor: Color {
        switch tier {
        case .elite: colorScheme == .dark ? Color(red: 0.3, green: 0.9, blue: 0.5) : Color(red: 0.1, green: 0.6, blue: 0.3)
        case .strong: colorScheme == .dark ? Color(red: 0.4, green: 0.7, blue: 1.0) : Color(red: 0.1, green: 0.4, blue: 0.8)
        case .middle: colorScheme == .dark ? Color(red: 1.0, green: 0.8, blue: 0.3) : Color(red: 0.8, green: 0.5, blue: 0.1)
        case .bottom: colorScheme == .dark ? Color(red: 1.0, green: 0.5, blue: 0.4) : Color(red: 0.8, green: 0.2, blue: 0.2)
        }
    }
    
    private var tierBorderOpacity: Double {
        switch tier {
        case .elite: colorScheme == .dark ? 0.5 : 0.35
        case .strong: colorScheme == .dark ? 0.4 : 0.3
        case .middle: colorScheme == .dark ? 0.35 : 0.25
        case .bottom: colorScheme == .dark ? 0.4 : 0.3
        }
    }
    
    private var streakColor: Color {
        team.streak.type == .win
            ? Color(red: 0.2, green: 0.8, blue: 0.4)
            : Color(red: 1.0, green: 0.4, blue: 0.3)
    }
}
