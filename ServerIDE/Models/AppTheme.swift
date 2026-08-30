import SwiftUI

// MARK: - App Themes (Glass & OLED Matrix)
enum AppTheme: String, CaseIterable, Identifiable {
    case emeraldMatrix = "emerald_matrix"
    case obsidianGlow  = "obsidian_glow"
    case titaniumSteel = "titanium_steel"
    case nebulaViolet  = "nebula_violet"
    case solarFlare    = "solar_flare"
    case arcticClean   = "arctic_clean"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emeraldMatrix: return "Cyber Emerald · زمرد رقمي"
        case .obsidianGlow:  return "Obsidian Void · أسود ملكي"
        case .titaniumSteel: return "Titanium Dark · تيتانيوم"
        case .nebulaViolet:  return "Nebula Glass · سديم بنفسجي"
        case .solarFlare:    return "Solar Flame · شعلة شمسية"
        case .arcticClean:   return "Pure Frost · جليدي فاتح"
        }
    }

    var accent: Color {
        switch self {
        case .emeraldMatrix: return Color(red: 0.13, green: 0.95, blue: 0.62) // Neon Emerald
        case .obsidianGlow:  return Color(red: 0.20, green: 0.78, blue: 1.00) // Electric Cyan
        case .titaniumSteel: return Color(red: 0.40, green: 0.70, blue: 0.95) // Ice Steel
        case .nebulaViolet:  return Color(red: 0.75, green: 0.40, blue: 1.00) // Neon Purple
        case .solarFlare:    return Color(red: 1.00, green: 0.55, blue: 0.15) // Amber Glow
        case .arcticClean:   return Color(red: 0.05, green: 0.60, blue: 0.45)
        }
    }

    var secondaryAccent: Color {
        switch self {
        case .emeraldMatrix: return Color(red: 0.00, green: 0.72, blue: 0.88)
        case .obsidianGlow:  return Color(red: 0.45, green: 0.35, blue: 0.95)
        case .titaniumSteel: return Color(red: 0.30, green: 0.45, blue: 0.65)
        case .nebulaViolet:  return Color(red: 0.95, green: 0.30, blue: 0.70)
        case .solarFlare:    return Color(red: 0.95, green: 0.25, blue: 0.30)
        case .arcticClean:   return Color(red: 0.10, green: 0.40, blue: 0.80)
        }
    }

    var background: Color {
        switch self {
        case .emeraldMatrix: return Color(red: 0.02, green: 0.04, blue: 0.035)
        case .obsidianGlow:  return Color(red: 0.015, green: 0.015, blue: 0.02)
        case .titaniumSteel: return Color(red: 0.05, green: 0.06, blue: 0.08)
        case .nebulaViolet:  return Color(red: 0.04, green: 0.02, blue: 0.06)
        case .solarFlare:    return Color(red: 0.05, green: 0.03, blue: 0.02)
        case .arcticClean:   return Color(red: 0.96, green: 0.97, blue: 0.99)
        }
    }

    var surface: Color {
        switch self {
        case .emeraldMatrix: return Color(red: 0.06, green: 0.11, blue: 0.09).opacity(0.65)
        case .obsidianGlow:  return Color(red: 0.08, green: 0.08, blue: 0.11).opacity(0.65)
        case .titaniumSteel: return Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.65)
        case .nebulaViolet:  return Color(red: 0.10, green: 0.06, blue: 0.14).opacity(0.65)
        case .solarFlare:    return Color(red: 0.12, green: 0.07, blue: 0.06).opacity(0.65)
        case .arcticClean:   return Color.white.opacity(0.75)
        }
    }

    var scheme: ColorScheme { self == .arcticClean ? .light : .dark }
}

// MARK: - Deep Glass Background with Animated-like Mesh Glow
struct StudioBackground: View {
    @AppStorage("appTheme") private var storedTheme = AppTheme.emeraldMatrix.rawValue
    private var theme: AppTheme { AppTheme(rawValue: storedTheme) ?? .emeraldMatrix }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [theme.accent.opacity(0.20), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [theme.secondaryAccent.opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 500
            )
            .ignoresSafeArea()

            // Subtle Cyber Grid Overlay
            VStack {
                Spacer()
                Circle()
                    .fill(theme.accent.opacity(0.06))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -80, y: 100)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Ultra Glassmorphism Surface Modifier
struct StudioSurface: ViewModifier {
    var cornerRadius: CGFloat = 22
    var glowColor: Color? = nil
    var isInteractive: Bool = false
    @AppStorage("appTheme") private var storedTheme = AppTheme.emeraldMatrix.rawValue
    private var theme: AppTheme { AppTheme(rawValue: storedTheme) ?? .emeraldMatrix }

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.surface)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                (glowColor ?? theme.accent).opacity(0.45),
                                .white.opacity(0.12),
                                (glowColor ?? theme.secondaryAccent).opacity(0.20),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: (glowColor ?? theme.accent).opacity(isInteractive ? 0.22 : 0.08),
                radius: 18,
                x: 0,
                y: 9
            )
    }
}

// MARK: - Modern Glowing Glass Icon Pod
struct GlassIconPod: View {
    var icon: String
    var color: Color
    var size: CGFloat = 46
    var iconSize: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.15))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.60), color.opacity(0.15), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: color.opacity(0.30), radius: 8, x: 0, y: 4)

            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Smart Terminal Syntax Colorizer (Rich Text Parser)
struct TerminalSyntaxHighlighter {
    static func highlight(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = Color(white: 0.90)
        attr.font = .system(size: 13.5, weight: .regular, design: .monospaced)

        // Rule: Python commands & keywords (Red & Coral)
        colorize(pattern: #"\b(python|python3|pip|pip3|pytest|django|flask|import|from|def|class|return)\b"#,
                 in: &attr, original: text, color: Color(red: 1.00, green: 0.32, blue: 0.35))

        // Rule: SSH & System Core Commands (Emerald Green)
        colorize(pattern: #"\b(ssh|sudo|systemctl|service|apt|yum|dnf|brew|nginx|docker|git)\b"#,
                 in: &attr, original: text, color: Color(red: 0.15, green: 0.92, blue: 0.58))

        // Rule: Network & Tools (Electric Cyan)
        colorize(pattern: #"\b(curl|wget|ping|traceroute|whois|dig|nslookup|netstat|nmap|ip|ifconfig)\b"#,
                 in: &attr, original: text, color: Color(red: 0.20, green: 0.82, blue: 1.00))

        // Rule: Success/Pass Status (Bright Neon Green)
        colorize(pattern: #"\b(SUCCESS|OK|PASSED|ACTIVE|CONNECTED|GOOD)\b"#,
                 in: &attr, original: text, color: Color(red: 0.20, green: 0.95, blue: 0.50))

        // Rule: Warnings & Alerts (Vibrant Amber)
        colorize(pattern: #"\b(WARNING|WARN|ALERT|CAUTION|PENDING)\b"#,
                 in: &attr, original: text, color: Color(red: 1.00, green: 0.65, blue: 0.15))

        // Rule: Errors, Fails & Criticals (Crimson Red)
        colorize(pattern: #"\b(ERROR|FAIL|FAILED|CRITICAL|DENIED|FATAL|Exception)\b"#,
                 in: &attr, original: text, color: Color(red: 1.00, green: 0.25, blue: 0.30))

        // Rule: IP Addresses & Ports (Neon Purple/Violet)
        colorize(pattern: #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?\b"#,
                 in: &attr, original: text, color: Color(red: 0.78, green: 0.45, blue: 1.00))

        // Rule: Domain names / URLs (Gold / Yellow)
        colorize(pattern: #"\b([a-zA-Z0-9-]+\.)+(com|cc|org|net|io|sa|app|dev)\b"#,
                 in: &attr, original: text, color: Color(red: 1.00, green: 0.85, blue: 0.30))

        return attr
    }

    private static func colorize(pattern: String, in attr: inout AttributedString, original: String, color: Color) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
        let range = NSRange(original.startIndex..<original.endIndex, in: original)
        let matches = regex.matches(in: original, options: [], range: range)

        for match in matches {
            if let swiftRange = Range(match.range, in: original),
               let attrRange = Range(swiftRange, in: attr) {
                attr[attrRange].foregroundColor = color
                attr[attrRange].font = .system(size: 13.5, weight: .bold, design: .monospaced)
            }
        }
    }
}

// MARK: - View Extension Helpers
extension View {
    func studioSurface(glow: Color? = nil, interactive: Bool = false) -> some View {
        modifier(StudioSurface(glowColor: glow, isInteractive: interactive))
    }
}
