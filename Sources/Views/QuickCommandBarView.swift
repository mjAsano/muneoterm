import SwiftUI

struct QuickCommandBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddSheet = false
    @State private var editingCommand: QuickCommand?

    private var usedShortcuts: Set<Int> {
        Set(appState.quickCommands.compactMap { $0.shortcutKey })
    }

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(appState.quickCommands) { cmd in
                        QuickCommandButton(command: cmd, usedShortcuts: usedShortcuts) {
                            appState.runQuickCommand(cmd)
                        }
                        .contextMenu {
                            Button("Edit...") { editingCommand = cmd }
                            Button("Duplicate") {
                                var dup = cmd
                                dup.id = UUID()
                                dup.name = cmd.name + " copy"
                                appState.addQuickCommand(dup)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                appState.removeQuickCommand(cmd)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
            }

            Divider()
                .frame(height: 18)

            Button(action: { showAddSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Add quick command")
            .padding(.trailing, 8)
        }
        .frame(height: 32)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        .sheet(isPresented: $showAddSheet) {
            QuickCommandEditView(mode: .add, usedShortcuts: usedShortcuts) { newCmd in
                appState.addQuickCommand(newCmd)
            }
        }
        .sheet(item: $editingCommand) { cmd in
            QuickCommandEditView(mode: .edit(cmd), usedShortcuts: usedShortcuts.subtracting(Set([cmd.shortcutKey].compactMap { $0 }))) { updated in
                appState.updateQuickCommand(updated)
            }
        }
    }
}

// MARK: - Command Button

struct QuickCommandButton: View {
    let command: QuickCommand
    var usedShortcuts: Set<Int> = []
    let action: () -> Void
    @State private var isHovered = false

    private var buttonColor: Color {
        Color(hex: command.colorHex) ?? .gray
    }

    var body: some View {
        let button = Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: command.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(command.name)
                    .font(.system(size: 10, weight: .medium))

                // 단축키 뱃지
                if let key = command.shortcutKey {
                    Text("⌘\(key)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(isHovered ? .white.opacity(0.7) : buttonColor.opacity(0.6))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isHovered ? Color.white.opacity(0.15) : buttonColor.opacity(0.1))
                        )
                }

                // 타겟 패널 뱃지
                Text(command.targetLabel)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovered ? .white.opacity(0.7) : buttonColor.opacity(0.6))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isHovered ? Color.white.opacity(0.15) : buttonColor.opacity(0.1))
                    )
            }
            .foregroundColor(isHovered ? .white : buttonColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? buttonColor.opacity(0.85) : buttonColor.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(buttonColor.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(shortcutHelpText)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }

        if let key = command.shortcutKey, let scalar = Unicode.Scalar("\(key)") {
            button.keyboardShortcut(KeyEquivalent(Character(scalar)), modifiers: .command)
        } else {
            button
        }
    }

    private var shortcutHelpText: String {
        var parts = ["\(command.command) → \(command.targetPanels.isEmpty ? "All panels" : "Panel \(command.targetLabel)")"]
        if let key = command.shortcutKey {
            parts.append("⌘\(key)")
        }
        return parts.joined(separator: "  ")
    }
}

// MARK: - Edit View

struct QuickCommandEditView: View {
    enum Mode: Identifiable {
        case add
        case edit(QuickCommand)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let cmd): return cmd.id.uuidString
            }
        }
    }

    let mode: Mode
    let onSave: (QuickCommand) -> Void
    var usedShortcuts: Set<Int> = []

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var command: String = ""
    @State private var icon: String = "terminal"
    @State private var selectedColorHex: String = "8E8E93"
    @State private var targetPanels: Set<Int> = []
    @State private var shortcutKey: Int? = nil

    private let colorOptions: [(name: String, hex: String)] = [
        ("Orange", "FF9500"),
        ("Red", "FF453A"),
        ("Green", "30D158"),
        ("Blue", "0A84FF"),
        ("Purple", "BF5AF2"),
        ("Cyan", "64D2FF"),
        ("Pink", "FF375F"),
        ("Yellow", "FFD60A"),
        ("Gray", "8E8E93"),
    ]

    private let iconOptions = [
        "terminal", "bolt.fill", "arrow.triangle.branch", "arrow.down.circle",
        "trash", "folder", "gear", "play.fill", "stop.fill", "hammer",
        "doc.text", "network", "server.rack", "cpu", "memorychip",
        "arrow.clockwise", "checkmark.circle", "xmark.circle",
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(mode.isAdd ? "New Quick Command" : "Edit Quick Command")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                LabeledField("Name") {
                    TextField("e.g. deploy", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledField("Command") {
                    TextField("e.g. git push origin main", text: $command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledField("Target Panels") {
                    VStack(alignment: .leading, spacing: 6) {
                        PanelGridPicker(selectedPanels: $targetPanels)

                        HStack(spacing: 8) {
                            Button("All") { targetPanels = [] }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: targetPanels.isEmpty ? .bold : .regular))
                                .foregroundColor(targetPanels.isEmpty ? .accentColor : .secondary)

                            Button("Top Row") { targetPanels = [1, 2, 3, 4] }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Button("Bottom Row") { targetPanels = [5, 6, 7, 8] }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Button("Left Half") { targetPanels = [1, 2, 5, 6] }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Button("Right Half") { targetPanels = [3, 4, 7, 8] }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                LabeledField("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(iconOptions, id: \.self) { ic in
                                Image(systemName: ic)
                                    .font(.system(size: 14))
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(icon == ic ? Color.accentColor.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(icon == ic ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                                    .onTapGesture { icon = ic }
                            }
                        }
                    }
                }

                LabeledField("Shortcut") {
                    HStack(spacing: 5) {
                        Button("None") {
                            shortcutKey = nil
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: shortcutKey == nil ? .bold : .regular))
                        .foregroundColor(shortcutKey == nil ? .accentColor : .secondary)

                        Divider().frame(height: 16)

                        ForEach(1...9, id: \.self) { n in
                            let isMine = shortcutKey == n
                            let isTaken = !isMine && usedShortcuts.contains(n)
                            Button("⌘\(n)") {
                                shortcutKey = isMine ? nil : n
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: isMine ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isMine ? .accentColor : (isTaken ? .secondary.opacity(0.4) : .secondary))
                            .help(isTaken ? "Already in use" : "")
                            .disabled(isTaken)
                        }
                    }
                }

                LabeledField("Color") {
                    HStack(spacing: 6) {
                        ForEach(colorOptions, id: \.hex) { opt in
                            Circle()
                                .fill(Color(hex: opt.hex) ?? .gray)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(selectedColorHex == opt.hex ? 0.8 : 0), lineWidth: 2)
                                )
                                .scaleEffect(selectedColorHex == opt.hex ? 1.15 : 1.0)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedColorHex = opt.hex
                                    }
                                }
                        }
                    }
                }
            }

            // Preview
            HStack {
                Text("Preview:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                QuickCommandButton(
                    command: QuickCommand(
                        name: name.isEmpty ? "Button" : name,
                        command: command,
                        icon: icon,
                        colorHex: selectedColorHex,
                        targetPanels: targetPanels
                    ),
                    action: {}
                )
                Spacer()
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(mode.isAdd ? "Add" : "Save") {
                    let cmd: QuickCommand
                    switch mode {
                    case .add:
                        cmd = QuickCommand(name: name, command: command, icon: icon, colorHex: selectedColorHex, targetPanels: targetPanels, shortcutKey: shortcutKey)
                    case .edit(let existing):
                        cmd = QuickCommand(id: existing.id, name: name, command: command, icon: icon, colorHex: selectedColorHex, targetPanels: targetPanels, shortcutKey: shortcutKey)
                    }
                    onSave(cmd)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            if case .edit(let cmd) = mode {
                name = cmd.name
                command = cmd.command
                icon = cmd.icon
                selectedColorHex = cmd.colorHex
                targetPanels = cmd.targetPanels
                shortcutKey = cmd.shortcutKey
            }
        }
    }
}

// MARK: - Panel Grid Picker (2x4)

struct PanelGridPicker: View {
    @Binding var selectedPanels: Set<Int>

    var body: some View {
        VStack(spacing: 3) {
            // Top row: 1 2 3 4
            HStack(spacing: 3) {
                ForEach(1...4, id: \.self) { num in
                    PanelCell(number: num, isSelected: selectedPanels.contains(num)) {
                        togglePanel(num)
                    }
                }
            }
            // Bottom row: 5 6 7 8
            HStack(spacing: 3) {
                ForEach(5...8, id: \.self) { num in
                    PanelCell(number: num, isSelected: selectedPanels.contains(num)) {
                        togglePanel(num)
                    }
                }
            }
        }
    }

    private func togglePanel(_ num: Int) {
        if selectedPanels.contains(num) {
            selectedPanels.remove(num)
        } else {
            selectedPanels.insert(num)
        }
    }
}

struct PanelCell: View {
    let number: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 44, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor : (isHovered ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Helpers

private struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            content
        }
    }
}

private extension QuickCommandEditView.Mode {
    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }
}

// MARK: - Color from Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6,
              let int = UInt64(hexSanitized, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
