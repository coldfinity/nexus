import SwiftUI
import AppKit

/// Applies window-level appearance from `WindowConfig`: transparency (so a
/// translucent terminal background shows the desktop through) and a WezTerm-style
/// background blur of whatever is behind the window.
struct WindowConfigurator: NSViewRepresentable {
    let window: WindowConfig
    let isDark: Bool
    /// The terminal theme's background — used as the opaque window color so the
    /// padding around the terminal blends with it.
    let backgroundColor: NSColor

    /// Blur radius (points) applied behind the window when blur is enabled.
    private let blurRadius = 30

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
        // Frosted-glass blur of the desktop behind the (translucent) window.
        WindowBlur.setRadius(window.blur ? blurRadius : 0, on: win)
    }
}

/// WezTerm-style background blur via the private window-server API
/// (`CGSSetWindowBackgroundBlurRadius`), resolved at runtime with `dlsym` so
/// there's no link-time dependency on private symbols.
private enum WindowBlur {
    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias SetBlurFn = @convention(c) (Int32, Int, Int) -> Int32

    private static let mainConnection: ConnectionFn? = symbol("CGSMainConnectionID")
    private static let setBackgroundBlur: SetBlurFn? = symbol("CGSSetWindowBackgroundBlurRadius")

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle = dlopen(nil, RTLD_LAZY), let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    static func setRadius(_ radius: Int, on window: NSWindow) {
        guard let connection = mainConnection, let setBlur = setBackgroundBlur else { return }
        _ = setBlur(connection(), window.windowNumber, radius)
    }
}
