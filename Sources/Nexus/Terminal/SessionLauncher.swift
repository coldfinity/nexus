import Foundation
import SwiftTerm

/// Spawns the user's login shell inside a SwiftTerm view's pseudo-terminal,
/// starting in the requested working directory when one is given.
enum SessionLauncher {
    static var userShell: String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    static func environment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        return env.map { "\($0.key)=\($0.value)" }
    }

    @MainActor
    static func start(in view: LocalProcessTerminalView, directory: String?) {
        let shell = userShell
        // argv[0] starting with '-' marks a login shell.
        let loginName = "-" + (shell as NSString).lastPathComponent
        let cwd = (directory?.isEmpty == false) ? directory : nil
        view.startProcess(
            executable: shell,
            args: ["-l"],
            environment: environment(),
            execName: loginName,
            currentDirectory: cwd
        )
    }
}
