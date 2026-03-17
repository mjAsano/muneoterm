import Foundation

struct QuickCommand: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var command: String
    var icon: String
    var colorHex: String
    /// 대상 패널 번호 (1~8). 비어있으면 전체 패널에 실행
    var targetPanels: Set<Int>
    /// Cmd+N 단축키 (1~9, nil = 없음)
    var shortcutKey: Int?

    init(id: UUID = UUID(), name: String, command: String, icon: String = "terminal", colorHex: String = "8E8E93", targetPanels: Set<Int> = [], shortcutKey: Int? = nil) {
        self.id = id
        self.name = name
        self.command = command
        self.icon = icon
        self.colorHex = colorHex
        self.targetPanels = targetPanels
        self.shortcutKey = shortcutKey
    }

    /// 타겟 패널 요약 텍스트
    var targetLabel: String {
        if targetPanels.isEmpty { return "ALL" }
        return targetPanels.sorted().map { "\($0)" }.joined(separator: ",")
    }

    static let defaults: [QuickCommand] = [
        QuickCommand(name: "Claude 8x", command: "claude --dangerously-skip-permissions", icon: "bolt.fill", colorHex: "FF9500"),
        QuickCommand(name: "git status", command: "git status", icon: "arrow.triangle.branch", colorHex: "30D158"),
        QuickCommand(name: "git pull", command: "git pull", icon: "arrow.down.circle", colorHex: "64D2FF"),
        QuickCommand(name: "clear", command: "clear", icon: "trash", colorHex: "FF453A"),
        QuickCommand(name: "ls", command: "ls -la", icon: "folder", colorHex: "BF5AF2"),
    ]
}
