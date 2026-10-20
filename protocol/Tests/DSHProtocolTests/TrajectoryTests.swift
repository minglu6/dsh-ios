import XCTest
@testable import DSHProtocol

final class TrajectoryTimelineTests: XCTestCase {
    func testLaneAssignmentMatchesDesktop() {
        XCTAssertEqual(trajectoryLaneFor("system"), 0)
        XCTAssertEqual(trajectoryLaneFor("用户"), 0)
        XCTAssertEqual(trajectoryLaneFor("上下文"), 0)
        XCTAssertEqual(trajectoryLaneFor("助手"), 1)
        XCTAssertEqual(trajectoryLaneFor("message"), 1)
        XCTAssertEqual(trajectoryLaneFor("compacted"), 1)
        XCTAssertEqual(trajectoryLaneFor("工具"), 2)
        XCTAssertEqual(trajectoryLaneFor("tool"), 2)
        XCTAssertEqual(trajectoryLaneFor("subtool"), 2)
    }

    func testSequenceModeUsesEqualWidthSlotsAndSemanticLanes() {
        let cells = [
            TrajectoryTimelineCell(key: "a", kind: "助手", label: "assistant", turn: 1, startedAt: nil, timeSeconds: nil),
            TrajectoryTimelineCell(key: "t", kind: "工具", label: "bash", turn: 1, startedAt: nil, timeSeconds: nil),
            TrajectoryTimelineCell(key: "u", kind: "用户", label: "unknown", turn: 1, startedAt: nil, timeSeconds: nil),
        ]
        let model = deriveTrajectoryTimeline(cells, mode: .sequence)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.start, 0.0)
        XCTAssertEqual(model?.end, 3.0)
        XCTAssertEqual(model?.spans, [
            TrajectoryTimelineSpan(key: "a", kind: "message", lane: 1, start: 0.0, end: 1.0, label: "assistant"),
            TrajectoryTimelineSpan(key: "t", kind: "tool", lane: 2, start: 1.0, end: 2.0, label: "bash"),
            TrajectoryTimelineSpan(key: "u", kind: "user", lane: 0, start: 2.0, end: 3.0, label: "unknown"),
        ])
        XCTAssertEqual(model?.turnBoundaries, [TrajectoryTimelineTurnBoundary(turn: 1, time: 0.0)])
    }

    func testDurationModeCompressesIdleGapsWhileActualRetainsWallTime() {
        let cells = [
            TrajectoryTimelineCell(key: "m1", kind: "助手", label: "first", turn: 1, startedAt: 1_000, timeSeconds: 1.0),
            TrajectoryTimelineCell(key: "t1", kind: "工具", label: "within-turn gap", turn: 1, startedAt: 4_000, timeSeconds: 1.0),
            TrajectoryTimelineCell(key: "m2", kind: "助手", label: "after user idle", turn: 2, startedAt: 40_000, timeSeconds: 1.0),
        ]
        let sequence = deriveTrajectoryTimeline(cells, mode: .sequence)!
        XCTAssertEqual(sequence.spans.map { ($0.start, $0.end) }.map { "\($0.0)-\($0.1)" }, ["0.0-1.0", "1.0-2.0", "2.0-3.0"])

        let duration = deriveTrajectoryTimeline(cells, mode: .duration)!
        XCTAssertEqual(duration.start, 1_000.0)
        XCTAssertEqual(duration.end, 4_000.0)
        XCTAssertEqual(duration.spans.map { ($0.start, $0.end) }, [
            (1_000.0, 2_000.0), (2_000.0, 3_000.0), (3_000.0, 4_000.0),
        ])
        XCTAssertEqual(
            duration.turnBoundaries,
            [TrajectoryTimelineTurnBoundary(turn: 1, time: 1_000.0), TrajectoryTimelineTurnBoundary(turn: 2, time: 3_000.0)]
        )

        let actual = deriveTrajectoryTimeline(cells, mode: .actual)!
        XCTAssertEqual(actual.start, 1_000.0)
        XCTAssertEqual(actual.end, 41_000.0)
        XCTAssertEqual(actual.spans.map { ($0.start, $0.end) }, [
            (1_000.0, 2_000.0), (4_000.0, 5_000.0), (40_000.0, 41_000.0),
        ])
    }

    func testEmptyTimelineIsNull() {
        XCTAssertNil(deriveTrajectoryTimeline([]))
    }
}

final class TrajectoryToolbarParityTests: XCTestCase {
    func testToolbarSearchUsesOfficialSearchOutlineSize11() {
        XCTAssertTrue(trajectoryToolbarSearchUsesOfficialGlyph)
        XCTAssertEqual(trajectoryToolbarSearchSymbol(), "official.searchOutline")
        XCTAssertEqual(trajectoryToolbarSearchSymbol(), sidebarSearchSymbol())
        XCTAssertEqual(trajectoryToolbarSearchIconSizePoints, 11)
        XCTAssertEqual(trajectoryToolbarSearchIconStrokeWidth, 1)
        XCTAssertEqual(trajectoryToolbarSearchIconStrokeWidth, sidebarSearchIconStrokeWidth)
        XCTAssertTrue(isForbiddenSystemSearchSymbol("magnifyingglass"))
        XCTAssertFalse(isForbiddenSystemSearchSymbol("official.searchOutline"))
        XCTAssertTrue(sidebarSearchCirclePath.hasPrefix("M6.58727 11.8586"))
        XCTAssertEqual(sidebarSearchHandlePath, "M10.2991 10.3933L14.7783 14.8725")
    }

    func testToolbarDurationUsesInlineClockSvgNotSystemOrIconClock() {
        XCTAssertTrue(trajectoryToolbarClockUsesOfficialGlyph)
        XCTAssertEqual(trajectoryToolbarClockSymbol(), "official.trajectoryClock")
        XCTAssertEqual(trajectoryToolbarClockIconSizePoints, 12)
        XCTAssertEqual(trajectoryToolbarClockIconStrokeWidth, 1.25)
        XCTAssertEqual(trajectoryToolbarClockCircleCenterX, 8)
        XCTAssertEqual(trajectoryToolbarClockCircleCenterY, 8)
        XCTAssertEqual(trajectoryToolbarClockCircleRadius, 5.25)
        XCTAssertEqual(trajectoryToolbarClockHandsPath, "M8 4.75V8l2.25 1.5")
        XCTAssertEqual(trajectoryToolbarClockIconUserStrokeWidth, 1.25 * 16 / 12, accuracy: 1e-12)
        XCTAssertNotEqual(trajectoryToolbarClockHandsPath, "M8 4.31V8.46L11 10.08")
        XCTAssertNotEqual(trajectoryToolbarClockCircleRadius, 6)
        XCTAssertTrue(isForbiddenTrajectoryToolbarClockSymbol("clock"))
        XCTAssertTrue(isForbiddenTrajectoryToolbarClockSymbol("clock.fill"))
        XCTAssertTrue(isForbiddenTrajectoryToolbarClockSymbol("official.clockOutline"))
        XCTAssertTrue(isForbiddenTrajectoryToolbarClockSymbol("IconClockOutlineRegular"))
        XCTAssertTrue(isForbiddenTrajectoryToolbarClockSymbol("IconClockOutlineMedium"))
        XCTAssertTrue(isForbiddenTrajectoryToolbarClockSymbol("IconClockOutlineArtwork"))
        XCTAssertTrue(isForbiddenTrajectoryToolbarClockSymbol("IconClockOutline"))
        XCTAssertFalse(isForbiddenTrajectoryToolbarClockSymbol("official.trajectoryClock"))
    }

    func testKindIconUsesDesktopArtworkNotSystemSymbols() {
        XCTAssertEqual(trajectoryKindIconSizePoints, 13)
        XCTAssertEqual(trajectoryInformationIconSizePoints, 14)
        XCTAssertEqual(trajectoryKindIconSizePoints(for: TrajL.kindContext), 14)
        XCTAssertEqual(trajectoryKindIconSizePoints(for: TrajL.kindAssistant), 13)
        XCTAssertEqual(trajectoryKindTagSizePoints, 19)
        XCTAssertEqual(trajectoryKindTagRadiusPoints, 4)
        XCTAssertEqual(dswRadiusXsPoints, 4)
        XCTAssertEqual(trajectoryAssistantForegroundHex(dark: false), srgbHex(srgbMix(dswBrandPrimaryNewMixLight, dswStateErrorSecondary, amountA: 0.60)))
        XCTAssertEqual(trajectoryAssistantForegroundHex(dark: true), srgbHex(srgbMix(dswBrandPrimaryNewMixDark, dswStateErrorSecondary, amountA: 0.60)))
        XCTAssertEqual(dswBrandPrimaryNewMixDark, 0x005686FE)
        XCTAssertNotEqual(dswBrandPrimaryNewMixDark, 0x007AAAFF)
        XCTAssertEqual(trajectoryContextBackgroundHex(dark: false), srgbHex(dswStateSuccessTertiaryLight))
        XCTAssertEqual(trajectoryContextBackgroundHex(dark: true), srgbHex(dswStateSuccessTertiaryDark))
        XCTAssertEqual(
            trajectoryContextForegroundHex(dark: false),
            srgbHex(srgbMix(dswStateSuccessPrimary, dswLabelSecondaryLight, amountA: 0.68))
        )
        XCTAssertEqual(trajectoryKindIconStrokeWidth, 1)
        XCTAssertEqual(trajectoryToolWrenchStrokeWidth, 1.5)
        XCTAssertEqual(trajectoryKindSymbol(TrajL.kindUser), "official.userOutline")
        XCTAssertEqual(trajectoryKindSymbol(TrajL.kindAssistant), "official.sparkle")
        XCTAssertEqual(trajectoryKindSymbol(TrajL.kindTool), "official.toolWrench")
        XCTAssertEqual(trajectoryKindSymbol(TrajL.kindSubtool), "official.toolWrench")
        XCTAssertEqual(trajectoryKindSymbol(TrajL.kindContext), "official.information")
        XCTAssertEqual(trajectoryKindSymbol(TrajL.kindCompacted), "official.compacted")
        XCTAssertEqual(trajectoryKindSymbol(TrajL.kindSystem), "official.settingsOutlineRegular")
        XCTAssertNil(trajectoryKindSymbol("unknown"))
        XCTAssertTrue(trajectoryUserHeadPath.hasPrefix("M8 8.25C9.51878"))
        XCTAssertEqual(trajectoryUserShoulderPath, "M2.5 14.5C2.5 11.5 5.25 10.25 8 10.25C10.75 10.25 13.5 11.5 13.5 14.5")
        XCTAssertTrue(trajectorySparkleLargePath.hasPrefix("M5.875 3C5.875"))
        XCTAssertTrue(trajectoryToolWrenchPath.hasPrefix("M14 3.3a3.8 3.8"))
        XCTAssertEqual(trajectoryInformationStemPath, "M8 7.75v3.4")
        XCTAssertEqual(trajectoryInformationCircleRadius, 6.7)
        XCTAssertTrue(isForbiddenTrajectoryKindSymbol("person"))
        XCTAssertTrue(isForbiddenTrajectoryKindSymbol("sparkle"))
        XCTAssertTrue(isForbiddenTrajectoryKindSymbol("wrench.and.screwdriver"))
        XCTAssertTrue(isForbiddenTrajectoryKindSymbol("gearshape"))
        XCTAssertFalse(isForbiddenTrajectoryKindSymbol("official.userOutline"))
        XCTAssertFalse(isForbiddenTrajectoryKindSymbol("official.sparkle"))
    }
}

final class TrajectoryBuilderTests: XCTestCase {
    func testGroupsUserTurnWithTools() {
        let turns = buildTrajectory([
            .user(Item.User(key: "u1", text: "hello")),
            .reasoning(Item.Reasoning(key: "r1", text: "think", durationMs: 1000, live: false)),
            .tool(Item.Tool(key: "t1", callId: "c1", name: "read", arguments: #"{"path":"a.kt"}"#, status: .ok, startedAt: 0, endedAt: 40)),
            .text(Item.Text(key: "x1", text: "done", live: false)),
            .user(Item.User(key: "u2", text: "more")),
            .text(Item.Text(key: "x2", text: "ok", live: false)),
        ])
        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(turns[0].index, 1)
        XCTAssertTrue(turns[0].rows.contains { $0.kind == TrajL.kindUser })
        XCTAssertTrue(turns[0].rows.contains { $0.kind == TrajL.kindTool && $0.title.hasPrefix("read") })
        XCTAssertTrue(turns[0].rows.allSatisfy { $0.kind != TrajL.recordThinking })
        XCTAssertEqual(turns[1].index, 2)
    }

    func testAssistantRowShowsUsageAndElapsedFromStepRecords() throws {
        let r = TranscriptReducer()
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"hasMore":false,"projections":{}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"event","event":{"type":"turn/start","seq":1,"time":1000,"data":{"turn":1}}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"event","event":{"type":"user/message","seq":2,"time":1001,"data":{"content":[{"type":"text","text":"你好"}],"source":{"kind":"user"},"role":"user"}}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"event","event":{"type":"step/start","seq":3,"time":10000,"data":{"turn":1,"step":1}}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"assistant/message","seq":4,"time":12200,"data":{"turn":1,"step":1,"stream":[],"usage":{"inputTokens":17730,"outputTokens":49},"message":{"source":{"provider":"deepseek","model":"deepseek-v4.1-flash"},"content":[{"type":"text","text":"你好！有什么可以帮忙的？"}]}}}}
        """)))
        let turns = buildTrajectory(r.items(), steps: r.stepRecords())
        XCTAssertEqual(turns.count, 1)
        let assistant = turns[0].rows.first { $0.kind == TrajL.kindAssistant }
        XCTAssertEqual(assistant?.title, "你好！有什么可以帮忙的？")
        XCTAssertEqual(assistant?.input, "17.7k")
        XCTAssertEqual(assistant?.output, "49")
        XCTAssertEqual(assistant?.think, "—")
        XCTAssertTrue(assistant?.time.hasPrefix("2.2") == true, "time=\(assistant?.time ?? "")")
        XCTAssertEqual(turns[0].rows.first { $0.kind == TrajL.kindUser }?.time, formatElapsed(0))
    }

    func testInterruptedAssistantIsErrorNotSystemNotice() throws {
        let r = TranscriptReducer()
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"hasMore":false,"projections":{}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"event","event":{"type":"turn/start","seq":1,"time":1000,"data":{"turn":1}}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"event","event":{"type":"user/message","seq":2,"time":1001,"data":{"content":[{"type":"text","text":"hi"}],"source":{"kind":"user"},"role":"user"}}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse(#"{"type":"event","event":{"type":"step/start","seq":3,"time":2000,"data":{"turn":1,"step":1}}}"#)))
        XCTAssertTrue(r.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"assistant/message","seq":4,"time":2500,"data":{"turn":1,"step":1,"interrupted":true,"stream":[],"usage":{},"message":{"content":[{"type":"text","text":"partial"}]}}}}
        """)))
        let notices = r.items().compactMap { item -> Item.Notice? in
            if case .notice(let n) = item { return n }
            return nil
        }
        XCTAssertEqual(notices.map(\.kind), [.stopped])
        XCTAssertEqual(notices.map { noticeChatTitle($0, english: false) }, ["已停止"])
        let assistant = buildTrajectory(r.items(), steps: r.stepRecords())[0].rows.first { $0.kind == TrajL.kindAssistant }
        XCTAssertEqual(assistant?.isError, true)
        XCTAssertEqual(trajectoryStatusLabel(trajRowState(assistant!)), "失败")
    }

    func testKindSystemInitialAndUpdated() {
        let turns = buildTrajectory([
            .system(Item.System(key: "sys1", label: TrajL.layoutInitialSystemPrompt, text: "You are helpful.", at: 100, toolsJson: #"[{"name":"read","description":"d","parameters":{}}]"#)),
            .system(Item.System(
                key: "sys2", label: TrajL.layoutSystemPromptUpdated, text: "You are updated.", at: 150,
                previousText: "You are helpful.",
                toolsJson: #"[{"name":"read","description":"d","parameters":{}},{"name":"bash","description":"b","parameters":{}}]"#,
                previousToolsJson: #"[{"name":"read","description":"d","parameters":{}}]"#
            )),
            .user(Item.User(key: "u1", text: "你好", at: 200)),
        ])
        let sys = turns[0].rows.filter { $0.kind == TrajL.kindSystem }
        XCTAssertEqual(sys.count, 2)
        XCTAssertEqual(sys[0].title, TrajL.layoutInitialSystemPrompt)
        XCTAssertEqual(trajDetailTabs(sys[0]), [.systemPrompt, .tools])
        XCTAssertEqual(trajDetailTabs(sys[1]), [.diff, .systemPrompt, .tools])
        XCTAssertNotNil(toolCatalogDiff(previousJson: sys[1].previousToolsJson, currentJson: sys[1].toolsJson))
    }

    func testKindUserWithSourceTab() {
        let row = buildTrajectory([
            .user(Item.User(key: "u1", text: "hello", messageSourceJson: #"{"kind":"user","rpcId":"r1"}"#)),
        ])[0].rows.first { $0.kind == TrajL.kindUser }!
        XCTAssertEqual(trajDetailTabs(row), [.overview, .preview, .raw, .source])
    }

    func testKindAssistantPreviewTabsAndToolCallOnly() {
        let toolOnly = buildTrajectory([
            .user(Item.User(key: "u", text: "x")),
            .text(Item.Text(key: "t", text: "", live: false)),
        ])[0].rows.first { $0.kind == TrajL.kindAssistant }!
        XCTAssertTrue(toolOnly.toolCallOnly)
        XCTAssertEqual(toolOnly.title, TrajL.layoutToolCallOnly)
        XCTAssertEqual(trajDetailTabs(toolOnly), [.overview, .preview, .raw])
    }

    func testKindToolDetailTabsAndInlineResult() {
        let tool = Item.Tool(
            key: "t1", callId: "c1", name: "read",
            arguments: #"{"file_path":"/tmp/a.yml","offset":12,"limit":40}"#,
            status: .ok, result: "<path>/tmp/a.yml</path>",
            startedAt: 1_000, endedAt: 1_011,
            turn: 6, step: 1,
            schemaJson: #"{"name":"read","description":"Read a UTF-8 text file and return line-numbered content.","parameters":{"type":"object"}}"#
        )
        let row = buildTrajectory([.user(Item.User(key: "u1", text: "hi")), .tool(tool)])[0].rows.first { $0.kind == TrajL.kindTool }!
        XCTAssertEqual(trajDetailTabs(row), [.overview, .input, .output, .schema, .timing])
        XCTAssertEqual(trajDetailKindLabel(row.kind), TrajL.kindTool)
        XCTAssertEqual(trajDetailLocation(row, turnIndex: 1), "\(TrajL.turnLabel(6)) · \(TrajL.groupStep(1))")
        XCTAssertEqual(trajectoryStatusLabel(trajRowState(row)), TrajL.statusCompleted)
        XCTAssertEqual(row.title, #"read {"file_path":"/tmp/a.yml","offset":12,"limit":40}"#)
        XCTAssertNotNil(row.resultPreview)
        XCTAssertTrue(row.resultPreview?.contains("<path>") == true)
    }

    func testKindSubtoolFromParentCallId() {
        let parent = Item.Tool(
            key: "t0", callId: "root", name: ptcToolName,
            arguments: #"{"code":"await read({path:'a'})","description":"read a"}"#,
            status: .ok, turn: 1, step: 1
        )
        let sub = Item.Tool(
            key: "t1", callId: "root:ptc:1", name: "read", arguments: #"{"path":"a"}"#,
            status: .ok, result: "ok", turn: 1, step: 1, parentCallId: "root"
        )
        let rows = buildTrajectory([.user(Item.User(key: "u", text: "hi")), .tool(parent), .tool(sub)])[0].rows
        XCTAssertTrue(rows.contains { $0.kind == TrajL.kindTool && $0.toolName == ptcToolName })
        let subRow = rows.first { $0.kind == TrajL.kindSubtool }!
        XCTAssertEqual(subRow.depth, 2)
        XCTAssertTrue(trajDetailTabs(subRow).contains(.overview))
        let runCode = rows.first { $0.toolName == ptcToolName }!
        XCTAssertTrue(trajDetailTabs(runCode).contains(.code))
        XCTAssertTrue(runCode.title.hasPrefix("\(ptcToolName) · "))
    }

    func testKindCompactedRunningAndDone() {
        let running = compactedFrom(Item.Compacted(key: "c1", compactionId: "id1", status: .running, startedAt: 10))
        XCTAssertEqual(running.title, TrajL.layoutCompacting)
        XCTAssertEqual(trajectoryStatusLabel(trajRowState(running)), TrajL.statusPending)
        XCTAssertEqual(trajDetailTabs(running), [.overview, .rawOutput])

        let done = compactedFrom(Item.Compacted(
            key: "c2", compactionId: "id2", status: .ok, summary: "Kept the goal.", startedAt: 10, endedAt: 40
        ))
        XCTAssertEqual(done.title, "Kept the goal.")
        XCTAssertEqual(trajectoryStatusLabel(trajRowState(done)), TrajL.statusCompleted)

        let failed = compactedFrom(Item.Compacted(
            key: "c3", compactionId: "id3", status: .error, interrupted: true, startedAt: 10, endedAt: 20
        ))
        XCTAssertEqual(failed.title, TrajL.layoutCompactionInterrupted)
        XCTAssertTrue(failed.isError)
    }

    func testPendingToolOmitsResultTabAndShowsWaiting() {
        let tool = Item.Tool(key: "t1", callId: "c1", name: "bash", arguments: #"{"command":"ls"}"#, status: .running, turn: 1, step: 2)
        let row = buildTrajectory([.user(Item.User(key: "u1", text: "hi")), .tool(tool)])[0].rows.first { $0.kind == TrajL.kindTool }!
        XCTAssertEqual(trajDetailTabs(row), [.overview, .input, .schema, .timing])
        XCTAssertEqual(trajectoryStatusLabel(trajRowState(row)), TrajL.statusPending)
        XCTAssertEqual(trajDetailLocation(row, turnIndex: 1), "\(TrajL.turnLabel(1)) · \(TrajL.groupStep(2))")
    }

    func testSearchMatchesAndTerms() {
        let turns = buildTrajectory([
            .user(Item.User(key: "u1", text: "hello world")),
            .context(Item.Context(key: "x1", text: "runtime context cwd=/tmp", sourceKind: "runtime-context")),
            .tool(Item.Tool(key: "t1", callId: "c1", name: "read", arguments: #"{"path":"a.kt"}"#, status: .ok)),
        ])
        XCTAssertNil(trajectorySearchMatches(turns, query: "  "))
        let hits = trajectorySearchMatches(turns, query: "runtime cwd")
        XCTAssertEqual(hits, Set(["x1"]))
        XCTAssertTrue(trajectorySearchMatches(turns, query: "read")?.contains("t1") == true)
    }

    func testThroughputZeroWindowUsesOfficialUnavailableCopy() {
        let row = TrajRow(
            key: "a1",
            depth: 1,
            kind: TrajL.kindAssistant,
            title: "hi",
            firstTokenTime: 1_000,
            startedAt: 1_000,
            timeSeconds: 0,
            outputTokens: 80
        )
        XCTAssertEqual(formatThroughput(row), TrajL.timingNotAvailable)
        XCTAssertFalse(formatThroughput(row).contains("时长过短"))
    }

    func testFollowSetFeedbackPayloadKeepsNullRating() {
        // Host clears a rating with explicit JSON null, not an omitted key.
        let encoded = try? JSONValue.object([
            "sessionId": .string("s"),
            "messageId": .string("m"),
            "rating": .null,
        ]).encodeString()
        XCTAssertTrue(encoded?.contains("\"rating\"") == true)
        XCTAssertTrue(encoded?.contains("null") == true)
    }

    private func compactedFrom(_ item: Item.Compacted) -> TrajRow {
        buildTrajectory([.user(Item.User(key: "u", text: "hi")), .compacted(item)])[0]
            .rows.first { $0.kind == TrajL.kindCompacted }!
    }
}

final class TrajectoryIndexTests: XCTestCase {
    private func request(
        _ number: Int, turn: Int? = 1, step: Int? = 1,
        resultKey: String? = nil, purpose: TrajectoryRequest.Purpose = .assistant
    ) -> TrajectoryRequest {
        TrajectoryRequest(
            number: number, identity: "request-\(number)", purpose: purpose,
            turn: turn, step: step, group: "", status: .complete, resultKey: resultKey
        )
    }

    private func row(_ key: String, _ kind: String, step: Int? = 1) -> TrajRow {
        // Fallback uses the enclosing turn, not the row's optional turn metadata.
        TrajRow(key: key, depth: 0, kind: kind, title: key, turn: 99, step: step)
    }

    func testResultKeysOverrideFallbackAcrossTurnsAndLaterRequestsWin() {
        let turns = [
            TrajTurn(index: 1, rows: [row("tool", TrajL.kindTool), row("assistant", TrajL.kindAssistant)]),
            TrajTurn(index: 2, rows: [row("result", TrajL.kindSystem), row("cmp7", TrajL.kindCompacted)]),
        ]
        let requests = [
            request(1, resultKey: "result"),
            request(2, resultKey: "missing"),
            request(3, turn: nil, step: nil, resultKey: "result"),
            request(4, turn: nil, step: nil, resultKey: "cmp7", purpose: .compaction),
            request(5, resultKey: "missing", purpose: .compaction),
        ]
        let boundaries = trajectoryRequestBoundaries(requests, turns: turns)
        XCTAssertEqual(boundaries, ["result": requests[2], "assistant": requests[1], "cmp7": requests[3]])
    }

    func testFallbackPrefersFirstAssistantAndOnlyFirstMatchingTurn() {
        let turns = [
            TrajTurn(index: 1, rows: [
                row("subtool", TrajL.kindSubtool), row("tool", TrajL.kindTool),
                row("first-assistant", TrajL.kindAssistant), row("second-assistant", TrajL.kindAssistant),
                row("step-two-subtool", TrajL.kindSubtool, step: 2),
                row("step-two-tool", TrajL.kindTool, step: 2),
                row("no-step", TrajL.kindAssistant, step: nil),
            ]),
            TrajTurn(index: 1, rows: [
                row("later-turn-assistant", TrajL.kindAssistant, step: 2),
                row("later-only-step", TrajL.kindAssistant, step: 3),
            ]),
            TrajTurn(index: 2, rows: []),
            TrajTurn(index: 2, rows: [row("after-empty-turn", TrajL.kindAssistant)]),
        ]
        let requests = [
            request(1), request(2, step: 2), request(3, step: 3),
            request(4, turn: 2), request(5, turn: nil), request(6, step: nil),
            request(7, turn: 3), request(8),
            request(9, turn: nil, step: nil, resultKey: "later-only-step"),
        ]
        XCTAssertEqual(trajectoryRequestBoundaries(requests, turns: turns), [
            "first-assistant": requests[7],
            "step-two-subtool": requests[1],
            "later-only-step": requests[8],
        ])
        XCTAssertTrue(trajectoryRequestBoundaries(requests, turns: []).isEmpty)
        XCTAssertTrue(trajectoryRequestBoundaries([], turns: turns).isEmpty)
    }

    func testToolCountsKeepTurnStepGroupingDuplicatesAndCompactionOrder() {
        func tool(_ key: String, turn: Int?, step: Int?, parent: String? = nil) -> Item {
            .tool(Item.Tool(
                key: key, callId: key, name: "read", arguments: "{}", status: .ok,
                turn: turn, step: step, parentCallId: parent
            ))
        }
        let items: [Item] = [
            tool("root", turn: 1, step: 1), tool("root", turn: 1, step: 1),
            tool("child", turn: 1, step: 1, parent: ""),
            tool("next-turn", turn: 2, step: 1),
            tool("next-step", turn: 1, step: 2, parent: "root"),
            tool("missing-turn", turn: nil, step: 1), tool("missing-step", turn: 1, step: nil),
            tool("unrecorded-step", turn: 1, step: 9),
            .compacted(Item.Compacted(key: "cmp15", compactionId: "running", status: .running, turn: 1)),
            .compacted(Item.Compacted(
                key: "cmp25", compactionId: "failed", status: .error,
                error: "stopped", interrupted: true, turn: 1
            )),
        ]
        let steps = [
            StepRecord(seq: 30, turn: 1, step: 1, usage: StepUsage(outputTokens: 3)),
            StepRecord(seq: 10, turn: 1, step: 1, usage: StepUsage(outputTokens: 1)),
            StepRecord(seq: 20, turn: 2, step: 1, usage: StepUsage(outputTokens: 2)),
            StepRecord(seq: 40, turn: 1, step: 2),
            StepRecord(seq: 50, turn: 3, step: 1),
        ]
        let requests = buildTrajectoryRequests(items: items, steps: steps)
        XCTAssertEqual(requests.map(\.resultKey), ["a10", "cmp15", "a20", "cmp25", "a30", "a40", "a50"])
        XCTAssertEqual(requests.map(\.number), Array(1...7))
        XCTAssertEqual(requests.map(\.toolCallCount), [2, 0, 1, 0, 2, 0, 0])
        XCTAssertEqual(requests.map(\.subtoolCallCount), [1, 0, 0, 0, 1, 1, 0])
        XCTAssertEqual(requests.map { $0.cumulativeUsage?.outputTokens }, [1, 1, 3, 3, 6, 6, 6])
        XCTAssertEqual(requests[1].status, .running)
        XCTAssertEqual(requests[3].status, .error)
        XCTAssertEqual(requests[3].error, "stopped")
        XCTAssertEqual(requests[3].errorCode, "interrupted")
        for request in requests where request.purpose == .assistant {
            XCTAssertEqual(request.group, TrajL.groupStep(request.step!))
        }
    }

    func testLiveUpdatesReplaceLastAssistantWithoutTouchingToolsOrOtherTurns() {
        let turns = buildTrajectory([
            .user(Item.User(key: "u1", text: "first")),
            .text(Item.Text(key: "shared", text: "older", live: false)),
            .text(Item.Text(key: "shared", text: "newer", live: false)),
            .reasoning(Item.Reasoning(key: "shared", text: "full reasoning", live: true)),
            .tool(Item.Tool(key: "shared", callId: "tool", name: "read", arguments: "{}", status: .ok)),
            .text(Item.Text(key: "another-live-key", text: "full answer", live: true)),
            .user(Item.User(key: "u2", text: "second")),
            .text(Item.Text(key: "shared", text: "second answer", live: true)),
        ])
        XCTAssertEqual(turns.map(\.index), [1, 2])
        XCTAssertEqual(turns[0].rows.map(\.kind), [
            TrajL.kindUser, TrajL.kindAssistant, TrajL.kindAssistant, TrajL.kindTool,
        ])
        XCTAssertEqual(turns[0].rows[1].outputDetail, "older")
        XCTAssertEqual(turns[0].rows[2].outputDetail, "full answer")
        XCTAssertEqual(turns[0].rows[2].thinkingDetail, "full reasoning")
        XCTAssertEqual(turns[0].rows[2].rawDetail, "full reasoning\n\nfull answer")
        XCTAssertEqual(turns[1].rows.count, 2)
        XCTAssertEqual(turns[1].rows[1].outputDetail, "second answer")
        XCTAssertNil(turns[1].rows[1].thinkingDetail)
    }

    func testSettledStepDeduplicationAndLiveReplacementSurviveCompactionPrefix() {
        let steps = [
            StepRecord(seq: 10, turn: 1, step: 1, replyText: "superseded", toolCallIds: ["call"]),
            StepRecord(seq: 10, turn: 1, step: 1, replyText: "settled"),
            StepRecord(seq: 20, turn: 1, step: 2, replyText: "tool owner", toolCallIds: ["call"]),
        ]
        let turns = buildTrajectory([
            .compacted(Item.Compacted(key: "cmp5", compactionId: "c5", status: .ok, summary: "full summary")),
            .user(Item.User(key: "u1", text: "continue")),
            .reasoning(Item.Reasoning(key: "r10", text: "settled reasoning", live: false)),
            .text(Item.Text(key: "a10", text: "settled", live: false)),
            .tool(Item.Tool(key: "t21", callId: "call", name: "read", arguments: "{}", status: .ok)),
            .reasoning(Item.Reasoning(key: "a10", text: "live reasoning", live: true)),
            .text(Item.Text(key: "live-text", text: "live answer", live: true)),
        ], steps: steps)
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].rows.map(\.key), ["cmp5", "u1", "a10", "a20", "t21"])
        XCTAssertEqual(turns[0].rows[0].outputDetail, "full summary")
        XCTAssertEqual(turns[0].rows[2].outputDetail, "live answer")
        XCTAssertEqual(turns[0].rows[2].thinkingDetail, "live reasoning")
        XCTAssertEqual(turns[0].rows[3].outputDetail, "tool owner")
    }

    func testLongTrajectoryRetainsEveryStepBoundaryAndSearchableDetail() {
        let count = 2_000
        var items: [Item] = [.user(Item.User(key: "u1", text: "long session"))]
        var steps: [StepRecord] = []
        for index in 1...count {
            let text = "complete reply \(index)\nunique-detail-\(index)"
            steps.append(StepRecord(seq: Int64(index), turn: 1, step: index, replyText: text))
            items.append(.text(Item.Text(key: "a\(index)", text: text, live: false)))
        }
        let turns = buildTrajectory(items, steps: steps)
        let requests = buildTrajectoryRequests(items: items, steps: steps)
        let boundaries = trajectoryRequestBoundaries(requests, turns: turns)
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].rows.count, count + 1)
        XCTAssertEqual(requests.count, count)
        XCTAssertEqual(boundaries.count, count)
        for index in 1...count {
            XCTAssertEqual(boundaries["a\(index)"]?.number, index)
            XCTAssertEqual(turns[0].rows[index].outputDetail, steps[index - 1].replyText)
        }
        XCTAssertEqual(trajectorySearchMatches(turns, query: "unique-detail-2000"), ["a2000"])
    }
}

private func XCTAssertEqual(
    _ a: [(Double, Double)],
    _ b: [(Double, Double)],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(a.count, b.count, file: file, line: line)
    for (lhs, rhs) in zip(a, b) {
        XCTAssertEqual(lhs.0, rhs.0, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(lhs.1, rhs.1, accuracy: 0.0001, file: file, line: line)
    }
}
