import SwiftUI
import AppKit

/// Hosts a pane's persistent terminal view inside SwiftUI. `makeNSView` returns
/// only a lightweight container; the actual terminal view lives on the `Pane`'s
/// `TerminalController` and is re-parented here. This keeps exactly one shell
/// per pane across splits, tab switches, and other layout restructuring.
struct TerminalPaneView: NSViewRepresentable {
    let pane: Pane
    let config: Config
    let isFocused: Bool
    let onFocusRequest: () -> Void

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        attach(to: container)

        let controller = pane.controller()
        controller.onFocus = onFocusRequest
        controller.apply(config)
        controller.startIfNeeded(directory: pane.startDirectory)

        // Make the focused pane the first responder. Deferred to the next
        // runloop tick because during a tab switch the view isn't in a window
        // yet when updateNSView runs, so a synchronous call would be dropped.
        if isFocused {
            DispatchQueue.main.async {
                guard let window = controller.view.window,
                      window.firstResponder !== controller.view else { return }
                window.makeFirstResponder(controller.view)
            }
        }
    }

    /// Ensure the pane's persistent terminal view is pinned inside `container`,
    /// re-parenting it from a previous container if the layout moved it.
    private func attach(to container: NSView) {
        let terminal = pane.controller().view
        guard terminal.superview !== container else { return }
        terminal.removeFromSuperview()
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}
