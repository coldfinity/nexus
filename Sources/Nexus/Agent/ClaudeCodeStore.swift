import Foundation
import Observation

/// Observable state for the Claude Code agent view. Claude Code has no local
/// server; instead it writes each session as a JSONL transcript under
/// `~/.claude/projects/<cwd-slug>/`. This maps the focused pane's directory to
/// that folder, lists the transcripts as sessions, and parses each for a title,
/// last prompt, model, and activity.
@MainActor
@Observable
public final class ClaudeCodeStore {
    public private(set) var sessions: [ClaudeSession] = []
    /// The project folder exists (Claude Code has been used in this directory).
    public private(set) var hasProject = false
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private var directory: String?
    /// Parsed metadata cached by (path, modification time) to avoid re-reading.
    @ObservationIgnored private var cache: [String: CacheEntry] = [:]
    @ObservationIgnored private let projectsRoot: URL

    public init(projectsRoot: URL = ClaudeCodeStore.defaultProjectsRoot) {
        self.projectsRoot = projectsRoot
    }

    public struct ClaudeSession: Identifiable, Equatable, Sendable {
        public let id: String            // session UUID (the file name)
        public let path: String
        public var title: String
        public var lastPrompt: String?
        public var model: String?
        public var lastActivity: Date
        /// The transcript was written to within the last few seconds.
        public var isActive: Bool
    }

    public nonisolated static let defaultProjectsRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)

    /// Claude Code slugs a directory by replacing `/` and `.` with `-`.
    public nonisolated static func slug(for directory: String) -> String {
        directory.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }

    // MARK: - Tracking

    /// The directory currently being reflected (a session resumes here).
    public var projectDirectory: String? { directory }

    public func update(directory newDirectory: String?) {
        directory = newDirectory
        reload()
    }

    private struct ScanResult: Sendable {
        var hasProject: Bool
        var sessions: [ClaudeSession]
        var cache: [String: CacheEntry]
    }
    struct CacheEntry: Sendable {
        let mtime: Date
        let session: ClaudeSession
    }

    public func reload() {
        guard let directory else {
            hasProject = false
            sessions = []
            return
        }
        let root = projectsRoot
        let existing = cache
        loadTask?.cancel()
        // Reading + parsing transcripts (which can be several MB) must not run
        // on the main thread, or it stutters the whole UI. Do it detached.
        loadTask = Task {
            let result = await Task.detached(priority: .utility) {
                Self.scan(root: root, directory: directory, cache: existing)
            }.value
            guard !Task.isCancelled else { return }
            hasProject = result.hasProject
            cache = result.cache
            sessions = result.sessions
            isLoading = false
        }
    }

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    nonisolated private static func scan(root: URL, directory: String, cache: [String: CacheEntry]) -> ScanResult {
        let dir = root.appendingPathComponent(slug(for: directory))
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return ScanResult(hasProject: false, sessions: [], cache: [:])
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let now = Date()
        var loaded: [ClaudeSession] = []
        var freshCache: [String: CacheEntry] = [:]

        for file in files where file.pathExtension == "jsonl" {
            let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let key = file.path

            var session: ClaudeSession
            if let cached = cache[key], cached.mtime == mtime {
                session = cached.session               // unchanged since last scan
            } else if let parsed = parse(file, mtime: mtime) {
                session = parsed
            } else {
                continue
            }
            session.isActive = now.timeIntervalSince(mtime) < 20
            loaded.append(session)
            freshCache[key] = CacheEntry(mtime: mtime, session: session)
        }

        return ScanResult(
            hasProject: true,
            sessions: loaded.sorted { $0.lastActivity > $1.lastActivity },
            cache: freshCache
        )
    }

    // MARK: - Actions

    /// The command that resumes this session (run in a new tab).
    public func resumeCommand(for session: ClaudeSession) -> String {
        "claude --resume \(session.id)"
    }

    /// Delete a session's transcript file. Destructive — removes its history.
    public func delete(_ session: ClaudeSession) {
        try? FileManager.default.removeItem(atPath: session.path)
        cache.removeValue(forKey: session.path)
        reload()
    }

    // MARK: - Parsing

    /// Extract the session's title, last prompt, and model by scanning the
    /// transcript from the end (the most recent values win). Only JSON-decodes
    /// the handful of lines that carry those markers, so large transcripts stay
    /// cheap.
    nonisolated private static func parse(_ file: URL, mtime: Date) -> ClaudeSession? {
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let id = file.deletingPathExtension().lastPathComponent

        var title: String?
        var lastPrompt: String?
        var model: String?

        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.reversed() {
            if title == nil, line.contains("\"ai-title\"") {
                title = decodeField(line, "aiTitle")
            }
            if lastPrompt == nil, line.contains("\"last-prompt\"") {
                lastPrompt = decodeField(line, "lastPrompt")
            }
            if model == nil, line.contains("\"model\":\"claude") {
                model = decodeField(line, "model")
            }
            if title != nil, lastPrompt != nil, model != nil { break }
        }

        return ClaudeSession(
            id: id,
            path: file.path,
            title: title ?? String(id.prefix(8)),
            lastPrompt: lastPrompt,
            model: model,
            lastActivity: mtime,
            isActive: false
        )
    }

    /// Pull a top-level string value out of a JSONL line by key.
    nonisolated private static func decodeField(_ line: Substring, _ key: String) -> String? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let direct = obj[key] as? String { return direct }
        // `model` lives inside the nested assistant `message` object.
        if let message = obj["message"] as? [String: Any], let nested = message[key] as? String {
            return nested
        }
        return nil
    }
}
