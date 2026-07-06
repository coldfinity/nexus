import XCTest
@testable import Nexus

@MainActor
final class AgentStoreTests: XCTestCase {
    func testParsesSqliteJSONRows() {
        // Shape emitted by `sqlite3 -json`: model is a nested JSON string.
        let json = ##"""
        [{"id":"ses_abc","title":"Add agent view","agent":"dev","model":"{\"id\":\"deepseek-v4-pro\",\"providerID\":\"deepseek\"}","time_updated":1783326307062}]
        """##.data(using: .utf8)!

        let now = Date(timeIntervalSince1970: 1783326307)  // same second → active
        let sessions = AgentStore.parse(json, now: now)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]
        XCTAssertEqual(s.id, "ses_abc")
        XCTAssertEqual(s.title, "Add agent view")
        XCTAssertEqual(s.agent, "dev")
        XCTAssertEqual(s.model, "deepseek-v4-pro")   // extracted from nested JSON
        XCTAssertTrue(s.isActive)
    }

    func testInactiveWhenStale() {
        let json = ##"[{"id":"s","title":"t","agent":null,"model":null,"time_updated":1000000000000}]"##.data(using: .utf8)!
        let sessions = AgentStore.parse(json, now: Date())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertFalse(sessions[0].isActive)
        XCTAssertNil(sessions[0].model)
    }

    func testEmptyResult() {
        XCTAssertTrue(AgentStore.parse(Data("[]".utf8), now: Date()).isEmpty)
        XCTAssertTrue(AgentStore.parse(Data(), now: Date()).isEmpty)
    }

    func testResumeCommand() {
        let session = AgentStore.OpencodeSession(
            id: "ses_xyz", title: "t", agent: nil, model: nil, lastActivity: Date(), isActive: false)
        let store = AgentStore(dbPath: "/nonexistent")
        XCTAssertEqual(store.resumeCommand(for: session), "opencode --session ses_xyz")
    }
}
