import Foundation
import DSHProtocol

enum HistoryPagingScreen {
    case chat
    case trajectory
    case inspector
}

extension AppModel {
    func installUITestHistoryPaging(screen: HistoryPagingScreen) {
        guard uiTestFixture, let sessionId = chat?.sessionId else { return }
        showDrawer = false
        routeStack = []
        uiTestHistoryPagingStatus = "connecting"
        let failFirst = ProcessInfo.processInfo.arguments.contains("-UITestHistoryFailFirst")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let transport = HistoryPagingTransport(sessionId: sessionId, failFirst: failFirst) { [weak self] status in
                Task { @MainActor in self?.uiTestHistoryPagingStatus = status }
            }
            let client = PocketClient()
            do {
                _ = try await client.connect(transport: transport, auth: .token("synthetic-history-fixture"))
                guard self.uiTestFixture, self.chat?.sessionId == sessionId else {
                    client.close()
                    return
                }
                self.installUITestHistoryPagingClient(client, snapshot: .object([
                    "type": .string("snapshot"),
                    "cursor": .number(23),
                    "hasMore": .bool(true),
                    "records": .array(HistoryPagingTransport.records(21...23)),
                    "projections": .object([:]),
                ]))
                self.uiTestHistoryPagingStatus = "requests=0;responses=0;failures=0"
                if screen == .inspector { self.push(.panel(.inspector)) }
                // Trajectory is selected by the test through its real tab control.
            } catch {
                self.uiTestHistoryPagingStatus = "setup-error: \(error.localizedDescription)"
            }
        }
    }
}

/// An in-process Host speaking the actual PocketClient wire protocol. All records
/// are synthetic; cursor validation makes a repeated/incorrect request observable.
private final class HistoryPagingTransport: FrameTransport, @unchecked Sendable {
    let route = Route.wsLocal
    let endpointURL: URL? = nil
    var closeReason: String? { "Synthetic history transport closed" }
    private let sessionId: String
    private let failFirst: Bool
    private let report: @Sendable (String) -> Void
    private let lock = NSLock()
    private var frames: [String] = []
    private var waiter: CheckedContinuation<String, Error>?
    private var closed = false
    private var requests = 0
    private var responses = 0
    private var failures = 0
    private var expectedBefore = 21

    init(sessionId: String, failFirst: Bool, report: @escaping @Sendable (String) -> Void) {
        self.sessionId = sessionId
        self.failFirst = failFirst
        self.report = report
    }

    static func records(_ range: ClosedRange<Int>) -> [JSONValue] {
        range.map { seq in
            .object([
                "type": .string("event"),
                "event": .object([
                    "seq": .number(Double(seq)),
                    "time": .number(1_700_000_000_000 + Double(seq * 1_000)),
                    "type": .string("user/message"),
                    "data": .object([
                        "id": .string("history-message-\(seq)"),
                        "role": .string("user"),
                        "source": .object(["kind": .string("user")]),
                        "content": .array([.object([
                            "type": .string("text"),
                            "text": .string("History record \(seq) — synthetic retained content"),
                        ])]),
                    ]),
                ]),
            ])
        }
    }

    func send(_ text: String) async throws {
        let request = try JSONValue.parse(text)
        if request["op"].str() == "hello" {
            try enqueue(.object(["id": request["id"], "ok": .bool(true), "result": .object(["proto": .number(1)])]))
            return
        }
        guard request["op"].str() == "history.page" else {
            try enqueue(error(request, message: "Unexpected fixture operation"))
            return
        }
        let (valid, shouldFail) = beginRequest(request)
        // Keep the real request pending long enough to exercise refresh lifetime.
        try await Task.sleep(nanoseconds: 600_000_000)
        if !valid || shouldFail {
            finishRequest(success: false)
            try enqueue(error(request, message: shouldFail ? "Synthetic history temporary failure" : "History cursor/session mismatch or request after end"))
        } else {
            let first = request["args"]["beforeSeq"].int() == 21 ? 11 : 1
            finishRequest(success: true)
            try enqueue(.object([
                "id": request["id"], "ok": .bool(true),
                "result": .object([
                    "records": .array(Self.records(first...(first + 2))),
                    "hasMore": .bool(first != 1),
                ]),
            ]))
        }
    }

    private func beginRequest(_ request: JSONValue) -> (Bool, Bool) {
        lock.lock()
        requests += 1
        let args = request["args"]
        let valid = expectedBefore > 1 && args["sessionId"].str() == sessionId
            && args["beforeSeq"].int() == expectedBefore && args["throughSeq"].int() == 23
            && args["maxMessages"].int() == HistoryPagingPolicy.pageSize
        let shouldFail = failFirst && requests == 1
        let status = statusLocked()
        lock.unlock()
        report(status)
        return (valid, shouldFail)
    }

    private func finishRequest(success: Bool) {
        lock.lock()
        if success {
            responses += 1
            expectedBefore = expectedBefore == 21 ? 11 : 1
        } else {
            failures += 1
        }
        let status = statusLocked()
        lock.unlock()
        report(status)
    }

    private func statusLocked() -> String {
        "requests=\(requests);responses=\(responses);failures=\(failures)"
    }

    private func error(_ request: JSONValue, message: String) -> JSONValue {
        .object([
            "id": request["id"], "ok": .bool(false),
            "error": .object(["code": .string("fixture"), "message": .string(message)]),
        ])
    }

    func ping() async throws {}

    func receive() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if !frames.isEmpty {
                let frame = frames.removeFirst()
                lock.unlock()
                continuation.resume(returning: frame)
            } else if closed {
                lock.unlock()
                continuation.resume(throwing: PocketError(code: "transport", message: closeReason ?? "closed"))
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }

    func close() {
        lock.lock()
        closed = true
        let pending = waiter
        waiter = nil
        lock.unlock()
        pending?.resume(throwing: PocketError(code: "transport", message: closeReason ?? "closed"))
    }

    private func enqueue(_ frame: JSONValue) throws {
        let text = try frame.encodeString()
        lock.lock()
        if let waiter {
            self.waiter = nil
            lock.unlock()
            waiter.resume(returning: text)
        } else {
            frames.append(text)
            lock.unlock()
        }
    }
}
