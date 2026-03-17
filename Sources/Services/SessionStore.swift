import Foundation
import os.log

class SessionStore {
    private let logger = Logger(subsystem: "com.hosun.terminal", category: "SessionStore")
    private let fileManager = FileManager.default

    private var sessionFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("HosunTerminal", isDirectory: true)

        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir.appendingPathComponent("session.json")
    }

    // MARK: - Save

    func save(tabs: [TabModel]) {
        do {
            let data = try JSONEncoder().encode(tabs)
            try data.write(to: sessionFileURL, options: .atomic)
            logger.info("Session saved: \(tabs.count) tabs")
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
        }
    }

    // MARK: - Load

    func load() -> [TabModel]? {
        guard fileManager.fileExists(atPath: sessionFileURL.path) else {
            logger.info("No saved session found")
            return nil
        }

        do {
            let data = try Data(contentsOf: sessionFileURL)
            let tabs = try JSONDecoder().decode([TabModel].self, from: data)
            logger.info("Session restored: \(tabs.count) tabs")
            return tabs
        } catch {
            logger.error("Failed to load session: \(error.localizedDescription)")
            // Remove corrupted file
            try? fileManager.removeItem(at: sessionFileURL)
            return nil
        }
    }

    // MARK: - Clear

    func clear() {
        try? fileManager.removeItem(at: sessionFileURL)
        logger.info("Session cleared")
    }
}
