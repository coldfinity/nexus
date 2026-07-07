import XCTest
import AppKit
@testable import Nexus

@MainActor
final class FontTests: XCTestCase {
    func testWeightNameMapping() {
        XCTAssertEqual(TerminalController.weight(named: "bold"), .bold)
        XCTAssertEqual(TerminalController.weight(named: "Medium"), .medium)     // case-insensitive
        XCTAssertEqual(TerminalController.weight(named: "semibold"), .semibold)
        XCTAssertEqual(TerminalController.weight(named: "nonsense"), .regular)  // fallback
    }

    func testMakeFontAppliesFamilyAndWeight() {
        var font = FontConfig(family: "SF Mono", size: 14, weight: "bold")
        let bold = TerminalController.makeFont(font)
        XCTAssertEqual(bold.pointSize, 14)
        XCTAssertTrue(bold.isFixedPitch)
        XCTAssertGreaterThan(NSFontManager.shared.weight(of: bold),
                             NSFontManager.shared.weight(of: TerminalController.makeFont(FontConfig(family: "SF Mono", weight: "regular"))))

        // An uninstalled family still yields a usable monospaced font.
        font.family = "Definitely Not Installed Font 12345"
        XCTAssertTrue(TerminalController.makeFont(font).isFixedPitch)
    }

    func testFontWeightRoundTripsThroughLua() throws {
        var config = Config()
        config.font.weight = "medium"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nexus-\(UUID()).lua")
        try LuaConfig.serialize(config).write(to: url, atomically: true, encoding: .utf8)
        XCTAssertEqual(try LuaConfig.load(path: url.path).font.weight, "medium")
    }
}
