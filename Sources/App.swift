import SwiftUI

@main
struct MuneoTermApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            TerminalCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Menu Commands

struct TerminalCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                appState.addTab()
            }
            .keyboardShortcut("t", modifiers: .command)

            Divider()

            Button("Split Horizontally") {
                appState.splitActive(direction: .horizontal)
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("Split Vertically") {
                appState.splitActive(direction: .vertical)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Button("Close Panel") {
                appState.closeActivePanel()
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        CommandMenu("Broadcast") {
            Button("브로드캐스트 입력창 토글") {
                appState.showBroadcastInput.toggle()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Divider()

            Button("Launch Claude (All Panels)") {
                appState.launchClaudeAllPanels()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        // MARK: - 패널 직접 포커스 (⌘1~⌘8)
        CommandGroup(after: .toolbar) {
            Section {
                ForEach(1...8, id: \.self) { num in
                    Button("Panel \(num)") {
                        appState.focusPanel(number: num)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(num)")), modifiers: .command)
                }
            }

            Divider()

            Button("Next Tab") {
                appState.selectNextTab()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("Previous Tab") {
                appState.selectPreviousTab()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Divider()

            Button("Navigate Left") {
                appState.navigatePanel(direction: .left)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

            Button("Navigate Right") {
                appState.navigatePanel(direction: .right)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

            Button("Navigate Up") {
                appState.navigatePanel(direction: .up)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])

            Button("Navigate Down") {
                appState.navigatePanel(direction: .down)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)

        // Set dock icon from asset catalog
        if let icon = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
}
