import SwiftUI
import DSHProtocol

struct WorkspaceDirectorySheet: View {
    @ObservedObject var model: AppModel
    var onCreated: (WorkspaceView) -> Void = { _ in }
    var onDismiss: () -> Void

    var body: some View {
        WorkspaceDirectoryDialog(
            browse: model.ops.contains("workspace.directoryList"),
            canCreate: model.isOnline && model.ops.contains("workspace.directoryCreate"),
            enabled: model.isOnline,
            canOpen: model.isOnline && model.ops.contains("workspace.create"),
            list: { try await model.listWorkspaceDirectories(path: $0) },
            createDirectory: { try await model.createWorkspaceDirectory(path: $0, name: $1) },
            open: { onCreated(try await model.createWorkspace(path: $0)) },
            onDismiss: onDismiss
        )
    }
}

struct WorkspaceDirectoryDialog: View {
    let browse: Bool
    let canCreate: Bool
    let enabled: Bool
    let canOpen: Bool
    let list: (String?) async throws -> WorkspaceDirectoryLevel
    let createDirectory: (String, String) async throws -> String
    let open: (String) async throws -> Void
    let onDismiss: () -> Void

    @StateObject private var dir: DirectoryController
    @State private var nativePath = ""
    @State private var saving = false
    @State private var saveError: String?
    @State private var folderName: String?
    @State private var creating = false
    @State private var createError: String?

    init(
        browse: Bool,
        canCreate: Bool,
        enabled: Bool,
        canOpen: Bool,
        list: @escaping (String?) async throws -> WorkspaceDirectoryLevel,
        createDirectory: @escaping (String, String) async throws -> String,
        open: @escaping (String) async throws -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.browse = browse
        self.canCreate = canCreate
        self.enabled = enabled
        self.canOpen = canOpen
        self.list = list
        self.createDirectory = createDirectory
        self.open = open
        self.onDismiss = onDismiss
        _dir = StateObject(wrappedValue: DirectoryController(list: list))
    }

    private var inert: Bool { saving || folderName != nil }
    private var target: String? { browse ? dir.target : nativePath.nilIfBlank }
    private var ready: Bool { enabled && target != nil && !dir.loading && !inert && dir.draft == nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            panes
            if dir.parent?.truncated == true || dir.child?.truncated == true {
                Text(L.foldersTruncated()).font(.system(size: 12)).foregroundStyle(T.text3).padding(.horizontal, 24).padding(.vertical, 4)
            }
            if let err = saveError ?? dir.error {
                Text(err).font(.system(size: 12)).foregroundStyle(T.err).lineLimit(3).padding(.horizontal, 24).padding(.vertical, 4)
            }
            Divider()
            footer
        }
        .background(T.surface2)
        .task {
            if browse, enabled { await dir.navigate() }
        }
        .onDisappear { dir.dispose() }
        .sheet(isPresented: Binding(get: { folderName != nil }, set: { if !$0, !creating { folderName = nil } })) {
            createFolderSheet
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.selectWorkspaceDirectory()).font(.system(size: 16, weight: .medium)).foregroundStyle(T.ink)
            if !browse || dir.draft != nil {
                TextField(L.editPath(), text: Binding(
                    get: { browse ? (dir.draft ?? "") : nativePath },
                    set: { value in
                        if browse { dir.edit(value) } else { nativePath = value }
                    }
                ))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(10)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.border, lineWidth: 0.5))
                .disabled(inert)
                .onSubmit { submitPath() }
            } else {
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(Array(dir.crumbs.enumerated()), id: \.offset) { index, crumb in
                                if index > 0 { Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(T.text3) }
                                Button {
                                    Task { await dir.navigate(path: crumb.path) }
                                } label: {
                                    Text(crumb.path == dir.parent?.home ? L.homeDirectory() : crumb.name)
                                        .font(.system(size: 13))
                                        .foregroundStyle(T.text3)
                                        .lineLimit(1)
                                }
                                .disabled(!(enabled && !inert))
                            }
                        }
                    }
                    Button { dir.beginEdit() } label: {
                        Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(T.text3)
                    }
                    .disabled(inert)
                    .accessibilityLabel(L.editPath())
                }
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 14)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var panes: some View {
        ZStack(alignment: .topTrailing) {
            if browse {
                GeometryReader { geo in
                    let two = dir.child != nil
                    let width = two ? max(256, (geo.size.width - 24) / 2) : geo.size.width
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if let parent = dir.parent {
                                DirectoryColumn(entries: dir.visibleEntries(parent), selected: dir.selected?.path, enabled: enabled && !inert, width: width) { entry in
                                    Task { await dir.navigate(path: entry.path, base: parent) }
                                }
                            }
                            if let child = dir.child {
                                Divider()
                                DirectoryColumn(entries: dir.visibleEntries(child), selected: dir.selected?.path, enabled: enabled && !inert, width: width) { entry in
                                    Task { await dir.navigate(path: entry.path, base: child) }
                                }
                            }
                        }
                    }
                }
            }
            if dir.loading {
                Text(L.loading())
                    .font(.system(size: 12))
                    .foregroundStyle(T.text3)
                    .padding(8)
                    .background(T.surface3, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(minHeight: 220)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if browse {
                HStack {
                    Button {
                        folderName = ""
                        createError = nil
                    } label: {
                        Label(L.newFolder(), systemImage: "plus")
                    }
                    .disabled(!(canCreate && ready))
                    Button { dir.toggleHidden() } label: {
                        HStack(spacing: 4) {
                            Text(L.showHiddenFiles()).font(.system(size: 12)).foregroundStyle(T.text3)
                            if dir.showHidden { Image(systemName: "checkmark").font(.system(size: 11)).foregroundStyle(T.text3) }
                        }
                    }
                    .disabled(inert)
                    Spacer()
                }
            }
            HStack {
                Spacer()
                Button(L.cancel()) { if !inert { onDismiss() } }
                    .disabled(inert)
                Button(L.open()) { openTarget() }
                    .disabled(!(ready && canOpen))
                    .foregroundStyle(T.onPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background((ready && canOpen) ? T.primaryButton : T.primaryButton.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var createFolderSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.newFolder()).font(.system(size: 16, weight: .medium)).foregroundStyle(T.ink)
            Text(L.newFolderIn(currentFolderName)).font(.system(size: 14)).foregroundStyle(T.ink)
            TextField(L.untitledFolder(), text: Binding(get: { folderName ?? "" }, set: { folderName = $0 }))
                .textInputAutocapitalization(.never)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.borderStrong, lineWidth: 0.5))
                .disabled(creating)
                .onSubmit { createFolder() }
            if let createError { Text(createError).font(.system(size: 12)).foregroundStyle(T.err) }
            HStack {
                Spacer()
                Button(L.cancel()) { if !creating { folderName = nil } }.disabled(creating)
                Button(L.create()) { createFolder() }
                    .disabled(!(enabled && canCreate && !creating && !(folderName ?? "").isEmpty))
            }
        }
        .padding(24)
        .background(T.surface2)
    }

    private var currentFolderName: String {
        if let name = dir.selected?.name { return name }
        if let crumb = dir.crumbs.last {
            return crumb.path == dir.parent?.home ? L.homeDirectory() : crumb.name
        }
        return ""
    }

    private func submitPath() {
        guard enabled, !inert, let draft = dir.draft?.nilIfBlank else { return }
        Task { await dir.navigate(path: draft) }
    }

    private func openTarget() {
        guard let path = target, ready, canOpen else { return }
        saving = true
        saveError = nil
        Task {
            do {
                try await open(path)
                onDismiss()
            } catch is CancellationError {
                return
            } catch {
                saveError = error.localizedDescription
            }
            saving = false
        }
    }

    private func createFolder() {
        guard let path = target, let name = folderName?.nilIfBlank, enabled, canCreate, !creating else { return }
        creating = true
        createError = nil
        Task {
            do {
                let created = try await createDirectory(path, name)
                folderName = nil
                await dir.navigate(path: created)
            } catch is CancellationError {
                return
            } catch {
                createError = error.localizedDescription
            }
            creating = false
        }
    }
}

private struct DirectoryColumn: View {
    let entries: [WorkspaceDirectoryEntry]
    let selected: String?
    let enabled: Bool
    let width: CGFloat
    let onPick: (WorkspaceDirectoryEntry) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(entries) { entry in
                    let isSelected = entry.path == selected
                    Button { onPick(entry) } label: {
                        HStack(spacing: 6) {
                            OfficialGlyph(
                                kind: isSelected ? .folderOpen : .folderClose,
                                size: 14,
                                color: !enabled ? T.caption : T.ink
                            )
                            Text(entry.name).font(.system(size: 13)).foregroundStyle(enabled ? T.ink : T.caption).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(T.text3)
                        }
                        .padding(.horizontal, 6)
                        .frame(minHeight: 44)
                        .background(isSelected ? T.hoverBg : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!enabled)
                }
            }
        }
        .frame(width: width)
    }
}

@MainActor
private final class DirectoryController: ObservableObject {
    let inner: WorkspaceDirectoryState
    @Published var parent: WorkspaceDirectoryLevel?
    @Published var child: WorkspaceDirectoryLevel?
    @Published var selected: WorkspaceDirectoryEntry?
    @Published var draft: String?
    @Published var loading = false
    @Published var error: String?
    @Published var showHidden = false

    var target: String? { selected?.path ?? parent?.path }
    var crumbs: [WorkspaceDirectoryEntry] { (child ?? parent)?.displayCrumbs() ?? [] }

    init(list: @escaping (String?) async throws -> WorkspaceDirectoryLevel) {
        inner = WorkspaceDirectoryState(list: list)
        inner.onChange = { [weak self] in
            Task { @MainActor in self?.publish() }
        }
    }

    func visibleEntries(_ level: WorkspaceDirectoryLevel) -> [WorkspaceDirectoryEntry] {
        inner.visibleEntries(level)
    }

    func navigate(path: String? = nil, base: WorkspaceDirectoryLevel? = nil) async {
        await inner.navigate(path: path, base: base)
        publish()
    }

    func beginEdit() {
        inner.beginEdit()
        publish()
    }

    func edit(_ value: String) {
        inner.edit(value)
        publish()
    }

    func toggleHidden() {
        inner.showHidden.toggle()
        showHidden = inner.showHidden
        objectWillChange.send()
    }

    func dispose() {
        inner.dispose()
    }

    private func publish() {
        parent = inner.parent
        child = inner.child
        selected = inner.selected
        draft = inner.draft
        loading = inner.loading
        error = inner.error
        showHidden = inner.showHidden
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
