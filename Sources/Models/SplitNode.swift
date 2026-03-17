import Foundation

enum SplitDirection: String, Codable {
    case horizontal // left | right
    case vertical   // top / bottom
}

indirect enum SplitNode: Identifiable {
    case leaf(id: UUID, sessionID: UUID)
    case split(id: UUID, direction: SplitDirection, ratio: CGFloat, first: SplitNode, second: SplitNode)

    var id: UUID {
        switch self {
        case .leaf(let id, _): return id
        case .split(let id, _, _, _, _): return id
        }
    }

    // MARK: - Operations

    /// Replace the leaf with given sessionID by splitting it
    func splitLeaf(sessionID: UUID, direction: SplitDirection, newSessionID: UUID) -> SplitNode {
        switch self {
        case .leaf(let id, let sid):
            if sid == sessionID {
                return .split(
                    id: UUID(),
                    direction: direction,
                    ratio: 0.5,
                    first: .leaf(id: id, sessionID: sid),
                    second: .leaf(id: UUID(), sessionID: newSessionID)
                )
            }
            return self

        case .split(let id, let dir, let ratio, let first, let second):
            return .split(
                id: id,
                direction: dir,
                ratio: ratio,
                first: first.splitLeaf(sessionID: sessionID, direction: direction, newSessionID: newSessionID),
                second: second.splitLeaf(sessionID: sessionID, direction: direction, newSessionID: newSessionID)
            )
        }
    }

    /// Remove the leaf with given sessionID, promoting its sibling
    func removeLeaf(sessionID: UUID) -> SplitNode? {
        switch self {
        case .leaf(_, let sid):
            return sid == sessionID ? nil : self

        case .split(_, _, _, let first, let second):
            let firstRemoved = first.removeLeaf(sessionID: sessionID)
            let secondRemoved = second.removeLeaf(sessionID: sessionID)

            if firstRemoved == nil { return secondRemoved ?? second }
            if secondRemoved == nil { return firstRemoved ?? first }

            // Neither child was removed — recurse normally
            if let f = firstRemoved, let s = secondRemoved {
                return .split(id: id, direction: direction, ratio: ratio, first: f, second: s)
            }
            return firstRemoved ?? secondRemoved
        }
    }

    /// Update ratio for a specific split node
    func updateRatio(nodeID: UUID, newRatio: CGFloat) -> SplitNode {
        switch self {
        case .leaf:
            return self

        case .split(let id, let dir, let ratio, let first, let second):
            let r = id == nodeID ? newRatio : ratio
            return .split(
                id: id,
                direction: dir,
                ratio: r,
                first: first.updateRatio(nodeID: nodeID, newRatio: newRatio),
                second: second.updateRatio(nodeID: nodeID, newRatio: newRatio)
            )
        }
    }

    /// Get the direction for a split node
    var direction: SplitDirection {
        switch self {
        case .leaf: return .horizontal
        case .split(_, let dir, _, _, _): return dir
        }
    }

    /// Get the ratio for a split node
    var ratio: CGFloat {
        switch self {
        case .leaf: return 1.0
        case .split(_, _, let r, _, _): return r
        }
    }

    /// Collect all session IDs in the tree
    var allSessionIDs: [UUID] {
        switch self {
        case .leaf(_, let sessionID):
            return [sessionID]
        case .split(_, _, _, let first, let second):
            return first.allSessionIDs + second.allSessionIDs
        }
    }

    /// Find the next session ID in a given direction from the current active session
    func navigateFrom(sessionID: UUID, direction navDirection: NavigationDirection) -> UUID? {
        let leaves = collectLeavesWithFrames()
        guard let currentIndex = leaves.firstIndex(where: { $0.sessionID == sessionID }) else {
            return nil
        }

        switch navDirection {
        case .left, .up:
            return currentIndex > 0 ? leaves[currentIndex - 1].sessionID : nil
        case .right, .down:
            return currentIndex < leaves.count - 1 ? leaves[currentIndex + 1].sessionID : nil
        }
    }

    /// Simple ordered leaf collection for navigation
    private func collectLeavesWithFrames() -> [(sessionID: UUID, index: Int)] {
        var result: [(sessionID: UUID, index: Int)] = []
        collectLeaves(into: &result)
        return result
    }

    private func collectLeaves(into result: inout [(sessionID: UUID, index: Int)]) {
        switch self {
        case .leaf(_, let sessionID):
            result.append((sessionID: sessionID, index: result.count))
        case .split(_, _, _, let first, let second):
            first.collectLeaves(into: &result)
            second.collectLeaves(into: &result)
        }
    }
}

enum NavigationDirection {
    case left, right, up, down
}

// MARK: - Codable

extension SplitNode: Codable {
    enum CodingKeys: String, CodingKey {
        case type, id, sessionID, direction, ratio, first, second
    }

    enum NodeType: String, Codable {
        case leaf, split
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(NodeType.self, forKey: .type)

        switch type {
        case .leaf:
            let id = try container.decode(UUID.self, forKey: .id)
            let sessionID = try container.decode(UUID.self, forKey: .sessionID)
            self = .leaf(id: id, sessionID: sessionID)

        case .split:
            let id = try container.decode(UUID.self, forKey: .id)
            let direction = try container.decode(SplitDirection.self, forKey: .direction)
            let ratio = try container.decode(CGFloat.self, forKey: .ratio)
            let first = try container.decode(SplitNode.self, forKey: .first)
            let second = try container.decode(SplitNode.self, forKey: .second)
            self = .split(id: id, direction: direction, ratio: ratio, first: first, second: second)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .leaf(let id, let sessionID):
            try container.encode(NodeType.leaf, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(sessionID, forKey: .sessionID)

        case .split(let id, let direction, let ratio, let first, let second):
            try container.encode(NodeType.split, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(direction, forKey: .direction)
            try container.encode(ratio, forKey: .ratio)
            try container.encode(first, forKey: .first)
            try container.encode(second, forKey: .second)
        }
    }
}
