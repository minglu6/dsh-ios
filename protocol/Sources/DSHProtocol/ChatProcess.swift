import Foundation

public enum TranscriptView: String, Sendable, CaseIterable {
    case compact, standard, detailed, verbose
}

/// Desktop `TranscriptViewPolicy`: non-desktop clients default to `detailed` when Host has no saved mode.
/// `normal` / `expanded` are legacy saved values read as `detailed`.
public func transcriptViewFromHost(_ raw: String?) -> TranscriptView {
    switch raw {
    case "compact": return .compact
    case "standard": return .standard
    case "detailed", "normal", "expanded": return .detailed
    case "verbose": return .verbose
    default: return .detailed
    }
}

/// Desktop `ui-chat.collapseTiming`: `completion` | `next-input`. Absence keeps completion folding.
public enum CollapseTiming: String, Sendable, CaseIterable {
    case completion
    case nextInput = "next-input"
}

public func collapseTimingFromHost(_ raw: String?) -> CollapseTiming {
    CollapseTiming(rawValue: raw ?? "") ?? .completion
}

/// Desktop `@deepseek-ai/dsh-client-ui-chat` presentation policy.
public struct PresentationPolicy: Equatable, Sendable {
    public var mode: TranscriptView
    public var foldCompletedTurns: Bool
    /// collapsed | history | none
    public var stepGrouping: String
    public var liveProcessDetail: Bool
    public var settledReasoningPreview: Bool
    public var collapseTiming: CollapseTiming
}

public func presentationPolicyFor(
    _ mode: TranscriptView = .standard,
    collapseTiming: CollapseTiming = .completion
) -> PresentationPolicy {
    switch mode {
    case .compact:
        return PresentationPolicy(
            mode: mode, foldCompletedTurns: true, stepGrouping: "collapsed",
            liveProcessDetail: false, settledReasoningPreview: false, collapseTiming: collapseTiming
        )
    case .standard:
        return PresentationPolicy(
            mode: mode, foldCompletedTurns: true, stepGrouping: "collapsed",
            liveProcessDetail: true, settledReasoningPreview: true, collapseTiming: collapseTiming
        )
    case .detailed:
        return PresentationPolicy(
            mode: mode, foldCompletedTurns: true, stepGrouping: "history",
            liveProcessDetail: true, settledReasoningPreview: true, collapseTiming: collapseTiming
        )
    case .verbose:
        return PresentationPolicy(
            mode: mode, foldCompletedTurns: false, stepGrouping: "none",
            liveProcessDetail: false, settledReasoningPreview: true, collapseTiming: collapseTiming
        )
    }
}

public struct ProcessStep: Equatable, Sendable {
    public var key: String
    public var step: Int?
    public var members: [Item]
}

/// One chat-flow row after desktop-style turn-process folding.
public enum ChatRow: Equatable, Sendable {
    case user(Item.User)
    case answer(Item.Text)
    case notice(Item.Notice)
    case retry(Item.Retry)
    case turnFailure(Item.TurnFailure)
    case tool(Item.Tool)
    case reasoning(Item.Reasoning)
    case process(Process)
    case deliverable(Item.Deliverable)
    case changes(Item.Changes)

    public var key: String {
        switch self {
        case .user(let v): return v.key
        case .answer(let v): return v.key
        case .notice(let v): return v.key
        case .retry(let v): return v.key
        case .turnFailure(let v): return v.key
        case .tool(let v): return v.key
        case .reasoning(let v): return v.key
        case .process(let v): return v.key
        case .deliverable(let v): return v.key
        case .changes(let v): return v.key
        }
    }

    public struct Process: Equatable, Sendable {
        public var key: String
        public var tools: [Item.Tool]
        public var reasoning: [Item.Reasoning]
        public var title: String
        public var closed: Bool
        public var defaultOpen: Bool
        public var durationMs: Int64?
        public var members: [Item]
        public var steps: [ProcessStep]
        public var turnSummary: Bool
        public var canCollapse: Bool
        public var turn: Int?
        public var grouped: Bool
        public var controlledKeys: Set<String>
        public var activityKind: String
        public var detail: String?

        public init(
            key: String,
            tools: [Item.Tool],
            reasoning: [Item.Reasoning],
            title: String,
            closed: Bool,
            defaultOpen: Bool,
            durationMs: Int64? = nil,
            members: [Item] = [],
            steps: [ProcessStep] = [],
            turnSummary: Bool = false,
            canCollapse: Bool = true,
            turn: Int? = nil,
            grouped: Bool = true,
            controlledKeys: Set<String> = [],
            activityKind: String = "thinking",
            detail: String? = nil
        ) {
            self.key = key
            self.tools = tools
            self.reasoning = reasoning
            self.title = title
            self.closed = closed
            self.defaultOpen = defaultOpen
            self.durationMs = durationMs
            self.members = members
            self.steps = steps
            self.turnSummary = turnSummary
            self.canCollapse = canCollapse
            self.turn = turn
            self.grouped = grouped
            self.controlledKeys = controlledKeys
            self.activityKind = activityKind
            self.detail = detail
        }
    }
}

public func toolActivityKind(_ name: String) -> String {
    if name == "read" { return "read" }
    if name == "read_image" { return "readImage" }
    if name == "grep" || name == "glob" || name.hasSuffix("_inspect") { return "search" }
    if name == "write" { return "write" }
    if name == "edit" || name == "apply_patch" { return "edit" }
    if name == "bash" || name == "pwsh" || name == "exec_command" || name == "write_stdin" || name.hasPrefix("terminal_") {
        return "commands"
    }
    if name == "run_code" { return "code" }
    if name == "web_search" { return "webSearch" }
    if name == "web_fetch" { return "webFetch" }
    if name == "subagent" || name.hasPrefix("subagent_") { return "subagents" }
    if ["todo_write", "create_goal", "update_goal", "get_goal"].contains(name) { return "plan" }
    if name == "ask_user_question" || name == "request_user_input" { return "questions" }
    return "tools"
}

private let doneLabelZh: [String: String] = [
    "thinking": "已完成分析", "read": "已读取文件", "readImage": "已读取图片",
    "write": "已写入文件", "search": "已搜索代码", "edit": "修改了文件",
    "commands": "执行了命令", "code": "运行了代码", "webSearch": "已搜索网页",
    "webFetch": "已访问网页", "subagents": "已协调子智能体", "plan": "更新了计划",
    "questions": "向用户提出了问题", "tools": "已调用工具",
]
private let doneLabelEn: [String: String] = [
    "thinking": "Analysis completed", "read": "Read files", "readImage": "Read images",
    "write": "Wrote files", "search": "Searched code", "edit": "Edited files",
    "commands": "Ran commands", "code": "Ran code", "webSearch": "Searched the web",
    "webFetch": "Visited web pages", "subagents": "Coordinated subagents",
    "plan": "Updated the plan", "questions": "Asked questions", "tools": "Called tools",
]
private let liveLabelZh: [String: String] = [
    "thinking": "正在分析请求", "read": "正在读取文件", "readImage": "正在读取图片",
    "write": "正在写入文件", "search": "正在搜索代码", "edit": "正在编辑文件",
    "commands": "正在运行命令", "code": "正在运行代码", "webSearch": "正在搜索网页",
    "webFetch": "正在访问网页", "subagents": "正在协调子智能体", "plan": "正在更新计划",
    "questions": "等待你的操作", "tools": "正在调用工具",
]
private let liveLabelEn: [String: String] = [
    "thinking": "Analyzing the request", "read": "Reading files", "readImage": "Reading images",
    "write": "Writing files", "search": "Searching code", "edit": "Editing files",
    "commands": "Running commands", "code": "Running code", "webSearch": "Searching the web",
    "webFetch": "Visiting web pages", "subagents": "Coordinating subagents",
    "plan": "Updating the plan", "questions": "Waiting for your action", "tools": "Calling tools",
]
private let prepareLabelZh: [String: String] = [
    "read": "准备读取文件", "readImage": "准备读取图片", "write": "准备写入文件",
    "search": "准备搜索代码", "edit": "准备编辑文件", "commands": "准备运行命令",
    "code": "准备运行代码", "webSearch": "准备搜索网页", "webFetch": "准备访问网页",
    "subagents": "准备协调子智能体", "plan": "准备更新计划", "questions": "准备提问",
    "tools": "准备调用工具",
]
private let prepareLabelEn: [String: String] = [
    "read": "Preparing to read files", "readImage": "Preparing to read images",
    "write": "Preparing to write files", "search": "Preparing to search code",
    "edit": "Preparing to edit files", "commands": "Preparing to run commands",
    "code": "Preparing to run code", "webSearch": "Preparing to search the web",
    "webFetch": "Preparing to visit web pages", "subagents": "Preparing to coordinate subagents",
    "plan": "Preparing to update the plan", "questions": "Preparing questions",
    "tools": "Preparing tool calls",
]

public func preparingToolTitle(_ name: String, en: Bool = false) -> String {
    (en ? prepareLabelEn : prepareLabelZh)[toolActivityKind(name)] ?? (en ? prepareLabelEn : prepareLabelZh)["tools"]!
}

public func processTitle(_ kinds: [String], en: Bool = false) -> String {
    let dictionary = en ? doneLabelEn : doneLabelZh
    if kinds.isEmpty { return dictionary["thinking"]! }
    let labels = kinds.prefix(3).map { dictionary[$0] ?? dictionary["tools"]! }
    let first = labels[0]
    if labels.count == 1 { return first }
    func continuation(_ label: String) -> String {
        guard let firstChar = label.first else { return label }
        return String(firstChar).lowercased() + label.dropFirst()
    }
    if labels.count == 2 {
        let second = labels[1]
        let prefix = "已"
        let trimmed = (!en && first.hasPrefix(prefix) && second.hasPrefix(prefix))
            ? String(second.dropFirst(prefix.count)) : second
        return "\(first)\(en ? " and " : "并")\(continuation(trimmed))"
    }
    let title = [first] + labels.dropFirst().map(continuation)
    let joined = title.joined(separator: en ? ", " : "，")
    return kinds.count > 3 ? joined + (en ? ", etc." : "等") : joined
}

public func rankedActivityKinds(_ tools: [Item.Tool]) -> [String] {
    var order: [(String, Int)] = []
    var index: [String: Int] = [:]
    var seen = Set<String>()
    for tool in tools {
        let id = tool.callId.isEmpty ? tool.key : tool.callId
        if !seen.insert(id).inserted { continue }
        let kind = toolActivityKind(tool.name)
        if let i = index[kind] {
            order[i].1 += 1
        } else {
            index[kind] = order.count
            order.append((kind, 1))
        }
    }
    return order.sorted { $0.1 > $1.1 }.map(\.0)
}

private func runningTool(_ tools: [Item.Tool]) -> Item.Tool? {
    var latest: Item.Tool?
    for tool in tools {
        if tool.status != .preparing && tool.status != .running && tool.status != .awaitingApproval { continue }
        if latest == nil || (tool.startedAt ?? Int64.min) >= (latest!.startedAt ?? Int64.min) {
            latest = tool
        }
    }
    return latest
}

public func liveProcessTitle(_ tools: [Item.Tool], _ reasoning: [Item.Reasoning], en: Bool = false) -> String {
    if let tool = runningTool(tools), tool.status == .preparing {
        return preparingToolTitle(tool.name, en: en)
    }
    let dictionary = en ? liveLabelEn : liveLabelZh
    let kind = runningTool(tools).map { toolActivityKind($0.name) } ?? "thinking"
    return dictionary[kind] ?? dictionary["thinking"]!
}

private let detailKeys = [
    "title", "description", "objective", "task", "task_name", "name", "question", "questions",
    "prompt", "message", "command", "cmd", "queries", "query", "pattern", "url", "uri",
    "file_path", "path", "target", "action", "status",
]

private func normalizeProcessDetail(_ text: String) -> String {
    let collapsed = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    if collapsed.count <= 160 { return collapsed }
    let end = collapsed.index(collapsed.startIndex, offsetBy: 159, limitedBy: collapsed.endIndex) ?? collapsed.endIndex
    let extra = collapsed.index(end, offsetBy: 2, limitedBy: collapsed.endIndex)
    if extra == nil || extra == collapsed.endIndex { return collapsed }
    return String(collapsed[..<end]).trimmingCharacters(in: .whitespaces) + "…"
}

private func processDetail(tool: Item.Tool?, reasoning: [Item.Reasoning]) -> String? {
    if tool == nil {
        return reasoning.reversed().compactMap { block -> String? in
            guard block.live else { return nil }
            return block.text
                .components(separatedBy: CharacterSet.newlines)
                .joined(separator: "\n")
                .split(separator: "\n\n", omittingEmptySubsequences: false)
                .reversed()
                .compactMap { paragraph in
                    let cleaned = normalizeProcessDetail(paragraph.replacingOccurrences(of: "**", with: ""))
                    return cleaned.isEmpty ? nil : cleaned
                }
                .first
        }.first
    }
    guard let tool else { return nil }
    let args = (try? JSONValue.parse(tool.arguments))?.obj()
    if let args {
        for key in detailKeys {
            guard let value = args[key] else { continue }
            let text: String?
            if key == "questions" {
                text = value.arr()?.compactMap { $0["question"].str()?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            } else if let str = value.str() {
                text = str
            } else if let arr = value.arr(), arr.allSatisfy({ $0.str() != nil }) {
                text = arr.compactMap { $0.str() }.joined(separator: ", ")
            } else {
                text = nil
            }
            if let detail = text.map(normalizeProcessDetail), !detail.isEmpty { return detail }
        }
    }
    let fallback = normalizeProcessDetail(tool.name)
    return fallback.isEmpty ? nil : fallback
}

public func formatRunDuration(_ milliseconds: Int64, en: Bool = false) -> String {
    let total = max(milliseconds / 1000, 0)
    let hours = total / 3600
    let minutes = total / 60 % 60
    let seconds = total % 60
    var out = ""
    if hours > 0 { out += "\(hours)\(en ? "h " : "小时")" }
    if total >= 60 { out += "\(minutes)\(en ? "m " : "分")" }
    out += "\(seconds)\(en ? "s" : "秒")"
    return out
}

private func processTurn(_ item: Item) -> Int? {
    switch item {
    case .tool(let v): return v.turn
    case .reasoning(let v): return v.turn
    case .text(let v): return v.turn
    case .notice(let v): return v.turn
    case .retry(let v): return v.turn
    case .turnFailure(let v): return v.turn
    case .deliverable(let v): return v.turn
    case .changes(let v): return v.turn
    default: return nil
    }
}

private func processStep(_ item: Item) -> Int? {
    switch item {
    case .tool(let v): return v.step
    case .reasoning(let v): return v.step
    case .text(let v): return v.step
    case .retry(let v): return v.step
    default: return nil
    }
}

private func processSteps(_ members: [Item]) -> [ProcessStep] {
    var groups: [ProcessStep] = []
    var currentStep: Int?
    var current: [Item] = []
    func flush() {
        guard let first = current.first else { return }
        groups.append(ProcessStep(key: first.key + "-step", step: currentStep, members: current))
        current = []
    }
    for item in members {
        let step = processStep(item)
        if !current.isEmpty && step != currentStep { flush() }
        currentStep = step
        current.append(item)
    }
    flush()
    return groups
}

private func isBlankAssistant(_ item: Item) -> Bool {
    switch item {
    case .reasoning(let v): return v.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .text(let v): return v.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    default: return false
    }
}

private func isHidden(_ item: Item) -> Bool {
    switch item {
    case .context, .system, .compacted: return true
    default: return isBlankAssistant(item)
    }
}

/// Segment in transcript order first. A response, independent input/notice or another Turn
/// settles the preceding group; only Host turn/end creates the separate whole-Turn control.
public func foldChatItems(
    _ items: [Item],
    policy: PresentationPolicy,
    sessionRunning: Bool,
    turnRecords: [TurnRecord] = [],
    en: Bool = false
) -> [ChatRow] {
    let facts = Dictionary(uniqueKeysWithValues: turnRecords.map { ($0.turn, $0) })
    let visible = items.filter { !isHidden($0) }
    let positions = Dictionary(uniqueKeysWithValues: visible.enumerated().map { ($0.element.key, $0.offset) })
    var byTurn: [Int: [Item]] = [:]
    for item in visible {
        if let turn = processTurn(item) {
            byTurn[turn, default: []].append(item)
        }
    }
    let latestTurn = (Array(byTurn.keys) + Array(facts.keys)).max()
    let latestInputSeq = visible.compactMap { item -> Int64? in
        if case .user(let user) = item { return user.seq }
        return nil
    }.max()
    let lastInputIndex = visible.lastIndex { if case .user = $0 { return true }; return false } ?? -1
    func deferCollapse(_ turn: Int?) -> Bool {
        guard let turn, policy.collapseTiming == .nextInput else { return false }
        let fact = facts[turn]
        let lastTurnIndex = byTurn[turn]?.last.flatMap { positions[$0.key] } ?? -1
        let followingInput = lastInputIndex > lastTurnIndex ||
            (fact?.endSeq.flatMap { end in latestInputSeq.map { $0 > end } } == true)
        return turn == latestTurn && !followingInput
    }
    var out: [ChatRow] = []
    var pending: [Item] = []
    var pendingTurn: Int?
    func flush(_ boundary: Bool) {
        guard let first = pending.first else { return }
        let members = pending
        pending = []
        let tools = members.compactMap { item -> Item.Tool? in if case .tool(let t) = item { return t }; return nil }
        let reasoning = members.compactMap { item -> Item.Reasoning? in if case .reasoning(let r) = item { return r }; return nil }
        let fact = pendingTurn.flatMap { facts[$0] }
        let turnClosed = fact?.closed == true
        let closed = boundary || turnClosed
        let grouped = policy.stepGrouping == "collapsed" ||
            (policy.stepGrouping == "history" && turnClosed && !deferCollapse(pendingTurn))
        let running = runningTool(tools)
        let ranked = closed ? rankedActivityKinds(tools) : []
        out.append(.process(ChatRow.Process(
            key: "\(first.key)-group",
            tools: tools,
            reasoning: reasoning,
            title: closed ? processTitle(ranked, en: en) : liveProcessTitle(tools, reasoning, en: en),
            closed: closed,
            defaultOpen: false,
            members: members,
            steps: processSteps(members),
            canCollapse: grouped,
            turn: pendingTurn,
            grouped: grouped,
            activityKind: closed ? (ranked.first ?? "thinking") : (running.map { toolActivityKind($0.name) } ?? "thinking"),
            detail: (!closed && policy.liveProcessDetail) ? processDetail(tool: running, reasoning: reasoning) : nil
        )))
    }
    for item in visible {
        let turn = processTurn(item)
        if !pending.isEmpty && pendingTurn != turn { flush(true) }
        switch item {
        case .tool, .reasoning:
            pendingTurn = turn
            pending.append(item)
        default:
            flush(true)
            emitPlain(&out, item)
        }
    }
    flush(false)

    func rowTurn(_ row: ChatRow) -> Int? {
        switch row {
        case .process(let v): return v.turn
        case .answer(let v): return v.turn
        case .notice(let v): return v.turn
        case .retry(let v): return v.turn
        case .turnFailure(let v): return v.turn
        case .deliverable(let v): return v.turn
        case .changes(let v): return v.turn
        default: return nil
        }
    }
    var rowsByTurn: [Int: [ChatRow]] = [:]
    for row in out {
        if let turn = rowTurn(row) { rowsByTurn[turn, default: []].append(row) }
    }
    var controls: [Int: ChatRow.Process] = [:]
    var controlOrder: [Int] = []
    for fact in turnRecords.filter(\.closed).sorted(by: { $0.turn < $1.turn }) {
        let owned = byTurn[fact.turn] ?? []
        let lastStep = owned.compactMap(processStep).max()
        let lastStepHasTools = owned.contains { if case .tool(let t) = $0 { return t.step == lastStep }; return false }
        let finalAnswer = owned.compactMap { item -> Item.Text? in
            if case .text(let t) = item { return t }
            return nil
        }.last { !$0.live && $0.step == lastStep && !lastStepHasTools }
        let finalPosition = finalAnswer.flatMap { positions[$0.key] }
        let finalAnswerKeys = Set(owned.compactMap { item -> String? in
            guard case .text(let t) = item, let finalAnswer, t.step == finalAnswer.step else { return nil }
            return t.key
        })
        let ownedPositions = owned.compactMap { positions[$0.key] }
        let first = ownedPositions.min()
        let last = ownedPositions.max()
        let interleaved = first != nil && last != nil && (first!...last!).contains { idx in
            if case .user = visible[idx] { return true }
            return false
        }
        var controlled = Set<String>()
        for row in rowsByTurn[fact.turn] ?? [] {
            switch row {
            case .process:
                controlled.insert(row.key)
            case .answer:
                if !finalAnswerKeys.contains(row.key) { controlled.insert(row.key) }
            case .deliverable:
                if finalPosition == nil || (positions[row.key] ?? Int.max) < finalPosition! {
                    controlled.insert(row.key)
                }
            case .changes:
                // Desktop keeps the WorkspaceChanges card outside the completed-turn fold.
                break
            default:
                break
            }
        }
        let failed = fact.endReason == "error" || fact.endReason == "aborted"
        let canCollapse = !controlled.isEmpty && !failed && !interleaved && policy.foldCompletedTurns
        let duration = fact.durationMs
        let title: String
        switch fact.endReason {
        case "aborted": title = en ? "Stopped" : "已停止"
        case "error": title = en ? "Failed" : "处理失败"
        default:
            if let duration {
                title = (en ? "Completed in " : "已完成，用时 ") + formatRunDuration(duration, en: en)
            } else {
                title = en ? "Completed" : "已完成"
            }
        }
        controls[fact.turn] = ChatRow.Process(
            key: "turn-\(fact.turn)-process",
            tools: [],
            reasoning: [],
            title: title,
            closed: true,
            defaultOpen: !canCollapse || deferCollapse(fact.turn),
            durationMs: duration,
            turnSummary: true,
            canCollapse: canCollapse,
            turn: fact.turn,
            controlledKeys: controlled
        )
        controlOrder.append(fact.turn)
    }
    var result: [ChatRow] = []
    for row in out {
        if let turn = rowTurn(row) {
            let preceding = controlOrder.filter { $0 <= turn && controls[$0] != nil }
            for closedTurn in preceding {
                if let control = controls.removeValue(forKey: closedTurn) {
                    result.append(.process(control))
                }
            }
        } else if case .user(let user) = row, let userSeq = user.seq {
            let preceding = controlOrder.filter { turn in
                if controls[turn] == nil { return false }
                if let end = facts[turn]?.endSeq { return end < userSeq }
                return false
            }
            for closedTurn in preceding {
                if let control = controls.removeValue(forKey: closedTurn) {
                    result.append(.process(control))
                }
            }
        }
        result.append(row)
    }
    for turn in controlOrder {
        if let control = controls.removeValue(forKey: turn) {
            result.append(.process(control))
        }
    }
    return result
}

/// Apply only outer-Turn visibility; local process-group disclosure remains independent.
public func visibleChatRows(_ rows: [ChatRow], openTurns: [String: Bool] = [:]) -> [ChatRow] {
    var hidden = Set<String>()
    for row in rows {
        if case .process(let proc) = row, proc.turnSummary, proc.canCollapse,
           !(openTurns[proc.key] ?? proc.defaultOpen) {
            hidden.formUnion(proc.controlledKeys)
        }
    }
    return hidden.isEmpty ? rows : rows.filter { !hidden.contains($0.key) }
}

/// Desktop turnTail: hide the independent card only when the last committed answer of
/// that turn is itself visible. Any earlier visible answer (or a live stream) must not
/// swallow the card into a missing attachment.
public func chatTranscriptRows(_ rows: [ChatRow], openTurns: [String: Bool] = [:]) -> [ChatRow] {
    let visible = visibleChatRows(rows, openTurns: openTurns)
    let lastCommitted = lastCommittedAnswerKeys(in: rows)
    var attachedTurns = Set<Int>()
    for row in visible {
        if case .answer(let text) = row, let turn = text.turn, lastCommitted[turn] == text.key {
            attachedTurns.insert(turn)
        }
    }
    return visible.filter { row in
        if case .changes(let item) = row { return !attachedTurns.contains(item.turn) }
        return true
    }
}

/// Closing-assistant turnTail attachment: the card rides the last committed answer.
public func changesAttachedToAnswer(
    _ text: Item.Text,
    lastCommittedAnswerKeys: [Int: String],
    changesByTurn: [Int: Item.Changes]
) -> Item.Changes? {
    guard let turn = text.turn, lastCommittedAnswerKeys[turn] == text.key else { return nil }
    return changesByTurn[turn]
}

public func lastCommittedAnswerKeys(in rows: [ChatRow]) -> [Int: String] {
    var keys: [Int: String] = [:]
    for row in rows {
        if case .answer(let text) = row, let turn = text.turn, isCommittedAnswer(text) {
            keys[turn] = text.key
        }
    }
    return keys
}

func isCommittedAnswer(_ text: Item.Text) -> Bool {
    !text.live && !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

public func inspectorRowIndex(_ rows: [ChatRow], itemKey: String) -> Int {
    rows.firstIndex { row in
        row.key == itemKey || {
            if case .process(let proc) = row { return proc.members.contains { $0.key == itemKey } }
            return false
        }()
    } ?? -1
}

public func inspectorPickKey(_ row: ChatRow) -> String {
    if case .process(let proc) = row {
        return proc.members.first?.key ?? row.key
    }
    return row.key
}

private func emitPlain(_ out: inout [ChatRow], _ item: Item) {
    switch item {
    case .user(let v): out.append(.user(v))
    case .tool(let v): out.append(.tool(v))
    case .reasoning(let v): out.append(.reasoning(v))
    case .text(let v): out.append(.answer(v))
    case .notice(let v): out.append(.notice(v))
    case .retry(let v): out.append(.retry(v))
    case .turnFailure(let v): out.append(.turnFailure(v))
    case .deliverable(let v): out.append(.deliverable(v))
    case .changes(let v): out.append(.changes(v))
    default: break
    }
}

public func retrySeconds(_ milliseconds: Int64) -> Int64 {
    if milliseconds <= 1000 { return 1 }
    return milliseconds / 1000 + (milliseconds % 1000 == 0 ? 0 : 1)
}

public func retryRemainingSeconds(delayMs: Int64, elapsedMs: Int64) -> Int64 {
    retrySeconds(max(delayMs, 0) - max(elapsedMs, 0))
}

public func chatFailureMessage(_ message: String, code: String?, en: Bool) -> String {
    switch code {
    case "ACCOUNT_SIGNED_OUT":
        return en ? "Stopped because you signed out of DeepSeek." : "任务已因退出 DeepSeek 登录而停止。"
    case "ACCOUNT_SIGN_IN_REQUIRED":
        return en ? "Sign in to DeepSeek and ensure the request destination supports account authentication." : "请先登录 DeepSeek，并确认请求地址支持账号认证。"
    case "QUOTA", "ACCOUNT_QUOTA", "QUOTA_EXCEEDED":
        return en ? "Request quota exhausted." : "当前请求的额度已用尽"
    case "AUTH", "AUTH_ERROR", "INVALID_API_KEY":
        return en ? "API key is invalid" : "API 密钥无效"
    default:
        return message
    }
}

private let reasoningParagraphBreak = try! NSRegularExpression(pattern: #"\r?\n(?:[\t ]*\r?\n)+"#)

public func reasoningPreview(_ text: String, running: Bool) -> String {
    if !running {
        return String(text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? Substring(text))
            .replacingOccurrences(of: "**", with: "")
    }
    var summary = ""
    var start = text.startIndex
    let nsRange = NSRange(text.startIndex..., in: text)
    reasoningParagraphBreak.enumerateMatches(in: text, range: nsRange) { match, _, _ in
        guard let match, let range = Range(match.range, in: text) else { return }
        if let newline = text[start...].firstIndex(of: "\n"), newline <= range.lowerBound {
            let line = text[start..<newline].trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { summary = line }
        }
        start = range.upperBound
    }
    if let newline = text[start...].firstIndex(of: "\n") {
        let line = text[start..<newline].trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.isEmpty { summary = line }
    }
    return summary.replacingOccurrences(of: "**", with: "")
}
