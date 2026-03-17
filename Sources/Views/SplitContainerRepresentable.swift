import SwiftUI

struct SplitContainerRepresentable: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> SplitContainerNSView {
        let view = SplitContainerNSView(sessionManager: appState.sessionManager)
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: SplitContainerNSView, context: Context) {
        context.coordinator.appState = appState

        guard let tab = appState.activeTab else { return }
        nsView.update(node: tab.rootNode, activeSessionID: appState.activeSessionID)
    }

    class Coordinator: NSObject, SplitContainerDelegate {
        var appState: AppState

        init(appState: AppState) {
            self.appState = appState
        }

        func splitContainerDidChangeRatio(_ nodeID: UUID, ratio: CGFloat) {
            appState.updateSplitRatio(nodeID: nodeID, ratio: ratio)
        }

        func splitContainerDidActivateSession(_ sessionID: UUID) {
            appState.activateSession(sessionID)
        }
    }
}
