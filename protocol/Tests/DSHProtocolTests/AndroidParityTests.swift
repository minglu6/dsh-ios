import XCTest
@testable import DSHProtocol

final class AndroidParityTests: XCTestCase {
    private func json(_ text: String) throws -> JSONValue { try JSONValue.parse(text) }

    func testCommandMenuInjectsExportAndFeedbackWithoutCollidingHostRows() throws {
        let host = [
            try json(#"{"name":"feedback","definitionId":"@deepseek-ai/dsh-command-feedback"}"#),
            try json(#"{"name":"deploy"}"#),
        ]
        let injected = commandMenuClientRows(
            ops: ["attachments.upload", "models.catalog", "session.export", "sessionFeedback.record"],
            sessionReady: true,
            subagent: false
        )
        let merged = commandMenuMerge(host: host, injected: injected)
        XCTAssertEqual(
            merged.compactMap { $0["name"].str() },
            ["feedback", "deploy", "file", "model", "export"]
        )
        XCTAssertEqual(
            commandMenuRows(merged, query: "", leading: true).compactMap { $0["name"].str() },
            ["file", "feedback", "model", "export", "deploy"]
        )
        XCTAssertTrue(commandMenuClientRows(ops: ["session.export"], sessionReady: false, subagent: false).isEmpty)
        XCTAssertEqual(
            commandContributionCollisionMessage("plan", english: false),
            "指令贡献 /plan 与远程主机指令冲突"
        )
        XCTAssertEqual(
            commandContributionCollisionMessage("plan", english: true),
            "Command contribution /plan collides with a host command"
        )
    }

    func testCommandMenuEmptyQueryUsesDesktopSections() throws {
        let rows = try (["deploy", "export", "feedback", "compact", "goal", "plan", "permission", "other"].map {
            try json(#"{"name":"\#($0)"}"#)
        }) + [
            try json(#"{"name":"file","client":"file"}"#),
            try json(#"{"name":"model","client":"model"}"#),
        ]
        XCTAssertEqual(
            commandMenuRows(rows, query: "", leading: true).compactMap { $0["name"].str() },
            ["file", "goal", "plan", "feedback", "compact", "permission", "model", "export", "deploy", "other"]
        )
    }

    func testCommandMenuInlineFiltersHintsAndRenamedBuiltins() throws {
        let rows = [
            try json(#"{"name":"team-plan","definitionId":"@deepseek-ai/dsh-plan-mode"}"#),
            try json(#"{"name":"goal","input":{"hint":"objective"}}"#),
            try json(#"{"name":"compact"}"#),
            try json(#"{"name":"custom","input":{}}"#),
        ]
        XCTAssertEqual(
            commandMenuRows(rows, query: "", leading: false).compactMap { $0["name"].str() },
            ["compact", "team-plan", "custom"]
        )
        XCTAssertEqual(commandMenuLabel(rows[0], english: false), "计划")
    }

    func testCommandMenuSearchRanksNamesAndLocalizedLabels() throws {
        let rows = [
            try json(#"{"name":"unrelated","description":"compact"}"#),
            try json(#"{"name":"team-compact"}"#),
            try json(#"{"name":"compact-now"}"#),
            try json(#"{"name":"compress","definitionId":"@deepseek-ai/dsh-command-compact"}"#),
        ]
        XCTAssertEqual(
            commandMenuRows(rows, query: "compact", leading: true).compactMap { $0["name"].str() },
            ["compact-now", "team-compact"]
        )
        XCTAssertEqual(
            commandMenuRows(rows, query: "cmpct", leading: true).compactMap { $0["name"].str() },
            ["compact-now", "team-compact"]
        )
        XCTAssertEqual(
            commandMenuRows(rows, query: "压缩", leading: true, english: false).compactMap { $0["name"].str() },
            ["compress"]
        )
    }

    func testSkillMenuParsesHostListAndRanksLikeDesktop() throws {
        let payload = try json("""
        {"skills":[
            {"name":"agent-browser","description":"Drive a browser","modelInvocable":true},
            {"name":"local-notes","description":"Private notes","invocation":{"modelInvocable":false}},
            {"name":"","description":"ignored"}
        ]}
        """)
        let skills = (payload["skills"].arr() ?? []).compactMap(SkillEntry.parse)
        XCTAssertEqual(skills.map(\.name), ["agent-browser", "local-notes"])
        XCTAssertTrue(skills[0].modelInvocable)
        XCTAssertEqual(skills[0].menuDescription(english: false), "Drive a browser")
        XCTAssertFalse(skills[1].modelInvocable)
        XCTAssertEqual(skills[1].menuDescription(english: false), "仅用户 · Private notes")
        XCTAssertEqual(skills[1].menuDescription(english: true), "user-only · Private notes")
        XCTAssertEqual(skillMenuRows(skills, query: "agent").map(\.name), ["agent-browser"])
        XCTAssertEqual(skillMenuRows(skills, query: "").map(\.name), ["agent-browser", "local-notes"])
    }

    func testSlimSessionAddedEventParsesTitleFromProjections() throws {
        let added = try json("""
        {"ev":"session","kind":"added","summary":{
            "sessionId":"session-desktop-new",
            "updatedAt":1710000000000,
            "running":false,
            "blank":true,
            "cwd":"/Users/luming/project",
            "origin":"user",
            "projections":{"values":{"title":"写入 parity 测试文件"}}
        }}
        """)
        let summary = try XCTUnwrap(SessionSummary.parse(added["summary"]))
        XCTAssertEqual(summary.sessionId, "session-desktop-new")
        XCTAssertEqual(summary.title, "写入 parity 测试文件")
        XCTAssertEqual(summary.cwd, "/Users/luming/project")
        XCTAssertTrue(summary.blank)
    }

    func testOfficePreviewWritesAllPagesOnce() async throws {
        let bytes = Data((0..<(128 * 1024 * 3 + 7)).map { UInt8($0 % 251) })
        let metadata = jsonObject([
            "bytes": .number(Double(bytes.count)),
            "absolutePath": .string("/project/a.docx"),
            "version": .string("v1"),
            "generation": .string("g1"),
            "chunkBytes": .number(Double(128 * 1024)),
            "missingFonts": .array([.string("Aptos")]),
        ])
        var offsets: [Int64] = []
        let directory = FileManager.default.temporaryDirectory
        let download = try await downloadOfficePreview(metadata: metadata, cacheDirectory: directory) { offset, length in
            offsets.append(offset)
            let start = Int(offset)
            let end = min(bytes.count, start + length)
            let slice = bytes.subdata(in: start..<end)
            return jsonObject([
                "bytes": .number(Double(bytes.count)),
                "absolutePath": .string("/project/a.docx"),
                "offset": .number(Double(offset)),
                "version": .string("v1"),
                "generation": .string("g1"),
                "encoding": .string("base64"),
                "eof": .bool(end == bytes.count),
                "data": .string(slice.base64EncodedString()),
            ])
        }
        XCTAssertEqual(offsets, [0, 131072, 262144, 393216])
        XCTAssertEqual(try Data(contentsOf: download.fileURL), bytes)
        XCTAssertEqual(download.missingFonts, ["Aptos"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: download.fileURL.path))
        download.close()
        download.close()
        XCTAssertFalse(FileManager.default.fileExists(atPath: download.fileURL.path))
    }

    func testWorkbookRangeReadsPreserveBytesAndConfirmFinalVersion() async throws {
        let bytes = Data((0..<(workbookChunkBytes * 2 + 19)).map { UInt8($0 % 251) })
        var calls: [(Int, Int)] = []
        let result = try await readWorkbookChunks { offset, length in
            calls.append((offset, length))
            return workbookPage(bytes, offset: offset, length: length)
        }
        XCTAssertEqual(result, bytes)
        XCTAssertEqual(calls.map { [$0.0, $0.1] }, [
            [0, workbookChunkBytes],
            [workbookChunkBytes, workbookChunkBytes],
            [workbookChunkBytes * 2, workbookChunkBytes],
            [bytes.count, 1],
        ])
    }

    func testWorkbookPreviewResourcesAreExact() {
        let assets: Set<String> = ["index.html", "preview.js", "preview.css"]
        let document = "https://workbook-preview.invalid/document/1111"
        XCTAssertEqual(workbookPreviewResourceFor(url: workbookURL, mainFrame: true, assets: assets, documentUrl: document), "index.html")
        XCTAssertEqual(
            workbookPreviewResourceFor(url: workbookAssetPrefix + "preview.js", mainFrame: false, assets: assets, documentUrl: document),
            "preview.js"
        )
        XCTAssertEqual(workbookPreviewResourceFor(url: document, mainFrame: false, assets: assets, documentUrl: document), "@document")
        for url in [
            document + "?token=x",
            "https://example.com/preview.js",
            "file:///data/private",
            workbookAssetPrefix + "../preview.js",
            workbookAssetPrefix + "preview.js?secret=x",
            workbookAssetPrefix + "missing.js",
        ] {
            XCTAssertNil(workbookPreviewResourceFor(url: url, mainFrame: false, assets: assets, documentUrl: document), url)
        }
    }

    func testWorkspaceDirectoryStartsAfterReady() async throws {
        var order: [String] = []
        var reads = 0
        let changes = AsyncThrowingStream<JSONValue, Error> { continuation in
            order.append("watch")
            XCTAssertEqual(reads, 0)
            continuation.yield(jsonObject(["kind": .string("ready")]))
            continuation.yield(jsonObject(["kind": .string("change")]))
            continuation.yield(jsonObject(["kind": .string("change")]))
            continuation.finish()
        }
        try await observeWorkspaceDirectory(
            list: { _ in
                order.append("list")
                reads += 1
                return jsonObject(["version": .number(Double(reads))])
            },
            changes: changes,
            onListing: { _ in order.append("render") },
            onFailure: { XCTFail("unexpected \($0)") }
        )
        XCTAssertEqual(order, ["watch", "list", "render", "list", "render", "list", "render"])
    }

    func testWorkspaceDirectorySkipsChangeWhileAutomaticRefreshIsOff() async throws {
        var reads = 0
        let changes = AsyncThrowingStream<JSONValue, Error> { continuation in
            continuation.yield(jsonObject(["kind": .string("ready")]))
            continuation.yield(jsonObject(["kind": .string("change")]))
            continuation.yield(jsonObject(["kind": .string("change")]))
            continuation.finish()
        }
        try await observeWorkspaceDirectory(
            list: { _ in
                reads += 1
                return jsonObject(["version": .number(Double(reads))])
            },
            changes: changes,
            automatic: { false },
            onListing: { _ in },
            onFailure: { XCTFail("unexpected \($0)") }
        )
        XCTAssertEqual(reads, 1)
    }

    func testUnsupportedWatchKeepsListingWithoutError() async throws {
        var reads = 0
        var rendered = 0
        let unsupported = PocketError(code: "workspace-file/watch-unsupported", message: "watch unsupported")
        for _ in 0..<2 {
            let changes = AsyncThrowingStream<JSONValue, Error> { continuation in
                continuation.finish(throwing: unsupported)
            }
            try await observeWorkspaceDirectory(
                list: { _ in
                    reads += 1
                    return jsonObject(["path": .string(".")])
                },
                changes: changes,
                onListing: { _ in rendered += 1 },
                onFailure: { XCTFail("unexpected \($0)") }
            )
        }
        XCTAssertEqual(rendered, 2)
        XCTAssertEqual(reads, 2)
    }

    func testQoderProfileOverridesRootAndOnlyChangedFieldsAreWritten() throws {
        let draft = qoderConnectionDraft(
            try json(#"{"apiKeyEnv":"ROOT","vpcInstance":"root","baseURL":"root-url","providers":{"qoder-cn":{"apiKeyEnv":"PROFILE","vpcInstance":"","openApiUrl":"profile-api","models":[{"id":"keep"}]}}}"#),
            revision: 4
        )
        XCTAssertEqual(draft.ref, "PROFILE")
        XCTAssertEqual(draft.path, ["providers", "qoder-cn"])
        XCTAssertEqual(draft.fields, QoderConnectionFields(vpcInstance: "", baseURL: "root-url", openApiUrl: "profile-api"))
        var changed = draft
        changed.fields.baseURL = " https://gateway.test "
        XCTAssertEqual(
            qoderConnectionOperations(changed),
            try json(#"[{"op":"set","path":["providers","qoder-cn","baseURL"],"value":"https://gateway.test"}]"#)
        )
        XCTAssertEqual(qoderConnectionDraft(try json("{}"), revision: 0).ref, "QODERCN_PERSONAL_ACCESS_TOKEN")
        XCTAssertEqual(qoderConnectionDraft(try json("{}"), revision: 0).path, [])
    }

    func testQoderPatOnlySaveFencesRevision() async throws {
        var draft = qoderConnectionDraft(try json("{}"), revision: 7)
        draft.pat = "secret-fixture"
        var calls: [String] = []
        let writable = try json(#"{"configured":true,"writable":true}"#)
        let result = try await saveQoderConnection(
            draft,
            writable: true,
            describe: { _ in calls.append("describe"); return writable },
            mutate: { ops, revision in
                calls.append("mutate")
                XCTAssertEqual(ops, .array([]))
                XCTAssertEqual(revision, 7)
                throw PocketError(code: "settings/conflict", message: "secret-fixture must not surface")
            },
            store: { _, _ in
                XCTFail("Credential must not be written after failed CAS")
                return .null
            }
        )
        XCTAssertEqual(calls, ["describe", "mutate"])
        XCTAssertEqual(result.error, .conflict)
        XCTAssertEqual(result.draft, draft)
        XCTAssertFalse(result.settingsSaved)
    }

    func testTrajectoryJsonEmptyContainersAndEscapedKeys() {
        let source = #"{"a/b":{"~key":["line\nquote\"\\",{},[]]},"a~1b":null}"#
        let root = trajectoryJsonDocument(source).root!
        let rows = trajectoryJsonRows(root, expanded: ["", "/a~1b", "/a~1b/~0key"])
        XCTAssertNotNil(rows.first { $0.path == "/a~01b" })
        if case .string(let text) = rows.first(where: { $0.path == "/a~1b/~0key/0" })?.value {
            XCTAssertEqual(text, "line\nquote\"\\")
        } else {
            XCTFail("escaped string")
        }
        let empty = rows.filter { $0.path.hasSuffix("/1") || $0.path.hasSuffix("/2") }
        XCTAssertEqual(empty.count, 2)
        XCTAssertTrue(empty.allSatisfy { !$0.expandable })
        XCTAssertEqual(empty.map { trajectoryJsonRowText($0, expanded: false) }, ["1: {}", "2: []"])
    }

    func testTrajectoryJsonInvalidRetainsSource() {
        for source in ["HTTP 500: connection failed\nretry later", "Error", "01", "{broken", "[true,]"] {
            let document = trajectoryJsonDocument(source)
            XCTAssertNil(document.root, source)
            XCTAssertEqual(document.source, source)
            XCTAssertFalse(document.depthLimited)
        }
    }

    func testJSONValueParseRejectsTrailingCommaAndLeadingZeros() {
        for source in ["[true,]", "{ \"a\": 1, }", "01", "{broken", "Error"] {
            XCTAssertThrowsError(try JSONValue.parse(source), source)
        }
        XCTAssertEqual(try JSONValue.parse("true"), .bool(true))
        XCTAssertEqual(try JSONValue.parse("[true]"), .array([.bool(true)]))
        XCTAssertEqual(try JSONValue.parse("0"), .number(0))
        XCTAssertEqual(try JSONValue.parse("{\"a\":1}"), .object(["a": .number(1)]))
    }

    func testTrajectoryJsonDepthLimit() {
        let source = String(repeating: "[", count: 20_000) + "0" + String(repeating: "]", count: 20_000)
        let document = trajectoryJsonDocument(source)
        XCTAssertTrue(document.depthLimited)
        XCTAssertNil(document.root)
        XCTAssertEqual(document.source, source)
    }

    func testTrajectoryJsonCopyModes() throws {
        let raw = "quote\"slash\\line\nzero\u{200B}width"
        let primitive = JSONValue.string(raw)
        XCTAssertEqual(trajectoryJsonCopyText(primitive, path: "$.text", mode: .value), raw)
        XCTAssertEqual(try JSONValue.parse(trajectoryJsonCopyText(primitive, path: "$.text", mode: .json)), primitive)
        let root = try json(#"{"text":"value","count":2}"#)
        XCTAssertEqual(try JSONValue.parse(trajectoryJsonCopyText(root, path: "$", mode: .prettyJson)), root)
        XCTAssertEqual(try JSONValue.parse(trajectoryJsonCopyText(root, path: "$", mode: .compactJson)), root)
    }

    func testBrowserTabsCheckpointMigratesLegacyAddress() {
        let checkpoint = browserTabsCheckpoint(stored: nil, legacyURL: "https://one.test/", legacyTitle: "One")
        XCTAssertEqual(checkpoint.pages.count, 1)
        XCTAssertEqual(checkpoint.pages[0].url, "https://one.test/")
        XCTAssertEqual(checkpoint.pages[0].title, "One")
        let encoded = encodeBrowserTabsCheckpoint(checkpoint)
        let restored = browserTabsCheckpoint(stored: encoded, legacyURL: "https://ignored.test/", legacyTitle: "Ignored")
        XCTAssertEqual(restored.pages.count, 1)
        XCTAssertEqual(restored.selected, checkpoint.selected)
        XCTAssertEqual(restored.pages[0].url, "https://one.test/")
    }

    func testOfficePreviewErrorReasonsAreOfficialOnly() {
        XCTAssertEqual(
            officePreviewErrorMessage(PocketError(code: "unknown-op", message: "nope"), english: false),
            "Office 预览不可用。请在运行 DeepSeek Harness 的远程主机上启用文档预览服务。"
        )
        XCTAssertEqual(
            officePreviewErrorMessage(PocketError(code: "document-render/failed", message: "x", details: jsonObject(["reason": .string("busy")])), english: true),
            "Office preview is busy. Try again shortly."
        )
        XCTAssertEqual(
            officePreviewErrorMessage(PocketError(code: "document-render/failed", message: "engine dump"), english: false),
            "Office 转换失败，未生成可用的 PDF。请检查该文件后重试。"
        )
    }

    func testPocketClientOfficeCancellationReleasesHandle() async throws {
        let transport = FakeTransport()
        let client = PocketClient()
        try await client.connect(transport: transport, auth: .token("test-token"))
        transport.onSend = {
            if let request = transport.requests.last, request["op"].str() == "office.release" {
                transport.reply(request, jsonObject(["released": .bool(true)]))
            }
        }
        let download = Task {
            try await client.withOfficePreview(sessionId: "s1", path: "report.docx") { _ in
                XCTFail("must not receive a lease")
            }
        }
        try await waitUntil { transport.requests.last?["op"].str() == "office.render" }
        let opening = try XCTUnwrap(transport.requests.last)
        download.cancel()
        _ = try? await download.value
        try await waitUntil { transport.requests.last?["op"].str() == "office.release" }
        let release = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(opening["args"]["subId"].str(), release["args"]["handle"].str())
        XCTAssertEqual(release["args"]["sessionId"].str(), "s1")
        XCTAssertEqual(client.pendingRequestCount, 0)
        client.close()
    }

    func testPocketClientFileWatchReadyBeforeOpeningReply() async throws {
        let transport = FakeTransport()
        let client = PocketClient()
        try await client.connect(transport: transport, auth: .token("test-token"))
        transport.onSend = {
            if let request = transport.requests.last, request["op"].str() == "unfollow" {
                transport.reply(request, jsonObject(["stopped": .bool(true)]))
            }
        }
        let frames = Task {
            var collected: [JSONValue] = []
            for try await frame in client.followFiles(sessionId: "s1", path: "src") {
                collected.append(frame)
                break
            }
            return collected
        }
        try await waitUntil { transport.requests.last?["op"].str() == "files.follow" }
        let opening = try XCTUnwrap(transport.requests.last)
        let subscription = try XCTUnwrap(opening["args"]["subId"].str())
        transport.push(jsonObject([
            "ev": .string("files"),
            "subId": .string("f-old"),
            "frame": jsonObject(["kind": .string("change")]),
        ]))
        transport.push(jsonObject([
            "ev": .string("files"),
            "subId": .string(subscription),
            "frame": jsonObject(["kind": .string("ready")]),
        ]))
        transport.reply(opening, jsonObject(["subId": .string(subscription)]))
        let received = try await frames.value
        XCTAssertEqual(received.single?["kind"].str(), "ready")
        try await waitUntil { transport.requests.last?["op"].str() == "unfollow" }
        XCTAssertEqual(transport.requests.last?["args"]["subId"].str(), subscription)
        client.close()
    }

    func testPreviewKindOfficeWorkbookAndPdf() {
        XCTAssertEqual(previewKindFor("a.docx"), .office)
        XCTAssertEqual(previewKindFor("a.pptx"), .office)
        XCTAssertEqual(previewKindFor("a.xlsx"), .workbook)
        XCTAssertEqual(previewKindFor("a.xls"), .workbook)
        XCTAssertEqual(previewKindFor("a.pdf"), .pdf)
        XCTAssertEqual(previewKindFor("a.png"), .image)
        XCTAssertEqual(previewKindFor("a.zip"), .unsupported)
    }

    private func workbookPage(_ bytes: Data, offset: Int, length: Int, version: String = "v1") -> JSONValue {
        let end = min(bytes.count, offset + length)
        let slice = bytes.subdata(in: offset..<end)
        return jsonObject([
            "absolutePath": .string("/work/book.xlsx"),
            "version": .string(version),
            "bytes": .number(Double(bytes.count)),
            "offset": .number(Double(offset)),
            "eof": .bool(end == bytes.count),
            "encoding": .string("base64"),
            "data": .string(slice.base64EncodedString()),
        ])
    }

    private func waitUntil(_ timeout: TimeInterval = 2, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("timed out")
    }
}

private final class FakeTransport: FrameTransport, @unchecked Sendable {
    let route = Route.wsLocal
    var closeReason: String?
    var closed = false
    var requests: [JSONValue] = []
    var onSend: (() -> Void)?
    private let lock = NSLock()
    private var frames: [String] = []
    private var waiter: CheckedContinuation<String, Error>?

    func send(_ text: String) async throws {
        let request = try JSONValue.parse(text)
        lock.lock()
        requests.append(request)
        lock.unlock()
        if request["op"].str() == "hello" {
            reply(request, jsonObject(["proto": .number(1)]))
        } else {
            onSend?()
        }
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
                continuation.resume(throwing: PocketError(code: "transport", message: "closed"))
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
        pending?.resume(throwing: PocketError(code: "transport", message: "closed"))
    }

    func reply(_ request: JSONValue, _ result: JSONValue) {
        emit(jsonObjectKeeping([
            "id": request["id"],
            "ok": .bool(true),
            "result": result,
        ]))
    }

    func push(_ frame: JSONValue) {
        emit(frame)
    }

    private func emit(_ frame: JSONValue) {
        let text = (try? frame.encodeString()) ?? "{}"
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

private extension Array where Element == JSONValue {
    var single: JSONValue? { count == 1 ? first : nil }
}
