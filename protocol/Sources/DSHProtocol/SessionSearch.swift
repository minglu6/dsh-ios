/// Host session search + local title/path merge. Port of Android drawer search.
public enum SessionSearch {
    public static let debounceMs: Int64 = 250

    public static func args(query: String) throws -> JSONValue {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PocketError(code: "bad-request", message: "query required")
        }
        return jsonObject(["query": .string(trimmed)])
    }

    public static func parseHits(_ result: JSONValue) -> [SessionSummary] {
        (result["items"].arr() ?? []).compactMap(SessionSummary.parse)
    }

    public static func localMatches(
        sessions: [SessionSummary],
        workspaces: [WorkspaceView],
        query: String
    ) -> [SessionSummary] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func contains(_ value: String?, _ needle: String) -> Bool {
        value?.range(of: needle, options: .caseInsensitive) != nil
    }

    /// Blank query is a client-side no-op, never a Host RPC.
    public static func shouldSearchHost(query: String, ops: Set<String>) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ops.contains("sessions.search")
    }
}
