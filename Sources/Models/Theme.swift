import AppKit

struct Theme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let backgroundColor: CodableColor
    let foregroundColor: CodableColor
    let cursorColor: CodableColor
    let selectionColor: CodableColor
    let ansiColors: AnsiColors
    let fontName: String
    let fontSize: CGFloat
    let backgroundOpacity: CGFloat

    var nsBackgroundColor: NSColor { backgroundColor.nsColor.withAlphaComponent(backgroundOpacity) }
    var nsForegroundColor: NSColor { foregroundColor.nsColor }
    var nsCursorColor: NSColor { cursorColor.nsColor }
    var nsSelectionColor: NSColor { selectionColor.nsColor }
    var nsFont: NSFont {
        NSFont(name: fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}

struct AnsiColors: Codable, Equatable {
    let black, red, green, yellow, blue, magenta, cyan, white: CodableColor
    let brightBlack, brightRed, brightGreen, brightYellow: CodableColor
    let brightBlue, brightMagenta, brightCyan, brightWhite: CodableColor
}

struct CodableColor: Codable, Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.red = c.redComponent
        self.green = c.greenComponent
        self.blue = c.blueComponent
    }
}

// MARK: - Built-in Themes

extension Theme {
    static let defaultDark = Theme(
        id: "default-dark",
        name: "Default Dark",
        backgroundColor: CodableColor(red: 0.11, green: 0.11, blue: 0.13),
        foregroundColor: CodableColor(red: 0.90, green: 0.90, blue: 0.92),
        cursorColor: CodableColor(red: 0.90, green: 0.90, blue: 0.92),
        selectionColor: CodableColor(red: 0.30, green: 0.35, blue: 0.50),
        ansiColors: .defaultDark,
        fontName: "MesloLGS-NF-Regular",
        fontSize: 14,
        backgroundOpacity: 1.0
    )

    static let ocean = Theme(
        id: "ocean",
        name: "Ocean",
        backgroundColor: CodableColor(red: 0.05, green: 0.10, blue: 0.18),
        foregroundColor: CodableColor(red: 0.78, green: 0.85, blue: 0.90),
        cursorColor: CodableColor(red: 0.40, green: 0.70, blue: 0.90),
        selectionColor: CodableColor(red: 0.15, green: 0.30, blue: 0.45),
        ansiColors: .defaultDark,
        fontName: "MesloLGS-NF-Regular",
        fontSize: 14,
        backgroundOpacity: 0.95
    )

    static let monokai = Theme(
        id: "monokai",
        name: "Monokai",
        backgroundColor: CodableColor(red: 0.16, green: 0.16, blue: 0.14),
        foregroundColor: CodableColor(red: 0.97, green: 0.97, blue: 0.95),
        cursorColor: CodableColor(red: 0.97, green: 0.97, blue: 0.95),
        selectionColor: CodableColor(red: 0.29, green: 0.29, blue: 0.27),
        ansiColors: .monokai,
        fontName: "MesloLGS-NF-Regular",
        fontSize: 14,
        backgroundOpacity: 1.0
    )

    static let allBuiltIn: [Theme] = [.defaultDark, .ocean, .monokai]
}

extension AnsiColors {
    static let defaultDark = AnsiColors(
        black: CodableColor(red: 0.10, green: 0.10, blue: 0.12),
        red: CodableColor(red: 0.90, green: 0.30, blue: 0.30),
        green: CodableColor(red: 0.30, green: 0.85, blue: 0.40),
        yellow: CodableColor(red: 0.95, green: 0.80, blue: 0.30),
        blue: CodableColor(red: 0.35, green: 0.55, blue: 0.95),
        magenta: CodableColor(red: 0.80, green: 0.40, blue: 0.90),
        cyan: CodableColor(red: 0.30, green: 0.85, blue: 0.85),
        white: CodableColor(red: 0.85, green: 0.85, blue: 0.87),
        brightBlack: CodableColor(red: 0.45, green: 0.45, blue: 0.50),
        brightRed: CodableColor(red: 1.00, green: 0.40, blue: 0.40),
        brightGreen: CodableColor(red: 0.40, green: 0.95, blue: 0.50),
        brightYellow: CodableColor(red: 1.00, green: 0.90, blue: 0.40),
        brightBlue: CodableColor(red: 0.50, green: 0.70, blue: 1.00),
        brightMagenta: CodableColor(red: 0.90, green: 0.50, blue: 1.00),
        brightCyan: CodableColor(red: 0.40, green: 0.95, blue: 0.95),
        brightWhite: CodableColor(red: 1.00, green: 1.00, blue: 1.00)
    )

    static let monokai = AnsiColors(
        black: CodableColor(red: 0.16, green: 0.16, blue: 0.14),
        red: CodableColor(red: 0.98, green: 0.15, blue: 0.45),
        green: CodableColor(red: 0.65, green: 0.89, blue: 0.18),
        yellow: CodableColor(red: 0.90, green: 0.86, blue: 0.45),
        blue: CodableColor(red: 0.40, green: 0.85, blue: 0.94),
        magenta: CodableColor(red: 0.68, green: 0.51, blue: 1.00),
        cyan: CodableColor(red: 0.65, green: 0.89, blue: 0.18),
        white: CodableColor(red: 0.97, green: 0.97, blue: 0.95),
        brightBlack: CodableColor(red: 0.45, green: 0.45, blue: 0.41),
        brightRed: CodableColor(red: 0.98, green: 0.15, blue: 0.45),
        brightGreen: CodableColor(red: 0.65, green: 0.89, blue: 0.18),
        brightYellow: CodableColor(red: 0.90, green: 0.86, blue: 0.45),
        brightBlue: CodableColor(red: 0.40, green: 0.85, blue: 0.94),
        brightMagenta: CodableColor(red: 0.68, green: 0.51, blue: 1.00),
        brightCyan: CodableColor(red: 0.65, green: 0.89, blue: 0.18),
        brightWhite: CodableColor(red: 0.97, green: 0.97, blue: 0.95)
    )
}
