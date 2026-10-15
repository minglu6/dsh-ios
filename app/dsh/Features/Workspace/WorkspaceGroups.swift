import SwiftUI
import UniformTypeIdentifiers
import DSHProtocol

struct WorkspaceNavigationGroups<SessionRows: View>: View {
    @ObservedObject var model: AppModel
    let workspaces: [WorkspaceView]
    let sessions: [SessionSummary]
    let tree: Bool
    var onMoveWorkspace: ((String, String?) -> Void)? = nil
    @ViewBuilder var renderSessions: (String, [SessionSummary]) -> SessionRows

    var body: some View {
        let assigned = Set(workspaces.flatMap(\.sessionIds))
        let orphans = sessions.filter { !assigned.contains($0.sessionId) }
        let paths = (workspaces.map { workspacePathKey($0.path) } + (orphans.isEmpty ? [] : [""])).uniqued()
        let currentId = model.chat?.sessionId
        let currentWorkspace = currentId.flatMap { id in workspaces.first { $0.sessionIds.contains(id) } }
        if tree {
            ForEach(workspaceBranches(paths), id: \.path) { branch in
                WorkspaceBranchBlock(
                    model: model,
                    path: branch.path,
                    children: branch.children,
                    depth: 0,
                    currentWorkspace: currentWorkspace,
                    orphans: orphans,
                    workspaces: workspaces,
                    sessions: sessions,
                    onMoveWorkspace: onMoveWorkspace,
                    renderSessions: renderSessions
                )
            }
            if paths.contains("") {
                WorkspaceBranchBlock(
                    model: model,
                    path: "",
                    children: [],
                    depth: 0,
                    currentWorkspace: currentWorkspace,
                    orphans: orphans,
                    workspaces: workspaces,
                    sessions: sessions,
                    onMoveWorkspace: onMoveWorkspace,
                    renderSessions: renderSessions
                )
            }
        } else {
            ForEach(paths, id: \.self) { path in
                WorkspaceBranchBlock(
                    model: model,
                    path: path,
                    children: [],
                    depth: 0,
                    currentWorkspace: currentWorkspace,
                    orphans: orphans,
                    workspaces: workspaces,
                    sessions: sessions,
                    onMoveWorkspace: onMoveWorkspace,
                    renderSessions: renderSessions
                )
            }
        }
    }
}

private struct WorkspaceBranchBlock<SessionRows: View>: View {
    @ObservedObject var model: AppModel
    let path: String
    let children: [WorkspaceBranch]
    let depth: Int
    let currentWorkspace: WorkspaceView?
    let orphans: [SessionSummary]
    let workspaces: [WorkspaceView]
    let sessions: [SessionSummary]
    var onMoveWorkspace: ((String, String?) -> Void)? = nil
    let renderSessions: (String, [SessionSummary]) -> SessionRows

    var body: some View {
        let registered = workspaces.filter { workspacePathKey($0.path) == path }
        let fallback = path.isEmpty ? orphans : []
        if registered.isEmpty {
            let key = "path:\(path)"
            WorkspaceGroupHeader(
                model: model,
                title: path.isEmpty ? L.ungrouped() : path,
                path: path,
                collapsed: model.collapsedWorkspaces.contains(key),
                workspace: nil,
                depth: depth,
                active: fallback.contains { $0.sessionId == model.chat?.sessionId } || containsCurrent(children, current: currentWorkspace)
            ) { model.toggleWorkspaceCollapsed(key) }
            if !model.collapsedWorkspaces.contains(key) {
                renderSessions(key, fallback)
                ForEach(children, id: \.path) { child in
                    WorkspaceBranchBlock(
                        model: model,
                        path: child.path,
                        children: child.children,
                        depth: depth + 1,
                        currentWorkspace: currentWorkspace,
                        orphans: orphans,
                        workspaces: workspaces,
                        sessions: sessions,
                        onMoveWorkspace: onMoveWorkspace,
                        renderSessions: renderSessions
                    )
                }
            }
        } else {
            ForEach(Array(registered.enumerated()), id: \.element.workspaceId) { index, workspace in
                let key = "workspace:\(workspace.workspaceId)"
                WorkspaceGroupHeader(
                    model: model,
                    title: workspaceDisplayTitle(title: workspace.title, path: workspace.path, localizedDefault: L.defaultWorkspace()),
                    path: workspace.path,
                    collapsed: model.collapsedWorkspaces.contains(key),
                    workspace: workspace,
                    depth: depth,
                    active: workspace.workspaceId == currentWorkspace?.workspaceId || (index == 0 && containsCurrent(children, current: currentWorkspace)),
                    onMoveWorkspace: onMoveWorkspace
                ) { model.toggleWorkspaceCollapsed(key) }
                if !model.collapsedWorkspaces.contains(key) {
                    if index == 0 {
                        ForEach(children, id: \.path) { child in
                            WorkspaceBranchBlock(
                                model: model,
                                path: child.path,
                                children: child.children,
                                depth: depth + 1,
                                currentWorkspace: currentWorkspace,
                                orphans: orphans,
                                workspaces: workspaces,
                                sessions: sessions,
                                onMoveWorkspace: onMoveWorkspace,
                                renderSessions: renderSessions
                            )
                        }
                    }
                    renderSessions(key, sessions.filter { workspace.sessionIds.contains($0.sessionId) } + (index == 0 ? fallback : []))
                }
            }
        }
    }

    private func containsCurrent(_ branches: [WorkspaceBranch], current: WorkspaceView?) -> Bool {
        guard let current else { return false }
        let key = workspacePathKey(current.path)
        func walk(_ branch: WorkspaceBranch) -> Bool {
            branch.path == key || branch.children.contains(where: walk)
        }
        return branches.contains(where: walk)
    }
}

struct WorkspaceGroupHeader: View {
    @ObservedObject var model: AppModel
    let title: String
    let path: String
    let collapsed: Bool
    var workspace: WorkspaceView?
    var depth: Int
    var active: Bool
    var onMoveWorkspace: ((String, String?) -> Void)? = nil
    var onToggle: () -> Void
    @State private var rename = false
    @State private var remove = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        Image(systemName: collapsed ? "folder" : "folder.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(active ? T.accent : T.text3)
                        Text(title)
                            .font(.system(size: 14))
                            .foregroundStyle(T.ink)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.leading, CGFloat(12 + min(depth, 4) * 12))
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                    .frame(minHeight: 48)
                }
                .accessibilityLabel(collapsed ? L.expand() : L.collapse())
                if let workspace {
                    if model.ops.contains("workspace.rename") || model.ops.contains("workspace.delete") {
                        Menu {
                            if model.ops.contains("workspace.rename") {
                                Button(L.rename()) {
                                    draft = workspace.title.nilIfBlank ?? title
                                    rename = true
                                }
                            }
                            if model.ops.contains("workspace.delete") {
                                Button(L.deleteWorkspace(), role: .destructive) { remove = true }
                            }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 14)).foregroundStyle(model.isOnline ? T.text2 : T.caption)
                                .frame(width: 48, height: 48)
                        }
                        .disabled(!model.isOnline)
                        .accessibilityLabel(L.moreActions())
                    }
                    Button {
                        model.createAndOpenSession(workspaceId: workspace.workspaceId)
                    } label: {
                        Image(systemName: "square.and.pencil").font(.system(size: 16)).foregroundStyle(
                            model.isOnline && model.ops.contains("sessions.create") ? T.text2 : T.caption
                        )
                        .frame(width: 48, height: 48)
                    }
                    .disabled(!(model.isOnline && model.ops.contains("sessions.create")))
                    .accessibilityLabel(L.newSession())
                }
            }
        }
        .onDrag {
            NSItemProvider(object: (workspace?.workspaceId ?? "") as NSString)
        }
        .onDrop(of: [.text], isTargeted: nil) { providers in
            guard let onMoveWorkspace, let target = workspace?.workspaceId else { return false }
            providers.first?.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                let source = (item as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? (item as? String)
                if let source, !source.isEmpty, source != target {
                    DispatchQueue.main.async { onMoveWorkspace(source, target) }
                }
            }
            return true
        }
        .alert(L.rename(), isPresented: $rename) {
            TextField(L.rename(), text: $draft)
            Button(L.save()) {
                if let workspace { model.renameWorkspace(id: workspace.workspaceId, title: draft.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(L.cancel(), role: .cancel) {}
        }
        .confirmationDialog(L.deleteWorkspace(), isPresented: $remove, titleVisibility: .visible) {
            Button(L.deleteWorkspace(), role: .destructive) {
                if let workspace { model.deleteWorkspace(id: workspace.workspaceId) }
            }
            Button(L.cancel(), role: .cancel) {}
        } message: {
            Text(L.deleteWorkspaceBody(title))
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
