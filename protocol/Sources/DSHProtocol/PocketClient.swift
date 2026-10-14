import Foundation

/// Client for the dsh-plugin-pocket protocol v1 over WebSocket text frames.
/// Auth tokens are identical on LAN and Tailscale.
public final class PocketClient: @unchecked Sendable {
    public enum State: String, Sendable {
        case idle, connecting, open, closed
    }

    public let appVersion: String
    public private(set) var state: State = .idle
    public private(set) var closeReason: String?
    public private(set) var route: Route?

    private let lock = NSLock()
    private var nextId: Int64 = 1
    private var pending: [Int64: CheckedContinuation<JSONValue, Error>] = [:]
    private var transport: URLSessionFrameTransport?
    private var generation: Int64 = 0
    private var pump: Task<Void, Never>?
    private var eventHandler: (@Sendable (JSONValue) -> Void)?
    private var stateHandler: (@Sendable (State) -> Void)?

    public init(appVersion: String = VersionCompatibility.minimumAppVersion) {
        self.appVersion = appVersion
    }

    public func setEventHandler(_ handler: (@Sendable (JSONValue) -> Void)?) {
        lock.lock(); eventHandler = handler; lock.unlock()
    }

    public func setStateHandler(_ handler: (@Sendable (State) -> Void)?) {
        lock.lock(); stateHandler = handler; lock.unlock()
    }

    public func connect(url: URL, host: String, auth: Auth, timeoutMs: Int64 = 120_000) async throws -> HelloResult {
        try await connect(urls: [(url, classifyWsRoute(host))], auth: auth, timeoutMs: timeoutMs)
    }

    public func connect(host: String, port: Int, auth: Auth, timeoutMs: Int64 = 120_000) async throws -> HelloResult {
        guard let url = websocketURL(host: host, port: port) else {
            throw PocketError(code: "transport", message: "invalid host:port")
        }
        return try await connect(url: url, host: host, auth: auth, timeoutMs: timeoutMs)
    }

    public func connect(urls: [(URL, Route)], auth: Auth, timeoutMs: Int64 = 120_000) async throws -> HelloResult {
        let attempt = beginConnect()
        do {
            var lastError: Error = PocketError(code: "transport", message: "all transports failed")
            var opened: URLSessionFrameTransport?
            for (url, route) in urls {
                do {
                    opened = try await TransportOpener.open(url: url, route: route, timeoutMs: timeoutMs)
                    break
                } catch {
                    lastError = error
                }
            }
            guard let transport = opened else { throw lastError }
            try attach(transport, attempt: attempt)
            let pair = handshakePayload(auth)
            let result = try await request(pair.op, args: pair.args, timeoutMs: timeoutMs, expectedGeneration: attempt)
            try markOpen(attempt: attempt, transport: transport)
            return HelloResult(raw: result, route: transport.route)
        } catch {
            fail(attempt, error.localizedDescription)
            throw error
        }
    }

    public func call(_ op: String, args: JSONValue = .object([:]), timeoutMs: Int64 = 60_000) async throws -> JSONValue {
        try await request(op, args: args, timeoutMs: timeoutMs, expectedGeneration: nil)
    }

    public func listSessions() async throws -> [SessionSummary] {
        (try await call("sessions.list")["items"].arr() ?? []).compactMap(SessionSummary.parse)
    }

    public func createSession(cwd: String? = nil, agentPreset: String? = nil, workspaceId: String? = nil) async throws -> String {
        let result = try await call("sessions.create", args: jsonObject([
            "cwd": cwd.map { .string($0) },
            "agentPreset": agentPreset.map { .string($0) },
            "workspaceId": workspaceId.map { .string($0) },
        ]))
        guard let id = result["sessionId"].str() else {
            throw PocketError(code: "bad-reply", message: "no sessionId")
        }
        return id
    }

    public func prompt(
        sessionId: String,
        text: String,
        mode: String,
        images: [PromptImage] = [],
        files: [PromptFile] = [],
        requestId: String? = nil
    ) async throws -> JSONValue {
        var args: [String: JSONValue?] = [
            "sessionId": .string(sessionId),
            "text": .string(text),
            "mode": .string(mode),
            "requestId": requestId.map { .string($0) },
        ]
        if !images.isEmpty {
            args["images"] = .array(images.map { image in
                jsonObject([
                    "mediaType": .string(image.mediaType),
                    "data": .string(image.data),
                    "name": image.name.map { .string($0) },
                ])
            })
        }
        if !files.isEmpty {
            args["files"] = .array(files.map { file in
                jsonObject(["receiptId": .string(file.receiptId)])
            })
        }
        return try await call("prompt", args: jsonObject(args))
    }

    public func cancel(sessionId: String) async throws -> JSONValue {
        try await call("cancel", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func follow(sessionId: String, afterSeq: Int64? = nil, maxMessages: Int? = nil) async throws -> String {
        let result = try await call("follow", args: jsonObject([
            "sessionId": .string(sessionId),
            "afterSeq": afterSeq.map { .number(Double($0)) },
            "maxMessages": maxMessages.map { .number(Double($0)) },
        ]))
        return result["subId"].str() ?? ""
    }

    public func unfollow(_ subId: String) async throws {
        _ = try await call("unfollow", args: jsonObject(["subId": .string(subId)]))
    }

    public func historyPage(sessionId: String, throughSeq: Int64, beforeSeq: Int64? = nil, maxMessages: Int = 100) async throws -> JSONValue {
        try await call("history.page", args: jsonObject([
            "sessionId": .string(sessionId),
            "throughSeq": .number(Double(throughSeq)),
            "beforeSeq": beforeSeq.map { .number(Double($0)) },
            "maxMessages": .number(Double(maxMessages)),
        ]))
    }

    public func answerApproval(approvalId: String, outcome: String) async throws {
        _ = try await call("approval.answer", args: jsonObject([
            "approvalId": .string(approvalId),
            "outcome": .string(outcome),
        ]))
    }

    public func modelCatalog() async throws -> ModelCatalog {
        ModelCatalog.parse(try await call("models.catalog"))
    }

    public func selectModel(sessionId: String, provider: String, model: String, effort: String?) async throws {
        _ = try await call("models.select", args: jsonObject([
            "sessionId": .string(sessionId),
            "provider": .string(provider),
            "model": .string(model),
            "reasoningEffort": effort.map { .string($0) },
        ]))
    }

    public func renameSession(sessionId: String, title: String) async throws {
        _ = try await call("sessions.rename", args: jsonObject([
            "sessionId": .string(sessionId),
            "title": .string(title),
        ]))
    }

    public func forkSession(sessionId: String, atSeq: Int64? = nil) async throws -> JSONValue {
        try await call("sessions.fork", args: jsonObject([
            "sessionId": .string(sessionId),
            "atSeq": atSeq.map { .number(Double($0)) },
        ]))
    }

    public func pinSession(_ sessionId: String) async throws {
        _ = try await call("workspace.pinSession", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func unpinSession(_ sessionId: String) async throws {
        _ = try await call("workspace.unpinSession", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func archiveSession(_ sessionId: String) async throws {
        _ = try await call("workspace.archiveSession", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func pluginsList() async throws -> JSONValue { try await call("plugins.list") }
    public func pluginsSetEnabled(enabled: Bool, bundle: String? = nil, id: String? = nil) async throws -> JSONValue {
        try await call("plugins.setEnabled", args: jsonObject([
            "enabled": .bool(enabled),
            "bundle": bundle.map { .string($0) },
            "id": id.map { .string($0) },
        ]))
    }
    public func scheduleList(sessionId: String) async throws -> JSONValue {
        try await call("schedule.list", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func close() {
        lock.lock()
        closeLocked()
        if state != .idle { applyStateLocked(.closed) }
        lock.unlock()
        notifyState(.closed)
    }

    private func handshakePayload(_ auth: Auth) -> (op: String, args: JSONValue) {
        switch auth {
        case .token(let token):
            return ("hello", jsonObject([
                "proto": .number(Double(VersionCompatibility.proto)),
                "token": .string(token),
                "app": .string("dsh-ios"),
                "appVersion": .string(appVersion),
            ]))
        case .pair(let code, let name):
            return ("pair", jsonObject([
                "proto": .number(Double(VersionCompatibility.proto)),
                "code": .string(code),
                "name": .string(name),
                "app": .string("dsh-ios"),
                "appVersion": .string(appVersion),
            ]))
        }
    }

    private func beginConnect() -> Int64 {
        lock.lock()
        closeLocked()
        applyStateLocked(.connecting)
        closeReason = nil
        let generation = self.generation
        lock.unlock()
        notifyState(.connecting)
        return generation
    }

    private func attach(_ transport: URLSessionFrameTransport, attempt: Int64) throws {
        lock.lock()
        defer { lock.unlock() }
        if attempt != generation {
            transport.close()
            throw PocketError(code: "transport", message: "connection superseded")
        }
        self.transport = transport
        route = transport.route
        pump = Task { [weak self] in
            await self?.pumpIncoming(attempt: attempt, transport: transport)
        }
    }

    private func markOpen(attempt: Int64, transport: URLSessionFrameTransport) throws {
        lock.lock()
        if attempt != generation || self.transport !== transport {
            let reason = closeReason ?? "connection superseded"
            lock.unlock()
            throw PocketError(code: "transport", message: reason)
        }
        applyStateLocked(.open)
        route = transport.route
        lock.unlock()
        notifyState(.open)
    }

    private func request(
        _ op: String,
        args: JSONValue,
        timeoutMs: Int64,
        expectedGeneration: Int64?
    ) async throws -> JSONValue {
        let id: Int64
        let transport: URLSessionFrameTransport
        lock.lock()
        if let expectedGeneration, expectedGeneration != generation {
            lock.unlock()
            throw PocketError(code: "transport", message: "connection superseded")
        }
        guard let current = self.transport else {
            lock.unlock()
            throw PocketError(code: "transport", message: "not connected")
        }
        id = nextId
        nextId += 1
        transport = current
        lock.unlock()
        let frame = jsonObject([
            "id": .number(Double(id)),
            "op": .string(op),
            "args": args,
        ])
        do {
            let reply: JSONValue = try await withTimeout(ms: timeoutMs) {
                try await withCheckedThrowingContinuation { continuation in
                    self.lock.lock()
                    self.pending[id] = continuation
                    self.lock.unlock()
                    Task {
                        do {
                            try await transport.send(try frame.encodeString())
                        } catch {
                            self.lock.lock()
                            let waiter = self.pending.removeValue(forKey: id)
                            self.lock.unlock()
                            waiter?.resume(throwing: PocketError(code: "transport", message: error.localizedDescription))
                        }
                    }
                }
            }
            lock.lock()
            pending.removeValue(forKey: id)
            lock.unlock()
            if reply["ok"].bool() == true {
                return reply.obj()?["result"] ?? .null
            }
            throw PocketError(
                code: reply["error"]["code"].str() ?? "error",
                message: reply["error"]["message"].str() ?? "",
                details: reply["error"]["details"].isNull ? nil : reply["error"]["details"]
            )
        } catch {
            lock.lock()
            pending.removeValue(forKey: id)
            lock.unlock()
            throw error
        }
    }

    private func pumpIncoming(attempt: Int64, transport: URLSessionFrameTransport) async {
        do {
            while !Task.isCancelled {
                let text = try await transport.receive()
                let outcome = handleFrame(text, attempt: attempt)
                if outcome.pong {
                    try? await transport.send(#"{"op":"pong"}"#)
                }
                if let event = outcome.event {
                    eventHandler?(event)
                }
            }
        } catch {
            fail(attempt, transport.closeReason ?? error.localizedDescription)
            return
        }
        fail(attempt, transport.closeReason ?? "closed")
    }

    private func handleFrame(_ text: String, attempt: Int64) -> (pong: Bool, event: JSONValue?) {
        lock.lock()
        defer { lock.unlock() }
        if attempt != generation { return (false, nil) }
        guard let parsed = try? JSONValue.parse(text) else { return (false, nil) }
        if let id = parsed["id"].long(), let waiter = pending.removeValue(forKey: id) {
            waiter.resume(returning: parsed)
            return (false, nil)
        }
        if parsed["ev"].str() == "ping" { return (true, nil) }
        if parsed["ev"].isNull { return (false, nil) }
        return (false, parsed)
    }

    private func fail(_ attempt: Int64, _ reason: String) {
        lock.lock()
        if attempt != generation {
            lock.unlock()
            return
        }
        closeReason = reason
        closeLocked()
        applyStateLocked(.closed)
        lock.unlock()
        notifyState(.closed)
    }

    private func closeLocked() {
        generation += 1
        pump?.cancel()
        pump = nil
        transport?.close()
        transport = nil
        route = nil
        let error = PocketError(code: "transport", message: closeReason ?? "connection closed")
        pending.values.forEach { $0.resume(throwing: error) }
        pending.removeAll()
    }

    private func applyStateLocked(_ next: State) {
        state = next
    }

    private func notifyState(_ next: State) {
        stateHandler?(next)
    }
}
