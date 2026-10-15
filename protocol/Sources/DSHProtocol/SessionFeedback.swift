/// Session-level feedback (`sessionFeedback.record`). Blank `text` is omitted, never sent as "".
public enum SessionFeedbackRequest {
    public static func args(sessionId: String, category: String?, note: String) -> JSONValue {
        var object: [String: JSONValue] = ["sessionId": .string(sessionId)]
        if let category, !category.isEmpty { object["category"] = .string(category) }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { object["text"] = .string(text) }
        return .object(object)
    }

    public static func recorded(_ result: JSONValue) throws {
        guard result["recorded"].bool() == true else {
            throw PocketError(code: "bad-reply", message: "Feedback was not recorded")
        }
    }
}

/// Official header ⋯ rows. Export is always listed; feedback is ops-gated.
public enum MoreSheetPolicy {
    public static func showsFeedback(ops: Set<String>) -> Bool {
        ops.contains("sessionFeedback.record")
    }

    public static func exportEnabled(online: Bool, ops: Set<String>, inChat: Bool) -> Bool {
        online && ops.contains("session.export") && inChat
    }

    public static func feedbackEnabled(inChat: Bool) -> Bool {
        inChat
    }

    public static func showsFork(ops: Set<String>, inChat: Bool) -> Bool {
        ops.contains("sessions.fork") && inChat
    }
}
