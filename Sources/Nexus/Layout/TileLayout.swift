import Foundation
import CoreGraphics

/// A pane and the rectangle it occupies within the tab's content area.
public struct PaneFrame: Equatable, Identifiable, Sendable {
    public let paneID: UUID
    public let rect: CGRect
    public var id: UUID { paneID }
}

/// A draggable divider: its hit rectangle, the split it resizes, the rectangle
/// of the whole split (for ratio math), and its orientation.
public struct DividerSpec: Equatable, Identifiable, Sendable {
    public let splitID: UUID
    public let rect: CGRect
    public let splitRect: CGRect
    /// True for a side-by-side (horizontal) split, i.e. a vertical divider line.
    public let horizontalSplit: Bool
    public var id: UUID { splitID }
}

/// The flattened geometry of a layout tree: where each pane sits and where the
/// dividers are. Computing this up front lets the UI render every pane as a
/// sibling with a stable identity instead of nesting them, which keeps terminal
/// views (and their shells) alive across splits and closes.
public struct TileLayout: Equatable, Sendable {
    public var panes: [PaneFrame]
    public var dividers: [DividerSpec]

    public static let empty = TileLayout(panes: [], dividers: [])
}

/// Recursively assign rectangles to every leaf in `node` within `rect`.
/// Coordinates are top-left origin, y increasing downward (matching SwiftUI).
public func computeTileLayout(
    _ node: LayoutNode,
    in rect: CGRect,
    dividerThickness t: CGFloat
) -> TileLayout {
    switch node {
    case let .leaf(id):
        return TileLayout(panes: [PaneFrame(paneID: id, rect: rect)], dividers: [])

    case let .split(sid, direction, ratio, first, second):
        switch direction {
        case .horizontal:
            let available = max(rect.width - t, 0)
            let firstW = available * ratio
            let firstRect = CGRect(x: rect.minX, y: rect.minY, width: firstW, height: rect.height)
            let dividerRect = CGRect(x: rect.minX + firstW, y: rect.minY, width: t, height: rect.height)
            let secondRect = CGRect(x: rect.minX + firstW + t, y: rect.minY, width: available - firstW, height: rect.height)
            var layout = merge(
                computeTileLayout(first, in: firstRect, dividerThickness: t),
                computeTileLayout(second, in: secondRect, dividerThickness: t)
            )
            layout.dividers.append(DividerSpec(splitID: sid, rect: dividerRect, splitRect: rect, horizontalSplit: true))
            return layout

        case .vertical:
            let available = max(rect.height - t, 0)
            let firstH = available * ratio
            let firstRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: firstH)
            let dividerRect = CGRect(x: rect.minX, y: rect.minY + firstH, width: rect.width, height: t)
            let secondRect = CGRect(x: rect.minX, y: rect.minY + firstH + t, width: rect.width, height: available - firstH)
            var layout = merge(
                computeTileLayout(first, in: firstRect, dividerThickness: t),
                computeTileLayout(second, in: secondRect, dividerThickness: t)
            )
            layout.dividers.append(DividerSpec(splitID: sid, rect: dividerRect, splitRect: rect, horizontalSplit: false))
            return layout
        }
    }
}

private func merge(_ a: TileLayout, _ b: TileLayout) -> TileLayout {
    TileLayout(panes: a.panes + b.panes, dividers: a.dividers + b.dividers)
}
