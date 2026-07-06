import XCTest
@testable import Nexus

@MainActor
final class ClaudeCodeStoreTests: XCTestCase {
    func testSlugReplacesSlashesAndDots() {
        XCTAssertEqual(
            ClaudeCodeStore.slug(for: "/Users/yudiwu/Documents/projects/nexus"),
            "-Users-yudiwu-Documents-projects-nexus"
        )
        XCTAssertEqual(
            ClaudeCodeStore.slug(for: "/Users/yudiwu/dotfiles/.config"),
            "-Users-yudiwu-dotfiles--config"
        )
    }

    /// Wait for the store's detached reload to publish.
    private func settle() async { try? await Task.sleep(for: .milliseconds(300)) }

    func testParsesTranscriptIntoSession() async throws {
        let cwd = "/Users/test/project"
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccstore-\(UUID().uuidString)", isDirectory: true)
        let projectDir = root.appendingPathComponent(ClaudeCodeStore.slug(for: cwd), isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let transcript = """
        {"type":"user","message":{"content":"hello"},"sessionId":"abc","cwd":"\(cwd)"}
        {"type":"ai-title","aiTitle":"Build custom terminal","sessionId":"abc"}
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":10}}}
        {"type":"last-prompt","lastPrompt":"add claude code","sessionId":"abc"}
        """
        try transcript.write(to: projectDir.appendingPathComponent("abc.jsonl"), atomically: true, encoding: .utf8)

        let store = ClaudeCodeStore(projectsRoot: root)
        store.update(directory: cwd)
        await settle()

        XCTAssertTrue(store.hasProject)
        XCTAssertEqual(store.sessions.count, 1)
        let session = try XCTUnwrap(store.sessions.first)
        XCTAssertEqual(session.id, "abc")
        XCTAssertEqual(session.title, "Build custom terminal")
        XCTAssertEqual(session.lastPrompt, "add claude code")
        XCTAssertEqual(session.model, "claude-opus-4-8")
        XCTAssertEqual(store.resumeCommand(for: session), "claude --resume abc")
    }

    func testMissingProjectDirectoryYieldsNoSessions() {
        let store = ClaudeCodeStore(projectsRoot: FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)"))
        store.update(directory: "/nowhere")
        XCTAssertFalse(store.hasProject)
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testDeleteRemovesTranscript() async throws {
        let cwd = "/Users/test/proj2"
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccstore-\(UUID().uuidString)", isDirectory: true)
        let projectDir = root.appendingPathComponent(ClaudeCodeStore.slug(for: cwd), isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try #"{"type":"ai-title","aiTitle":"X"}"#.write(
            to: projectDir.appendingPathComponent("s1.jsonl"), atomically: true, encoding: .utf8)

        let store = ClaudeCodeStore(projectsRoot: root)
        store.update(directory: cwd)
        await settle()
        let session = try XCTUnwrap(store.sessions.first)
        store.delete(session)
        await settle()
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.path))
    }
}
