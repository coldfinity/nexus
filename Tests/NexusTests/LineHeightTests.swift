import XCTest
import AppKit
import SwiftTerm
@testable import Nexus

@MainActor
final class LineHeightTests: XCTestCase {
    /// The vendored SwiftTerm patch scales cell height by lineHeightMultiplier.
    func testLineHeightMultiplierScalesCellHeight() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Taller cells mean fewer rows fit in the same fixed frame.
        view.lineHeightMultiplier = 1.0
        let baseRows = Double(view.getTerminal().rows)

        view.lineHeightMultiplier = 1.5
        let tallRows = Double(view.getTerminal().rows)

        XCTAssertLessThan(tallRows, baseRows)
        // Row count should shrink by roughly the multiplier.
        XCTAssertEqual(baseRows / tallRows, 1.5, accuracy: 0.15)
    }
}
