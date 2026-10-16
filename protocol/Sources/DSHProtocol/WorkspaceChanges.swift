import Foundation

/// Files remain in Host order: their list index identifies the corresponding diff.
public struct WorkspaceChangedFile: Sendable, Equatable {
    public var path: String
    public var display: String
    public var added: Int
    public var deleted: Int
    public var binary: Bool
    public var oversized: Bool

    public init(
        path: String,
        display: String,
        added: Int,
        deleted: Int,
        binary: Bool = false,
        oversized: Bool = false
    ) {
        self.path = path
        self.display = display
        self.added = added
        self.deleted = deleted
        self.binary = binary
        self.oversized = oversized
    }
}

public struct WorkspaceChangesSummary: Sendable, Equatable {
    public var turn: Int
    public var cwd: String
    public var files: [WorkspaceChangedFile]
    public var total: Int
    public var added: Int
    public var deleted: Int

    public init(
        turn: Int,
        cwd: String,
        files: [WorkspaceChangedFile],
        total: Int,
        added: Int,
        deleted: Int
    ) {
        self.turn = turn
        self.cwd = cwd
        self.files = files
        self.total = total
        self.added = added
        self.deleted = deleted
    }

    public static func parse(_ value: JSONValue?) -> WorkspaceChangesSummary? {
        guard let object = value?.obj() else { return nil }
        // Desktop `isChangesSummary`: turn >= 1; HTTP omits Host-only `cwd` / snapshot ids.
        guard let turn = object["turn"]?.changeCount(), turn >= 1 else { return nil }
        let cwd: String
        if let raw = object["cwd"], !raw.isNull {
            guard let directory = raw.str() else { return nil }
            cwd = directory
        } else {
            cwd = ""
        }
        guard let total = object["total"]?.changeCount(), total > 0 else { return nil }
        guard let added = object["added"]?.changeCount() else { return nil }
        guard let deleted = object["deleted"]?.changeCount() else { return nil }
        guard let entries = object["files"]?.arr() else { return nil }
        if entries.count > total { return nil }
        var files: [WorkspaceChangedFile] = []
        files.reserveCapacity(entries.count)
        // Never drop malformed entries: doing so would shift every later Host diff index.
        for entry in entries {
            guard let file = entry.obj() else { return nil }
            guard let path = file["path"]?.str() else { return nil }
            guard let display = file["display"]?.str() else { return nil }
            guard let fileAdded = file["added"]?.changeCount() else { return nil }
            guard let fileDeleted = file["deleted"]?.changeCount() else { return nil }
            let binary: Bool
            if file["binary"] != nil {
                guard let value = file["binary"]?.bool() else { return nil }
                binary = value
            } else {
                binary = false
            }
            let oversized: Bool
            if file["oversized"] != nil {
                guard let value = file["oversized"]?.bool() else { return nil }
                oversized = value
            } else {
                oversized = false
            }
            files.append(WorkspaceChangedFile(
                path: path, display: display, added: fileAdded, deleted: fileDeleted,
                binary: binary, oversized: oversized
            ))
        }
        return WorkspaceChangesSummary(turn: turn, cwd: cwd, files: files, total: total, added: added, deleted: deleted)
    }
}

public struct WorkspaceDiffHunk: Sendable, Equatable {
    public var oldStart: Int
    public var newStart: Int
    public var lines: [String]

    public init(oldStart: Int, newStart: Int, lines: [String]) {
        self.oldStart = oldStart
        self.newStart = newStart
        self.lines = lines
    }
}

public struct WorkspaceFileDiff: Sendable, Equatable {
    public var kind: String
    public var path: String
    public var display: String
    public var before: Bool
    public var after: Bool
    public var hunks: [WorkspaceDiffHunk]
    public var coarse: Bool

    public init(
        kind: String,
        path: String,
        display: String,
        before: Bool = true,
        after: Bool = true,
        hunks: [WorkspaceDiffHunk] = [],
        coarse: Bool = false
    ) {
        self.kind = kind
        self.path = path
        self.display = display
        self.before = before
        self.after = after
        self.hunks = hunks
        self.coarse = coarse
    }

    public static func parse(_ value: JSONValue?) -> WorkspaceFileDiff? {
        guard let object = value?.obj() else { return nil }
        guard let kind = object["kind"]?.str() else { return nil }
        guard let path = object["path"]?.str() else { return nil }
        guard let display = object["display"]?.str() else { return nil }
        if kind == "binary" || kind == "oversized" {
            return WorkspaceFileDiff(kind: kind, path: path, display: display)
        }
        guard kind == "text" else { return nil }
        guard let before = object["before"]?.bool() else { return nil }
        guard let after = object["after"]?.bool() else { return nil }
        guard let coarse = object["coarse"]?.bool() else { return nil }
        guard let hunkValues = object["hunks"]?.arr() else { return nil }
        var hunks: [WorkspaceDiffHunk] = []
        for hunk in hunkValues {
            guard let oldStart = hunk["oldStart"].changeCount() else { return nil }
            guard let newStart = hunk["newStart"].changeCount() else { return nil }
            guard let lineValues = hunk["lines"].arr() else { return nil }
            var lines: [String] = []
            for line in lineValues {
                guard let text = line.str() else { return nil }
                lines.append(text)
            }
            hunks.append(WorkspaceDiffHunk(oldStart: oldStart, newStart: newStart, lines: lines))
        }
        return WorkspaceFileDiff(
            kind: kind, path: path, display: display, before: before, after: after, hunks: hunks, coarse: coarse
        )
    }
}

public struct ChangeDiffLine: Sendable, Equatable {
    public var old: Int?
    public var new: Int?
    public var text: String

    public init(old: Int?, new: Int?, text: String) {
        self.old = old
        self.new = new
        self.text = text
    }
}

public func changeDiffLines(_ diff: WorkspaceFileDiff) -> [ChangeDiffLine] {
    var out: [ChangeDiffLine] = []
    for hunk in diff.hunks {
        var old = hunk.oldStart
        var new = hunk.newStart
        for line in hunk.lines {
            if out.count >= 5000 { return out }
            switch line.first {
            case "+":
                out.append(ChangeDiffLine(old: nil, new: new, text: line))
                new += 1
            case "-":
                out.append(ChangeDiffLine(old: old, new: nil, text: line))
                old += 1
            default:
                out.append(ChangeDiffLine(old: old, new: new, text: line))
                old += 1
                new += 1
            }
        }
    }
    return out
}

public func workspaceChangesSummaryArgs(sessionId: String, seq: Int64) -> JSONValue {
    jsonObject(["sessionId": .string(sessionId), "seq": .number(Double(seq))])
}

public func workspaceChangesDiffArgs(sessionId: String, seq: Int64, index: Int) -> JSONValue {
    jsonObject([
        "sessionId": .string(sessionId),
        "seq": .number(Double(seq)),
        "index": .number(Double(index)),
    ])
}

extension JSONValue {
    /// Host change counts are 32-bit non-negative integers, never JSON strings.
    func changeCount() -> Int? {
        guard case .number(let value) = self, value.isFinite, value.rounded() == value,
              value >= 0, value <= Double(Int32.max) else { return nil }
        return Int(value)
    }
}
