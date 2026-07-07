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
                AgentPlaceholder(icon: "terminal", title: "opencode isn't set up yet",
                                 detail: "Run `opencode` in a project to get started.")
            } else if store.sessions.isEmpty {
                AgentPlaceholder(icon: "bubble.left", title: "No sessions here",
                                 detail: "Run `opencode` in this folder to start one.")
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
        AgentHeader(
            icon: "terminal",
            folder: store.projectDirectory,
            count: store.sessions.count,
            isLoading: store.isLoading,
            onRefresh: { store.reload() }
        )
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
                    title: "No sessions here",
                    detail: "Run `claude` in this folder to start one."
                )
            } else if store.sessions.isEmpty {
                AgentPlaceholder(icon: "bubble.left", title: "No sessions here",
                                 detail: "Run `claude` in this folder to start one.")
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
        AgentHeader(
            icon: "sparkles",
            folder: store.projectDirectory,
            count: store.sessions.count,
            isLoading: false,
            onRefresh: { store.reload() }
        )
    }
}

/// Shared agent header: the scoped folder name + a session count, with the
/// provider already named by the toggle above.
private struct AgentHeader: View {
    @Environment(\.palette) private var palette
    let icon: String
    let folder: String?
    let count: Int
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Icon(name: icon, size: 12).foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(folder.map { ($0 as NSString).lastPathComponent } ?? "—")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count) session\(count == 1 ? "" : "s")")
                        .font(.nxMonoSmall)
                        .foregroundStyle(palette.textTertiary)
                }
            }
            Spacer(minLength: 4)
            if isLoading { ProgressView().controlSize(.small).scaleEffect(0.7) }
            IconButton(system: "arrow.clockwise", help: "Refresh", action: onRefresh)
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
                    // Live sessions get a soft halo so "running" reads at a glance.
                    .shadow(color: isActive ? Color.green.opacity(0.9) : .clear, radius: 3.5)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isActive ? palette.textPrimary : palette.textPrimary.opacity(0.92))
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
