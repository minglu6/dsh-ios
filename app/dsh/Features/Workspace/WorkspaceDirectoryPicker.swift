import SwiftUI
import DSHProtocol

struct WorkspaceDirectoryPicker: View {
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
    @ObservedObject private var theme = ThemeStateHolder.shared
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case path, folder }

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

    private var inert: Bool { saving || creating || folderName != nil }
    private var target: String? { browse ? dir.target : nativePath.nilIfBlank }
    private var ready: Bool { enabled && target != nil && !dir.loading && !inert && dir.draft == nil }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                T.scrim.ignoresSafeArea().onTapGesture { dismiss() }
                card
                    .frame(width: max(0, min(680, geometry.size.width - 48)),
                           height: max(0, min(500, geometry.size.height - 48)))
                    .background(T.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(theme.dark ? 0.35 : 0.16), radius: 24, y: 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityIdentifier("workspaceDirectoryDialog")
                    .accessibilityHidden(folderName != nil)
                if folderName != nil {
                    T.scrim.ignoresSafeArea().onTapGesture { cancelFolder() }
                    ScrollView { createFolderDialog }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: max(0, min(380, geometry.size.width - 48)))
                        .background(T.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: .black.opacity(theme.dark ? 0.35 : 0.16), radius: 24, y: 8)
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isModal)
                        .accessibilityIdentifier("workspaceCreateFolderDialog")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .task {
            if browse, enabled { await dir.navigate() }
        }
        .onDisappear { dir.dispose() }
    }

    private var card: some View {
        VStack(spacing: 0) {
            header
            separator
            panes
            if dir.parent?.truncated == true || dir.child?.truncated == true {
                Text(L.foldersTruncated()).font(.system(size: 12)).foregroundStyle(T.text2).padding(.horizontal, 24).padding(.vertical, 4)
            }
            if let err = saveError ?? dir.error {
                Text(err).font(.system(size: 12)).foregroundStyle(T.err).lineLimit(3).padding(.horizontal, 24).padding(.vertical, 4)
            }
            separator
            footer
        }
    }

    private var separator: some View {
        T.borderL3.frame(height: 0.5)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.selectWorkspaceDirectory()).font(.system(size: 16, weight: .medium)).foregroundStyle(T.ink)
                .frame(minHeight: 28, alignment: .bottomLeading)
            if !browse || dir.draft != nil {
                TextField(L.editPath(), text: Binding(
                    get: { browse ? (dir.draft ?? "") : nativePath },
                    set: { value in
                        if browse { dir.edit(value) } else { nativePath = value }
                    }
                ))
                .font(.system(size: 13)).foregroundStyle(T.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .path)
                .padding(.horizontal, 8).frame(height: 24)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.border, lineWidth: 1))
                .padding(.leading, -9)
                .disabled(inert || !enabled)
                .submitLabel(.go)
                .onSubmit { submitPath() }
                .onAppear { focusedField = .path }
                .accessibilityIdentifier("workspaceDirectoryPath")
            } else {
                HStack(spacing: 4) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(dir.crumbs.enumerated()), id: \.offset) { index, crumb in
                                    if index > 0 {
                                        OfficialGlyph(kind: .chevronRight, size: 12, color: T.text3)
                                    }
                                    Button {
                                        Task { await dir.navigate(path: crumb.path) }
                                    } label: {
                                        Text(crumb.path == dir.parent?.home ? L.homeDirectory() : crumb.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(T.text3)
                                            .lineLimit(1)
                                            .frame(maxWidth: 160)
                                    }
                                    .disabled(!(enabled && !inert))
                                    .id(crumb.path)
                                }
                            }
                        }
                        .onAppear { proxy.scrollTo(dir.crumbs.last?.path, anchor: .trailing) }
                        .onChange(of: dir.crumbs.last?.path) { path in proxy.scrollTo(path, anchor: .trailing) }
                    }
                    Button { dir.beginEdit() } label: {
                        OfficialGlyph(kind: .editOutline, size: 14, color: T.text3)
                            .frame(minWidth: 34, minHeight: 24, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .disabled(inert || !enabled)
                    .accessibilityLabel(L.editPath())
                    .accessibilityIdentifier("workspaceDirectoryEditPath")
                }
                .frame(height: 24)
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 14)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var panes: some View {
        ZStack(alignment: .bottomTrailing) {
            if browse {
                GeometryReader { geo in
                    let width = dir.child != nil ? max(256, (geo.size.width - 24.5) / 2) : geo.size.width
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                if let parent = dir.parent {
                                    DirectoryColumn(entries: dir.visibleEntries(parent), selected: dir.selected?.path, enabled: enabled && !inert, width: width) { entry in
                                        Task { await dir.navigate(path: entry.path, base: parent) }
                                    }
                                }
                                if let child = dir.child {
                                    T.borderL3.frame(width: 0.5)
                                    DirectoryColumn(entries: dir.visibleEntries(child), selected: nil, enabled: enabled && !inert, width: width) { entry in
                                        Task { await dir.navigate(path: entry.path, base: child) }
                                    }
                                    .id("directoryChild")
                                }
                            }
                            .frame(height: geo.size.height)
                        }
                        .onChange(of: dir.child?.path) { path in
                            if path != nil { proxy.scrollTo("directoryChild", anchor: .trailing) }
                        }
                        .onChange(of: geo.size.width) { _ in
                            if dir.child != nil { proxy.scrollTo("directoryChild", anchor: .trailing) }
                        }
                    }
                }
            }
            if dir.loading {
                Text(L.loading())
                    .font(.system(size: 12))
                    .foregroundStyle(T.text3)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(T.surface2)
            }
        }
        .frame(minHeight: 0, maxHeight: .infinity)
        .padding(.leading, 24)
        .padding(.trailing, 16)
        .padding(.vertical, 16)
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                if browse { browsingActions }
                Spacer(minLength: 0)
                confirmationActions
            }
            VStack(alignment: .leading, spacing: 8) {
                if browse {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { browsingActions }
                        VStack(alignment: .leading, spacing: 8) { browsingActions }
                    }
                }
                HStack { Spacer(minLength: 0); confirmationActions }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var browsingActions: some View {
        Button {
            folderName = ""
            createError = nil
        } label: {
            HStack(spacing: 4) {
                OfficialGlyph(kind: .plusOutline, size: 14, color: T.ink)
                Text(L.newFolder())
            }
        }
        .buttonStyle(DirectoryActionStyle())
        .disabled(!(canCreate && ready))
        .accessibilityIdentifier("workspaceDirectoryNewFolder")
        Button { dir.toggleHidden() } label: {
            HStack(spacing: 4) {
                Text(L.showHiddenFiles())
                if dir.showHidden {
                    OfficialGlyph(kind: .checkOutline, size: 14, color: inert ? T.caption : T.ink)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(inert ? T.caption : (dir.showHidden ? T.ink : T.text2))
            .fixedSize()
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .disabled(inert)
        .accessibilityValue(dir.showHidden ? L.t("已开启", "On") : L.t("已关闭", "Off"))
        .accessibilityIdentifier("workspaceDirectoryHidden")
    }

    private var confirmationActions: some View {
        HStack(spacing: 8) {
            Button(L.cancel()) { dismiss() }
                .buttonStyle(DirectoryActionStyle(minWidth: 72))
                .disabled(inert)
                .accessibilityIdentifier("workspaceDirectoryCancel")
            Button(L.open()) { openTarget() }
                .buttonStyle(DirectoryActionStyle(primary: true, minWidth: 72))
                .disabled(!(ready && canOpen))
                .accessibilityIdentifier("workspaceDirectoryOpen")
        }
        .background {
            Button("") {
                if dir.draft != nil {
                    focusedField = nil
                    Task { await dir.cancelEdit() }
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(.cancelAction)
            .hidden()
            .disabled(inert)
        }
    }

    private var createFolderDialog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.newFolder()).font(.system(size: 16, weight: .medium)).foregroundStyle(T.ink)
            Text(L.newFolderIn(currentFolderName)).font(.system(size: 14)).foregroundStyle(T.ink)
            TextField(L.untitledFolder(), text: Binding(get: { folderName ?? "" }, set: { folderName = $0 }))
                .font(.system(size: 14)).foregroundStyle(T.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .folder)
                .padding(.horizontal, 14).frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.borderStrong, lineWidth: 0.5))
                .disabled(creating)
                .submitLabel(.done)
                .onSubmit { createFolder() }
                .onAppear { focusedField = .folder }
                .accessibilityLabel(L.folderName())
                .accessibilityIdentifier("workspaceDirectoryFolderName")
            if let createError { Text(createError).font(.system(size: 12)).foregroundStyle(T.err) }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(L.cancel()) { cancelFolder() }
                    .buttonStyle(DirectoryActionStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(creating)
                Button(L.create()) { createFolder() }
                    .buttonStyle(DirectoryActionStyle(primary: true))
                    .disabled(!(enabled && canCreate && !creating && folderName?.nilIfBlank != nil))
                    .accessibilityIdentifier("workspaceDirectoryCreate")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 20)
    }

    private func dismiss() {
        guard !inert else { return }
        focusedField = nil
        onDismiss()
    }

    private func cancelFolder() {
        guard !creating else { return }
        focusedField = nil
        folderName = nil
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
                saving = false
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
                focusedField = nil
                folderName = nil
                await dir.navigate(path: created)
            } catch is CancellationError {
                creating = false
                return
            } catch {
                createError = error.localizedDescription
            }
            creating = false
        }
    }
}

private struct DirectoryActionStyle: ButtonStyle {
    var primary = false
    var minWidth: CGFloat = 0
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundStyle(primary ? T.onPrimary : T.ink)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(minWidth: minWidth, minHeight: 36)
            .background(primary ? T.primaryButton : (configuration.isPressed ? T.hoverBg : .clear),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(primary ? .clear : T.borderL3, lineWidth: 0.5))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
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
                        HStack(spacing: 4) {
                            OfficialGlyph(
                                kind: isSelected ? .folderOpen : .folderClose,
                                size: 14,
                                color: !enabled ? T.caption : (isSelected ? T.accent : T.text2)
                            )
                            Text(entry.name).font(.system(size: 13, weight: .medium)).foregroundStyle(enabled ? T.ink : T.caption).lineLimit(1)
                            Spacer()
                            OfficialGlyph(kind: .chevronRight, size: 10, color: T.text3)
                        }
                        .padding(.horizontal, 4)
                        .frame(height: 28)
                        .background(isSelected ? T.interactiveBgActive : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .disabled(!enabled)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("workspaceDirectoryEntry.\(entry.path)")
                }
            }
            .padding(.trailing, 8)
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
        if inner.draft == nil { inner.draft = "" }
        publish()
    }

    func cancelEdit() async {
        await inner.cancelEdit()
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
