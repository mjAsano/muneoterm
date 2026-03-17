import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(appState.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(
                            title: tab.title,
                            isActive: index == appState.activeTabIndex,
                            onSelect: { appState.selectTab(at: index) },
                            onClose: { appState.closeTab(at: index) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // 브로드캐스트 입력 토글 버튼
            Button(action: { appState.showBroadcastInput.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .bold))
                    Text("입력")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(appState.showBroadcastInput ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(appState.showBroadcastInput
                              ? Color.accentColor.opacity(0.85)
                              : Color.gray.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .help("브로드캐스트 입력창 토글 (⌘⇧B)")

            // Claude 일괄실행 버튼
            Button(action: { appState.launchClaudeAllPanels() }) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Claude 8x")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.85))
                )
            }
            .buttonStyle(.plain)
            .help("모든 패널에서 claude --dangerously-skip-permissions 실행")

            Button(action: { appState.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }
}

struct TabItemView: View {
    let title: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)

            if isHovered || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive
                    ? Color(nsColor: .controlAccentColor).opacity(0.15)
                    : (isHovered ? Color.white.opacity(0.05) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}
