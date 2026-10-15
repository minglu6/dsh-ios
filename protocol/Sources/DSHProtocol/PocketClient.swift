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

    private let mutex = Mutex()
    private var nextId: Int64 = 1
    private var pending: [Int64: CheckedContinuation<JSONValue, Error>] = [:]
    private var transport: FrameTransport?
    private var generation: Int64 = 0
    private var pump: Task<Void, Never>?
    private var eventHandler: (@Sendable (JSONValue) -> Void)?
    private var stateHandler: (@Sendable (State) -> Void)?
    private var eventTaps: [UUID: @Sendable (JSONValue) -> Void] = [:]
    private var stateTaps: [UUID: @Sendable (State) -> Void] = [:]

    var pendingRequestCount: Int { mutex.withLock { pending.count } }

    public init(appVersion: String = VersionCompatibility.minimumAppVersion) {
        self.appVersion = appVersion
    }

    public func setEventHandler(_ handler: (@Sendable (JSONValue) -> Void)?) {
        mutex.withLock { eventHandler = handler }
    }

    public func setStateHandler(_ handler: (@Sendable (State) -> Void)?) {
        mutex.withLock { stateHandler = handler }
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
            var opened: FrameTransport?
            for (url, route) in urls {
                do {
                    opened = try await TransportOpener.open(url: url, route: route, timeoutMs: timeoutMs)
                    break
                } catch {
                    lastError = error
                }
            }
            guard let transport = opened else { throw lastError }
            return try await handshake(transport: transport, auth: auth, timeoutMs: timeoutMs, attempt: attempt)
        } catch {
            fail(attempt, error.localizedDescription)
            throw error
        }
    }

    /// Inject a live transport (tests and non-WebSocket fixtures). Handshake still uses hello/pair.
    public func connect(transport: FrameTransport, auth: Auth, timeoutMs: Int64 = 120_000) async throws -> HelloResult {
        let attempt = beginConnect()
        do {
            return try await handshake(transport: transport, auth: auth, timeoutMs: timeoutMs, attempt: attempt)
        } catch {
            fail(attempt, error.localizedDescription)
            throw error
        }
    }

    private func handshake(transport: FrameTransport, auth: Auth, timeoutMs: Int64, attempt: Int64) async throws -> HelloResult {
        try attach(transport, attempt: attempt)
        let pair = handshakePayload(auth)
        let result = try await request(pair.op, args: pair.args, timeoutMs: timeoutMs, expectedGeneration: attempt)
        try markOpen(attempt: attempt, transport: transport)
        return HelloResult(raw: result, route: transport.route)
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

    /// Session follow. Do not send `maxMessages` / iroh frame caps on the phone WS path.
    public func follow(sessionId: String, afterSeq: Int64? = nil) async throws -> String {
        let result = try await call("follow", args: FollowRequest.args(sessionId: sessionId, afterSeq: afterSeq))
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

    public func workspaceChangesSummary(sessionId: String, seq: Int64) async throws -> JSONValue {
        try await call("workspaceChanges.summary", args: workspaceChangesSummaryArgs(sessionId: sessionId, seq: seq))
    }

    public func workspaceChangesDiff(sessionId: String, seq: Int64, index: Int) async throws -> JSONValue {
        try await call("workspaceChanges.diff", args: workspaceChangesDiffArgs(sessionId: sessionId, seq: seq, index: index))
    }

    public func answerApproval(approvalId: String, outcome: String) async throws -> JSONValue {
        try await call("approval.answer", args: jsonObject([
            "approvalId": .string(approvalId),
            "outcome": .string(outcome),
        ]))
    }

    public func modelCatalog() async throws -> ModelCatalog {
        ModelCatalog.parse(try await call("models.catalog"))
    }

    public func selectModel(sessionId: String, provider: String, model: String, effort: String?) async throws -> JSONValue {
        try await call("models.select", args: jsonObject([
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

    public func getFeedback(sessionId: String) async throws -> JSONValue {
        try await call("feedback.get", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func setFeedback(
        sessionId: String,
        messageId: String,
        rating: String?,
        category: String? = nil,
        note: String? = nil,
        ifVersion: String? = nil
    ) async throws -> JSONValue {
        // jsonObject drops nulls; Host needs an explicit null to clear a rating.
        var object: [String: JSONValue] = [
            "sessionId": .string(sessionId),
            "messageId": .string(messageId),
            "rating": rating.map { .string($0) } ?? .null,
        ]
        if let category { object["category"] = .string(category) }
        if let note { object["note"] = .string(note) }
        if let ifVersion { object["ifVersion"] = .string(ifVersion) }
        return try await call("feedback.set", args: .object(object))
    }

    public func pinSession(_ sessionId: String) async throws {
        _ = try await call("workspace.pinSession", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func unpinSession(_ sessionId: String) async throws {
        _ = try await call("workspace.unpinSession", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func archiveSession(_ sessionId: String, stopActivity: Bool = false) async throws {
        _ = try await call("workspace.archiveSession", args: jsonObject([
            "sessionId": .string(sessionId),
            "stopActivity": stopActivity ? .bool(true) : nil,
        ]))
    }

    public func unarchiveSession(_ sessionId: String) async throws -> JSONValue {
        try await call("workspace.unarchiveSession", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func insertWorkspaceBefore(workspaceId: String, beforeWorkspaceId: String?) async throws -> JSONValue {
        try await call("workspace.insertBefore", args: WorkspaceOrder.insertBeforeArgs(
            workspaceId: workspaceId,
            beforeWorkspaceId: beforeWorkspaceId
        ))
    }

    public func insertSessionBefore(workspaceId: String, sessionId: String, beforeSessionId: String?) async throws -> JSONValue {
        try await call("workspace.insertSessionBefore", args: WorkspaceOrder.insertSessionBeforeArgs(
            workspaceId: workspaceId,
            sessionId: sessionId,
            beforeSessionId: beforeSessionId
        ))
    }

    public func searchSessions(query: String) async throws -> JSONValue {
        try await call("sessions.search", args: SessionSearch.args(query: query))
    }

    public func recordSessionFeedback(sessionId: String, category: String?, note: String) async throws -> JSONValue {
        try await call("sessionFeedback.record", args: SessionFeedbackRequest.args(
            sessionId: sessionId,
            category: category,
            note: note
        ))
    }

    public func presetsList() async throws -> JSONValue { try await call("presets.list") }

    public func presetsSettings() async throws -> JSONValue { try await call("presets.settings") }

    public func readPreset(id: String) async throws -> JSONValue {
        try await call("presets.read", args: jsonObject(["id": .string(id)]))
    }

    public func modelsProviders() async throws -> JSONValue { try await call("models.providers") }
    public func modelsProviderGet(provider: String) async throws -> JSONValue {
        try await call("models.providerGet", args: jsonObject(["provider": .string(provider)]))
    }
    public func modelsSettingsMutate(ns: String, ops: JSONValue, expectedRevision: Int64? = nil) async throws -> JSONValue {
        try await call("models.settingsMutate", args: jsonObject([
            "ns": .string(ns),
            "ops": ops,
            "expectedRevision": expectedRevision.map { .number(Double($0)) },
        ]))
    }
    public func modelsDiscover(settingsNs: String, request: JSONValue = .object([:])) async throws -> JSONValue {
        try await call("models.discover", args: jsonObject([
            "settingsNs": .string(settingsNs),
            "request": request,
        ]))
    }

    public func pluginsList() async throws -> JSONValue { try await call("plugins.list") }
    public func pluginsInventory() async throws -> JSONValue { try await call("plugins.inventory") }
    public func pluginsSetEnabled(enabled: Bool, bundle: String? = nil, id: String? = nil) async throws -> JSONValue {
        try await call("plugins.setEnabled", args: jsonObject([
            "enabled": .bool(enabled),
            "bundle": bundle.map { .string($0) },
            "id": id.map { .string($0) },
        ]))
    }
    public func pluginsInstall(spec: String, options: JSONValue? = nil) async throws -> JSONValue {
        try await call("plugins.install", args: jsonObject([
            "spec": .string(spec),
            "options": options,
        ]), timeoutMs: 1_800_000)
    }
    public func pluginsInspect(spec: String, registry: String? = nil) async throws -> JSONValue {
        try await call("plugins.inspect", args: jsonObject([
            "spec": .string(spec),
            "options": registry.map { jsonObject(["registry": .string($0)]) },
        ]))
    }
    public func pluginsRegistries() async throws -> JSONValue { try await call("plugins.registries") }
    public func pluginsUninstall(bundle: String) async throws -> JSONValue {
        try await call("plugins.uninstall", args: jsonObject(["bundle": .string(bundle)]), timeoutMs: 1_800_000)
    }
    public func pluginsCancelInstall(requestId: String) async throws -> JSONValue {
        try await call("plugins.cancelInstall", args: jsonObject(["requestId": .string(requestId)]), timeoutMs: 120_000)
    }
    public func pluginsWaitForInstall(requestId: String) async throws -> JSONValue {
        try await call("plugins.waitForInstall", args: jsonObject(["requestId": .string(requestId)]), timeoutMs: 1_800_000)
    }
    public func pluginsSettingsDescribe() async throws -> JSONValue { try await call("plugins.settingsDescribe") }
    public func pluginsSettingsMutate(ns: String, ops: JSONValue, expectedRevision: Int) async throws -> JSONValue {
        try await call("plugins.settingsMutate", args: jsonObject([
            "ns": .string(ns),
            "ops": ops,
            "expectedRevision": .number(Double(expectedRevision)),
        ]))
    }

    public func scheduleCatalog() async throws -> JSONValue { try await call("schedule.catalog") }
    public func scheduleList(sessionId: String) async throws -> JSONValue {
        try await call("schedule.list", args: jsonObject(["sessionId": .string(sessionId)]))
    }
    public func scheduleCreate(args: JSONValue) async throws -> JSONValue {
        try await call("schedule.create", args: args)
    }
    public func scheduleUpdate(args: JSONValue) async throws -> JSONValue {
        try await call("schedule.update", args: args)
    }
    public func scheduleDelete(sessionId: String, id: String) async throws -> JSONValue {
        try await call("schedule.delete", args: jsonObject([
            "sessionId": .string(sessionId),
            "id": .string(id),
        ]))
    }
    public func scheduleHistory(sessionId: String, id: String, limit: Int = 20, before: String? = nil) async throws -> JSONValue {
        try await call("schedule.history", args: jsonObject([
            "sessionId": .string(sessionId),
            "id": .string(id),
            "limit": .number(Double(limit)),
            "before": before.map { .string($0) },
        ]))
    }

    public func credentialsDescribe(ref: String) async throws -> JSONValue {
        try await call("credentials.describe", args: jsonObject(["ref": .string(ref)]))
    }
    public func credentialsSet(ref: String, value: String) async throws -> JSONValue {
        try await call("credentials.set", args: jsonObject(["ref": .string(ref), "value": .string(value)]))
    }
    public func credentialsUnset(ref: String) async throws -> JSONValue {
        try await call("credentials.unset", args: jsonObject(["ref": .string(ref)]))
    }

    public func uiOpen(section: String? = nil) async throws -> JSONValue {
        try await call("ui.open", args: jsonObject(["section": section.map { .string($0) }]))
    }

    public func uiClose(ticket: String) async throws -> JSONValue {
        try await call("ui.close", args: jsonObject(["ticket": .string(ticket)]), timeoutMs: 5_000)
    }

    public func permissionsCatalog() async throws -> PermissionCatalog {
        try PermissionCatalog.parse(try await call("permissions.catalog"))
    }

    public func permission(sessionId: String) async throws -> String {
        try PermissionSelection.parse(try await call("permissions.get", args: jsonObject([
            "sessionId": .string(sessionId),
        ]))).currentValue
    }

    public func setPermission(sessionId: String, name: String) async throws -> String {
        try PermissionSelection.parse(try await call("permissions.set", args: jsonObject([
            "sessionId": .string(sessionId),
            "name": .string(name),
        ]))).currentValue
    }

    public func updateQueuedPrompt(sessionId: String, itemId: String, action: QueueAction) async throws -> JSONValue {
        try await call("queue.update", args: queueUpdateArgs(sessionId: sessionId, itemId: itemId, action: action))
    }

    public func listCommands(sessionId: String) async throws -> [JSONValue] {
        try await call("commands.list", args: jsonObject(["sessionId": .string(sessionId)]))["commands"].arr() ?? []
    }

    public func executeCommand(sessionId: String, line: String) async throws -> JSONValue {
        try await call("commands.execute", args: jsonObject([
            "sessionId": .string(sessionId),
            "line": .string(line),
        ]))
    }

    public func exportSession(sessionId: String, includeDescendants: Bool = true) async throws -> JSONValue {
        try await call("session.export", args: jsonObject([
            "sessionId": .string(sessionId),
            "includeDescendants": .bool(includeDescendants),
        ]), timeoutMs: 180_000)
    }

    public func uploadAttachment(sessionId: String, data: String, name: String? = nil) async throws -> JSONValue {
        try await call("attachments.upload", args: jsonObject([
            "sessionId": .string(sessionId),
            "data": .string(data),
            "name": name.map { .string($0) },
        ]))
    }

    public func sessionAttachment(sessionId: String, attachmentId: String) async throws -> JSONValue {
        try await call("session.attachment", args: SessionAttachment.args(
            sessionId: sessionId,
            attachmentId: attachmentId
        ))
    }

    public func answerUserQuestion(sessionId: String, callId: String, answers: [JSONValue]) async throws -> JSONValue {
        try await call("userQuestions.answer", args: userQuestionAnswerArgs(sessionId: sessionId, callId: callId, answers: answers))
    }

    public func getGoal(sessionId: String) async throws -> JSONValue {
        try await call("goals.get", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func mutateGoal(sessionId: String, action: String, ref: JSONValue, objective: String? = nil) async throws -> JSONValue {
        try await call("goals.\(action)", args: goalMutationArgs(sessionId: sessionId, ref: ref, objective: objective))
    }

    public func referenceFiles(sessionId: String, query: String = "") async throws -> JSONValue {
        try await call("references.files", args: jsonObject([
            "sessionId": .string(sessionId),
            "query": .string(query),
        ]))
    }

    public func referenceSessions(sessionId: String, query: String = "") async throws -> JSONValue {
        try await call("references.sessions", args: jsonObject([
            "sessionId": .string(sessionId),
            "query": .string(query),
        ]))
    }

    public func listFiles(sessionId: String, path: String = ".") async throws -> JSONValue {
        try await call("files.list", args: jsonObject([
            "sessionId": .string(sessionId),
            "path": .string(path),
        ]))
    }

    public func readFile(sessionId: String, path: String, offset: Int? = nil, limit: Int? = nil) async throws -> JSONValue {
        var args: [String: JSONValue?] = [
            "sessionId": .string(sessionId),
            "path": .string(path),
        ]
        if offset != nil || limit != nil {
            args["range"] = jsonObject([
                "offset": offset.map { .number(Double($0)) },
                "limit": limit.map { .number(Double($0)) },
            ])
        }
        return try await call("files.read", args: jsonObject(args))
    }

    public func readFileBytes(sessionId: String, path: String, offset: Int? = nil, length: Int? = nil) async throws -> JSONValue {
        var args: [String: JSONValue?] = [
            "sessionId": .string(sessionId),
            "path": .string(path),
        ]
        if let offset, let length {
            args["options"] = jsonObject([
                "range": jsonObject([
                    "offset": .number(Double(offset)),
                    "length": .number(Double(length)),
                ]),
            ])
        }
        return try await call("files.readBytes", args: jsonObject(args))
    }

    /// A bounded invalidation stream, detached even if cancellation races its opening reply.
    public func followFiles(sessionId: String, path: String = ".") -> AsyncThrowingStream<JSONValue, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    try await self.runFollowFiles(sessionId: sessionId, path: path, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One connection-bound Office lease. Cancellation releases even a render whose reply never arrived.
    public func withOfficePreview<T>(
        sessionId: String,
        path: String,
        _ block: (OfficePreviewReader) async throws -> T
    ) async throws -> T {
        let handle = "o-\(UUID().uuidString.lowercased())"
        let attempt = mutex.withLock { generation }
        do {
            let metadata = try await request(
                "office.render",
                args: jsonObject([
                    "sessionId": .string(sessionId),
                    "path": .string(path),
                    "subId": .string(handle),
                ]),
                timeoutMs: 610_000,
                expectedGeneration: attempt
            )
            guard metadata["handle"].str() == handle else {
                throw PocketError(code: "document-render/failed", message: "Invalid Office handle")
            }
            let reader = OfficePreviewReader(
                sessionId: sessionId,
                handle: handle,
                attempt: attempt,
                metadata: metadata
            ) { [weak self] offset, length in
                guard let self else {
                    throw PocketError(code: "transport", message: "not connected")
                }
                return try await self.request(
                    "office.read",
                    args: jsonObject([
                        "sessionId": .string(sessionId),
                        "handle": .string(handle),
                        "offset": .number(Double(offset)),
                        "length": .number(Double(length)),
                        "version": metadata["version"].str().map { .string($0) },
                        "generation": metadata["generation"].str().map { .string($0) },
                    ]),
                    timeoutMs: 60_000,
                    expectedGeneration: attempt
                )
            }
            let result = try await block(reader)
            await releaseOffice(sessionId: sessionId, handle: handle, attempt: attempt)
            return result
        } catch {
            await releaseOffice(sessionId: sessionId, handle: handle, attempt: attempt)
            throw error
        }
    }

    public func listTerminals(sessionId: String) async throws -> JSONValue {
        try await call("terminal.list", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func createTerminal(sessionId: String, cols: Int = 80, rows: Int = 24, id: String? = nil) async throws -> JSONValue {
        try await call("terminal.create", args: jsonObject([
            "sessionId": .string(sessionId),
            "cols": .number(Double(cols)),
            "rows": .number(Double(rows)),
            "id": id.map { .string($0) },
        ]))
    }

    public func followTerminal(sessionId: String, id: String, attachmentId: String? = nil) async throws -> JSONValue {
        try await call("terminal.follow", args: jsonObject([
            "sessionId": .string(sessionId),
            "id": .string(id),
            "attachmentId": attachmentId.map { .string($0) },
        ]))
    }

    public func writeTerminal(sessionId: String, id: String, attachmentId: String, data: String) async throws -> JSONValue {
        try await call("terminal.write", args: jsonObject([
            "sessionId": .string(sessionId),
            "id": .string(id),
            "attachmentId": .string(attachmentId),
            "data": .string(data),
        ]))
    }

    public func resizeTerminal(sessionId: String, id: String, attachmentId: String, cols: Int, rows: Int) async throws -> JSONValue {
        try await call("terminal.resize", args: jsonObject([
            "sessionId": .string(sessionId),
            "id": .string(id),
            "attachmentId": .string(attachmentId),
            "cols": .number(Double(cols)),
            "rows": .number(Double(rows)),
        ]))
    }

    public func closeTerminal(sessionId: String, id: String) async throws -> JSONValue {
        try await call("terminal.close", args: jsonObject([
            "sessionId": .string(sessionId),
            "id": .string(id),
        ]))
    }

    public func listJobs(sessionId: String) async throws -> JSONValue {
        try await call("jobs.list", args: jsonObject(["sessionId": .string(sessionId)]))
    }

    public func killJob(sessionId: String, jobId: String) async throws -> JSONValue {
        try await call("jobs.kill", args: jsonObject([
            "sessionId": .string(sessionId),
            "jobId": .string(jobId),
        ]))
    }

    public func followJob(sessionId: String, jobId: String, from: Int64? = nil) async throws -> String {
        let result = try await call("jobs.follow", args: JobFollowRequest.args(sessionId: sessionId, jobId: jobId, from: from))
        guard let subId = result["subId"].str(), !subId.isEmpty else {
            throw PocketError(code: "bad-reply", message: "missing job subscription")
        }
        return subId
    }

    public func createWorkspace(path: String) async throws -> JSONValue {
        try await call("workspace.create", args: jsonObject(["path": .string(path)]))
    }

    public func renameWorkspace(workspaceId: String, title: String) async throws -> JSONValue {
        try await call("workspace.rename", args: jsonObject([
            "workspaceId": .string(workspaceId),
            "title": .string(title),
        ]))
    }

    public func deleteWorkspace(workspaceId: String) async throws -> JSONValue {
        try await call("workspace.delete", args: jsonObject(["workspaceId": .string(workspaceId)]))
    }

    public func directoryList(path: String? = nil) async throws -> JSONValue {
        try await call("workspace.directoryList", args: jsonObject(["path": path.map { .string($0) }]))
    }

    public func directoryCreate(path: String, name: String) async throws -> JSONValue {
        try await call("workspace.directoryCreate", args: jsonObject([
            "path": .string(path),
            "name": .string(name),
        ]))
    }

    public func close() {
        mutex.withLock {
            closeLocked()
            if state != .idle { applyStateLocked(.closed) }
        }
        notifyState(.closed)
    }

    /// WebSocket ping. Keeps a background socket from going idle during `beginBackgroundTask`.
    public func ping(timeoutMs: Int64 = BackgroundKeepAlivePolicy.pingTimeoutMs) async throws {
        let transport: FrameTransport = try mutex.withLock {
            guard state == .open, let current = self.transport else {
                throw PocketError(code: "transport", message: "not connected")
            }
            return current
        }
        try await withTimeout(ms: timeoutMs) {
            try await transport.ping()
        }
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
        let generation: Int64 = mutex.withLock {
            closeLocked()
            applyStateLocked(.connecting)
            closeReason = nil
            return self.generation
        }
        notifyState(.connecting)
        return generation
    }

    private func attach(_ transport: FrameTransport, attempt: Int64) throws {
        try mutex.withLock {
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
    }

    private func markOpen(attempt: Int64, transport: FrameTransport) throws {
        try mutex.withLock {
            if attempt != generation || self.transport !== transport {
                throw PocketError(code: "transport", message: closeReason ?? "connection superseded")
            }
            applyStateLocked(.open)
            route = transport.route
        }
        notifyState(.open)
    }

    private func request(
        _ op: String,
        args: JSONValue,
        timeoutMs: Int64,
        expectedGeneration: Int64?
    ) async throws -> JSONValue {
        let prepared: (id: Int64, transport: FrameTransport) = try mutex.withLock {
            if let expectedGeneration, expectedGeneration != generation {
                throw PocketError(code: "transport", message: "connection superseded")
            }
            guard let current = self.transport else {
                throw PocketError(code: "transport", message: "not connected")
            }
            let id = nextId
            nextId += 1
            return (id, current)
        }
        let id = prepared.id
        let transport = prepared.transport
        let frame = jsonObject([
            "id": .number(Double(id)),
            "op": .string(op),
            "args": args,
        ])
        do {
            let reply: JSONValue = try await withTaskCancellationHandler {
                try await withTimeout(ms: timeoutMs) {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<JSONValue, Error>) in
                        self.mutex.withLock { self.pending[id] = continuation }
                        Task {
                            do {
                                try await transport.send(try frame.encodeString())
                            } catch {
                                let waiter = self.mutex.withLock { self.pending.removeValue(forKey: id) }
                                waiter?.resume(throwing: PocketError(code: "transport", message: error.localizedDescription))
                            }
                        }
                    }
                }
            } onCancel: {
                let waiter = self.mutex.withLock { self.pending.removeValue(forKey: id) }
                waiter?.resume(throwing: CancellationError())
            }
            mutex.withLock { pending.removeValue(forKey: id) }
            if reply["ok"].bool() == true {
                return reply.obj()?["result"] ?? .null
            }
            throw PocketError(
                code: reply["error"]["code"].str() ?? "error",
                message: reply["error"]["message"].str() ?? "",
                details: reply["error"]["details"].isNull ? nil : reply["error"]["details"]
            )
        } catch {
            mutex.withLock { pending.removeValue(forKey: id) }
            throw error
        }
    }

    private func pumpIncoming(attempt: Int64, transport: FrameTransport) async {
        do {
            while !Task.isCancelled {
                let text = try await transport.receive()
                let outcome = handleFrame(text, attempt: attempt)
                if outcome.pong {
                    try? await transport.send(#"{"op":"pong"}"#)
                }
                if let event = outcome.event {
                    let taps: [@Sendable (JSONValue) -> Void] = mutex.withLock {
                        var handlers = Array(eventTaps.values)
                        if let eventHandler { handlers.append(eventHandler) }
                        return handlers
                    }
                    for tap in taps { tap(event) }
                }
            }
        } catch {
            fail(attempt, transport.closeReason ?? error.localizedDescription)
            return
        }
        fail(attempt, transport.closeReason ?? "closed")
    }

    private func handleFrame(_ text: String, attempt: Int64) -> (pong: Bool, event: JSONValue?) {
        enum Outcome {
            case ignore
            case reply(CheckedContinuation<JSONValue, Error>, JSONValue)
            case pong
            case event(JSONValue)
        }
        let outcome: Outcome = mutex.withLock {
            if attempt != generation { return .ignore }
            guard let parsed = try? JSONValue.parse(text) else { return .ignore }
            if let id = parsed["id"].long(), let waiter = pending.removeValue(forKey: id) {
                return .reply(waiter, parsed)
            }
            if parsed["ev"].str() == "ping" { return .pong }
            if parsed["ev"].isNull { return .ignore }
            return .event(parsed)
        }
        switch outcome {
        case .ignore:
            return (false, nil)
        case .reply(let waiter, let parsed):
            waiter.resume(returning: parsed)
            return (false, nil)
        case .pong:
            return (true, nil)
        case .event(let parsed):
            return (false, parsed)
        }
    }

    private func fail(_ attempt: Int64, _ reason: String) {
        let shouldNotify = mutex.withLock { () -> Bool in
            if attempt != generation { return false }
            closeReason = reason
            closeLocked()
            applyStateLocked(.closed)
            return true
        }
        if shouldNotify { notifyState(.closed) }
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
        let taps: [@Sendable (State) -> Void] = mutex.withLock {
            var handlers = Array(stateTaps.values)
            if let stateHandler { handlers.append(stateHandler) }
            return handlers
        }
        for tap in taps { tap(next) }
    }

    private func addEventTap(_ handler: @escaping @Sendable (JSONValue) -> Void) -> UUID {
        let id = UUID()
        mutex.withLock { eventTaps[id] = handler }
        return id
    }

    private func removeEventTap(_ id: UUID) {
        mutex.withLock { eventTaps.removeValue(forKey: id) }
    }

    private func addStateTap(_ handler: @escaping @Sendable (State) -> Void) -> UUID {
        let id = UUID()
        mutex.withLock { stateTaps[id] = handler }
        return id
    }

    private func removeStateTap(_ id: UUID) {
        mutex.withLock { stateTaps.removeValue(forKey: id) }
    }

    private func releaseOffice(sessionId: String, handle: String, attempt: Int64) async {
        _ = try? await request(
            "office.release",
            args: jsonObject([
                "sessionId": .string(sessionId),
                "handle": .string(handle),
            ]),
            timeoutMs: 5_000,
            expectedGeneration: attempt
        )
    }

    private func runFollowFiles(
        sessionId: String,
        path: String,
        continuation: AsyncThrowingStream<JSONValue, Error>.Continuation
    ) async throws {
        let subscription = "f-\(UUID().uuidString.lowercased())"
        let attempt = mutex.withLock { generation }
        let inbox = ConflatedInbox()
        let eventTap = addEventTap { event in
            if event["subId"].str() == subscription, event["ev"].str()?.hasPrefix("files") == true {
                inbox.send(event)
            }
        }
        let stateTap = addStateTap { [weak self] state in
            if state == .closed {
                inbox.fail(PocketError(code: "transport", message: self?.closeReason ?? "connection closed"))
            }
        }
        defer {
            removeEventTap(eventTap)
            removeStateTap(stateTap)
        }
        do {
            _ = try await request(
                "files.follow",
                args: jsonObject([
                    "sessionId": .string(sessionId),
                    "path": .string(path),
                    "subId": .string(subscription),
                ]),
                timeoutMs: 60_000,
                expectedGeneration: attempt
            )
            while let event = try await inbox.next() {
                switch event["ev"].str() {
                case "files":
                    if let frame = event["frame"].obj() {
                        continuation.yield(.object(frame))
                    }
                case "files.end":
                    throw PocketError(code: "workspace-file/watch-ended", message: "directory watch ended")
                case "files.error":
                    throw PocketError(
                        code: event["error"]["code"].str() ?? "internal",
                        message: event["error"]["message"].str() ?? "directory watch failed"
                    )
                default:
                    break
                }
            }
        } catch {
            _ = try? await request(
                "unfollow",
                args: jsonObject(["subId": .string(subscription)]),
                timeoutMs: 5_000,
                expectedGeneration: attempt
            )
            throw error
        }
        _ = try? await request(
            "unfollow",
            args: jsonObject(["subId": .string(subscription)]),
            timeoutMs: 5_000,
            expectedGeneration: attempt
        )
    }
}

private final class ConflatedInbox: @unchecked Sendable {
    private let mutex = Mutex()
    private var latest: JSONValue?
    private var waiter: CheckedContinuation<JSONValue?, Error>?
    private var failure: Error?
    private var finished = false

    func send(_ value: JSONValue) {
        mutex.withLock {
            if finished { return }
            if let waiter {
                self.waiter = nil
                waiter.resume(returning: value)
            } else {
                latest = value
            }
        }
    }

    func fail(_ error: Error) {
        mutex.withLock {
            if finished { return }
            finished = true
            failure = error
            latest = nil
            if let waiter {
                self.waiter = nil
                waiter.resume(throwing: error)
            }
        }
    }

    func next() async throws -> JSONValue? {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                mutex.withLock {
                    if let failure {
                        continuation.resume(throwing: failure)
                    } else if let latest {
                        self.latest = nil
                        continuation.resume(returning: latest)
                    } else if finished {
                        continuation.resume(returning: nil)
                    } else {
                        waiter = continuation
                    }
                }
            }
        } onCancel: {
            mutex.withLock {
                waiter?.resume(throwing: CancellationError())
                waiter = nil
            }
        }
    }
}
