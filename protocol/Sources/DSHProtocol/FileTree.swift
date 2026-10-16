import Foundation

/// One directory level in the workspace file tree.
///
/// Desktop `ui-sidebar-files` keeps a collapsed level's listing so reopening
/// draws immediately, then the watch re-lists. `loading` is only used when
/// that cache does not exist yet.
public enum FileTreeLevel: Equatable, Sendable {
    case loading
    case ready(entries: [WorkspaceFileEntry], truncated: Bool, failure: String?)
    case failed(String)
}

/// Workspace-relative tree: root is `""`, a child is `parent/name`.
/// The root stays expanded; only descendant directories toggle.
public struct FileTreeState: Equatable, Sendable {
    public var levels: [String: FileTreeLevel]
    public var expanded: Set<String>

    public init(levels: [String: FileTreeLevel] = [:], expanded: Set<String> = [""]) {
        self.levels = levels
        self.expanded = expanded
    }

    public static var root: FileTreeState { FileTreeState() }
}

public enum FileTreeRowKind: Equatable, Sendable {
    case directory(expanded: Bool)
    case file
    case other
    case loading
    case empty
    case truncated
    case failed
}

/// Flattened row for an in-place tree. Indent is `depth` steps.
public struct FileTreeRow: Equatable, Sendable, Identifiable {
    public var path: String
    public var name: String
    public var type: String
    public var depth: Int
    public var kind: FileTreeRowKind
    public var message: String?

    public init(
        path: String,
        name: String,
        type: String,
        depth: Int,
        kind: FileTreeRowKind,
        message: String? = nil
    ) {
        self.path = path
        self.name = name
        self.type = type
        self.depth = depth
        self.kind = kind
        self.message = message
    }

    public var id: String {
        switch kind {
        case .loading: return "\(path)|loading"
        case .empty: return "\(path)|empty"
        case .truncated: return "\(path)|truncated"
        case .failed: return "\(path)|failed"
        default: return path
        }
    }

    public var isDirectory: Bool {
        if case .directory = kind { return true }
        return false
    }
}

public func fileTreeChildPath(parent: String, name: String) -> String {
    parent.isEmpty ? name : "\(parent)/\(name)"
}

public func fileTreeToggle(_ state: inout FileTreeState, path: String) {
    if path.isEmpty { return }
    if state.expanded.contains(path) {
        state.expanded.remove(path)
        return
    }
    state.expanded.insert(path)
    if state.levels[path] == nil {
        state.levels[path] = .loading
    }
}

/// Mark a level loading only when it has no ready cache (desktop `actions.loading`).
public func fileTreeMarkLoading(_ state: inout FileTreeState, path: String) {
    switch state.levels[path] {
    case .ready:
        return
    case .failed, .loading, nil:
        state.levels[path] = .loading
    }
}

public func fileTreeApplyListing(
    _ state: inout FileTreeState,
    path: String,
    entries: [WorkspaceFileEntry],
    truncated: Bool
) {
    if case .ready(let previous, _, _) = state.levels[path] {
        let nextNames = Set(previous.filter(\.isDirectory).map(\.name))
        let keep = Set(entries.filter(\.isDirectory).map(\.name))
        for name in nextNames where !keep.contains(name) {
            let removed = fileTreeChildPath(parent: path, name: name)
            state.expanded = Set(state.expanded.filter { $0 != removed && !$0.hasPrefix(removed + "/") })
            state.levels = state.levels.filter { $0.key != removed && !$0.key.hasPrefix(removed + "/") }
        }
    }
    state.levels[path] = .ready(entries: entries, truncated: truncated, failure: nil)
}

public func fileTreeApplyFailure(_ state: inout FileTreeState, path: String, message: String) {
    if case .ready(let entries, let truncated, _) = state.levels[path] {
        state.levels[path] = .ready(entries: entries, truncated: truncated, failure: message)
        return
    }
    state.levels[path] = .failed(message)
}

/// Drop cached listings and keep the expanded set (manual reload first half).
public func fileTreeResetListings(_ state: inout FileTreeState) {
    state.levels = [:]
}

public func fileTreeVisibleRows(_ state: FileTreeState) -> [FileTreeRow] {
    fileTreeVisibleRows(state, path: "", depth: 0)
}

private func fileTreeVisibleRows(_ state: FileTreeState, path: String, depth: Int) -> [FileTreeRow] {
    guard let level = state.levels[path] else {
        return [FileTreeRow(path: path, name: "", type: "", depth: depth, kind: .loading)]
    }
    switch level {
    case .loading:
        return [FileTreeRow(path: path, name: "", type: "", depth: depth, kind: .loading)]
    case .failed(let message):
        return [FileTreeRow(path: path, name: "", type: "", depth: depth, kind: .failed, message: message)]
    case .ready(let entries, let truncated, let failure):
        var rows: [FileTreeRow] = []
        if let failure {
            rows.append(FileTreeRow(path: path, name: "", type: "", depth: depth, kind: .failed, message: failure))
        }
        if entries.isEmpty {
            rows.append(FileTreeRow(path: path, name: "", type: "", depth: depth, kind: .empty))
        }
        for entry in fileTreeOrderEntries(entries) {
            let child = fileTreeChildPath(parent: path, name: entry.name)
            if entry.isDirectory {
                let expanded = state.expanded.contains(child)
                rows.append(
                    FileTreeRow(
                        path: child,
                        name: entry.name,
                        type: entry.type,
                        depth: depth,
                        kind: .directory(expanded: expanded)
                    )
                )
                if expanded {
                    rows.append(contentsOf: fileTreeVisibleRows(state, path: child, depth: depth + 1))
                }
            } else if entry.isFile {
                rows.append(
                    FileTreeRow(
                        path: child,
                        name: entry.name,
                        type: entry.type,
                        depth: depth,
                        kind: .file
                    )
                )
            } else {
                rows.append(
                    FileTreeRow(
                        path: child,
                        name: entry.name,
                        type: entry.type,
                        depth: depth,
                        kind: .other
                    )
                )
            }
        }
        if truncated {
            rows.append(FileTreeRow(path: path, name: "", type: "", depth: depth, kind: .truncated))
        }
        return rows
    }
}

/// Desktop `Intl.Collator({ numeric: true, sensitivity: 'base' })`: directories
/// first, then Finder-style numeric names (`file2` before `file10`).
public func fileTreeOrderEntries(_ entries: [WorkspaceFileEntry]) -> [WorkspaceFileEntry] {
    entries.sorted {
        if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
        return $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
}
