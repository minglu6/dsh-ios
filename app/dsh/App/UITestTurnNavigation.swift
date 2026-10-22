#if DEBUG
import Foundation
import CoreFoundation
import DSHProtocol

extension AppModel {
    func installUITestTurnNavigation(single: Bool, legacy: Bool) {
        guard uiTestFixture, let sessionId = chat?.sessionId else { return }
        showDrawer = false
        routeStack = []
        uiTestHistoryPagingStatus = "connecting"
        Task { @MainActor [weak self] in
            guard let self else { return }
            let transport = TurnNavigationTransport(sessionId: sessionId) { [weak self] status in
                Task { @MainActor in self?.uiTestHistoryPagingStatus = status }
            }
            let client = PocketClient()
            do {
                _ = try await client.connect(transport: transport, auth: .token("synthetic-turn-navigation"))
                guard self.chat?.sessionId == sessionId else { client.close(); return }
                let turns = single ? [21] : [8, 21]
                let values: [String: JSONValue] = legacy ? [:] : ["turnOutline": TurnNavigationFrames.outline(single ? [21] : [3, 8, 21])]
                self.installUITestHistoryPagingClient(client, snapshot: .object([
                    "type": .string("snapshot"), "cursor": .number(2103), "hasMore": .bool(!single),
                    "records": .array(turns.flatMap { TurnNavigationFrames.records(turn: $0) }),
                    "projections": .object(["asOfSeq": .number(2103), "values": .object(values)]),
                ]), subscriptionId: "fixture-turn-navigation")
                self.uiTestHistoryPagingStatus = "requests=0;responses=0;failures=0"
                self.uiTestTurnNavigationDriver = UITestTurnNavigationDriver { [weak self] in
                    Task { @MainActor in
                        guard let self, self.chat?.sessionId == sessionId else { return }
                        for frame in TurnNavigationFrames.records(turn: 34) { self.receiveUITestTurnNavigationFollow(frame) }
                        self.receiveUITestTurnNavigationFollow(.object([
                            "type": .string("projection"), "key": .string("turnOutline"), "seq": .number(3403),
                            "value": TurnNavigationFrames.outline(single ? [21, 34] : [3, 8, 21, 34]),
                        ]))
                    }
                }
            } catch { self.uiTestHistoryPagingStatus = "setup-error: \(error.localizedDescription)" }
        }
    }
}

/// Same cross-process control pattern as TodoLifecycle; no test-only production buttons.
final class UITestTurnNavigationDriver: @unchecked Sendable {
    private let append: @Sendable () -> Void
    static let notification = "dev.dsh.uitest.turnNavigation.append"
    init(append: @escaping @Sendable () -> Void) {
        self.append = append
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<UITestTurnNavigationDriver>.fromOpaque(observer).takeUnretainedValue().append()
            }, Self.notification as CFString, nil, .deliverImmediately)
    }
    deinit { CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque()) }
}

private enum TurnNavigationFrames {
    static func event(_ type: String, seq: Int, data: JSONValue) -> JSONValue {
        .object(["type": .string("event"), "event": .object([
            "seq": .number(Double(seq)), "time": .number(1_700_000_000_000 + Double(seq * 1000)),
            "type": .string(type), "data": data,
        ])])
    }

    static func outline(_ turns: [Int]) -> JSONValue {
        .array(turns.map { turn in .object([
            "turn": .number(Double(turn)), "seq": .number(Double(turn * 100)),
            "prompt": .string("Navigation prompt \(turn)"), "response": .string("Readable response preview for Host turn \(turn)"),
        ]) })
    }

    static func records(turn: Int) -> [JSONValue] {
        let seq = turn * 100
        let answer = (1...18).map { "Host turn \(turn) paragraph \($0). Retained transcript content for real scroll and reading-position checks." }.joined(separator: "\n\n")
        return [
            event("turn/start", seq: seq, data: .object(["turn": .number(Double(turn))])),
            event("user/message", seq: seq + 1, data: .object([
                "id": .string("nav-user-\(turn)"), "role": .string("user"), "source": .object(["kind": .string("user")]),
                "content": .array([.object(["type": .string("text"), "text": .string("Navigation prompt \(turn)")])]),
            ])),
            event("assistant/message", seq: seq + 2, data: .object([
                "turn": .number(Double(turn)), "step": .number(1),
                "message": .object(["id": .string("nav-answer-\(turn)"), "role": .string("assistant"),
                    "content": .array([.object(["type": .string("text"), "text": .string(answer)])])]),
            ])),
            event("turn/end", seq: seq + 3, data: .object(["turn": .number(Double(turn)), "reason": .object(["kind": .string("completed")])])),
        ]
    }
}

/// history.page runs through PocketClient and the normal AppModel page loader.
private final class TurnNavigationTransport: FrameTransport, @unchecked Sendable {
    let route = Route.wsLocal
    let endpointURL: URL? = nil
    var closeReason: String? { "Turn navigation fixture closed" }
    private let sessionId: String
    private let report: @Sendable (String) -> Void
    private let frames: AsyncThrowingStream<String, Error>
    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    private let lock = NSLock()
    private var requested = false

    init(sessionId: String, report: @escaping @Sendable (String) -> Void) {
        self.sessionId = sessionId
        self.report = report
        var sink: AsyncThrowingStream<String, Error>.Continuation!
        self.frames = AsyncThrowingStream { sink = $0 }
        self.continuation = sink
    }

    func send(_ text: String) async throws {
        let request = try JSONValue.parse(text)
        if request["op"].str() == "hello" {
            try reply(request, result: .object(["proto": .number(1)]))
            return
        }
        let valid = validate(request)
        report("requests=1;responses=0;failures=0")
        try await Task.sleep(nanoseconds: 650_000_000)
        if valid {
            try reply(request, result: .object(["records": .array(TurnNavigationFrames.records(turn: 3)), "hasMore": .bool(false)]))
            report("requests=1;responses=1;failures=0")
        } else {
            continuation.yield(try JSONValue.object([
                "id": request["id"], "ok": .bool(false),
                "error": .object(["code": .string("fixture"), "message": .string("Invalid navigation cursor/session or repeated page")]),
            ]).encodeString())
            report("requests=1;responses=0;failures=1")
        }
    }

    private func validate(_ request: JSONValue) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let args = request["args"]
        guard !requested, request["op"].str() == "history.page", args["sessionId"].str() == sessionId,
              args["beforeSeq"].int() == 800, args["throughSeq"].int() == 2103,
              args["maxMessages"].int() == HistoryPagingPolicy.pageSize else { return false }
        requested = true
        return true
    }
    private func reply(_ request: JSONValue, result: JSONValue) throws {
        continuation.yield(try JSONValue.object(["id": request["id"], "ok": .bool(true), "result": result]).encodeString())
    }
    func receive() async throws -> String {
        var iterator = frames.makeAsyncIterator()
        guard let frame = try await iterator.next() else { throw PocketError(code: "closed", message: closeReason ?? "closed") }
        return frame
    }
    func close() { continuation.finish() }
    func ping() async throws {}
}
#endif
