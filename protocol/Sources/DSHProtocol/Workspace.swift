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

/// One item in a Host `workspace/session-active` activity family.
public struct ArchiveActivityItem: Equatable, Sendable {
    public var id: String
    public var label: String?

    public init(id: String, label: String? = nil) {
        self.id = id
        self.label = label
    }
}

/// Desktop `ui-workspace` `ArchiveConfirmForm` activity family.
public struct ArchiveActivityEntry: Equatable, Sendable {
    public var kind: String
    public var items: [ArchiveActivityItem]

    public init(kind: String, items: [ArchiveActivityItem] = []) {
        self.kind = kind
        self.items = items
    }
}

/// Desktop reads `rpcError.details.activity` from `workspace/session-active`.
public func archiveSessionActiveActivity(_ details: JSONValue?) -> [ArchiveActivityEntry] {
    (details?["activity"].arr() ?? []).map { activity in
        ArchiveActivityEntry(
            kind: activity["kind"].str() ?? "",
            items: (activity["items"].arr() ?? []).map { item in
                ArchiveActivityItem(id: item["id"].str() ?? "", label: item["label"].str())
            }
        )
    }
}

/// Desktop `archive.confirm.listSeparator`.
public func archiveConfirmListSeparator(english: Bool) -> String {
    english ? ", " : "、"
}

/// Desktop `ArchiveSession.activityLine`.
public func archiveConfirmActivityLine(_ entry: ArchiveActivityEntry, english: Bool) -> String {
    let n = entry.items.count
    let names = entry.items.map { $0.label ?? $0.id }.joined(separator: archiveConfirmListSeparator(english: english))
    let one = n == 1
    switch entry.kind {
    case "turn":
        return english ? "The turn in progress" : "进行中的回合"
    case "subagent":
        if english {
            return one ? "\(n) running subagent: \(names)" : "\(n) running subagents: \(names)"
        }
        return "\(n) 个运行中的子智能体：\(names)"
    case "job":
        if english {
            return one ? "\(n) background job: \(names)" : "\(n) background jobs: \(names)"
        }
        return "\(n) 个后台任务：\(names)"
    case "schedule":
        if english {
            return one ? "\(n) scheduled reminder: \(names)" : "\(n) scheduled reminders: \(names)"
        }
        return "\(n) 条定时提醒：\(names)"
    default:
        if english {
            return one
                ? "\(n) other item of work (\(entry.kind))"
                : "\(n) other items of work (\(entry.kind))"
        }
        return "\(n) 项其他工作（\(entry.kind)）"
    }
}

/// Desktop `archive.confirm.title`.
public func archiveConfirmTitle(english: Bool) -> String {
    english ? "Stop and archive this session?" : "停止并归档此会话？"
}

/// Desktop `archive.confirm.desc`.
public func archiveConfirmDescription(title: String, english: Bool) -> String {
    if english {
        return "“\(title)” still has work in progress. Archiving stops it first; you can restore the session later from the “All conversations (show archived)” filter in the sidebar, and the stopped work will not resume on its own."
    }
    return "“\(title)”仍有正在进行的工作。归档会先停止这些工作；之后可在侧栏筛选“全部对话（显示已归档）”中恢复会话，被停止的工作不会自动继续。"
}

/// Desktop `archive.confirm.activity`.
public func archiveConfirmActivityLabel(english: Bool) -> String {
    english ? "Work that will be stopped" : "将被停止的工作"
}

/// Desktop `archive.confirm.action`.
public func archiveConfirmAction(english: Bool) -> String {
    english ? "Stop and archive" : "停止并归档"
}

/// Desktop `archive.confirm.pending`.
public func archiveConfirmPending(english: Bool) -> String {
    english ? "Stopping and archiving…" : "正在停止并归档…"
}

/// Desktop `toast.archived` / `toast.stoppedAndArchived` + undo + or + filter.
public func archiveSuccessToast(stopped: Bool, english: Bool) -> String {
    let head: String
    if stopped {
        head = english ? "Session stopped and archived. You can " : "已停止并归档，可"
    } else {
        head = english ? "Session archived. You can " : "会话已归档，可"
    }
    let undo = english ? "undo" : "撤销"
    let or = english ? " or " : "或"
    let filter = english ? "filter archived sessions" : "筛选已归档会话"
    return head + undo + or + filter
}

/// Official activity lines, joined for the confirm body (not a toast).
public func archiveActivityDescription(_ details: JSONValue?, english: Bool) -> String {
    archiveSessionActiveActivity(details)
        .map { archiveConfirmActivityLine($0, english: english) }
        .joined(separator: "\n")
}

/// Host `workspace/session-active` must open the confirm dialog, not a toast.
public let archiveSessionActiveOpensConfirm = true

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
        return $0.name.localizedStandardCompare($1.name) == .orderedAscending
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
