import XCTest
@testable import DSHProtocol

final class JobsTests: XCTestCase {
    func testRealisticHostRosterParsesLossyFalseAndShowsLiveChip() throws {
        let result = try JSONValue.parse("""
        {"type":"rows","jobs":[
          {"id":"bash-1","kind":"bash","label":"sleep 600","status":"running","startedAt":1700000000000,"output":{"total":0,"earliest":0,"lossy":false}},
          {"id":"bash-2","kind":"bash","label":"sleep 900","status":"running","startedAt":1700000001000,"output":{"total":12,"earliest":0,"lossy":false}}
        ]}
        """)
        let rows = parseJobRoster(result)
        XCTAssertEqual(rows.map(\.id), ["bash-1", "bash-2"])
        XCTAssertEqual(rows.map(\.kind), ["bash", "bash"])
        XCTAssertEqual(rows.map(\.title), ["sleep 600", "sleep 900"])
        XCTAssertEqual(rows.map(\.status), ["running", "running"])
        XCTAssertEqual(rows[0].outputTotal, 0)
        XCTAssertEqual(rows[1].outputTotal, 12)
        XCTAssertTrue(rows.allSatisfy(\.isLive))
        XCTAssertEqual(JobsActionLabel.chip(jobs: rows, failed: false), .live(2))
        XCTAssertEqual(JobsActionLabel.text(.live(1), en: false), "1 个后台任务运行中")
        XCTAssertTrue(jobsActionShouldWatch(online: true, hasListOp: true))
        XCTAssertFalse(jobsActionShouldWatch(online: true, hasListOp: false))
        XCTAssertGreaterThan(jobsActionWatchAnchorPoints, 0)
        XCTAssertEqual(jobIdentity(try JSONValue.parse(#"{"id":7}"#)), "7")
    }

    func testListRosterParsesIdAliasesAndDropsRowsWithoutIdentity() throws {
        let result = try JSONValue.parse("""
        {"jobs":[
          {"id":"job-0","status":"running","label":"build"},
          {"jobId":"job-1","state":"completed","command":"echo hi"},
          {"name":"orphan","status":"pending"},
          {"id":"job-2","status":"failed","name":"lint","detail":"exit 1"}
        ]}
        """)
        let rows = parseJobRoster(result)
        XCTAssertEqual(rows.map(\.id), ["job-0", "job-1", "job-2"])
        XCTAssertEqual(rows.map(\.status), ["running", "completed", "failed"])
        XCTAssertEqual(rows.map(\.title), ["build", "echo hi", "lint"])
        XCTAssertEqual(rows[2].detail, "exit 1")
        XCTAssertTrue(rows[0].isLive)
        XCTAssertFalse(rows[1].isLive)
        XCTAssertFalse(JobRow(id: "p", status: "pending", title: "p").canKill)
        XCTAssertTrue(JobRow(id: "r", status: "running", title: "r").canKill)
        XCTAssertFalse(rows[1].canKill)
    }

    func testChipHidesEmptyRosterAndFailedRefreshIsNotZero() {
        XCTAssertNil(JobsActionLabel.chip(jobs: nil, failed: false))
        XCTAssertNil(JobsActionLabel.chip(jobs: [], failed: false))
        XCTAssertEqual(JobsActionLabel.chip(jobs: nil, failed: true), .unavailable)
        XCTAssertEqual(JobsActionLabel.chip(jobs: [], failed: true), .unavailable)

        let mixed = [
            JobRow(id: "a", status: "running", title: "a"),
            JobRow(id: "b", status: "stopping", title: "b"),
            JobRow(id: "c", status: "completed", title: "c"),
            JobRow(id: "d", status: "failed", title: "d"),
            JobRow(id: "e", status: "killed", title: "e"),
        ]
        XCTAssertEqual(JobsActionLabel.chip(jobs: mixed, failed: false), .live(2))
        let settled = mixed.filter { !$0.isLive }
        XCTAssertEqual(JobsActionLabel.chip(jobs: settled, failed: false), .retained(3))
        XCTAssertEqual(JobsActionLabel.chip(jobs: mixed, failed: true), .unavailable)
    }

    func testChipCopyMatchesAndroidZhEn() {
        XCTAssertEqual(JobsActionLabel.text(.unavailable, en: false), "任务状态不可用")
        XCTAssertEqual(JobsActionLabel.text(.unavailable, en: true), "Job status unavailable")
        XCTAssertEqual(JobsActionLabel.text(.live(1), en: false), "1 个后台任务运行中")
        XCTAssertEqual(JobsActionLabel.text(.live(2), en: false), "2 个后台任务运行中")
        XCTAssertEqual(JobsActionLabel.text(.live(1), en: true), "1 background job running")
        XCTAssertEqual(JobsActionLabel.text(.live(2), en: true), "2 background jobs running")
        XCTAssertEqual(JobsActionLabel.text(.retained(1), en: false), "1 个后台任务")
        XCTAssertEqual(JobsActionLabel.text(.retained(3), en: false), "3 个后台任务")
        XCTAssertEqual(JobsActionLabel.text(.retained(1), en: true), "1 background job")
        XCTAssertEqual(JobsActionLabel.text(.retained(3), en: true), "3 background jobs")
    }

    func testFollowClaimUnfollowsDuplicateSubId() {
        var assigned: [String: String] = [:]
        XCTAssertNil(JobFollowClaim.assign(current: &assigned, jobId: "j1", subId: "s1"))
        XCTAssertEqual(assigned["j1"], "s1")
        XCTAssertEqual(JobFollowClaim.assign(current: &assigned, jobId: "j1", subId: "s2"), "s2")
        XCTAssertEqual(assigned["j1"], "s1")
        XCTAssertNil(JobFollowClaim.assign(current: &assigned, jobId: "j1", subId: "s1"))
        XCTAssertNil(JobFollowClaim.assign(current: &assigned, jobId: "j2", subId: "s3"))
        XCTAssertEqual(assigned["j2"], "s3")
    }

    func testFollowClaimBeginRejectsAssignedOrInFlight() {
        var assigned: [String: String] = ["j1": "s1"]
        var inFlight: Set<String> = []
        XCTAssertFalse(JobFollowClaim.begin(inFlight: &inFlight, assigned: assigned, jobId: "j1"))
        XCTAssertTrue(inFlight.isEmpty)
        XCTAssertTrue(JobFollowClaim.begin(inFlight: &inFlight, assigned: assigned, jobId: "j2"))
        XCTAssertEqual(inFlight, ["j2"])
        XCTAssertFalse(JobFollowClaim.begin(inFlight: &inFlight, assigned: assigned, jobId: "j2"))
        JobFollowClaim.end(inFlight: &inFlight, jobId: "j2")
        XCTAssertTrue(inFlight.isEmpty)
        XCTAssertTrue(JobFollowClaim.begin(inFlight: &inFlight, assigned: assigned, jobId: "j2"))
    }

    func testFollowRequestOmitsNullFrom() throws {
        let args = JobFollowRequest.args(sessionId: "S", jobId: "J")
        XCTAssertEqual(args["sessionId"].str(), "S")
        XCTAssertEqual(args["jobId"].str(), "J")
        XCTAssertTrue(args["from"].isNull)
        let encoded = try args.encodeString()
        XCTAssertFalse(encoded.contains("from"))
        let resumed = JobFollowRequest.args(sessionId: "S", jobId: "J", from: 40)
        XCTAssertEqual(resumed["from"].long(), 40)
    }

    func testTwoPressKillArmsThenConfirmsAndDisarms() {
        let armed = jobKillPress(phase: .idle, key: "j1", nowMs: 1_000)
        XCTAssertEqual(armed, .armed(key: "j1", untilMs: 4_000))
        XCTAssertEqual(jobKillPress(phase: armed, key: "j1", nowMs: 2_000), .pending(key: "j1"))
        XCTAssertEqual(jobKillPress(phase: armed, key: "j2", nowMs: 2_000), .armed(key: "j2", untilMs: 5_000))
        XCTAssertEqual(jobKillTick(phase: armed, nowMs: 4_000, runningKeys: ["j1"]), .idle)
        XCTAssertEqual(jobKillTick(phase: .pending(key: "j1"), nowMs: 9_000, runningKeys: ["j1"]), .pending(key: "j1"))
        XCTAssertEqual(jobKillTick(phase: .pending(key: "j1"), nowMs: 9_000, runningKeys: []), .idle)
        XCTAssertEqual(jobKillAdmit(phase: .pending(key: "j1"), key: "j1", ok: false, nowMs: 3_000), .failed(key: "j1", untilMs: 7_000))
        XCTAssertEqual(jobKillAdmit(phase: .pending(key: "j1"), key: "j1", ok: true, nowMs: 3_000), .pending(key: "j1"))
        XCTAssertEqual(jobKillArmMs, 3_000)
        XCTAssertEqual(jobKillFailedMs, 4_000)
        XCTAssertEqual(jobKillConfirmLabel(english: false), "再次点击确认停止")
        XCTAssertEqual(jobKillConfirmAction(english: false), "确认停止")
        XCTAssertEqual(jobKillFailedLabel(english: false), "停止失败")
        XCTAssertEqual(jobKillFailedLabel(english: true), "Stop failed")
        XCTAssertEqual(jobKillStopLabel(label: "build", english: false), "停止任务 build")
        XCTAssertEqual(jobSectionLive(english: false), "进行中")
        XCTAssertEqual(jobSectionSettled(count: 2, english: false), "已结束 2")
        XCTAssertEqual(jobDurationText(elapsedMs: 5_000, english: false), "5秒")
        XCTAssertEqual(jobDurationText(elapsedMs: 65_000, english: false), "1分5秒")
        XCTAssertEqual(jobDurationText(elapsedMs: 3_661_000, english: true), "1h 1m")
    }

    func testJobRosterOrdersLiveFirstThenSettledNewest() throws {
        let result = try JSONValue.parse("""
        {"jobs":[
          {"id":"old","status":"completed","label":"old","startedAt":1,"finishedAt":10,"kind":"shell","output":{"total":2}},
          {"id":"live-b","status":"running","label":"b","startedAt":30,"kind":"shell"},
          {"id":"live-a","status":"running","label":"a","startedAt":20,"kind":"shell"},
          {"id":"new","status":"failed","label":"new","startedAt":5,"finishedAt":40,"kind":"shell"}
        ]}
        """)
        let rows = orderedJobRows(parseJobRoster(result))
        XCTAssertEqual(rows.map(\.id), ["live-a", "live-b", "new", "old"])
        XCTAssertEqual(rows[0].kind, "shell")
        XCTAssertTrue(rows[3].isObservable)
        XCTAssertEqual(jobStatusLabel("killed", english: false), "已取消")
    }

    func testFollowOutputFramesPreserveLossAndGaps() throws {
        let opened = JobFollowFrame.parse(
            try JSONValue.parse(#"{"type":"opened","job":{"id":"bash-1","status":"running","label":"sleep 300"}}"#),
            fallbackId: "bash-1"
        )
        guard case .opened(let openedJob) = opened else { return XCTFail("expected opened") }
        XCTAssertEqual(openedJob.status, "running")
        XCTAssertTrue(openedJob.isLive)
        let status = JobFollowFrame.parse(
            try JSONValue.parse(#"{"type":"status","job":{"id":"bash-1","status":"completed"}}"#),
            fallbackId: "bash-1"
        )
        guard case .status(let settled) = status else { return XCTFail("expected status") }
        XCTAssertEqual(settled.status, "completed")
        XCTAssertFalse(settled.isLive)

        let frame = try JSONValue.parse("""
        {"type":"output","lossy":true,"chunks":[
          {"text":"one","gapBefore":false},
          {"text":"two\\nthree","gapBefore":true}
        ]}
        """)
        guard case .output(let lossy, let chunks) = JobFollowFrame.parse(frame) else {
            return XCTFail("expected output frame")
        }
        XCTAssertTrue(lossy)
        XCTAssertEqual(chunks, [
            JobOutputChunk(text: "one", gapBefore: false),
            JobOutputChunk(text: "two\nthree", gapBefore: true),
        ])

        var lines: [String] = []
        applyJobOutputFrames(
            to: &lines,
            lossy: true,
            chunks: chunks,
            expiredNotice: jobOutputGap(english: false),
            missingNotice: jobOutputGap(english: false)
        )
        XCTAssertEqual(lines, ["", "……较早的输出已丢弃……", "one", "……较早的输出已丢弃……", "two", "three"])
    }

    func testLossyFlagAcceptsBooleanOrStringTrue() throws {
        XCTAssertTrue(jsonFlagTrue(try JSONValue.parse("true")))
        XCTAssertTrue(jsonFlagTrue(try JSONValue.parse(#""true""#)))
        XCTAssertFalse(jsonFlagTrue(try JSONValue.parse("false")))
        XCTAssertFalse(jsonFlagTrue(.null))
        let stringy = JobFollowFrame.parse(try JSONValue.parse(#"{"type":"output","lossy":"true","chunks":[]}"#))
        XCTAssertEqual(stringy, .output(lossy: true, chunks: []))
    }

    func testRealisticHostKilledRosterMatchesDesktopJobView() throws {
        let result = try JSONValue.parse("""
        {"type":"rows","jobs":[
          {"id":"bash-1","kind":"bash","label":"sleep 300","status":"killed","detail":"signal: SIGTERM; cancelled by the user","startedAt":1700000000000,"finishedAt":1700000070000,"output":{"total":0,"earliest":0}}
        ]}
        """)
        let rows = parseJobRoster(result)
        XCTAssertEqual(rows.count, 1)
        let job = try XCTUnwrap(rows.first)
        XCTAssertEqual(job.id, "bash-1")
        XCTAssertEqual(job.kind, "bash")
        XCTAssertEqual(job.title, "sleep 300")
        XCTAssertEqual(job.status, "killed")
        XCTAssertEqual(job.detail, "signal: SIGTERM; cancelled by the user")
        XCTAssertNil(job.progress)
        XCTAssertEqual(job.finishedAt, 1_700_000_070_000)
        XCTAssertFalse(job.isLive)
        XCTAssertFalse(job.canKill)
        XCTAssertEqual(jobRowStatusText(job, english: false), "signal: SIGTERM; cancelled by the user")
        XCTAssertEqual(jobElapsedMs(job, nowMs: 1_700_000_200_000), 70_000)
        XCTAssertEqual(jobDurationText(elapsedMs: 70_000, english: false), "1分10秒")
        XCTAssertEqual(JobsActionLabel.chip(jobs: rows, failed: false), .retained(1))
        XCTAssertTrue(orderedJobRows(rows).allSatisfy { !$0.isLive })
    }

    func testSettledSectionMatchesDesktopJobListActionFold() {
        XCTAssertFalse(jobsSettledSectionExpanded(explicit: nil, liveCount: 1))
        XCTAssertTrue(jobsSettledSectionExpanded(explicit: nil, liveCount: 0))
        XCTAssertTrue(jobsSettledSectionExpanded(explicit: true, liveCount: 2))
        XCTAssertFalse(jobsSettledSectionExpanded(explicit: false, liveCount: 0))
        XCTAssertTrue(jobsSettledSectionToggled(explicit: nil, liveCount: 1))
        XCTAssertFalse(jobsSettledSectionToggled(explicit: nil, liveCount: 0))
        XCTAssertFalse(jobsSettledSectionToggled(explicit: true, liveCount: 4))
        XCTAssertTrue(jobsSettledSectionToggled(explicit: false, liveCount: 0))
        XCTAssertEqual(jobsToggledExpandedKey(current: nil, jobId: "bash-2"), "bash-2")
        XCTAssertNil(jobsToggledExpandedKey(current: "bash-2", jobId: "bash-2"))
        XCTAssertEqual(jobsToggledExpandedKey(current: "bash-1", jobId: "bash-2"), "bash-2")
        XCTAssertTrue(jobsPopoverClockRuns(open: true, liveCount: 1))
        XCTAssertFalse(jobsPopoverClockRuns(open: true, liveCount: 0))
        XCTAssertFalse(jobsPopoverClockRuns(open: false, liveCount: 3))
    }

    func testTriggerUsesOfficialChevronDownNotSystemClock() {
        XCTAssertTrue(jobsActionTriggerUsesOfficialGlyph)
        XCTAssertEqual(jobsActionTriggerSymbol(), "official.jobsChevron")
        XCTAssertEqual(jobsActionTriggerIconSizePoints, 12)
        XCTAssertEqual(jobsActionTriggerIconStrokeWidth, 1)
        XCTAssertEqual(
            jobsActionTriggerChevronPath,
            "M4 6L7.29289 9.29289C7.68342 9.68342 8.31658 9.68342 8.70711 9.29289L12 6"
        )
        XCTAssertTrue(isForbiddenJobsActionTriggerSymbol("clock"))
        XCTAssertTrue(isForbiddenJobsActionTriggerSymbol("clock.fill"))
        XCTAssertTrue(isForbiddenJobsActionTriggerSymbol("chevron.down"))
        XCTAssertTrue(isForbiddenJobsActionTriggerSymbol("official.clockOutline"))
        XCTAssertTrue(isForbiddenJobsActionTriggerSymbol("official.trajectoryClock"))
        XCTAssertTrue(isForbiddenJobsActionTriggerSymbol("IconClockOutlineRegular"))
        XCTAssertFalse(isForbiddenJobsActionTriggerSymbol("official.jobsChevron"))
    }

    func testKilledHostExitObjectProjectsJobViewStatusAndDetail() throws {
        let result = try JSONValue.parse("""
        {"type":"rows","jobs":[
          {"id":"bash-1","kind":"bash","label":"sleep 300","status":"running","exit":{"signal":"SIGTERM","reason":"cancelled by the user"},"startedAt":1700000000000,"finishedAt":1700000061000,"progress":"running","output":{"total":0,"earliest":0}}
        ]}
        """)
        let job = try XCTUnwrap(parseJobRoster(result).first)
        XCTAssertEqual(job.status, "killed")
        XCTAssertEqual(job.detail, "signal: SIGTERM; cancelled by the user")
        XCTAssertNil(job.progress)
        XCTAssertFalse(job.isLive)
        XCTAssertFalse(job.canKill)
        XCTAssertEqual(jobRowStatusText(job, english: true), "signal: SIGTERM; cancelled by the user")
        XCTAssertEqual(jobElapsedMs(job, nowMs: 1_700_000_200_000), 61_000)
        XCTAssertEqual(jobDurationText(elapsedMs: 61_000, english: false), "1分1秒")
    }

    func testFollowStatusReplacesFullJobViewAndDoesNotReviveSettledRow() throws {
        var jobs: [JobRow]? = [
            JobRow(
                id: "bash-1",
                status: "running",
                title: "sleep 300",
                kind: "bash",
                startedAt: 1_700_000_000_000,
                progress: "running"
            ),
        ]
        let killed = try JSONValue.parse("""
        {"type":"status","job":{"id":"bash-1","kind":"bash","label":"sleep 300","status":"killed","detail":"signal: SIGTERM; cancelled by the user","startedAt":1700000000000,"finishedAt":1700000070000,"output":{"total":0,"earliest":0}}}
        """)
        guard case .status(let incoming) = JobFollowFrame.parse(killed, fallbackId: "bash-1") else {
            return XCTFail("expected status frame")
        }
        applyJobFollowProjection(&jobs, jobId: "bash-1", incoming: incoming)
        let settled = try XCTUnwrap(jobs?.first)
        XCTAssertEqual(settled.status, "killed")
        XCTAssertEqual(settled.detail, "signal: SIGTERM; cancelled by the user")
        XCTAssertEqual(settled.finishedAt, 1_700_000_070_000)
        XCTAssertNil(settled.progress)
        XCTAssertFalse(settled.isLive)
        XCTAssertFalse(settled.canKill)

        let staleOpened = JobRow(id: "bash-1", status: "running", title: "sleep 300", kind: "bash")
        applyJobFollowProjection(&jobs, jobId: "bash-1", incoming: staleOpened)
        XCTAssertEqual(jobs?.first?.status, "killed")
        XCTAssertEqual(jobs?.first?.detail, "signal: SIGTERM; cancelled by the user")
        XCTAssertFalse(jobs?.first?.isLive ?? true)
    }
}

final class CompletionRemindersTests: XCTestCase {
    func testDelayedStateReplyCannotRestoreAnAcknowledgedCompletion() throws {
        let reminders = CompletionReminders()
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":4,"unreadIds":["one"]}"#))
        XCTAssertEqual(reminders.unreadIds, ["one"])
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":5,"unreadIds":[]}"#))
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":4,"unreadIds":["one"]}"#))
        XCTAssertEqual(reminders.unreadIds, [])
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":6,"unreadIds":["two"]}"#))
        XCTAssertEqual(reminders.unreadIds, ["two"])
    }

    func testADifferentHostStartsFreshAndRejectsOldEpochsAndMalformedSnapshots() throws {
        let reminders = CompletionReminders()
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":40,"unreadIds":["one"]}"#))
        reminders.reset()
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-b","revision":0,"unreadIds":["two"]}"#))
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":41,"unreadIds":[]}"#))
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-b","revision":1,"unreadIds":[null]}"#))
        XCTAssertEqual(reminders.unreadIds, ["two"])
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-b","revision":1,"unreadIds":[]}"#))
        XCTAssertEqual(reminders.unreadIds, [])
    }

    func testBlankEpochRevisionOrMissingIdsAreRejected() throws {
        let reminders = CompletionReminders()
        reminders.accept(try JSONValue.parse(#"{"epoch":"","revision":1,"unreadIds":["one"]}"#))
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":-1,"unreadIds":["one"]}"#))
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":1}"#))
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":1,"unreadIds":[" "]}"#))
        XCTAssertEqual(reminders.unreadIds, [])
        reminders.accept(try JSONValue.parse(#"{"epoch":"host-a","revision":0,"unreadIds":["kept"]}"#))
        XCTAssertEqual(reminders.unreadIds, ["kept"])
    }

    func testCompletionViewArgsKeepExplicitNull() throws {
        let cleared = CompletionViewRequest.args(sessionId: nil)
        XCTAssertTrue(cleared["sessionId"].isNull)
        XCTAssertTrue(try cleared.encodeString().contains("sessionId"))
        XCTAssertTrue(try cleared.encodeString().contains("null"))
        let viewed = CompletionViewRequest.args(sessionId: "S")
        XCTAssertEqual(viewed["sessionId"].str(), "S")
        XCTAssertFalse(try viewed.encodeString().contains("null"))
    }

    func testViewedSessionRequiresDesiredChatAndReady() {
        XCTAssertEqual(CompletionViewed.sessionId(desired: "S", chat: "S", ready: "S"), "S")
        XCTAssertNil(CompletionViewed.sessionId(desired: nil, chat: "S", ready: "S"))
        XCTAssertNil(CompletionViewed.sessionId(desired: "S", chat: "T", ready: "S"))
        XCTAssertNil(CompletionViewed.sessionId(desired: "S", chat: "S", ready: nil))
        XCTAssertNil(CompletionViewed.sessionId(desired: "S", chat: nil, ready: "S"))
    }

    func testViewedSessionDedupeSkipsSameClientAndSession() {
        XCTAssertFalse(CompletionViewed.shouldSkip(sameClient: false, lastSession: nil, nextSession: nil))
        XCTAssertTrue(CompletionViewed.shouldSkip(sameClient: true, lastSession: nil, nextSession: nil))
        XCTAssertTrue(CompletionViewed.shouldSkip(sameClient: true, lastSession: "S", nextSession: "S"))
        XCTAssertFalse(CompletionViewed.shouldSkip(sameClient: true, lastSession: "S", nextSession: nil))
        XCTAssertFalse(CompletionViewed.shouldSkip(sameClient: false, lastSession: "S", nextSession: "S"))
    }
}
