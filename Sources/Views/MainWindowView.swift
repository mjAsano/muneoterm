import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()

            SplitContainerRepresentable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: appState.currentTheme.nsBackgroundColor))
        .focusedObject(appState)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let sessionID = appState.activeSessionID {
                    appState.sessionManager.focusSession(sessionID)
                }
            }
        }
    }
}
