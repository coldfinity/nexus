import XCTest
@testable import Nexus

final class ConfigTests: XCTestCase {
    private func decode(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    func testEmptyObjectDecodesToDefaults() throws {
        let config = try decode("{}")
        XCTAssertEqual(config, Config())
    }

    func testPartialConfigFillsMissingWithDefaults() throws {
        let config = try decode(#"{ "font": { "size": 16 } }"#)
        XCTAssertEqual(config.font.size, 16)
        XCTAssertEqual(config.font.family, "SF Mono") // default preserved
        XCTAssertEqual(config.theme, Theme.defaultDark) // default preserved
    }

    func testInvalidAnsiCountFallsBackToDefault() throws {
        let config = try decode(##"{ "theme": { "ansi": ["#000000", "#ffffff"] } }"##)
        XCTAssertEqual(config.theme.ansi, Theme.defaultDark.ansi)
    }

    func testOpacityIsClamped() throws {
        let config = try decode(#"{ "window": { "opacity": 5.0 } }"#)
        XCTAssertEqual(config.window.opacity, 1.0, accuracy: 0.0001)
    }

    func testRoundTripEncodeDecode() throws {
        var original = Config()
        original.font.size = 15
        original.window.opacity = 0.8
        original.theme.background = "#101010"
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testHexColorParsing() {
        XCTAssertNil(HexColor.rgb("not a color"))
        XCTAssertNil(HexColor.rgb("#fff")) // 3-digit unsupported
        let rgb = HexColor.rgb("#ff8000")
        XCTAssertEqual(rgb?.0, 255)
        XCTAssertEqual(rgb?.1, 128)
        XCTAssertEqual(rgb?.2, 0)
    }
}
