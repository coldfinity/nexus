import Foundation

/// Orientation of a split. `.horizontal` places panes side-by-side (a vertical
/// divider), `.vertical` stacks them top/bottom (a horizontal divider) — matching
/// how most terminals label "split horizontally / vertically".
public enum SplitDirection: String, Codable, Sendable {
    case horizontal
    case vertical
}

/// A pure, value-type binary tree describing a tab's pane layout.
///
/// Leaves reference panes by `UUID`; split nodes also carry a stable `UUID` so
/// dividers have identity for drag handling and SwiftUI diffing. The actual
/// terminal sessions live in a separate registry, so this tree stays free of
/// UI/process state and can be unit-tested in isolation. Every operation returns
/// a new tree (value semantics) rather than mutating in place.
public indirect enum LayoutNode: Equatable, Sendable {
    case leaf(UUID)
    case split(id: UUID, direction: SplitDirection, ratio: Double, first: LayoutNode, second: LayoutNode)

    // MARK: - Queries

    /// All pane IDs in left-to-right, depth-first order.
    public var paneIDs: [UUID] {
        switch self {
        case let .leaf(id):
            return [id]
        case let .split(_, _, _, first, second):
            return first.paneIDs + second.paneIDs
        }
    }

    /// The first (top-left) leaf's pane ID.
    public var firstPaneID: UUID? {
        paneIDs.first
    }

    public func contains(_ paneID: UUID) -> Bool {
        paneIDs.contains(paneID)
    }

    // MARK: - Mutations

    /// Split the leaf holding `paneID` into two panes, inserting `newPaneID`.
    /// The existing pane becomes `first`, the new pane `second`. No-op if the
    /// pane isn't found.
    public func splitting(
        paneID: UUID,
        direction: SplitDirection,
        newPaneID: UUID,
        splitID: UUID = UUID(),
        ratio: Double = 0.5
    ) -> LayoutNode {
        switch self {
        case let .leaf(id):
            guard id == paneID else { return self }
            return .split(
                id: splitID,
                direction: direction,
                ratio: ratio,
                first: .leaf(id),
                second: .leaf(newPaneID)
            )
        case let .split(sid, dir, r, first, second):
            return .split(
                id: sid,
                direction: dir,
                ratio: r,
                first: first.splitting(paneID: paneID, direction: direction, newPaneID: newPaneID, splitID: splitID, ratio: ratio),
                second: second.splitting(paneID: paneID, direction: direction, newPaneID: newPaneID, splitID: splitID, ratio: ratio)
            )
        }
    }

    /// Remove the pane with `paneID`. When a split loses a child, it collapses
    /// to the surviving child. Returns `nil` if the whole tree is removed
    /// (i.e. the last pane was closed).
    public func removing(paneID: UUID) -> LayoutNode? {
        switch self {
        case let .leaf(id):
            return id == paneID ? nil : self
        case let .split(sid, dir, r, first, second):
            let newFirst = first.removing(paneID: paneID)
            let newSecond = second.removing(paneID: paneID)
            switch (newFirst, newSecond) {
            case (nil, nil):
                return nil // shouldn't happen (a pane is in only one subtree) but stay total
            case let (nil, .some(child)), let (.some(child), nil):
                return child
            case let (.some(f), .some(s)):
                return .split(id: sid, direction: dir, ratio: r, first: f, second: s)
            }
        }
    }

    /// Update the ratio of the split node with `splitID`. Clamped so a pane
    /// can't be dragged to nothing.
    public func settingRatio(_ ratio: Double, forSplitID splitID: UUID) -> LayoutNode {
        let clamped = min(max(ratio, 0.05), 0.95)
        switch self {
        case .leaf:
            return self
        case let .split(sid, dir, r, first, second):
            if sid == splitID {
                return .split(id: sid, direction: dir, ratio: clamped, first: first, second: second)
            }
            return .split(
                id: sid,
                direction: dir,
                ratio: r,
                first: first.settingRatio(ratio, forSplitID: splitID),
                second: second.settingRatio(ratio, forSplitID: splitID)
            )
        }
    }
}
