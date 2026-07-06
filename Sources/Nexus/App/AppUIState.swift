import Observation

/// Which panel is currently shown inside the sidebar.
public enum SidebarTab: String, CaseIterable {
    case git
    case agent
}

/// Which agent provider the Agents tab is showing.
public enum AgentProvider: String, CaseIterable {
    case opencode = "opencode"
    case claudeCode = "Claude Code"
}

/// Window-level UI state that isn't part of the terminal workspace or config —
/// e.g. whether the sidebar is showing and which tab is selected.
@MainActor
@Observable
public final class AppUIState {
    public var sidebarVisible: Bool = true
    public var currentSidebarTab: SidebarTab = .git
    public var agentProvider: AgentProvider = .claudeCode

    public init() {}

    public func toggleSidebar() {
        sidebarVisible.toggle()
    }
}
