import SwiftUI
import DSHProtocol

struct FilesPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var requestedPath = ""
    @State private var path = ""
    @State private var entries: [WorkspaceFileEntry] = []
    @State private var loading = true
    @State private var failure: String?
    @State private var truncated = false
    @State private var generation = 0
    @State private var previewPath: String?

    private var sessionId: String? { model.chat?.sessionId }
    private var cwd: String? { model.sessions.first { $0.sessionId == sessionId }?.cwd }
    private var canList: Bool { model.isOnline && model.ops.contains("files.list") }
    private var canWatch: Bool { canList && model.ops.contains("files.follow") }

    var body: some View {
        Group {
            if let previewPath {
                FilePreviewView(
                    model: model,
                    sessionId: sessionId ?? "",
                    path: previewPath,
                    onBack: { self.previewPath = nil }
                )
            } else {
                listing
            }
        }
        .onAppear { consumePreview() }
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
            crumbs
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    content
                }
            }
        }
        .background(T.bg)
        .onAppear {
            load(requestedPath)
        }
        .task(id: "\(sessionId ?? "")-\(generation)-\(cwd ?? "")-\(model.filesRevision)-\(canWatch)-\(previewPath ?? "")-\(scenePhase == .active)") {
            guard scenePhase == .active else { return }
            await fetch()
        }
    }

    private var crumbs: some View {
        HStack(spacing: 4) {
            let parent = workspaceFilesParentPath(path)
            Button {
                if let parent { load(parent) }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(canList && parent != nil ? T.text2 : T.text3.opacity(0.45))
            }
            .disabled(!(canList && parent != nil))
            .accessibilityLabel(L.parentDirectory())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    Button {
                        load("")
                    } label: {
                        Text(cwdName)
                            .font(.system(size: 12))
                            .foregroundStyle(canList && !loading && !(cwd ?? "").isEmpty ? T.text2 : T.caption)
                    }
                    .disabled(!(canList && !loading && !(cwd ?? "").isEmpty))
                    ForEach(Array(path.split(separator: "/").enumerated()), id: \.offset) { index, part in
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(T.text3)
                        Button {
                            load(path.split(separator: "/").prefix(index + 1).joined(separator: "/"))
                        } label: {
                            Text(String(part)).font(.system(size: 12)).foregroundStyle(canList && !loading ? T.text2 : T.caption)
                        }
                        .disabled(!(canList && !loading))
                    }
                }
            }
            Button { load(path) } label: {
                Image(systemName: "arrow.clockwise").foregroundStyle(canList && !loading && !(cwd ?? "").isEmpty ? T.text2 : T.caption)
            }
            .disabled(!(canList && !loading && !(cwd ?? "").isEmpty))
            .accessibilityLabel(L.reload())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(T.surface)
    }

    private var cwdName: String {
        guard let cwd, !cwd.isEmpty else { return L.noWorkspace() }
        let trimmed = cwd.trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
        return trimmed.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? "/"
    }

    @ViewBuilder
    private var content: some View {
        if cwd == nil || cwd?.isEmpty == true {
            Text(L.noWorkspaceHint()).font(.system(size: 13)).foregroundStyle(T.text3).padding(20)
        } else if loading {
            HStack(spacing: 10) {
                ProgressView().controlSize(.mini)
                Text(L.readingFiles()).font(.system(size: 13)).foregroundStyle(T.text3)
            }
            .padding(20)
        } else if let failure {
            VStack(alignment: .leading, spacing: 8) {
                Text(failure).font(.system(size: 13)).foregroundStyle(T.err)
                Button(L.reload()) { load(path) }.disabled(!canList).foregroundStyle(canList ? T.accent : T.caption)
            }
            .padding(20)
        } else if entries.isEmpty {
            Text(L.emptyDirectory()).font(.system(size: 13)).foregroundStyle(T.text3).padding(20)
        } else {
            ForEach(entries) { entry in
                let directory = entry.isDirectory
                let openable = directory || entry.isFile
                let enabled = model.isOnline && openable && (!directory || canList)
                Button {
                    let child = path.isEmpty ? entry.name : "\(path)/\(entry.name)"
                    if directory { load(child) } else { previewPath = child }
                } label: {
                    HStack(spacing: 10) {
                        FileTypeIcon(path: entry.name, type: entry.type, openable: openable)
                        Text(entry.name)
                            .font(.system(size: 13))
                            .foregroundStyle(enabled ? T.ink : T.text3)
                            .lineLimit(1)
                        Spacer()
                        if directory { Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(T.text3) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .frame(minHeight: 48)
                }
                .disabled(!enabled)
                .accessibilityLabel(openable ? entry.name : "\(entry.name)。\(L.notFileOrDirectory())")
            }
            if truncated {
                Text(L.filesTruncated()).font(.system(size: 12)).foregroundStyle(T.text3).padding(20)
            }
        }
    }

    private func load(_ target: String) {
        guard canList else { return }
        if target != path {
            entries = []
            truncated = false
            loading = true
        }
        requestedPath = target
        path = target
        failure = nil
        generation += 1
    }

    private func fetch() async {
        guard canList, let sessionId, previewPath == nil else {
            loading = false
            return
        }
        let request = generation
        let target = requestedPath
        guard let cwd, !cwd.isEmpty else {
            entries = []
            loading = false
            return
        }
        func currentRequest() -> Bool { generation == request }
        do {
            try await observeWorkspaceDirectory(
                list: { watchedPath in
                    try await model.listFiles(sessionId: sessionId, path: watchedPath ?? (target.isEmpty ? "." : target))
                },
                changes: canWatch ? model.followFiles(sessionId: sessionId, path: target.isEmpty ? "." : target) : nil,
                onListing: { result in
                    Task { @MainActor in
                        guard currentRequest() else { return }
                        let listedPath = result["path"].str() ?? target
                        let relative = listedPath == "." ? "" : listedPath
                        if !workspaceFileListIsRelative(relative) {
                            entries = []
                            truncated = false
                            failure = filesFailureMessage(error: PocketError(code: "workspace-file/outside-workspace", message: listedPath), english: L.en)
                            loading = false
                            return
                        }
                        path = relative
                        entries = parseWorkspaceFileEntries(result)
                        truncated = result["truncated"].bool() == true
                        failure = nil
                        loading = false
                    }
                },
                onFailure: { error in
                    Task { @MainActor in
                        guard currentRequest() else { return }
                        entries = []
                        truncated = false
                        failure = filesFailureMessage(error: error, english: L.en)
                        loading = false
                    }
                }
            )
        } catch is CancellationError {
            return
        } catch {
            if currentRequest() {
                entries = []
                truncated = false
                failure = filesFailureMessage(error: error, english: L.en)
                loading = false
            }
        }
    }
}
