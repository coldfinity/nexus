import SwiftUI

/// The row of tabs across the top of the window, plus the sidebar toggle and a
/// new-tab button. Styled to the "pro-tool dark" chrome.
struct TabBarView: View {
    @Environment(\.palette) private var palette
    let workspace: Workspace
    let sidebarVisible: Bool
    let onToggleSidebar: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            IconButton(system: "sidebar.left", active: sidebarVisible, help: "Toggle git sidebar", action: onToggleSidebar)

            Rectangle().fill(palette.hairline).frame(width: 1, height: 16).padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(workspace.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabChip(
                            title: title(for: tab, index: index),
                            isSelected: tab.id == workspace.selectedTabID,
                            onSelect: { workspace.selectTab(tab.id) },
                            onClose: { closeTab(tab) }
                        )
                    }
                }
            }

            IconButton(system: "plus", active: false, help: "New tab", action: workspace.newTab)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
        .background(palette.chromeRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.hairline).frame(height: 1)
        }
    }

    private func title(for tab: TerminalTab, index: Int) -> String {
        if let pane = workspace.pane(tab.focusedPaneID), !pane.title.isEmpty {
            return pane.title
        }
        return "Tab \(index + 1)"
    }

    private func closeTab(_ tab: TerminalTab) {
        for paneID in tab.root.paneIDs {
            workspace.closePane(paneID)
        }
    }
}

private struct TabChip: View {
    @Environment(\.palette) private var palette
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Group {
                if hovering {
                    Button(action: onClose) {
                        Icon(name: "xmark", size: 8, weight: .bold)
                            .foregroundStyle(palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close tab")
                } else {
                    // Reserve the space so the label doesn't shift on hover.
                    Color.clear.frame(width: 8)
                }
            }
        }
        .frame(maxWidth: 180)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: NX.rowRadius)
                .fill(isSelected ? palette.overlayStrong : (hovering ? palette.overlay : .clear))
        )
        .overlay(alignment: .bottom) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1)
                    .fill(palette.accent)
                    .frame(height: 2)
                    .padding(.horizontal, 10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }
}
