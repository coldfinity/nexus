import SwiftUI

/// Parses config shortcut strings like `"cmd+shift+d"` into a SwiftUI
/// `KeyboardShortcut`. Unknown tokens are ignored; an unparseable string yields
/// nil so the caller can fall back to a default.
enum ShortcutParser {
    static func parse(_ string: String) -> KeyboardShortcut? {
        let tokens = string.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyToken = tokens.last, !keyToken.isEmpty else { return nil }

        var modifiers: EventModifiers = []
        for token in tokens.dropLast() {
            switch token {
            case "cmd", "command", "super": modifiers.insert(.command)
            case "shift": modifiers.insert(.shift)
            case "ctrl", "control": modifiers.insert(.control)
            case "opt", "option", "alt": modifiers.insert(.option)
            default: break
            }
        }

        guard let key = keyEquivalent(keyToken) else { return nil }
        return KeyboardShortcut(key, modifiers: modifiers)
    }

    private static func keyEquivalent(_ token: String) -> KeyEquivalent? {
        switch token {
        case "return", "enter": return .return
        case "tab": return .tab
        case "space": return .space
        case "escape", "esc": return .escape
        case "delete", "backspace": return .delete
        case "up": return .upArrow
        case "down": return .downArrow
        case "left": return .leftArrow
        case "right": return .rightArrow
        default:
            guard token.count == 1, let ch = token.first else { return nil }
            return KeyEquivalent(ch)
        }
    }
}
