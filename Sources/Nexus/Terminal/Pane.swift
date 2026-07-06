import Foundation
import Observation

/// One terminal session: the shell running in a single pane. Owns the observable
/// UI-facing state (title, cwd, exit status) and, lazily, the persistent
/// `TerminalController` that holds the SwiftTerm view. Referenced from the
/// layout tree only by `id`.
@MainActor
@Observable
public final class Pane: Identifiable {
    public let id: UUID

    /// Title reported by the shell (OSC 0/2), shown in the tab and pane header.
    public var title: String = "Shell"

    /// Working directory reported by the shell (OSC 7). New splits inherit this.
    public var currentDirectory: String?

    /// True once the shell process exits; the view shows a restart affordance.
    public var hasExited: Bool = false
    public var exitCode: Int32?

    /// Directory to spawn the shell in. Set at creation (inherited from the
    /// pane that was split, or the user's home).
    @ObservationIgnored public let startDirectory: String?

    /// The persistent terminal view + shell, created on first display so the
    /// shell's lifetime is tied to this pane rather than to SwiftUI view churn.
    @ObservationIgnored private var _controller: TerminalController?

    /// A command to run once the shell is ready (e.g. `claude --resume <id>`).
    @ObservationIgnored public let pendingCommand: String?

    public init(id: UUID = UUID(), startDirectory: String? = nil, pendingCommand: String? = nil) {
        self.id = id
        self.startDirectory = startDirectory
        self.pendingCommand = pendingCommand
    }

    /// Get-or-create the terminal controller for this pane.
    func controller() -> TerminalController {
        if let controller = _controller { return controller }
        let controller = TerminalController(pane: self)
        _controller = controller
        return controller
    }

    /// The shell's live working directory: read from the process when possible
    /// (tracks `cd`), falling back to the OSC 7 report or the start directory.
    public func resolvedWorkingDirectory() -> String? {
        if let controller = _controller, let cwd = WorkingDirectory.of(pid: controller.shellPid) {
            return cwd
        }
        return currentDirectory ?? startDirectory
    }

    /// The PID of the shell process (0 if not yet started).
    public var shellPid: pid_t {
        _controller?.shellPid ?? 0
    }

    /// Terminate the shell when the pane is closed, so no orphan process lingers.
    func shutDown() {
        _controller?.terminate()
    }

    /// Re-spawn the shell after it exited (bound to the restart affordance).
    public func restart() {
        guard hasExited else { return }
        hasExited = false
        exitCode = nil
        _controller?.restart(directory: currentDirectory ?? startDirectory)
    }
}
