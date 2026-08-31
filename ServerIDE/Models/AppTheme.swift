import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case aurora, midnight, ocean, ember, forest, paper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .aurora: return "Aurora · شفق"
        case .midnight: return "Midnight · ليلي"
        case .ocean: return "Ocean · محيط"
        case .ember: return "Ember · كهرماني"
        case .forest: return "Forest · غابة"
        case .paper: return "Paper · فاتح"
        }
    }
    var accent: Color {
        switch self {
        case .aurora: return Color(red: 0.25, green: 0.76, blue: 1.0)
        case .midnight: return Color(red: 0.67, green: 0.55, blue: 1)
        case .ocean: return .cyan
        case .ember: return .orange
        case .forest: return .mint
        case .paper: return .indigo
        }
    }
    var secondaryAccent: Color {
        switch self {
        case .aurora: return Color(red: 0.66, green: 0.38, blue: 1.0)
        case .midnight: return Color(red: 0.30, green: 0.78, blue: 1.0)
        case .ocean: return Color(red: 0.28, green: 0.45, blue: 0.96)
        case .ember: return Color(red: 1.0, green: 0.28, blue: 0.36)
        case .forest: return Color(red: 0.18, green: 0.72, blue: 0.88)
        case .paper: return Color(red: 0.12, green: 0.42, blue: 0.84)
        }
    }
    var background: Color {
        switch self {
        case .aurora: return Color(red: 0.025, green: 0.045, blue: 0.105)
        case .midnight: return Color(red: 0.055, green: 0.045, blue: 0.10)
        case .ocean: return Color(red: 0.025, green: 0.075, blue: 0.12)
        case .ember: return Color(red: 0.10, green: 0.055, blue: 0.04)
        case .forest: return Color(red: 0.035, green: 0.085, blue: 0.065)
        case .paper: return Color(red: 0.95, green: 0.95, blue: 0.98)
        }
    }
    var scheme: ColorScheme { self == .paper ? .light : .dark }
    var surface: Color { self == .paper ? .white.opacity(0.78) : .white.opacity(0.075) }
}

struct StudioBackground: View {
    @AppStorage("appTheme") private var storedTheme = "aurora"
    private var theme: AppTheme { AppTheme(rawValue: storedTheme) ?? .aurora }
    var body: some View {
        ZStack {
            theme.background
            RadialGradient(colors: [theme.accent.opacity(0.28), .clear], center: .topLeading, startRadius: 20, endRadius: 440)
            RadialGradient(colors: [theme.secondaryAccent.opacity(0.18), .clear], center: .bottomTrailing, startRadius: 30, endRadius: 520)
        }.ignoresSafeArea()
    }
}

struct StudioSurface: ViewModifier {
    var glowColor: Color? = nil
    var isInteractive = false
    @AppStorage("appTheme") private var storedTheme = "aurora"
    private var theme: AppTheme { AppTheme(rawValue: storedTheme) ?? .aurora }
    func body(content: Content) -> some View {
        let glow = glowColor ?? theme.accent
        content.padding(18)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LinearGradient(colors: [glow.opacity(0.48), .white.opacity(0.12), theme.secondaryAccent.opacity(0.22), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
            .shadow(color: glow.opacity(isInteractive ? 0.22 : 0.09), radius: 18, x: 0, y: 9)
    }
}

extension View {
    func studioSurface(glow: Color? = nil, interactive: Bool = false) -> some View {
        modifier(StudioSurface(glowColor: glow, isInteractive: interactive))
    }
}
