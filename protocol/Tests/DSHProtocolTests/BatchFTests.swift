import XCTest
@testable import DSHProtocol

final class WorkspaceChangesTests: XCTestCase {
    private func j(_ value: String) throws -> JSONValue { try JSONValue.parse(value) }
    private let summary = """
    {"turn":7,"cwd":"/work","total":12,"added":150,"deleted":80,"files":[
        {"path":"z.bin","display":"z.bin","added":0,"deleted":0,"binary":true},
        {"path":"../a.kt","display":"../a.kt","added":4,"deleted":2},
        {"path":"big.dat","display":"big.dat","added":0,"deleted":0,"oversized":true}
    ]}
    """

    func testPreservesHostTotalsOrderPathsAndUncountedFileFlags() throws {
        let parsed = try XCTUnwrap(WorkspaceChangesSummary.parse(j(summary)))
        XCTAssertEqual(parsed.turn, 7)
        XCTAssertEqual(parsed.cwd, "/work")
        XCTAssertEqual(parsed.total, 12)
        XCTAssertEqual(parsed.added, 150)
        XCTAssertEqual(parsed.deleted, 80)
        XCTAssertEqual(parsed.files.map(\.path), ["z.bin", "../a.kt", "big.dat"])
        XCTAssertTrue(parsed.files[0].binary)
        XCTAssertFalse(parsed.files[0].oversized)
        XCTAssertEqual(parsed.files[1], WorkspaceChangedFile(path: "../a.kt", display: "../a.kt", added: 4, deleted: 2))
        XCTAssertTrue(parsed.files[2].oversized)
    }

    func testMissingOrEmptySummaryDoesNotBecomeZeroFileCard() throws {
        for value in ["null", "{}", "[]", #"{"turn":1,"cwd":"/work","total":0,"added":0,"deleted":0,"files":[]}"#, #"{"turn":0,"total":1,"added":1,"deleted":0,"files":[{"path":"a","display":"a","added":1,"deleted":0}]}"#] {
            XCTAssertNil(try WorkspaceChangesSummary.parse(j(value)))
        }
        XCTAssertNil(WorkspaceChangesSummary.parse(nil))
        let capped = try XCTUnwrap(WorkspaceChangesSummary.parse(j(
            #"{"turn":1,"cwd":"/work","total":2,"added":8,"deleted":4,"files":[]}"#
        )))
        XCTAssertEqual(capped.total, 2)
        XCTAssertTrue(capped.files.isEmpty)
    }

    func testHttpSummaryOmitsCwdAndKeepsHostServedOutsideWorkspacePaths() throws {
        let parsed = try XCTUnwrap(WorkspaceChangesSummary.parse(j("""
        {"turn":1,"total":2,"added":3,"deleted":0,"files":[
            {"path":"/tmp/dsh-parity-r2.txt","display":"/tmp/dsh-parity-r2.txt","added":2,"deleted":0},
            {"path":"../outside.txt","display":"../outside.txt","added":1,"deleted":0}
        ]}
        """)))
        XCTAssertEqual(parsed.cwd, "")
        XCTAssertEqual(parsed.files.map(\.path), ["/tmp/dsh-parity-r2.txt", "../outside.txt"])
        XCTAssertEqual(parsed.files.map(\.display), ["/tmp/dsh-parity-r2.txt", "../outside.txt"])
        XCTAssertEqual(parsed.total, 2)
        XCTAssertNil(try WorkspaceChangesSummary.parse(j(
            #"{"turn":1,"cwd":12,"total":1,"added":1,"deleted":0,"files":[{"path":"a","display":"a","added":1,"deleted":0}]}"#
        )))
    }

    func testMalformedEntryRejectsWholeSummaryInsteadOfShiftingDiffIndices() throws {
        XCTAssertNil(try WorkspaceChangesSummary.parse(j(summary.replacingOccurrences(of: "\"path\":\"z.bin\"", with: "\"path\":null"))))
        XCTAssertNil(try WorkspaceChangesSummary.parse(j(summary.replacingOccurrences(of: "\"display\":\"../a.kt\"", with: "\"display\":12"))))
        XCTAssertNil(try WorkspaceChangesSummary.parse(j(summary.replacingOccurrences(of: "\"added\":4", with: "\"added\":-1"))))
        XCTAssertNil(try WorkspaceChangesSummary.parse(j(summary.replacingOccurrences(of: "\"total\":12", with: "\"total\":2147483648"))))
        XCTAssertNil(try WorkspaceChangesSummary.parse(j(summary.replacingOccurrences(of: "\"total\":12", with: "\"total\":2"))))
    }

    func testTextDiffKeepsPrefixesEmptyLinesExistenceAndCoarseFlag() throws {
        let parsed = try XCTUnwrap(WorkspaceFileDiff.parse(j("""
        {
            "kind":"text","path":"src/a.kt","display":"src/a.kt","before":false,"after":true,"coarse":true,
            "hunks":[{"oldStart":1,"oldLines":0,"newStart":5,"newLines":3,"lines":[" context","-old","+new","+", ""]}]
        }
        """)))
        XCTAssertFalse(parsed.before)
        XCTAssertTrue(parsed.after)
        XCTAssertTrue(parsed.coarse)
        XCTAssertEqual(parsed.hunks.single, WorkspaceDiffHunk(oldStart: 1, newStart: 5, lines: [" context", "-old", "+new", "+", ""]))
        let deleted = try XCTUnwrap(WorkspaceFileDiff.parse(j(
            #"{"kind":"text","path":"gone","display":"gone","before":true,"after":false,"coarse":false,"hunks":[]}"#
        )))
        XCTAssertTrue(deleted.before)
        XCTAssertFalse(deleted.after)
        XCTAssertTrue(deleted.hunks.isEmpty)
    }

    func testBinaryAndOversizedDiffsDoNotRequireTextFields() throws {
        for kind in ["binary", "oversized"] {
            let parsed = try XCTUnwrap(WorkspaceFileDiff.parse(j(#"{"kind":"\#(kind)","path":"a","display":"a"}"#)))
            XCTAssertEqual(parsed.kind, kind)
            XCTAssertTrue(parsed.hunks.isEmpty)
        }
    }

    func testMissingUnknownAndMalformedDiffsRemainUnavailable() throws {
        for value in ["null", "{}", #"{"kind":"other","path":"a","display":"a"}"#, #"{"kind":"text","path":"a","display":"a"}"#] {
            XCTAssertNil(try WorkspaceFileDiff.parse(j(value)))
        }
        XCTAssertNil(try WorkspaceFileDiff.parse(j("""
        {"kind":"text","path":"a","display":"a","before":true,"after":true,"coarse":false,
            "hunks":[{"oldStart":1,"newStart":1,"lines":["+valid",null]}]}
        """)))
    }

    func testChangeDiffLinesKeepPrefixesAndCapAt5000() {
        let diff = WorkspaceFileDiff(
            kind: "text", path: "a", display: "a",
            hunks: [
                WorkspaceDiffHunk(oldStart: 4, newStart: 8, lines: [" context", "-old", "+new", " next"]),
                WorkspaceDiffHunk(oldStart: 20, newStart: 24, lines: ["+added"]),
            ]
        )
        XCTAssertEqual(
            changeDiffLines(diff),
            [
                ChangeDiffLine(old: 4, new: 8, text: " context"),
                ChangeDiffLine(old: 5, new: nil, text: "-old"),
                ChangeDiffLine(old: nil, new: 9, text: "+new"),
                ChangeDiffLine(old: 6, new: 10, text: " next"),
                ChangeDiffLine(old: nil, new: 24, text: "+added"),
            ]
        )
        let capped = changeDiffLines(WorkspaceFileDiff(
            kind: "text", path: "a", display: "a",
            hunks: [WorkspaceDiffHunk(oldStart: 1, newStart: 1, lines: (0..<5001).map { "+\($0)" })]
        ))
        XCTAssertEqual(capped.last, ChangeDiffLine(old: nil, new: 5000, text: "+4999"))
        XCTAssertEqual(capped.count, 5000)
    }

    func testPocketSummaryEnvelopeParsesHostObjectWithSnapshot() throws {
        let envelope = try j("""
        {"ok":true,"result":{"summary":{
            "turn":1,
            "cwd":"/Users/luming/project",
            "total":1,
            "added":2,
            "deleted":0,
            "snapshot":{"before":"aaa111","after":"bbb222"},
            "files":[{"path":"parity-r3-card.txt","display":"parity-r3-card.txt","added":2,"deleted":0}]
        }}}
        """)
        XCTAssertEqual(envelope["ok"].bool(), true)
        let parsed = try XCTUnwrap(WorkspaceChangesSummary.parsePocketResult(envelope["result"]))
        XCTAssertEqual(parsed.turn, 1)
        XCTAssertEqual(parsed.cwd, "/Users/luming/project")
        XCTAssertEqual(parsed.total, 1)
        XCTAssertEqual(parsed.added, 2)
        XCTAssertEqual(parsed.deleted, 0)
        XCTAssertEqual(parsed.files.single, WorkspaceChangedFile(
            path: "parity-r3-card.txt", display: "parity-r3-card.txt", added: 2, deleted: 0
        ))
    }

    func testPocketSummaryNullAndMalformedFlagsStayUnavailable() throws {
        XCTAssertNil(try WorkspaceChangesSummary.parsePocketResult(j(#"{"summary":null}"#)))
        XCTAssertNil(WorkspaceChangesSummary.parsePocketResult(nil))
        let serializedFalse = try XCTUnwrap(WorkspaceChangesSummary.parsePocketResult(j(#"{"summary":{"turn":1,"total":1,"added":2,"deleted":0,"files":[{"path":"a","display":"a","added":2,"deleted":0,"binary":false,"oversized":false}]}}"#)))
        XCTAssertEqual(serializedFalse.files.single, WorkspaceChangedFile(path: "a", display: "a", added: 2, deleted: 0))
        XCTAssertNil(try WorkspaceChangesSummary.parsePocketResult(j(#"{"summary":{"turn":1,"total":1,"added":2,"deleted":0,"files":[{"path":"","display":"a","added":2,"deleted":0}]}}"#)))
        XCTAssertNil(try WorkspaceChangesSummary.parsePocketResult(j(#"{"summary":{"turn":1,"total":1,"added":2,"deleted":0,"files":[{"path":"a","display":"a","added":2,"deleted":0,"binary":null}]}}"#)))
        XCTAssertNil(try WorkspaceChangesSummary.parsePocketResult(j(#"{"summary":{"turn":1,"total":1,"added":2,"deleted":0,"files":[{"path":"a","display":"a","added":2,"deleted":0,"binary":"yes"}]}}"#)))
        let http = try XCTUnwrap(WorkspaceChangesSummary.parsePocketResult(j("""
        {"summary":{"turn":1,"total":1,"added":1,"deleted":1,"files":[
            {"path":"parity-r3-card.txt","display":"parity-r3-card.txt","added":1,"deleted":1}
        ]}}
        """)))
        XCTAssertEqual(http.cwd, "")
        XCTAssertEqual(http.files.single.deleted, 1)
    }

    func testTrailingBlankAssistantKeepsTurnTailChangesAttachment() throws {
        let answer = Item.Text(key: "a1", text: "已创建文件", live: false, turn: 1, step: 2)
        let blank = Item.Text(key: "a-blank", text: "  \n", live: false, turn: 1, step: 2)
        let changes = Item.Changes(key: "ch10", turn: 1, seq: 10)
        let items: [Item] = [
            .user(Item.User(key: "u", text: "edit")),
            .text(answer),
            .text(blank),
            .changes(changes),
        ]
        XCTAssertEqual(ChatActionKeys.lastCommittedAnswerKeys(items)[1], "a1")
        let rows: [ChatRow] = [.answer(answer), .changes(changes)]
        XCTAssertEqual(lastCommittedAnswerKeys(in: rows)[1], "a1")
        let visible = chatTranscriptRows(rows)
        XCTAssertFalse(visible.contains { if case .changes = $0 { return true }; return false })
        XCTAssertEqual(
            changesAttachedToAnswer(answer, lastCommittedAnswerKeys: ChatActionKeys.lastCommittedAnswerKeys(items), changesByTurn: [1: changes])?.seq,
            10
        )
    }

    func testSummaryAndDiffArgsKeepHostFieldNames() throws {
        let summary = workspaceChangesSummaryArgs(sessionId: "specified-session", seq: 42)
        XCTAssertEqual(summary["sessionId"].str(), "specified-session")
        XCTAssertEqual(summary["seq"].long(), 42)
        let diff = workspaceChangesDiffArgs(sessionId: "another-session", seq: 91, index: 2)
        XCTAssertEqual(diff["sessionId"].str(), "another-session")
        XCTAssertEqual(diff["seq"].long(), 91)
        XCTAssertEqual(diff["index"].int(), 2)
    }

    private func event(_ seq: Int, _ type: String, _ data: String) throws -> JSONValue {
        try JSONValue.parse(
            #"{"type":"event","event":{"seq":\#(seq),"time":\#(seq),"type":"\#(type)","data":\#(data)}}"#
        )
    }

    private func changesItems(_ reducer: TranscriptReducer) -> [Item.Changes] {
        reducer.items().compactMap { item in
            if case .changes(let change) = item { return change }
            return nil
        }
    }

    func testWorkspaceChangesEventKeepsLatestAnnouncementPerTurn() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try event(1, "workspace/changes", #"{"turn":3}"#)))
        XCTAssertTrue(reducer.apply(try event(2, "workspace/changes", #"{"turn":3}"#)))
        XCTAssertTrue(reducer.apply(try event(3, "workspace/changes", #"{"turn":4}"#)))
        XCTAssertTrue(reducer.apply(try event(4, "workspace/changes", #"{"turn":-1}"#)))
        XCTAssertTrue(reducer.apply(try event(5, "workspace/changes", #"{"turn":0}"#)))
        XCTAssertTrue(reducer.apply(try event(6, "workspace/changes", "{}")))
        let items = changesItems(reducer)
        XCTAssertEqual(items.map(\.turn), [3, 4])
        XCTAssertEqual(items.map(\.key), ["ch2", "ch3"])
        XCTAssertEqual(items.map(\.seq), [2, 3])
    }

    func testCollapsedTurnKeepsIndependentChangesCard() {
        let items: [Item] = [
            .user(Item.User(key: "u", text: "edit files")),
            .tool(Item.Tool(key: "t1", callId: "c1", name: "write", arguments: "{}", status: .ok, turn: 1, step: 1)),
            .changes(Item.Changes(key: "ch10", turn: 1, seq: 10)),
            .text(Item.Text(key: "a1", text: "done", live: false, turn: 1, step: 1)),
        ]
        let rows = foldChatItems(
            items,
            policy: presentationPolicyFor(.standard),
            sessionRunning: false,
            turnRecords: [TurnRecord(turn: 1, startSeq: 1, endSeq: 10, startedAt: 0, endedAt: 2000)]
        )
        let control = rows.compactMap { row -> ChatRow.Process? in
            if case .process(let proc) = row, proc.turnSummary { return proc }
            return nil
        }.single
        XCTAssertFalse(control.controlledKeys.contains("ch10"))
        XCTAssertTrue(control.controlledKeys.contains("a1"))
        let collapsed = chatTranscriptRows(rows)
        XCTAssertTrue(collapsed.contains { if case .changes(let item) = $0 { return item.key == "ch10" }; return false })
        let expanded = chatTranscriptRows(rows, openTurns: [control.key: true])
        XCTAssertFalse(expanded.contains { if case .changes = $0 { return true }; return false })
        XCTAssertTrue(expanded.contains { if case .answer(let text) = $0 { return text.key == "a1" }; return false })
        XCTAssertEqual(
            changesAttachedToAnswer(
                Item.Text(key: "a1", text: "done", live: false, turn: 1, step: 1),
                lastCommittedAnswerKeys: ChatActionKeys.lastCommittedAnswerKeys(items),
                changesByTurn: [1: Item.Changes(key: "ch10", turn: 1, seq: 10)]
            )?.key,
            "ch10"
        )
    }

    func testEarlierVisibleAnswerDoesNotHideIndependentCardWhenLastCommittedIsFolded() {
        let earlier = Item.Text(key: "a0", text: "working", live: false, turn: 1, step: 1)
        let last = Item.Text(key: "a1", text: "done", live: false, turn: 1, step: 2)
        let changes = Item.Changes(key: "ch10", turn: 1, seq: 10)
        let rows: [ChatRow] = [
            .user(Item.User(key: "u", text: "edit files")),
            .process(ChatRow.Process(
                key: "turn-1-process",
                tools: [],
                reasoning: [],
                title: "已完成",
                closed: true,
                defaultOpen: false,
                turnSummary: true,
                canCollapse: true,
                turn: 1,
                controlledKeys: ["a1"]
            )),
            .answer(earlier),
            .changes(changes),
            .answer(last),
        ]
        let collapsed = chatTranscriptRows(rows)
        XCTAssertTrue(collapsed.contains { if case .answer(let text) = $0 { return text.key == "a0" }; return false })
        XCTAssertFalse(collapsed.contains { if case .answer(let text) = $0 { return text.key == "a1" }; return false })
        XCTAssertTrue(collapsed.contains { if case .changes(let item) = $0 { return item.key == "ch10" }; return false })
        XCTAssertNil(changesAttachedToAnswer(
            earlier,
            lastCommittedAnswerKeys: [1: last.key],
            changesByTurn: [1: changes]
        ))
        XCTAssertEqual(
            changesAttachedToAnswer(last, lastCommittedAnswerKeys: [1: last.key], changesByTurn: [1: changes])?.key,
            "ch10"
        )
    }

    func testCreateWorkspaceTempFileSessionShowsTurnTailCardNotFolded() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try event(1, "turn/start", #"{"turn":1}"#)))
        XCTAssertTrue(reducer.apply(try event(2, "user/message", #"{"message":{"id":"u1","content":[{"type":"text","text":"创建工作区临时文件并展示变更"}],"source":{"kind":"user"}}}"#)))
        XCTAssertTrue(reducer.apply(try event(3, "step/start", #"{"turn":1,"step":1}"#)))
        XCTAssertTrue(reducer.apply(try event(4, "tool/call", #"{"callId":"write-1","name":"write","arguments":"{\"path\":\"dsh-parity-r2.txt\"}","turn":1,"step":1}"#)))
        XCTAssertTrue(reducer.apply(try event(5, "tool/result", #"{"message":{"toolCallId":"write-1","content":[{"type":"text","text":"wrote"}]}}"#)))
        XCTAssertTrue(reducer.apply(try event(6, "step/end", #"{"turn":1,"step":1}"#)))
        XCTAssertTrue(reducer.apply(try event(7, "step/start", #"{"turn":1,"step":2}"#)))
        XCTAssertTrue(reducer.apply(try event(8, "assistant/message", #"{"turn":1,"step":2,"message":{"id":"m1","content":[{"type":"text","text":"已创建文件并已为您展示变更卡"}]}}"#)))
        XCTAssertTrue(reducer.apply(try event(9, "step/end", #"{"turn":1,"step":2}"#)))
        XCTAssertTrue(reducer.apply(try event(10, "workspace/changes", #"{"turn":1}"#)))
        XCTAssertTrue(reducer.apply(try event(11, "turn/end", #"{"turn":1,"reason":{"kind":"complete"}}"#)))

        let items = reducer.items()
        let changes = changesItems(reducer)
        XCTAssertEqual(changes.map(\.turn), [1])
        XCTAssertEqual(changes.map(\.key), ["ch10"])
        XCTAssertEqual(changes.map(\.seq), [10])

        let lastCommitted = ChatActionKeys.lastCommittedAnswerKeys(items)
        XCTAssertEqual(lastCommitted[1], "t8.0")

        let rows = foldChatItems(
            items,
            policy: presentationPolicyFor(.standard),
            sessionRunning: false,
            turnRecords: reducer.turnRecords()
        )
        let control = rows.compactMap { row -> ChatRow.Process? in
            if case .process(let proc) = row, proc.turnSummary { return proc }
            return nil
        }.single
        XCTAssertFalse(control.controlledKeys.contains("ch10"))
        XCTAssertFalse(control.controlledKeys.contains("t8.0"))
        let process = rows.compactMap { row -> ChatRow.Process? in
            if case .process(let proc) = row, !proc.turnSummary { return proc }
            return nil
        }.single
        XCTAssertTrue(control.controlledKeys.contains(process.key))

        let collapsed = chatTranscriptRows(rows)
        XCTAssertFalse(collapsed.contains { if case .changes = $0 { return true }; return false })
        let answer = collapsed.compactMap { row -> Item.Text? in
            if case .answer(let text) = row { return text }
            return nil
        }.single
        XCTAssertEqual(answer.key, "t8.0")
        XCTAssertEqual(
            changesAttachedToAnswer(answer, lastCommittedAnswerKeys: lastCommitted, changesByTurn: [1: changes.single])?.seq,
            10
        )
        XCTAssertNil(changesAttachedToAnswer(
            Item.Text(key: "earlier", text: "draft", live: false, turn: 1, step: 1),
            lastCommittedAnswerKeys: lastCommitted,
            changesByTurn: [1: changes.single]
        ))
    }
}

final class BrowserPolicyTests: XCTestCase {
    private let policy = BrowserPolicy()

    private func accepted(_ input: String, _ expected: String, using policy: BrowserPolicy? = nil) {
        let actual = (policy ?? self.policy).parse(input)
        guard case .target(let url, _) = actual else {
            XCTFail("Expected accepted address for \(input), got \(actual)")
            return
        }
        XCTAssertEqual(url, expected)
    }

    private func refused(_ input: String, _ reason: BrowserAddressFailure? = nil, using policy: BrowserPolicy? = nil) {
        let actual = (policy ?? self.policy).parse(input)
        guard case .rejected(let got) = actual else {
            XCTFail("Expected refused address for \(input), got \(actual)")
            return
        }
        if let reason { XCTAssertEqual(got, reason, input) }
    }

    func testMissingSchemeDefaultsToHttpsAndRetainsPathsQueriesAndFragments() {
        accepted(" example.com ", "https://example.com/")
        accepted("EXAMPLE.com/path?q=a%20b#section", "https://example.com/path?q=a%20b#section")
        accepted("HTTP://Example.COM/a", "http://example.com/a")
        accepted("https://example.com/中文", "https://example.com/%E4%B8%AD%E6%96%87")
        accepted("https://例子.com", "https://xn--fsqu00a.com/")
    }

    func testLocalAddressesAreRealHttpTargetsNotAnImplicitHostProxy() {
        accepted("localhost:8080", "https://localhost:8080/")
        accepted("http://localhost:8080/demo", "http://localhost:8080/demo")
        accepted("127.0.0.1:3000?x=1", "https://127.0.0.1:3000/?x=1")
        accepted("[::1]:8080/path", "https://[::1]:8080/path")
        accepted("http://[::1]:8080/", "http://[::1]:8080/")
        accepted("computer:1234", "https://computer:1234/")
    }

    func testNativeAndScriptSchemesCannotNavigateEvenWithNumericPayloads() {
        for value in [
            "file:///sdcard/private", "content://dev.dsh.pocket.files/private",
            "data:text/html,<script>x</script>", "javascript:alert(1)", "blob:https://example.com/id",
            "intent://example.com", "about:blank", "ftp://example.com", "ws://example.com",
            "data:123", "javascript:123", "content:123", "file:123",
        ] {
            refused(value, .protocolKind)
        }
    }

    func testUserinfoNeverBecomesAnAddressOrExternalIntent() {
        for value in [
            "https://user:password@example.com/", "http://user@example.com", "https://@example.com/",
            "https://%75ser@example.com", "https://example.com@evil.test",
        ] {
            refused(value, .credentials)
        }
        refused("https://user%40example.com/")
        refused("https://example%2ecom/")
    }

    func testMalformedAuthoritiesAndAmbiguousSeparatorsAreRejected() {
        for value in [
            "https:///example.com", "http:example.com", "https://", "//example.com", "https://example.com:",
            "https://example.com:0", "https://example.com:65536", "https://example.com:abc", "https://example.com:-1",
            "https://example.com\\@evil.test", "https://example.com/\nheader", "https://example.com/a b",
            "https://example.com/%zz", "https://[::1", "https://example..com",
        ] {
            refused(value)
        }
    }

    func testAddressLengthAndEmptyValuesAreBoundedBeforeNavigation() {
        refused("   ", .empty)
        refused("https://example.com/" + String(repeating: "a", count: maxBrowserURLLength), .invalid)
        let prefix = "https://example.com/"
        let exactLimit = prefix + String(repeating: "a", count: maxBrowserURLLength - prefix.count)
        accepted(exactLimit, exactLimit)
    }

    func testHostOriginsUseCanonicalHostAndEffectivePort() {
        let blocked = BrowserPolicy(applicationOrigins: [
            "https://HOST.example:443/manage", "http://localhost:3000", "https://[::1]:4443",
        ])
        for value in [
            "https://host.example", "https://HOST.EXAMPLE:443/x", "https://host.example./x",
            "https://host.example:443/?q=x#y",
        ] {
            refused(value, .applicationOrigin, using: blocked)
        }
        refused("http://LOCALHOST:3000/anything", .applicationOrigin, using: blocked)
        refused("https://[::1]:4443/", .applicationOrigin, using: blocked)
        accepted("https://host.example:444/", "https://host.example:444/", using: blocked)
        accepted("http://host.example/", "http://host.example/", using: blocked)
        accepted("https://host.example.evil.test/", "https://host.example.evil.test/", using: blocked)
    }

    func testRequestChecksDoNotInterpretRelativeOrSpecialUrlsAsTypedHostnames() {
        for value in ["example.com", "localhost:8080", "/relative/path", "//example.com", "data:123", "javascript:123"] {
            if case .rejected = policy.parse(value, allowShorthand: false) { continue }
            XCTFail("expected rejected \(value)")
        }
        if case .target = policy.parse("https://example.com/page", allowShorthand: false) { return }
        XCTFail("expected accepted https page")
    }

    func testInvalidConfiguredOriginsDoNotGrantSpecialAccessOrBlockUnrelatedSites() {
        let blocked = BrowserPolicy(applicationOrigins: ["invalid", "null", "file:///tmp", "https://"])
        accepted("https://example.com", "https://example.com/", using: blocked)
        refused("javascript:alert(1)", .protocolKind, using: blocked)
    }
}

final class CodePreviewTests: XCTestCase {
    func testAssetPolicyOnlyServesExactOfflineNamesAndOneInitialDocument() {
        let assets: Set<String> = ["index.html", "preview.js", "preview.css", "grammar-ABC123.js"]
        let base = "https://code-preview.invalid/code-preview/"
        XCTAssertEqual(codePreviewAssetFor(url: base + "index.html", mainFrame: true, assets: assets), "index.html")
        XCTAssertEqual(codePreviewAssetFor(url: base + "preview.js", mainFrame: false, assets: assets), "preview.js")
        XCTAssertEqual(codePreviewAssetFor(url: base + "grammar-ABC123.js", mainFrame: false, assets: assets), "grammar-ABC123.js")
        XCTAssertEqual(
            codePreviewAssetFor(url: "https://code-preview.invalid/font/meslo.ttf", mainFrame: false, assets: assets),
            "@meslo"
        )
        for url in [
            "https://example.com/preview.js", "http://code-preview.invalid/code-preview/preview.js",
            "file:///data/user/0/dev.dsh.pocket/files/private", "content://private/file",
            "javascript:alert(1)", "data:text/html,<script>alert(1)</script>",
            base + "../preview.js", base + "%2e%2e/preview.js", base + "preview.js?url=secret",
            base + "preview.js#fragment", base + "unlisted.js", base + "vendor/LICENSE",
            "https://code-preview.invalid.evil/code-preview/preview.js",
        ] {
            XCTAssertNil(codePreviewAssetFor(url: url, mainFrame: false, assets: assets), url)
        }
        XCTAssertNil(codePreviewAssetFor(url: base + "preview.js", mainFrame: true, assets: assets))
        XCTAssertNil(codePreviewAssetFor(url: "https://code-preview.invalid/font/meslo.ttf", mainFrame: true, assets: assets))
    }

    func testJavascriptArgumentRoundTripsAttackStringsAndOriginalNewlines() throws {
        let path = "C:\\source\\attack.js"
        let source = "</script><img src=x onerror=alert(1)>\r\n\t\"; globalThis.attacked=true; //\n\u{2028}\u{2029}"
        let script = codePreviewDocumentScript(path: path, text: source)
        XCTAssertTrue(script.hasPrefix("window.codePreview.setDocument("))
        XCTAssertTrue(script.hasSuffix(");"))
        let json = String(script.dropFirst("window.codePreview.setDocument(".count).dropLast(2))
        let document = try JSONValue.parse(json)
        XCTAssertEqual(document["path"].str(), path)
        XCTAssertEqual(document["text"].str(), source)
        XCTAssertFalse(script.contains("\u{2028}"))
        XCTAssertFalse(script.contains("\u{2029}"))
    }

    func testExtensionRulesMatchOfficialTableRatherThanIconClassification() {
        XCTAssertEqual(previewCodeLanguage("dist/index.js"), "javascript")
        XCTAssertEqual(previewCodeLanguage("C:\\src\\Main.KT"), "kotlin")
        XCTAssertEqual(previewCodeLanguage("scripts/main.PS1"), "powershell")
        XCTAssertEqual(previewCodeLanguage(".env"), "dotenv")
        XCTAssertEqual(previewCodeLanguage("build.gradle"), "groovy")
        for path in ["Makefile", "Dockerfile", ".gitignore", "README", "dir.py/unknown", "file.constructor", "file.lock"] {
            XCTAssertNil(previewCodeLanguage(path), path)
        }
    }
}

final class TranscriptPublisherTests: XCTestCase {
    private struct View: Equatable, Sendable {
        var session: String
        var text: String
        var running: Bool
    }

    private final class PaintLog: @unchecked Sendable {
        private let lock = NSLock()
        private var views: [View] = []
        var current = View(session: "", text: "", running: false)
        func appendCurrent() {
            lock.lock()
            views.append(current)
            lock.unlock()
        }
        var snapshot: [View] {
            lock.lock()
            defer { lock.unlock() }
            return views
        }
    }

    private func waitUntilWaiters(_ clock: ManualTranscriptClock, _ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10_000 {
            if clock.pendingWaiterCount >= count { return }
            await Task.yield()
        }
        XCTFail("clock waiters \(clock.pendingWaiterCount) < \(count)", file: file, line: line)
    }

    private func waitUntilPainted(_ log: PaintLog, _ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10_000 {
            if log.snapshot.count >= count { return }
            await Task.yield()
        }
        XCTFail("painted \(log.snapshot.count) < \(count)", file: file, line: line)
    }

    func testContinuousDeltasPublishTheCompleteLatestTextWithoutDebouncingForever() async throws {
        let painted = PaintLog()
        painted.current = View(session: "A", text: "", running: true)
        let clock = ManualTranscriptClock()
        let publisher = TranscriptPublisher(clock: clock) { painted.appendCurrent() }
        for index in 0..<5 {
            painted.current.text += "\(index)"
            publisher.schedule()
            if index == 0 { await waitUntilWaiters(clock, 1) }
            clock.advanceTime(10)
        }
        XCTAssertTrue(painted.snapshot.isEmpty)
        clock.runDue()
        await waitUntilPainted(painted, 1)
        XCTAssertEqual(painted.snapshot, [View(session: "A", text: "01234", running: true)])
        painted.current.text += "5"
        publisher.schedule()
        await waitUntilWaiters(clock, 1)
        clock.advanceTime(50)
        clock.runDue()
        await waitUntilPainted(painted, 2)
        XCTAssertEqual(painted.snapshot.last, View(session: "A", text: "012345", running: true))
        XCTAssertEqual(painted.snapshot.count, 2)
    }

    func testCompletionFlushIncludesPendingTextAndOldTickCannotReopenRunningState() async throws {
        let painted = PaintLog()
        painted.current = View(session: "A", text: "partial", running: true)
        let clock = ManualTranscriptClock()
        let publisher = TranscriptPublisher(clock: clock) { painted.appendCurrent() }
        publisher.schedule()
        await waitUntilWaiters(clock, 1)
        clock.advanceTime(20)
        painted.current = View(session: "A", text: "complete answer", running: false)
        publisher.flush()
        XCTAssertEqual(painted.snapshot, [painted.current])
        clock.advanceTime(100)
        clock.runDue()
        XCTAssertEqual(painted.snapshot, [View(session: "A", text: "complete answer", running: false)])
    }

    func testDetachedGenerationCannotPaintIntoTheNextSession() async throws {
        let painted = PaintLog()
        painted.current = View(session: "A", text: "old answer", running: true)
        let clock = ManualTranscriptClock()
        let publisher = TranscriptPublisher(clock: clock) { painted.appendCurrent() }
        publisher.schedule()
        await waitUntilWaiters(clock, 1)
        clock.advanceTime(25)
        publisher.cancel()
        painted.current = View(session: "B", text: "new answer", running: true)
        publisher.schedule()
        await waitUntilWaiters(clock, 2)
        clock.advanceTime(25)
        clock.runDue()
        XCTAssertTrue(painted.snapshot.isEmpty)
        clock.advanceTime(25)
        clock.runDue()
        await waitUntilPainted(painted, 1)
        XCTAssertEqual(painted.snapshot, [View(session: "B", text: "new answer", running: true)])
    }
}

final class TrajectoryRequestTests: XCTestCase {
    private func j(_ s: String) throws -> JSONValue { try JSONValue.parse(s) }
    private func ev(_ seq: Int, _ type: String, _ data: String, time: Int = 0) throws -> JSONValue {
        let t = time == 0 ? 1000 + seq : time
        return try j(#"{"type":"event","event":{"type":"\#(type)","seq":\#(seq),"time":\#(t),"data":\#(data)}}"#)
    }

    func testNumbersAssistantAndCompactionInSeqOrder() {
        let items: [Item] = [
            .user(Item.User(key: "u1", text: "hi")),
            .compacted(Item.Compacted(key: "cmp1", compactionId: "c1", status: .ok, summary: "kept", startedAt: 50, endedAt: 90)),
            .text(Item.Text(key: "a1", text: "hello", live: false)),
            .tool(Item.Tool(key: "t1", callId: "c1", name: "read", arguments: "{}", status: .ok, turn: 1, step: 1)),
            .tool(Item.Tool(key: "t2", callId: "c1:ptc:1", name: "bash", arguments: "{}", status: .ok, turn: 1, step: 1, parentCallId: "c1")),
        ]
        let steps = [
            StepRecord(
                seq: 10, turn: 1, step: 1, stepStartTime: 100, messageTime: 200,
                replyText: "hello", usage: StepUsage(inputTokens: 10, outputTokens: 2),
                provider: "deepseek", model: "flash", toolCallIds: ["c1", "c1:ptc:1"],
                requestConfigJson: #"{"provider":"deepseek","model":"flash"}"#
            ),
        ]
        let requests = buildTrajectoryRequests(items: items, steps: steps)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].purpose, .compaction)
        XCTAssertEqual(requests[0].number, 1)
        XCTAssertEqual(requests[1].purpose, .assistant)
        XCTAssertEqual(requests[1].number, 2)
        XCTAssertEqual(requests[1].toolCallCount, 1)
        XCTAssertEqual(requests[1].subtoolCallCount, 1)
        XCTAssertEqual(requests[1].usage, StepUsage(inputTokens: 10, outputTokens: 2))
        XCTAssertEqual(requests[1].cumulativeUsage, StepUsage(inputTokens: 10, outputTokens: 2))
        XCTAssertEqual(trajRequestTabs(requests[1]), [.overview, .options, .usage, .timing])
        XCTAssertEqual(trajRequestTabs(requests[0]), [.overview, .usage, .timing])
    }

    func testBoundaryChipAnchorsOnAssistantResultRow() throws {
        let steps = [
            StepRecord(seq: 10, turn: 1, step: 1, stepStartTime: 100, messageTime: 200, replyText: "ok"),
        ]
        let items: [Item] = [.user(Item.User(key: "u", text: "hi")), .text(Item.Text(key: "a10", text: "ok", live: false))]
        let turns = buildTrajectory(items, steps: steps)
        let requests = buildTrajectoryRequests(items: items, steps: steps)
        let req = requests[0]
        XCTAssertEqual(requestBoundaryRowKey(req, turns: turns), "a10")
        let assistant = try XCTUnwrap(turns[0].rows.first { $0.kind == TrajL.kindAssistant })
        XCTAssertEqual(requestForRow(assistant, requests: requests), req)
    }

    func testRequestHeaderAndRetryStampOntoStepRecord() throws {
        let r = TranscriptReducer()
        _ = try r.apply(j(#"{"type":"snapshot","cursor":0,"records":[],"hasMore":false,"projections":{}}"#))
        _ = try r.apply(ev(1, "turn/start", #"{"turn":1}"#))
        _ = try r.apply(ev(2, "step/start", #"{"turn":1,"step":1}"#))
        _ = try r.apply(ev(3, "request/header", """
        {"header":{"config":{"provider":"deepseek","model":"flash","temperature":0.2},
                "tools":[{"name":"read","description":"R","parameters":{"type":"object"}}]}}
        """))
        _ = try r.apply(ev(4, "llm/retry", #"{"retry":1,"maxRetries":3,"delayMs":500,"error":{"message":"rate limited"}}"#))
        _ = try r.apply(ev(5, "assistant/message", """
        {"turn":1,"step":1,"stream":[],"usage":{"inputTokens":11,"outputTokens":3},
                "message":{"content":[{"type":"text","text":"hi"}]}}
        """))
        let step = r.stepRecords()[0]
        XCTAssertEqual(step.provider, "deepseek")
        XCTAssertEqual(step.model, "flash")
        XCTAssertNotNil(step.requestConfigJson)
        XCTAssertTrue(step.requestConfigJson?.contains("temperature") == true)
        XCTAssertEqual(step.retry, 1)
        XCTAssertEqual(step.maxRetries, 3)
        XCTAssertEqual(step.retryDelayMs, 500)
        XCTAssertEqual(step.lastAttemptError, "rate limited")
        let header = r.requestHeaders()[0]
        XCTAssertEqual(header.provider, "deepseek")
        XCTAssertEqual(header.model, "flash")
        let req = buildTrajectoryRequests(items: r.items(), steps: r.stepRecords())[0]
        XCTAssertEqual(req.retry, 1)
        XCTAssertEqual(req.maxRetries, 3)
        XCTAssertEqual(req.status, .complete)
        XCTAssertTrue(req.requestConfigJson?.contains("temperature") == true)
    }

    func testPrependMergesOlderRequestHeaders() throws {
        let r = TranscriptReducer()
        _ = try r.apply(j("""
        {"type":"snapshot","cursor":4,"hasMore":true,"records":[
            {"type":"event","event":{"type":"request/header","seq":4,"time":4,"data":{"header":{"config":{"provider":"new","model":"m2"},"tools":[]}}}}
        ],"projections":{}}
        """))
        XCTAssertEqual(r.requestHeaders().count, 1)
        XCTAssertEqual(r.requestHeaders()[0].provider, "new")
        let older = try j("""
        [
            {"type":"event","event":{"type":"request/header","seq":2,"time":2,"data":{"header":{"config":{"provider":"old","model":"m1"},"tools":[]}}}}
        ]
        """)
        XCTAssertTrue(r.prepend(records: older, pageHasMore: false))
        XCTAssertEqual(r.requestHeaders().map(\.provider), ["old", "new"])
        XCTAssertFalse(r.hasMore)
    }

    func testLocalesMatchDesktopRequestAndHistory() {
        TrajL.en = false
        XCTAssertEqual(TrajL.requestLabel(3), "请求 #3")
        XCTAssertEqual(TrajL.requestLabelCompaction(2), "请求 #2 · 压缩")
        XCTAssertEqual(TrajL.historyLoadEarlier, "加载更早的历史")
        XCTAssertEqual(TrajL.historyLoadingEarlier, "正在加载更早的历史…")
        XCTAssertEqual(TrajL.tabOptions, "选项")
        XCTAssertEqual(TrajL.tabUsage, "用量")
        XCTAssertEqual(TrajL.detailsResult, "结果")
        XCTAssertEqual(TrajL.detailsCompacted, "已压缩")
    }
}

final class SessionInspectorLogTests: XCTestCase {
    private func event(_ seq: Int64, _ type: String = "custom/event") throws -> JSONValue {
        try JSONValue.parse(
            #"{"type":"event","event":{"seq":\#(seq),"time":1234,"type":"\#(type)","data":{"secret":"test-value"}}}"#
        )
    }
    private func snapshot(_ records: JSONValue...) -> JSONValue {
        jsonObjectKeeping(["type": .string("snapshot"), "records": .array(records)])
    }
    private func chunk(_ text: String) throws -> JSONValue {
        try JSONValue.parse(
            #"{"type":"assistant-stream","frame":{"type":"chunk","attemptId":"a","chunk":{"type":"text-delta","text":"\#(text)"}}}"#
        )
    }

    func testSnapshotReplacesWindowAndResumeDeduplicatesActualEventRecords() throws {
        let log = SessionInspectorLog()
        log.apply(snapshot(try event(20), try event(21)))
        log.apply(jsonObjectKeeping([
            "type": .string("resume"),
            "records": .array([try event(21), try event(22)]),
        ]))
        log.apply(try event(22))
        XCTAssertEqual(log.snapshot().map { $0["seq"].long() }, [20, 21, 22])
        log.apply(snapshot(try event(5)))
        XCTAssertEqual(log.snapshot().map { $0["seq"].long() }, [5])
        XCTAssertEqual(log.snapshot()[0]["data"]["secret"].str(), "test-value")
    }

    func testEarlierAssistantHistoryDoesNotEraseCurrentObservedStream() throws {
        let log = SessionInspectorLog()
        log.apply(snapshot(try event(20)))
        let observed = try chunk("live")
        log.apply(observed)
        let key = inspectorRawRows(log.snapshot()).last?.key
        log.prepend(.array([try event(5, "assistant/message"), try event(20)]))
        XCTAssertEqual(log.snapshot().map { $0["seq"].long() }, [5, 20, nil])
        XCTAssertEqual(log.snapshot().last, observed)
        XCTAssertEqual(inspectorRawRows(log.snapshot()).last?.key, key)
        log.apply(try event(21, "assistant/message"))
        XCTAssertEqual(log.snapshot().map { $0["seq"].long() }, [5, 20, 21])
    }

    func testSnapshotsRemainImmutableAcrossAppendsReplacementAndClear() throws {
        let log = SessionInspectorLog()
        log.apply(snapshot(try event(20)))
        let first = log.snapshot()
        log.apply(try chunk("one"))
        let second = log.snapshot()
        log.apply(try chunk("two"))
        log.apply(try event(21))
        log.prepend(.array([try event(1)]))
        log.clear()
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0]["seq"].long(), 20)
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(second.last?["frame"]["chunk"]["text"].str(), "one")
        XCTAssertTrue(log.snapshot().isEmpty)
    }

    func testBaselinePreservesActualObjectAndControlFramesStayOut() throws {
        let log = SessionInspectorLog()
        let baseline = try JSONValue.parse(#"{"activeAttempt":{"attemptId":"a","stream":[]}}"#)
        log.apply(jsonObjectKeeping([
            "type": .string("snapshot"),
            "records": .array([]),
            "assistantStream": baseline,
        ]))
        log.apply(jsonObjectKeeping(["type": .string("projection"), "key": .string("title"), "seq": .number(7)]))
        XCTAssertEqual(log.snapshot(), [baseline])
        let row = inspectorRawRows(log.snapshot())[0]
        XCTAssertNil(row.seq)
        XCTAssertNil(row.time)
        log.apply(jsonObjectKeeping([
            "type": .string("resume"),
            "records": .array([]),
            "assistantStream": .object([:]),
        ]))
        XCTAssertTrue(log.snapshot().isEmpty)
    }

    func testObservedFramesDoNotInventServerSequenceOrClock() throws {
        let log = SessionInspectorLog()
        log.apply(try chunk("live"))
        let row = inspectorRawRows(log.snapshot())[0]
        XCTAssertNil(row.seq)
        XCTAssertNil(row.time)
    }
}

final class SessionInspectorModelTests: XCTestCase {
    private func obj(_ json: String) throws -> JSONValue { try JSONValue.parse(json) }
    private func event(_ seq: Int64, _ type: String, _ data: String) throws -> JSONValue {
        try obj(#"{"seq":\#(seq),"type":"\#(type)","time":1234,"data":\#(data)}"#)
    }

    func testTypeFilterMatchesDesktopContainmentNotWildcardExpressions() {
        XCTAssertTrue(inspectorTypeMatches("reasoning-delta", filter: "DELTA"))
        XCTAssertTrue(inspectorTypeMatches("reasoning-delta", filter: " ** Reasoning ** "))
        XCTAssertFalse(inspectorTypeMatches("reasoning-delta", filter: "*reasoning*delta*"))
        XCTAssertFalse(inspectorTypeMatches("Item.Tool", filter: "Item.+"))
        XCTAssertTrue(inspectorTypeMatches("anything", filter: " *** "))
    }

    func testFilterKeepsRealAncestorsWithoutCountingThemAsMatches() {
        let tool = InspectorRow(key: "tool", type: "Item.Tool", value: .object([:]))
        let step = InspectorRow(key: "step", type: "ProcessStep", value: .object([:]), children: [tool])
        let group = InspectorRow(key: "group", type: "ChatRow.Process", value: .object([:]), children: [step])
        let other = InspectorRow(key: "text", type: "Item.Text", value: .object([:]))
        let visible = inspectorVisibleRows([group, other], filter: "TOOL", collapsed: [])
        XCTAssertEqual(visible.map(\.row.key), ["group", "step", "tool"])
        XCTAssertEqual(visible.map(\.depth), [0, 1, 2])
        XCTAssertEqual(visible.filter(\.matches).count, 1)
        XCTAssertEqual(
            inspectorVisibleRows([group], filter: "tool", collapsed: ["group"]).map(\.row.key),
            ["group"]
        )
    }

    func testUsesActualProcessStepsAndKeepsHiddenReducerItemsAtTheirRootAnchor() {
        let items: [Item] = [
            .user(Item.User(key: "u", text: "question")),
            .context(Item.Context(key: "context", text: "injected context")),
            .reasoning(Item.Reasoning(key: "reasoning", text: "thinking", live: false, turn: 8, step: 2)),
            .tool(Item.Tool(key: "tool", callId: "call", name: "read", arguments: "{}", status: .ok, turn: 8, step: 2)),
            .text(Item.Text(key: "answer", text: "reply", live: false, turn: 8, step: 2)),
        ]
        let state = InspectorChatState(
            sessionId: "s", items: items, turns: [TurnRecord(turn: 8, startSeq: 10, endSeq: 20, startedAt: 1000, endedAt: 2000)]
        )
        let policy = presentationPolicyFor(.detailed)
        let projected = foldChatItems(items, policy: policy, sessionRunning: false, turnRecords: state.turns)
            .compactMap { row -> ChatRow.Process? in if case .process(let proc) = row { return proc }; return nil }
        let actual = projected.first { !$0.turnSummary }!
        let control = projected.first { $0.turnSummary }!
        let rows = inspectorGroupRows(state, policy: policy)
        XCTAssertEqual(
            rows.map(\.key),
            ["item:u", "item:context", "group:\(control.key)", "group:\(actual.key)", "item:answer"]
        )
        let group = rows.first { $0.key == "group:\(actual.key)" }!
        let controlRow = rows.first { $0.key == "group:\(control.key)" }!
        XCTAssertEqual(controlRow.value["turn"].int(), 8)
        XCTAssertTrue(controlRow.children.isEmpty)
        XCTAssertEqual(
            Set((controlRow.value["controlledKeys"].arr() ?? []).compactMap { $0.str() }),
            control.controlledKeys
        )
        XCTAssertEqual(group.children.map { $0.value["step"].int() }, actual.steps.map(\.step))
        XCTAssertEqual(group.children.flatMap(\.children).map(\.key), actual.members.map { "item:\($0.key)" })
        XCTAssertEqual(rows[1].type, "Item.Context")
        XCTAssertEqual(rows.filter { $0.key == "item:context" }.count, 1)
    }

    func testPartialWindowNeverInventsTurnOrStepForUnownedItems() {
        let orphan = Item.tool(Item.Tool(key: "tool", callId: "call", name: "read", arguments: "{}", status: .running))
        let state = InspectorChatState(sessionId: "s", items: [orphan], hasMore: true)
        let group = inspectorGroupRows(state, policy: presentationPolicyFor(.compact))[0]
        XCTAssertEqual(group.type, "ChatRow.Process")
        XCTAssertNil(group.value["turn"].int())
        XCTAssertNil(group.children[0].value["step"].int())
        XCTAssertNil(group.children[0].children[0].value["turn"].int())
    }

    func testVerboseProjectionKeepsProcessIdentityButDoesNotGroupItsPresentation() {
        let state = InspectorChatState(
            sessionId: "s",
            items: [.tool(Item.Tool(key: "t", callId: "c", name: "read", arguments: "{}", status: .ok, turn: 1, step: 1))]
        )
        let rows = inspectorGroupRows(state, policy: presentationPolicyFor(.verbose))
        XCTAssertEqual(rows.map(\.type), ["ChatRow.Process"])
        XCTAssertEqual(rows[0].value["grouped"].bool(), false)
        XCTAssertEqual(rows[0].children[0].children[0].value["callId"].str(), "c")
    }

    func testUtcClockKeepsMillisecondsWithoutDateOrSuffix() {
        XCTAssertEqual(inspectorTime(0), "00:00:00.000")
        XCTAssertEqual(inspectorTime(-1), "23:59:59.999")
        XCTAssertEqual(inspectorTime(86_401_234), "00:00:01.234")
        XCTAssertEqual(inspectorTime(nil), "")
    }

    func testRawRangesRetainEndEventsAndDoNotInventMissingStarts() throws {
        let records = try [
            event(1, "step/end", #"{"turn":3,"step":1}"#),
            event(2, "turn/start", #"{"turn":4}"#),
            event(3, "step/start", #"{"turn":4,"step":1}"#),
            event(4, "custom/event", #"{"turn":4,"step":1,"payload":{"secret":"verbatim"}}"#),
            event(5, "step/end", #"{"turn":4,"step":1}"#),
            event(6, "turn/end", #"{"turn":4}"#),
            event(7, "outside", "{}"),
        ]
        let rows = inspectorRawRows(records)
        XCTAssertEqual(rows.map(\.key), ["event:1", "event:2", "event:7"])
        XCTAssertEqual(rows[1].children.map(\.key), ["event:3", "event:6"])
        let nested = rows[1].children[0].children
        XCTAssertEqual(nested.map(\.key), ["event:4", "event:5"])
        XCTAssertEqual(nested[0].value, records[3])
        XCTAssertEqual(nested[0].identity, "4")
        XCTAssertEqual(nested[0].location, "4/1")
        XCTAssertFalse(rows[1].defaultCollapsed)
    }

    func testCompactStreamsExpandExactTimesAndKeepIndexedBlockAncestry() throws {
        let record = try event(8, "assistant/message", """
        {"turn":2,"step":3,"stream":[
            {"type":"chunk","time":100,"chunk":{"type":"block-start","index":0,"blockType":"reasoning"}},
            {"type":"chunk","time":101,"chunk":{"type":"block-start","index":1,"blockType":"text"}},
            {"type":"reasoning-chunks","index":0,"time0":102,"texts":["first"," second"],"dt":[-1]},
            {"type":"text-chunks","index":1,"time0":104,"texts":["a","b"],"dt":[0]},
            {"type":"chunk","time":105,"chunk":{"type":"block-end","index":0}},
            {"type":"tool-call-chunks","index":2,"time0":106,"id":"call","args":["{","}"],"dt":[2]},
            {"type":"tool-call-chunks","index":3,"time0":109,"id":"named","name":"read","args":["{}"],"dt":[]}
        ]}
        """)
        let root = inspectorRawRows([record])[0]
        let reasoning = root.children[0]
        XCTAssertEqual(root.value, record)
        XCTAssertEqual(reasoning.type, "block-start")
        XCTAssertEqual(reasoning.children.map(\.identity), ["2", "3", "6"])
        XCTAssertEqual(reasoning.children.map(\.time), [102, 101, 105])
        XCTAssertEqual(reasoning.summary, "blockType: reasoning · first second")
        XCTAssertTrue(reasoning.defaultCollapsed)
        XCTAssertEqual(root.children[1].children.map { $0.value["text"].str() }, ["a", "b"])
        let unnamed = root.children[2]
        XCTAssertEqual(unnamed.type, "tool-call-delta")
        XCTAssertEqual(unnamed.value["argumentsDelta"].str(), "{")
        XCTAssertNil(unnamed.value.obj()?["name"])
        XCTAssertEqual(root.children[3].time, 108)
        XCTAssertEqual(root.children[4].value["name"].str(), "read")
        XCTAssertTrue(root.children.allSatisfy { $0.location == "2/3" })
    }

    func testFilterOpensDefaultClosedBlocksAndSuggestionsIncludeHiddenDescendants() {
        let delta = InspectorRow(key: "delta", type: "reasoning-delta", value: .object([:]))
        let block = InspectorRow(key: "block", type: "block-start", value: .object([:]), children: [delta], defaultCollapsed: true)
        let root = InspectorRow(key: "root", type: "assistant/message", value: .object([:]), children: [block])
        let rows = [root]
        XCTAssertEqual(inspectorVisibleRows(rows, filter: "", collapsed: []).map(\.row.key), ["root", "block"])
        XCTAssertEqual(inspectorVisibleRows(rows, filter: "", collapsed: [], expanded: ["block"]).count, 3)
        let filtered = inspectorVisibleRows(rows, filter: "*delta*", collapsed: [])
        XCTAssertEqual(filtered.map(\.row.key), ["root", "block", "delta"])
        XCTAssertEqual(filtered.map(\.matches), [false, false, true])
        XCTAssertEqual(inspectorTypeSuggestions(rows, filter: "delta"), ["reasoning-delta"])
        XCTAssertEqual(inspectorTypeSuggestions(rows, filter: ""), ["assistant/message", "block-start", "reasoning-delta"])
        XCTAssertEqual(inspectorVisibleRows(rows, filter: "delta", collapsed: ["block"]).count, 2)
    }

    func testLiveBaselineAndFramesShareOneAttemptWithoutLosingOriginalJson() throws {
        let baseline = try obj("""
        {"revision":3,"activeAttempt":{"attemptId":"a","turn":9,"step":2,"stream":[
            {"type":"chunk","time":1,"chunk":{"type":"block-start","index":0,"blockType":"reasoning"}},
            {"type":"reasoning-chunks","index":0,"time0":2,"texts":["one"],"dt":[]}
        ]}}
        """)
        let frame = try obj("""
        {"type":"assistant-stream","frame":{"type":"chunk","attemptId":"a","revision":3,"index":2,"time":3,
            "chunk":{"type":"reasoning-delta","index":0,"text":"two"}}}
        """)
        let root = inspectorRawRows([baseline, frame])[0]
        XCTAssertEqual(root.type, "assistant/live")
        XCTAssertEqual(root.identity, "a")
        XCTAssertEqual(root.location, "9/2")
        XCTAssertNil(root.seq)
        XCTAssertEqual(root.time, 3)
        XCTAssertEqual(root.value["records"].arr(), [baseline, frame])
        XCTAssertEqual(root.children[0].children.map(\.identity), ["1", "2"])
        XCTAssertEqual(root.children[0].summary, "blockType: reasoning · onetwo")
    }

    func testMissingBlockStartAndMalformedCompactRecordsRemainInspectable() throws {
        let record = try event(1, "assistant/attempt", """
        {"stream":[
            {"type":"chunk","time":1,"chunk":{"type":"reasoning-delta","index":5,"text":"orphan"}},
            {"type":"text-chunks","index":2,"time0":3,"texts":["a","b"],"dt":[]},
            {"type":"future-record","payload":{"nested":true}}
        ]}
        """)
        let root = inspectorRawRows([record])[0]
        XCTAssertEqual(root.children.map(\.type), ["reasoning-delta", "text-chunks", "future-record"])
        XCTAssertTrue(root.children.allSatisfy(\.children.isEmpty))
        XCTAssertEqual(root.children[1].value, record["data"]["stream"].arr()![1])
        XCTAssertEqual(root.value, record)
    }

    func testPreviewsOmitColumnMetadataButNeverAlterRawValues() throws {
        let delta = try obj(#"{"type":"tool-call-delta","index":2,"id":"c","argumentsDelta":"{ exact }","time":500}"#)
        XCTAssertEqual(inspectorPreview(delta), "{ exact }")
        XCTAssertEqual(inspectorPreview(try obj(#"{"type":"text-delta","index":2,"text":"answer"}"#)), "index: 2 · text: answer")
        let raw = try obj(#"{"type":"reasoning-delta","index":0,"text":"\#(String(repeating: "a", count: 300))"}"#)
        XCTAssertEqual(inspectorPreview(raw).count, 180)
        XCTAssertEqual(raw["text"].str()?.count, 300)
        XCTAssertEqual(inspectorPreview(try obj(#"{"key":"k","turn":1,"text":"body"}"#), hiddenRootFields: ["key", "turn"]), "body")
    }

    func testNavigationUsesCallIdSequenceAndReasoningBlockAndRejectsUnknownItems() throws {
        let tool = Item.tool(Item.Tool(key: "tool", callId: "call", name: "read", arguments: "{}", status: .ok, turn: 2, step: 3))
        let reasoning = Item.reasoning(Item.Reasoning(key: "reason", text: "think", live: false, turn: 2, step: 3, seq: 5))
        let answer = Item.text(Item.Text(key: "answer", text: "reply", live: false, seq: 5, turn: 2, step: 3))
        let state = InspectorChatState(sessionId: "s", items: [tool, reasoning, answer])
        let rows = inspectorRawRows(try [
            event(4, "tool/call", #"{"callId":"call","turn":2,"step":3}"#),
            event(5, "assistant/message", """
            {"turn":2,"step":3,"stream":[
                {"type":"chunk","time":1,"chunk":{"type":"block-start","index":0,"blockType":"reasoning"}}
            ]}
            """),
        ])
        XCTAssertEqual(inspectorRowForItem(rows, item: tool)?.key, "event:4")
        XCTAssertEqual(inspectorRowForItem(rows, item: answer)?.key, "event:5")
        let block = try XCTUnwrap(inspectorRowForItem(rows, item: reasoning))
        XCTAssertEqual(block.type, "block-start")
        XCTAssertEqual(inspectorItemForRow(state, row: block), "reason")
        XCTAssertEqual(inspectorItemForRow(state, row: rows[0]), "tool")
        XCTAssertNil(inspectorRowForItem(rows, item: .notice(Item.Notice(key: "unknown", text: "no location"))))
        XCTAssertNil(inspectorItemForRow(state, row: InspectorRow(key: "missing", type: "unknown", value: .object([:]))))
        let projected = inspectorGroupRows(state, policy: presentationPolicyFor(.detailed))
        XCTAssertEqual(inspectorRowForItem(projected, item: tool)?.key, "item:tool")
    }

    func testUnsafeOrNonNumericCompactTimingIsNotInvented() throws {
        let record = try event(1, "assistant/message", """
        {"stream":[
            {"type":"text-chunks","index":0,"time0":9007199254740991,"texts":["a","b"],"dt":[1]},
            {"type":"text-chunks","index":0,"time0":1,"texts":["a","b"],"dt":["2"]},
            {"type":"text-chunks","index":-1,"time0":1,"texts":["a"],"dt":[]}
        ]}
        """)
        let root = inspectorRawRows([record])[0]
        XCTAssertEqual(root.children.map(\.type), ["text-chunks", "text-chunks", "text-chunks"])
        XCTAssertEqual(root.children.map(\.value), record["data"]["stream"].arr())
    }

    func testProjectedColumnsUseOnlyActualItemIdentityLocationAndTime() {
        let state = InspectorChatState(sessionId: "s", items: [
            .text(Item.Text(key: "answer", text: "reply", live: false, at: 1234, seq: 20, turn: 3, step: 2)),
            .notice(Item.Notice(key: "notice", text: "message", turn: 3)),
        ])
        let rows = inspectorGroupRows(state, policy: presentationPolicyFor(.verbose))
        let answer = rows.first { $0.key == "item:answer" }!
        XCTAssertEqual(answer.identity, "answer")
        XCTAssertEqual(answer.location, "3/2")
        XCTAssertEqual(answer.seq, 20)
        XCTAssertEqual(answer.time, 1234)
        XCTAssertEqual(inspectorTime(answer.time), "00:00:01.234")
        let notice = rows.first { $0.key == "item:notice" }!
        XCTAssertEqual(notice.value["turn"].int(), 3)
        XCTAssertEqual(notice.location, "3")
        XCTAssertNil(notice.time)
    }
}

private extension Array {
    var single: Element {
        precondition(count == 1)
        return self[0]
    }
}
