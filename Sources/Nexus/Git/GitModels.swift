import Foundation

public struct GitBranch: Equatable, Identifiable, Sendable {
    public let name: String
    public let isCurrent: Bool
    public var id: String { name }
}

public struct ChangedFile: Equatable, Identifiable, Sendable {
    public let path: String
    public let added: Int?   // nil for binary files
    public let deleted: Int?
    public var id: String { path }
}

/// The full detail of a single commit, loaded on demand when selected.
public struct CommitDetail: Equatable, Sendable {
    public let hash: String
    public let body: String
    public let files: [ChangedFile]
    public let patch: String
}

public struct GitWorktree: Equatable, Identifiable, Sendable {
    public let path: String
    public let branch: String?
    public let isBare: Bool
    public let isDetached: Bool
    /// True for the worktree that contains the currently active directory.
    public let isCurrent: Bool
    public var id: String { path }

    public var displayName: String {
        (path as NSString).lastPathComponent
    }
}
