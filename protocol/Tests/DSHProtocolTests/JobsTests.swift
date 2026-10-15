import XCTest
@testable import DSHProtocol

final class JobsTests: XCTestCase {
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
        XCTAssertTrue(JobRow(id: "p", status: "pending", title: "p").canKill)
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

    func testFollowOutputFramesPreserveLossAndGaps() throws {
        let opened = JobFollowFrame.parse(try JSONValue.parse(#"{"type":"opened","job":{"status":"running"}}"#))
        XCTAssertEqual(opened, .opened(status: "running"))
        let status = JobFollowFrame.parse(try JSONValue.parse(#"{"type":"status","job":{"status":"completed"}}"#))
        XCTAssertEqual(status, .status(status: "completed"))

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
            expiredNotice: "[部分历史输出已过期]",
            missingNotice: "[此处输出存在缺失]"
        )
        XCTAssertEqual(lines, ["", "[部分历史输出已过期]", "one", "[此处输出存在缺失]", "two", "three"])
    }

    func testLossyFlagAcceptsBooleanOrStringTrue() throws {
        XCTAssertTrue(jsonFlagTrue(try JSONValue.parse("true")))
        XCTAssertTrue(jsonFlagTrue(try JSONValue.parse(#""true""#)))
        XCTAssertFalse(jsonFlagTrue(try JSONValue.parse("false")))
        XCTAssertFalse(jsonFlagTrue(.null))
        let stringy = JobFollowFrame.parse(try JSONValue.parse(#"{"type":"output","lossy":"true","chunks":[]}"#))
        XCTAssertEqual(stringy, .output(lossy: true, chunks: []))
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
