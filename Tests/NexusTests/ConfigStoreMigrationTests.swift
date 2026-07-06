import XCTest
@testable import Nexus

@MainActor
final class ConfigStoreMigrationTests: XCTestCase {
    func testMigratesLegacyJSONToLua() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nexus-migrate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // A pre-existing legacy JSON config.
        let json = #"{ "font": { "family": "Menlo", "size": 15 }, "window": { "opacity": 0.7 } }"#
        try json.write(to: dir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        let luaURL = dir.appendingPathComponent("config.lua")
        let store = ConfigStore(fileURL: luaURL)

        // config.lua was generated, and the values came from the JSON.
        XCTAssertTrue(FileManager.default.fileExists(atPath: luaURL.path))
        XCTAssertEqual(store.config.font.family, "Menlo")
        XCTAssertEqual(store.config.font.size, 15)
        XCTAssertEqual(store.config.window.opacity, 0.7, accuracy: 0.001)
    }

    func testFreshInstallWritesDefaultLua() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nexus-fresh-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let luaURL = dir.appendingPathComponent("config.lua")
        let store = ConfigStore(fileURL: luaURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: luaURL.path))
        XCTAssertEqual(store.config, Config())
    }
}
