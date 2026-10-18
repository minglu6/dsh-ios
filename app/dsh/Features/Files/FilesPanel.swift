import Combine
import SwiftUI
import UIKit
import DSHProtocol

struct FilesPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var autoRefresh = FileAutoRefresh()
    @State private var tree = FileTreeState.root
    @State private var refreshToken = 0
    @State private var previewPath: String?

    private var sessionId: String? { model.chat?.sessionId }
    private var cwd: String? { model.sessions.first { $0.sessionId == sessionId }?.cwd }
    private var canList: Bool { model.isOnline && model.ops.contains("files.list") }
    private var canWatch: Bool { canList && model.ops.contains("files.follow") }
    private var rows: [FileTreeRow] { fileTreeVisibleRows(tree) }

    private var cacheKey: String { fileTreeCacheKey(sessionId: sessionId, cwd: cwd) }

    var body: some View {
        ZStack {
            listing
                .opacity(previewPath == nil ? 1 : 0)
                .allowsHitTesting(previewPath == nil)
            if let previewPath {
                FilePreviewView(
                    model: model,
                    sessionId: sessionId ?? "",
                    path: previewPath,
                    onBack: { self.previewPath = nil }
                )
            }
        }
        .onAppear {
            restoreTree()
            consumePreview()
        }
        .onDisappear { persistTree() }
        .onChange(of: model.filePreview) { _ in consumePreview() }
    }

    private func consumePreview() {
        guard let pending = model.filePreview, pending.sessionId == sessionId else { return }
        previewPath = pending.path
        model.filePreview = nil
    }

    private var listing: some View {
        VStack(spacing: 0) {
            header(L.workspaceFiles()) { model.pop() }
            toolbar
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    content
                }
                .background {
                    ScrollOffsetBridge(offset: Binding(
                        get: { model.fileTreeOffsets[cacheKey] ?? 0 },
                        set: { model.fileTreeOffsets[cacheKey] = $0 }
                    ))
                }
            }
        }
        .background(T.bg)
        .background { watches }
        .onChange(of: sessionId) { _ in resetTree() }
        .onChange(of: cwd) { _ in resetTree() }
        .onChange(of: model.filesRevision) { _ in refreshToken += 1 }
        .onChange(of: tree) { _ in persistTree() }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            PreviewPathLabel(path: cwdName)
            Spacer(minLength: 8)
            Button {
                autoRefresh.enabled.toggle()
                if autoRefresh.enabled { refreshToken += 1 }
            } label: {
                OfficialGlyph(
                    kind: autoRefresh.enabled ? .pauseOutline : .playOutline,
                    size: 16,
                    color: canWatch ? T.text2 : T.caption
                )
            }
            .disabled(!canWatch)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L.autoRefresh())
            .accessibilityHint(autoRefresh.enabled ? L.autoRefreshDisable() : L.autoRefreshEnable())
            .accessibilityAddTraits(autoRefresh.enabled ? [.isSelected] : [])
            Button { refreshToken += 1 } label: {
                OfficialGlyph(
                    kind: .refreshOutline,
                    size: 16,
                    color: canList && !(cwd ?? "").isEmpty ? T.text2 : T.caption
                )
            }
            .disabled(!(canList && !(cwd ?? "").isEmpty))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L.reload())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(T.surface)
    }

    private var cwdName: String {
        guard let cwd, !cwd.isEmpty else { return L.noWorkspace() }
        return cwd
    }

    @ViewBuilder
    private var watches: some View {
        if previewPath == nil, scenePhase == .active, canList, let cwd, !cwd.isEmpty {
            ForEach(tree.expanded.sorted(), id: \.self) { path in
                Color.clear
                    .frame(width: 0, height: 0)
                    .task(id: "\(sessionId ?? "")-\(path)-\(refreshToken)-\(cwd)-\(canWatch)") {
                        await fetch(path)
                    }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if cwd == nil || cwd?.isEmpty == true {
            Text(L.noWorkspaceHint()).font(.system(size: 13)).foregroundStyle(T.text3).padding(20)
        } else if tree.levels[""] == nil && !canList {
            EmptyView()
        } else {
            ForEach(rows) { row in
                fileRow(row)
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ row: FileTreeRow) -> some View {
        switch row.kind {
        case .loading:
            noteRow(L.readingFiles(), depth: row.depth)
        case .empty:
            noteRow(L.emptyDirectory(), depth: row.depth)
        case .truncated:
            noteRow(L.filesTruncated(), depth: row.depth)
        case .failed:
            noteRow(row.message ?? "", depth: row.depth, error: true)
        case .directory(let expanded):
            let enabled = model.isOnline && canList
            Button {
                fileTreeToggle(&tree, path: row.path)
            } label: {
                HStack(spacing: 8) {
                    FileTypeIcon(path: row.name, type: row.type, openable: enabled, expanded: expanded)
                    Text(row.name)
                        .font(.system(size: 13))
                        .foregroundStyle(enabled ? T.ink : T.text3)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.leading, 12 + CGFloat(row.depth) * 18)
                .padding(.trailing, 20)
                .padding(.vertical, 9)
                .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityLabel(row.name)
            .accessibilityAddTraits(expanded ? [.isSelected] : [])
            .fileTreeContextMenu(path: row.path)
        case .file:
            let enabled = model.isOnline
            Button {
                previewPath = row.path
            } label: {
                HStack(spacing: 8) {
                    FileTypeIcon(path: row.name, type: row.type, openable: enabled)
                    Text(row.name)
                        .font(.system(size: 13))
                        .foregroundStyle(enabled ? T.ink : T.text3)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.leading, 12 + CGFloat(row.depth) * 18)
                .padding(.trailing, 20)
                .padding(.vertical, 9)
                .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityLabel(row.name)
            .fileTreeContextMenu(path: row.path)
        case .other:
            HStack(spacing: 8) {
                FileTypeIcon(path: row.name, type: row.type, openable: false)
                Text(row.name)
                    .font(.system(size: 13))
                    .foregroundStyle(T.text3)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, 12 + CGFloat(row.depth) * 18)
            .padding(.trailing, 20)
            .padding(.vertical, 9)
            .frame(minHeight: 48)
            .accessibilityLabel("\(row.name)。\(L.notFileOrDirectory())")
            .fileTreeContextMenu(path: row.path)
        }
    }

    private func noteRow(_ text: String, depth: Int, error: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(error ? T.err : T.text3)
            .padding(.leading, 40 + CGFloat(depth) * 18)
            .padding(.trailing, 20)
            .padding(.vertical, 6)
    }

    private func persistTree() {
        model.fileTreeStates[cacheKey] = tree
    }

    private func restoreTree() {
        if let stored = model.fileTreeStates[cacheKey] {
            tree = stored
        }
    }

    private func resetTree() {
        persistTree()
        if let stored = model.fileTreeStates[fileTreeCacheKey(sessionId: sessionId, cwd: cwd)] {
            tree = stored
        } else {
            tree = FileTreeState.root
        }
        refreshToken += 1
    }

    private func fetch(_ path: String) async {
        guard canList, let sessionId else { return }
        guard let cwd, !cwd.isEmpty else { return }
        await MainActor.run { fileTreeMarkLoading(&tree, path: path) }
        do {
            try await observeWorkspaceDirectory(
                list: { _ in
                    try await model.listFiles(sessionId: sessionId, path: path.isEmpty ? "." : path)
                },
                changes: canWatch ? model.followFiles(sessionId: sessionId, path: path.isEmpty ? "." : path) : nil,
                automatic: { [autoRefresh] in autoRefresh.enabled },
                onListing: { result in
                    Task { @MainActor in
                        let listedPath = result["path"].str() ?? path
                        let relative = listedPath == "." ? "" : listedPath
                        if !workspaceFileListIsRelative(relative) {
                            fileTreeApplyFailure(
                                &tree,
                                path: path,
                                message: filesFailureMessage(
                                    error: PocketError(code: "workspace-file/outside-workspace", message: listedPath),
                                    english: L.en
                                )
                            )
                            return
                        }
                        fileTreeApplyListing(
                            &tree,
                            path: path,
                            entries: parseWorkspaceFileEntries(result),
                            truncated: result["truncated"].bool() == true
                        )
                    }
                },
                onFailure: { error in
                    Task { @MainActor in
                        fileTreeApplyFailure(&tree, path: path, message: filesFailureMessage(error: error, english: L.en))
                    }
                }
            )
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                fileTreeApplyFailure(&tree, path: path, message: filesFailureMessage(error: error, english: L.en))
            }
        }
    }
}

private struct ScrollOffsetBridge: UIViewRepresentable {
    @Binding var offset: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(offset: $offset) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.offset = $offset
        DispatchQueue.main.async { context.coordinator.attach(from: uiView) }
    }

    final class Coordinator: NSObject {
        var offset: Binding<CGFloat>
        weak var scroll: UIScrollView?
        var restoring = false

        init(offset: Binding<CGFloat>) { self.offset = offset }

        func attach(from view: UIView) {
            guard scroll == nil else {
                restoreIfNeeded()
                return
            }
            var current: UIView? = view
            while let next = current?.superview {
                if let found = next as? UIScrollView {
                    scroll = found
                    found.addObserver(self, forKeyPath: "contentOffset", options: [.new], context: nil)
                    found.addObserver(self, forKeyPath: "contentSize", options: [.new], context: nil)
                    restoreIfNeeded()
                    return
                }
                current = next
            }
        }

        func restoreIfNeeded() {
            guard let scroll, !restoring else { return }
            guard let target = fileTreeRestoredOffset(
                saved: Double(offset.wrappedValue),
                contentHeight: Double(scroll.contentSize.height),
                viewportHeight: Double(scroll.bounds.height)
            ) else { return }
            if abs(scroll.contentOffset.y - CGFloat(target)) > 1 {
                restoring = true
                scroll.setContentOffset(CGPoint(x: 0, y: target), animated: false)
                restoring = false
            }
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "contentSize" {
                restoreIfNeeded()
                return
            }
            guard keyPath == "contentOffset", let scroll, !restoring else { return }
            if fileTreeShouldKeepSavedOffset(
                current: Double(scroll.contentOffset.y),
                saved: Double(offset.wrappedValue),
                contentHeight: Double(scroll.contentSize.height),
                viewportHeight: Double(scroll.bounds.height)
            ) {
                return
            }
            offset.wrappedValue = scroll.contentOffset.y
        }

        deinit {
            scroll?.removeObserver(self, forKeyPath: "contentOffset")
            scroll?.removeObserver(self, forKeyPath: "contentSize")
        }
    }
}

private final class FileAutoRefresh: ObservableObject, @unchecked Sendable {
    @Published var enabled = true
}

private extension View {
    func fileTreeContextMenu(path: String) -> some View {
        contextMenu {
            Button(L.copyPath()) {
                UIPasteboard.general.string = path
            }
            Button(L.copyName()) {
                UIPasteboard.general.string = previewFileName(path)
            }
        }
    }
}
