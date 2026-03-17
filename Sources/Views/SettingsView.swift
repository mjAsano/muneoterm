import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedThemeID: String = Theme.defaultDark.id

    var body: some View {
        TabView {
            appearanceSettings
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            fontSettings
                .tabItem { Label("Font", systemImage: "textformat") }

            keyBindingsInfo
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 450, height: 350)
        .onAppear {
            selectedThemeID = appState.currentTheme.id
        }
    }

    // MARK: - Appearance

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Theme")
                .font(.headline)

            ForEach(Theme.allBuiltIn) { theme in
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: theme.nsBackgroundColor))
                        .frame(width: 40, height: 30)
                        .overlay(
                            Text("A")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(nsColor: theme.nsForegroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                    Text(theme.name)
                        .font(.system(size: 13))

                    Spacer()

                    if selectedThemeID == theme.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedThemeID = theme.id
                    appState.applyTheme(theme)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Font

    private var fontSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Font")
                .font(.headline)

            HStack {
                Text("Current: \(appState.currentTheme.fontName)")
                    .font(.system(size: 13))
                Text("(\(Int(appState.currentTheme.fontSize))pt)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Text("Font can be changed by editing the theme configuration.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Key Bindings

    private var keyBindingsInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Group {
                shortcutRow("New Tab", shortcut: "Cmd + T")
                shortcutRow("Close Panel", shortcut: "Cmd + W")
                shortcutRow("Split Horizontal", shortcut: "Cmd + D")
                shortcutRow("Split Vertical", shortcut: "Cmd + Shift + D")
                shortcutRow("Navigate Left", shortcut: "Cmd + Option + ←")
                shortcutRow("Navigate Right", shortcut: "Cmd + Option + →")
                shortcutRow("Navigate Up", shortcut: "Cmd + Option + ↑")
                shortcutRow("Navigate Down", shortcut: "Cmd + Option + ↓")
                shortcutRow("Next Tab", shortcut: "Cmd + Shift + ]")
                shortcutRow("Previous Tab", shortcut: "Cmd + Shift + [")
            }

            Spacer()
        }
        .padding(20)
    }

    private func shortcutRow(_ name: String, shortcut: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
    }
}
