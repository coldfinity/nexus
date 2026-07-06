import Foundation

/// Runs `git` as a subprocess off the main thread and parses its output into the
/// git models. Read-only queries and mutating actions both go through `run`.
enum GitProcess {
    struct Output: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
        var ok: Bool { status == 0 }
    }

    /// ASCII unit / record separators, used so fields and records can contain
    /// spaces and newlines without ambiguity.
    static let unit = "\u{1f}"
    static let record = "\u{1e}"

    static func run(_ args: [String], in directory: String) async -> Output {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["git"] + args
                process.currentDirectoryURL = URL(fileURLWithPath: directory)

                let out = Pipe()
                let err = Pipe()
                process.standardOutput = out
                process.standardError = err

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: Output(status: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }

                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                continuation.resume(returning: Output(
                    status: process.terminationStatus,
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self)
                ))
            }
        }
    }

    // MARK: - Queries

    /// The repository root containing `directory`, or nil if not in a repo.
    static func topLevel(of directory: String) async -> String? {
        let result = await run(["rev-parse", "--show-toplevel"], in: directory)
        guard result.ok else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    static func currentBranch(in root: String) async -> String? {
        let result = await run(["rev-parse", "--abbrev-ref", "HEAD"], in: root)
        guard result.ok else { return nil }
        let branch = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch.isEmpty ? nil : branch
    }

    static func commits(in root: String, limit: Int = 200) async -> [RawCommit] {
        let format = ["%H", "%P", "%h", "%s", "%an", "%ar", "%D"].joined(separator: unit) + record
        let result = await run([
            "log", "--no-color", "--all", "--topo-order",
            "-n", "\(limit)", "--pretty=format:\(format)"
        ], in: root)
        guard result.ok else { return [] }

        return result.stdout
            .components(separatedBy: record)
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                let fields = line.components(separatedBy: unit)
                guard fields.count >= 7 else { return nil }
                let parents = fields[1].split(separator: " ").map(String.init)
                let refs = fields[6]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                return RawCommit(
                    hash: fields[0],
                    parents: parents,
                    shortHash: fields[2],
                    subject: fields[3],
                    author: fields[4],
                    relativeDate: fields[5],
                    refs: refs
                )
            }
    }

    static func branches(in root: String) async -> [GitBranch] {
        let format = "%(refname:short)\(unit)%(HEAD)"
        let result = await run(["for-each-ref", "--format=\(format)", "refs/heads"], in: root)
        guard result.ok else { return [] }
        return result.stdout
            .split(separator: "\n")
            .compactMap { line in
                let fields = line.components(separatedBy: unit)
                guard fields.count >= 2, !fields[0].isEmpty else { return nil }
                return GitBranch(name: fields[0], isCurrent: fields[1] == "*")
            }
    }

    static func commitDetail(_ hash: String, in root: String) async -> CommitDetail? {
        async let bodyOut = run(["show", "-s", "--format=%B", hash], in: root)
        async let filesOut = run(["show", "--numstat", "--format=", "--no-color", hash], in: root)
        async let patchOut = run(["show", "--format=", "--no-color", hash], in: root)

        let body = await bodyOut
        guard body.ok else { return nil }

        let files = (await filesOut).stdout
            .split(separator: "\n")
            .compactMap { line -> ChangedFile? in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 3 else { return nil }
                return ChangedFile(
                    path: parts[2],
                    added: Int(parts[0]),
                    deleted: Int(parts[1])
                )
            }

        return CommitDetail(
            hash: hash,
            body: body.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            files: files,
            patch: (await patchOut).stdout
        )
    }

    static func worktrees(in root: String, current directory: String) async -> [GitWorktree] {
        let result = await run(["worktree", "list", "--porcelain"], in: root)
        guard result.ok else { return [] }

        var trees: [GitWorktree] = []
        var path: String?
        var branch: String?
        var bare = false
        var detached = false

        func flush() {
            guard let path else { return }
            let isCurrent = directory == path || directory.hasPrefix(path + "/")
            trees.append(GitWorktree(path: path, branch: branch, isBare: bare, isDetached: detached, isCurrent: isCurrent))
        }

        for line in result.stdout.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("worktree ") {
                flush()
                path = String(line.dropFirst("worktree ".count))
                branch = nil; bare = false; detached = false
            } else if line.hasPrefix("branch ") {
                branch = String(line.dropFirst("branch ".count))
                    .replacingOccurrences(of: "refs/heads/", with: "")
            } else if line == "bare" {
                bare = true
            } else if line == "detached" {
                detached = true
            }
        }
        flush()
        return trees
    }
}
