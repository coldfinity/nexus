import Foundation

/// A named, built-in color theme selectable from the theme picker.
public struct NamedTheme: Identifiable, Equatable, Sendable {
    public let name: String
    public let theme: Theme
    public var id: String { name }
}

public enum BuiltInThemes {
    public static let all: [NamedTheme] = [
        NamedTheme(name: "One Dark", theme: Theme.defaultDark),
        NamedTheme(name: "Dracula", theme: Theme(
            foreground: "#f8f8f2", background: "#282a36", cursor: "#f8f8f0",
            ansi: [
                "#21222c", "#ff5555", "#50fa7b", "#f1fa8c",
                "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2",
                "#6272a4", "#ff6e6e", "#69ff94", "#ffffa5",
                "#d6acff", "#ff92df", "#a4ffff", "#ffffff"
            ])),
        NamedTheme(name: "Solarized Dark", theme: Theme(
            foreground: "#839496", background: "#002b36", cursor: "#93a1a1",
            ansi: [
                "#073642", "#dc322f", "#859900", "#b58900",
                "#268bd2", "#d33682", "#2aa198", "#eee8d5",
                "#002b36", "#cb4b16", "#586e75", "#657b83",
                "#839496", "#6c71c4", "#93a1a1", "#fdf6e3"
            ])),
        NamedTheme(name: "Solarized Light", theme: Theme(
            foreground: "#657b83", background: "#fdf6e3", cursor: "#586e75",
            ansi: [
                "#073642", "#dc322f", "#859900", "#b58900",
                "#268bd2", "#d33682", "#2aa198", "#eee8d5",
                "#002b36", "#cb4b16", "#586e75", "#657b83",
                "#839496", "#6c71c4", "#93a1a1", "#fdf6e3"
            ])),
        NamedTheme(name: "Nord", theme: Theme(
            foreground: "#d8dee9", background: "#2e3440", cursor: "#d8dee9",
            ansi: [
                "#3b4252", "#bf616a", "#a3be8c", "#ebcb8b",
                "#81a1c1", "#b48ead", "#88c0d0", "#e5e9f0",
                "#4c566a", "#bf616a", "#a3be8c", "#ebcb8b",
                "#81a1c1", "#b48ead", "#8fbcbb", "#eceff4"
            ])),
        NamedTheme(name: "Gruvbox Dark", theme: Theme(
            foreground: "#ebdbb2", background: "#282828", cursor: "#ebdbb2",
            ansi: [
                "#282828", "#cc241d", "#98971a", "#d79921",
                "#458588", "#b16286", "#689d6a", "#a89984",
                "#928374", "#fb4934", "#b8bb26", "#fabd2f",
                "#83a598", "#d3869b", "#8ec07c", "#ebdbb2"
            ])),
        NamedTheme(name: "Tokyo Night", theme: Theme(
            foreground: "#c0caf5", background: "#1a1b26", cursor: "#c0caf5",
            ansi: [
                "#15161e", "#f7768e", "#9ece6a", "#e0af68",
                "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6",
                "#414868", "#f7768e", "#9ece6a", "#e0af68",
                "#7aa2f7", "#bb9af7", "#7dcfff", "#c0caf5"
            ])),
        NamedTheme(name: "Rosé Pine", theme: Theme(
            foreground: "#e0def4", background: "#191724", cursor: "#e0def4",
            ansi: [
                "#26233a", "#eb6f92", "#31748f", "#f6c177",
                "#9ccfd8", "#c4a7e7", "#ebbcba", "#e0def4",
                "#6e6a86", "#eb6f92", "#31748f", "#f6c177",
                "#9ccfd8", "#c4a7e7", "#ebbcba", "#e0def4"
            ])),
        NamedTheme(name: "Black Metal (Venom)", theme: Theme(
            foreground: "#c1c1c1", background: "#000000", cursor: "#c1c1c1",
            ansi: [
                "#000000", "#5f8787", "#f8f7f2", "#79241f",
                "#888888", "#999999", "#aaaaaa", "#c1c1c1",
                "#404040", "#5f8787", "#f8f7f2", "#79241f",
                "#888888", "#999999", "#aaaaaa", "#c1c1c1"
            ])),
        NamedTheme(name: "Monokai", theme: Theme(
            foreground: "#f8f8f2", background: "#272822", cursor: "#f8f8f0",
            ansi: [
                "#272822", "#f92672", "#a6e22e", "#f4bf75",
                "#66d9ef", "#ae81ff", "#a1efe4", "#f8f8f2",
                "#75715e", "#f92672", "#a6e22e", "#f4bf75",
                "#66d9ef", "#ae81ff", "#a1efe4", "#f9f8f5"
            ]))
    ]

    /// The preset matching `theme` exactly, if any (else the user has a custom
    /// palette).
    public static func match(_ theme: Theme) -> NamedTheme? {
        all.first { $0.theme == theme }
    }

    /// The preset with the given name, ignoring case and diacritics (so
    /// "rose pine" matches "Rosé Pine").
    public static func named(_ name: String) -> NamedTheme? {
        let target = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return all.first {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) == target
        }
    }
}
