import Foundation

/// Exact provider-reported accounting for every billed attempt in a completed turn.
public struct TurnTokenUsage: Equatable, Sendable {
    public var uncachedInputTokens: Int64
    public var outputTokens: Int64
    public var totalTokens: Int64
    public var cacheReadTokens: Int64?
    public var cacheWriteTokens: Int64?
    public var reasoningTokens: Int64?
    public var routes: [TurnTokenUsageRoute]?

    public init(
        uncachedInputTokens: Int64,
        outputTokens: Int64,
        totalTokens: Int64,
        cacheReadTokens: Int64? = nil,
        cacheWriteTokens: Int64? = nil,
        reasoningTokens: Int64? = nil,
        routes: [TurnTokenUsageRoute]? = nil
    ) {
        self.uncachedInputTokens = uncachedInputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.reasoningTokens = reasoningTokens
        self.routes = routes
    }

    /// Positional constructor used by protocol tests (matches Android data-class order).
    public init(
        _ uncachedInputTokens: Int64,
        _ outputTokens: Int64,
        _ totalTokens: Int64,
        _ cacheReadTokens: Int64? = nil,
        _ cacheWriteTokens: Int64? = nil,
        _ reasoningTokens: Int64? = nil,
        _ routes: [TurnTokenUsageRoute]? = nil
    ) {
        self.init(
            uncachedInputTokens: uncachedInputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            cacheReadTokens: cacheReadTokens,
            cacheWriteTokens: cacheWriteTokens,
            reasoningTokens: reasoningTokens,
            routes: routes
        )
    }
}

public struct TurnTokenUsageRoute: Equatable, Hashable, Sendable {
    public var provider: String
    public var model: String
    public init(provider: String, model: String) {
        self.provider = provider
        self.model = model
    }
}

private let maxSafeTokenCount: Int64 = 9_007_199_254_740_991

private func tokenCount(_ value: JSONValue?) -> Int64? {
    guard let value, case .number(let number) = value else { return nil }
    if !number.isFinite || number < 0 || number > Double(maxSafeTokenCount) { return nil }
    let count = Int64(number)
    return Double(count) == number ? count : nil
}

private func tokenSum(_ a: Int64, _ b: Int64) -> Int64? {
    a > maxSafeTokenCount - b ? nil : a + b
}

private struct AttemptUsage {
    var input: Int64
    var output: Int64
    var total: Int64
    var read: Int64?
    var write: Int64?
    var reasoning: Int64?
    var route: TurnTokenUsageRoute?
}

private func normalizeUsage(_ value: JSONValue?, route: TurnTokenUsageRoute?) -> AttemptUsage? {
    guard let value, value.obj() != nil else { return nil }
    let object = value.obj()!
    guard let input = tokenCount(value["inputTokens"]), let output = tokenCount(value["outputTokens"]) else { return nil }
    let read = tokenCount(value["cacheReadTokens"])
    let write = tokenCount(value["cacheWriteTokens"])
    let reasoning = tokenCount(value["reasoningTokens"])
    if object["cacheReadTokens"] != nil && read == nil { return nil }
    if object["cacheWriteTokens"] != nil && write == nil { return nil }
    if object["reasoningTokens"] != nil && (reasoning == nil || reasoning! > output) { return nil }
    guard let promptWithRead = tokenSum(input, read ?? 0), let knownPrompt = tokenSum(promptWithRead, write ?? 0) else { return nil }
    let total: Int64
    if object["totalTokens"] != nil {
        guard let exact = tokenCount(value["totalTokens"]), exact >= output, exact - output >= knownPrompt else { return nil }
        if read != nil && write != nil && exact - output != knownPrompt { return nil }
        total = exact
    } else {
        if read == nil || write == nil { return nil }
        guard let derived = tokenSum(knownPrompt, output) else { return nil }
        total = derived
    }
    return AttemptUsage(input: input, output: output, total: total, read: read, write: write, reasoning: reasoning, route: route)
}

private enum UsageEventKind {
    case turnStart, turnEnd, stepStart, stepEnd, message, attempt, retry, retryStarted
}

private struct UsageEvent {
    var kind: UsageEventKind
    var turn: Int?
    var step: Int?
    var usage: AttemptUsage?
}

private func usageEvent(_ event: JSONValue) -> UsageEvent? {
    let kind: UsageEventKind
    switch event["type"].str() {
    case "turn/start": kind = .turnStart
    case "turn/end": kind = .turnEnd
    case "step/start": kind = .stepStart
    case "step/end": kind = .stepEnd
    case "assistant/message": kind = .message
    case "assistant/attempt": kind = .attempt
    case "llm/retry": kind = .retry
    case "llm/retry-started": kind = .retryStarted
    default: return nil
    }
    let data = event["data"]
    let turn = tokenCount(data["turn"]).flatMap { $0 <= Int64(Int.max) ? Int($0) : nil }
    let step = tokenCount(data["step"]).flatMap { $0 <= Int64(Int.max) ? Int($0) : nil }
    var usage: AttemptUsage?
    if kind == .message || kind == .attempt {
        let finalUsage = data["usage"].isNull ? nil : data["usage"]
        let streamUsage = (data["stream"].arr() ?? []).last(where: {
            $0["type"].str() == "chunk" && $0["chunk"]["type"].str() == "usage"
        })?["chunk"]["usage"]
        let source = data["message"]["source"]
        let provider = source["provider"].str()?.nilIfEmpty
        let model = source["model"].str()?.nilIfEmpty
        let route = (kind == .message && provider != nil && model != nil)
            ? TurnTokenUsageRoute(provider: provider!, model: model!)
            : nil
        usage = normalizeUsage(kind == .message ? (finalUsage ?? streamUsage) : streamUsage, route: route)
    }
    return UsageEvent(kind: kind, turn: turn, step: step, usage: usage)
}

private enum AttemptPhase { case idle, open, finishClosed, messageSettled, retrySettled }

private final class TurnUsageFold {
    let turn: Int?
    private var phase = AttemptPhase.idle
    private var step: Int?
    private var invalid: Bool
    private var ended = false
    private var attempts = 0
    private var input: Int64 = 0
    private var output: Int64 = 0
    private var total: Int64 = 0
    private var read: Int64? = 0
    private var write: Int64? = 0
    private var reasoning: Int64? = 0
    private var attributed = true
    private var routes: [TurnTokenUsageRoute] = []

    init(turn: Int?) {
        self.turn = turn
        self.invalid = turn == nil
    }

    func accept(_ event: UsageEvent) {
        if invalid { return }
        if event.turn != turn || ended || event.kind == .turnStart {
            invalid = true
            return
        }
        switch event.kind {
        case .turnStart:
            invalid = true
        case .turnEnd:
            if phase == .idle { ended = true } else { invalid = true }
        case .stepStart:
            if phase != .idle || event.step == nil { invalid = true }
            else { phase = .open; step = event.step }
        default:
            if phase == .idle || event.step != step { invalid = true; return }
            switch event.kind {
            case .retryStarted:
                if phase != .retrySettled { invalid = true } else { phase = .open }
            case .message, .attempt:
                guard phase == .open, let usage = event.usage else { invalid = true; return }
                add(usage)
                phase = event.kind == .message ? .messageSettled : .finishClosed
            case .retry:
                if phase != .finishClosed { invalid = true } else { phase = .retrySettled }
            case .stepEnd:
                if phase == .open { invalid = true } else { phase = .idle }
            default:
                break
            }
        }
    }

    private func add(_ usage: AttemptUsage) {
        guard let nextInput = tokenSum(input, usage.input),
              let nextOutput = tokenSum(output, usage.output),
              let nextTotal = tokenSum(total, usage.total) else {
            invalid = true
            return
        }
        input = nextInput
        output = nextOutput
        total = nextTotal
        read = read.flatMap { a in usage.read.flatMap { tokenSum(a, $0) } }
        write = write.flatMap { a in usage.write.flatMap { tokenSum(a, $0) } }
        reasoning = reasoning.flatMap { a in usage.reasoning.flatMap { tokenSum(a, $0) } }
        if let route = usage.route {
            if !routes.contains(route) { routes.append(route) }
        } else {
            attributed = false
        }
        attempts += 1
    }

    func result() -> TurnTokenUsage? {
        if invalid || !ended || phase != .idle || attempts == 0 { return nil }
        return TurnTokenUsage(
            uncachedInputTokens: input,
            outputTokens: output,
            totalTokens: total,
            cacheReadTokens: read,
            cacheWriteTokens: write,
            reasoningTokens: reasoning,
            routes: attributed ? routes : nil
        )
    }
}

/// Fed only after TranscriptReducer's seq dedupe; older pages replay these compact facts.
final class TurnUsageLedger {
    private var events: [UsageEvent] = []
    private var completed: [Int: TurnTokenUsage] = [:]
    private var current: TurnUsageFold?
    private var snapshotValue: [Int: TurnTokenUsage] = [:]
    private var snapshotDirty = false

    func snapshot() -> [Int: TurnTokenUsage] {
        if snapshotDirty {
            snapshotValue = completed
            snapshotDirty = false
        }
        return snapshotValue
    }

    func clear() {
        events.removeAll()
        completed.removeAll()
        current = nil
        snapshotValue = [:]
        snapshotDirty = false
    }

    func apply(_ event: JSONValue) {
        guard let fact = usageEvent(event) else { return }
        events.append(fact)
        fold(fact)
    }

    func prepend(_ earlier: TurnUsageLedger) -> Bool {
        if earlier.events.isEmpty { return false }
        events.insert(contentsOf: earlier.events, at: 0)
        completed.removeAll()
        current = nil
        snapshotValue = [:]
        snapshotDirty = true
        events.forEach(fold)
        return true
    }

    private func fold(_ event: UsageEvent) {
        let old = current
        if event.kind == .turnStart && (old == nil || old?.turn != event.turn) {
            current = TurnUsageFold(turn: event.turn)
        } else {
            old?.accept(event)
        }
        guard let active = current, let turn = active.turn else { return }
        let result = active.result()
        let changed: Bool
        if let result {
            changed = completed[turn] != result
            completed[turn] = result
        } else {
            changed = completed.removeValue(forKey: turn) != nil
        }
        if changed { snapshotDirty = true }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
