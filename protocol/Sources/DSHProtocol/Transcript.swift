import Foundation

public struct ImageRef: Sendable, Equatable {
    public var attachmentId: String
    public var mediaType: String?
}

public struct DeliverableFile: Sendable, Equatable {
    public var path: String
    public var description: String?
}

public struct QueuedPrompt: Sendable, Equatable, Identifiable {
    public var id: String
    public var text: String
    public var images: Int
    public var files: Int
    public var sending: Bool
    public var editable: Bool

    public init(id: String, text: String, images: Int = 0, files: Int = 0, sending: Bool = false) {
        self.id = id
        self.text = text
        self.images = images
        self.files = files
        self.sending = sending
        self.editable = images == 0 && files == 0
    }
}

public enum QueueAction: Sendable {
    case edit(String)
    case remove
    case steer
}

public enum ToolStatus: String, Sendable {
    case preparing, running, awaitingApproval, ok, error
}

public enum CompactionStatus: String, Sendable {
    case running, ok, error
}

public struct TodoItem: Sendable, Equatable, Identifiable {
    public var content: String
    public var status: String
    public var id: String { content }
}

public enum RetryState: String, Sendable, Equatable {
    case scheduled, started, cancelled
}

public struct RetryAttempt: Sendable, Equatable {
    public var seq: Int64
    public var retry: Int
    public var maxRetries: Int?
    public var mode: String
    public var delayMs: Int64
    public var message: String
    public var code: String?
    public var state: RetryState

    public init(
        seq: Int64,
        retry: Int,
        maxRetries: Int? = nil,
        mode: String,
        delayMs: Int64,
        message: String,
        code: String? = nil,
        state: RetryState = .scheduled
    ) {
        self.seq = seq
        self.retry = retry
        self.maxRetries = maxRetries
        self.mode = mode
        self.delayMs = delayMs
        self.message = message
        self.code = code
        self.state = state
    }
}

public enum Item: Sendable, Equatable, Identifiable {
    case user(User)
    case reasoning(Reasoning)
    case text(Text)
    case tool(Tool)
    case notice(Notice)
    case deliverable(Deliverable)
    case context(Context)
    case system(System)
    case compacted(Compacted)
    case retry(Retry)
    case turnFailure(TurnFailure)
    case changes(Changes)

    public var id: String { key }
    public var key: String {
        switch self {
        case .user(let v): return v.key
        case .reasoning(let v): return v.key
        case .text(let v): return v.key
        case .tool(let v): return v.key
        case .notice(let v): return v.key
        case .deliverable(let v): return v.key
        case .context(let v): return v.key
        case .system(let v): return v.key
        case .compacted(let v): return v.key
        case .retry(let v): return v.key
        case .turnFailure(let v): return v.key
        case .changes(let v): return v.key
        }
    }

    public struct User: Sendable, Equatable {
        public var key: String
        public var text: String
        public var images: Int
        public var pending: Bool
        public var at: Int64?
        public var seq: Int64?
        public var imageRefs: [ImageRef]
        public var requestId: String?
        public var messageId: String?
        public var messageSourceJson: String?

        public init(
            key: String,
            text: String,
            images: Int = 0,
            pending: Bool = false,
            at: Int64? = nil,
            seq: Int64? = nil,
            imageRefs: [ImageRef] = [],
            requestId: String? = nil,
            messageId: String? = nil,
            messageSourceJson: String? = nil
        ) {
            self.key = key
            self.text = text
            self.images = images
            self.pending = pending
            self.at = at
            self.seq = seq
            self.imageRefs = imageRefs
            self.requestId = requestId
            self.messageId = messageId
            self.messageSourceJson = messageSourceJson
        }
    }

    public struct Reasoning: Sendable, Equatable {
        public var key: String
        public var text: String
        public var durationMs: Int64?
        public var live: Bool
        public var turn: Int?
        public var step: Int?
        public var seq: Int64?

        public init(key: String, text: String, durationMs: Int64? = nil, live: Bool, turn: Int? = nil, step: Int? = nil, seq: Int64? = nil) {
            self.key = key
            self.text = text
            self.durationMs = durationMs
            self.live = live
            self.turn = turn
            self.step = step
            self.seq = seq
        }
    }

    public struct Text: Sendable, Equatable {
        public var key: String
        public var text: String
        public var live: Bool
        public var at: Int64?
        public var seq: Int64?
        public var messageId: String?
        public var turn: Int?
        public var step: Int?

        public init(key: String, text: String, live: Bool, at: Int64? = nil, seq: Int64? = nil, messageId: String? = nil, turn: Int? = nil, step: Int? = nil) {
            self.key = key
            self.text = text
            self.live = live
            self.at = at
            self.seq = seq
            self.messageId = messageId
            self.turn = turn
            self.step = step
        }
    }

    public struct Tool: Sendable, Equatable {
        public var key: String
        public var callId: String
        public var name: String
        public var arguments: String
        public var status: ToolStatus
        public var result: String?
        public var error: String?
        public var startedAt: Int64?
        public var endedAt: Int64?
        public var turn: Int?
        public var step: Int?
        public var parentCallId: String?
        public var schemaJson: String?

        public init(
            key: String,
            callId: String,
            name: String,
            arguments: String,
            status: ToolStatus,
            result: String? = nil,
            error: String? = nil,
            startedAt: Int64? = nil,
            endedAt: Int64? = nil,
            turn: Int? = nil,
            step: Int? = nil,
            parentCallId: String? = nil,
            schemaJson: String? = nil
        ) {
            self.key = key
            self.callId = callId
            self.name = name
            self.arguments = arguments
            self.status = status
            self.result = result
            self.error = error
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.turn = turn
            self.step = step
            self.parentCallId = parentCallId
            self.schemaJson = schemaJson
        }
    }

    public struct Notice: Sendable, Equatable {
        public var key: String
        public var text: String
        public var turn: Int?

        public init(key: String, text: String, turn: Int? = nil) {
            self.key = key
            self.text = text
            self.turn = turn
        }
    }

    public struct Deliverable: Sendable, Equatable {
        public var key: String
        public var files: [DeliverableFile]
        public var turn: Int?

        public init(key: String, files: [DeliverableFile], turn: Int? = nil) {
            self.key = key
            self.files = files
            self.turn = turn
        }
    }

    public struct Context: Sendable, Equatable {
        public var key: String
        public var text: String
        public var sourceKind: String?
        public var at: Int64?
        public var messageSourceJson: String?

        public init(key: String, text: String, sourceKind: String? = nil, at: Int64? = nil, messageSourceJson: String? = nil) {
            self.key = key
            self.text = text
            self.sourceKind = sourceKind
            self.at = at
            self.messageSourceJson = messageSourceJson
        }
    }

    public struct System: Sendable, Equatable {
        public var key: String
        public var label: String
        public var text: String
        public var at: Int64?
        public var previousText: String?
        public var toolsJson: String?
        public var previousToolsJson: String?

        public init(
            key: String,
            label: String,
            text: String,
            at: Int64? = nil,
            previousText: String? = nil,
            toolsJson: String? = nil,
            previousToolsJson: String? = nil
        ) {
            self.key = key
            self.label = label
            self.text = text
            self.at = at
            self.previousText = previousText
            self.toolsJson = toolsJson
            self.previousToolsJson = previousToolsJson
        }
    }

    public struct Compacted: Sendable, Equatable {
        public var key: String
        public var compactionId: String
        public var status: CompactionStatus
        public var summary: String?
        public var error: String?
        public var interrupted: Bool
        public var startedAt: Int64?
        public var endedAt: Int64?
        public var turn: Int?

        public init(
            key: String,
            compactionId: String,
            status: CompactionStatus,
            summary: String? = nil,
            error: String? = nil,
            interrupted: Bool = false,
            startedAt: Int64? = nil,
            endedAt: Int64? = nil,
            turn: Int? = nil
        ) {
            self.key = key
            self.compactionId = compactionId
            self.status = status
            self.summary = summary
            self.error = error
            self.interrupted = interrupted
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.turn = turn
        }
    }

    public struct Retry: Sendable, Equatable {
        public var key: String
        public var retryId: String
        public var turn: Int?
        public var step: Int?
        public var attempts: [RetryAttempt]

        public init(key: String, retryId: String, turn: Int? = nil, step: Int? = nil, attempts: [RetryAttempt]) {
            self.key = key
            self.retryId = retryId
            self.turn = turn
            self.step = step
            self.attempts = attempts
        }

        var identity: RetryIdentity { RetryIdentity(id: retryId, turn: turn, step: step) }
    }

    public struct TurnFailure: Sendable, Equatable {
        public var key: String
        public var message: String
        public var code: String?
        public var turn: Int?

        public init(key: String, message: String, code: String? = nil, turn: Int? = nil) {
            self.key = key
            self.message = message
            self.code = code
            self.turn = turn
        }
    }

    public struct Changes: Sendable, Equatable {
        public var key: String
        public var turn: Int
        public var seq: Int64?

        public init(key: String, turn: Int, seq: Int64? = nil) {
            self.key = key
            self.turn = turn
            self.seq = seq
        }
    }
}

public struct Usage: Sendable, Equatable {
    public var turns: Int
    public var steps: Int
    public var inputTokens: Int64
    public var cacheReadTokens: Int64
    public var outputTokens: Int64
}

public struct StepUsage: Sendable, Equatable {
    public var inputTokens: Int64?
    public var cacheReadTokens: Int64?
    public var cacheWriteTokens: Int64?
    public var outputTokens: Int64?
    public var reasoningTokens: Int64?

    public init(
        inputTokens: Int64? = nil,
        cacheReadTokens: Int64? = nil,
        cacheWriteTokens: Int64? = nil,
        outputTokens: Int64? = nil,
        reasoningTokens: Int64? = nil
    ) {
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
    }
}

public struct StepRecord: Sendable, Equatable {
    public var seq: Int64
    public var turn: Int
    public var step: Int
    public var stepStartTime: Int64?
    public var messageTime: Int64?
    public var firstTokenTime: Int64?
    public var replyText: String
    public var reasoningText: String
    public var usage: StepUsage
    public var provider: String?
    public var model: String?
        public var toolCallIds: [String]
        public var interrupted: Bool
        public var requestConfigJson: String?
        public var retry: Int?
        public var maxRetries: Int?
        public var retryDelayMs: Int64?
        public var lastAttemptError: String?

        public init(
            seq: Int64,
            turn: Int,
            step: Int,
            stepStartTime: Int64? = nil,
            messageTime: Int64? = nil,
            firstTokenTime: Int64? = nil,
            replyText: String = "",
            reasoningText: String = "",
            usage: StepUsage = StepUsage(),
            provider: String? = nil,
            model: String? = nil,
            toolCallIds: [String] = [],
            interrupted: Bool = false,
            requestConfigJson: String? = nil,
            retry: Int? = nil,
            maxRetries: Int? = nil,
            retryDelayMs: Int64? = nil,
            lastAttemptError: String? = nil
        ) {
        self.seq = seq
        self.turn = turn
        self.step = step
        self.stepStartTime = stepStartTime
        self.messageTime = messageTime
        self.firstTokenTime = firstTokenTime
        self.replyText = replyText
        self.reasoningText = reasoningText
        self.usage = usage
        self.provider = provider
        self.model = model
        self.toolCallIds = toolCallIds
        self.interrupted = interrupted
        self.requestConfigJson = requestConfigJson
        self.retry = retry
        self.maxRetries = maxRetries
        self.retryDelayMs = retryDelayMs
        self.lastAttemptError = lastAttemptError
    }
}

public struct TurnRecord: Sendable, Equatable {
    public var turn: Int
    public var startSeq: Int64?
    public var endSeq: Int64?
    public var startedAt: Int64?
    public var endedAt: Int64?
    public var endReason: String?
    public var closed: Bool { endSeq != nil }
    /// Host turn start/end only. Abort/error never invent an elapsed time.
    public var durationMs: Int64? {
        if !closed || endReason == "aborted" || endReason == "error" { return nil }
        guard let start = startedAt, let end = endedAt else { return nil }
        return max(end - start, 1000)
    }

    public init(
        turn: Int,
        startSeq: Int64? = nil,
        endSeq: Int64? = nil,
        startedAt: Int64? = nil,
        endedAt: Int64? = nil,
        endReason: String? = nil
    ) {
        self.turn = turn
        self.startSeq = startSeq
        self.endSeq = endSeq
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.endReason = endReason
    }
}

/// Folds dsh SessionFollowFrames into chat items. Pure and deterministic.
public final class TranscriptReducer {
    private struct LocalEcho {
        var prompt: QueuedPrompt
        var queued: Bool
    }

    private var committed: [Item] = []
    private var toolIndex: [String: Int] = [:]
    private var approvalCall: [String: String] = [:]
    private var userByRpc: [String: Int] = [:]
    private var userByMessage: [String: Int] = [:]
    private var localEchoes: [String: LocalEcho] = [:]
    private var retiredMessages = Set<String>()
    private var retiredRequests = Set<String>()
    private var inbox: [String: [JSONValue]] = ["next-turn": [], "next-step": []]
    private var inboxSeq: Int64 = -1
    private var live: LiveAttempt?
    private var assistantRevision: Int64 = 0
    private var streamSuppressed = false
    private var retiredAttempts = Set<String>()
    private var settlementSeqs: [String: Int64] = [:]
    private var turnFacts: [Int: TurnRecord] = [:]
    private var todos: [TodoItem] = []
    private var planActive = false
    private var planProjectionSeq: Int64 = -1
    private var titleValue: String?
    private var turns = 0
    private var steps = 0
    private var openTurn: Int?
    private var openStep: Int?
    private var inputTokens: Int64 = 0
    private var cacheRead: Int64 = 0
    private var outputTokens: Int64 = 0
    private var settledSteps: [StepRecord] = []
    private var stepStartTimes: [String: Int64] = [:]
    private var compactIndex: [String: Int] = [:]
    private var systemPromptSeen = false
    private var lastSystemPromptText: String?
    private var retryIndex: [RetryIdentity: Int] = [:]
    private var retryStarts: [RetryIdentity: [Int: Int64]] = [:]
    private var closedSteps: [StepIdentity: Int64] = [:]
    private var openRetry: Int?
    private var openMaxRetries: Int?
    private var openRetryDelayMs: Int64?
    private var openLastAttemptError: String?
    private var toolTimings: [String: ToolCallTiming] = [:]
    private let turnUsageLedger = TurnUsageLedger()
    private let composerProjections = ComposerProjectionStore()

    public private(set) var needsResync = false
    public private(set) var cursor: Int64 = -1
    public private(set) var firstSeq: Int64 = -1
    public private(set) var hasMore = false
    public private(set) var running = false

    public init() {}

    public var title: String? { titleValue }
    public var usage: Usage { Usage(turns: turns, steps: steps, inputTokens: inputTokens, cacheReadTokens: cacheRead, outputTokens: outputTokens) }
    public var planMode: Bool { planActive }
    public var composerMetrics: ComposerMetrics { composerProjections.metrics(steps: settledSteps, toolTimings: Array(toolTimings.values)) }
    public func todosSnapshot() -> [TodoItem] { todos }
    public func turnRecords() -> [TurnRecord] { turnFacts.values.sorted { $0.turn < $1.turn } }
    public func stepRecords() -> [StepRecord] { settledSteps }
    public func turnTokenUsage() -> [Int: TurnTokenUsage] { turnUsageLedger.snapshot() }
    public func clearComposerProjections() { composerProjections.clear() }

    public func items() -> [Item] {
        var result: [Item] = []
        for item in committed {
            if case .tool(let tool) = item, tool.status == .preparing,
               streamSuppressed || turnFacts[tool.turn ?? -1]?.closed == true || (openTurn != nil && tool.turn != openTurn) {
                continue
            }
            result.append(item)
        }
        if let live, live.settlementSeq == nil {
            for item in live.items() {
                if case .tool(let tool) = item, toolIndex[tool.callId] != nil { continue }
                result.append(item)
            }
        }
        return result
    }

    public func queueMessages() -> [QueuedPrompt] {
        let host = (inbox["next-turn"] ?? []).compactMap { message -> QueuedPrompt? in
            let rpc = message["source"]["rpcId"].str()
            if isRetired(message) { return nil }
            if let rpc, localEchoes[rpc]?.queued == false { return nil }
            return queuedPrompt(message)
        }
        let admitted = Set((inbox.values.flatMap { $0 }).compactMap { $0["source"]["rpcId"].str() })
        let local = localEchoes.values.compactMap { echo -> QueuedPrompt? in
            echo.queued && !admitted.contains(echo.prompt.id) ? echo.prompt : nil
        }
        return host + local
    }

    @discardableResult
    public func apply(_ frame: JSONValue) -> Bool {
        let type = frame["type"].str()
        if needsResync && type != "snapshot" && type != "resume" { return false }
        switch type {
        case "snapshot":
            let keep = localEchoes
            reset()
            localEchoes = keep
            records(frame["records"])
            for (id, echo) in localEchoes {
                if retiredRequests.contains(id) {
                    localEchoes.removeValue(forKey: id)
                } else if let idx = userByRpc[id], case .user(let user) = committed[idx], !user.pending {
                    localEchoes.removeValue(forKey: id)
                } else if !echo.queued {
                    addEcho(echo.prompt)
                }
            }
            readProjections(frame["projections"], atSeq: frame["cursor"].long() ?? cursor)
            cursor = frame["cursor"].long() ?? cursor
            hasMore = frame["hasMore"].bool() ?? false
            firstSeq = minSeq(frame["records"])
            baseline(frame["assistantStream"])
        case "resume":
            records(frame["records"])
            readProjections(frame["projections"], atSeq: frame["cursor"].long() ?? cursor)
            cursor = max(cursor, frame["cursor"].long() ?? cursor)
            baseline(frame["assistantStream"])
        case "event":
            return event(frame["event"])
        case "projection":
            let key = frame["key"].str() ?? ""
            let seq = frame["seq"].long() ?? -1
            if key == "plan" {
                if seq < planProjectionSeq { return false }
                planProjectionSeq = seq
                planActive = frame["value"]["active"].bool() ?? false
                return true
            }
            if key == "inbox" { return readInbox(frame["value"], seq: seq) }
            return composerProjections.apply(key: key, value: frame["value"], seq: seq)
        case "assistant-stream":
            return stream(frame["frame"])
        default:
            return false
        }
        return true
    }

    @discardableResult
    public func prepend(records page: JSONValue, pageHasMore: Bool) -> Bool {
        let filtered = (page.arr() ?? []).filter { row in
            guard let seq = row["event"]["seq"].long() else { return false }
            return firstSeq < 0 || seq < firstSeq
        }
        hasMore = pageHasMore
        if filtered.isEmpty { return false }
        let prior = TranscriptReducer()
        let maxSeq = filtered.compactMap { $0["event"]["seq"].long() }.max() ?? 0
        let snapshot: JSONValue = .object([
            "type": .string("snapshot"),
            "cursor": .number(Double(maxSeq)),
            "hasMore": .bool(false),
            "records": .array(filtered),
            "projections": .object([String: JSONValue]()),
        ])
        _ = prior.apply(snapshot)
        let olderTurnUsage = turnUsageLedger.prepend(prior.turnUsageLedger)
        for (turn, earlier) in prior.turnFacts {
            turnFacts[turn] = turnFacts[turn].map { later in
                TurnRecord(
                    turn: turn,
                    startSeq: later.startSeq ?? earlier.startSeq,
                    endSeq: later.endSeq ?? earlier.endSeq,
                    startedAt: later.startedAt ?? earlier.startedAt,
                    endedAt: later.endedAt ?? earlier.endedAt,
                    endReason: later.endReason ?? earlier.endReason
                )
            } ?? earlier
        }
        for (id, earlier) in prior.toolTimings {
            if let later = toolTimings[id] {
                later.callStartedAt = later.callStartedAt ?? earlier.callStartedAt
                later.resultAt = earlier.resultAt ?? later.resultAt
            } else {
                toolTimings[id] = earlier
            }
        }
        for (identity, starts) in prior.retryStarts {
            var known = retryStarts[identity] ?? [:]
            for (retry, seq) in starts {
                known[retry] = max(known[retry] ?? -1, seq)
            }
            retryStarts[identity] = known
        }
        for (step, seq) in prior.closedSteps {
            closedSteps[step] = max(closedSteps[step] ?? -1, seq)
        }
        var mergedRetries = Set<RetryIdentity>()
        let older = prior.items().map { item -> Item in
            guard case .retry(let retry) = item else { return item }
            let identity = retry.identity
            guard let laterIndex = retryIndex[identity], case .retry(let later) = committed[laterIndex] else { return item }
            mergedRetries.insert(identity)
            var attempts = retry.attempts + later.attempts
            var seen = Set<Int64>()
            attempts = attempts.filter { seen.insert($0.seq).inserted }.sorted { $0.seq < $1.seq }
            return .retry(Item.Retry(key: retry.key, retryId: retry.retryId, turn: retry.turn, step: retry.step, attempts: attempts))
        }
        let olderSteps = prior.stepRecords()
        if !older.isEmpty {
            committed.removeAll { item in
                if case .retry(let retry) = item { return mergedRetries.contains(retry.identity) }
                return false
            }
            committed.insert(contentsOf: older, at: 0)
            rebuildIndexes()
        }
        refreshRetries()
        if !olderSteps.isEmpty {
            settledSteps.insert(contentsOf: olderSteps, at: 0)
        }
        if let min = filtered.compactMap({ $0["event"]["seq"].long() }).min() {
            firstSeq = firstSeq < 0 ? min : Swift.min(firstSeq, min)
        }
        return !older.isEmpty || !olderSteps.isEmpty || !prior.toolTimings.isEmpty || !prior.turnFacts.isEmpty
            || olderTurnUsage || !prior.retryStarts.isEmpty || !prior.closedSteps.isEmpty
    }

    public func echo(text: String, requestId: String = UUID().uuidString, mode: String = "queue", images: Int = 0, files: Int = 0) {
        if localEchoes[requestId] != nil || userByRpc[requestId] != nil || retiredRequests.contains(requestId) { return }
        let prompt = QueuedPrompt(id: requestId, text: text, images: images, files: files, sending: true)
        let queued = running && mode == "queue"
        localEchoes[requestId] = LocalEcho(prompt: prompt, queued: queued)
        if !queued { addEcho(prompt) }
    }

    public func discardEcho(_ requestId: String) {
        guard localEchoes.removeValue(forKey: requestId) != nil else { return }
        if let index = userByRpc[requestId], case .user(let user) = committed[index], user.pending {
            committed.remove(at: index)
            rebuildIndexes()
        }
    }

    public func setRunning(_ running: Bool) {
        self.running = running
        streamSuppressed = !running
        if !running {
            if let live { retiredAttempts.insert(live.id) }
            live = nil
        }
    }

    private func reset() {
        committed.removeAll()
        toolIndex.removeAll()
        approvalCall.removeAll()
        userByRpc.removeAll()
        userByMessage.removeAll()
        localEchoes.removeAll()
        retiredMessages.removeAll()
        retiredRequests.removeAll()
        inbox = ["next-turn": [], "next-step": []]
        inboxSeq = -1
        live = nil
        assistantRevision = 0
        streamSuppressed = false
        needsResync = false
        retiredAttempts.removeAll()
        settlementSeqs.removeAll()
        turnFacts.removeAll()
        cursor = -1
        firstSeq = -1
        hasMore = false
        turns = 0
        steps = 0
        openTurn = nil
        openStep = nil
        inputTokens = 0
        cacheRead = 0
        outputTokens = 0
        running = false
        todos = []
        planActive = false
        planProjectionSeq = -1
        titleValue = nil
        settledSteps.removeAll()
        stepStartTimes.removeAll()
        compactIndex.removeAll()
        systemPromptSeen = false
        lastSystemPromptText = nil
        retryIndex.removeAll()
        retryStarts.removeAll()
        closedSteps.removeAll()
        openRetry = nil
        openMaxRetries = nil
        openRetryDelayMs = nil
        openLastAttemptError = nil
        toolTimings.removeAll()
        turnUsageLedger.clear()
    }

    private func rebuildIndexes() {
        toolIndex.removeAll()
        userByRpc.removeAll()
        userByMessage.removeAll()
        compactIndex.removeAll()
        for (index, item) in committed.enumerated() {
            switch item {
            case .tool(let tool):
                if !tool.callId.isEmpty { toolIndex[tool.callId] = index }
            case .user(let user):
                if let rpc = user.requestId { userByRpc[rpc] = index }
                if let messageId = user.messageId { userByMessage[messageId] = index }
            case .compacted(let compacted):
                compactIndex[compacted.compactionId] = index
            case .retry(let retry):
                retryIndex[retry.identity] = index
            default:
                break
            }
        }
    }

    private func minSeq(_ arr: JSONValue) -> Int64 {
        (arr.arr() ?? []).compactMap { $0["event"]["seq"].long() }.min() ?? -1
    }

    private func records(_ arr: JSONValue) {
        for row in arr.arr() ?? [] where row["type"].str() == "event" {
            _ = event(row["event"])
        }
    }

    private func readProjections(_ p: JSONValue, atSeq: Int64) {
        composerProjections.baseline(p, fallbackSeq: atSeq)
        if let title = p["values"]["title"].str() { titleValue = title }
        if !p["values"]["inbox"].isNull {
            _ = readInbox(p["values"]["inbox"], seq: p["asOfSeq"].long() ?? atSeq, baseline: true)
        }
        let usage = p["values"]["tokenUsage"]
        if usage.obj() != nil {
            let uncached = usage["uncachedInputTokens"].long() ?? 0
            let cr = usage["cacheReadTokens"].long() ?? 0
            cacheRead = cr
            inputTokens = uncached + cr + (usage["cacheWriteTokens"].long() ?? 0)
            outputTokens = usage["outputTokens"].long() ?? 0
        }
        if let arr = p["values"]["todos"].arr() {
            todos = arr.compactMap { row in
                let content = row["content"].str()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard let status = row["status"].str(), !content.isEmpty else { return nil }
                return TodoItem(content: content, status: status)
            }
        }
        if !p["values"]["plan"].isNull {
            let seq = p["asOfSeq"].long() ?? atSeq
            if seq >= planProjectionSeq {
                planProjectionSeq = seq
                planActive = p["values"]["plan"]["active"].bool() ?? false
            }
        }
    }

    private func baseline(_ b: JSONValue) {
        live = nil
        retiredAttempts.removeAll()
        assistantRevision = b["revision"].long() ?? 0
        needsResync = false
        streamSuppressed = false
        let a = b["activeAttempt"]
        guard a.obj() != nil else { return }
        guard let id = a["attemptId"].str(),
              let turn = a["turn"].int(),
              let step = a["step"].int(),
              let afterSeq = a["startedAfterSeq"].long(),
              let nextIndex = a["nextIndex"].long(), nextIndex >= 0 else {
            continuityFault()
            return
        }
        if turnFacts[turn]?.closed == true || (settlementSeqs["\(turn):\(step)"] ?? -1) > afterSeq {
            retiredAttempts.insert(id)
            return
        }
        let attempt = LiveAttempt(id: id, turn: turn, step: step, startedAfterSeq: afterSeq, nextIndex: nextIndex)
        var remaining = nextIndex
        for rec in a["stream"].arr() ?? [] {
            if remaining == 0 { break }
            remaining -= Int64(attempt.record(rec, remaining: remaining))
        }
        live = attempt
        openTurn = turn
        openStep = step
        if turnFacts[turn] == nil { turnFacts[turn] = TurnRecord(turn: turn) }
    }

    @discardableResult
    private func event(_ e: JSONValue) -> Bool {
        if e.isNull || e["ignorable"].bool() == true { return false }
        guard let seq = e["seq"].long(), seq > cursor else { return false }
        cursor = seq
        turnUsageLedger.apply(e)
        let data = e["data"]
        switch e["type"].str() {
        case "turn/start":
            turns += 1
            setRunning(true)
            openTurn = data["turn"].int()
            if let live, live.turn != openTurn {
                retiredAttempts.insert(live.id)
                self.live = nil
            }
            openStep = nil
            if let turn = openTurn {
                var fact = turnFacts[turn] ?? TurnRecord(turn: turn)
                fact.startSeq = seq
                fact.startedAt = e["time"].long()
                turnFacts[turn] = fact
            }
        case "turn/end":
            let reason = data["reason"]
            let turn = data["turn"].int() ?? openTurn
            let currentTurn = openTurn ?? live?.turn
            let endsCurrent = currentTurn == nil || turn == nil || currentTurn == turn
            if endsCurrent { setRunning(false) }
            if let turn {
                var fact = turnFacts[turn] ?? TurnRecord(turn: turn)
                fact.endSeq = seq
                fact.endedAt = e["time"].long()
                fact.endReason = reason["kind"].str()
                turnFacts[turn] = fact
            }
            refreshRetries()
            if endsCurrent {
                openTurn = nil
                openStep = nil
            }
            switch reason["kind"].str() {
            case "error":
                committed.append(.turnFailure(Item.TurnFailure(
                    key: "te\(seq)",
                    message: reason["error"]["message"].str() ?? "",
                    code: reason["error"]["code"].str(),
                    turn: turn
                )))
            case "aborted":
                let hook = reason["reason"]
                if hook["kind"].str() == "hook", hook["reason"].str() == "deepseek-account/signed-out" {
                    committed.append(.notice(Item.Notice(key: "te\(seq)", text: "任务已因退出 DeepSeek 登录而停止。", turn: turn)))
                }
            case "max-tokens", "max_tokens":
                committed.append(.notice(Item.Notice(key: "mt\(seq)", text: "已达到输出 token 上限", turn: turn)))
                committed.append(.notice(Item.Notice(key: "mth\(seq)", text: "回答被截断，已有输出保留在对话中。发送“继续”可让模型接着输出。", turn: turn)))
            default:
                break
            }
        case "todo/write":
            todos = (data["todos"].arr() ?? []).compactMap { row in
                let content = row["content"].str()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard let status = row["status"].str(), !content.isEmpty else { return nil }
                return TodoItem(content: content, status: status)
            }
        case "plan/mode":
            if seq >= planProjectionSeq {
                planProjectionSeq = seq
                planActive = data["active"].bool() ?? planActive
            }
        case "step/start":
            openTurn = data["turn"].int() ?? openTurn
            openStep = data["step"].int() ?? (steps + 1)
            openRetry = nil
            openMaxRetries = nil
            openRetryDelayMs = nil
            openLastAttemptError = nil
            if let turn = openTurn, let step = openStep, let time = e["time"].long() {
                stepStartTimes["\(turn):\(step)"] = time
            }
            if let turn = openTurn, turnFacts[turn] == nil { turnFacts[turn] = TurnRecord(turn: turn) }
        case "step/end":
            if let turn = data["turn"].int() ?? openTurn, let step = data["step"].int() ?? openStep {
                closedSteps[StepIdentity(turn: turn, step: step)] = seq
            }
            refreshRetries()
        case "llm/retry":
            openRetry = data["retry"].int() ?? ((openRetry ?? 0) + 1)
            openMaxRetries = data["maxRetries"].int() ?? data["maximum"].int() ?? openMaxRetries
            openRetryDelayMs = data["delayMs"].long() ?? data["retryDelayMs"].long() ?? openRetryDelayMs
            openLastAttemptError = data["failure"]["message"].str()
                ?? data["error"]["message"].str()
                ?? data["error"]["reason"].str()
                ?? data["error"].str()
                ?? openLastAttemptError
            scheduleRetry(data, seq: seq)
        case "llm/retry-started":
            if let identity = retryIdentity(data), let retry = data["retry"].int() {
                var starts = retryStarts[identity] ?? [:]
                starts[retry] = seq
                retryStarts[identity] = starts
                if let index = retryIndex[identity], case .retry(let item) = committed[index] {
                    committed[index] = .retry(projectRetry(item))
                }
            }
        case "user/message":
            let msg = data["content"].isNull ? data["message"] : data
            retireMessage(msg)
            if isTyped(msg) {
                upsertUser(msg, key: "u\(seq)", pending: false, at: e["time"].long(), seq: seq)
            } else {
                upsertContext(msg, key: "x\(seq)", at: e["time"].long())
            }
        case "developer/message":
            upsertContext(data["message"].isNull ? data : data["message"], key: "d\(seq)", at: e["time"].long())
        case "assistant/message":
            steps += 1
            let matching = matchingAttempt(e)
            let ownerTurn = data["turn"].int() ?? openTurn
            let turn = ownerTurn ?? turns
            let step = data["step"].int() ?? openStep ?? steps
            settleAttempt(e)
            let messageTime = e["time"].long()
            if let ownerTurn, turnFacts[ownerTurn] == nil { turnFacts[ownerTurn] = TurnRecord(turn: ownerTurn) }
            let firstTokenTime = matching?.firstTokenTime ?? assistantStreamFirstTokenTime(data["stream"])
            let messageId = data["message"]["id"].str()
            var replyParts: [String] = []
            var reasoningParts: [String] = []
            var toolCallIds: [String] = []
            for (i, block) in (data["message"]["content"].arr() ?? []).enumerated() {
                switch block["type"].str() {
                case "reasoning":
                    let text = block["text"].str() ?? ""
                    reasoningParts.append(text)
                    committed.append(.reasoning(Item.Reasoning(
                        key: "r\(seq).\(i)",
                        text: text,
                        durationMs: nil,
                        live: false,
                        turn: ownerTurn,
                        step: step,
                        seq: seq
                    )))
                case "text":
                    if let text = block["text"].str(), !text.isEmpty {
                        replyParts.append(text)
                        committed.append(.text(Item.Text(
                            key: "t\(seq).\(i)",
                            text: text,
                            live: false,
                            at: messageTime,
                            seq: seq,
                            messageId: messageId,
                            turn: ownerTurn,
                            step: step
                        )))
                    }
                case "tool-call":
                    let id = block["id"].str() ?? "c\(seq).\(i)"
                    toolCallIds.append(id)
                    upsertTool(
                        id: id,
                        name: block["name"].str() ?? "",
                        args: block["arguments"].str() ?? "",
                        time: e["time"].long(),
                        turn: ownerTurn,
                        step: step,
                        status: matching != nil ? .preparing : .running
                    )
                default:
                    break
                }
            }
            let u = data["usage"]
            let stepUsage = StepUsage(
                inputTokens: u["inputTokens"].long(),
                cacheReadTokens: u["cacheReadTokens"].long(),
                cacheWriteTokens: u["cacheWriteTokens"].long(),
                outputTokens: u["outputTokens"].long(),
                reasoningTokens: u["reasoningTokens"].long()
            )
            outputTokens += u["outputTokens"].long() ?? 0
            inputTokens += (u["inputTokens"].long() ?? 0) + (u["cacheReadTokens"].long() ?? 0) + (u["cacheWriteTokens"].long() ?? 0)
            cacheRead += u["cacheReadTokens"].long() ?? 0
            let source = data["message"]["source"]
            let interrupted = data["interrupted"].bool() == true
            let stepStartTime = stepStartTimes.removeValue(forKey: "\(turn):\(step)")
            settledSteps.append(StepRecord(
                seq: seq,
                turn: turn,
                step: step,
                stepStartTime: stepStartTime,
                messageTime: messageTime,
                firstTokenTime: firstTokenTime,
                replyText: replyParts.joined(separator: "\n\n"),
                reasoningText: reasoningParts.joined(separator: "\n\n"),
                usage: stepUsage,
                provider: source["provider"].str(),
                model: source["model"].str(),
                toolCallIds: toolCallIds,
                interrupted: interrupted,
                retry: openRetry,
                maxRetries: openMaxRetries,
                retryDelayMs: openRetryDelayMs,
                lastAttemptError: openLastAttemptError
            ))
            openRetry = nil
            openMaxRetries = nil
            openRetryDelayMs = nil
            openLastAttemptError = nil
            if interrupted {
                committed.append(.notice(Item.Notice(key: "i\(seq)", text: "已停止", turn: ownerTurn)))
            }
        case "system/message":
            upsertSystemPrompt(e, data: data, seq: seq)
        case "compaction/start":
            upsertCompactionStart(data, time: e["time"].long())
        case "compaction/summary":
            upsertCompactionSummary(data)
        case "compaction/end":
            upsertCompactionEnd(data, time: e["time"].long())
        case "assistant/attempt":
            settleAttempt(e)
        case "tool/call":
            let id = data["callId"].str() ?? "c\(seq)"
            let time = e["time"].long()
            let timing = toolTimings[id] ?? ToolCallTiming()
            timing.callStartedAt = time
            toolTimings[id] = timing
            upsertTool(
                id: id,
                name: data["name"].str() ?? "",
                args: data["arguments"].str() ?? "",
                time: time,
                turn: data["turn"].int() ?? openTurn,
                step: data["step"].int() ?? openStep
            )
        case "tool/result":
            let id = data["message"]["toolCallId"].str() ?? data["message"]["source"]["callId"].str()
            guard let id else { return false }
            let text = (data["message"]["content"].arr() ?? [])
                .filter { $0["type"].str() == "text" }
                .map { $0["text"].str() ?? "" }
                .joined(separator: "\n")
            let err = data["error"]
            let isErr = !err.isNull || data["message"]["isError"].bool() == true
            let timing = toolTimings[id] ?? ToolCallTiming()
            timing.resultAt = timing.resultAt ?? e["time"].long()
            toolTimings[id] = timing
            updateTool(id) { tool in
                var next = tool
                next.status = isErr ? .error : .ok
                next.result = text
                next.error = err.isNull ? nil : (err["reason"].str() ?? err["code"].str())
                next.endedAt = e["time"].long()
                return next
            }
        case "tool/ptc-dispatch-start":
            upsertPtcDispatch(data, time: e["time"].long(), settled: false)
        case "tool/ptc-dispatch":
            upsertPtcDispatch(data, time: e["time"].long(), settled: true)
        case "approval/asked":
            if let id = data["callId"].str() {
                if let approvalId = data["id"].str() { approvalCall[approvalId] = id }
                updateTool(id) { tool in
                    var next = tool
                    next.status = .awaitingApproval
                    return next
                }
            }
        case "approval/decided":
            let outcome = data["outcome"].str()
            let callId = data["id"].str().flatMap { approvalCall.removeValue(forKey: $0) }
            let known = callId.flatMap { toolIndex[$0] }
            let index = known ?? committed.indices.reversed().first { idx in
                if case .tool(let tool) = committed[idx] { return tool.status == .awaitingApproval }
                return false
            }
            if let index, case .tool(let tool) = committed[index] {
                var next = tool
                if outcome == "allowed-once" {
                    next.status = .running
                } else {
                    next.status = .error
                    next.error = outcome
                }
                committed[index] = .tool(next)
            }
        case "deliverables/presented":
            let files = (data["files"].arr() ?? []).compactMap { file -> DeliverableFile? in
                guard let path = file["path"].str(), !path.isEmpty else { return nil }
                return DeliverableFile(path: path, description: file["description"].str())
            }
            if !files.isEmpty {
                committed.append(.deliverable(Item.Deliverable(key: "dl\(seq)", files: files, turn: data["turn"].int())))
            }
        default:
            break
        }
        return true
    }

    private func matchingAttempt(_ e: JSONValue) -> LiveAttempt? {
        guard let attempt = live else { return nil }
        if e["type"].str() == "assistant/message", let op = e["surfaceOp"].str(), op != "append" { return nil }
        let seq = e["seq"].long() ?? -1
        guard seq > attempt.startedAfterSeq,
              e["data"]["turn"].int() == attempt.turn,
              e["data"]["step"].int() == attempt.step else { return nil }
        return attempt
    }

    private func settleAttempt(_ e: JSONValue) {
        if e["type"].str() == "assistant/message", let op = e["surfaceOp"].str(), op != "append" { return }
        guard let turn = e["data"]["turn"].int(), let step = e["data"]["step"].int(), let seq = e["seq"].long() else { return }
        settlementSeqs["\(turn):\(step)"] = seq
        if let attempt = matchingAttempt(e) {
            attempt.settlementSeq = seq
            attempt.settlementType = e["type"].str()
        }
    }

    @discardableResult
    private func stream(_ f: JSONValue) -> Bool {
        guard let revision = f["revision"].long() else { return continuityFault() }
        if revision <= assistantRevision {
            let id = f["attemptId"].str()
            if f["type"].str() == "start", let id, id != live?.id, !retiredAttempts.contains(id),
               (f["startedAfterSeq"].long() ?? -1) >= cursor {
                return continuityFault()
            }
            return false
        }
        if revision != assistantRevision + 1 { return continuityFault() }
        assistantRevision = revision
        guard let id = f["attemptId"].str() else { return continuityFault() }
        if retiredAttempts.contains(id) { return false }
        switch f["type"].str() {
        case "start":
            guard let turn = f["turn"].int(), let step = f["step"].int(), let afterSeq = f["startedAfterSeq"].long() else {
                return continuityFault()
            }
            if streamSuppressed || turnFacts[turn]?.closed == true || (openTurn.map { turn < $0 } == true)
                || (settlementSeqs["\(turn):\(step)"] ?? -1) > afterSeq {
                retiredAttempts.insert(id)
                return false
            }
            if let previous = live {
                if previous.id == id { return false }
                if previous.settlementSeq == nil { return continuityFault() }
                retiredAttempts.insert(previous.id)
            }
            live = LiveAttempt(id: id, turn: turn, step: step, startedAfterSeq: afterSeq, nextIndex: 0)
            if turnFacts[turn] == nil { turnFacts[turn] = TurnRecord(turn: turn) }
            return true
        case "chunk", "end":
            guard let attempt = live, attempt.id == id else { return false }
            guard let index = f["index"].long() else { return continuityFault() }
            if index < attempt.nextIndex { return false }
            if index != attempt.nextIndex { return continuityFault() }
            if f["type"].str() == "chunk" {
                attempt.nextIndex += 1
                if attempt.settlementSeq != nil { return false }
                attempt.chunk(f["chunk"], time: f["time"].long())
                return true
            }
            switch f["outcome"]["kind"].str() {
            case "committed":
                if attempt.settlementSeq == nil
                    || f["outcome"]["seq"].long() != attempt.settlementSeq
                    || f["outcome"]["eventType"].str() != attempt.settlementType {
                    return continuityFault()
                }
            case "abandoned":
                if attempt.settlementSeq != nil { return continuityFault() }
            default:
                return continuityFault()
            }
            retiredAttempts.insert(id)
            live = nil
            return attempt.settlementSeq == nil
        default:
            return continuityFault()
        }
    }

    @discardableResult
    private func continuityFault() -> Bool {
        needsResync = true
        live = nil
        return true
    }

    private func upsertUser(_ msg: JSONValue, key: String, pending: Bool, at: Int64?, seq: Int64?) {
        let blocks = msg["content"].arr() ?? []
        let text = blocks.filter { $0["type"].str() == "text" }.map { $0["text"].str() ?? "" }.joined(separator: "\n")
        let imageRefs = blocks.compactMap { block -> ImageRef? in
            let att = block["attachment"]
            let id = att["attachmentId"].str() ?? block["attachmentId"].str()
            guard let id else { return nil }
            return ImageRef(attachmentId: id, mediaType: att["mediaType"].str() ?? block["mediaType"].str())
        }
        let images = imageRefs.isEmpty ? blocks.filter { $0["type"].str() == "image" }.count : imageRefs.count
        let rpc = msg["source"]["rpcId"].str()
        let messageId = msg["id"].str()
        let sourceJson = prettySource(msg["source"])
        let idx = rpc.flatMap { userByRpc[$0] } ?? messageId.flatMap { userByMessage[$0] }
        if let idx, case .user(var old) = committed[idx] {
            old.text = text
            old.images = images
            old.pending = pending && old.pending
            old.at = at ?? old.at
            old.seq = seq ?? old.seq
            old.imageRefs = imageRefs.isEmpty ? old.imageRefs : imageRefs
            old.requestId = rpc ?? old.requestId
            old.messageId = messageId ?? old.messageId
            old.messageSourceJson = sourceJson ?? old.messageSourceJson
            committed[idx] = .user(old)
            if let rpc { userByRpc[rpc] = idx }
            if let messageId { userByMessage[messageId] = idx }
        } else {
            if let rpc { userByRpc[rpc] = committed.count }
            if let messageId { userByMessage[messageId] = committed.count }
            committed.append(.user(Item.User(
                key: key, text: text, images: images, pending: pending, at: at, seq: seq,
                imageRefs: imageRefs, requestId: rpc, messageId: messageId, messageSourceJson: sourceJson
            )))
        }
    }

    private func addEcho(_ prompt: QueuedPrompt) {
        if userByRpc[prompt.id] != nil { return }
        userByRpc[prompt.id] = committed.count
        committed.append(.user(Item.User(
            key: "local-\(prompt.id)", text: prompt.text, images: prompt.images, pending: true,
            at: nil, seq: nil, imageRefs: [], requestId: prompt.id, messageId: nil
        )))
    }

    private func upsertContext(_ msg: JSONValue, key: String, at: Int64?) {
        let text = (msg["content"].arr() ?? []).filter { $0["type"].str() == "text" }.map { $0["text"].str() ?? "" }.joined(separator: "\n")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        committed.append(.context(Item.Context(
            key: key, text: text, sourceKind: msg["source"]["kind"].str(), at: at,
            messageSourceJson: prettySource(msg["source"])
        )))
    }

    private func upsertTool(id: String, name: String, args: String, time: Int64?, turn: Int?, step: Int?, status: ToolStatus = .running, parentCallId: String? = nil) {
        if let i = toolIndex[id], case .tool(var tool) = committed[i] {
            tool.name = name.isEmpty ? tool.name : name
            tool.arguments = args.isEmpty ? tool.arguments : args
            if tool.status == .preparing { tool.status = status }
            if tool.status == .preparing && status == .running { tool.startedAt = time }
            tool.turn = turn ?? tool.turn
            tool.step = step ?? tool.step
            tool.parentCallId = parentCallId ?? tool.parentCallId
            committed[i] = .tool(tool)
        } else {
            toolIndex[id] = committed.count
            committed.append(.tool(Item.Tool(
                key: "k\(id)", callId: id, name: name, arguments: args, status: status,
                result: nil, error: nil, startedAt: time, endedAt: nil, turn: turn, step: step, parentCallId: parentCallId, schemaJson: nil
            )))
        }
    }

    private func updateTool(_ id: String, _ transform: (Item.Tool) -> Item.Tool) {
        guard let i = toolIndex[id], case .tool(let tool) = committed[i] else { return }
        committed[i] = .tool(transform(tool))
    }

    private func isTyped(_ msg: JSONValue) -> Bool {
        if let kind = msg["source"]["kind"].str() { return kind == "user" }
        let text = (msg["content"].arr() ?? []).first { $0["type"].str() == "text" }?["text"].str() ?? ""
        return msg["source"].isNull && !text.trimmingCharacters(in: .whitespaces).hasPrefix("<")
    }

    private func queuedPrompt(_ message: JSONValue) -> QueuedPrompt {
        let blocks = message["content"].arr() ?? []
        return QueuedPrompt(
            id: message["id"].str() ?? message["source"]["rpcId"].str() ?? "",
            text: blocks.filter { $0["type"].str() == "text" }.map { $0["text"].str() ?? "" }.joined(separator: "\n"),
            images: blocks.filter { $0["type"].str() == "image" }.count,
            files: blocks.filter { $0["type"].str() == "file" }.count,
            sending: false
        )
    }

    private func isRetired(_ message: JSONValue) -> Bool {
        if let id = message["id"].str(), retiredMessages.contains(id) { return true }
        if let rpc = message["source"]["rpcId"].str(), retiredRequests.contains(rpc) { return true }
        return false
    }

    private func retireMessage(_ message: JSONValue) {
        if let id = message["id"].str() { retiredMessages.insert(id) }
        if let rpc = message["source"]["rpcId"].str() {
            retiredRequests.insert(rpc)
            localEchoes.removeValue(forKey: rpc)
        }
    }

    @discardableResult
    private func readInbox(_ value: JSONValue, seq: Int64, baseline: Bool = false) -> Bool {
        if seq < inboxSeq || (!baseline && seq == inboxSeq) || value.obj() == nil { return false }
        inboxSeq = seq
        for target in ["next-turn", "next-step"] {
            inbox[target] = value[target].arr() ?? []
            for (index, message) in (inbox[target] ?? []).enumerated() {
                observeInboxMessage(target: target, message: message, seq: seq, index: index)
            }
        }
        return true
    }

    private func prettySource(_ source: JSONValue) -> String? {
        guard source.obj() != nil else { return nil }
        return source.prettyString()
    }

    private func upsertSystemPrompt(_ e: JSONValue, data: JSONValue, seq: Int64) {
        let surface = e["surfaceOp"]
        if surface.obj() != nil { return }
        if let op = surface.str(), op != "append" { return }
        let msg = data["message"].isNull ? data : data["message"]
        let text = (msg["content"].arr() ?? []).filter { $0["type"].str() == "text" }.map { $0["text"].str() ?? "" }.joined(separator: "\n")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        let label = systemPromptSeen ? TrajL.layoutSystemPromptUpdated : TrajL.layoutInitialSystemPrompt
        let previous = systemPromptSeen ? lastSystemPromptText : nil
        systemPromptSeen = true
        lastSystemPromptText = text
        committed.append(.system(Item.System(
            key: "sys\(seq)", label: label, text: text, at: e["time"].long(), previousText: previous
        )))
    }

    private func upsertCompactionStart(_ data: JSONValue, time: Int64?) {
        guard let id = data["compactionId"].str(), compactIndex[id] == nil else { return }
        compactIndex[id] = committed.count
        committed.append(.compacted(Item.Compacted(
            key: "cmp\(id)", compactionId: id, status: .running,
            startedAt: time, turn: data["turn"].int() ?? openTurn
        )))
    }

    private func upsertCompactionSummary(_ data: JSONValue) {
        guard let id = data["compactionId"].str() else { return }
        let summary = data["summary"].str() ?? (data["message"]["content"].arr() ?? [])
            .filter { $0["type"].str() == "text" }
            .map { $0["text"].str() ?? "" }
            .joined(separator: "\n")
            .nilIfBlank
        guard let i = compactIndex[id], case .compacted(var c) = committed[i] else { return }
        c.summary = summary ?? c.summary
        committed[i] = .compacted(c)
    }

    private func upsertCompactionEnd(_ data: JSONValue, time: Int64?) {
        guard let id = data["compactionId"].str() else { return }
        let err = data["error"]
        let interrupted = err["code"].str() == "interrupted" || err["reason"].str() == "interrupted" || data["interrupted"].bool() == true
        let isErr = !err.isNull
        guard let i = compactIndex[id], case .compacted(var c) = committed[i] else { return }
        c.status = isErr ? .error : .ok
        c.error = err.isNull ? nil : (err["reason"].str() ?? err["message"].str() ?? err["code"].str())
        c.interrupted = interrupted
        c.endedAt = time
        committed[i] = .compacted(c)
    }

    private func observeInboxMessage(target: String, message: JSONValue, seq: Int64, index: Int) {
        if isRetired(message) { return }
        let rpc = message["source"]["rpcId"].str()
        if let rpc, localEchoes[rpc]?.queued == true { localEchoes.removeValue(forKey: rpc) }
        if target == "next-step", isTyped(message) {
            upsertUser(message, key: "inbox-\(queuedPrompt(message).id)", pending: true, at: nil, seq: seq)
        }
        _ = index
    }

    private func assistantStreamFirstTokenTime(_ stream: JSONValue) -> Int64? {
        var earliest: Int64?
        for record in stream.arr() ?? [] {
            guard let type = record["type"].str() else { continue }
            if type == "reasoning-chunks" || type == "reasoning-delta" { continue }
            let time: Int64?
            switch type {
            case "text-chunks", "tool-call-chunks": time = record["time0"].long() ?? record["time"].long()
            case "chunk": time = record["time"].long()
            default: time = record["time"].long() ?? record["time0"].long()
            }
            guard let time else { continue }
            earliest = earliest.map { min($0, time) } ?? time
        }
        return earliest
    }

    private func retryIdentity(_ data: JSONValue) -> RetryIdentity? {
        guard let id = data["retryId"].str(), !id.isEmpty else { return nil }
        return RetryIdentity(id: id, turn: data["turn"].int(), step: data["step"].int())
    }

    private func scheduleRetry(_ data: JSONValue, seq: Int64) {
        guard let identity = retryIdentity(data), let retry = data["retry"].int() else { return }
        let attempt = RetryAttempt(
            seq: seq,
            retry: retry,
            maxRetries: data["maxRetries"].int(),
            mode: data["mode"].str() ?? "",
            delayMs: data["delayMs"].long() ?? 0,
            message: data["failure"]["message"].str() ?? "",
            code: data["failure"]["code"].str(),
            state: .scheduled
        )
        if let index = retryIndex[identity], case .retry(let previous) = committed[index] {
            committed[index] = .retry(projectRetry(Item.Retry(
                key: previous.key, retryId: previous.retryId, turn: previous.turn, step: previous.step,
                attempts: previous.attempts + [attempt]
            )))
        } else {
            let item = Item.Retry(
                key: "retry:\(identity.turn.map(String.init) ?? "nil"):\(identity.step.map(String.init) ?? "nil"):\(identity.id)",
                retryId: identity.id, turn: identity.turn, step: identity.step, attempts: [attempt]
            )
            retryIndex[identity] = committed.count
            committed.append(.retry(projectRetry(item)))
        }
    }

    private func projectRetry(_ item: Item.Retry) -> Item.Retry {
        let starts = retryStarts[item.identity]
        let closedAt = max(
            item.turn.flatMap { turnFacts[$0]?.endSeq } ?? -1,
            (item.turn != nil && item.step != nil) ? (closedSteps[StepIdentity(turn: item.turn!, step: item.step!)] ?? -1) : -1
        )
        var updated = item.attempts
        var changed = false
        for index in updated.indices {
            let attempt = updated[index]
            let state: RetryState
            if attempt.state == .started || (starts?[attempt.retry] ?? -1) > attempt.seq {
                state = .started
            } else if index == updated.count - 1 && closedAt > attempt.seq {
                state = .cancelled
            } else {
                state = attempt.state
            }
            if state != attempt.state {
                var next = attempt
                next.state = state
                updated[index] = next
                changed = true
            }
        }
        return changed ? Item.Retry(key: item.key, retryId: item.retryId, turn: item.turn, step: item.step, attempts: updated) : item
    }

    private func refreshRetries() {
        for index in retryIndex.values {
            if case .retry(let item) = committed[index] {
                committed[index] = .retry(projectRetry(item))
            }
        }
    }

    private func upsertPtcDispatch(_ data: JSONValue, time: Int64?, settled: Bool) {
        guard let subCallId = data["subCallId"].str(), let parentCallId = data["parentCallId"].str() else { return }
        let args: String
        if let text = data["arguments"].str() {
            args = text
        } else if data["arguments"].obj() != nil || data["arguments"].arr() != nil {
            args = data["arguments"].prettyString() ?? "{}"
        } else {
            args = "{}"
        }
        upsertTool(
            id: subCallId,
            name: data["name"].str() ?? "",
            args: args,
            time: time,
            turn: openTurn,
            step: openStep,
            parentCallId: parentCallId
        )
        if !settled { return }
        let text = (data["content"].arr() ?? [])
            .filter { $0["type"].str() == "text" }
            .map { $0["text"].str() ?? "" }
            .joined(separator: "\n")
        let err = data["error"]
        let isErr = data["isError"].bool() == true || !err.isNull
        updateTool(subCallId) { tool in
            var next = tool
            next.status = isErr ? .error : .ok
            next.result = text.isEmpty ? nil : text
            next.error = err.isNull ? nil : (err["reason"].str() ?? err["code"].str())
            next.endedAt = time
            next.parentCallId = parentCallId
            return next
        }
    }
}

struct RetryIdentity: Hashable {
    var id: String
    var turn: Int?
    var step: Int?
}

private struct StepIdentity: Hashable {
    var turn: Int
    var step: Int
}

private final class LiveAttempt {
    let id: String
    let turn: Int
    let step: Int
    let startedAfterSeq: Int64
    var nextIndex: Int64
    var settlementSeq: Int64?
    var settlementType: String?
    var firstTokenTime: Int64?

    private struct Block {
        var type: String
        var text = ""
        var toolId: String?
        var toolName: String?
        var startedAt: Int64?
    }

    private var blocks: [Int: Block] = [:]

    init(id: String, turn: Int, step: Int, startedAfterSeq: Int64, nextIndex: Int64) {
        self.id = id
        self.turn = turn
        self.step = step
        self.startedAfterSeq = startedAfterSeq
        self.nextIndex = nextIndex
    }

    func record(_ rec: JSONValue, remaining: Int64) -> Int {
        let type = rec["type"].str()
        let blockType: String?
        switch type {
        case "text-chunks": blockType = "text"
        case "reasoning-chunks": blockType = "reasoning"
        case "tool-call-chunks": blockType = "tool-call"
        default:
            if type == "chunk" { chunk(rec["chunk"], time: rec["time"].long()) } else { chunk(rec, time: nil) }
            return 1
        }
        guard let blockType else { return 1 }
        let members = rec[blockType == "tool-call" ? "args" : "texts"].arr() ?? []
        let count = min(Int64(members.count), remaining)
        if count == 0 { return 0 }
        let time = rec["time0"].long() ?? rec["time"].long()
        var block = block(rec["index"].int() ?? 0, blockType)
        if blockType == "reasoning" { block.startedAt = block.startedAt ?? time }
        if blockType == "tool-call" {
            block.toolId = rec["id"].str() ?? block.toolId
            block.toolName = rec["name"].str() ?? block.toolName
            if !(block.toolName ?? "").isEmpty { block.startedAt = block.startedAt ?? time }
        }
        for i in 0..<Int(count) { block.text += members[i].str() ?? "" }
        blocks[rec["index"].int() ?? 0] = block
        return Int(count)
    }

    func chunk(_ c: JSONValue, time: Int64?) {
        let idx = c["index"].int() ?? 0
        switch c["type"].str() {
        case "block-start":
            var b = block(idx, c["blockType"].str() ?? "text")
            b.startedAt = time
            blocks[idx] = b
        case "text-delta":
            var b = block(idx, "text")
            b.text += c["text"].str() ?? ""
            blocks[idx] = b
            if firstTokenTime == nil { firstTokenTime = time }
        case "reasoning-delta":
            var b = block(idx, "reasoning")
            b.startedAt = b.startedAt ?? time
            b.text += c["text"].str() ?? ""
            blocks[idx] = b
        case "tool-call-delta":
            var b = block(idx, "tool-call")
            b.toolId = c["id"].str() ?? b.toolId
            b.toolName = c["name"].str() ?? b.toolName
            if !(b.toolName ?? "").isEmpty { b.startedAt = b.startedAt ?? time }
            b.text += c["argumentsDelta"].str() ?? ""
            blocks[idx] = b
        default:
            break
        }
    }

    private func block(_ i: Int, _ type: String) -> Block {
        blocks[i] ?? Block(type: type)
    }

    func items() -> [Item] {
        blocks.keys.sorted().compactMap { i in
            guard let b = blocks[i] else { return nil }
            switch b.type {
            case "reasoning":
                return .reasoning(Item.Reasoning(key: "live-\(id)-\(i)", text: b.text, durationMs: nil, live: true, turn: turn, step: step, seq: nil))
            case "tool-call":
                guard let name = b.toolName, !name.isEmpty else { return nil }
                return .tool(Item.Tool(
                    key: "live-\(id)-\(i)", callId: b.toolId ?? "", name: name, arguments: b.text,
                    status: .preparing, result: nil, error: nil, startedAt: b.startedAt, endedAt: nil,
                    turn: turn, step: step, parentCallId: nil
                ))
            default:
                if b.text.isEmpty { return nil }
                return .text(Item.Text(key: "live-\(id)-\(i)", text: b.text, live: true, at: nil, seq: nil, messageId: nil, turn: turn, step: step))
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
