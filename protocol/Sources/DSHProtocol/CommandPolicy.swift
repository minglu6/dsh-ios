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

public let commandAddNames = ["file", "goal", "plan", "feedback"]
public let commandOrderedNames = commandAddNames + ["compact", "permission", "model", "export"]

/// Client-injected `/` and `+` rows. Desktop puts feedback/export here, not on a
/// conversation header ⋯ menu. Skip a kind already present from `commands.list`.
/// Landing (no session yet) still lists the same client rows a blank desktop
/// session would — `sessionReady` is only for execution, not catalog membership.
public func commandMenuClientRows(ops: Set<String>, sessionReady: Bool, subagent: Bool) -> [JSONValue] {
    var rows: [JSONValue] = []
    if ops.contains("attachments.upload") {
        rows.append(jsonObject(["name": .string("file"), "client": .string("file")]))
    }
    if !subagent && ops.contains("models.catalog") {
        rows.append(jsonObject(["name": .string("model"), "client": .string("model")]))
    }
    if ops.contains("sessionFeedback.record") {
        rows.append(jsonObject(["name": .string("feedback"), "client": .string("feedback")]))
    }
    if ops.contains("session.export") {
        rows.append(jsonObject(["name": .string("export"), "client": .string("export")]))
    }
    _ = sessionReady
    return rows
}

public func commandMenuMerge(host: [JSONValue], injected: [JSONValue]) -> [JSONValue] {
    var kinds = Set(host.compactMap(commandMenuKind))
    var names = Set(host.compactMap { $0["name"].str() })
    var result = host
    for row in injected {
        if let kind = commandMenuKind(row), kinds.contains(kind) { continue }
        if let name = row["name"].str(), names.contains(name) { continue }
        result.append(row)
        if let kind = commandMenuKind(row) { kinds.insert(kind) }
        if let name = row["name"].str() { names.insert(name) }
    }
    return result
}

public func commandMenuKind(_ command: JSONValue) -> String? {
    command["client"].str() ?? builtinCommandName(command["definitionId"].str())
}

public func commandMenuLabel(_ command: JSONValue, english: Bool) -> String? {
    switch commandMenuKind(command) {
    case "file": return english ? "File" : "文件"
    case "model": return english ? "Model" : "模型"
    case "goal": return english ? "Goal" : "目标"
    case "plan": return english ? "Plan" : "计划"
    case "feedback": return english ? "Feedback" : "反馈"
    case "compact": return english ? "Compact" : "压缩"
    case "permission": return english ? "Permission" : "权限"
    case "export": return english ? "Export" : "下载日志"
    default: return nil
    }
}

public func commandMenuDescription(_ command: JSONValue, english: Bool) -> String? {
    switch commandMenuKind(command) {
    case "model": return english ? "Select the model for this conversation" : "选择本会话使用的模型"
    case "goal": return english ? "Set or view the goal for a long-running task" : "设置或查看长期任务目标"
    case "plan": return english ? "Enter or leave plan mode" : "进入或退出计划模式"
    case "feedback": return english ? "Record feedback about this session" : "发送关于当前会话的反馈"
    case "compact": return english ? "Compact older conversation history" : "压缩以上对话内容"
    case "permission": return english
        ? "Switch the permission preset (sandbox mode + approval policy)"
        : "切换权限预设（沙箱模式与审批策略）"
    case "export": return english ? "Download this Session log as a ZIP archive" : "将当前会话内容导出为 ZIP"
    default: return command["description"].str()
    }
}

/// ui-commands sectionRows + ui-primitives rankByName; names, not builtin identities, set section order.
public func commandMenuRows(_ commands: [JSONValue], query: String, leading: Bool, english: Bool = false) -> [JSONValue] {
    let visible = commands.filter { leading || $0["input"]["hint"].str() == nil }
    if query.isEmpty {
        var byName: [String: JSONValue] = [:]
        for row in visible {
            if let name = row["name"].str() { byName[name] = row }
        }
        let ordered = commandOrderedNames.compactMap { byName[$0] }
        let rest = visible.filter { row in
            guard let name = row["name"].str() else { return true }
            return !commandOrderedNames.contains(name)
        }
        return ordered + rest
    }
    let lowerQuery = query.lowercased()
    struct Match {
        var row: JSONValue
        var index: Int
        var prefix: Bool
        var score: Int
    }
    var matches: [Match] = []
    for (index, row) in visible.enumerated() {
        var best: Int?
        var prefix = false
        for key in [row["name"].str(), commandMenuLabel(row, english: english)].compactMap({ $0 }) {
            let name = key.lowercased()
            guard let score = commandAlignmentScore(name, query: lowerQuery) else { continue }
            prefix = prefix || name.hasPrefix(lowerQuery)
            best = max(best ?? score, score)
        }
        if let best {
            matches.append(Match(row: row, index: index, prefix: prefix, score: best))
        }
    }
    return matches.sorted {
        if $0.prefix != $1.prefix { return $0.prefix && !$1.prefix }
        if $0.score != $1.score { return $0.score > $1.score }
        return $0.index < $1.index
    }.map(\.row)
}

public func commandAlignmentScore(_ name: String, query: String) -> Int? {
    if query.count > name.count { return nil }
    let none = Int.min
    let nameChars = Array(name)
    let queryChars = Array(query)
    func boundary(_ index: Int) -> Int {
        if index == 0 || nameChars[index - 1] == "-" || nameChars[index - 1] == "_" { return 8 }
        return 0
    }
    var previous = (0..<nameChars.count).map { index in
        nameChars[index] == queryChars[0] ? 1 + boundary(index) - index : none
    }
    var current = Array(repeating: none, count: nameChars.count)
    if queryChars.count > 1 {
        for queryIndex in 1..<queryChars.count {
            current = Array(repeating: none, count: nameChars.count)
            var left = none
            var leftLeft = none
            var bestGapped = none
            for index in nameChars.indices {
                let prior = previous[index]
                if leftLeft != none { bestGapped = max(bestGapped, leftLeft + index - 2) }
                if nameChars[index] == queryChars[queryIndex] {
                    let bonus = 1 + boundary(index)
                    var score = left == none ? none : left + bonus + 4
                    if bestGapped != none { score = max(score, bestGapped + bonus + 1 - index) }
                    current[index] = score
                }
                leftLeft = left
                left = prior
            }
            swap(&previous, &current)
        }
    }
    return previous.max().flatMap { $0 == none ? nil : $0 }
}

public func commandContributionCollision(_ commands: [JSONValue]) -> String? {
    var counts: [String: Int] = [:]
    for command in commands {
        guard let name = command["name"].str() else { continue }
        counts[name, default: 0] += 1
    }
    return counts.first { $0.value > 1 }?.key
}

public func commandContributionCollisionMessage(_ name: String, english: Bool) -> String {
    english
        ? "Command contribution /\(name) collides with a host command"
        : "指令贡献 /\(name) 与远程主机指令冲突"
}

/// Slash-menu skill row from Host `skills/list` / pocket `skills.list`.
public struct SkillEntry: Equatable, Sendable, Identifiable {
    public var name: String
    public var description: String
    public var modelInvocable: Bool
    public var id: String { name }

    public init(name: String, description: String, modelInvocable: Bool) {
        self.name = name
        self.description = description
        self.modelInvocable = modelInvocable
    }

    public static func parse(_ element: JSONValue) -> SkillEntry? {
        guard let object = element.obj() else { return nil }
        guard let name = object["name"]?.str(), !name.isEmpty else { return nil }
        let description = object["description"]?.str() ?? ""
        let modelInvocable = object["modelInvocable"]?.bool()
            ?? object["invocation"]?.obj()?["modelInvocable"]?.bool()
            ?? false
        return SkillEntry(name: name, description: description, modelInvocable: modelInvocable)
    }

    /// Desktop ui-skill: `modelInvocable: false` wears the user-only marker as a description prefix.
    public func menuDescription(english: Bool) -> String {
        if modelInvocable { return description }
        let prefix = english ? "user-only" : "仅用户"
        return description.isEmpty ? prefix : "\(prefix) · \(description)"
    }
}

public func skillMenuRows(_ skills: [SkillEntry], query: String) -> [SkillEntry] {
    if query.isEmpty { return skills }
    let lowerQuery = query.lowercased()
    struct Match {
        var skill: SkillEntry
        var index: Int
        var prefix: Bool
        var score: Int
    }
    var matches: [Match] = []
    for (index, skill) in skills.enumerated() {
        let name = skill.name.lowercased()
        guard let score = commandAlignmentScore(name, query: lowerQuery) else { continue }
        matches.append(Match(skill: skill, index: index, prefix: name.hasPrefix(lowerQuery), score: score))
    }
    return matches.sorted {
        if $0.prefix != $1.prefix { return $0.prefix && !$1.prefix }
        if $0.score != $1.score { return $0.score > $1.score }
        return $0.index < $1.index
    }.map(\.skill)
}

/// One slash-menu row. Sections are headings; command/skill rows are selectable.
public enum CommandMenuRow: Equatable, Sendable {
    case section(String)
    case command(JSONValue)
    case skill(SkillEntry)

    public var isSelectable: Bool {
        switch self {
        case .section: return false
        case .command, .skill: return true
        }
    }
}

public func commandMenuSectionTitle(_ section: String, english: Bool) -> String {
    switch section {
    case "add": return english ? "Add" : "添加"
    case "commands": return english ? "Commands" : "指令"
    case "skills": return english ? "Skills" : "技能"
    default:
        return section
    }
}

public func commandMenuAvailable(kind: String?, ops: Set<String>) -> Bool {
    switch kind {
    case "file": return ops.contains("attachments.upload")
    case "model": return ops.contains("models.catalog")
    case "feedback": return ops.contains("sessionFeedback.record")
    case "export": return ops.contains("session.export")
    case "permission": return ops.contains("permissions.catalog")
    default: return ops.contains("commands.execute")
    }
}

/// Desktop composer menu keeps 「添加 / 指令 / 技能」 as three groups.
/// Rank inside each group with the shared name ranker.
public func commandMenuDisplayRows(
    commands: [JSONValue],
    skills: [SkillEntry],
    query: String,
    leading: Bool,
    english: Bool
) -> [CommandMenuRow] {
    let add = commands.filter { commandAddNames.contains($0["name"].str() ?? "") }
    let rest = commands.filter { !commandAddNames.contains($0["name"].str() ?? "") }
    let addRows = commandMenuRows(add, query: query, leading: leading, english: english)
    let commandRows = commandMenuRows(rest, query: query, leading: leading, english: english)
    let skillRows = skillMenuRows(skills, query: query)
    var items: [CommandMenuRow] = []
    if !addRows.isEmpty {
        items.append(.section(commandMenuSectionTitle("add", english: english)))
        items.append(contentsOf: addRows.map { .command($0) })
    }
    if !commandRows.isEmpty {
        items.append(.section(commandMenuSectionTitle("commands", english: english)))
        items.append(contentsOf: commandRows.map { .command($0) })
    }
    if !skillRows.isEmpty {
        items.append(.section(commandMenuSectionTitle("skills", english: english)))
        items.append(contentsOf: skillRows.map { .skill($0) })
    }
    return items
}

public func commandMenuSelectableIndexes(_ rows: [CommandMenuRow]) -> [Int] {
    rows.indices.filter { rows[$0].isSelectable }
}

public func commandMenuDefaultHighlight(_ rows: [CommandMenuRow]) -> Int? {
    commandMenuSelectableIndexes(rows).first
}

public func commandMenuMoveHighlight(rows: [CommandMenuRow], current: Int?, direction: Int) -> Int? {
    let indexes = commandMenuSelectableIndexes(rows)
    guard !indexes.isEmpty else { return nil }
    guard let current, let at = indexes.firstIndex(of: current) else {
        return direction >= 0 ? indexes.first : indexes.last
    }
    let next = (at + direction % indexes.count + indexes.count) % indexes.count
    return indexes[next]
}

public func commandMenuHighlightedRow(_ rows: [CommandMenuRow], highlight: Int?) -> CommandMenuRow? {
    guard let highlight, rows.indices.contains(highlight) else { return nil }
    let row = rows[highlight]
    return row.isSelectable ? row : nil
}

/// Identity of a slash token whose menu the user dismissed. The same query
/// must not reopen until the token or query changes (desktop ui-input-trigger).
public struct SlashMenuDismissal: Equatable, Sendable {
    public var query: String
    public var start: Int
    public var end: Int

    public init(query: String, start: Int, end: Int) {
        self.query = query
        self.start = start
        self.end = end
    }
}

public func slashMenuTrigger(_ text: String, cursor: Int? = nil) -> ComposerTrigger? {
    let at = cursor ?? text.count
    guard let trigger = composerTrigger(text, cursor: at), trigger.kind == Character("/") else { return nil }
    return trigger
}

public func slashMenuQuery(_ text: String, cursor: Int? = nil) -> String {
    slashMenuTrigger(text, cursor: cursor)?.query ?? ""
}

public func slashMenuIsLeading(_ text: String, cursor: Int? = nil) -> Bool {
    let at = cursor ?? text.count
    if let trigger = slashMenuTrigger(text, cursor: at) {
        return text.prefix(trigger.start).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// Plus-button launcher + typed `/` share one overlay. A dismissed token stays
/// closed until the query changes; deleting `/` always hides the menu.
public struct SlashMenuState: Equatable, Sendable {
    public var plusOpen: Bool
    public var dismissed: SlashMenuDismissal?

    public init(plusOpen: Bool = false, dismissed: SlashMenuDismissal? = nil) {
        self.plusOpen = plusOpen
        self.dismissed = dismissed
    }

    public func isVisible(trigger: ComposerTrigger?) -> Bool {
        if plusOpen { return true }
        guard let trigger, trigger.kind == Character("/") else { return false }
        if let dismissed, dismissed.query == trigger.query, dismissed.start == trigger.start, dismissed.end == trigger.end {
            return false
        }
        return true
    }

    public mutating func track(trigger: ComposerTrigger?) {
        guard let trigger, trigger.kind == Character("/") else {
            if dismissed != nil, trigger == nil { dismissed = nil }
            return
        }
        if let dismissed, dismissed.query != trigger.query || dismissed.start != trigger.start || dismissed.end != trigger.end {
            self.dismissed = nil
        }
    }

    public mutating func dismiss(trigger: ComposerTrigger?) {
        plusOpen = false
        if let trigger, trigger.kind == Character("/") {
            dismissed = SlashMenuDismissal(query: trigger.query, start: trigger.start, end: trigger.end)
        } else {
            dismissed = nil
        }
    }

    public mutating func togglePlus(trigger: ComposerTrigger?) {
        if isVisible(trigger: trigger) {
            dismiss(trigger: trigger)
            return
        }
        plusOpen = true
        dismissed = nil
    }

    public mutating func closeAfterPick(trigger: ComposerTrigger?) {
        dismiss(trigger: trigger)
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
