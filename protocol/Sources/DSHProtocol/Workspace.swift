import Foundation

public struct WorkspaceBranch: Equatable, Sendable {
    public var path: String
    public var children: [WorkspaceBranch]

    public init(path: String, children: [WorkspaceBranch] = []) {
        self.path = path
        self.children = children
    }
}

/// Match the desktop's automatic title; paths remain unchanged for Host operations.
public func workspaceDisplayTitle(
    title: String?,
    path: String,
    localizedDefault: String
) -> String {
    let label = title?.nilIfBlank
        ?? path.trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
            .split(whereSeparator: { $0 == "/" || $0 == "\\" })
            .last
            .map(String.init)
            .flatMap { $0.isEmpty ? nil : $0 }
        ?? path
    return label == "default-workspace" ? localizedDefault : label
}

/// Host paths are identities, never their display basenames. Preserve absent cwd as ungrouped.
public func workspacePathKey(_ path: String?) -> String {
    guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
    let trimmed = path.hasSuffix("/") && path != "/" ? String(path.dropLast()) : path
    return trimmed.isEmpty ? "/" : trimmed
}

/// A path-segment tree, so /a/project never absorbs /b/project or /a/project-other.
public func workspaceBranches(_ paths: [String]) -> [WorkspaceBranch] {
    let keys = paths.map(workspacePathKey).filter { !$0.isEmpty }.uniquedPreservingOrder()
    func children(_ parent: String?) -> [WorkspaceBranch] {
        keys.filter { path in
            let ancestor = keys
                .filter { $0 != path && path.hasPrefix($0 == "/" ? $0 : "\($0)/") }
                .max(by: { $0.count < $1.count })
            return ancestor == parent
        }.map { WorkspaceBranch(path: $0, children: children($0)) }
    }
    return children(nil)
}

public func visibleDrawerSession(
    _ session: SessionSummary,
    current: String?,
    archived: Set<String>,
    filter: WorkspaceArchivedFilter
) -> Bool {
    if session.origin == "subagent" { return false }
    if session.blank && session.sessionId != current { return false }
    switch filter {
    case .hide: return !archived.contains(session.sessionId) && session.archived != true
    case .show: return true
    case .only: return archived.contains(session.sessionId) || session.archived == true
    }
}

public enum WorkspaceArchivedFilter: String, Sendable {
    case hide, show, only
}

/// Host archive-activity refusal details (`workspace/session-active`).
public func archiveActivityDescription(_ details: JSONValue?, english: Bool) -> String {
    (details?["activity"].arr() ?? []).map { activity in
        let kind = activity["kind"].str() ?? ""
        let family: String
        switch kind {
        case "turn": family = english ? "Turn in progress" : "进行中的回合"
        case "subagent": family = english ? "Subagents" : "子智能体"
        case "job": family = english ? "Background jobs" : "后台任务"
        case "schedule": family = english ? "Scheduled reminders" : "定时提醒"
        default: family = kind
        }
        let names = (activity["items"].arr() ?? []).compactMap { $0["label"].str() ?? $0["id"].str() }
        return names.isEmpty ? family : "\(family): \(names.joined(separator: ", "))"
    }.joined(separator: "\n")
}

/// Keep hidden archives in the same order account; insert ordinary forks before their source.
public func reconcileSessionOrder(sessions: [SessionSummary], saved: [String]) -> [String] {
    let members = Dictionary(uniqueKeysWithValues: sessions.map { ($0.sessionId, $0) })
    var order = saved.filter { members[$0] != nil }.uniquedPreservingOrder()
    let missing = sessions.sorted { $0.updatedAt > $1.updatedAt }.filter { !order.contains($0.sessionId) }
    func insert(_ session: SessionSummary, visiting: Set<String>) {
        if order.contains(session.sessionId) { return }
        if let parentId = session.parentSessionId, let parent = members[parentId],
           !visiting.contains(parent.sessionId), !order.contains(parent.sessionId) {
            insert(parent, visiting: visiting.union([session.sessionId]))
        }
        if let at = session.parentSessionId.flatMap({ order.firstIndex(of: $0) }), session.origin != "subagent" {
            order.insert(session.sessionId, at: at)
        } else {
            order.append(session.sessionId)
        }
    }
    missing.forEach { insert($0, visiting: []) }
    return order
}

public struct WorkspaceDirectoryEntry: Equatable, Sendable, Identifiable {
    public var name: String
    public var path: String
    public var hidden: Bool
    public var id: String { path }

    public init(name: String, path: String, hidden: Bool) {
        self.name = name
        self.path = path
        self.hidden = hidden
    }
}

public struct WorkspaceDirectoryLevel: Equatable, Sendable {
    public var path: String
    public var home: String
    public var crumbs: [WorkspaceDirectoryEntry]
    public var entries: [WorkspaceDirectoryEntry]
    public var truncated: Bool

    public init(
        path: String,
        home: String,
        crumbs: [WorkspaceDirectoryEntry],
        entries: [WorkspaceDirectoryEntry],
        truncated: Bool
    ) {
        self.path = path
        self.home = home
        self.crumbs = crumbs
        self.entries = entries
        self.truncated = truncated
    }

    public var separator: Character { home.contains("\\") ? "\\" : "/" }
    public var directory: String { path.hasSuffix(String(separator)) ? path : "\(path)\(separator)" }

    public func displayCrumbs() -> [WorkspaceDirectoryEntry] {
        if let index = crumbs.firstIndex(where: { $0.path == home }) {
            return Array(crumbs[index...])
        }
        return crumbs
    }

    public static func parse(_ value: JSONValue) throws -> WorkspaceDirectoryLevel {
        func entries(_ key: String) -> [WorkspaceDirectoryEntry] {
            (value[key].arr() ?? []).map { entry in
                WorkspaceDirectoryEntry(
                    name: entry["name"].str() ?? "",
                    path: entry["path"].str() ?? "",
                    hidden: entry["hidden"].bool() == true
                )
            }
        }
        guard let path = value["path"].str(), let home = value["home"].str() else {
            throw PocketError(code: "bad-reply", message: "missing directory listing")
        }
        let listed = entries("entries")
        if listed.contains(where: { $0.path.isEmpty }) {
            throw PocketError(code: "bad-reply", message: "directory entry missing path")
        }
        return WorkspaceDirectoryLevel(
            path: path,
            home: home,
            crumbs: entries("crumbs"),
            entries: listed,
            truncated: value["truncated"].bool() == true
        )
    }
}

/// Host listings use slash-separated workspace-relative paths; the root is empty.
public func workspaceFilesParentPath(_ path: String) -> String? {
    if path.isEmpty || path == "." { return nil }
    if let slash = path.lastIndex(of: "/") {
        return String(path[..<slash])
    }
    return ""
}

public func workspaceFileListIsRelative(_ path: String) -> Bool {
    if path.hasPrefix("/") || path.contains("\\") { return false }
    if path.split(separator: "/").contains("..") { return false }
    if path.count >= 2, path[path.index(path.startIndex, offsetBy: 1)] == ":" { return false }
    return true
}

public struct WorkspaceFileEntry: Equatable, Sendable, Identifiable {
    public var name: String
    public var type: String
    public var id: String { name }

    public init(name: String, type: String) {
        self.name = name
        self.type = type
    }

    public var isDirectory: Bool { type == "directory" }
    public var isFile: Bool { type == "file" }
}

public func parseWorkspaceFileEntries(_ result: JSONValue) -> [WorkspaceFileEntry] {
    (result["entries"].arr() ?? []).compactMap { entry in
        guard let name = entry["name"].str() else { return nil }
        let valid = !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\")
        return WorkspaceFileEntry(name: name, type: valid ? (entry["type"].str() ?? "other") : "other")
    }
    .sorted {
        if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
}

public func filesFailureMessage(error: Error, english: Bool) -> String {
    let code = (error as? PocketError)?.code
    switch code {
    case "workspace-file/not-found":
        return english
            ? "That directory is gone. It may have been moved or deleted."
            : "这个目录不在了。可能已被移动或删除。"
    case "workspace-file/outside-workspace":
        return english
            ? "That directory is outside the workspace, so the sidebar will not read it."
            : "这个目录在工作区之外，侧栏不会读取它。"
    case "workspace-file/not-directory":
        return english ? "That is not a directory." : "这不是一个目录。"
    default:
        let detail = error.localizedDescription
        return (english ? "Read failed: " : "读取失败：") + detail
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

private extension Array where Element: Hashable {
    func uniquedPreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
