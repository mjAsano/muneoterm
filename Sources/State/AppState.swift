import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var tabs: [TabModel] = []
    @Published var activeTabIndex: Int = 0
    @Published var activeSessionID: UUID?
    @Published var currentTheme: Theme = .defaultDark
    @Published var quickCommands: [QuickCommand] = []
    @Published var monitorStateVersion: Int = 0
    @Published var showBroadcastInput: Bool = false
    @Published var panelNames: [UUID: String] = [:]

    let sessionManager = TerminalSessionManager()
    let outputMonitor: OutputMonitor
    private let sessionStore = SessionStore()
    private var cancellables = Set<AnyCancellable>()
    private let quickCommandsKey = "savedQuickCommands"

    var activeTab: TabModel? {
        guard activeTabIndex >= 0, activeTabIndex < tabs.count else { return nil }
        return tabs[activeTabIndex]
    }

    init() {
        self.outputMonitor = OutputMonitor(sessionManager: sessionManager)
        loadQuickCommands()
        addTabWith8Split()
        setupOutputMonitor()
    }

    private func setupOutputMonitor() {
        outputMonitor.onStateChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.monitorStateVersion += 1

                // Update tab title with progress counter
                self.updateTabProgress()

                // Notify when all finished
                if self.outputMonitor.allFinished {
                    NotificationService.shared.notifyAllCompleted(
                        total: self.outputMonitor.totalMonitored,
                        errors: self.outputMonitor.errorCount
                    )
                }
            }
        }
        NotificationService.shared.requestPermission()
    }

    private func updateTabProgress() {
        guard let tab = activeTab else { return }
        let done = outputMonitor.completedCount + outputMonitor.errorCount
        let total = outputMonitor.totalMonitored
        if total > 0 {
            tab.title = "\(done)/\(total) 완료"
        }
    }

    // MARK: - 8-Split Layout

    /// 시작 시 8분할 레이아웃 생성 (2행 x 4열 그리드)
    func addTabWith8Split() {
        // 8개 세션 생성
        var sessionIDs: [UUID] = []
        for _ in 0..<8 {
            sessionIDs.append(sessionManager.createSession(theme: currentTheme))
        }

        // 2행 x 4열 그리드 구성
        //  ┌────┬────┬────┬────┐
        //  │ 0  │ 1  │ 2  │ 3  │
        //  ├────┼────┼────┼────┤
        //  │ 4  │ 5  │ 6  │ 7  │
        //  └────┴────┴────┴────┘

        func column(_ top: UUID, _ bottom: UUID) -> SplitNode {
            .split(id: UUID(), direction: .vertical, ratio: 0.5,
                   first: .leaf(id: UUID(), sessionID: top),
                   second: .leaf(id: UUID(), sessionID: bottom))
        }

        let col0 = column(sessionIDs[0], sessionIDs[4])
        let col1 = column(sessionIDs[1], sessionIDs[5])
        let col2 = column(sessionIDs[2], sessionIDs[6])
        let col3 = column(sessionIDs[3], sessionIDs[7])

        // 4열을 수평으로 합치기
        let leftHalf = SplitNode.split(id: UUID(), direction: .horizontal, ratio: 0.5,
                                       first: col0, second: col1)
        let rightHalf = SplitNode.split(id: UUID(), direction: .horizontal, ratio: 0.5,
                                        first: col2, second: col3)
        let root = SplitNode.split(id: UUID(), direction: .horizontal, ratio: 0.5,
                                   first: leftHalf, second: rightHalf)

        let tab = TabModel(sessionID: sessionIDs[0])
        tab.rootNode = root
        tab.activeSessionID = sessionIDs[0]
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        activeSessionID = sessionIDs[0]

        observeTab(tab)
    }

    // MARK: - Tab Operations

    func addTab() {
        addTabWith8Split()
    }

    func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }

        let tab = tabs[index]
        for sid in tab.rootNode.allSessionIDs {
            sessionManager.removeSession(sid)
            outputMonitor.stopMonitoring(sessionID: sid)
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
            outputMonitor.stopMonitoring(sessionID: sessionID)
            tab.rootNode = newRoot
            let remaining = newRoot.allSessionIDs
            tab.activeSessionID = remaining.first ?? UUID()
            activeSessionID = tab.activeSessionID
            objectWillChange.send()
        }
    }

    // MARK: - Navigation

    /// 다음 분할창으로 포커스 이동 (Tab)
    func focusNextPanel() {
        guard let tab = activeTab, let sessionID = activeSessionID else { return }
        let sessions = tab.rootNode.allSessionIDs
        guard let currentIndex = sessions.firstIndex(of: sessionID) else { return }
        let nextIndex = (currentIndex + 1) % sessions.count
        tab.activeSessionID = sessions[nextIndex]
        activeSessionID = sessions[nextIndex]
        focusActiveSession()
        objectWillChange.send()
    }

    /// 이전 분할창으로 포커스 이동 (Shift+Tab)
    func focusPreviousPanel() {
        guard let tab = activeTab, let sessionID = activeSessionID else { return }
        let sessions = tab.rootNode.allSessionIDs
        guard let currentIndex = sessions.firstIndex(of: sessionID) else { return }
        let prevIndex = (currentIndex - 1 + sessions.count) % sessions.count
        tab.activeSessionID = sessions[prevIndex]
        activeSessionID = sessions[prevIndex]
        focusActiveSession()
        objectWillChange.send()
    }

    /// 패널 번호(1~8)로 직접 포커스
    func focusPanel(number: Int) {
        guard let tab = activeTab else { return }
        let sessions = tab.rootNode.allSessionIDs
        let index = number - 1
        guard index >= 0, index < sessions.count else {
            NSSound.beep()
            return
        }
        tab.activeSessionID = sessions[index]
        activeSessionID = sessions[index]
        focusActiveSession()
        objectWillChange.send()
    }

    /// 2D 그리드 네비게이션 (2행 x 4열 기준)
    func navigatePanel(direction: NavigationDirection) {
        guard let tab = activeTab, let sessionID = activeSessionID else { return }
        let sessions = tab.rootNode.allSessionIDs
        guard let currentIndex = sessions.firstIndex(of: sessionID) else { return }

        let cols = min(4, sessions.count)
        let rows = (sessions.count + cols - 1) / cols
        let row = currentIndex / cols
        let col = currentIndex % cols

        var newRow = row
        var newCol = col

        switch direction {
        case .left:  newCol = (col - 1 + cols) % cols
        case .right: newCol = (col + 1) % cols
        case .up:    newRow = (row - 1 + rows) % rows
        case .down:  newRow = (row + 1) % rows
        }

        let newIndex = newRow * cols + newCol
        guard newIndex >= 0, newIndex < sessions.count else { return }

        tab.activeSessionID = sessions[newIndex]
        activeSessionID = sessions[newIndex]
        focusActiveSession()
        objectWillChange.send()
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

    // MARK: - Panel Names

    func panelName(for sessionID: UUID) -> String {
        panelNames[sessionID] ?? ""
    }

    func setPanelName(_ name: String, for sessionID: UUID) {
        panelNames[sessionID] = name.isEmpty ? nil : name
    }

    // MARK: - Broadcast

    /// 현재 탭의 모든 패널에 명령어 일괄 실행
    func broadcastToActiveTab(_ command: String) {
        guard let tab = activeTab else { return }
        let sessionIDs = tab.rootNode.allSessionIDs
        sessionManager.sendCommandToSessions(command, sessionIDs: sessionIDs)

        // Start monitoring for completion
        outputMonitor.startMonitoring(sessionIDs: sessionIDs)
        monitorStateVersion += 1
    }

    /// 모든 패널에 claude --dangerously-skip-permissions 실행
    func launchClaudeAllPanels() {
        guard let tab = activeTab else { return }
        let sessionIDs = tab.rootNode.allSessionIDs
        sessionManager.sendCommandToSessions("claude --dangerously-skip-permissions", sessionIDs: sessionIDs)

        // Start monitoring for completion
        outputMonitor.startMonitoring(sessionIDs: sessionIDs)
        monitorStateVersion += 1
    }

    // MARK: - Quick Commands

    func runQuickCommand(_ cmd: QuickCommand) {
        guard let tab = activeTab else { return }
        let allSessions = tab.rootNode.allSessionIDs

        if cmd.targetPanels.isEmpty {
            // 전체 패널
            sessionManager.sendCommandToSessions(cmd.command, sessionIDs: allSessions)
        } else {
            // 지정된 패널만
            let targetIDs = cmd.targetPanels.compactMap { num -> UUID? in
                let idx = num - 1
                guard idx >= 0, idx < allSessions.count else { return nil }
                return allSessions[idx]
            }
            sessionManager.sendCommandToSessions(cmd.command, sessionIDs: targetIDs)
        }
    }

    func addQuickCommand(_ cmd: QuickCommand) {
        quickCommands.append(cmd)
        saveQuickCommands()
    }

    func updateQuickCommand(_ cmd: QuickCommand) {
        if let index = quickCommands.firstIndex(where: { $0.id == cmd.id }) {
            quickCommands[index] = cmd
            saveQuickCommands()
        }
    }

    func removeQuickCommand(_ cmd: QuickCommand) {
        quickCommands.removeAll { $0.id == cmd.id }
        saveQuickCommands()
    }

    func moveQuickCommand(from source: IndexSet, to destination: Int) {
        quickCommands.move(fromOffsets: source, toOffset: destination)
        saveQuickCommands()
    }

    private func loadQuickCommands() {
        if let data = UserDefaults.standard.data(forKey: quickCommandsKey),
           let saved = try? JSONDecoder().decode([QuickCommand].self, from: data) {
            quickCommands = saved
        } else {
            quickCommands = QuickCommand.defaults
            saveQuickCommands()
        }
    }

    private func saveQuickCommands() {
        if let data = try? JSONEncoder().encode(quickCommands) {
            UserDefaults.standard.set(data, forKey: quickCommandsKey)
        }
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
