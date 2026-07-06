import SwiftUI
import AppKit

/// Renders a `CommitGraph`: a lane column drawn with a `Canvas` (nodes + parent
/// edges) beside aligned commit rows.
struct CommitGraphView: View {
    @Environment(\.palette) private var palette
    let graph: CommitGraph
    let gitStore: GitStore
    let onSelect: (RawCommit) -> Void

    private let rowHeight: CGFloat = 44
    private let laneWidth: CGFloat = 13
    private let nodeRadius: CGFloat = 3.5

    var body: some View {
        if graph.commits.isEmpty {
            Text("No commits")
                .font(.nxMonoSmall)
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        } else {
            HStack(alignment: .top, spacing: 4) {
                graphCanvas
                    .frame(width: CGFloat(graph.laneCount) * laneWidth, height: totalHeight)
                commitRows
            }
            .padding(.leading, 8)
        }
    }

    private var totalHeight: CGFloat {
        CGFloat(graph.commits.count) * rowHeight
    }

    private func laneX(_ lane: Int) -> CGFloat { CGFloat(lane) * laneWidth + laneWidth / 2 }
    private func rowY(_ row: Int) -> CGFloat { CGFloat(row) * rowHeight + rowHeight / 2 }
    private func color(_ lane: Int) -> Color { palette.lanes[lane % palette.lanes.count] }

    private var graphCanvas: some View {
        Canvas { context, _ in
            // Parent edges first, so nodes sit on top.
            for commit in graph.commits {
                let start = CGPoint(x: laneX(commit.lane), y: rowY(commit.row))
                for parentHash in commit.commit.parents {
                    var path = Path()
                    path.move(to: start)
                    if let parent = graph.byHash[parentHash] {
                        let end = CGPoint(x: laneX(parent.lane), y: rowY(parent.row))
                        // Vertical drop then a short diagonal into the parent lane.
                        if parent.lane == commit.lane {
                            path.addLine(to: end)
                        } else {
                            path.addLine(to: CGPoint(x: start.x, y: end.y - rowHeight / 2))
                            path.addLine(to: end)
                        }
                        context.stroke(path, with: .color(color(parent.lane).opacity(0.8)), lineWidth: 1.5)
                    } else {
                        // Parent not loaded: stub downward off the bottom.
                        path.addLine(to: CGPoint(x: start.x, y: start.y + rowHeight))
                        context.stroke(path, with: .color(color(commit.lane).opacity(0.5)), lineWidth: 1.5)
                    }
                }
            }
            for commit in graph.commits {
                let center = CGPoint(x: laneX(commit.lane), y: rowY(commit.row))
                let rect = CGRect(x: center.x - nodeRadius, y: center.y - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color(commit.lane)))
            }
        }
    }

    private var commitRows: some View {
        VStack(spacing: 0) {
            ForEach(graph.commits) { commit in
                CommitRow(commit: commit.commit, gitStore: gitStore, onSelect: onSelect)
                    .frame(height: rowHeight)
            }
        }
    }
}

private struct CommitRow: View {
    @Environment(\.palette) private var palette
    let commit: RawCommit
    let gitStore: GitStore
    let onSelect: (RawCommit) -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Subject gets the full width so it isn't truncated by metadata.
            HStack(spacing: 5) {
                ForEach(commit.refs, id: \.self) { ref in
                    Text(ref.replacingOccurrences(of: "HEAD -> ", with: ""))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(palette.accent.opacity(0.16)))
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                Text(commit.subject)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 6) {
                Text(commit.shortHash)
                    .font(.nxMonoSmall)
                    .foregroundStyle(palette.textTertiary)
                Text("·").foregroundStyle(palette.textTertiary)
                Text(commit.relativeDate)
                    .font(.system(size: 9))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovering ? palette.overlay : .clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(commit) }
        .onHover { hovering = $0 }
        .help("\(commit.author) · \(commit.relativeDate)\n\(commit.subject)")
        .contextMenu {
            Button("View Details") { onSelect(commit) }
            Button("Copy SHA") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.hash, forType: .string)
            }
            Button("Checkout This Commit") { gitStore.checkoutCommit(commit.hash) }
        }
    }
}
