import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let monitor = appState.outputMonitor
        let sessionIDs = appState.activeTab?.rootNode.allSessionIDs ?? []

        if !monitor.panelStates.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(sessionIDs.enumerated()), id: \.element) { index, sessionID in
                    let state = monitor.state(for: sessionID)
                    HStack(spacing: 3) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(state.icon)
                            .font(.system(size: 10))
                    }
                }

                Spacer()

                if monitor.totalMonitored > 0 {
                    Text(summaryText(monitor: monitor))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        }
    }

    private func summaryText(monitor: OutputMonitor) -> String {
        let done = monitor.completedCount + monitor.errorCount
        let total = monitor.totalMonitored
        if monitor.errorCount > 0 {
            return "\(done)/\(total) 완료 · \(monitor.errorCount) 에러"
        } else if done == total {
            return "모두 완료"
        } else {
            return "\(done)/\(total) 완료"
        }
    }
}

extension PanelState {
    var icon: String {
        switch self {
        case .idle: return "💤"
        case .generating: return "⏳"
        case .completed: return "✅"
        case .error: return "❌"
        }
    }

    var borderColor: NSColor {
        switch self {
        case .idle: return NSColor.separatorColor.withAlphaComponent(0.2)
        case .generating: return NSColor.systemBlue.withAlphaComponent(0.6)
        case .completed: return NSColor.systemGreen.withAlphaComponent(0.7)
        case .error: return NSColor.systemRed.withAlphaComponent(0.7)
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .idle: return 1
        case .generating, .completed, .error: return 2
        }
    }
}
