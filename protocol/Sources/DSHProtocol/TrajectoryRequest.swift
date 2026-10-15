import Foundation

/// Desktop `TrajectoryRequestNumber` — one session-global numbered request
/// (assistant step or compaction) for the Request inspector.
public struct TrajectoryRequest: Sendable, Equatable, Identifiable {
    public var id: String { identity }
    public enum Purpose: Sendable, Equatable {
        case assistant, compaction
    }

    public var number: Int
    public var identity: String
    public var purpose: Purpose
    public var turn: Int?
    public var step: Int?
    public var group: String
    public var status: TrajectoryRecordState
    public var startedAt: Int64?
    public var completedAt: Int64?
    public var provider: String?
    public var model: String?
    public var requestConfigJson: String?
    public var usage: StepUsage?
    public var cumulativeUsage: StepUsage?
    public var toolCallCount: Int
    public var subtoolCallCount: Int
    public var error: String?
    public var errorCode: String?
    public var retry: Int?
    public var maxRetries: Int?
    public var retryDelayMs: Int64?
    /// Ledger row key for the result (assistant / compacted).
    public var resultKey: String?

    public init(
        number: Int,
        identity: String,
        purpose: Purpose,
        turn: Int?,
        step: Int?,
        group: String,
        status: TrajectoryRecordState,
        startedAt: Int64? = nil,
        completedAt: Int64? = nil,
        provider: String? = nil,
        model: String? = nil,
        requestConfigJson: String? = nil,
        usage: StepUsage? = nil,
        cumulativeUsage: StepUsage? = nil,
        toolCallCount: Int = 0,
        subtoolCallCount: Int = 0,
        error: String? = nil,
        errorCode: String? = nil,
        retry: Int? = nil,
        maxRetries: Int? = nil,
        retryDelayMs: Int64? = nil,
        resultKey: String? = nil
    ) {
        self.number = number
        self.identity = identity
        self.purpose = purpose
        self.turn = turn
        self.step = step
        self.group = group
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.provider = provider
        self.model = model
        self.requestConfigJson = requestConfigJson
        self.usage = usage
        self.cumulativeUsage = cumulativeUsage
        self.toolCallCount = toolCallCount
        self.subtoolCallCount = subtoolCallCount
        self.error = error
        self.errorCode = errorCode
        self.retry = retry
        self.maxRetries = maxRetries
        self.retryDelayMs = retryDelayMs
        self.resultKey = resultKey
    }
}

/// Desktop REQUEST_TABS: 概述 / 选项 / 用量 / 计时.
public enum TrajRequestTab: String, Sendable, Equatable, Hashable, CaseIterable {
    case overview, options, usage, timing

    public var label: String {
        switch self {
        case .overview: return TrajL.tabSummary
        case .options: return TrajL.tabOptions
        case .usage: return TrajL.tabUsage
        case .timing: return TrajL.tabTiming
        }
    }
}

public func trajRequestTabs(_ request: TrajectoryRequest) -> [TrajRequestTab] {
    var tabs: [TrajRequestTab] = [.overview]
    if request.requestConfigJson != nil { tabs.append(.options) }
    tabs.append(.usage)
    tabs.append(.timing)
    return tabs
}

/// Build session-global numbered requests from settled steps + compaction items
/// (desktop TrajectoryView `requestNumbers` memo).
public func buildTrajectoryRequests(items: [Item], steps: [StepRecord]) -> [TrajectoryRequest] {
    struct Entry {
        var seq: Int64
        var build: (Int, StepUsage?) -> TrajectoryRequest
    }
    var entries: [Entry] = []

    for step in steps {
        let tools = items.compactMap { item -> Item.Tool? in
            if case .tool(let tool) = item, tool.turn == step.turn, tool.step == step.step { return tool }
            return nil
        }
        let toolCount = tools.filter { $0.parentCallId == nil }.count
        let subCount = tools.filter { $0.parentCallId != nil }.count
        let status: TrajectoryRecordState = step.interrupted ? .error : .complete
        entries.append(Entry(seq: step.seq) { number, cumulative in
            TrajectoryRequest(
                number: number,
                identity: "assistant:\(step.turn):\(step.step):\(step.seq)",
                purpose: .assistant,
                turn: step.turn,
                step: step.step,
                group: TrajL.groupStep(step.step),
                status: status,
                startedAt: step.stepStartTime,
                completedAt: step.messageTime,
                provider: step.provider,
                model: step.model,
                requestConfigJson: step.requestConfigJson,
                usage: step.usage,
                cumulativeUsage: cumulative,
                toolCallCount: toolCount,
                subtoolCallCount: subCount,
                error: (step.interrupted || step.retry != nil) ? step.lastAttemptError : nil,
                retry: step.retry,
                maxRetries: step.maxRetries,
                retryDelayMs: step.retryDelayMs,
                resultKey: "a\(step.seq)"
            )
        })
    }

    for item in items {
        guard case .compacted(let compacted) = item else { continue }
        let status: TrajectoryRecordState
        switch compacted.status {
        case .running: status = .running
        case .error: status = .error
        case .ok: status = .complete
        }
        let seq: Int64
        if compacted.key.hasPrefix("cmp"), let parsed = Int64(compacted.key.dropFirst(3)) {
            seq = parsed
        } else {
            seq = Int64(compacted.compactionId.hashValue)
        }
        entries.append(Entry(seq: seq) { number, cumulative in
            TrajectoryRequest(
                number: number,
                identity: "compaction:\(compacted.compactionId)",
                purpose: .compaction,
                turn: compacted.turn,
                step: nil,
                group: TrajL.groupCompaction(seq),
                status: status,
                startedAt: compacted.startedAt,
                completedAt: compacted.endedAt,
                usage: nil,
                cumulativeUsage: cumulative,
                error: compacted.error,
                errorCode: compacted.interrupted ? "interrupted" : nil,
                resultKey: compacted.key
            )
        })
    }

    entries.sort { $0.seq < $1.seq }
    var cumulative: StepUsage?
    return entries.enumerated().map { index, entry in
        let req = entry.build(index + 1, cumulative)
        if req.purpose == .assistant, req.usage != nil {
            cumulative = addUsage(cumulative, req.usage)
        }
        var stamped = req
        stamped.cumulativeUsage = cumulative
        return stamped
    }
}

/// Desktop `addUsage` for request cumulative token totals.
public func addUsage(_ a: StepUsage?, _ b: StepUsage?) -> StepUsage? {
    if a == nil { return b }
    if b == nil { return a }
    func plus(_ lhs: Int64?, _ rhs: Int64?) -> Int64? {
        if lhs == nil && rhs == nil { return nil }
        return (lhs ?? 0) + (rhs ?? 0)
    }
    return StepUsage(
        inputTokens: plus(a?.inputTokens, b?.inputTokens),
        cacheReadTokens: plus(a?.cacheReadTokens, b?.cacheReadTokens),
        cacheWriteTokens: plus(a?.cacheWriteTokens, b?.cacheWriteTokens),
        outputTokens: plus(a?.outputTokens, b?.outputTokens),
        reasoningTokens: plus(a?.reasoningTokens, b?.reasoningTokens)
    )
}

/// Map a ledger row to its owning request (assistant step or compaction).
public func requestForRow(_ row: TrajRow, requests: [TrajectoryRequest]) -> TrajectoryRequest? {
    if let match = requests.first(where: { $0.resultKey == row.key }) { return match }
    if row.kind == TrajL.kindTool || row.kind == TrajL.kindSubtool {
        if let turn = row.turn, let step = row.step {
            return requests.first {
                $0.purpose == .assistant && $0.turn == turn && $0.step == step
            }
        }
    }
    if row.kind == TrajL.kindAssistant, let turn = row.turn, let step = row.step {
        return requests.first {
            $0.purpose == .assistant && $0.turn == turn && $0.step == step
        }
    }
    return nil
}

/// First ledger row key that should show the Request boundary control for `request`.
public func requestBoundaryRowKey(_ request: TrajectoryRequest, turns: [TrajTurn]) -> String? {
    if let key = request.resultKey, turns.contains(where: { $0.rows.contains(where: { $0.key == key }) }) {
        return key
    }
    if request.purpose == .assistant {
        guard let turn = request.turn, let step = request.step else { return nil }
        let rows = turns.first(where: { $0.index == turn })?.rows ?? []
        return rows.first(where: { $0.kind == TrajL.kindAssistant && $0.step == step })?.key
            ?? rows.first(where: {
                ($0.kind == TrajL.kindTool || $0.kind == TrajL.kindSubtool) && $0.step == step
            })?.key
    }
    return nil
}

public func requestLabel(_ request: TrajectoryRequest) -> String {
    switch request.purpose {
    case .compaction: return TrajL.requestLabelCompaction(request.number)
    case .assistant: return TrajL.requestLabel(request.number)
    }
}
