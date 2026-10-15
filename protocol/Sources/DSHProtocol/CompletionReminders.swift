import Foundation

/// Host-owned reminders: a stale RPC response must not undo a newer pushed acknowledgement.
/// Port of Android `CompletionReminders`.
public final class CompletionReminders: @unchecked Sendable {
    public private(set) var unreadIds: Set<String> = []
    private var epoch: String?
    private var revision: Int64 = -1

    public init() {}

    public func reset() {
        epoch = nil
        revision = -1
        unreadIds = []
    }

    public func accept(_ snapshot: JSONValue) {
        guard let nextEpoch = snapshot["epoch"].str()?.nilIfBlank else { return }
        guard let nextRevision = snapshot["revision"].long(), nextRevision >= 0 else { return }
        guard let ids = snapshot["unreadIds"].arr() else { return }
        if epoch != nil && epoch != nextEpoch || nextRevision <= revision { return }
        var values = Set<String>()
        for id in ids {
            guard let value = id.str()?.nilIfBlank else { return }
            values.insert(value)
        }
        epoch = nextEpoch
        revision = nextRevision
        unreadIds = values
    }
}

public enum CompletionViewRequest {
    /// Host treats omitted `sessionId` as a different op than JSON null (not viewing).
    public static func args(sessionId: String?) -> JSONValue {
        .object(["sessionId": sessionId.map { .string($0) } ?? .null])
    }
}

/// Android `desiredViewedSession?.takeIf { it == chat && it == completionReadySession }`.
public enum CompletionViewed {
    public static func sessionId(desired: String?, chat: String?, ready: String?) -> String? {
        guard let desired, desired == chat, desired == ready else { return nil }
        return desired
    }

    /// Same client already reported this viewed value, including explicit null after the first send.
    public static func shouldSkip(sameClient: Bool, lastSession: String?, nextSession: String?) -> Bool {
        sameClient && lastSession == nextSession
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
