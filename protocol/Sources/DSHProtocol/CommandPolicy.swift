import Foundation

public struct CommandEntry: Equatable, Sendable, Identifiable {
    public var name: String
    public var description: String?
    public var definitionId: String?
    public var id: String { definitionId ?? name }

    public static func parse(_ element: JSONValue) -> CommandEntry? {
        guard let name = element["name"].str(), !name.isEmpty else { return nil }
        return CommandEntry(
            name: name,
            description: element["description"].str(),
            definitionId: element["definitionId"].str()
        )
    }
}

public func builtinCommandName(_ definitionId: String?) -> String? {
    switch definitionId {
    case "@deepseek-ai/dsh-command-goal": return "goal"
    case "@deepseek-ai/dsh-plan-mode": return "plan"
    case "@deepseek-ai/dsh-command-feedback": return "feedback"
    case "@deepseek-ai/dsh-command-compact": return "compact"
    case "@deepseek-ai/dsh-permission-presets": return "permission"
    case "@deepseek-ai/dsh-session-log-export": return "export"
    default: return nil
    }
}

public func todoProgressLabel(_ todos: [TodoItem], en: Bool) -> String {
    var done = 0
    var active = 0
    var pending = 0
    for item in todos {
        switch item.status {
        case "completed": done += 1
        case "in_progress": active += 1
        default: pending += 1
        }
    }
    var parts: [String] = []
    if done > 0 { parts.append("\(done) \(en ? "completed" : "已完成")") }
    if active > 0 { parts.append("\(active) \(en ? "in progress" : "进行中")") }
    if pending > 0 { parts.append("\(pending) \(en ? "pending" : "待处理")") }
    return parts.joined(separator: "\u{2002}·\u{2002}")
}

public func goalPhaseLabel(phase: String?, activation: String?) -> String {
    switch phase {
    case "active": return activation == "disarmed" ? "已暂停的目标" : "进行中的目标"
    case "paused": return "已暂停的目标"
    case "blocked": return "受阻的目标"
    case "complete": return "已完成的目标"
    default: return "目标状态未知"
    }
}

public func permissionLabel(value: String, option: PermissionOption? = nil) -> String {
    if value == "auto" { return "自动审查" }
    let name = option?.name ?? value
    let builtIn: (String, String)?
    switch value {
    case "read-only": builtIn = ("Read Only", "仅可查看")
    case "workspace-write": builtIn = ("Workspace Write", "工作区内修改")
    case "danger-full-access": builtIn = ("Full access", "完全权限")
    default: builtIn = nil
    }
    if let builtIn, name == value || name == builtIn.0 { return builtIn.1 }
    return name
}

public func queueUpdateArgs(sessionId: String, itemId: String, action: QueueAction) -> JSONValue {
    var actionObject: [String: JSONValue]
    switch action {
    case .edit(let text):
        actionObject = [
            "kind": .string("edit"),
            "content": .array([.object(["type": .string("text"), "text": .string(text)])]),
        ]
    case .remove:
        actionObject = ["kind": .string("remove")]
    case .steer:
        actionObject = ["kind": .string("steer")]
    }
    return .object([
        "sessionId": .string(sessionId),
        "itemId": .string(itemId),
        "action": .object(actionObject),
    ])
}

public func userQuestionAnswerArgs(sessionId: String, callId: String, answers: [JSONValue]) -> JSONValue {
    .object([
        "sessionId": .string(sessionId),
        "callId": .string(callId),
        "answers": .object(["answers": .array(answers)]),
    ])
}

public func goalMutationArgs(sessionId: String, ref: JSONValue, objective: String? = nil) -> JSONValue {
    jsonObject([
        "sessionId": .string(sessionId),
        "ref": ref,
        "request": jsonObject(["objective": objective.map { .string($0) }]),
    ])
}

public struct UploadReceipt: Equatable, Sendable {
    public var receiptId: String
    public var name: String?
    public var attachmentId: String?

    public static func parse(_ element: JSONValue) -> UploadReceipt? {
        guard let id = element["receiptId"].str() else { return nil }
        return UploadReceipt(
            receiptId: id,
            name: element["file"]["name"].str() ?? element["name"].str(),
            attachmentId: element["file"]["attachmentId"].str()
        )
    }
}
