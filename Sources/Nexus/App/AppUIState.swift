import Observation

/// Window-level UI state that isn't part of the terminal workspace or config —
/// e.g. whether the git sidebar is showing.
@MainActor
@Observable
public final class AppUIState {
    public var showGitSidebar: Bool = true

    public init() {}

    public func toggleGitSidebar() {
        showGitSidebar.toggle()
    }
}
