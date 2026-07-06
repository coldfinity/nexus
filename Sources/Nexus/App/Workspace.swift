import Foundation
import Observation

/// A single tab: a layout tree of panes plus which pane is focused.
@MainActor
@Observable
public final class TerminalTab: Identifiable {
    public let id: UUID
    public var root: LayoutNode
    public var focusedPaneID: UUID

    public init(id: UUID = UUID(), rootPaneID: UUID) {
        self.id = id
        self.root = .leaf(rootPaneID)
        self.focusedPaneID = rootPaneID
    }
}

/// Top-level window state: the tabs, the selected tab, and the registry mapping
/// pane IDs (used by the layout trees) to their live `Pane` sessions.
@MainActor
@Observable
public final class Workspace {
    public private(set) var tabs: [TerminalTab] = []
    public var selectedTabID: UUID
    public private(set) var panes: [UUID: Pane] = [:]

    /// Called when the last pane closes, so the app can close the window.
    @ObservationIgnored public var onEmpty: (() -> Void)?

    public init() {
        let pane = Pane(startDirectory: Self.homeDirectory)
        let tab = TerminalTab(rootPaneID: pane.id)
        selectedTabID = tab.id
        tabs = [tab]
        panes = [pane.id: pane]
    }

    public static var homeDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    public var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID }
    }

    public func pane(_ id: UUID) -> Pane? { panes[id] }

    public var focusedPane: Pane? {
        guard let id = selectedTab?.focusedPaneID else { return nil }
        return panes[id]
    }

    // MARK: - Tabs

    public func newTab() {
        newTab(directory: focusedPane?.resolvedWorkingDirectory() ?? Self.homeDirectory)
    }

    public func newTab(directory: String) {
        let pane = Pane(startDirectory: directory)
        let tab = TerminalTab(rootPaneID: pane.id)
        panes[pane.id] = pane
        tabs.append(tab)
        selectedTabID = tab.id
    }

    public func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
    }

    public func selectTab(index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedTabID = tabs[index].id
    }

    // MARK: - Splits

    public func splitFocused(_ direction: SplitDirection) {
        guard let tab = selectedTab else { return }
        let inherited = panes[tab.focusedPaneID]?.currentDirectory ?? Self.homeDirectory
        let newPane = Pane(startDirectory: inherited)
        panes[newPane.id] = newPane
        tab.root = tab.root.splitting(
            paneID: tab.focusedPaneID,
            direction: direction,
            newPaneID: newPane.id
        )
        tab.focusedPaneID = newPane.id
    }

    // MARK: - Closing

    public func closeFocused() {
        guard let tab = selectedTab else { return }
        closePane(tab.focusedPaneID)
    }

    public func closePane(_ paneID: UUID) {
        guard let tab = tabs.first(where: { $0.root.contains(paneID) }) else { return }
        panes[paneID]?.shutDown()
        panes.removeValue(forKey: paneID)

        if let newRoot = tab.root.removing(paneID: paneID) {
            tab.root = newRoot
            if !newRoot.contains(tab.focusedPaneID) {
                tab.focusedPaneID = newRoot.firstPaneID ?? tab.focusedPaneID
            }
        } else {
            // Last pane in the tab closed → drop the tab.
            removeTab(tab)
        }
    }

    private func removeTab(_ tab: TerminalTab) {
        let wasSelected = selectedTabID == tab.id
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty {
            // Closing the final pane closes the whole terminal.
            onEmpty?()
        } else if wasSelected {
            selectedTabID = tabs.last!.id
        }
    }

    // MARK: - Focus

    public func focusPane(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.root.contains(id) }) else { return }
        selectedTabID = tab.id
        tab.focusedPaneID = id
    }
}
