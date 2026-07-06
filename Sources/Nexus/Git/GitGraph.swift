import Foundation

/// A commit as parsed from `git log`, before graph placement.
public struct RawCommit: Equatable, Identifiable, Sendable {
    public var id: String { hash }

    public let hash: String
    public let parents: [String]
    public let shortHash: String
    public let subject: String
    public let author: String
    public let relativeDate: String
    /// Ref names decorating this commit (branch/tag names), if any.
    public let refs: [String]

    public init(
        hash: String, parents: [String], shortHash: String, subject: String, author: String,
        relativeDate: String, refs: [String]
    ) {
        self.hash = hash
        self.parents = parents
        self.shortHash = shortHash
        self.subject = subject
        self.author = author
        self.relativeDate = relativeDate
        self.refs = refs
    }
}

/// A commit placed into the graph: which row (top-to-bottom) and lane (column).
public struct GraphCommit: Equatable, Identifiable, Sendable {
    public let commit: RawCommit
    public let row: Int
    public let lane: Int
    public var id: String { commit.hash }
}

/// The result of laying commits into lanes.
public struct CommitGraph: Equatable, Sendable {
    public let commits: [GraphCommit]
    public let laneCount: Int
    /// hash → its placed commit, for drawing parent edges.
    public let byHash: [String: GraphCommit]

    public static let empty = CommitGraph(commits: [], laneCount: 0, byHash: [:])
}

/// Assigns each commit (in the order given, newest first) to a lane using the
/// standard "active lanes" algorithm, so branches and merges render as a graph.
///
/// Pure and deterministic — unit tested independently of any `git` invocation.
public enum GitGraph {
    public static func layout(_ commits: [RawCommit]) -> CommitGraph {
        // Each active lane tracks the hash of the commit expected next in it.
        var activeLanes: [String?] = []
        var placed: [GraphCommit] = []
        placed.reserveCapacity(commits.count)

        func firstFreeLane() -> Int {
            if let idx = activeLanes.firstIndex(where: { $0 == nil }) { return idx }
            activeLanes.append(nil)
            return activeLanes.count - 1
        }

        for (row, commit) in commits.enumerated() {
            // The lane awaiting this commit, or a fresh lane for a branch tip.
            let lane: Int
            if let existing = activeLanes.firstIndex(where: { $0 == commit.hash }) {
                lane = existing
            } else {
                lane = firstFreeLane()
            }

            placed.append(GraphCommit(commit: commit, row: row, lane: lane))

            // Any other lanes that also awaited this commit (converging merges)
            // are satisfied here; free them so they don't linger.
            for i in activeLanes.indices where i != lane && activeLanes[i] == commit.hash {
                activeLanes[i] = nil
            }

            if commit.parents.isEmpty {
                activeLanes[lane] = nil
            } else {
                activeLanes[lane] = commit.parents[0]
                for extraParent in commit.parents.dropFirst() {
                    // Reuse a lane already awaiting this parent, else a free one.
                    if activeLanes.contains(where: { $0 == extraParent }) { continue }
                    activeLanes[firstFreeLane()] = extraParent
                }
            }
        }

        let laneCount = max(placed.map { $0.lane }.max().map { $0 + 1 } ?? 0, 1)
        let byHash = Dictionary(uniqueKeysWithValues: placed.map { ($0.commit.hash, $0) })
        return CommitGraph(commits: placed, laneCount: laneCount, byHash: byHash)
    }
}
