import SwiftUI
import DSHProtocol

struct FilesPanel: View {
    @ObservedObject var model: AppModel
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
        .task(id: "\(sessionId ?? "")-\(generation)-\(cwd ?? "")-\(model.filesRevision)") {
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
                        Image(systemName: fileIcon(entry))
                            .foregroundStyle(openable ? T.text2 : T.text3)
                            .frame(width: 20)
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

    private func fileIcon(_ entry: WorkspaceFileEntry) -> String {
        if entry.isDirectory { return "folder" }
        if !entry.isFile { return "exclamationmark.triangle" }
        switch classifyFileType(entry.name) {
        case "image": return "photo"
        case "markdown": return "doc.richtext"
        case "pdf": return "doc.fill"
        default: return "doc"
        }
    }

    private func load(_ target: String) {
        guard canList else { return }
        requestedPath = target
        path = target
        loading = true
        failure = nil
        generation += 1
    }

    private func fetch() async {
        guard canList, let sessionId else {
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
        do {
            let result = try await model.listFiles(sessionId: sessionId, path: target.isEmpty ? "." : target)
            if generation != request { return }
            let listedPath = result["path"].str() ?? target
            let relative = listedPath == "." ? "" : listedPath
            if !workspaceFileListIsRelative(relative) {
                throw PocketError(code: "workspace-file/outside-workspace", message: listedPath)
            }
            path = relative
            entries = parseWorkspaceFileEntries(result)
            truncated = result["truncated"].bool() == true
        } catch is CancellationError {
            return
        } catch {
            if generation != request { return }
            entries = []
            truncated = false
            failure = filesFailureMessage(error: error, english: L.en)
        }
        if generation == request { loading = false }
    }
}
