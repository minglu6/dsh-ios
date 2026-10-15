import Foundation

/// The loaded follow window, not a second subscription or a durable logging service.
public final class SessionInspectorLog: @unchecked Sendable {
    private var events: [JSONValue] = []
    private var observed: [JSONValue] = []
    private var sequences = Set<Int64>()
    private var published: [JSONValue] = []

    public init() {}

    public func clear() {
        events = []
        observed = []
        sequences = []
        publish()
    }

    public func apply(_ frame: JSONValue?) {
        guard let frame else { return }
        switch frame["type"].str() {
        case "snapshot":
            // A snapshot replaces the loaded window, including on reconnect. Pocket rejects
            // obsolete subscription generations before reaching this store.
            clear()
            merge(frame["records"])
            baseline(frame["assistantStream"])
        case "resume":
            merge(frame["records"], settle: true)
            if frame["assistantStream"].obj() != nil { baseline(frame["assistantStream"]) }
        case "event":
            let event = frame["event"]
            guard event.obj() != nil else { return }
            guard let seq = event["seq"].numericLong() else { return }
            if !sequences.insert(seq).inserted { return }
            if let last = events.last?["seq"].numericLong(), seq < last {
                events = (events + [event]).sorted {
                    ($0["seq"].numericLong() ?? 0) < ($1["seq"].numericLong() ?? 0)
                }
            } else {
                events.append(event)
            }
            if event["type"].str() == "assistant/message" { observed = [] }
        case "assistant-stream":
            guard frame.obj() != nil else { return }
            if frame["frame"]["type"].str() == "start" { observed = [] }
            observed.append(frame)
        default:
            return // Projection/control frames are not session events.
        }
        publish()
    }

    public func prepend(_ records: JSONValue?) {
        merge(records)
        publish()
    }

    public func snapshot() -> [JSONValue] { published }

    private func baseline(_ value: JSONValue) {
        observed = []
        // Preserve the actual baseline object, never synthesize stream timestamps or seqs.
        guard value.obj() != nil else { return }
        if value["activeAttempt"].obj() != nil { observed.append(value) }
    }

    private func merge(_ records: JSONValue?, settle: Bool = false) {
        let incoming = (records?.arr() ?? []).compactMap { record -> JSONValue? in
            if record["type"].str() != "event" { return nil }
            let event = record["event"]
            guard event.obj() != nil else { return nil }
            guard let seq = event["seq"].numericLong() else { return nil }
            return sequences.insert(seq).inserted ? event : nil
        }
        if incoming.isEmpty { return }
        events = (events + incoming).sorted {
            ($0["seq"].numericLong() ?? 0) < ($1["seq"].numericLong() ?? 0)
        }
        if settle && incoming.contains(where: { $0["type"].str() == "assistant/message" }) {
            observed = []
        }
    }

    private func publish() {
        published = events + observed
    }
}

extension JSONValue {
    /// Host integers only — JSON strings never become seq/clock values.
    func numericLong() -> Int64? {
        guard case .number(let value) = self, value.isFinite, value.rounded() == value else { return nil }
        if value < Double(Int64.min) || value > Double(Int64.max) { return nil }
        return Int64(value)
    }
}
