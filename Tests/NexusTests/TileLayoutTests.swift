import XCTest
import CoreGraphics
@testable import Nexus

final class TileLayoutTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 600)
    private let t: CGFloat = 6

    func testSingleLeafFillsBounds() {
        let a = UUID()
        let layout = computeTileLayout(.leaf(a), in: bounds, dividerThickness: t)
        XCTAssertEqual(layout.panes.count, 1)
        XCTAssertEqual(layout.panes[0].rect, bounds)
        XCTAssertTrue(layout.dividers.isEmpty)
    }

    func testHorizontalSplitDividesWidth() {
        let a = UUID(), b = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b, ratio: 0.5)
        let layout = computeTileLayout(tree, in: bounds, dividerThickness: t)

        let byID = Dictionary(uniqueKeysWithValues: layout.panes.map { ($0.paneID, $0.rect) })
        // (1000 - 6) / 2 = 497 each
        XCTAssertEqual(byID[a]!.width, 497, accuracy: 0.01)
        XCTAssertEqual(byID[b]!.width, 497, accuracy: 0.01)
        XCTAssertEqual(byID[a]!.height, 600, accuracy: 0.01)
        // panes don't overlap the divider gap
        XCTAssertEqual(byID[b]!.minX, 503, accuracy: 0.01)
        XCTAssertEqual(layout.dividers.count, 1)
        XCTAssertTrue(layout.dividers[0].horizontalSplit)
    }

    func testVerticalSplitDividesHeight() {
        let a = UUID(), b = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .vertical, newPaneID: b, ratio: 0.5)
        let layout = computeTileLayout(tree, in: bounds, dividerThickness: t)

        let byID = Dictionary(uniqueKeysWithValues: layout.panes.map { ($0.paneID, $0.rect) })
        XCTAssertEqual(byID[a]!.height, 297, accuracy: 0.01)
        XCTAssertEqual(byID[b]!.height, 297, accuracy: 0.01)
        XCTAssertEqual(byID[a]!.width, 1000, accuracy: 0.01)
        XCTAssertFalse(layout.dividers[0].horizontalSplit)
    }

    func testNestedSplitProducesThreePanesThatTileTheBounds() {
        let a = UUID(), b = UUID(), c = UUID()
        var tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b)
        tree = tree.splitting(paneID: b, direction: .vertical, newPaneID: c)
        let layout = computeTileLayout(tree, in: bounds, dividerThickness: t)

        XCTAssertEqual(layout.panes.count, 3)
        XCTAssertEqual(layout.dividers.count, 2)
        // Total pane area + divider area should roughly cover the bounds and not
        // exceed it.
        for frame in layout.panes {
            XCTAssertTrue(bounds.contains(frame.rect.integral) || bounds.union(frame.rect) == bounds)
            XCTAssertGreaterThan(frame.rect.width, 0)
            XCTAssertGreaterThan(frame.rect.height, 0)
        }
    }

    func testClosingAPaneReflowsSurvivorToFullBounds() {
        // Two panes side by side; closing one should leave the other filling
        // the whole area (this is the "resize on close" behaviour).
        let a = UUID(), b = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b)
        let afterClose = tree.removing(paneID: b)!
        let layout = computeTileLayout(afterClose, in: bounds, dividerThickness: t)
        XCTAssertEqual(layout.panes.count, 1)
        XCTAssertEqual(layout.panes[0].paneID, a)
        XCTAssertEqual(layout.panes[0].rect, bounds)
        XCTAssertTrue(layout.dividers.isEmpty)
    }
}
