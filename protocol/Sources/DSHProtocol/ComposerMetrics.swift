import Foundation

/// Whole-log Host projections; nil is unavailable, not a zero reading.
public struct ComposerMetrics: Equatable, Sendable {
    public var activity: ComposerActivity?
    public var tokens: ComposerTokenUsage?
    public var context: ComposerContext?
    public var contextBreakdown: ComposerContextBreakdown?
    /// False only for the official window-scoped fallback on Hosts without session-stats.
    public var activityIsWholeSession: Bool

    public init(
        activity: ComposerActivity? = nil,
        tokens: ComposerTokenUsage? = nil,
        context: ComposerContext? = nil,
        contextBreakdown: ComposerContextBreakdown? = nil,
        activityIsWholeSession: Bool = false
    ) {
        self.activity = activity
        self.tokens = tokens
        self.context = context
        self.contextBreakdown = contextBreakdown
        self.activityIsWholeSession = activityIsWholeSession
    }
}

public struct ComposerActivity: Equatable, Sendable {
    public var turns: Int64
    public var steps: Int64
    public var llmMs: Double
    public var toolMs: Double
    public var ttftMs: Double
    public var ttftSteps: Int64
    public var decodeMs: Double
    public var decodeTokens: Int64

    public var tokensPerSecond: Double? { decodeMs > 0 ? Double(decodeTokens) / (decodeMs / 1000) : nil }
    public var meanTtftMs: Double? { ttftSteps > 0 ? ttftMs / Double(ttftSteps) : nil }

    public init(
        turns: Int64,
        steps: Int64,
        llmMs: Double,
        toolMs: Double,
        ttftMs: Double,
        ttftSteps: Int64,
        decodeMs: Double,
        decodeTokens: Int64
    ) {
        self.turns = turns
        self.steps = steps
        self.llmMs = llmMs
        self.toolMs = toolMs
        self.ttftMs = ttftMs
        self.ttftSteps = ttftSteps
        self.decodeMs = decodeMs
        self.decodeTokens = decodeTokens
    }
}

public struct ComposerTokenUsage: Equatable, Sendable {
    public var uncachedInputTokens: Int64
    public var cacheReadTokens: Int64
    public var cacheWriteTokens: Int64
    public var outputTokens: Int64

    public var billedInputTokens: Int64 { uncachedInputTokens + cacheReadTokens + cacheWriteTokens }
    public var totalTokens: Int64 { billedInputTokens + outputTokens }
    public var cacheHitPercent: String? { formatComposerCacheHit(cacheReadTokens, billedInputTokens) }

    public init(uncachedInputTokens: Int64, cacheReadTokens: Int64, cacheWriteTokens: Int64, outputTokens: Int64) {
        self.uncachedInputTokens = uncachedInputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.outputTokens = outputTokens
    }
}

public struct ComposerContext: Equatable, Sendable {
    public var usedTokens: Double
    public var contextWindow: Double
    public var percent: Int {
        Int((usedTokens / contextWindow * 100 + 0.5).rounded(.down).clamped(to: 0...100))
    }
}

public struct ComposerContextBreakdown: Equatable, Sendable {
    public var systemTokens: Double
    public var toolsTokens: Double
    public var messageTokens: Double
}

/// Durable call/result facts, separate from tool-card creation and PTC dispatch timing.
final class ToolCallTiming {
    var callStartedAt: Int64?
    var resultAt: Int64?
    init(callStartedAt: Int64? = nil, resultAt: Int64? = nil) {
        self.callStartedAt = callStartedAt
        self.resultAt = resultAt
    }
}

/// Match token-format.ts: a partial cache hit must never round to 100%.
public func formatComposerCacheHit(_ cacheReadTokens: Int64, _ promptTokens: Int64) -> String? {
    if promptTokens <= 0 || cacheReadTokens < 0 || cacheReadTokens > promptTokens { return nil }
    if cacheReadTokens == promptTokens { return "100" }
    let numerator = Decimal(cacheReadTokens) * 100
    let denominator = Decimal(promptTokens)
    var places = 0
    var rounded = (numerator / denominator).rounded(places)
    while rounded == 100 {
        places += 1
        rounded = (numerator / denominator).rounded(places)
    }
    return rounded.stripTrailingZeros()
}

/// Same higher-seq-wins semantics as the official ProjectionValueStore, independent of event cursor.
final class ComposerProjectionStore {
    private var sequences: [String: Int64] = [:]
    private let keys: Set<String> = ["sessionStats", "tokenUsage", "contextPressure", "contextBreakdown"]
    private(set) var activity: ComposerActivity?
    private(set) var tokens: ComposerTokenUsage?
    private(set) var context: ComposerContext?
    private(set) var contextBreakdown: ComposerContextBreakdown?

    @discardableResult
    func apply(key: String, value: JSONValue?, seq: Int64) -> Bool {
        if !keys.contains(key) { return false }
        if let previous = sequences[key], seq <= previous { return false }
        sequences[key] = seq
        readValue(key, value)
        return true
    }

    private func readValue(_ key: String, _ value: JSONValue?) {
        switch key {
        case "sessionStats": activity = parseActivity(value)
        case "tokenUsage": tokens = parseTokens(value)
        case "contextPressure": context = parseContext(value)
        case "contextBreakdown": contextBreakdown = parseBreakdown(value)
        default: break
        }
    }

    func baseline(_ projections: JSONValue?, fallbackSeq: Int64) {
        guard let values = projections?["values"].obj() else { return }
        let seq = projections?["asOfSeq"].long() ?? fallbackSeq
        for key in keys {
            if values[key] != nil {
                apply(key: key, value: values[key], seq: seq)
            } else if (sequences[key] ?? Int64.min) <= seq {
                sequences.removeValue(forKey: key)
                readValue(key, nil)
            }
        }
    }

    func clear() {
        sequences.removeAll()
        for key in keys { readValue(key, nil) }
    }

    func metrics(steps: [StepRecord], toolTimings: [ToolCallTiming]) -> ComposerMetrics {
        ComposerMetrics(
            activity: activity ?? windowActivity(steps, toolTimings),
            tokens: tokens,
            context: context,
            contextBreakdown: contextBreakdown,
            activityIsWholeSession: activity != nil
        )
    }
}

private func nonnegativeNumber(_ value: JSONValue?) -> Double? {
    guard case .number(let number) = value, number.isFinite, number >= 0 else { return nil }
    return number
}

private func nonnegativeCount(_ value: JSONValue?) -> Int64? {
    value?.long().flatMap { $0 >= 0 ? $0 : nil }
}

private func parseActivity(_ v: JSONValue?) -> ComposerActivity? {
    guard v?.obj() != nil else { return nil }
    guard let turns = nonnegativeCount(v?["turns"]),
          let steps = nonnegativeCount(v?["steps"]),
          let llmMs = nonnegativeNumber(v?["llmMs"]),
          let toolMs = nonnegativeNumber(v?["toolMs"]),
          let ttftMs = nonnegativeNumber(v?["ttftMs"]),
          let ttftSteps = nonnegativeCount(v?["ttftSteps"]),
          let decodeMs = nonnegativeNumber(v?["decodeMs"]),
          let decodeTokens = nonnegativeCount(v?["decodeTokens"]) else { return nil }
    return ComposerActivity(
        turns: turns, steps: steps, llmMs: llmMs, toolMs: toolMs,
        ttftMs: ttftMs, ttftSteps: ttftSteps, decodeMs: decodeMs, decodeTokens: decodeTokens
    )
}

private func parseTokens(_ v: JSONValue?) -> ComposerTokenUsage? {
    guard v?.obj() != nil else { return nil }
    guard let uncached = nonnegativeCount(v?["uncachedInputTokens"]),
          let read = nonnegativeCount(v?["cacheReadTokens"]),
          let write = nonnegativeCount(v?["cacheWriteTokens"]),
          let output = nonnegativeCount(v?["outputTokens"]) else { return nil }
    return ComposerTokenUsage(
        uncachedInputTokens: uncached,
        cacheReadTokens: read,
        cacheWriteTokens: write,
        outputTokens: output
    )
}

private func parseContext(_ v: JSONValue?) -> ComposerContext? {
    guard let used = nonnegativeNumber(v?["projectedTokens"] ?? v?["pressureTokens"]),
          let capacity = nonnegativeNumber(v?["contextWindow"]), capacity > 0 else { return nil }
    return ComposerContext(usedTokens: used, contextWindow: capacity)
}

private func parseBreakdown(_ v: JSONValue?) -> ComposerContextBreakdown? {
    guard let system = nonnegativeNumber(v?["systemTokens"]),
          let tools = nonnegativeNumber(v?["toolsTokens"]),
          let message = nonnegativeNumber(v?["messageTokens"]) else { return nil }
    return ComposerContextBreakdown(systemTokens: system, toolsTokens: tools, messageTokens: message)
}

/// Official deriveStats fallback: only the loaded window, never advertised as a durable session total.
private func windowActivity(_ steps: [StepRecord], _ toolTimings: [ToolCallTiming]) -> ComposerActivity? {
    if steps.isEmpty && toolTimings.isEmpty { return nil }
    var turns = Set<Int>()
    var llmMs = 0.0
    var ttftMs = 0.0
    var ttftSteps: Int64 = 0
    var decodeMs = 0.0
    var decodeTokens: Int64 = 0
    for step in steps {
        turns.insert(step.turn)
        let start = step.stepStartTime
        let first = step.firstTokenTime
        let end = step.messageTime
        if let start, let end { llmMs += Double(max(end - start, 0)) }
        if let start, let first {
            ttftMs += Double(max(first - start, 0))
            ttftSteps += 1
        }
        if let first, let end, let output = step.usage.outputTokens, output >= 0 {
            decodeMs += Double(max(end - first, 0))
            decodeTokens += output
        }
    }
    var toolMs = 0.0
    for timing in toolTimings {
        if let start = timing.callStartedAt, let end = timing.resultAt {
            toolMs += Double(max(end - start, 0))
        }
    }
    return ComposerActivity(
        turns: Int64(turns.count),
        steps: Int64(steps.count),
        llmMs: llmMs,
        toolMs: toolMs,
        ttftMs: ttftMs,
        ttftSteps: ttftSteps,
        decodeMs: decodeMs,
        decodeTokens: decodeTokens
    )
}

private extension Decimal {
    func rounded(_ places: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, places, .plain)
        return result
    }

    func stripTrailingZeros() -> String {
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 16,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let number = NSDecimalNumber(decimal: self).rounding(accordingToBehavior: handler)
        var text = number.stringValue
        if text.contains(".") {
            while text.last == "0" { text.removeLast() }
            if text.last == "." { text.removeLast() }
        }
        return text
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
