import Foundation
import Observation

/// Observable state for the opencode agent view. opencode records its sessions
/// in a local SQLite database; this reads the sessions for the focused pane's
/// directory (whether or not opencode is currently running) so you can resume a
/// previous one. Mirrors `ClaudeCodeStore`.
@MainActor
@Observable
public final class AgentStore {
    public private(set) var sessions: [OpencodeSession] = []
    /// The opencode database exists (opencode has been used).
    public private(set) var hasStorage = false
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private var directory: String?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private let dbPath: String

    public init(dbPath: String = AgentStore.defaultDBPath) {
        self.dbPath = dbPath
    }

    public struct OpencodeSession: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let agent: String?
        public let model: String?
        public let lastActivity: Date
        public var isActive: Bool
    }

    public nonisolated static let defaultDBPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/opencode/opencode.db").path

    /// The directory currently being reflected (a session resumes here).
    public var projectDirectory: String? { directory }

    // MARK: - Tracking

    public func update(directory newDirectory: String?) {
        guard newDirectory != directory else {
            reload()   // refresh activity/status on each tick
            return
        }
        directory = newDirectory
        reload()
    }

    public func reload() {
        loadTask?.cancel()
        guard let directory, FileManager.default.fileExists(atPath: dbPath) else {
            hasStorage = FileManager.default.fileExists(atPath: dbPath)
            sessions = []
            return
        }
        hasStorage = true
        isLoading = true
        let path = dbPath
        loadTask = Task { [weak self] in
            let json = await Self.query(dbPath: path, directory: directory)
            if Task.isCancelled { return }
            let parsed = json.map { Self.parse($0, now: Date()) } ?? []
            self?.sessions = parsed
            self?.isLoading = false
        }
    }

    // MARK: - Actions

    /// The command that resumes this session (run in a new tab).
    public func resumeCommand(for session: OpencodeSession) -> String {
        "opencode --session \(session.id)"
    }

    /// Delete a session via the opencode CLI, then refresh.
    public func delete(_ session: OpencodeSession) {
        let id = session.id
        Task {
            _ = await Self.runProcess("/usr/bin/env", ["opencode", "session", "delete", id])
            reload()
        }
    }

    // MARK: - Query + parse

    private static func query(dbPath: String, directory: String) async -> Data? {
        let escaped = directory.replacingOccurrences(of: "'", with: "''")
        let sql = """
        SELECT id, title, agent, model, time_updated FROM session \
        WHERE directory='\(escaped)' AND time_archived IS NULL \
        ORDER BY time_updated DESC LIMIT 100;
        """
        return await runProcess("/usr/bin/sqlite3", ["-readonly", "-json", dbPath, sql])
    }

    private struct Row: Codable {
        let id: String
        let title: String
        let agent: String?
        let model: String?
        let time_updated: Double
    }

    static func parse(_ data: Data, now: Date) -> [OpencodeSession] {
        guard !data.isEmpty, let rows = try? JSONDecoder().decode([Row].self, from: data) else { return [] }
        return rows.map { row in
            let date = Date(timeIntervalSince1970: row.time_updated / 1000)
            return OpencodeSession(
                id: row.id,
                title: row.title,
                agent: row.agent,
                model: row.model.flatMap(modelName),
                lastActivity: date,
                isActive: now.timeIntervalSince(date) < 20
            )
        }
    }

    /// opencode stores the model as a JSON blob; pull out its `id`.
    static func modelName(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return json
        }
        return obj["id"] as? String
    }

    @discardableResult
    private static func runProcess(_ executable: String, _ args: [String]) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args
                let out = Pipe()
                process.standardOutput = out
                process.standardError = Pipe()
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? data : nil)
            }
        }
    }
}
