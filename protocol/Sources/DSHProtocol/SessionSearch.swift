import Foundation

/// Host session search + local title/path merge. Desktop `ui-workspace` Search:
/// local metadata matches immediately, 250 ms Host content search, cap 20,
/// failed content search keeps metadata rows with no extra warning.
public enum SessionSearch {
    public static let debounceMs: Int64 = 250
    public static let resultLimit = 20
    public static let maxQueryUtf16 = 500

    public static func sanitizeQuery(_ query: String) -> String {
        let stripped = query.replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty { return "" }
        let units = Array(stripped.utf16)
        if units.count <= maxQueryUtf16 { return stripped }
        var end = maxQueryUtf16
        if end > 0, UTF16.isTrailSurrogate(units[end]) {
            end -= 1
        }
        return String(utf16CodeUnits: Array(units.prefix(end)), count: end)
    }

    public static func args(query: String) throws -> JSONValue {
        let trimmed = sanitizeQuery(query)
        guard !trimmed.isEmpty else {
            throw PocketError(code: "bad-request", message: "query required")
        }
        return jsonObject(["query": .string(trimmed)])
    }

    public static func parseHits(_ result: JSONValue) -> [SessionSummary] {
        parse(result).items
    }

    public static func parse(_ result: JSONValue) -> (items: [SessionSummary], hasMore: Bool) {
        (
            items: (result["items"].arr() ?? []).compactMap(SessionSummary.parse),
            hasMore: result["hasMore"].bool() ?? false
        )
    }

    public static func localMatches(
        sessions: [SessionSummary],
        workspaces: [WorkspaceView],
        query: String
    ) -> [SessionSummary] {
        let needle = sanitizeQuery(query)
        if needle.isEmpty { return [] }
        return sessions.filter { session in
            contains(session.title, needle)
                || contains(session.cwd, needle)
                || workspaces.contains { workspace in
                    workspace.sessionIds.contains(session.sessionId)
                        && (contains(workspace.title, needle) || contains(workspace.path, needle))
                }
        }
    }

    public static func merge(hits: [SessionSummary], local: [SessionSummary]) -> [SessionSummary] {
        var seen = Set<String>()
        return (hits + local).filter { seen.insert($0.sessionId).inserted }
    }

    public struct Presented: Equatable, Sendable {
        public var rows: [SessionSummary]
        public var hasMore: Bool

        public init(rows: [SessionSummary], hasMore: Bool) {
            self.rows = rows
            self.hasMore = hasMore
        }
    }

    public static func present(
        hits: [SessionSummary],
        local: [SessionSummary],
        hostHasMore: Bool = false
    ) -> Presented {
        let merged = merge(hits: hits, local: local)
        if merged.count > resultLimit {
            return Presented(rows: Array(merged.prefix(resultLimit)), hasMore: true)
        }
        return Presented(rows: merged, hasMore: hostHasMore)
    }

    private static func contains(_ value: String?, _ needle: String) -> Bool {
        value?.range(of: needle, options: .caseInsensitive) != nil
    }

    /// Blank query is a client-side no-op, never a Host RPC.
    public static func shouldSearchHost(query: String, ops: Set<String>) -> Bool {
        !sanitizeQuery(query).isEmpty && ops.contains("sessions.search")
    }
}

/// History rows without a stored title use 未命名 / Untitled. Only the current
/// blank row is 「新会话」. Desktop `ui-workspace` session.new vs session.untitled.
public func drawerSessionTitle(
    _ session: SessionSummary,
    current: String?,
    newSession: String,
    untitled: String
) -> String {
    if session.blank && session.sessionId == current { return newSession }
    if let title = session.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
        return title
    }
    return untitled
}

public func sessionSearchHasMoreLabel(_ limit: Int, english: Bool) -> String {
    english
        ? "Showing the first \(limit) results. Narrow your search."
        : "仅显示前 \(limit) 条结果，请缩小搜索范围。"
}
