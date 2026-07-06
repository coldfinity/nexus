import SwiftUI

/// A single terminal pane: the SwiftTerm view, a focus ring, and — when the
/// shell has exited — a restart overlay.
struct PaneContainerView: View {
    @Environment(\.palette) private var palette
    let pane: Pane
    let isFocused: Bool
    let config: Config
    let onFocus: () -> Void

    var body: some View {
        ZStack {
            TerminalPaneView(
                pane: pane,
                config: config,
                isFocused: isFocused,
                onFocusRequest: onFocus
            )

            if pane.hasExited {
                exitOverlay
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(
                    isFocused ? palette.accent.opacity(0.8) : Color.clear,
                    lineWidth: 1.5
                )
                .allowsHitTesting(false)
        )
    }

    private var exitOverlay: some View {
        Button(action: pane.restart) {
            VStack(spacing: 8) {
                Icon(name: "arrow.clockwise.circle", size: 22)
                    .foregroundStyle(palette.accent)
                Text("Process exited\(pane.exitCode.map { " · code \($0)" } ?? "")")
                    .font(.nxMono)
                    .foregroundStyle(palette.textSecondary)
                Text("Click to restart")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(palette.surface.opacity(0.88))
    }
}
