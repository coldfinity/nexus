import SwiftUI
import AppKit

private let tilingSpace = "nexus.tiling"

/// Renders a tab's panes as a flat, absolutely-positioned set of siblings driven
/// by `computeTileLayout`. Each pane keeps a stable identity (its UUID) no matter
/// how the tree restructures, so splitting or closing a pane only re-frames the
/// survivors — it never tears down and rebuilds their terminal views.
struct LayoutTreeView: View {
    let node: LayoutNode
    let tab: TerminalTab
    let workspace: Workspace
    let config: Config

    private let thickness: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let layout = computeTileLayout(
                node,
                in: CGRect(origin: .zero, size: geo.size),
                dividerThickness: thickness
            )

            ZStack(alignment: .topLeading) {
                ForEach(layout.panes) { frame in
                    if let pane = workspace.pane(frame.paneID) {
                        PaneContainerView(
                            pane: pane,
                            isFocused: workspace.selectedTabID == tab.id && tab.focusedPaneID == frame.paneID,
                            config: config,
                            onFocus: { workspace.focusPane(frame.paneID) }
                        )
                        .frame(width: frame.rect.width, height: frame.rect.height)
                        .offset(x: frame.rect.minX, y: frame.rect.minY)
                    }
                }

                ForEach(layout.dividers) { spec in
                    DividerHandle(spec: spec, thickness: thickness) { newRatio in
                        tab.root = tab.root.settingRatio(newRatio, forSplitID: spec.splitID)
                    }
                }
            }
            .coordinateSpace(name: tilingSpace)
        }
    }
}

/// A draggable divider positioned over a split. Uses absolute drag location in
/// the tiling coordinate space to compute the new ratio, so there's no feedback.
private struct DividerHandle: View {
    @Environment(\.palette) private var palette
    let spec: DividerSpec
    let thickness: CGFloat
    let onRatio: (Double) -> Void

    @State private var hovering = false

    var body: some View {
        Rectangle()
            .fill(hovering ? palette.accent.opacity(0.6) : palette.hairline)
            .frame(width: spec.rect.width, height: spec.rect.height)
            .offset(x: spec.rect.minX, y: spec.rect.minY)
            .onHover { inside in
                hovering = inside
                if inside {
                    (spec.horizontalSplit ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .named(tilingSpace))
                    .onChanged { value in
                        let sr = spec.splitRect
                        let newRatio: Double
                        if spec.horizontalSplit {
                            newRatio = Double((value.location.x - sr.minX) / max(sr.width - thickness, 1))
                        } else {
                            newRatio = Double((value.location.y - sr.minY) / max(sr.height - thickness, 1))
                        }
                        onRatio(newRatio)
                    }
            )
    }
}
