import AppKit
import SwiftTerm

protocol SplitContainerDelegate: AnyObject {
    func splitContainerDidChangeRatio(_ nodeID: UUID, ratio: CGFloat)
    func splitContainerDidActivateSession(_ sessionID: UUID)
    func splitContainerDidRenamePanel(_ sessionID: UUID, name: String)
}

class SplitContainerNSView: NSView {
    weak var delegate: SplitContainerDelegate?

    private let sessionManager: TerminalSessionManager
    private var currentNode: SplitNode?
    private var activeSessionID: UUID?
    private var panelWrappers: [UUID: TerminalPanelWrapper] = [:]

    init(sessionManager: TerminalSessionManager) {
        self.sessionManager = sessionManager
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(node: SplitNode, activeSessionID: UUID?, panelNames: [UUID: String]) {
        self.currentNode = node
        self.activeSessionID = activeSessionID
        rebuildHierarchy()
        // Update names without full rebuild
        for (sessionID, wrapper) in panelWrappers {
            wrapper.setPanelName(panelNames[sessionID] ?? "")
        }
    }

    // MARK: - Rebuild

    private func rebuildHierarchy() {
        subviews.forEach { $0.removeFromSuperview() }

        guard let node = currentNode else { return }

        let view = buildView(for: node)
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        updateActiveBorders()
    }

    private func buildView(for node: SplitNode) -> NSView {
        switch node {
        case .leaf(_, let sessionID):
            return panelWrapper(for: sessionID)

        case .split(let nodeID, let direction, let ratio, let first, let second):
            let firstView = buildView(for: first)
            let secondView = buildView(for: second)
            let pairView = SplitPairView(
                direction: direction,
                ratio: ratio,
                firstView: firstView,
                secondView: secondView
            )
            pairView.onRatioChanged = { [weak self] newRatio in
                self?.delegate?.splitContainerDidChangeRatio(nodeID, ratio: newRatio)
            }
            return pairView
        }
    }

    private func panelWrapper(for sessionID: UUID) -> TerminalPanelWrapper {
        if let existing = panelWrappers[sessionID] {
            return existing
        }

        let wrapper = TerminalPanelWrapper(sessionID: sessionID)
        wrapper.onActivate = { [weak self] sid in
            self?.delegate?.splitContainerDidActivateSession(sid)
        }
        wrapper.onRename = { [weak self] sid, name in
            self?.delegate?.splitContainerDidRenamePanel(sid, name: name)
        }

        if let terminalView = sessionManager.terminalView(for: sessionID) {
            terminalView.removeFromSuperview()
            wrapper.setTerminalView(terminalView)
        }

        panelWrappers[sessionID] = wrapper
        return wrapper
    }

    // MARK: - Active Border

    func updateActiveBorders() {
        for (sessionID, wrapper) in panelWrappers {
            wrapper.setActive(sessionID == activeSessionID)
        }
    }

    // MARK: - Panel States

    func updatePanelStates(from monitor: OutputMonitor) {
        for (sessionID, wrapper) in panelWrappers {
            let state = monitor.state(for: sessionID)
            wrapper.setPanelState(state)
        }
    }

    // MARK: - Cleanup

    func removePanelWrapper(for sessionID: UUID) {
        panelWrappers.removeValue(forKey: sessionID)
    }
}

// MARK: - Terminal Panel Wrapper

class TerminalPanelWrapper: NSView {
    let sessionID: UUID
    var onActivate: ((UUID) -> Void)?
    var onRename: ((UUID, String) -> Void)?
    private var borderLayer: CALayer?
    private var isActivePanel = false
    private var panelState: PanelState = .idle

    private let titleBar = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let titleField = NSTextField()
    private var terminalTopConstraint: NSLayoutConstraint?

    static let titleBarHeight: CGFloat = 20

    init(sessionID: UUID) {
        self.sessionID = sessionID
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 2

        setupBorder()
        setupTitleBar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTerminalView(_ view: NSView) {
        view.removeFromSuperview()
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        let topConstraint = view.topAnchor.constraint(equalTo: titleBar.bottomAnchor, constant: 0)
        terminalTopConstraint = topConstraint
        NSLayoutConstraint.activate([
            topConstraint,
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
        ])
    }

    func setPanelName(_ name: String) {
        titleLabel.stringValue = name
        titleLabel.isHidden = !titleField.isHidden || name.isEmpty
    }

    private func setupTitleBar() {
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        addSubview(titleBar)
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            titleBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            titleBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            titleBar.heightAnchor.constraint(equalToConstant: TerminalPanelWrapper.titleBarHeight),
        ])

        // Label (read mode)
        titleLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.isHidden = true
        titleBar.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -6),
        ])

        // Text field (edit mode)
        titleField.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        titleField.textColor = NSColor.white
        titleField.isBordered = false
        titleField.backgroundColor = NSColor.white.withAlphaComponent(0.1)
        titleField.isHidden = true
        titleField.delegate = self
        titleField.focusRingType = .none
        titleBar.addSubview(titleField)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleField.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 4),
            titleField.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -4),
        ])

        // Double-click gesture
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(titleBarDoubleClicked))
        doubleClick.numberOfClicksRequired = 2
        titleBar.addGestureRecognizer(doubleClick)
    }

    @objc private func titleBarDoubleClicked() {
        titleField.stringValue = titleLabel.stringValue
        titleLabel.isHidden = true
        titleField.isHidden = false
        titleBar.window?.makeFirstResponder(titleField)
    }

    private func commitRename() {
        let newName = titleField.stringValue.trimmingCharacters(in: .whitespaces)
        titleField.isHidden = true
        titleLabel.stringValue = newName
        titleLabel.isHidden = newName.isEmpty
        onRename?(sessionID, newName)
    }

    func setActive(_ active: Bool) {
        isActivePanel = active
        updateBorderAppearance()
    }

    func setPanelState(_ state: PanelState) {
        let oldState = panelState
        panelState = state
        updateBorderAppearance()

        // Pulse animation on completion
        if oldState == .generating && (state == .completed || state == .error) {
            animateCompletionPulse(color: state.borderColor)
        }
    }

    private func updateBorderAppearance() {
        if panelState != .idle {
            // State-based border takes priority
            borderLayer?.borderColor = panelState.borderColor.cgColor
            borderLayer?.borderWidth = panelState.borderWidth
        } else if isActivePanel {
            borderLayer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
            borderLayer?.borderWidth = 2
        } else {
            borderLayer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
            borderLayer?.borderWidth = 1
        }
    }

    private func animateCompletionPulse(color: NSColor) {
        guard let border = borderLayer else { return }

        let pulseAnimation = CABasicAnimation(keyPath: "borderWidth")
        pulseAnimation.fromValue = 4.0
        pulseAnimation.toValue = panelState.borderWidth
        pulseAnimation.duration = 0.5
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let colorAnimation = CABasicAnimation(keyPath: "borderColor")
        colorAnimation.fromValue = color.withAlphaComponent(1.0).cgColor
        colorAnimation.toValue = color.cgColor
        colorAnimation.duration = 0.5
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        border.add(pulseAnimation, forKey: "pulseWidth")
        border.add(colorAnimation, forKey: "pulseColor")
    }

    override func mouseDown(with event: NSEvent) {
        onActivate?(sessionID)
        super.mouseDown(with: event)
    }

    private func setupBorder() {
        let border = CALayer()
        border.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        border.borderWidth = 1
        border.cornerRadius = 2
        layer?.addSublayer(border)
        borderLayer = border
    }

    override func layout() {
        super.layout()
        borderLayer?.frame = bounds
    }
}

// MARK: - NSTextFieldDelegate

extension TerminalPanelWrapper: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitRename()
            window?.makeFirstResponder(nil)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            titleField.isHidden = true
            titleLabel.isHidden = titleLabel.stringValue.isEmpty
            window?.makeFirstResponder(nil)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if !titleField.isHidden {
            commitRename()
        }
    }
}
