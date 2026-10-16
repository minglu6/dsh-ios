import Foundation

public struct InspectorRow: Sendable, Equatable {
    public var key: String
    public var type: String
    public var value: JSONValue
    public var seq: Int64?
    public var time: Int64?
    public var children: [InspectorRow]
    public var identity: String
    public var location: String
    public var summary: String?
    public var defaultCollapsed: Bool

    public init(
        key: String,
        type: String,
        value: JSONValue,
        seq: Int64? = nil,
        time: Int64? = nil,
        children: [InspectorRow] = [],
        identity: String? = nil,
        location: String = "",
        summary: String? = nil,
        defaultCollapsed: Bool = false
    ) {
        self.key = key
        self.type = type
        self.value = value
        self.seq = seq
        self.time = time
        self.children = children
        self.identity = identity ?? seq.map(String.init) ?? ""
        self.location = location
        self.summary = summary
        self.defaultCollapsed = defaultCollapsed
    }
}

/// Chat projection snapshot consumed by the inspector (Android `ChatState` fields it actually reads).
public struct InspectorChatState: Sendable {
    public var sessionId: String
    public var items: [Item]
    public var turns: [TurnRecord]
    public var running: Bool
    public var hasMore: Bool

    public init(
        sessionId: String,
        items: [Item] = [],
        turns: [TurnRecord] = [],
        running: Bool = false,
        hasMore: Bool = false
    ) {
        self.sessionId = sessionId
        self.items = items
        self.turns = turns
        self.running = running
        self.hasMore = hasMore
    }
}

/// Desktop containment semantics: only surrounding stars are optional, not internal wildcards.
private func inspectorTypeQuery(_ filter: String) -> String {
    filter.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "*"))
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

public func inspectorTypeMatches(_ type: String, filter: String) -> Bool {
    let query = inspectorTypeQuery(filter)
    // Kotlin String.contains("") is true for every receiver.
    if query.isEmpty { return true }
    return type.range(of: query, options: .caseInsensitive) != nil
}

public func inspectorTypeSuggestions(_ rows: [InspectorRow], filter: String) -> [String] {
    var found = Set<String>()
    func visit(_ row: InspectorRow) {
        if inspectorTypeMatches(row.type, filter: filter) { found.insert(row.type) }
        row.children.forEach(visit)
    }
    rows.forEach(visit)
    return found.sorted()
}

public struct InspectorVisibleRow: Sendable, Equatable {
    public var row: InspectorRow
    public var depth: Int
    public var matches: Bool
}

/// Keep matching descendants' actual ancestors without counting those ancestors as matches.
public func inspectorVisibleRows(
    _ rows: [InspectorRow],
    filter: String,
    collapsed: Set<String>,
    expanded: Set<String> = []
) -> [InspectorVisibleRow] {
    func visit(_ row: InspectorRow, depth: Int) -> [InspectorVisibleRow] {
        let children = row.children.flatMap { visit($0, depth: depth + 1) }
        let matches = inspectorTypeMatches(row.type, filter: filter)
        if !matches && children.isEmpty { return [] }
        var out: [InspectorVisibleRow] = [InspectorVisibleRow(row: row, depth: depth, matches: matches)]
        if !collapsed.contains(row.key) &&
            (!inspectorTypeQuery(filter).isEmpty || !row.defaultCollapsed || expanded.contains(row.key)) {
            out.append(contentsOf: children)
        }
        return out
    }
    return rows.flatMap { visit($0, depth: 0) }
}

private let inspectorUtc: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
}()

public func inspectorTime(_ time: Int64?) -> String {
    guard let time else { return "" }
    return inspectorUtc.string(from: Date(timeIntervalSince1970: Double(time) / 1000.0))
}

/// Bounded horizontal display only; the original JSON remains the detail value.
public func inspectorPreview(_ value: JSONValue, hiddenRootFields: Set<String> = []) -> String {
    func preview(_ value: JSONValue, depth: Int) -> String {
        switch value {
        case .string(let text):
            return String(text.prefix(180))
        case .number, .bool, .null:
            return inspectorPrimitive(value)
        case .array, .object:
            if depth > 1 {
                if case .array(let items) = value { return "[\(items.count)]" }
                return "{…}"
            }
            let fields: Set<String>?
            switch value["type"].str() {
            case "tool-call-delta": fields = ["argumentsDelta"]
            case "reasoning-delta": fields = ["text"]
            default: fields = nil
            }
            let entries: [(String, JSONValue)]
            switch value {
            case .object(let object):
                entries = object.map { ($0.key, $0.value) }
            case .array(let items):
                entries = items.enumerated().map { (String($0.offset), $0.element) }
            default:
                entries = []
            }
            let filtered = entries.filter { key, _ in
                if depth == 0 && (key.lowercased() == "time" || hiddenRootFields.contains(key)) {
                    return false
                }
                if let fields {
                    return fields.contains(key)
                }
                let lower = key.lowercased()
                return lower != "type" && lower != "seq" && lower != "sequence"
            }
            let ordered: [(String, JSONValue)]
            if case .array = value {
                ordered = filtered
            } else {
                ordered = filtered.sorted { $0.0 < $1.0 }
            }
            if ordered.count == 1 { return preview(ordered[0].1, depth: depth + 1) }
            return String(ordered.prefix(5).map { key, item in
                "\(key): \(preview(item, depth: depth + 1))"
            }.joined(separator: " · ").prefix(240))
        }
    }
    return preview(value, depth: 0)
}

private func inspectorPrimitive(_ value: JSONValue) -> String {
    switch value {
    case .string(let text): return text
    case .bool(let flag): return flag ? "true" : "false"
    case .null: return "null"
    case .number(let number):
        if number.isFinite, number.rounded() == number, let asInt = value.numericLong() {
            return String(asInt)
        }
        return String(number)
    case .array, .object: return value.description
    }
}

private func inspectorLocation(_ value: JSONValue?) -> String {
    guard let turn = value?["turn"].numericLong() else { return "" }
    if let step = value?["step"].numericLong() { return "\(turn)/\(step)" }
    return "\(turn)"
}

private final class InspectorNode {
    var row: InspectorRow
    var children: [InspectorNode] = []
    init(_ row: InspectorRow) { self.row = row }
    func freeze() -> InspectorRow {
        var frozen = row
        frozen.children = children.map { $0.freeze() }
        return frozen
    }
}

/// Loaded starts alone create ranges; a partial history never gains invented Turn/Step headers.
public func inspectorRawRows(_ records: [JSONValue]) -> [InspectorRow] {
    var roots: [InspectorNode] = []
    var turn: InspectorNode?
    var step: InspectorNode?
    var attempts: [String: InspectorStream] = [:]
    func attach(_ node: InspectorNode, parent: InspectorNode?, useOpen: Bool) {
        let resolved = useOpen ? (parent ?? step ?? turn) : parent
        if let resolved {
            resolved.children.append(node)
        } else {
            roots.append(node)
        }
    }
    func attach(_ node: InspectorNode) { attach(node, parent: nil, useOpen: true) }
    for (ordinal, value) in records.enumerated() {
        let frame = value["frame"].obj().map { JSONValue.object($0) }
        let baseline = value["activeAttempt"].obj().map { JSONValue.object($0) }
        if value["type"].str() == "assistant-stream" || baseline != nil {
            let source = baseline ?? frame
            if let attemptId = source?["attemptId"].str() {
                let stream = attempts[attemptId] ?? {
                    let node = InspectorNode(InspectorRow(
                        key: "attempt:\(attemptId)",
                        type: "assistant/live",
                        value: value,
                        identity: attemptId,
                        location: inspectorLocation(source)
                    ))
                    attach(node)
                    let created = InspectorStream(node)
                    attempts[attemptId] = created
                    return created
                }()
                stream.sources.append(value)
                let location = inspectorLocation(source)
                let resolvedLocation = location.isEmpty ? stream.root.row.location : location
                stream.root.row.value = stream.sources.count == 1
                    ? value
                    : jsonObjectKeeping(["records": .array(stream.sources)])
                stream.root.row.location = resolvedLocation
                if let streamValues = baseline?["stream"].arr() {
                    streamValues.forEach { stream.record($0) }
                }
                if frame?["type"].str() == "chunk", let chunk = frame?["chunk"].obj() {
                    stream.chunk(
                        JSONValue.object(chunk),
                        time: frame?["time"].numericLong(),
                        index: frame?["index"].numericLong()
                    )
                }
                continue
            }
        }
        let type = value["type"].str() ?? "unknown"
        let seq = value["seq"].numericLong()
        let node = InspectorNode(InspectorRow(
            key: seq.map { "event:\($0)" } ?? "observed:\(ordinal)",
            type: type,
            value: value,
            seq: seq,
            time: value["time"].numericLong(),
            location: inspectorLocation(value["data"])
        ))
        switch type {
        case "turn/start":
            step = nil
            attach(node, parent: nil, useOpen: false)
            turn = node
        case "step/start":
            attach(node, parent: turn, useOpen: false)
            step = node
        case "step/end":
            attach(node)
            step = nil
        case "turn/end":
            attach(node, parent: turn, useOpen: false)
            step = nil
            turn = nil
        default:
            attach(node)
        }
        if type == "assistant/message" || type == "assistant/attempt" {
            let stream = InspectorStream(node)
            (value["data"]["stream"].arr() ?? []).forEach { stream.record($0) }
        }
    }
    return roots.map { $0.freeze() }
}

/// A block owns its indexed chunks even when different blocks are interleaved.
private final class InspectorStream {
    let root: InspectorNode
    var sources: [JSONValue] = []
    private var blocks: [Int64: InspectorNode] = [:]
    private var reasoning: [Int64: String] = [:]
    private var count: Int64 = 0

    init(_ root: InspectorNode) { self.root = root }

    func chunk(_ value: JSONValue, time: Int64?, index: Int64? = nil) {
        let object: JSONValue
        if value.obj() != nil {
            object = value
        } else {
            object = .object([:])
        }
        let ordinal = index ?? count
        count = max(count, ordinal + 1)
        let type = object["type"].str() ?? "unknown"
        let row = InspectorNode(InspectorRow(
            key: "\(root.row.key)/chunk:\(ordinal)",
            type: type,
            value: object,
            time: time,
            identity: String(ordinal),
            location: root.row.location
        ))
        let blockIndex = object["index"].numericLong()
        let parent = type == "block-start" ? nil : blockIndex.flatMap { blocks[$0] }
        (parent ?? root).children.append(row)
        if root.row.type == "assistant/live" {
            root.row.time = time
        }
        if type == "block-start", let blockIndex {
            blocks[blockIndex] = row
            if object["blockType"].str() == "reasoning" {
                reasoning[blockIndex] = ""
                row.row.summary = "blockType: reasoning"
            }
        } else if let parent, let blockIndex {
            if type == "reasoning-delta", reasoning[blockIndex] != nil {
                let text = String(((reasoning[blockIndex] ?? "") + (object["text"].str() ?? "")).prefix(240))
                reasoning[blockIndex] = text
                parent.row.summary = String(("blockType: reasoning" + (text.isEmpty ? "" : " · \(text)")).prefix(240))
            }
            if type == "block-end" {
                parent.row.defaultCollapsed = true
            }
        }
    }

    func record(_ value: JSONValue) {
        guard value.obj() != nil else { return } // Original malformed values remain in the owning event.
        if value["type"].str() == "chunk", value["chunk"].obj() != nil {
            chunk(value["chunk"], time: value["time"].numericLong())
            return
        }
        let type = value["type"].str()
        let tool = type == "tool-call-chunks"
        let members = value[tool ? "args" : "texts"].arr()
        let gaps = value["dt"].arr()
        let index = value["index"].inspectorInteger()
        var time = value["time0"].inspectorInteger()
        // Do not manufacture deltas or timestamps from unknown / incomplete compact records.
        let membersAreStrings = members?.allSatisfy {
            if case .string = $0 { return true }
            return false
        } ?? false
        let gapsAreInts = gaps?.allSatisfy { $0.inspectorInteger() != nil } ?? false
        let namePresent = value.obj()?.keys.contains("name") == true
        let nameEmpty = (value["name"].str() ?? "").isEmpty
        if type != "text-chunks" && type != "reasoning-chunks" && type != "tool-call-chunks"
            || members == nil || members!.isEmpty
            || gaps == nil || gaps!.count != members!.count - 1
            || index == nil || index! < 0 || time == nil
            || !membersAreStrings || !gapsAreInts
            || (tool && ((value["id"].str() ?? "").isEmpty || (namePresent && nameEmpty))) {
            chunk(value, time: value["time"].numericLong())
            return
        }
        var lastTime = time!
        for gap in gaps! {
            lastTime += gap.inspectorInteger()!
            if lastTime < -inspectorSafeInteger || lastTime > inspectorSafeInteger {
                chunk(value, time: value["time"].numericLong())
                return
            }
        }
        for (memberIndex, textValue) in members!.enumerated() {
            if memberIndex > 0 { time = time! + gaps![memberIndex - 1].numericLong()! }
            let text = textValue.str() ?? ""
            var delta: [String: JSONValue] = [
                "type": .string(
                    type == "text-chunks" ? "text-delta"
                        : type == "reasoning-chunks" ? "reasoning-delta"
                        : "tool-call-delta"
                ),
                "index": .number(Double(index!)),
            ]
            if tool {
                delta["id"] = value["id"]
                if namePresent { delta["name"] = value["name"] }
                delta["argumentsDelta"] = .string(text)
            } else {
                delta["text"] = .string(text)
            }
            chunk(.object(delta), time: time)
        }
    }
}

private let inspectorSafeInteger: Int64 = 9_007_199_254_740_991

extension JSONValue {
    func inspectorInteger() -> Int64? {
        guard case .number(let value) = self, value.isFinite, value.rounded() == value else { return nil }
        if abs(value) > Double(inspectorSafeInteger) { return nil }
        let n = Int64(value)
        if n < -inspectorSafeInteger || n > inspectorSafeInteger { return nil }
        return n
    }
}

/// Inspect the same chat projection, including its real ProcessStep members.
/// Hidden reducer items remain roots at their input anchor; they are never assigned to a turn.
public func inspectorGroupRows(_ st: InspectorChatState, policy: PresentationPolicy) -> [InspectorRow] {
    let positions = Dictionary(uniqueKeysWithValues: st.items.enumerated().map { ($0.element.key, $0.offset) })
    let folded = foldChatItems(st.items, policy: policy, sessionRunning: st.running, turnRecords: st.turns, en: TrajL.en)
    var controlAnchors: [String: Int] = [:]
    for row in folded {
        guard case .process(let proc) = row, proc.turnSummary else { continue }
        let index = st.items.firstIndex { $0.inspectorTurn() == proc.turn }
        if let index { controlAnchors[proc.key] = index }
    }
    var covered = Set<String>()
    var lastPosition = -1
    let anchored: [(Int, InspectorRow)] = folded.map { row in
        let members: [Item]
        switch row {
        case .process(let proc): members = proc.members
        case .user(let item): members = [.user(item)]
        case .answer(let item): members = [.text(item)]
        case .tool(let item): members = [.tool(item)]
        case .reasoning(let item): members = [.reasoning(item)]
        case .notice(let item): members = [.notice(item)]
        case .retry(let item): members = [.retry(item)]
        case .turnFailure(let item): members = [.turnFailure(item)]
        case .deliverable(let item): members = [.deliverable(item)]
        case .changes(let item): members = [.changes(item)]
        case .turnTrigger(let item): members = [.context(item)]
        case .compacted(let item): members = [.compacted(item)]
        case .context(let item): members = [.context(item)]
        }
        covered.formUnion(members.map(\.key))
        let position = members.first.flatMap { positions[$0.key] } ?? controlAnchors[row.key] ?? lastPosition
        lastPosition = position
        let result: InspectorRow
        if case .process(let proc) = row {
            result = InspectorRow(
                key: "group:\(proc.key)",
                type: "ChatRow.Process",
                value: jsonObject([
                    "key": .string(proc.key),
                    "title": .string(proc.title),
                    "closed": .bool(proc.closed),
                    "defaultOpen": .bool(proc.defaultOpen),
                    "durationMs": proc.durationMs.map { .number(Double($0)) },
                    "turnSummary": .bool(proc.turnSummary),
                    "canCollapse": .bool(proc.canCollapse),
                    "turn": proc.turn.map { .number(Double($0)) },
                    "grouped": .bool(proc.grouped),
                    "controlledKeys": .array(Array(proc.controlledKeys).map { .string($0) }),
                    "activityKind": .string(proc.activityKind),
                    "detail": proc.detail.map { .string($0) },
                    "members": .array(proc.members.map { .string($0.key) }),
                    "steps": .array(proc.steps.map { .string($0.key) }),
                ]),
                children: proc.steps.map { step in
                    InspectorRow(
                        key: "step:\(proc.key):\(step.key)",
                        type: "ProcessStep",
                        value: jsonObject([
                            "key": .string(step.key),
                            "step": step.step.map { .number(Double($0)) },
                            "members": .array(step.members.map { .string($0.key) }),
                        ]),
                        children: step.members.map(inspectorItemRow),
                        identity: step.key,
                        location: step.members.first.map(inspectorItemLocation) ?? ""
                    )
                },
                identity: proc.key,
                location: proc.turn.map(String.init) ?? ""
            )
        } else {
            result = inspectorItemRow(members[0])
        }
        return (position, result)
    }
    let unlisted: [(Int, InspectorRow)] = st.items.enumerated().compactMap { index, item in
        covered.contains(item.key) ? nil : (index, inspectorItemRow(item))
    }
    return (anchored + unlisted).sorted { $0.0 < $1.0 }.map { $0.1 }
}

private func inspectorItemRow(_ item: Item) -> InspectorRow {
    let fields: JSONValue
    let type: String
    switch item {
    case .user(let v):
        type = "Item.User"
        fields = jsonObject([
            "text": .string(v.text),
            "images": .number(Double(v.images)),
            "pending": .bool(v.pending),
            "at": v.at.map { .number(Double($0)) },
            "seq": v.seq.map { .number(Double($0)) },
            "messageSourceJson": v.messageSourceJson.map { .string($0) },
            "imageRefs": .array(v.imageRefs.map {
                jsonObject(["attachmentId": .string($0.attachmentId), "mediaType": $0.mediaType.map { .string($0) }])
            }),
        ])
    case .text(let v):
        type = "Item.Text"
        fields = jsonObject([
            "text": .string(v.text),
            "live": .bool(v.live),
            "at": v.at.map { .number(Double($0)) },
            "seq": v.seq.map { .number(Double($0)) },
            "messageId": v.messageId.map { .string($0) },
            "turn": v.turn.map { .number(Double($0)) },
            "step": v.step.map { .number(Double($0)) },
        ])
    case .reasoning(let v):
        type = "Item.Reasoning"
        fields = jsonObject([
            "text": .string(v.text),
            "durationMs": v.durationMs.map { .number(Double($0)) },
            "live": .bool(v.live),
            "turn": v.turn.map { .number(Double($0)) },
            "step": v.step.map { .number(Double($0)) },
            "seq": v.seq.map { .number(Double($0)) },
        ])
    case .tool(let v):
        type = "Item.Tool"
        fields = jsonObject([
            "callId": .string(v.callId),
            "name": .string(v.name),
            "arguments": .string(v.arguments),
            "status": .string(inspectorToolStatus(v.status)),
            "result": v.result.map { .string($0) },
            "error": v.error.map { .string($0) },
            "startedAt": v.startedAt.map { .number(Double($0)) },
            "endedAt": v.endedAt.map { .number(Double($0)) },
            "schemaJson": v.schemaJson.map { .string($0) },
            "turn": v.turn.map { .number(Double($0)) },
            "step": v.step.map { .number(Double($0)) },
            "parentCallId": v.parentCallId.map { .string($0) },
        ])
    case .context(let v):
        type = "Item.Context"
        fields = jsonObject([
            "text": .string(v.text),
            "sourceKind": v.sourceKind.map { .string($0) },
            "at": v.at.map { .number(Double($0)) },
            "messageSourceJson": v.messageSourceJson.map { .string($0) },
            "toolAdditions": .array(v.toolAdditions.map { .string($0) }),
            "toolRemovals": .array(v.toolRemovals.map { .string($0) }),
        ])
    case .system(let v):
        type = "Item.System"
        fields = jsonObject([
            "label": .string(v.label),
            "text": .string(v.text),
            "at": v.at.map { .number(Double($0)) },
            "previousText": v.previousText.map { .string($0) },
            "toolsJson": v.toolsJson.map { .string($0) },
            "previousToolsJson": v.previousToolsJson.map { .string($0) },
        ])
    case .notice(let v):
        type = "Item.Notice"
        fields = jsonObject([
            "text": .string(v.text),
            "turn": v.turn.map { .number(Double($0)) },
            "kind": .string(v.kind.rawValue),
        ])
    case .retry(let v):
        type = "Item.Retry"
        fields = jsonObject([
            "retryId": .string(v.retryId),
            "turn": v.turn.map { .number(Double($0)) },
            "step": v.step.map { .number(Double($0)) },
            "attempts": .array(v.attempts.map { attempt in
                jsonObject([
                    "seq": .number(Double(attempt.seq)),
                    "retry": .number(Double(attempt.retry)),
                    "maxRetries": attempt.maxRetries.map { .number(Double($0)) },
                    "mode": .string(attempt.mode),
                    "delayMs": .number(Double(attempt.delayMs)),
                    "message": .string(attempt.message),
                    "code": attempt.code.map { .string($0) },
                    "state": .string(inspectorRetryState(attempt.state)),
                ])
            }),
        ])
    case .turnFailure(let v):
        type = "Item.TurnFailure"
        fields = jsonObject([
            "message": .string(v.message),
            "code": v.code.map { .string($0) },
            "turn": v.turn.map { .number(Double($0)) },
        ])
    case .compacted(let v):
        type = "Item.Compacted"
        fields = jsonObject([
            "compactionId": .string(v.compactionId),
            "status": .string(inspectorCompactionStatus(v.status)),
            "summary": v.summary.map { .string($0) },
            "error": v.error.map { .string($0) },
            "interrupted": .bool(v.interrupted),
            "startedAt": v.startedAt.map { .number(Double($0)) },
            "endedAt": v.endedAt.map { .number(Double($0)) },
            "turn": v.turn.map { .number(Double($0)) },
            "shadowedItemCount": v.shadowedItemCount.map { .number(Double($0)) },
            "shadowedTokenCount": v.shadowedTokenCount.map { .number(Double($0)) },
            "sourceCommandId": v.sourceCommandId.map { .string($0) },
            "hasCheckpoint": .bool(v.hasCheckpoint),
        ])
    case .deliverable(let v):
        type = "Item.Deliverable"
        fields = jsonObject([
            "turn": v.turn.map { .number(Double($0)) },
            "files": .array(v.files.map {
                jsonObject(["path": .string($0.path), "description": $0.description.map { .string($0) }])
            }),
        ])
    case .changes(let v):
        type = "Item.Changes"
        fields = jsonObject([
            "turn": .number(Double(v.turn)),
            "seq": v.seq.map { .number(Double($0)) },
        ])
    }
    var merged: [String: JSONValue] = ["key": .string(item.key)]
    if let object = fields.obj() {
        for (key, value) in object { merged[key] = value }
    }
    let value = JSONValue.object(merged)
    return InspectorRow(
        key: "item:\(item.key)",
        type: type,
        value: value,
        seq: item.inspectorSeq(),
        time: fields["at"].numericLong() ?? fields["startedAt"].numericLong(),
        identity: item.key,
        location: inspectorItemLocation(item),
        summary: inspectorPreview(value, hiddenRootFields: ["key", "turn", "step", "at", "startedAt"])
    )
}

private func inspectorToolStatus(_ status: ToolStatus) -> String {
    switch status {
    case .preparing: return "Preparing"
    case .running: return "Running"
    case .awaitingApproval: return "AwaitingApproval"
    case .ok: return "Ok"
    case .error: return "Error"
    }
}

private func inspectorCompactionStatus(_ status: CompactionStatus) -> String {
    switch status {
    case .running: return "Running"
    case .ok: return "Ok"
    case .error: return "Error"
    }
}

private func inspectorRetryState(_ state: RetryState) -> String {
    switch state {
    case .scheduled: return "Scheduled"
    case .started: return "Started"
    case .cancelled: return "Cancelled"
    }
}

private func inspectorFind(_ rows: [InspectorRow], _ predicate: (InspectorRow) -> Bool) -> InspectorRow? {
    for row in rows {
        if predicate(row) { return row }
        if let nested = inspectorFind(row.children, predicate) { return nested }
    }
    return nil
}

/// Resolve only identities and locations retained by the actual projection.
public func inspectorRowForItem(_ rows: [InspectorRow], item: Item) -> InspectorRow? {
    if let row = inspectorFind(rows, { $0.key == "item:\(item.key)" }) { return row }
    if case .tool(let tool) = item {
        if let row = inspectorFind(rows, {
            $0.value["data"]["callId"].str() == tool.callId ||
                ($0.type == "tool-call-delta" && $0.value["id"].str() == tool.callId)
        }) { return row }
    }
    let seq = item.inspectorSeq()
    let exact = seq.flatMap { target in inspectorFind(rows, { $0.seq == target }) }
    let location = inspectorItemLocation(item)
    let assistant = exact ?? (location.isEmpty ? nil : inspectorFind(rows, {
        $0.location == location &&
            ($0.type == "assistant/message" || $0.type == "assistant/attempt" || $0.type == "assistant/live")
    }))
    if case .reasoning = item, let assistant {
        if let block = inspectorFind(assistant.children, {
            $0.type == "block-start" && $0.value["blockType"].str() == "reasoning"
        }) { return block }
    }
    if let exact { return exact }
    if case .text = item, let assistant { return assistant }
    if case .reasoning = item, let assistant { return assistant }
    if location.isEmpty { return nil }
    return inspectorFind(rows, { $0.location == location && $0.type == "step/start" })
        ?? inspectorFind(rows, { $0.location == (item.inspectorTurn().map(String.init) ?? "") && $0.type == "turn/start" })
        ?? inspectorFind(rows, { $0.location == location })
}

/// Reverse navigation never guesses a chat item when neither identity nor Turn/Step is known.
public func inspectorItemForRow(_ st: InspectorChatState, row: InspectorRow) -> String? {
    if row.key.hasPrefix("item:") {
        return st.items.first { "item:\($0.key)" == row.key }?.key
    }
    if row.type == "ChatRow.Process" || row.type == "ProcessStep" {
        for child in row.children {
            if let found = inspectorItemForRow(st, row: child) { return found }
        }
        return nil
    }
    let callId = row.value["data"]["callId"].str()
        ?? (row.type == "tool-call-delta" ? row.value["id"].str() : nil)
    if let callId {
        if let tool = st.items.first(where: {
            if case .tool(let item) = $0 { return item.callId == callId }
            return false
        }) { return tool.key }
    }
    if let seq = row.seq {
        if row.type.hasPrefix("assistant/") {
            if let text = st.items.first(where: {
                if case .text(let item) = $0 { return item.seq == seq }
                return false
            }) { return text.key }
        }
        if let match = st.items.first(where: { $0.inspectorSeq() == seq }) { return match.key }
    }
    if row.location.isEmpty { return nil }
    let matching = st.items.filter {
        if row.location.contains("/") { return inspectorItemLocation($0) == row.location }
        return $0.inspectorTurn().map(String.init) == row.location
    }
    if row.type == "reasoning-delta" || (row.type == "block-start" && row.value["blockType"].str() == "reasoning") {
        if let reasoning = matching.first(where: { if case .reasoning = $0 { return true }; return false }) {
            return reasoning.key
        }
    }
    if row.type == "text-delta" || row.type.hasPrefix("assistant/") {
        if let text = matching.first(where: { if case .text = $0 { return true }; return false }) {
            return text.key
        }
    }
    return matching.first?.key
}

extension Item {
    func inspectorSeq() -> Int64? {
        switch self {
        case .user(let v): return v.seq
        case .text(let v): return v.seq
        case .reasoning(let v): return v.seq
        case .changes(let v): return v.seq
        case .retry(let v): return v.attempts.first?.seq
        default: return nil
        }
    }

    func inspectorTurn() -> Int? {
        switch self {
        case .text(let v): return v.turn
        case .reasoning(let v): return v.turn
        case .tool(let v): return v.turn
        case .notice(let v): return v.turn
        case .retry(let v): return v.turn
        case .turnFailure(let v): return v.turn
        case .compacted(let v): return v.turn
        case .deliverable(let v): return v.turn
        case .changes(let v): return v.turn
        default: return nil
        }
    }

    func inspectorStep() -> Int? {
        switch self {
        case .text(let v): return v.step
        case .reasoning(let v): return v.step
        case .tool(let v): return v.step
        case .retry(let v): return v.step
        default: return nil
        }
    }
}

private func inspectorItemLocation(_ item: Item) -> String {
    guard let turn = item.inspectorTurn() else { return "" }
    if let step = item.inspectorStep() { return "\(turn)/\(step)" }
    return "\(turn)"
}
