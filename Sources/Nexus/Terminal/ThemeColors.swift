import AppKit
import SwiftTerm

/// Parsing of `#rrggbb` hex strings into the color types SwiftTerm needs.
enum HexColor {
    /// Parse into (r,g,b) bytes. Returns nil for malformed input.
    static func rgb(_ hex: String) -> (UInt8, UInt8, UInt8)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return (
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        )
    }

    /// SwiftTerm uses 16-bit color channels (0...65535).
    static func swiftTerm(_ hex: String, fallback: SwiftTerm.Color = SwiftTerm.Color(red: 0, green: 0, blue: 0)) -> SwiftTerm.Color {
        guard let (r, g, b) = rgb(hex) else { return fallback }
        return SwiftTerm.Color(
            red: UInt16(r) * 257,
            green: UInt16(g) * 257,
            blue: UInt16(b) * 257
        )
    }

    static func nsColor(_ hex: String, alpha: CGFloat = 1.0, fallback: NSColor = .black) -> NSColor {
        guard let (r, g, b) = rgb(hex) else { return fallback }
        return NSColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: alpha
        )
    }
}

extension Theme {
    /// The 16 ANSI colors as SwiftTerm colors, in palette order.
    var ansiSwiftTermColors: [SwiftTerm.Color] {
        ansi.map { HexColor.swiftTerm($0) }
    }
}
