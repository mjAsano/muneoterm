import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var tabs: [TabModel] = []
    @Published var activeTabIndex: Int = 0
    @Published var activeSessionID: UUID?
    @Published var currentTheme: Theme = .defaultDark

    let sessionManager = TerminalSessionManager()
    private let sessionStore = SessionStore()
    private var cancellables = Set<AnyCancellable>()

    var activeTab: TabModel? {
        guard activeTabIndex >= 0, activeTabIndex < tabs.count else { return nil }
        return tabs[activeTabIndex]
    }

    init() {
        addTab()
    }

    // MARK: - Tab Operations

    func addTab() {
        let sessionID = sessionManager.createSession(theme: currentTheme)
        let tab = TabModel(sessionID: sessionID)
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        activeSessionID = sessionID

        observeTab(tab)
    }

    func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }

        let tab = tabs[index]
        for sid in tab.rootNode.allSessionIDs {
            sessionManager.removeSession(sid)
        }
        tabs.remove(at: index)

        if tabs.isEmpty {
            addTab()
        } else {
            activeTabIndex = min(activeTabIndex, tabs.count - 1)
            activeSessionID = activeTab?.activeSessionID
        }
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeTabIndex = index
        activeSessionID = tabs[index].activeSessionID
        focusActiveSession()
    }

    func selectNextTab() {
        selectTab(at: (activeTabIndex + 1) % tabs.count)
    }

    func selectPreviousTab() {
        selectTab(at: (activeTabIndex - 1 + tabs.count) % tabs.count)
    }

    // MARK: - Split Operations

    func splitActive(direction: SplitDirection) {
        guard let tab = activeTab, let sessionID = activeSessionID else { return }

        let totalPanels = tab.rootNode.allSessionIDs.count
        guard totalPanels < 16 else {
            NSSound.beep()
            return
        }

        let newSessionID = sessionManager.createSession(theme: currentTheme)
        tab.rootNode = tab.rootNode.splitLeaf(
            sessionID: sessionID,
            direction: direction,
            newSessionID: newSessionID
        )
        tab.activeSessionID = newSessionID
        activeSessionID = newSessionID
        objectWillChange.send()
    }

    func closeActivePanel() {
        guard let tab = activeTab, let sessionID = activeSessionID else { return }

        let allSessions = tab.rootNode.allSessionIDs
        if allSessions.count <= 1 {
            closeTab(at: activeTabIndex)
            return
        }

        if let newRoot = tab.rootNode.removeLeaf(sessionID: sessionID) {
            sessionManager.removeSession(sessionID)
            tab.rootNode = newRoot
            let remaining = newRoot.allSessionIDs
            tab.activeSessionID = remaining.first ?? UUID()
            activeSessionID = tab.activeSessionID
            objectWillChange.send()
        }
    }

    // MARK: - Navigation

    func navigatePanel(direction: NavigationDirection) {
        guard let tab = activeTab, let sessionID = activeSessionID else { return }

        if let nextID = tab.rootNode.navigateFrom(sessionID: sessionID, direction: direction) {
            tab.activeSessionID = nextID
            activeSessionID = nextID
            focusActiveSession()
            objectWillChange.send()
        }
    }

    func activateSession(_ sessionID: UUID) {
        guard let tab = activeTab else { return }
        tab.activeSessionID = sessionID
        activeSessionID = sessionID
        focusActiveSession()
        objectWillChange.send()
    }

    // MARK: - Ratio

    func updateSplitRatio(nodeID: UUID, ratio: CGFloat) {
        guard let tab = activeTab else { return }
        tab.rootNode = tab.rootNode.updateRatio(nodeID: nodeID, newRatio: ratio)
    }

    // MARK: - Theme

    func applyTheme(_ theme: Theme) {
        currentTheme = theme
        sessionManager.applyTheme(theme)
        objectWillChange.send()
    }

    // MARK: - Session Persistence

    func saveSession() {
        sessionStore.save(tabs: tabs)
    }

    // MARK: - Private

    private func focusActiveSession() {
        guard let sessionID = activeSessionID else { return }
        sessionManager.focusSession(sessionID)
    }

    private func observeTab(_ tab: TabModel) {
        tab.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
