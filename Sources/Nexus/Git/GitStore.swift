import Foundation
import Observation

/// Observable git state for the sidebar. Points at the repository containing a
/// working directory (the focused pane's cwd), loads the commit graph, branches,
/// and worktrees, and performs mutating actions.
@MainActor
@Observable
public final class GitStore {
    public private(set) var repoRoot: String?
    public private(set) var currentBranch: String?
    public private(set) var graph: CommitGraph = .empty
    public private(set) var branches: [GitBranch] = []
    public private(set) var worktrees: [GitWorktree] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    /// The directory the sidebar is currently reflecting.
    @ObservationIgnored private var directory: String?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public var isRepository: Bool { repoRoot != nil }

    public init() {}

    /// Point the sidebar at a new working directory. No-op if unchanged.
    public func update(directory newDirectory: String?) {
        guard newDirectory != directory else { return }
        directory = newDirectory
        reload()
    }

    public func reload() {
        loadTask?.cancel()
        guard let directory else {
            clear()
            return
        }
        isLoading = true
        loadTask = Task { await load(directory) }
    }

    private func load(_ directory: String) async {
        guard let root = await GitProcess.topLevel(of: directory) else {
            if !Task.isCancelled { clear() }
            return
        }

        async let branchName = GitProcess.currentBranch(in: root)
        async let commits = GitProcess.commits(in: root)
        async let branchList = GitProcess.branches(in: root)
        async let trees = GitProcess.worktrees(in: root, current: directory)

        let loadedGraph = GitGraph.layout(await commits)
        let loadedBranch = await branchName
        let loadedBranches = await branchList
        let loadedTrees = await trees

        if Task.isCancelled { return }
        repoRoot = root
        currentBranch = loadedBranch
        graph = loadedGraph
        branches = loadedBranches
        worktrees = loadedTrees
        errorMessage = nil
        isLoading = false
    }

    private func clear() {
        repoRoot = nil
        currentBranch = nil
        graph = .empty
        branches = []
        worktrees = []
        isLoading = false
        errorMessage = nil
    }

    // MARK: - Actions

    public func checkout(_ branch: String) {
        runAction(["checkout", branch])
    }

    /// Load the detail (message, changed files, patch) for a commit.
    public func commitDetail(_ hash: String) async -> CommitDetail? {
        guard let root = repoRoot else { return nil }
        return await GitProcess.commitDetail(hash, in: root)
    }

    /// Check out a commit (detached HEAD).
    public func checkoutCommit(_ hash: String) {
        runAction(["checkout", hash])
    }

    /// Create a new branch at `hash` and switch to it.
    public func createBranch(_ name: String, at hash: String) {
        runAction(["checkout", "-b", name, hash])
    }

    public func removeWorktree(_ path: String) {
        runAction(["worktree", "remove", path])
    }

    /// Add a worktree at `path`. When `newBranch` is set, create that branch;
    /// otherwise check out `base` (a branch or commit) into the new worktree.
    public func addWorktree(path: String, base: String, newBranch: String?) {
        var args = ["worktree", "add"]
        if let newBranch, !newBranch.isEmpty {
            args += ["-b", newBranch, path]
            if !base.isEmpty { args.append(base) }
        } else {
            args.append(path)
            if !base.isEmpty { args.append(base) }
        }
        runAction(args)
    }

    private func runAction(_ args: [String]) {
        guard let root = repoRoot else { return }
        Task {
            let result = await GitProcess.run(args, in: root)
            if !result.ok {
                errorMessage = result.stderr
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: "\n").first.map(String.init) ?? "git error"
            } else {
                errorMessage = nil
            }
            reload()
        }
    }
}
