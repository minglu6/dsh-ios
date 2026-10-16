import Foundation

/// Stale drawer rows: Host `follow` / `goals.get` / `follow.error` may return
/// `session/not-found` after the list still shows the Session. Desktop drops the
/// row (or refreshes `sessions.list`) and clears the main selection — it does
/// not toast the wire code.
public enum SessionNotFoundPolicy {
    public static let code = "session/not-found"
    public static let hyphenCode = "session-not-found"

    public static func matches(_ error: Error) -> Bool {
        if let pocket = error as? PocketError {
            return matches(code: pocket.code, message: pocket.message)
        }
        return matches(code: nil, message: error.localizedDescription)
    }

    public static func matches(code: String?, message: String? = nil) -> Bool {
        [code, message].compactMap { $0 }.contains { token in
            isNotFoundToken(token)
        }
    }

    /// Remove the missing Session. If it was current, the next current id is nil
    /// (desktop `sessions.clear()`), never a silent jump to another row.
    public static func drop(
        missingId: String,
        from sessions: [SessionSummary],
        currentId: String?
    ) -> DroppedSession {
        DroppedSession(
            sessions: sessions.filter { $0.sessionId != missingId },
            currentId: currentId == missingId ? nil : currentId,
            droppedCurrent: currentId == missingId
        )
    }

    public static func drop(sessionId: String, from workspaces: [WorkspaceView]) -> [WorkspaceView] {
        workspaces.map { workspace in
            var next = workspace
            next.sessionIds = workspace.sessionIds.filter { $0 != sessionId }
            return next
        }
    }

    public struct DroppedSession: Equatable, Sendable {
        public var sessions: [SessionSummary]
        public var currentId: String?
        public var droppedCurrent: Bool

        public init(sessions: [SessionSummary], currentId: String?, droppedCurrent: Bool) {
            self.sessions = sessions
            self.currentId = currentId
            self.droppedCurrent = droppedCurrent
        }
    }

    private static func isNotFoundToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == code || trimmed == hyphenCode { return true }
        if trimmed.hasPrefix("\(code):") || trimmed.hasPrefix("\(hyphenCode):") { return true }
        return false
    }
}
