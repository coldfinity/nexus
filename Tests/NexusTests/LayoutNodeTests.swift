import XCTest
@testable import Nexus

final class LayoutNodeTests: XCTestCase {
    func testSplitLeafCreatesSplitWithBothPanes() {
        let a = UUID(), b = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b)
        XCTAssertEqual(tree.paneIDs, [a, b])
        if case let .split(_, dir, ratio, first, second) = tree {
            XCTAssertEqual(dir, .horizontal)
            XCTAssertEqual(ratio, 0.5)
            XCTAssertEqual(first, .leaf(a))
            XCTAssertEqual(second, .leaf(b))
        } else {
            XCTFail("expected a split")
        }
    }

    func testSplitUnknownPaneIsNoOp() {
        let a = UUID(), other = UUID(), new = UUID()
        let tree = LayoutNode.leaf(a)
        let result = tree.splitting(paneID: other, direction: .vertical, newPaneID: new)
        XCTAssertEqual(result, tree)
    }

    func testNestedSplitOnlyAffectsTargetPane() {
        let a = UUID(), b = UUID(), c = UUID()
        var tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b)
        tree = tree.splitting(paneID: b, direction: .vertical, newPaneID: c)
        XCTAssertEqual(tree.paneIDs, [a, b, c])
    }

    func testRemovingPaneCollapsesSplit() {
        let a = UUID(), b = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b)
        let afterRemove = tree.removing(paneID: b)
        XCTAssertEqual(afterRemove, .leaf(a))
    }

    func testRemovingLastPaneReturnsNil() {
        let a = UUID()
        XCTAssertNil(LayoutNode.leaf(a).removing(paneID: a))
    }

    func testRemovingMiddlePaneKeepsSiblings() {
        let a = UUID(), b = UUID(), c = UUID()
        var tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b)
        tree = tree.splitting(paneID: b, direction: .vertical, newPaneID: c)
        let afterRemove = tree.removing(paneID: b)
        XCTAssertEqual(afterRemove?.paneIDs, [a, c])
    }

    func testSettingRatioUpdatesMatchingSplit() {
        let a = UUID(), b = UUID()
        let splitID = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b, splitID: splitID)
        let updated = tree.settingRatio(0.7, forSplitID: splitID)
        if case let .split(_, _, ratio, _, _) = updated {
            XCTAssertEqual(ratio, 0.7, accuracy: 0.0001)
        } else {
            XCTFail("expected a split")
        }
    }

    func testSettingRatioClampsToBounds() {
        let a = UUID(), b = UUID()
        let splitID = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b, splitID: splitID)
        let tooBig = tree.settingRatio(2.0, forSplitID: splitID)
        if case let .split(_, _, ratio, _, _) = tooBig {
            XCTAssertEqual(ratio, 0.95, accuracy: 0.0001)
        } else {
            XCTFail("expected a split")
        }
    }

    func testFirstPaneIDIsTopLeft() {
        let a = UUID(), b = UUID()
        let tree = LayoutNode.leaf(a).splitting(paneID: a, direction: .horizontal, newPaneID: b)
        XCTAssertEqual(tree.firstPaneID, a)
    }
}
