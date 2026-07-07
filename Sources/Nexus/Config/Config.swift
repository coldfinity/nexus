import Foundation

/// The persisted, user-editable configuration. Lives at
/// `~/.config/nexus/config.json`. Every field has a default so a partial or
/// empty file still decodes.
public struct Config: Codable, Equatable, Sendable {
    public var theme: Theme
    public var font: FontConfig
    public var window: WindowConfig
    public var keybindings: [String: String]
    /// Git sidebar width in points.
    public var sidebarWidth: Double
    /// Padding (points) around the terminal panes — a margin from the tab bar
    /// and window edges.
    public var padding: Double

    public init(
        theme: Theme = .defaultDark,
        font: FontConfig = .init(),
        window: WindowConfig = .init(),
        keybindings: [String: String] = Config.defaultKeybindings,
        sidebarWidth: Double = 340,
        padding: Double = 8
    ) {
        self.theme = theme
        self.font = font
        self.window = window
        self.keybindings = keybindings
        self.sidebarWidth = sidebarWidth
        self.padding = padding
    }

    // Decode with per-field fallback so an incomplete JSON object is valid.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(Theme.self, forKey: .theme) ?? .defaultDark
        font = try c.decodeIfPresent(FontConfig.self, forKey: .font) ?? .init()
        window = try c.decodeIfPresent(WindowConfig.self, forKey: .window) ?? .init()
        keybindings = try c.decodeIfPresent([String: String].self, forKey: .keybindings) ?? Config.defaultKeybindings
        sidebarWidth = try c.decodeIfPresent(Double.self, forKey: .sidebarWidth).map { min(max($0, 240), 680) } ?? 340
        padding = try c.decodeIfPresent(Double.self, forKey: .padding).map { min(max($0, 0), 40) } ?? 8
    }

    public static let sidebarWidthRange: ClosedRange<Double> = 240...680

    public static let defaultKeybindings: [String: String] = [
        "newTab": "cmd+t",
        "closePane": "cmd+w",
        "splitHorizontal": "cmd+d",
        "splitVertical": "cmd+shift+d"
    ]
}

/// Terminal colors. Hex strings (`#rrggbb`) keep the config human-editable.
public struct Theme: Codable, Equatable, Sendable {
    public var foreground: String
    public var background: String
    public var cursor: String
    /// The 16 ANSI colors (0-7 normal, 8-15 bright).
    public var ansi: [String]

    public init(foreground: String, background: String, cursor: String, ansi: [String]) {
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
        self.ansi = ansi
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        foreground = try c.decodeIfPresent(String.self, forKey: .foreground) ?? Theme.defaultDark.foreground
        background = try c.decodeIfPresent(String.self, forKey: .background) ?? Theme.defaultDark.background
        cursor = try c.decodeIfPresent(String.self, forKey: .cursor) ?? Theme.defaultDark.cursor
        let decoded = try c.decodeIfPresent([String].self, forKey: .ansi) ?? Theme.defaultDark.ansi
        ansi = decoded.count == 16 ? decoded : Theme.defaultDark.ansi
    }

    /// A pleasant default dark palette (based on the "One Dark" family).
    public static let defaultDark = Theme(
        foreground: "#abb2bf",
        background: "#282c34",
        cursor: "#528bff",
        ansi: [
            "#282c34", "#e06c75", "#98c379", "#e5c07b",
            "#61afef", "#c678dd", "#56b6c2", "#abb2bf",
            "#5c6370", "#e06c75", "#98c379", "#e5c07b",
            "#61afef", "#c678dd", "#56b6c2", "#ffffff"
        ]
    )
}

public struct FontConfig: Codable, Equatable, Sendable {
    public var family: String
    public var size: Double
    /// Line-height multiplier: 1.0 = the font's natural spacing.
    public var lineHeight: Double
    /// Font weight name (thin, light, regular, medium, semibold, bold, …).
    public var weight: String

    public init(family: String = "SF Mono", size: Double = 13, lineHeight: Double = 1.0, weight: String = "regular") {
        self.family = family
        self.size = size
        self.lineHeight = lineHeight
        self.weight = weight
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        family = try c.decodeIfPresent(String.self, forKey: .family) ?? "SF Mono"
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 13
        lineHeight = try c.decodeIfPresent(Double.self, forKey: .lineHeight).map { min(max($0, 0.8), 2.0) } ?? 1.0
        weight = try c.decodeIfPresent(String.self, forKey: .weight) ?? "regular"
    }

    /// Weight names offered in Settings, in visual order.
    public static let weightNames = ["thin", "light", "regular", "medium", "semibold", "bold", "heavy"]
}

public struct WindowConfig: Codable, Equatable, Sendable {
    /// Background opacity, 0...1. Values below 1 let the desktop show through.
    public var opacity: Double
    /// Whether to render a translucent "vibrancy" backdrop behind the window.
    public var blur: Bool
    /// Whether transparency also applies to the terminal panes (true) or just
    /// the chrome/sidebar (false).
    public var transparentTerminal: Bool

    public init(opacity: Double = 1.0, blur: Bool = false, transparentTerminal: Bool = true) {
        self.opacity = opacity
        self.blur = blur
        self.transparentTerminal = transparentTerminal
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity).map { min(max($0, 0.1), 1.0) } ?? 1.0
        blur = try c.decodeIfPresent(Bool.self, forKey: .blur) ?? false
        transparentTerminal = try c.decodeIfPresent(Bool.self, forKey: .transparentTerminal) ?? true
    }
}
