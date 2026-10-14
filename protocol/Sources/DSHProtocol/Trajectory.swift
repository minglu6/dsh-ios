import Foundation

/// Desktop `@deepseek-ai/dsh-client-ui-trajectory` `locales.ts` zh dictionary
/// (`deepseek-harness` @ d743267). Invent no copy.
public enum TrajL {
    public static let viewTrajectory = "轨迹"
    public static let toolbarDuration = "时长"
    public static let toolbarTurns = "轮次"
    public static let toolbarCalls = "调用"
    public static let toolbarSearch = "搜索轨迹"
    public static let toolbarSearchPlaceholder = "搜索"

    public static let kindSystem = "系统"
    public static let kindUser = "用户"
    public static let kindContext = "上下文"
    public static let kindCompacted = "已压缩"
    public static let kindAssistant = "助手"
    public static let kindTool = "工具"
    public static let kindSubtool = "子工具"

    public static let columnInput = "输入"
    public static let columnOutput = "输出"
    public static let columnThink = "思考"
    public static let columnTime = "时间"
    public static let columnModel = "模型"
    public static let columnTools = "工具"

    public static func turnLabel(_ turn: Int) -> String { "第 \(turn) 轮" }
    public static let sectionBetweenTurns = "轮次之间"
    public static func groupStep(_ step: Int) -> String { "第 \(step) 步" }
    public static func groupCompaction(_ seq: Int64) -> String { "压缩 \(seq)" }

    public static let statusFailed = "失败"
    public static let statusPending = "等待中"
    public static let statusCompleted = "已完成"

    public static let timingNotAvailable = "不可用"
    public static let timingStarted = "开始时间"
    public static let timingTotalDuration = "总时长"
    public static let timingTtft = "首 token 延迟"
    public static let timingGeneration = "生成"
    public static let timingThroughput = "吞吐量"
    public static let timingDuration = "时长"
    public static let timingSource = "计时来源"
    public static let timingSessionTimestamps = "会话时间戳"
    public static let timingSessionTimestampsRunning = "会话时间戳（运行中）"
    public static let timingFirstTokenUnavailable = "首 token 时间不可用"
    public static let timingRequest = "请求计时"

    public static func unitMilliseconds(_ value: String) -> String { "\(value) 毫秒" }
    public static func unitTokens(_ value: Int64) -> String { "\(value) tok" }
    public static func unitTokensPerSecond(_ value: String) -> String { "\(value) tok/s" }

    public static let usageTokens = "Token"
    public static let usageReasoning = "推理"
    public static let usageContent = "内容"
    public static let usageInput = "输入"
    public static let usageOutput = "输出"

    public static let tabSummary = "概述"
    public static let tabRawOutput = "原始输出"
    public static let tabPreview = "预览"
    public static let tabRaw = "原始内容"
    public static let tabSource = "来源"
    public static let tabPayload = "参数"
    public static let tabResult = "结果"
    public static let tabSchema = "Schema"
    public static let tabTiming = "计时"
    public static let tabDiff = "差异"
    public static let tabSystemPrompt = "系统提示词"
    public static let tabTools = "工具"
    public static let tabOptions = "选项"
    public static let tabUsage = "用量"

    public static let requestLabelPrefix = "请求 #"
    public static func requestLabel(_ n: Int) -> String { "请求 #\(n)" }
    public static func requestLabelCompaction(_ n: Int) -> String { "请求 #\(n) · 压缩" }
    public static let requestCompactionPurpose = "压缩"
    public static func requestRetryProgress(retry: Int, maximum: Int) -> String { "\(retry)/\(maximum)" }

    public static let detailsPurpose = "用途"
    public static let detailsProvider = "提供方"
    public static let detailsModel = "模型"
    public static let detailsToolCalls = "工具调用"
    public static let detailsSubtoolCalls = "子工具调用"
    public static let detailsError = "错误"
    public static let detailsLastAttemptError = "上次尝试错误"
    public static let detailsRetry = "重试"
    public static let detailsRetryDelay = "重试延迟"
    public static let detailsResult = "结果"
    public static let detailsCompacted = "已压缩"
    public static let detailsFailureAuth = "API 密钥无效"
    public static func requestCompactionSection(_ section: String) -> String { "压缩 · \(section)" }

    public static let usageThisRequest = "本次请求"
    public static let usageSessionCumulative = "会话累计"
    public static let usageCached = "缓存读取"
    public static let usageCacheCreated = "缓存写入"
    public static let usageNotReported = "未报告用量"
    public static let optionsNotRecorded = "未记录选项"
    public static let optionsJson = "请求选项 JSON"

    public static let historyLoadingTrajectory = "正在加载轨迹…"
    public static let historyLoadingEarlier = "正在加载更早的历史…"
    public static let historyLoadEarlier = "加载更早的历史"
    public static let historyClickToLoadEarlier = "点击加载更早的历史"

    public static let recordToolCallOnly = "（仅工具调用）"
    public static let recordNoContent = "无内容"
    public static let recordNoPayload = "未捕获参数"
    public static let recordNoResult = "未捕获结果"
    public static let recordNoOutput = "无输出"
    public static let recordSchemaUnavailable = "Schema 不可用"
    public static let recordParameters = "参数"
    public static let recordThinking = "思考"
    public static let recordSystemPromptMissing = "本次请求没有系统提示词"
    public static let recordToolsMissing = "本次请求没有工具"
    public static let recordSystemPrompt = "系统提示词"
    public static let recordTools = "工具"

    public static let codeSource = "代码"
    public static let codeOutput = "输出"
    public static let codeRunning = "执行中…"
    public static let codeOriginalJson = "原始 JSON"

    public static let detailsStatus = "状态"
    public static let detailsHierarchy = "层级"
    public static let detailsAssistantMessage = "助手消息"
    public static let detailsToolCall = "工具调用"
    public static let detailsSource = "来源"
    public static let detailsEvent = "事件详情"
    public static let detailsClose = "关闭详情"

    public static let sourceUser = "用户"
    public static let sourceUnknown = "未知"
    public static let sourceNotRecorded = "未记录来源"

    public static let layoutCompacting = "正在压缩上下文…"
    public static let layoutCompactionFailed = "上下文压缩失败"
    public static let layoutCompacted = "上下文已压缩"
    public static let layoutToolCallOnly = "仅工具调用"
    public static let layoutInitialSystemPrompt = "初始系统提示词"
    public static let layoutSystemPromptUpdated = "系统提示词已更新"
    public static let layoutToolsUpdated = "工具已更新"
    public static let layoutSystemPromptAndToolsUpdated = "系统提示词和工具已更新"
    public static let layoutCompactionInterrupted = "上下文压缩在完成前被中断。"
    public static func layoutImageCount(_ count: Int) -> String { "图片 ×\(count)" }
    public static func layoutFileAttachments(_ count: Int) -> String { "文件 ×\(count)" }
    public static func layoutToolAdded(_ name: String) -> String { "已添加工具：\(name)" }
    public static func layoutToolRemoved(_ name: String) -> String { "已移除工具：\(name)" }

    public static let emptyTrajectory = "暂无轨迹"
}

/// Desktop `code-program.ts` PTC entry point name.
public let ptcToolName = "run_code"

public struct CodeProgram: Sendable, Equatable {
    public var rawInput: String
    public var source: String
    public var description: String
    public var language: String?
}

/// One row in the Trajectory tab (desktop ui-trajectory cell kinds).
public struct TrajRow: Sendable, Equatable, Identifiable {
    public var key: String
    public var depth: Int
    public var kind: String
    public var title: String
    public var input: String
    public var output: String
    public var think: String
    public var time: String
    public var running: Bool
    public var thinkingDetail: String?
    public var inputDetail: String?
    public var outputDetail: String?
    public var schemaDetail: String?
    public var rawDetail: String?
    public var messageSourceJson: String?
    public var previousText: String?
    public var toolsJson: String?
    public var previousToolsJson: String?
    public var toolName: String?
    public var resultPreview: String?
    public var toolCallOnly: Bool
    public var firstTokenTime: Int64?
    public var turn: Int?
    public var step: Int?
    public var startedAt: Int64?
    public var timeSeconds: Double?
    public var isError: Bool
    public var searchText: String
    public var outputTokens: Int64?
    public var reasoningTokens: Int64?
    public var toolCallIds: [String]
    public var callId: String?

    public var id: String { key }

    public init(
        key: String,
        depth: Int,
        kind: String,
        title: String,
        input: String = "",
        output: String = "",
        think: String = "",
        time: String = "",
        running: Bool = false,
        thinkingDetail: String? = nil,
        inputDetail: String? = nil,
        outputDetail: String? = nil,
        schemaDetail: String? = nil,
        rawDetail: String? = nil,
        messageSourceJson: String? = nil,
        previousText: String? = nil,
        toolsJson: String? = nil,
        previousToolsJson: String? = nil,
        toolName: String? = nil,
        resultPreview: String? = nil,
        toolCallOnly: Bool = false,
        firstTokenTime: Int64? = nil,
        turn: Int? = nil,
        step: Int? = nil,
        startedAt: Int64? = nil,
        timeSeconds: Double? = nil,
        isError: Bool = false,
        searchText: String = "",
        outputTokens: Int64? = nil,
        reasoningTokens: Int64? = nil,
        toolCallIds: [String] = [],
        callId: String? = nil
    ) {
        self.key = key
        self.depth = depth
        self.kind = kind
        self.title = title
        self.input = input
        self.output = output
        self.think = think
        self.time = time
        self.running = running
        self.thinkingDetail = thinkingDetail
        self.inputDetail = inputDetail
        self.outputDetail = outputDetail
        self.schemaDetail = schemaDetail
        self.rawDetail = rawDetail
        self.messageSourceJson = messageSourceJson
        self.previousText = previousText
        self.toolsJson = toolsJson
        self.previousToolsJson = previousToolsJson
        self.toolName = toolName
        self.resultPreview = resultPreview
        self.toolCallOnly = toolCallOnly
        self.firstTokenTime = firstTokenTime
        self.turn = turn
        self.step = step
        self.startedAt = startedAt
        self.timeSeconds = timeSeconds
        self.isError = isError
        self.searchText = searchText
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.toolCallIds = toolCallIds
        self.callId = callId
    }
}

public struct TrajTurn: Sendable, Equatable {
    public var index: Int
    public var rows: [TrajRow]
    public init(index: Int, rows: [TrajRow]) {
        self.index = index
        self.rows = rows
    }
}

public enum TrajDetailTab: String, Sendable, Equatable, CaseIterable {
    case overview
    case input
    case code
    case output
    case rawOutput
    case schema
    case timing
    case preview
    case raw
    case thinking
    case source
    case diff
    case systemPrompt
    case tools

    public var label: String {
        switch self {
        case .overview: return TrajL.tabSummary
        case .input: return TrajL.tabPayload
        case .code: return TrajL.codeSource
        case .output: return TrajL.tabResult
        case .rawOutput: return TrajL.tabRawOutput
        case .schema: return TrajL.tabSchema
        case .timing: return TrajL.tabTiming
        case .preview: return TrajL.tabPreview
        case .raw: return TrajL.tabRaw
        case .thinking: return TrajL.recordThinking
        case .source: return TrajL.tabSource
        case .diff: return TrajL.tabDiff
        case .systemPrompt: return TrajL.tabSystemPrompt
        case .tools: return TrajL.tabTools
        }
    }
}

public enum TrajectoryRecordState: Sendable {
    case complete, running, error
}

private let posix = Locale(identifier: "en_US_POSIX")

/// Compact token count for trajectory columns (`17730` → `17.7k`).
public func kfmt(_ n: Int64) -> String {
    if n >= 1000 {
        return String(format: "%.1fk", locale: posix, Double(n) / 1000.0)
    }
    return "\(n)"
}

/// Elapsed wall time: under 10s two decimals; otherwise one (`2.20s`, `14.6s`).
public func formatElapsed(_ ms: Int64) -> String {
    let seconds = Double(ms) / 1000.0
    if ms < 10_000 {
        return String(format: "%.2fs", locale: posix, seconds)
    }
    return String(format: "%.1fs", locale: posix, seconds)
}

public func formatDurationMillis(_ milliseconds: Double?) -> String {
    guard let milliseconds, milliseconds.isFinite else { return "—" }
    let integer = Int64((milliseconds).rounded())
    let digits = "\(integer)"
    var chunks: [String] = []
    var rest = digits
    while rest.count > 3 {
        chunks.append(String(rest.suffix(3)))
        rest = String(rest.dropLast(3))
    }
    chunks.append(rest)
    return "\(chunks.reversed().joined(separator: ",")) 毫秒"
}

public func formatElapsedSeconds(_ seconds: Double?) -> String {
    formatDurationMillis(seconds.map { $0 * 1000.0 })
}

public func formatStartedAt(_ timestampMs: Int64?) -> String {
    guard let timestampMs else { return TrajL.timingNotAvailable }
    let date = Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000.0)
    let formatter = DateFormatter()
    formatter.locale = posix
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
}

public func trajectoryToolState(isError: Bool, hasOutput: Bool) -> TrajectoryRecordState {
    if isError { return .error }
    if !hasOutput { return .running }
    return .complete
}

public func trajectoryStatusLabel(_ state: TrajectoryRecordState) -> String {
    switch state {
    case .error: return TrajL.statusFailed
    case .running: return TrajL.statusPending
    case .complete: return TrajL.statusCompleted
    }
}

public func trajectoryPreviewText(_ text: String, max: Int = 512) -> String {
    let collapsed = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if collapsed.count > max {
        return String(collapsed.prefix(max)) + "…"
    }
    return collapsed
}

private func oneLinePreview(_ text: String, max: Int = 96) -> String {
    trajectoryPreviewText(text, max: max)
}

private func firstLine(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
        .map(String.init) ?? ""
}

private func assistantTitle(reply: String, reasoning: String) -> (String, Bool) {
    let fromReply = firstLine(reply)
    if !fromReply.isEmpty { return (fromReply, false) }
    let fromThink = firstLine(reasoning)
    if !fromThink.isEmpty { return (fromThink, false) }
    return (TrajL.layoutToolCallOnly, true)
}

public func codeProgram(toolName: String?, inputDetail: String?, schemaDetail: String?) -> CodeProgram? {
    guard toolName == ptcToolName, let inputDetail, !inputDetail.isEmpty else { return nil }
    guard let parsed = try? JSONValue.parse(inputDetail), let obj = parsed.obj() else { return nil }
    guard let code = obj["code"]?.str() else { return nil }
    let description: String
    if obj["description"] == nil || obj["description"]?.isNull == true {
        description = firstLine(code)
    } else if let d = obj["description"]?.str() {
        let trimmed = d.trimmingCharacters(in: .whitespacesAndNewlines)
        description = trimmed.isEmpty ? firstLine(code) : trimmed
    } else {
        return nil
    }
    return CodeProgram(rawInput: inputDetail, source: code, description: description, language: recordedLanguage(schemaDetail))
}

private func recordedLanguage(_ schemaRaw: String?) -> String? {
    guard let schemaRaw, let parsed = try? JSONValue.parse(schemaRaw), let obj = parsed.obj() else { return nil }
    let description = obj["parameters"]["properties"]["code"]["description"].str() ?? ""
    let ts = description.range(of: #"\bTypeScript\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    let py = description.range(of: #"\bPython\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    if ts == py { return nil }
    return ts ? "typescript" : "python"
}

private func assistantRow(_ step: StepRecord) -> TrajRow {
    let start = step.stepStartTime
    let end = step.messageTime
    let elapsedMs: Int64? = {
        if let start, let end { return max(0, end - start) }
        return nil
    }()
    let elapsed = elapsedMs.map(formatElapsed) ?? ""
    let input = step.usage.inputTokens.map(kfmt) ?? ""
    let output = step.usage.outputTokens.map(kfmt) ?? ""
    let think = step.usage.reasoningTokens.map(kfmt) ?? "—"
    let (title, toolOnly) = assistantTitle(reply: step.replyText, reasoning: step.reasoningText)
    let raw = [step.reasoningText, step.replyText]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    return TrajRow(
        key: "a\(step.seq)",
        depth: 0,
        kind: TrajL.kindAssistant,
        title: title,
        input: input,
        output: output,
        think: think,
        time: elapsed,
        thinkingDetail: step.reasoningText.isEmpty ? nil : step.reasoningText,
        outputDetail: step.replyText.isEmpty ? nil : step.replyText,
        rawDetail: raw.isEmpty ? nil : raw,
        toolCallOnly: toolOnly,
        firstTokenTime: step.firstTokenTime,
        turn: step.turn,
        step: step.step,
        startedAt: start,
        timeSeconds: elapsedMs.map { Double($0) / 1000.0 },
        isError: step.interrupted,
        searchText: [step.replyText, step.reasoningText, step.model ?? "", step.provider ?? ""].joined(separator: "\n"),
        outputTokens: step.usage.outputTokens,
        reasoningTokens: step.usage.reasoningTokens,
        toolCallIds: step.toolCallIds
    )
}

private func liveAssistantRow(key: String, reply: String, reasoning: String) -> TrajRow {
    let (title, toolOnly) = assistantTitle(reply: reply, reasoning: reasoning)
    let raw = [reasoning, reply]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    return TrajRow(
        key: key,
        depth: 0,
        kind: TrajL.kindAssistant,
        title: title,
        think: "—",
        time: "…",
        running: true,
        thinkingDetail: reasoning.isEmpty ? nil : reasoning,
        outputDetail: reply.isEmpty ? nil : reply,
        rawDetail: raw.isEmpty ? nil : raw,
        toolCallOnly: toolOnly,
        searchText: "\(reply)\n\(reasoning)"
    )
}

private func toolResultPreview(_ item: Item.Tool) -> String? {
    if let error = item.error { return error }
    let result = item.result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if result.isEmpty {
        return item.status == .ok ? TrajL.recordNoOutput : nil
    }
    return trajectoryPreviewText(result, max: 96)
}

private func preparingToolTitle(_ name: String) -> String { name }

private func toolRow(_ item: Item.Tool) -> TrajRow {
    let preparing = item.status == .preparing
    let running = preparing || item.status == .running || item.status == .awaitingApproval
    let started = item.startedAt
    let ended = item.endedAt
    let durMs: Int64? = {
        if let started, let ended { return max(0, ended - started) }
        return nil
    }()
    let dur: String = {
        if let durMs { return formatElapsed(durMs) }
        if running { return "…" }
        return ""
    }()
    let program = codeProgram(toolName: item.name, inputDetail: item.arguments, schemaDetail: item.schemaJson)
    let title: String = {
        if preparing { return preparingToolTitle(item.name) }
        if let program {
            let desc = program.description.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            return "\(ptcToolName) · \(desc)"
        }
        let args = trajectoryPreviewText(item.arguments)
        return args.isEmpty ? item.name : "\(item.name) \(args)"
    }()
    let outputDetail: String? = {
        if let error = item.error {
            return [error, item.result].compactMap { $0 }.joined(separator: "\n")
        }
        return item.result
    }()
    let isSub = !(item.parentCallId ?? "").isEmpty
    let timeSeconds: Double? = {
        if running && durMs == nil { return nil }
        return durMs.map { Double($0) / 1000.0 }
    }()
    return TrajRow(
        key: item.key,
        depth: isSub ? 2 : 1,
        kind: isSub ? TrajL.kindSubtool : TrajL.kindTool,
        title: title,
        time: dur,
        running: running,
        inputDetail: item.arguments.isEmpty ? nil : item.arguments,
        outputDetail: outputDetail,
        schemaDetail: item.schemaJson,
        toolName: item.name,
        resultPreview: toolResultPreview(item),
        turn: item.turn,
        step: item.step,
        startedAt: started,
        timeSeconds: timeSeconds,
        isError: item.status == .error,
        searchText: [item.name, item.arguments, item.result ?? "", item.error ?? "", item.schemaJson ?? "", item.parentCallId ?? ""].joined(separator: "\n"),
        callId: item.callId
    )
}

private func compactedRow(_ item: Item.Compacted) -> TrajRow {
    let running = item.status == .running
    let title: String = {
        if running { return TrajL.layoutCompacting }
        if item.interrupted { return TrajL.layoutCompactionInterrupted }
        if item.status == .error { return item.error ?? TrajL.layoutCompactionFailed }
        if let summary = item.summary, !summary.isEmpty { return oneLinePreview(summary) }
        return TrajL.layoutCompacted
    }()
    let durMs: Int64? = {
        if let started = item.startedAt, let ended = item.endedAt { return max(0, ended - started) }
        return nil
    }()
    return TrajRow(
        key: item.key,
        depth: 0,
        kind: TrajL.kindCompacted,
        title: title,
        time: {
            if let durMs { return formatElapsed(durMs) }
            if running { return "…" }
            return ""
        }(),
        running: running,
        outputDetail: item.summary,
        rawDetail: item.summary ?? item.error,
        turn: item.turn,
        startedAt: item.startedAt,
        timeSeconds: running ? nil : durMs.map { Double($0) / 1000.0 },
        isError: item.status == .error,
        searchText: [item.summary ?? "", item.error ?? "", item.compactionId].joined(separator: "\n")
    )
}

private func userTitle(_ item: Item.User) -> String {
    var parts: [String] = []
    if item.images > 0 { parts.append(TrajL.layoutImageCount(item.images)) }
    let preview = oneLinePreview(item.text, max: 80)
    if !preview.isEmpty { parts.append(preview) }
    return parts.isEmpty ? TrajL.recordNoContent : parts.joined(separator: " · ")
}

private func itemSeq(_ item: Item) -> Int64? {
    switch item {
    case .text(let t):
        let body = String(t.key.dropFirst())
        return Int64(body.split(separator: ".").first.map(String.init) ?? "")
    case .reasoning(let r):
        let body = String(r.key.dropFirst())
        return Int64(body.split(separator: ".").first.map(String.init) ?? "")
    default:
        return nil
    }
}

/// Fold chat items and settled step records into turn-grouped trajectory rows.
public func buildTrajectory(_ items: [Item], steps: [StepRecord] = []) -> [TrajTurn] {
    if items.isEmpty { return [] }
    var turns: [TrajTurn] = []
    var turnIdx = 0
    var rows: [TrajRow] = []
    var pendingPrefix: [TrajRow] = []
    var emitted = Array(repeating: false, count: steps.count)
    var stepBySeq: [Int64: Int] = [:]
    var stepByTool: [String: Int] = [:]
    for (i, s) in steps.enumerated() {
        stepBySeq[s.seq] = i
        for id in s.toolCallIds { stepByTool[id] = i }
    }

    func flush() {
        if rows.isEmpty { return }
        turns.append(TrajTurn(index: turnIdx, rows: rows))
        rows = []
    }

    func emitStep(_ i: Int) {
        guard i >= 0, i < steps.count, !emitted[i] else { return }
        emitted[i] = true
        rows.append(assistantRow(steps[i]))
    }

    func emitBySeq(_ seq: Int64?) {
        guard let seq, let i = stepBySeq[seq] else { return }
        emitStep(i)
    }

    func addPrefixOrRow(_ row: TrajRow) {
        if turnIdx == 0 { pendingPrefix.append(row) } else { rows.append(row) }
    }

    var liveAssistantKey: String?
    for item in items {
        switch item {
        case .deliverable, .changes:
            break
        case .retry, .turnFailure:
            break
        case .system(let sys):
            addPrefixOrRow(TrajRow(
                key: sys.key, depth: 0, kind: TrajL.kindSystem, title: sys.label,
                rawDetail: sys.text,
                previousText: sys.previousText,
                toolsJson: sys.toolsJson,
                previousToolsJson: sys.previousToolsJson,
                startedAt: sys.at, timeSeconds: 0.0,
                searchText: [sys.label, sys.text, sys.toolsJson ?? "", sys.previousText ?? ""].joined(separator: "\n")
            ))
        case .context(let ctx):
            addPrefixOrRow(TrajRow(
                key: ctx.key, depth: 0, kind: TrajL.kindContext, title: oneLinePreview(ctx.text),
                inputDetail: ctx.text, rawDetail: ctx.text,
                messageSourceJson: ctx.messageSourceJson,
                startedAt: ctx.at, timeSeconds: 0.0,
                searchText: [ctx.text, ctx.sourceKind ?? "", ctx.messageSourceJson ?? ""].joined(separator: "\n")
            ))
        case .compacted(let c):
            addPrefixOrRow(compactedRow(c))
        case .user(let user):
            flush()
            turnIdx += 1
            liveAssistantKey = nil
            if !pendingPrefix.isEmpty {
                rows.append(contentsOf: pendingPrefix)
                pendingPrefix.removeAll()
            }
            rows.append(TrajRow(
                key: user.key, depth: 0, kind: TrajL.kindUser, title: userTitle(user),
                time: formatElapsed(0),
                inputDetail: user.text, rawDetail: user.text,
                messageSourceJson: user.messageSourceJson,
                turn: turnIdx,
                startedAt: user.at,
                timeSeconds: 0.0,
                searchText: [user.text, user.messageSourceJson ?? ""].joined(separator: "\n")
            ))
        case .reasoning(let reasoning):
            if reasoning.live {
                let key = liveAssistantKey ?? reasoning.key
                liveAssistantKey = key
                let row = liveAssistantRow(key: key, reply: "", reasoning: reasoning.text)
                if let idx = rows.lastIndex(where: { $0.key == key && $0.kind == TrajL.kindAssistant }) {
                    rows[idx] = row
                } else {
                    rows.append(row)
                }
            } else {
                emitBySeq(itemSeq(item))
            }
        case .text(let text):
            if text.live {
                let key = liveAssistantKey ?? text.key
                liveAssistantKey = key
                let prev = rows.last(where: { $0.key == key && $0.kind == TrajL.kindAssistant })
                let reasoning = prev?.thinkingDetail ?? ""
                let row = liveAssistantRow(key: key, reply: text.text, reasoning: reasoning)
                if let idx = rows.lastIndex(where: { $0.key == key && $0.kind == TrajL.kindAssistant }) {
                    rows[idx] = row
                } else {
                    rows.append(row)
                }
            } else {
                let seq = itemSeq(item)
                let stepIdx = seq.flatMap { stepBySeq[$0] }
                if let stepIdx {
                    emitStep(stepIdx)
                } else if steps.isEmpty {
                    let (title, toolOnly) = assistantTitle(reply: text.text, reasoning: "")
                    rows.append(TrajRow(
                        key: text.key, depth: 0, kind: TrajL.kindAssistant, title: title,
                        think: "—",
                        rawDetail: text.text, outputDetail: text.text,
                        toolCallOnly: toolOnly,
                        searchText: text.text
                    ))
                }
            }
        case .tool(let tool):
            if let i = stepByTool[tool.callId] { emitStep(i) }
            rows.append(toolRow(tool))
        case .notice(let notice):
            rows.append(TrajRow(
                key: notice.key, depth: 0, kind: TrajL.kindSystem, title: oneLinePreview(notice.text, max: 80),
                rawDetail: notice.text, searchText: notice.text
            ))
        }
    }
    if !pendingPrefix.isEmpty && turnIdx == 0 {
        turnIdx = 1
        rows.insert(contentsOf: pendingPrefix, at: 0)
        pendingPrefix.removeAll()
    }
    flush()
    return turns
}

public func trajectoryTimelineCells(_ turns: [TrajTurn]) -> [TrajectoryTimelineCell] {
    turns.flatMap { turn in
        turn.rows.map { row in
            TrajectoryTimelineCell(
                key: row.key,
                kind: row.kind,
                label: row.title,
                turn: turn.index,
                startedAt: row.startedAt,
                timeSeconds: row.timeSeconds,
                isError: row.isError
            )
        }
    }
}

/// Desktop search: trim → lowercase → whitespace-split → AND of includes.
public func trajectorySearchMatches(_ turns: [TrajTurn], query: String) -> Set<String>? {
    let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .split(whereSeparator: \.isWhitespace)
        .map(String.init)
        .filter { !$0.isEmpty }
    if terms.isEmpty { return nil }
    var matches = Set<String>()
    for turn in turns {
        for row in turn.rows {
            let hay = [
                row.kind, row.title, row.input, row.output, row.think, row.time, row.searchText
            ].joined(separator: "\n").lowercased()
            if terms.allSatisfy({ hay.contains($0) }) {
                matches.insert(row.key)
            }
        }
    }
    return matches
}

public func trajDetailTabs(_ row: TrajRow) -> [TrajDetailTab] {
    switch row.kind {
    case TrajL.kindSystem:
        if row.previousText != nil {
            return [.diff, .systemPrompt, .tools]
        }
        if row.toolsJson != nil {
            return [.systemPrompt, .tools]
        }
        return [.systemPrompt]
    case TrajL.kindCompacted:
        return [.overview, .rawOutput]
    case TrajL.kindTool, TrajL.kindSubtool:
        var tabs: [TrajDetailTab] = [.overview]
        let program = codeProgram(toolName: row.toolName, inputDetail: row.inputDetail, schemaDetail: row.schemaDetail)
        if row.inputDetail != nil {
            tabs.append(program != nil ? .code : .input)
        }
        if row.outputDetail != nil || program != nil {
            tabs.append(.output)
        }
        tabs.append(.schema)
        tabs.append(.timing)
        return tabs
    case TrajL.kindAssistant:
        var tabs: [TrajDetailTab] = [.overview, .preview, .raw]
        if row.messageSourceJson != nil { tabs.append(.source) }
        return tabs
    default:
        var tabs: [TrajDetailTab] = [.overview, .preview, .raw]
        if row.messageSourceJson != nil { tabs.append(.source) }
        return tabs
    }
}

public func trajDetailKindLabel(_ kind: String) -> String {
    switch kind {
    case TrajL.kindAssistant: return TrajL.kindAssistant
    case TrajL.kindTool: return TrajL.kindTool
    case TrajL.kindSubtool: return TrajL.kindSubtool
    case TrajL.kindUser: return TrajL.kindUser
    case TrajL.kindContext: return TrajL.kindContext
    case TrajL.kindSystem: return TrajL.kindSystem
    case TrajL.kindCompacted: return TrajL.kindCompacted
    default: return kind
    }
}

public func trajDetailLocation(_ row: TrajRow, turnIndex: Int) -> String {
    let turn = row.turn ?? (turnIndex > 0 ? turnIndex : nil)
    let turnLabel = turn.map(TrajL.turnLabel) ?? TrajL.sectionBetweenTurns
    if let step = row.step {
        return "\(turnLabel) · \(TrajL.groupStep(step))"
    }
    return turnLabel
}

public func trajRowState(_ row: TrajRow) -> TrajectoryRecordState {
    switch row.kind {
    case TrajL.kindTool, TrajL.kindSubtool:
        return trajectoryToolState(isError: row.isError, hasOutput: row.outputDetail != nil)
    case TrajL.kindCompacted:
        if row.isError { return .error }
        if row.running || row.timeSeconds == nil { return .running }
        return .complete
    default:
        if row.isError { return .error }
        if row.running { return .running }
        return .complete
    }
}

public func formatAssistantDuration(_ seconds: Double?) -> String {
    guard let seconds, seconds.isFinite else { return TrajL.timingNotAvailable }
    let value = max(0.0, seconds)
    if value < 1 {
        return TrajL.unitMilliseconds("\(Int64((value * 1000).rounded()))")
    }
    if value < 10 {
        return String(format: "%.2f 秒", locale: posix, value)
    }
    return String(format: "%.1f 秒", locale: posix, value)
}

public func formatTtft(_ row: TrajRow) -> String {
    guard let start = row.startedAt else { return TrajL.timingFirstTokenUnavailable }
    guard let first = row.firstTokenTime else { return TrajL.timingFirstTokenUnavailable }
    return formatAssistantDuration(Double(max(0, first - start)) / 1000.0)
}

public func formatGeneration(_ row: TrajRow) -> String {
    guard let first = row.firstTokenTime else { return TrajL.timingFirstTokenUnavailable }
    let end: Int64? = {
        if let start = row.startedAt, let seconds = row.timeSeconds {
            return start + Int64(seconds * 1000)
        }
        return nil
    }()
    guard let end else {
        return row.running ? TrajL.statusPending : TrajL.timingNotAvailable
    }
    return formatAssistantDuration(Double(max(0, end - first)) / 1000.0)
}

public func formatThroughput(_ row: TrajRow) -> String {
    guard let first = row.firstTokenTime else { return TrajL.timingFirstTokenUnavailable }
    if row.running { return TrajL.statusPending }
    let end: Int64? = {
        if let start = row.startedAt, let seconds = row.timeSeconds {
            return start + Int64(seconds * 1000)
        }
        return nil
    }()
    guard let end else { return TrajL.timingNotAvailable }
    let seconds = Double(end - first) / 1000.0
    if seconds <= 0 { return "时长过短" }
    guard let tokens = row.outputTokens else { return TrajL.timingNotAvailable }
    return TrajL.unitTokensPerSecond(String(format: "%.1f", locale: posix, Double(tokens) / seconds))
}

public func toolCatalogDiff(previousJson: String?, currentJson: String?) -> String? {
    let prev = toolNames(previousJson)
    let curr = toolNames(currentJson)
    if prev.isEmpty && curr.isEmpty { return nil }
    let added = curr.subtracting(prev).sorted()
    let removed = prev.subtracting(curr).sorted()
    var lines: [String] = []
    for name in added { lines.append(TrajL.layoutToolAdded(name)) }
    for name in removed { lines.append(TrajL.layoutToolRemoved(name)) }
    return lines.isEmpty ? nil : lines.joined(separator: "\n")
}

private func toolNames(_ json: String?) -> Set<String> {
    guard let json, let parsed = try? JSONValue.parse(json) else { return [] }
    let arr = parsed.arr() ?? []
    return Set(arr.compactMap { $0["name"].str() })
}

public func formatMessageClock(_ timestampMs: Int64, nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000.0)
    let now = Date(timeIntervalSince1970: TimeInterval(nowMs) / 1000.0)
    let cal = Calendar.current
    let hmFormatter = DateFormatter()
    hmFormatter.locale = posix
    hmFormatter.dateFormat = "HH:mm"
    let hm = hmFormatter.string(from: date)
    if cal.isDate(date, inSameDayAs: now) { return hm }
    let y = cal.component(.year, from: date)
    let m = cal.component(.month, from: date)
    let d = cal.component(.day, from: date)
    if cal.component(.year, from: date) == cal.component(.year, from: now) {
        return "\(m)月\(d)日 \(hm)"
    }
    return "\(y)年\(m)月\(d)日"
}
