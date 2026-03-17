import SwiftUI

@main
struct HosunTerminalApp: App {
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

        CommandGroup(after: .toolbar) {
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
        // Set activation policy to regular (shows in dock)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
}
