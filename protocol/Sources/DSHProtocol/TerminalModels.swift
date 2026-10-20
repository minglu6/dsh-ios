import Foundation

public struct TerminalMeta: Sendable, Equatable {
    public var sessionId: String
    public var id: String
    public var attachmentId: String
    public var title: String?
    public var state: String?
    public var cwd: String?

    public init(
        sessionId: String,
        id: String,
        attachmentId: String,
        title: String? = nil,
        state: String? = nil,
        cwd: String? = nil
    ) {
        self.sessionId = sessionId
        self.id = id
        self.attachmentId = attachmentId
        self.title = title
        self.state = state
        self.cwd = cwd
    }
}

public struct TerminalSessionCatalog: Sendable, Equatable {
    public var entries: [TerminalSessionEntry]
    public var platform: String?

    public init(entries: [TerminalSessionEntry], platform: String? = nil) {
        self.entries = entries
        self.platform = platform
    }
}

public struct TerminalSessionEntry: Sendable, Equatable, Identifiable {
    public var sessionId: String
    public var id: String
    public var title: String?
    public var state: String?
    public var cwd: String?
    /// Host `WebTerminalInfo.shell.name`. Plugin `terminal.list` forwards the
    /// full info object; desktop tab chrome uses `info.title` (created as
    /// `shell.name`) and never this field on its own.
    public var shellName: String?

    public var sessionTerminalKey: String { "\(sessionId)\t\(id)" }

    public init(
        sessionId: String,
        id: String,
        title: String? = nil,
        state: String? = nil,
        cwd: String? = nil,
        shellName: String? = nil
    ) {
        self.sessionId = sessionId
        self.id = id
        self.title = title
        self.state = state
        self.cwd = cwd
        self.shellName = shellName
    }

    public static func parse(sessionId: String, value: JSONValue) throws -> TerminalSessionEntry {
        guard let id = value["id"].str()?.nilIfBlank else {
            throw PocketError(code: "bad-reply", message: "no terminal id")
        }
        return TerminalSessionEntry(
            sessionId: sessionId,
            id: id,
            title: value["title"].str(),
            state: value["state"].str(),
            cwd: value["cwd"].str(),
            shellName: value["shell"]["name"].str()
        )
    }
}

/// Missing explicit/saved identities never silently become a different shell.
public func selectTerminal(
    entries: [TerminalSessionEntry],
    savedId: String?,
    explicitId: String?
) throws -> TerminalSessionEntry? {
    let preferred = explicitId ?? savedId
    if let preferred {
        if let found = entries.first(where: { $0.id == preferred }) { return found }
        throw PocketError(
            code: "terminal/unavailable",
            message: "终端已退出或已由远程主机回收，请选择其他会话或新建"
        )
    }
    return entries.first(where: { $0.state == "running" }) ?? entries.first
}

/// Identities are discovery hints only; the Host remains authoritative for process lifetime.
public struct SavedTerminalOwner: Codable, Equatable, Sendable {
    public var sessionId: String
    public var ids: [String]
    public var selectedId: String?

    public init(sessionId: String, ids: [String] = [], selectedId: String? = nil) {
        self.sessionId = sessionId
        self.ids = ids
        self.selectedId = selectedId
    }
}

public enum TerminalIdentityStore {
    public static func record(
        owners: [SavedTerminalOwner],
        sessionId: String,
        terminalId: String,
        selected: Bool
    ) -> [SavedTerminalOwner] {
        let owner = owners.first { $0.sessionId == sessionId } ?? SavedTerminalOwner(sessionId: sessionId)
        let next = SavedTerminalOwner(
            sessionId: sessionId,
            ids: (owner.ids + [terminalId]).uniqued(),
            selectedId: selected ? terminalId : owner.selectedId
        )
        return owners.filter { $0.sessionId != sessionId } + [next]
    }

    public static func reconcile(
        owners: [SavedTerminalOwner],
        sessionId: String,
        ids: [String]
    ) -> [SavedTerminalOwner] {
        let selected = owners.first { $0.sessionId == sessionId }?.selectedId.flatMap { ids.contains($0) ? $0 : nil }
        let rest = owners.filter { $0.sessionId != sessionId }
        if ids.isEmpty { return rest }
        return rest + [SavedTerminalOwner(sessionId: sessionId, ids: ids.uniqued(), selectedId: selected)]
    }

    public static func forget(
        owners: [SavedTerminalOwner],
        sessionId: String,
        terminalId: String
    ) -> [SavedTerminalOwner] {
        guard let owner = owners.first(where: { $0.sessionId == sessionId }) else { return owners }
        return reconcile(owners: owners, sessionId: sessionId, ids: owner.ids.filter { $0 != terminalId })
    }
}

/// UIKeyInput supplies committed text, not the entire contents of an editing buffer.
/// Normalize pasted CRLF as one Return; backspace is a separate key event.
public func terminalInputText(_ text: String) -> String {
    text.replacingOccurrences(of: "\r\n", with: "\r").replacingOccurrences(of: "\n", with: "\r")
}

/// Screen coordinates belong to the Host frame's dimensions, not the current
/// phone viewport. Apply size changes in stream order before subsequent output.
public func applyTerminalScreenFrame(_ frame: JSONValue, to terminal: AnsiTerminal) {
    switch frame["type"].str() {
    case "snapshot":
        terminal.clear()
        terminal.resize(
            newCols: frame["info"]["cols"].int() ?? terminal.cols,
            newRows: frame["info"]["rows"].int() ?? terminal.rows
        )
        terminal.write(frame["screen"].str() ?? "")
    case "state":
        if let cols = frame["info"]["cols"].int(), let rows = frame["info"]["rows"].int() {
            terminal.resize(newCols: cols, newRows: rows)
        }
    case "output":
        terminal.write(frame["data"].str() ?? "")
    default:
        break
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
