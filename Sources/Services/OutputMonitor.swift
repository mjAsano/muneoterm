import Foundation
import SwiftTerm
import os.log

class OutputMonitor {
    private let logger = Logger(subsystem: "com.hosun.terminal", category: "OutputMonitor")

    private weak var sessionManager: TerminalSessionManager?
    private var fingerprints: [UUID: (hash: Int, lastChangeTime: Date)] = [:]
    private var pollTimer: Timer?

    private let idleThreshold: TimeInterval = 3.0
    private let pollInterval: TimeInterval = 0.5

    private(set) var panelStates: [UUID: PanelState] = [:]
    var onStateChanged: (() -> Void)?

    init(sessionManager: TerminalSessionManager) {
        self.sessionManager = sessionManager
    }

    deinit {
        stopPolling()
    }

    // MARK: - Public

    func startMonitoring(sessionIDs: [UUID]) {
        for id in sessionIDs {
            panelStates[id] = .generating
            fingerprints[id] = (hash: 0, lastChangeTime: Date())
        }
        startPolling()
        onStateChanged?()
        logger.info("Started monitoring \(sessionIDs.count) sessions")
    }

    func stopMonitoring(sessionID: UUID) {
        panelStates.removeValue(forKey: sessionID)
        fingerprints.removeValue(forKey: sessionID)
        if !panelStates.values.contains(.generating) {
            stopPolling()
        }
        onStateChanged?()
    }

    func resetState(sessionID: UUID) {
        panelStates[sessionID] = .idle
        fingerprints.removeValue(forKey: sessionID)
        onStateChanged?()
    }

    func stopAll() {
        panelStates.removeAll()
        fingerprints.removeAll()
        stopPolling()
        onStateChanged?()
    }

    /// Summary counts for current tab
    var completedCount: Int {
        panelStates.values.filter { $0 == .completed }.count
    }

    var errorCount: Int {
        panelStates.values.filter { $0 == .error }.count
    }

    var generatingCount: Int {
        panelStates.values.filter { $0 == .generating }.count
    }

    var totalMonitored: Int {
        panelStates.count
    }

    var allFinished: Bool {
        !panelStates.isEmpty && generatingCount == 0
    }

    func state(for sessionID: UUID) -> PanelState {
        panelStates[sessionID] ?? .idle
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        guard let manager = sessionManager else {
            stopPolling()
            return
        }

        var changed = false

        for (id, state) in panelStates where state == .generating {
            guard let terminalView = manager.terminalView(for: id) else { continue }
            let terminal = terminalView.getTerminal()

            let currentHash = captureFingerprint(terminal: terminal)

            if let previous = fingerprints[id] {
                if currentHash != previous.hash {
                    // Content changed — reset idle timer
                    fingerprints[id] = (hash: currentHash, lastChangeTime: Date())
                } else {
                    // Content unchanged — check if idle long enough
                    if Date().timeIntervalSince(previous.lastChangeTime) >= idleThreshold {
                        if detectError(terminal: terminal) {
                            panelStates[id] = .error
                            logger.info("Session \(id.uuidString.prefix(8)): generating → error")
                        } else {
                            panelStates[id] = .completed
                            logger.info("Session \(id.uuidString.prefix(8)): generating → completed")
                        }
                        changed = true
                    }
                }
            } else {
                fingerprints[id] = (hash: currentHash, lastChangeTime: Date())
            }
        }

        if changed {
            onStateChanged?()
        }

        // Stop polling when nothing is generating
        if !panelStates.values.contains(.generating) {
            stopPolling()
            logger.info("All sessions finished. Polling stopped.")
        }
    }

    // MARK: - Fingerprint

    private func captureFingerprint(terminal: Terminal) -> Int {
        var hasher = Hasher()
        for row in 0..<terminal.rows {
            if let line = terminal.getLine(row: row) {
                hasher.combine(line.translateToString())
            }
        }
        return hasher.finalize()
    }

    // MARK: - Error Detection

    private static let errorPatterns = [
        "error:", "error.", "apierror", "rate_limit",
        "overloaded_error", "an error occurred", "failed",
        "connection refused", "timed out", "permission denied"
    ]

    private func detectError(terminal: Terminal) -> Bool {
        let checkRows = min(8, terminal.rows)
        for row in (terminal.rows - checkRows)..<terminal.rows {
            guard let line = terminal.getLine(row: row) else { continue }
            let text = line.translateToString().lowercased()
            for pattern in Self.errorPatterns {
                if text.contains(pattern) {
                    return true
                }
            }
        }
        return false
    }
}
