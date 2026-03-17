import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState

    private func setupTabKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Tab key (keyCode 48), Ctrl+Tab으로 패널 전환
            if event.keyCode == 48 && event.modifierFlags.contains(.control) {
                if event.modifierFlags.contains(.shift) {
                    appState.focusPreviousPanel()
                } else {
                    appState.focusNextPanel()
                }
                return nil // 이벤트 소비
            }
            return event
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            QuickCommandBarView()

            if appState.showBroadcastInput {
                BroadcastInputBarView(isVisible: $appState.showBroadcastInput)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            StatusBarView()

            SplitContainerRepresentable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.15), value: appState.showBroadcastInput)
        .background(Color(nsColor: appState.currentTheme.nsBackgroundColor))
        .focusedObject(appState)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let sessionID = appState.activeSessionID {
                    appState.sessionManager.focusSession(sessionID)
                }
            }
            setupTabKeyMonitor()
        }
    }
}
