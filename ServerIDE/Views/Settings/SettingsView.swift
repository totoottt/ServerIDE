import SwiftUI

struct SettingsView: View {
    @AppStorage("terminalTheme") private var terminalTheme = "cyber_matrix"
    @AppStorage("terminalFontSize") private var fontSize = 14.0
    @AppStorage("appTheme") private var appTheme = AppTheme.emeraldMatrix.rawValue
    @EnvironmentObject private var store: ServerStore
    @AppStorage("terminalWrapLines") private var terminalWrap = true
    @AppStorage("fileWrapNames") private var fileWrap = true
    @AppStorage("fileFontSize") private var fileSize = 15.0

    private var activeTheme: AppTheme { AppTheme(rawValue: appTheme) ?? .emeraldMatrix }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.8.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "24"
    }

    private var releaseMarker: String {
        Bundle.main.object(forInfoDictionaryKey: "ServerIDEReleaseMarker") as? String ?? "PRO-GLASS-2026"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Section: App Theme & Cyber Palette
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        GlassIconPod(icon: "paintpalette.fill", color: activeTheme.accent, size: 36, iconSize: 16)
                        Text("APPEARANCE & THEMES")
                            .font(.caption.bold())
                            .tracking(2)
                            .foregroundStyle(activeTheme.accent)
                    }

                    Text("اختر المظهر الزجاجي الخاص بك:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Theme selector cards
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(AppTheme.allCases) { style in
                            Button {
                                appTheme = style.rawValue
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(style.accent)
                                        .frame(width: 14, height: 14)
                                        .shadow(color: style.accent, radius: 4)
                                    Text(style.title.components(separatedBy: " · ").first ?? style.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(appTheme == style.rawValue ? .white : .secondary)
                                    Spacer()
                                    if appTheme == style.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(style.accent)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(appTheme == style.rawValue ? style.accent.opacity(0.18) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(appTheme == style.rawValue ? style.accent.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .studioSurface(glow: activeTheme.accent)

                // Section: Terminal & Console Engine
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        GlassIconPod(icon: "terminal.fill", color: Color(red: 0.15, green: 0.92, blue: 0.58), size: 36, iconSize: 16)
                        Text("TERMINAL SYNTAX & ENGINE")
                            .font(.caption.bold())
                            .tracking(2)
                            .foregroundStyle(Color(red: 0.15, green: 0.92, blue: 0.58))
                    }

                    // Terminal Live Preview with Colorized Syntax
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                            Spacer()
                            Text("bash · zsh · python").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 4)

                        Text(TerminalSyntaxHighlighter.highlight("root@matrix:~# python3 manage.py runserver 127.0.0.1:8000\n[OK] HTTP server connected to tootottt.cc\n[WARNING] DKIM key missing in DNS\n[ERROR] Port 22 connection timeout"))
                            .lineSpacing(4)
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    VStack(spacing: 12) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(fontSize)) pt").font(.caption.bold().monospaced()).foregroundStyle(activeTheme.accent)
                        }
                        Slider(value: $fontSize, in: 10...26, step: 1)
                            .tint(activeTheme.accent)

                        Toggle("Wrap terminal lines", isOn: $terminalWrap)
                            .tint(activeTheme.accent)
                    }
                }
                .studioSurface(glow: Color(red: 0.15, green: 0.92, blue: 0.58))

                // Section: Security & Credentials
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        GlassIconPod(icon: "lock.shield.fill", color: Color(red: 0.20, green: 0.82, blue: 1.00), size: 36, iconSize: 16)
                        Text("SECURITY & KEYCHAIN")
                            .font(.caption.bold())
                            .tracking(2)
                            .foregroundStyle(Color(red: 0.20, green: 0.82, blue: 1.00))
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .foregroundColor(Color(red: 1.00, green: 0.75, blue: 0.20))
                        Text("Encrypted via iOS Keychain hardware enclave")
                            .font(.subheadline)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(Color(red: 0.15, green: 0.92, blue: 0.58))
                        Text("Zero analytics or external telemetry logging")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .studioSurface(glow: Color(red: 0.20, green: 0.82, blue: 1.00))

                // Section: About
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ServerIDE Glass Pro")
                            .font(.headline)
                        Spacer()
                        Text("v\(version) (\(build))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Text("A premium developer workspace tailored with next-generation glassmorphism and syntax highlighting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .studioSurface()
            }
            .padding(20)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .background(StudioBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
