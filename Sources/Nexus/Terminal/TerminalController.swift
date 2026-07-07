import AppKit
import SwiftTerm

/// Owns one pane's `LocalProcessTerminalView` for the pane's whole lifetime,
/// independent of SwiftUI view identity.
///
/// This is the crux of correct split/tab behaviour: when the layout tree
/// restructures (a leaf becoming a split, a pane moving branches), SwiftUI tears
/// down and rebuilds the *hosting* views. If the terminal NSView were created in
/// `makeNSView`, every restructure would spawn a fresh shell and orphan the old
/// one. Instead the view is created once here and merely re-parented, so exactly
/// one shell lives per pane.
@MainActor
final class TerminalController: NSObject, @preconcurrency LocalProcessTerminalViewDelegate {
    let view: LocalProcessTerminalView
    private weak var pane: Pane?
    var onFocus: (() -> Void)?
    private var started = false

    init(pane: Pane) {
        self.pane = pane
        self.view = LocalProcessTerminalView(frame: .zero)
        super.init()
        view.processDelegate = self

        // Report focus on click without stealing mouse events (SwiftTerm's
        // responder methods are sealed and can't be overridden).
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleFocusClick))
        click.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(click)
    }

    /// Spawn the shell the first time the pane is shown.
    func startIfNeeded(directory: String?) {
        guard !started else { return }
        started = true
        SessionLauncher.start(in: view, directory: directory)

        // Run the pane's pending command once the shell has had a moment to
        // print its prompt (e.g. resuming a Claude Code session).
        if let command = pane?.pendingCommand {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak view] in
                view?.send(txt: command + "\n")
            }
        }
    }

    /// Re-spawn after the shell exited (bound to the restart affordance).
    func restart(directory: String?) {
        started = true
        SessionLauncher.start(in: view, directory: directory)
    }

    /// The PID of the shell running in this pane (0 before it starts).
    var shellPid: pid_t {
        view.process?.shellPid ?? 0
    }

    /// Kill the shell process (SIGTERM) when the pane is closed.
    func terminate() {
        view.terminate()
    }

    func apply(_ config: Config) {
        let theme = config.theme
        view.installColors(theme.ansiSwiftTermColors)
        view.nativeForegroundColor = HexColor.nsColor(theme.foreground, fallback: .white)

        // Terminal panes are translucent only when transparency is scoped to
        // include the terminal; otherwise they stay fully opaque.
        let bgAlpha = config.window.transparentTerminal ? config.window.opacity : 1.0
        let bgColor = HexColor.nsColor(theme.background, alpha: CGFloat(bgAlpha), fallback: .black)
        view.nativeBackgroundColor = bgColor
        // SwiftTerm only pushes the alpha to its layer during initial setup, so
        // set it directly here — this is what actually makes the pane see-through.
        view.wantsLayer = true
        view.layer?.backgroundColor = bgColor.cgColor
        view.layer?.isOpaque = bgAlpha >= 1.0

        view.caretColor = HexColor.nsColor(theme.cursor, fallback: .white)

        view.font = Self.makeFont(config.font)
        view.lineHeightMultiplier = CGFloat(config.font.lineHeight)
    }

    /// Resolve the terminal font by family + weight. Uses a font descriptor
    /// (matching by family, so real family names like "SF Mono" or "JetBrains
    /// Mono" work — `NSFont(name:)` does not), falling back to the monospaced
    /// system font at the requested weight if the family isn't installed.
    static func makeFont(_ font: FontConfig) -> NSFont {
        let size = CGFloat(font.size)
        let weight = weight(named: font.weight)
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: font.family,
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue],
        ])
        return NSFont(descriptor: descriptor, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    static func weight(named name: String) -> NSFont.Weight {
        switch name.lowercased() {
        case "thin": return .thin
        case "ultralight", "ultra-light": return .ultraLight
        case "light": return .light
        case "medium": return .medium
        case "semibold", "semi-bold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }

    @objc private func handleFocusClick() {
        onFocus?()
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        if !title.isEmpty { pane?.title = title }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        if let directory { pane?.currentDirectory = directory }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        pane?.hasExited = true
        pane?.exitCode = exitCode
    }
}
