import SwiftUI

/// The Agents tab: a segmented toggle between the two providers (opencode and
/// Claude Code), each with its own detection and session list.
struct AgentSidebarView: View {
    @Environment(\.palette) private var palette
    let provider: AgentProvider
    let onSelectProvider: (AgentProvider) -> Void
    let agentStore: AgentStore
    let claudeStore: ClaudeCodeStore
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            SegmentedControl(
                segments: AgentProvider.allCases.map { ($0, $0.rawValue) },
                selection: provider,
                onSelect: onSelectProvider
            )
            Rectangle().fill(palette.hairline).frame(height: 1)

            switch provider {
            case .opencode:
                OpencodeContent(store: agentStore, workspace: workspace)
            case .claudeCode:
                ClaudeCodeContent(store: claudeStore, workspace: workspace)
            }
        }
        .frame(minWidth: 240, maxWidth: .infinity)
        .background(palette.chrome)
    }
}

// MARK: - Shared placeholder

private struct AgentPlaceholder: View {
    @Environment(\.palette) private var palette
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Icon(name: icon, size: 22).foregroundStyle(palette.textTertiary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text(detail)
                .font(.nxMonoSmall)
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - opencode

private struct OpencodeContent: View {
    @Environment(\.palette) private var palette
    let store: AgentStore
    let workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !store.hasStorage {
                AgentPlaceholder(icon: "terminal", title: "opencode not found",
                                 detail: "Run `opencode` to create your first session.")
            } else if store.sessions.isEmpty {
                AgentPlaceholder(icon: "bubble.left", title: "No sessions",
                                 detail: "No opencode sessions in this directory yet.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeaderRow(title: "Sessions")
                        ForEach(store.sessions) { session in
                            AgentSessionRow(
                                title: session.title,
                                subtitle: session.agent,
                                meta: session.model,
                                lastActivity: session.lastActivity,
                                isActive: session.isActive,
                                onResume: {
                                    workspace.newTab(
                                        directory: store.projectDirectory ?? Workspace.homeDirectory,
                                        command: store.resumeCommand(for: session)
                                    )
                                },
                                onDelete: { store.delete(session) }
                            )
                        }
                    }
                    .padding(.horizontal, 6).padding(.bottom, 14)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Icon(name: "terminal", size: 12).foregroundStyle(palette.accent)
            Text("opencode")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 4)
            if store.isLoading { ProgressView().controlSize(.small).scaleEffect(0.7) }
            IconButton(system: "arrow.clockwise", help: "Refresh") { store.reload() }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
    }
}

// MARK: - Claude Code

private struct ClaudeCodeContent: View {
    @Environment(\.palette) private var palette
    let store: ClaudeCodeStore
    let workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !store.hasProject {
                AgentPlaceholder(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "No Claude Code sessions",
                    detail: "Run `claude` in this directory to start one."
                )
            } else if store.sessions.isEmpty {
                AgentPlaceholder(icon: "bubble.left", title: "No sessions", detail: "Nothing recorded here yet.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeaderRow(title: "Sessions")
                        ForEach(store.sessions) { session in
                            AgentSessionRow(
                                title: session.title,
                                subtitle: session.lastPrompt,
                                meta: session.model,
                                lastActivity: session.lastActivity,
                                isActive: session.isActive,
                                onResume: {
                                    workspace.newTab(
                                        directory: store.projectDirectory ?? Workspace.homeDirectory,
                                        command: store.resumeCommand(for: session)
                                    )
                                },
                                onDelete: { store.delete(session) }
                            )
                        }
                    }
                    .padding(.horizontal, 6).padding(.bottom, 14)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Icon(name: "sparkles", size: 12).foregroundStyle(palette.accent)
            Text("Claude Code")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 4)
            IconButton(system: "arrow.clockwise", help: "Refresh") { store.reload() }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
    }
}

/// A unified session row used by both agents: title, an optional subtitle
/// (last prompt / agent), a meta line (model · time), an active dot, and
/// resume/delete actions. Double-click or the ↗ button resumes it.
private struct AgentSessionRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let subtitle: String?
    let meta: String?
    let lastActivity: Date
    let isActive: Bool
    let onResume: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Circle()
                    .fill(isActive ? Color.green : palette.textTertiary)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if hovering {
                    IconButton(system: "arrow.up.forward.square", help: "Resume in new tab", action: onResume)
                    IconButton(system: "trash", help: "Delete session") { confirmingDelete = true }
                }
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 13)
            }

            HStack(spacing: 6) {
                if let meta, !meta.isEmpty {
                    Text(meta).font(.nxMonoSmall).foregroundStyle(palette.textTertiary).lineLimit(1)
                    Text("·").foregroundStyle(palette.textTertiary)
                }
                Text(Self.relative.localizedString(for: lastActivity, relativeTo: Date()))
                    .font(.system(size: 9))
                    .foregroundStyle(palette.textTertiary)
                Spacer(minLength: 0)
            }
            .padding(.leading, 13)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: NX.rowRadius).fill(hovering ? palette.overlay : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2, perform: onResume)
        .confirmationDialog("Delete this session? This removes its history permanently.",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
