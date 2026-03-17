import Foundation
import os.log

class ThemeManager {
    private let logger = Logger(subsystem: "com.hosun.terminal", category: "ThemeManager")
    private let fileManager = FileManager.default

    private var customThemesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let themesDir = appSupport
            .appendingPathComponent("HosunTerminal", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)

        if !fileManager.fileExists(atPath: themesDir.path) {
            try? fileManager.createDirectory(at: themesDir, withIntermediateDirectories: true)
        }

        return themesDir
    }

    // MARK: - Load All Themes

    func loadAllThemes() -> [Theme] {
        var themes = Theme.allBuiltIn

        let customThemes = loadCustomThemes()
        themes.append(contentsOf: customThemes)

        return themes
    }

    // MARK: - Custom Themes

    private func loadCustomThemes() -> [Theme] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: customThemesDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Theme? in
                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(Theme.self, from: data)
                } catch {
                    logger.error("Failed to load theme \(url.lastPathComponent): \(error.localizedDescription)")
                    return nil
                }
            }
    }

    func saveTheme(_ theme: Theme) throws {
        let url = customThemesDirectory.appendingPathComponent("\(theme.id).json")
        let data = try JSONEncoder().encode(theme)
        try data.write(to: url, options: .atomic)
        logger.info("Theme saved: \(theme.name)")
    }
}
