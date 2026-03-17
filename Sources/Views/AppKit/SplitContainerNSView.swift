import AppKit
import SwiftTerm

protocol SplitContainerDelegate: AnyObject {
    func splitContainerDidChangeRatio(_ nodeID: UUID, ratio: CGFloat)
    func splitContainerDidActivateSession(_ sessionID: UUID)
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

    func update(node: SplitNode, activeSessionID: UUID?) {
        self.currentNode = node
        self.activeSessionID = activeSessionID
        rebuildHierarchy()
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

    // MARK: - Cleanup

    func removePanelWrapper(for sessionID: UUID) {
        panelWrappers.removeValue(forKey: sessionID)
    }
}

// MARK: - Terminal Panel Wrapper

class TerminalPanelWrapper: NSView {
    let sessionID: UUID
    var onActivate: ((UUID) -> Void)?
    private var borderLayer: CALayer?
    private var isActivePanel = false

    init(sessionID: UUID) {
        self.sessionID = sessionID
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 2

        setupBorder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTerminalView(_ view: NSView) {
        view.removeFromSuperview()
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
        ])
    }

    func setActive(_ active: Bool) {
        isActivePanel = active
        borderLayer?.borderColor = active
            ? NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
            : NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        borderLayer?.borderWidth = active ? 2 : 1
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
