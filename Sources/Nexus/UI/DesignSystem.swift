import SwiftUI
import AppKit

/// Geometry + type tokens that don't depend on the theme.
enum NX {
    static let radius: CGFloat = 7
    static let rowRadius: CGFloat = 6
}

/// An SF Symbol resolved through AppKit (`NSImage(systemSymbolName:)`) rather
/// than SwiftUI's `Image(systemName:)`. In SwiftPM-built apps the SwiftUI path
/// can fail to resolve symbols at runtime and shows a "?" placeholder; the
/// AppKit path is reliable. Renders as a template so `foregroundStyle` tints it.
struct Icon: View {
    let name: String
    var size: CGFloat = 13
    var weight: NSFont.Weight = .regular

    var body: some View {
        if let image = Self.symbol(name, size: size, weight: weight) {
            Image(nsImage: image).renderingMode(.template)
        } else {
            Image(systemName: name).font(.system(size: size))
        }
    }

    private static func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let configured = base.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        ) ?? base

        // Flatten into a plain bitmap. Multi-layer symbols (badges, "…in.circle",
        // connected-graph glyphs) render unreliably when hosted live; a
        // pre-rasterized template image always draws.
        let box = configured.size
        guard box.width > 0, box.height > 0 else {
            configured.isTemplate = true
            return configured
        }
        let flattened = NSImage(size: box)
        flattened.lockFocus()
        configured.draw(in: NSRect(origin: .zero, size: box))
        flattened.unlockFocus()
        flattened.isTemplate = true
        return flattened
    }
}

extension Font {
    static let nxSectionLabel = Font.system(size: 10, weight: .semibold)
    static let nxMonoSmall = Font.system(size: 10, design: .monospaced)
    static let nxMono = Font.system(size: 11, design: .monospaced)
}

/// A small RGB helper for deriving chrome colors from the terminal theme.
private struct RGBColor {
    var r: Double, g: Double, b: Double

    static func from(hex: String, fallback: RGBColor) -> RGBColor {
        guard let (r, g, b) = HexColor.rgb(hex) else { return fallback }
        return RGBColor(r: Double(r) / 255, g: Double(g) / 255, b: Double(b) / 255)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    var chroma: Double { Swift.max(r, g, b) - Swift.min(r, g, b) }

    func mix(_ other: RGBColor, _ t: Double) -> RGBColor {
        RGBColor(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
}

/// The chrome color palette, derived from the active terminal `Theme` so the
/// tab bar, sidebar, and panels harmonize with whatever colors are on screen.
struct Palette: Equatable {
    var surface: Color
    var surfaceRaised: Color
    var surfaceSunken: Color
    var hairline: Color
    var textPrimary: Color
    var textSecondary: Color
    var textTertiary: Color
    var overlay: Color
    var overlayStrong: Color
    var accent: Color
    var danger: Color
    var lanes: [Color]
    var isDark: Bool
    /// The window's background opacity; chrome surfaces adopt this so the
    /// desktop shows through in transparency mode. Text/icons stay fully opaque.
    var windowOpacity: Double = 1

    /// Translucent chrome backgrounds (solid when `windowOpacity` is 1).
    var chrome: Color { surface.opacity(windowOpacity) }
    var chromeRaised: Color { surfaceRaised.opacity(windowOpacity) }

    static func from(theme: Theme, opacity: Double = 1) -> Palette {
        let bg = RGBColor.from(hex: theme.background, fallback: RGBColor(r: 0.09, g: 0.10, b: 0.11))
        let fg = RGBColor.from(hex: theme.foreground, fallback: RGBColor(r: 0.9, g: 0.9, b: 0.9))
        let isDark = bg.luminance < 0.5
        let ansi = theme.ansi

        func a(_ i: Int) -> RGBColor {
            RGBColor.from(hex: i < ansi.count ? ansi[i] : "#888888", fallback: RGBColor(r: 0.5, g: 0.5, b: 0.5))
        }

        // Accent: the most vivid non-red color in the theme (cursor gets first
        // dibs if it's saturated enough), so the accent always belongs to the
        // palette rather than being imposed.
        let cursor = RGBColor.from(hex: theme.cursor, fallback: fg)
        var candidates = [a(4), a(12), a(2), a(10), a(5), a(13), a(6), a(14), a(3), a(11)]
        if cursor.chroma > 0.15 { candidates.insert(cursor, at: 0) }
        let accent = candidates.max(by: { $0.chroma < $1.chroma }) ?? cursor

        let fgColor = fg.color
        return Palette(
            surface: bg.color,
            surfaceRaised: bg.mix(fg, 0.06).color,
            surfaceSunken: bg.mix(isDark ? RGBColor(r: 0, g: 0, b: 0) : fg, isDark ? 0.22 : 0.05).color,
            hairline: bg.mix(fg, 0.15).color,
            textPrimary: fgColor,
            textSecondary: fg.mix(bg, 0.40).color,
            textTertiary: fg.mix(bg, 0.62).color,
            overlay: fgColor.opacity(isDark ? 0.06 : 0.06),
            overlayStrong: fgColor.opacity(isDark ? 0.11 : 0.10),
            accent: accent.color,
            danger: a(1).color,
            lanes: [a(4), a(2), a(5), a(3), a(6), a(1), a(12), a(10)].map { $0.color },
            isDark: isDark,
            windowOpacity: opacity
        )
    }

    static let fallbackDark = Palette.from(theme: .defaultDark)
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.fallbackDark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// An uppercase, letter-spaced section header used throughout the sidebar.
struct SectionLabel: View {
    @Environment(\.palette) private var palette
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.nxSectionLabel)
            .tracking(0.8)
            .foregroundStyle(palette.textTertiary)
    }
}
