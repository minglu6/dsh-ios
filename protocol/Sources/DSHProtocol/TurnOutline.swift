import Foundation

/// Host whole-log projection; coordinates are identities, never local row indexes.
public struct TurnOutlineEntry: Sendable, Equatable {
    public var turn: Int
    public var seq: Int64
    public var prompt: String
    public var response: String

    public init(turn: Int, seq: Int64, prompt: String = "", response: String = "") {
        self.turn = turn
        self.seq = seq
        self.prompt = prompt
        self.response = response
    }
}

final class TurnOutlineProjectionStore {
    private var sequence: Int64?
    private(set) var entries: [TurnOutlineEntry] = []

    @discardableResult
    func apply(_ value: JSONValue, seq: Int64) -> Bool {
        guard seq >= -1, seq <= 9_007_199_254_740_991, sequence.map({ seq > $0 }) ?? true else { return false }
        sequence = seq
        var byTurn: [Int: TurnOutlineEntry] = [:]
        for raw in value.arr() ?? [] {
            guard let turn = coordinate(raw["turn"]), let start = coordinate(raw["seq"], rejectNegativeZero: true) else { continue }
            byTurn[Int(turn)] = TurnOutlineEntry(turn: Int(turn), seq: start,
                prompt: raw["prompt"].str() ?? "", response: raw["response"].str() ?? "")
        }
        entries = byTurn.values.sorted { $0.turn < $1.turn }
        return true
    }

    func baseline(_ projections: JSONValue, fallbackSeq: Int64) {
        guard let values = projections["values"].obj() else { return }
        let seq = projections["asOfSeq"].long() ?? fallbackSeq
        if let value = values["turnOutline"] { apply(value, seq: seq) }
        else if sequence.map({ $0 <= seq }) ?? true {
            sequence = seq
            entries = []
        }
    }

    func clear() { sequence = nil; entries = [] }

    private func coordinate(_ value: JSONValue, rejectNegativeZero: Bool = false) -> Int64? {
        guard case .number(let n) = value, n.isFinite, n >= 0, n <= 9_007_199_254_740_991,
              n.rounded() == n, !(rejectNegativeZero && n == 0 && n.sign == .minus) else { return nil }
        return Int64(n)
    }
}

public struct TranscriptTurnMark: Sendable, Equatable, Identifiable {
    public var turn: Int
    public var prompt: String
    public var response: String
    public var anchorKey: String?
    public var seq: Int64?
    public var id: Int { turn }
}

public func transcriptTurnMarks(rows: [ChatRow], turns: [TurnRecord], outline: [TurnOutlineEntry]) -> [TranscriptTurnMark] {
    var marks: [Int: TranscriptTurnMark] = [:]
    var starts: [Int: Int64] = [:]
    var ends: [Int: Int64] = [:]
    for entry in outline {
        starts[entry.turn] = entry.seq
        marks[entry.turn] = TranscriptTurnMark(turn: entry.turn, prompt: entry.prompt, response: entry.response, seq: entry.seq)
    }
    for record in turns {
        if let seq = record.startSeq {
            starts[record.turn] = seq
            if marks[record.turn] == nil { marks[record.turn] = TranscriptTurnMark(turn: record.turn, prompt: "", response: "", seq: seq) }
        }
        ends[record.turn] = record.endSeq
    }
    let boundaries = starts.sorted { $0.value < $1.value }
    func userTurn(_ user: Item.User) -> Int? {
        guard !user.pending, let seq = user.seq else { return nil }
        var low = 0
        var high = boundaries.count
        while low < high {
            let mid = low + (high - low) / 2
            if boundaries[mid].value <= seq { low = mid + 1 } else { high = mid }
        }
        guard low > 0 else { return nil }
        let turn = boundaries[low - 1].key
        return ends[turn].map({ seq <= $0 }) ?? true ? turn : nil
    }
    var userAnchors = Set<Int>()
    for row in rows {
        let turn: Int?
        switch row {
        case .user(let user):
            turn = userTurn(user)
        case .answer(let item): turn = item.turn
        case .notice(let item): turn = item.turn
        case .retry(let item): turn = item.turn
        case .turnFailure(let item): turn = item.turn
        case .tool(let item): turn = item.turn
        case .reasoning(let item): turn = item.turn
        case .process(let item): turn = item.turn
        case .deliverable(let item): turn = item.turn
        case .changes(let item): turn = item.turn
        case .compacted(let item): turn = item.turn
        default: turn = nil
        }
        guard let turn else { continue }
        var mark = marks[turn] ?? TranscriptTurnMark(turn: turn, prompt: "", response: "", seq: starts[turn])
        var firstUser = false
        if case .user = row { firstUser = userAnchors.insert(turn).inserted }
        if mark.anchorKey == nil || firstUser { mark.anchorKey = row.key }
        switch row {
        case .user(let item): if firstUser, !item.text.isEmpty { mark.prompt = turnPreview(item.text, limit: 50) }
        case .answer(let item): if !item.text.isEmpty { mark.response = turnPreview(item.text, limit: 120) }
        case .process(let process):
            for case .text(let item) in process.members where !item.text.isEmpty { mark.response = turnPreview(item.text, limit: 120) }
        default: break
        }
        marks[turn] = mark
    }
    return marks.values.sorted { $0.turn < $1.turn }
}

private func turnPreview(_ text: String, limit: Int) -> String {
    let prefix = text.prefix(limit * 2)
    let normalized = prefix.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    if normalized.count > limit { return String(normalized.prefix(limit - 1)) + "…" }
    return normalized + (prefix.endIndex < text.endIndex ? "…" : "")
}
