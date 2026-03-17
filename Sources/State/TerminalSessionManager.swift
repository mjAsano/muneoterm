import AppKit
import SwiftTerm

class TerminalSessionManager {
    private var sessions: [UUID: SessionInfo] = [:]

    struct SessionInfo {
        let terminalView: LocalProcessTerminalView
        let delegate: TerminalSessionDelegate
        var title: String
        var isRunning: Bool
    }

    func createSession(theme: Theme) -> UUID {
        let id = UUID()
        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))

        let delegate = TerminalSessionDelegate(sessionID: id, manager: self)
        terminalView.processDelegate = delegate

        applyTheme(theme, to: terminalView)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        for (key, value) in ProcessInfo.processInfo.environment {
            if key != "TERM" {
                env.append("\(key)=\(value)")
            }
        }

        terminalView.startProcess(
            executable: shell,
            args: [],
            environment: env,
            execName: nil
        )

        sessions[id] = SessionInfo(
            terminalView: terminalView,
            delegate: delegate,
            title: "Terminal",
            isRunning: true
        )

        return id
    }

    func terminalView(for sessionID: UUID) -> LocalProcessTerminalView? {
        sessions[sessionID]?.terminalView
    }

    func removeSession(_ sessionID: UUID) {
        sessions.removeValue(forKey: sessionID)
    }

    func focusSession(_ sessionID: UUID) {
        guard let view = sessions[sessionID]?.terminalView,
              let window = view.window else { return }
        window.makeFirstResponder(view)
    }

    func updateTitle(_ title: String, for sessionID: UUID) {
        sessions[sessionID]?.title = title
    }

    func markTerminated(_ sessionID: UUID) {
        sessions[sessionID]?.isRunning = false
    }

    func title(for sessionID: UUID) -> String {
        sessions[sessionID]?.title ?? "Terminal"
    }

    func applyTheme(_ theme: Theme) {
        for (_, info) in sessions {
            applyTheme(theme, to: info.terminalView)
        }
    }

    private func applyTheme(_ theme: Theme, to view: LocalProcessTerminalView) {
        view.font = theme.nsFont
        view.nativeForegroundColor = theme.nsForegroundColor
        view.nativeBackgroundColor = theme.nsBackgroundColor

        let colors: [SwiftTerm.Color] = [
            swiftTermColor(theme.ansiColors.black),
            swiftTermColor(theme.ansiColors.red),
            swiftTermColor(theme.ansiColors.green),
            swiftTermColor(theme.ansiColors.yellow),
            swiftTermColor(theme.ansiColors.blue),
            swiftTermColor(theme.ansiColors.magenta),
            swiftTermColor(theme.ansiColors.cyan),
            swiftTermColor(theme.ansiColors.white),
            swiftTermColor(theme.ansiColors.brightBlack),
            swiftTermColor(theme.ansiColors.brightRed),
            swiftTermColor(theme.ansiColors.brightGreen),
            swiftTermColor(theme.ansiColors.brightYellow),
            swiftTermColor(theme.ansiColors.brightBlue),
            swiftTermColor(theme.ansiColors.brightMagenta),
            swiftTermColor(theme.ansiColors.brightCyan),
            swiftTermColor(theme.ansiColors.brightWhite),
        ]
        view.installColors(colors)
    }

    private func swiftTermColor(_ c: CodableColor) -> SwiftTerm.Color {
        SwiftTerm.Color(
            red: UInt16(c.red * 65535),
            green: UInt16(c.green * 65535),
            blue: UInt16(c.blue * 65535)
        )
    }
}

// MARK: - Terminal Delegate

class TerminalSessionDelegate: NSObject, LocalProcessTerminalViewDelegate {
    let sessionID: UUID
    weak var manager: TerminalSessionManager?
    var onTitleChanged: ((String) -> Void)?
    var onProcessTerminated: (() -> Void)?

    init(sessionID: UUID, manager: TerminalSessionManager) {
        self.sessionID = sessionID
        self.manager = manager
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // SwiftTerm handles PTY resize internally
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        manager?.updateTitle(title, for: sessionID)
        onTitleChanged?(title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // Could update tab title with current directory
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        manager?.markTerminated(sessionID)
        onProcessTerminated?()
    }
}
