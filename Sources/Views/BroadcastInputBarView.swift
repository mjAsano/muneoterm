import SwiftUI

struct BroadcastInputBarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isVisible: Bool

    @State private var inputText: String = ""
    @State private var targetPanels: Set<Int> = []
    @State private var history: [String] = []
    @State private var historyIndex: Int = -1
    @FocusState private var isFocused: Bool

    private var panelCount: Int {
        appState.activeTab?.rootNode.allSessionIDs.count ?? 8
    }

    var body: some View {
        HStack(spacing: 8) {
            // 아이콘
            Image(systemName: "terminal.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 18)

            // 입력 필드
            TextField("명령어 입력 (Enter로 실행, ↑↓ 히스토리)", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($isFocused)
                .onSubmit { runCommand() }
                .onKeyPress(.upArrow) { navigateHistory(-1); return .handled }
                .onKeyPress(.downArrow) { navigateHistory(+1); return .handled }
                .onKeyPress(.escape) { dismiss(); return .handled }

            Divider().frame(height: 16)

            // 패널 선택
            HStack(spacing: 3) {
                // ALL 버튼
                Button(action: { targetPanels = [] }) {
                    Text("ALL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(targetPanels.isEmpty ? .white : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(targetPanels.isEmpty ? Color.accentColor : Color.gray.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)

                // 패널 개별 선택
                ForEach(1...panelCount, id: \.self) { num in
                    let selected = targetPanels.contains(num)
                    Button(action: { togglePanel(num) }) {
                        Text("\(num)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(selected ? .white : .secondary)
                            .frame(width: 18, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(selected ? Color.orange.opacity(0.85) : Color.gray.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 16)

            // 실행 버튼
            Button(action: runCommand) {
                HStack(spacing: 3) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("실행")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(inputText.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)

            // 닫기 버튼
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("닫기 (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.accentColor.opacity(0.4)),
            alignment: .top
        )
        .onChange(of: isVisible) { visible in
            if visible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isFocused = true
                }
            }
        }
    }

    // MARK: - Actions

    private func runCommand() {
        let cmd = inputText.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        // 히스토리에 추가 (중복 제거)
        history.removeAll { $0 == cmd }
        history.insert(cmd, at: 0)
        if history.count > 50 { history.removeLast() }
        historyIndex = -1

        // 실행
        if targetPanels.isEmpty {
            appState.broadcastToActiveTab(cmd)
        } else {
            guard let tab = appState.activeTab else { return }
            let allSessions = tab.rootNode.allSessionIDs
            let targetIDs = targetPanels.sorted().compactMap { num -> UUID? in
                let idx = num - 1
                guard idx >= 0, idx < allSessions.count else { return nil }
                return allSessions[idx]
            }
            appState.sessionManager.sendCommandToSessions(cmd, sessionIDs: targetIDs)
        }

        inputText = ""
    }

    private func navigateHistory(_ delta: Int) {
        guard !history.isEmpty else { return }
        let newIndex = historyIndex + delta
        if newIndex < -1 {
            return
        } else if newIndex >= history.count {
            return
        }
        historyIndex = newIndex
        inputText = newIndex == -1 ? "" : history[newIndex]
    }

    private func togglePanel(_ num: Int) {
        if targetPanels.contains(num) {
            targetPanels.remove(num)
        } else {
            targetPanels.insert(num)
        }
    }

    private func dismiss() {
        isVisible = false
        isFocused = false
    }
}
