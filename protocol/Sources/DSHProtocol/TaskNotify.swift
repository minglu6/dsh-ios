/// Minimal host task event. The phone builds notification text locally.
/// Port of Android `TaskEvent` / `TaskNotifyTexts`.
public struct TaskEvent: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case done
        case question
    }

    public var kind: Kind
    public var sessionId: String
    public var turn: Int64
    public var questionId: String?

    public init(kind: Kind, sessionId: String, turn: Int64 = 0, questionId: String? = nil) {
        self.kind = kind
        self.sessionId = sessionId
        self.turn = turn
        self.questionId = questionId
    }

    public static func parse(_ value: JSONValue) -> TaskEvent? {
        guard let sessionId = value["sessionId"].str()?.nilIfBlank else { return nil }
        let kind: Kind
        switch value["kind"].str() {
        case "done": kind = .done
        case "question": kind = .question
        default: return nil
        }
        return TaskEvent(
            kind: kind,
            sessionId: sessionId,
            turn: value["turn"].long() ?? 0,
            questionId: value["questionId"].str()
        )
    }
}

public enum TaskNotifyTexts {
    public static func title(_ kind: TaskEvent.Kind, english: Bool = false) -> String {
        switch kind {
        case .done: return english ? "Task finished" : "任务已完成"
        case .question: return english ? "Input needed" : "需要你确认"
        }
    }

    public static func body(_ kind: TaskEvent.Kind, sessionTitle: String?, english: Bool = false) -> String {
        let label = sessionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch kind {
        case .done:
            if label.isEmpty { return english ? "Your DSH task finished" : "你的 DSH 任务已完成" }
            return english ? "Your DSH task finished: \(label)" : "你的 DSH 任务已完成：\(label)"
        case .question:
            if label.isEmpty { return english ? "Waiting for your answer" : "等待你的回答" }
            return english ? "\(label) — waiting for your answer" : "\(label) — 等待你的回答"
        }
    }

    /// Stable notification tag so concurrent sessions keep separate entries.
    public static func tag(_ event: TaskEvent) -> String {
        switch event.kind {
        case .done: return "dsh-task-done-\(event.sessionId)-\(event.turn)"
        case .question: return "dsh-task-question-\(event.questionId ?? event.sessionId)"
        }
    }
}

public enum ApprovalNotifyTexts {
    public static func title(toolName: String, english: Bool = false) -> String {
        english
            ? "Tool \(toolName) requests elevated permission"
            : "工具 \(toolName) 请求越权执行"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
