import XCTest
@testable import Nexus

final class GitGraphTests: XCTestCase {
    private func commit(_ hash: String, _ parents: [String]) -> RawCommit {
        RawCommit(hash: hash, parents: parents, shortHash: String(hash.prefix(7)), subject: hash, author: "t", relativeDate: "now", refs: [])
    }

    func testLinearHistoryStaysInOneLane() {
        let commits = [
            commit("c", ["b"]),
            commit("b", ["a"]),
            commit("a", [])
        ]
        let graph = GitGraph.layout(commits)
        XCTAssertEqual(graph.laneCount, 1)
        XCTAssertEqual(graph.commits.map { $0.lane }, [0, 0, 0])
        XCTAssertEqual(graph.commits.map { $0.row }, [0, 1, 2])
    }

    func testBranchAndMergeUsesTwoLanes() {
        // d merges b and c; both descend from a.
        let commits = [
            commit("d", ["b", "c"]),
            commit("b", ["a"]),
            commit("c", ["a"]),
            commit("a", [])
        ]
        let graph = GitGraph.layout(commits)
        XCTAssertGreaterThanOrEqual(graph.laneCount, 2)
        // The merge commit takes lane 0; its second parent opens a new lane.
        XCTAssertEqual(graph.byHash["d"]?.lane, 0)
        XCTAssertNotNil(graph.byHash["c"])
        // Converging back to `a` shouldn't leave phantom lanes beyond what's used.
        XCTAssertEqual(graph.commits.count, 4)
    }

    func testEveryCommitIsPlacedExactlyOnce() {
        let commits = [
            commit("e", ["d"]),
            commit("d", ["b", "c"]),
            commit("c", ["a"]),
            commit("b", ["a"]),
            commit("a", [])
        ]
        let graph = GitGraph.layout(commits)
        XCTAssertEqual(graph.commits.count, 5)
        XCTAssertEqual(Set(graph.byHash.keys), Set(["a", "b", "c", "d", "e"]))
        XCTAssertEqual(graph.commits.map { $0.row }, [0, 1, 2, 3, 4])
    }

    func testEmptyInput() {
        let graph = GitGraph.layout([])
        XCTAssertTrue(graph.commits.isEmpty)
        XCTAssertEqual(graph.laneCount, 1)
    }
}
