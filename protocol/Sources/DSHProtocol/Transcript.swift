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

public enum Item: Sendable, Equatable, Identifiable {
    case user(User)
    case reasoning(Reasoning)
    case text(Text)
    case tool(Tool)
    case notice(Notice)
    case deliverable(Deliverable)
    case context(Context)

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
    }

    public struct Reasoning: Sendable, Equatable {
        public var key: String
        public var text: String
        public var durationMs: Int64?
        public var live: Bool
        public var turn: Int?
        public var step: Int?
        public var seq: Int64?
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
    }

    public struct Notice: Sendable, Equatable {
        public var key: String
        public var text: String
        public var turn: Int?
    }

    public struct Deliverable: Sendable, Equatable {
        public var key: String
        public var files: [DeliverableFile]
        public var turn: Int?
    }

    public struct Context: Sendable, Equatable {
        public var key: String
        public var text: String
        public var sourceKind: String?
        public var at: Int64?
    }
}

public struct Usage: Sendable, Equatable {
    public var turns: Int
    public var steps: Int
    public var inputTokens: Int64
    public var cacheReadTokens: Int64
    public var outputTokens: Int64
}

public struct StepRecord: Sendable, Equatable {
    public var seq: Int64
    public var turn: Int
    public var step: Int
    public var replyText: String
    public var reasoningText: String
}

public struct TurnRecord: Sendable, Equatable {
    public var turn: Int
    public var startSeq: Int64?
    public var endSeq: Int64?
    public var startedAt: Int64?
    public var endedAt: Int64?
    public var endReason: String?
    public var closed: Bool { endSeq != nil }
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

    public private(set) var needsResync = false
    public private(set) var cursor: Int64 = -1
    public private(set) var firstSeq: Int64 = -1
    public private(set) var hasMore = false
    public private(set) var running = false

    public init() {}

    public var title: String? { titleValue }
    public var usage: Usage { Usage(turns: turns, steps: steps, inputTokens: inputTokens, cacheReadTokens: cacheRead, outputTokens: outputTokens) }
    public var planMode: Bool { planActive }
    public func todosSnapshot() -> [TodoItem] { todos }
    public func turnRecords() -> [TurnRecord] { turnFacts.values.sorted { $0.turn < $1.turn } }

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
            return false
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
        _ = prior.apply(jsonObject([
            "type": .string("snapshot"),
            "cursor": .number(Double(maxSeq)),
            "hasMore": .bool(false),
            "records": .array(filtered),
            "projections": .object([:]),
        ]))
        let older = prior.items()
        if !older.isEmpty {
            committed.insert(contentsOf: older, at: 0)
            rebuildIndexes()
        }
        if let min = filtered.compactMap({ $0["event"]["seq"].long() }).min() {
            firstSeq = firstSeq < 0 ? min : Swift.min(firstSeq, min)
        }
        return !older.isEmpty
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
    }

    private func rebuildIndexes() {
        toolIndex.removeAll()
        userByRpc.removeAll()
        userByMessage.removeAll()
        for (index, item) in committed.enumerated() {
            switch item {
            case .tool(let tool):
                if !tool.callId.isEmpty { toolIndex[tool.callId] = index }
            case .user(let user):
                if let rpc = user.requestId { userByRpc[rpc] = index }
                if let messageId = user.messageId { userByMessage[messageId] = index }
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
            if endsCurrent {
                openTurn = nil
                openStep = nil
            }
            switch reason["kind"].str() {
            case "error":
                committed.append(.notice(Item.Notice(
                    key: "te\(seq)",
                    text: reason["error"]["message"].str() ?? "",
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
            if let turn = openTurn, turnFacts[turn] == nil { turnFacts[turn] = TurnRecord(turn: turn) }
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
            let messageId = data["message"]["id"].str()
            for (i, block) in (data["message"]["content"].arr() ?? []).enumerated() {
                switch block["type"].str() {
                case "reasoning":
                    committed.append(.reasoning(Item.Reasoning(
                        key: "r\(seq).\(i)",
                        text: block["text"].str() ?? "",
                        durationMs: nil,
                        live: false,
                        turn: ownerTurn,
                        step: step,
                        seq: seq
                    )))
                case "text":
                    if let text = block["text"].str(), !text.isEmpty {
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
            outputTokens += u["outputTokens"].long() ?? 0
            inputTokens += (u["inputTokens"].long() ?? 0) + (u["cacheReadTokens"].long() ?? 0) + (u["cacheWriteTokens"].long() ?? 0)
            cacheRead += u["cacheReadTokens"].long() ?? 0
            if data["interrupted"].bool() == true {
                committed.append(.notice(Item.Notice(key: "i\(seq)", text: "已停止", turn: ownerTurn)))
            }
        case "assistant/attempt":
            settleAttempt(e)
        case "tool/call":
            let id = data["callId"].str() ?? "c\(seq)"
            upsertTool(
                id: id,
                name: data["name"].str() ?? "",
                args: data["arguments"].str() ?? "",
                time: e["time"].long(),
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
            updateTool(id) { tool in
                var next = tool
                next.status = isErr ? .error : .ok
                next.result = text
                next.error = err.isNull ? nil : (err["reason"].str() ?? err["code"].str())
                next.endedAt = e["time"].long()
                return next
            }
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
            committed[idx] = .user(old)
            if let rpc { userByRpc[rpc] = idx }
            if let messageId { userByMessage[messageId] = idx }
        } else {
            if let rpc { userByRpc[rpc] = committed.count }
            if let messageId { userByMessage[messageId] = committed.count }
            committed.append(.user(Item.User(
                key: key, text: text, images: images, pending: pending, at: at, seq: seq,
                imageRefs: imageRefs, requestId: rpc, messageId: messageId
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
        committed.append(.context(Item.Context(key: key, text: text, sourceKind: msg["source"]["kind"].str(), at: at)))
    }

    private func upsertTool(id: String, name: String, args: String, time: Int64?, turn: Int?, step: Int?, status: ToolStatus = .running) {
        if let i = toolIndex[id], case .tool(var tool) = committed[i] {
            tool.name = name.isEmpty ? tool.name : name
            tool.arguments = args.isEmpty ? tool.arguments : args
            if tool.status == .preparing { tool.status = status }
            if tool.status == .preparing && status == .running { tool.startedAt = time }
            tool.turn = turn ?? tool.turn
            tool.step = step ?? tool.step
            committed[i] = .tool(tool)
        } else {
            toolIndex[id] = committed.count
            committed.append(.tool(Item.Tool(
                key: "k\(id)", callId: id, name: name, arguments: args, status: status,
                result: nil, error: nil, startedAt: time, endedAt: nil, turn: turn, step: step, parentCallId: nil
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

    private func observeInboxMessage(target: String, message: JSONValue, seq: Int64, index: Int) {
        if isRetired(message) { return }
        let rpc = message["source"]["rpcId"].str()
        if let rpc, localEchoes[rpc]?.queued == true { localEchoes.removeValue(forKey: rpc) }
        if target == "next-step", isTyped(message) {
            upsertUser(message, key: "inbox-\(queuedPrompt(message).id)", pending: true, at: nil, seq: seq)
        }
        _ = index
    }
}

private final class LiveAttempt {
    let id: String
    let turn: Int
    let step: Int
    let startedAfterSeq: Int64
    var nextIndex: Int64
    var settlementSeq: Int64?
    var settlementType: String?

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
