import SwiftUI
import AppKit

/// The window's content: an optional sidebar (git or agent) alongside the tab
/// bar and the selected tab's pane tree.
struct RootView: View {
    let workspace: Workspace
    let configStore: ConfigStore
    let gitStore: GitStore
    let agentStore: AgentStore
    let claudeStore: ClaudeCodeStore
    let uiState: AppUIState

    /// Live width while dragging; nil otherwise (falls back to the saved config).
    @State private var liveWidth: CGFloat?
    @State private var dragBaseWidth: CGFloat?

    private var palette: Palette {
        Palette.from(theme: configStore.config.theme, opacity: configStore.config.window.opacity)
    }

    private var sidebarWidth: CGFloat {
        liveWidth ?? CGFloat(configStore.config.sidebarWidth)
    }

    /// A 1px hairline with a wider invisible strip for dragging the sidebar width.
    /// The new width is persisted to the config once the drag ends.
    private var sidebarResizeHandle: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(width: 1)
            .overlay {
                Color.clear
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let base = dragBaseWidth ?? CGFloat(configStore.config.sidebarWidth)
                                if dragBaseWidth == nil { dragBaseWidth = base }
                                liveWidth = min(max(base + value.translation.width, 240), 680)
                            }
                            .onEnded { _ in
                                if let width = liveWidth { configStore.setSidebarWidth(Double(width)) }
                                liveWidth = nil
                                dragBaseWidth = nil
                            }
                    )
            }
    }

    var body: some View {
        // The window itself is made translucent + blurred by WindowConfigurator;
        // the chrome and terminal panes paint their own (translucent) surfaces on
        // top, so the blurred desktop shows through them.
        Group {
            HStack(spacing: 0) {
                if uiState.sidebarVisible {
                    SidebarPanelView(
                        uiState: uiState,
                        gitStore: gitStore,
                        agentStore: agentStore,
                        claudeStore: claudeStore,
                        workspace: workspace
                    )
                        .frame(width: sidebarWidth)
                    sidebarResizeHandle
                }

                terminalArea
            }
        }
        .frame(minWidth: 760, minHeight: 400)
        .environment(\.palette, palette)
        .task { await trackWorkingDirectory() }
    }

    private var terminalArea: some View {
        ZStack {
            VStack(spacing: 0) {
                if let error = configStore.loadError {
                    ConfigErrorBanner(message: error)
                }

                TabBarView(
                    workspace: workspace,
                    sidebarVisible: uiState.sidebarVisible,
                    onToggleSidebar: uiState.toggleSidebar
                )

                if let tab = workspace.selectedTab {
                    LayoutTreeView(
                        node: tab.root,
                        tab: tab,
                        workspace: workspace,
                        config: configStore.config
                    )
                    .padding(CGFloat(configStore.config.padding))
                } else {
                    Color.clear
                }
            }
        }
        .background(WindowConfigurator(
            window: configStore.config.window,
            isDark: palette.isDark,
            backgroundColor: HexColor.nsColor(configStore.config.theme.background, fallback: .black)
        ))
    }

    /// Keep the sidebar pointed at the focused pane's live working directory.
    private func trackWorkingDirectory() async {
        while !Task.isCancelled {
            let cwd = workspace.focusedPane?.resolvedWorkingDirectory()
            gitStore.update(directory: cwd)
            agentStore.update(directory: cwd)
            claudeStore.update(directory: cwd)
            try? await Task.sleep(for: .seconds(2))
        }
    }
}

/// A two-tab sidebar panel that switches between the git and agent views.
private struct SidebarPanelView: View {
    @Environment(\.palette) private var palette
    let uiState: AppUIState
    let gitStore: GitStore
    let agentStore: AgentStore
    let claudeStore: ClaudeCodeStore
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            SegmentedControl(
                segments: SidebarTab.allCases.map { ($0, $0.rawValue.capitalized) },
                selection: uiState.currentSidebarTab,
                onSelect: { uiState.currentSidebarTab = $0 }
            )
            Rectangle().fill(palette.hairline).frame(height: 1)

            switch uiState.currentSidebarTab {
            case .git:
                GitSidebarView(gitStore: gitStore, workspace: workspace)
            case .agent:
                AgentSidebarView(
                    provider: uiState.agentProvider,
                    onSelectProvider: { uiState.agentProvider = $0 },
                    agentStore: agentStore,
                    claudeStore: claudeStore,
                    workspace: workspace
                )
            }
        }
    }
}

/// A reusable segmented control themed to the chrome.
struct SegmentedControl<Value: Hashable>: View {
    @Environment(\.palette) private var palette
    let segments: [(Value, String)]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments, id: \.0) { value, label in
                let isSelected = value == selection
                Button { onSelect(value) } label: {
                    Text(label)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? palette.textPrimary : palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: NX.rowRadius)
                                .fill(isSelected ? palette.overlayStrong : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 34)
        .background(palette.chromeRaised)
    }
}

private struct ConfigErrorBanner: View {
    @Environment(\.palette) private var palette
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Icon(name: "exclamationmark.triangle.fill", size: 10)
            Text(message)
                .font(.nxMonoSmall)
                .lineLimit(2)
            Spacer()
        }
        .foregroundStyle(palette.danger)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.danger.opacity(0.12))
        .overlay(alignment: .bottom) { Rectangle().fill(palette.hairline).frame(height: 1) }
    }
}
