import AppKit

class SplitPairView: NSView {
    let direction: SplitDirection
    private(set) var ratio: CGFloat
    var onRatioChanged: ((CGFloat) -> Void)?

    private let firstView: NSView
    private let secondView: NSView
    private let dividerView: DividerView

    private static let dividerThickness: CGFloat = 1
    private static let dividerHitArea: CGFloat = 8
    private static let minPanelSize: CGFloat = 80

    init(direction: SplitDirection, ratio: CGFloat, firstView: NSView, secondView: NSView) {
        self.direction = direction
        self.ratio = ratio
        self.firstView = firstView
        self.secondView = secondView
        self.dividerView = DividerView(direction: direction)

        super.init(frame: .zero)

        wantsLayer = true
        addSubview(firstView)
        addSubview(dividerView)
        addSubview(secondView)

        dividerView.onDrag = { [weak self] delta in
            self?.handleDividerDrag(delta: delta)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutSubviewsForSplit()
    }

    private func layoutSubviewsForSplit() {
        let size = bounds.size
        let dividerThickness = Self.dividerThickness

        switch direction {
        case .horizontal:
            let firstWidth = (size.width - dividerThickness) * ratio
            let secondWidth = size.width - firstWidth - dividerThickness

            firstView.frame = NSRect(x: 0, y: 0, width: firstWidth, height: size.height)
            dividerView.frame = NSRect(x: firstWidth, y: 0, width: dividerThickness, height: size.height)
            secondView.frame = NSRect(x: firstWidth + dividerThickness, y: 0, width: secondWidth, height: size.height)

        case .vertical:
            let firstHeight = (size.height - dividerThickness) * ratio
            let secondHeight = size.height - firstHeight - dividerThickness

            // First view is on top (higher y in flipped coords)
            secondView.frame = NSRect(x: 0, y: 0, width: size.width, height: secondHeight)
            dividerView.frame = NSRect(x: 0, y: secondHeight, width: size.width, height: dividerThickness)
            firstView.frame = NSRect(x: 0, y: secondHeight + dividerThickness, width: size.width, height: firstHeight)
        }
    }

    private func handleDividerDrag(delta: CGFloat) {
        let size = bounds.size
        let totalSize: CGFloat
        let dividerThickness = Self.dividerThickness

        switch direction {
        case .horizontal:
            totalSize = size.width - dividerThickness
        case .vertical:
            totalSize = size.height - dividerThickness
        }

        guard totalSize > 0 else { return }

        let newRatio = (ratio * totalSize + delta) / totalSize
        let minRatio = Self.minPanelSize / totalSize
        let maxRatio = 1.0 - minRatio

        ratio = min(max(newRatio, minRatio), maxRatio)
        layoutSubviewsForSplit()
        onRatioChanged?(ratio)
    }
}

// MARK: - Divider View

class DividerView: NSView {
    let direction: SplitDirection
    var onDrag: ((CGFloat) -> Void)?

    private var isDragging = false
    private var lastDragPoint: NSPoint = .zero

    private static let hitAreaPadding: CGFloat = 4

    init(direction: SplitDirection) {
        self.direction = direction
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        let expandedRect: NSRect
        switch direction {
        case .horizontal:
            expandedRect = bounds.insetBy(dx: -Self.hitAreaPadding, dy: 0)
            addCursorRect(expandedRect, cursor: .resizeLeftRight)
        case .vertical:
            expandedRect = bounds.insetBy(dx: 0, dy: -Self.hitAreaPadding)
            addCursorRect(expandedRect, cursor: .resizeUpDown)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        let expandedBounds: NSRect
        switch direction {
        case .horizontal:
            expandedBounds = bounds.insetBy(dx: -Self.hitAreaPadding, dy: 0)
        case .vertical:
            expandedBounds = bounds.insetBy(dx: 0, dy: -Self.hitAreaPadding)
        }
        return expandedBounds.contains(localPoint) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        lastDragPoint = convert(event.locationInWindow, from: nil)

        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let currentPoint = convert(event.locationInWindow, from: nil)
        let delta: CGFloat

        switch direction {
        case .horizontal:
            delta = currentPoint.x - lastDragPoint.x
        case .vertical:
            delta = -(currentPoint.y - lastDragPoint.y)
        }

        lastDragPoint = currentPoint
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
    }

    override func mouseEntered(with event: NSEvent) {
        if !isDragging {
            layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }

        let expandedRect: NSRect
        switch direction {
        case .horizontal:
            expandedRect = bounds.insetBy(dx: -Self.hitAreaPadding, dy: 0)
        case .vertical:
            expandedRect = bounds.insetBy(dx: 0, dy: -Self.hitAreaPadding)
        }

        addTrackingArea(NSTrackingArea(
            rect: expandedRect,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        ))
    }
}
