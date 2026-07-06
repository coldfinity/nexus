import SwiftUI

/// The left sidebar: current repo, a commit graph, branches, and a worktree
/// manager. Styled to the pro-tool dark chrome.
struct GitSidebarView: View {
    @Environment(\.palette) private var palette
    let gitStore: GitStore
    let workspace: Workspace

    @State private var showingAddWorktree = false
    @State private var selectedCommit: RawCommit?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(palette.hairline).frame(height: 1)

            if let error = gitStore.errorMessage {
                errorBanner(error)
            }

            if gitStore.isRepository {
                content
            } else {
                notARepo
            }
        }
        .frame(minWidth: 240, maxWidth: .infinity)
        .background(palette.chrome)
        .sheet(isPresented: $showingAddWorktree) {
            AddWorktreeSheet(gitStore: gitStore)
        }
        .sheet(item: $selectedCommit) { commit in
            CommitDetailView(commit: commit, gitStore: gitStore)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Icon(name: "point.3.filled.connected.trianglepath.dotted", size: 13)
                .foregroundStyle(palette.accent)
            HStack(spacing: 5) {
                Text(repoName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                if let branch = gitStore.currentBranch {
                    Icon(name: "chevron.right", size: 7, weight: .semibold)
                        .foregroundStyle(palette.textTertiary)
                    Text(branch)
                        .font(.nxMonoSmall)
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if gitStore.isLoading {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            }
            IconButton(system: "arrow.clockwise", help: "Refresh", action: gitStore.reload)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
    }

    private var repoName: String {
        gitStore.repoRoot.map { ($0 as NSString).lastPathComponent } ?? "Nexus"
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Icon(name: "exclamationmark.triangle.fill", size: 9)
            Text(message)
                .font(.nxMonoSmall)
                .lineLimit(2)
        }
        .foregroundStyle(palette.danger)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.danger.opacity(0.12))
    }

    private var notARepo: some View {
        VStack(spacing: 8) {
            Spacer()
            Icon(name: "folder.badge.questionmark", size: 22)
                .foregroundStyle(palette.textTertiary)
            Text("Not a git repository")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text("cd into a repo in the focused pane")
                .font(.nxMonoSmall)
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeaderRow(title: "Commits")
                CommitGraphView(graph: gitStore.graph, gitStore: gitStore) { commit in
                    selectedCommit = commit
                }
                .padding(.bottom, 2)

                SectionHeaderRow(title: "Branches")
                ForEach(gitStore.branches) { branch in
                    BranchRow(branch: branch) { gitStore.checkout(branch.name) }
                }

                SectionHeaderRow(title: "Worktrees") {
                    IconButton(system: "plus", help: "Add worktree") { showingAddWorktree = true }
                }
                ForEach(gitStore.worktrees) { worktree in
                    WorktreeRow(
                        worktree: worktree,
                        onOpen: { workspace.newTab(directory: worktree.path) },
                        onRemove: { gitStore.removeWorktree(worktree.path) }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Shared bits

/// A quiet icon button with hover feedback.
struct IconButton: View {
    @Environment(\.palette) private var palette
    let system: String
    var active: Bool = false
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Icon(name: system, size: 11, weight: .medium)
                .foregroundStyle(active ? palette.accent : (hovering ? palette.textPrimary : palette.textSecondary))
                .frame(width: 22, height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? palette.overlay : .clear))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

struct SectionHeaderRow<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    init(title: String, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title
        self.accessory = accessory
    }

    var body: some View {
        HStack {
            SectionLabel(title: title)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

private struct BranchRow: View {
    @Environment(\.palette) private var palette
    let branch: GitBranch
    let onCheckout: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(branch.isCurrent ? palette.accent : palette.textTertiary)
                .frame(width: 6, height: 6)
            Text(branch.name)
                .font(.nxMono)
                .foregroundStyle(branch.isCurrent ? palette.accent : palette.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if hovering && !branch.isCurrent {
                Text("checkout")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: NX.rowRadius).fill(hovering ? palette.overlay : .clear))
        .contentShape(Rectangle())
        .onTapGesture { if !branch.isCurrent { onCheckout() } }
        .onHover { hovering = $0 }
    }
}

private struct WorktreeRow: View {
    @Environment(\.palette) private var palette
    let worktree: GitWorktree
    let onOpen: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Icon(name: worktree.isCurrent ? "folder.fill" : "folder", size: 10)
                .foregroundStyle(worktree.isCurrent ? palette.accent : palette.textSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(worktree.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text(worktree.branch ?? (worktree.isBare ? "(bare)" : "(detached)"))
                    .font(.nxMonoSmall)
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if hovering {
                IconButton(system: "arrow.up.forward.square", help: "Open in new tab", action: onOpen)
                if !worktree.isCurrent && !worktree.isBare {
                    IconButton(system: "trash", help: "Remove worktree", action: onRemove)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: NX.rowRadius).fill(hovering ? palette.overlay : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - Add worktree

private struct AddWorktreeSheet: View {
    @Environment(\.palette) private var palette
    let gitStore: GitStore
    @Environment(\.dismiss) private var dismiss

    @State private var path = ""
    @State private var base = ""
    @State private var createBranch = false
    @State private var newBranch = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Worktree")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                labeledField("Path", text: $path, prompt: "/path/to/worktree")
                Toggle("Create new branch", isOn: $createBranch)
                    .toggleStyle(.switch)
                    .tint(palette.accent)
                if createBranch {
                    labeledField("New branch", text: $newBranch, prompt: "feature/x")
                    labeledField("From", text: $base, prompt: "branch or commit (optional)")
                } else {
                    labeledField("Branch or commit", text: $base, prompt: "optional")
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    gitStore.addWorktree(path: path, base: base, newBranch: createBranch ? newBranch : nil)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(path.isEmpty || (createBranch && newBranch.isEmpty))
            }
        }
        .padding(18)
        .frame(width: 400)
        .background(palette.surface)
    }

    private func labeledField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(palette.textTertiary)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(palette.textTertiary))
                .textFieldStyle(.roundedBorder)
                .font(.nxMono)
        }
    }
}
