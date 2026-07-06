import SwiftUI
import AppKit

/// Applies window-level appearance from `WindowConfig`: transparency (so a
/// translucent terminal background shows the desktop through) and an optional
/// vibrancy blur backdrop.
struct WindowConfigurator: NSViewRepresentable {
    let window: WindowConfig
    let isDark: Bool
    /// The terminal theme's background — used as the opaque window color so the
    /// padding around the terminal blends with it.
    let backgroundColor: NSColor

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { apply(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(from: nsView) }
    }

    private func apply(from view: NSView) {
        guard let win = view.window else { return }
        let translucent = window.opacity < 1.0 || window.blur
        win.isOpaque = !translucent
        win.backgroundColor = translucent ? .clear : backgroundColor
        // Match the titlebar and system controls to the terminal theme.
        win.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}

/// A vibrancy backdrop placed behind the terminal content when blur is enabled.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
