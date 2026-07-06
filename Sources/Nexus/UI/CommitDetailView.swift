import SwiftUI
import AppKit

/// Detail sheet for a commit: full message, changed files with line stats, and
/// the colorized patch. Also offers commit-level actions.
struct CommitDetailView: View {
    @Environment(\.palette) private var palette
    let commit: RawCommit
    let gitStore: GitStore
    @Environment(\.dismiss) private var dismiss

    @State private var detail: CommitDetail?
    @State private var newBranch = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if let detail {
                body(for: detail)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 720, height: 620)
        .background(palette.surface)
        .task { detail = await gitStore.commitDetail(commit.hash) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(commit.shortHash)
                    .font(.nxMono)
                    .foregroundStyle(palette.accent)
                Spacer()
                Button("Copy SHA") { copy(commit.hash) }
                Button("Checkout") { gitStore.checkoutCommit(commit.hash); dismiss() }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            Text(commit.subject)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .textSelection(.enabled)

            Text("\(commit.author) · \(commit.relativeDate)")
                .font(.system(size: 11))
                .foregroundStyle(palette.textSecondary)

            HStack(spacing: 6) {
                TextField("new-branch-name", text: $newBranch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Branch here") {
                    gitStore.createBranch(newBranch, at: commit.hash)
                    dismiss()
                }
                .disabled(newBranch.isEmpty)
            }
        }
        .padding(12)
    }

    private func body(for detail: CommitDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !detail.body.isEmpty, detail.body != commit.subject {
                    Text(detail.body)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    Divider()
                }

                filesSummary(detail.files)
                Divider()
                DiffView(patch: detail.patch)
            }
        }
    }

    private func filesSummary(_ files: [ChangedFile]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(files.count) file\(files.count == 1 ? "" : "s") changed")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            ForEach(files) { file in
                HStack(spacing: 8) {
                    Text(file.path)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if let added = file.added { Text("+\(added)").foregroundStyle(.green) }
                    if let deleted = file.deleted { Text("-\(deleted)").foregroundStyle(.red) }
                }
                .font(.system(size: 10, design: .monospaced))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

/// Renders a unified diff with per-line coloring.
struct DiffView: View {
    let patch: String

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(patch.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : String(line))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(color(for: line))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(for: line))
            }
        }
        .textSelection(.enabled)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func color(for line: Substring) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red }
        if line.hasPrefix("@@") { return .cyan }
        if line.hasPrefix("diff ") || line.hasPrefix("index ") { return .secondary }
        return .primary
    }

    private func background(for line: Substring) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green.opacity(0.08) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red.opacity(0.08) }
        return .clear
    }
}
