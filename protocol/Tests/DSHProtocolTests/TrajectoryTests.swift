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
        let notices = r.items().compactMap { item -> String? in
            if case .notice(let n) = item { return n.text }
            return nil
        }
        XCTAssertEqual(notices, ["已停止"])
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
        XCTAssertEqual(hits, ["x1"])
        XCTAssertTrue(trajectorySearchMatches(turns, query: "read")?.contains("t1") == true)
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
