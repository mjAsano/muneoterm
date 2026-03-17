import Foundation

final class TabModel: Identifiable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var rootNode: SplitNode
    @Published var activeSessionID: UUID

    init(sessionID: UUID, title: String = "Terminal") {
        self.id = UUID()
        self.title = title
        self.rootNode = .leaf(id: UUID(), sessionID: sessionID)
        self.activeSessionID = sessionID
    }
}

// MARK: - Codable

extension TabModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, rootNode
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rootNode = try container.decode(SplitNode.self, forKey: .rootNode)
        let title = try container.decode(String.self, forKey: .title)
        let firstSession = rootNode.allSessionIDs.first ?? UUID()
        self.init(sessionID: firstSession, title: title)
        self.rootNode = rootNode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(rootNode, forKey: .rootNode)
    }
}
