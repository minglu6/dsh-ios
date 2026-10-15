import XCTest
@testable import DSHProtocol

/// Distinguishes Android's omitted `usage()` default from an explicit `nil`.
private let defaultUsageSentinel = "__default_usage__"

final class TurnTokenUsageTests: XCTestCase {
    private func event(_ seq: Int, _ type: String, turn: Int = 1, step: Int = 1, extra: String = "") throws -> JSONValue {
        try JSONValue.parse(
            #"{"type":"event","event":{"seq":\#(seq),"time":\#(seq),"type":"\#(type)","data":{"turn":\#(turn),"step":\#(step)\#(extra)}}}"#
        )
    }

    private func usage(_ overrides: [String: String] = [:], remove: [String] = []) -> String {
        var values = [
            "inputTokens": "100", "outputTokens": "20", "totalTokens": "170", "cacheReadTokens": "50",
        ]
        for (key, value) in overrides { values[key] = value }
        for key in remove { values.removeValue(forKey: key) }
        let body = values.map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
        return "{\(body)}"
    }

    /// Android `message(seq, value = usage(), streamUsage = value)`: omitted args use
    /// the default sample; an explicit `nil` omits that usage object.
    private func message(
        _ seq: Int,
        value: String? = defaultUsageSentinel,
        streamUsage: String? = defaultUsageSentinel,
        turn: Int = 1,
        step: Int = 1,
        provider: String = "deepseek",
        model: String = "deepseek-chat"
    ) throws -> JSONValue {
        let resolvedValue = value == defaultUsageSentinel ? usage() : value
        let resolvedStream = streamUsage == defaultUsageSentinel ? resolvedValue : streamUsage
        let stream = resolvedStream == nil
            ? "[]"
            : #"[{"type":"chunk","chunk":{"type":"usage","usage":\#(resolvedStream!)}}]"#
        let final = resolvedValue == nil ? "" : #", "usage":\#(resolvedValue!)"#
        return try event(
            seq, "assistant/message", turn: turn, step: step,
            extra: #", "stream":\#(stream), "message":{"id":"m\#(seq)","role":"assistant","content":[{"type":"text","text":"done"}],"source":{"provider":"\#(provider)","model":"\#(model)"}}\#(final)"#
        )
    }

    private func attempt(_ seq: Int, value: String? = defaultUsageSentinel, step: Int = 1) throws -> JSONValue {
        let resolved = value == defaultUsageSentinel ? usage() : value
        let sample = resolved == nil ? "" : #"{"type":"chunk","chunk":{"type":"usage","usage":\#(resolved!)}},"#
        return try event(
            seq, "assistant/attempt", step: step,
            extra: #", "stream":[\#(sample){"type":"chunk","chunk":{"type":"finish","reason":{"kind":"error"}}}]"#
        )
    }

    private func complete(_ middle: JSONValue...) throws -> [JSONValue] {
        try [event(1, "turn/start"), event(2, "step/start")] + middle + [event(90, "step/end"), event(91, "turn/end")]
    }

    private func reducer(_ events: [JSONValue]) -> TranscriptReducer {
        let r = TranscriptReducer()
        events.forEach { _ = r.apply($0) }
        return r
    }

    private func result(_ events: [JSONValue]) -> TurnTokenUsage? { reducer(events).turnTokenUsage()[1] }

    private func snapshot(_ events: [JSONValue], more: Bool = false) throws -> JSONValue {
        let cursor = events.last?["event"]["seq"].long() ?? -1
        return .object([
            "type": .string("snapshot"),
            "cursor": .number(Double(cursor)),
            "records": .array(events),
            "hasMore": .bool(more),
        ])
    }

    func testExactCompleteUsageAndOptionalZeroBuckets() throws {
        let extra = try complete(message(
            3, value: usage(["cacheWriteTokens": "0", "reasoningTokens": "8"])
        ))
        XCTAssertEqual(
            result(extra),
            TurnTokenUsage(100, 20, 170, 50, 0, 8, [TurnTokenUsageRoute(provider: "deepseek", model: "deepseek-chat")])
        )
    }

    func testDerivesTotalOnlyWithBothCacheBuckets() throws {
        XCTAssertEqual(
            result(try complete(message(3, value: usage(["cacheWriteTokens": "0"], remove: ["totalTokens"]))))?.totalTokens,
            170
        )
        XCTAssertNil(result(try complete(message(3, value: usage(remove: ["totalTokens"])))))
    }

    func testFinalUsageOverridesStreamAndStreamFillsMissingFinal() throws {
        let final = usage(["inputTokens": "30", "outputTokens": "5", "cacheReadTokens": "10", "totalTokens": "45"])
        XCTAssertEqual(result(try complete(message(3, value: final, streamUsage: usage())))?.totalTokens, 45)
        XCTAssertEqual(result(try complete(message(3, value: nil, streamUsage: usage())))?.totalTokens, 170)
        XCTAssertNil(result(try complete(message(3, value: usage(["inputTokens": "-1"]), streamUsage: usage()))))
    }

    func testLastDurableStreamSampleWinsWithoutCountingSamplesTwice() throws {
        let last = usage(["totalTokens": "180"])
        let sample = try event(3, "assistant/message", extra: """
            , "message":{"content":[],"source":{"provider":"deepseek","model":"deepseek-chat"}},
            "stream":[{"type":"chunk","chunk":{"type":"usage","usage":\(usage())}},
                      {"type":"chunk","chunk":{"type":"usage","usage":\(last)}}]
            """)
        XCTAssertEqual(result(try complete(sample))?.totalTokens, 180)
    }

    func testFailedAttemptCountsExactlyOnceAcrossRetryAndWithoutRetryStart() throws {
        let retried = result(try complete(attempt(3), event(4, "llm/retry"), event(5, "llm/retry-started"), message(6)))
        XCTAssertEqual(retried, TurnTokenUsage(200, 40, 340, 100))
        XCTAssertEqual(result(try complete(attempt(3), event(4, "llm/retry"))), TurnTokenUsage(100, 20, 170, 50))
        XCTAssertEqual(result(try complete(attempt(3)))?.totalTokens, 170)
        XCTAssertNil(result(try complete(attempt(3, value: nil), event(4, "llm/retry"), event(5, "llm/retry-started"), message(6))))
    }

    func testMultipleStepsSumWithDistinctRoutesAndOptionalBucketsRequireEveryAttempt() throws {
        let events = try [
            event(1, "turn/start"), event(2, "step/start"), message(3), event(4, "step/end"),
            event(5, "step/start", step: 2), message(6, step: 2, provider: "openai", model: "gpt-5"),
            event(7, "step/end", step: 2), event(8, "turn/end"),
        ]
        XCTAssertEqual(
            result(events),
            TurnTokenUsage(200, 40, 340, 100, nil, nil, [
                TurnTokenUsageRoute(provider: "deepseek", model: "deepseek-chat"),
                TurnTokenUsageRoute(provider: "openai", model: "gpt-5"),
            ])
        )
        var partial = events
        partial[2] = try message(3, value: usage(["cacheWriteTokens": "0", "reasoningTokens": "2"]))
        partial[5] = try message(6, value: usage(remove: ["cacheReadTokens"]), step: 2, provider: "", model: "")
        XCTAssertEqual(result(partial), TurnTokenUsage(200, 40, 340))
        partial[5] = try message(6, step: 2)
        XCTAssertEqual(result(partial)?.routes, [TurnTokenUsageRoute(provider: "deepseek", model: "deepseek-chat")])
    }

    func testRejectsInvalidCountersAndContradictoryTotals() throws {
        let invalid = [
            usage(["inputTokens": "-1"]),
            usage(["outputTokens": "1.5"]),
            usage(["totalTokens": "9007199254740992"]),
            usage(["inputTokens": "\"100\""]),
            usage(["cacheReadTokens": "-1"]),
            usage(["cacheWriteTokens": "1.5"]),
            usage(["totalTokens": "10"]),
            usage(["totalTokens": "160"]),
            usage(["totalTokens": "171", "cacheWriteTokens": "0"]),
            usage(["reasoningTokens": "21"]),
            usage(["inputTokens": "9007199254740991", "outputTokens": "0", "cacheReadTokens": "1", "totalTokens": "9007199254740991"]),
            usage(["inputTokens": "9007199254740991", "outputTokens": "1", "cacheReadTokens": "0", "cacheWriteTokens": "0"], remove: ["totalTokens"]),
        ]
        for value in invalid {
            XCTAssertNil(result(try complete(message(3, value: value))), value)
        }
    }

    func testAggregationNeverExceedsJavascriptSafeInteger() throws {
        let half = "4503599627370496"
        for bucket in ["inputTokens", "outputTokens", "totalTokens"] {
            let value = usage(["inputTokens": "0", "outputTokens": "0", "totalTokens": half], remove: ["cacheReadTokens"])
            var object = try JSONValue.parse(value).obj()!
            object[bucket] = .number(4_503_599_627_370_496)
            if bucket != "totalTokens" { object["totalTokens"] = .number(4_503_599_627_370_496) }
            let encoded = try JSONValue.object(object).encodeString()
            let events = try [
                event(1, "turn/start"), event(2, "step/start"), message(3, value: encoded), event(4, "step/end"),
                event(5, "step/start", step: 2), message(6, value: encoded, step: 2), event(7, "step/end", step: 2), event(8, "turn/end"),
            ]
            XCTAssertNil(result(events), bucket)
        }
    }

    func testMissingOrContradictoryLifecycleHidesWholeTurn() throws {
        let valid = try complete(message(3))
        let invalid: [[JSONValue]] = try [
            Array(valid.dropFirst()), Array(valid.dropLast()),
            valid.enumerated().filter { $0.offset != 1 }.map(\.element),
            valid.enumerated().filter { $0.offset != 3 }.map(\.element),
            complete(message(3, value: nil, streamUsage: nil)), complete(),
            [event(1, "turn/start"), event(2, "turn/end")],
            [event(1, "turn/start"), event(2, "turn/start")] + Array(valid.dropFirst()),
            complete(event(3, "step/start", step: 2), message(4)),
            complete(message(3, step: 2)), complete(message(3, turn: 2)),
            complete(event(3, "llm/retry-started"), message(4)),
            complete(message(3), event(4, "llm/retry-started")),
            complete(message(3), event(4, "llm/retry")),
            complete(event(3, "llm/retry"), message(4)),
            complete(attempt(3), event(4, "llm/retry"), event(5, "llm/retry-started", step: 2), message(6)),
            complete(attempt(3), event(4, "llm/retry", step: 2)),
            complete(attempt(3, step: 2)),
            Array(valid.dropLast()) + [event(91, "turn/end", turn: 2)],
            valid + [event(92, "turn/end")], valid + [event(92, "step/start")],
        ]
        for (index, events) in invalid.enumerated() {
            XCTAssertNil(result(events), "lifecycle case \(index)")
        }
    }

    func testPartialHistoryCanBeCompletedAcrossSeveralPrependPages() throws {
        let events = try complete(attempt(3), event(4, "llm/retry"), event(5, "llm/retry-started"), message(6))
        let r = TranscriptReducer()
        _ = r.apply(try snapshot(Array(events.dropFirst(5)), more: true))
        XCTAssertTrue(r.turnTokenUsage().isEmpty)
        XCTAssertTrue(r.prepend(records: .array(Array(events[2..<5])), pageHasMore: true))
        XCTAssertTrue(r.turnTokenUsage().isEmpty)
        XCTAssertTrue(r.prepend(records: .array(Array(events.prefix(2))), pageHasMore: false))
        XCTAssertEqual(r.turnTokenUsage()[1]?.totalTokens, 340)
        XCTAssertFalse(r.prepend(records: .array(events), pageHasMore: false))
        XCTAssertEqual(r.turnTokenUsage()[1]?.totalTokens, 340)
    }

    func testSnapshotResetsAccountingAndDuplicateEventsDoNotRebill() throws {
        let events = try complete(message(3))
        let r = reducer(events)
        let saved = r.turnTokenUsage()
        events.forEach { _ = r.apply($0) }
        _ = r.apply(.object(["type": .string("resume"), "records": .array(events)]))
        XCTAssertEqual(saved, r.turnTokenUsage())
        _ = r.apply(try snapshot(Array(events.dropFirst()), more: true))
        XCTAssertTrue(r.turnTokenUsage().isEmpty)
        XCTAssertEqual(saved[1]?.totalTokens, 170)
        _ = r.prepend(records: .array(Array(events.prefix(1))), pageHasMore: false)
        XCTAssertEqual(saved, r.turnTokenUsage())
        _ = r.apply(try snapshot([]))
        XCTAssertTrue(r.turnTokenUsage().isEmpty)
    }

    func testSessionUsageAndTrajectoryKeepExistingMessageOnlyAccounting() throws {
        let r = reducer(try complete(attempt(3), event(4, "llm/retry"), event(5, "llm/retry-started"), message(6)))
        XCTAssertEqual(r.turnTokenUsage()[1]?.totalTokens, 340)
        XCTAssertEqual(r.stepRecords().count, 1)
        XCTAssertEqual(r.usage.steps, 1)
        XCTAssertEqual(r.usage.inputTokens, 150)
        XCTAssertEqual(r.usage.outputTokens, 20)
    }
}

final class RetryTranscriptTests: XCTestCase {
    private func event(_ seq: Int, _ type: String, _ data: String) throws -> JSONValue {
        try JSONValue.parse(
            #"{"type":"event","event":{"seq":\#(seq),"time":\#(1000 + seq),"type":"\#(type)","data":\#(data)}}"#
        )
    }

    private func scheduled(
        _ seq: Int, retry: Int = 1, id: String = "request-a", turn: Int = 1, step: Int = 1,
        mode: String = "normal", maximum: String = #","maxRetries":5"#
    ) throws -> JSONValue {
        try event(seq, "llm/retry", """
        {"retryId":"\(id)","turn":\(turn),"step":\(step),"provider":"deepseek","mode":"\(mode)",
        "policyKey":"provider","retry":\(retry)\(maximum),"delayMs":1500,
        "failure":{"message":"provider temporarily unavailable","code":"RATE_LIMIT","retryable":true}}
        """)
    }

    private func started(_ seq: Int, retry: Int = 1, id: String = "request-a", turn: Int = 1, step: Int = 1) throws -> JSONValue {
        try event(seq, "llm/retry-started", #"{"retryId":"\#(id)","turn":\#(turn),"step":\#(step),"retry":\#(retry)}"#)
    }

    private func turnEnd(_ seq: Int, turn: Int = 1, error: Bool = false) throws -> JSONValue {
        try event(
            seq, "turn/end",
            error
                ? #"{"turn":\#(turn),"reason":{"kind":"error","error":{"message":"raw provider failure","code":"QUOTA"}}}"#
                : #"{"turn":\#(turn),"reason":{"kind":"completed"}}"#
        )
    }

    private func opening(_ type: String, _ records: [JSONValue], cursor: Int, more: Bool = false) -> JSONValue {
        .object([
            "type": .string(type),
            "cursor": .number(Double(cursor)),
            "hasMore": .bool(more),
            "records": .array(records),
            "projections": .object([:]),
        ])
    }

    private func retries(_ reducer: TranscriptReducer) -> [Item.Retry] {
        reducer.items().compactMap { if case .retry(let r) = $0 { return r }; return nil }
    }

    func testFiveAttemptsProduceOneChainAndIndependentTerminalFailure() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try event(1, "turn/start", #"{"turn":1}"#))
        _ = reducer.apply(try event(2, "step/start", #"{"turn":1,"step":1}"#))
        for retry in 1...5 {
            _ = reducer.apply(try scheduled(retry * 2 + 1, retry: retry))
            _ = reducer.apply(try started(retry * 2 + 2, retry: retry))
        }
        _ = reducer.apply(try turnEnd(13, error: true))
        let chain = retries(reducer).first
        XCTAssertEqual(chain?.attempts.map(\.retry), [1, 2, 3, 4, 5])
        XCTAssertTrue(chain?.attempts.allSatisfy { $0.state == .started } == true)
        XCTAssertEqual(chain?.attempts.last?.maxRetries, 5)
        XCTAssertEqual(chain?.attempts.last?.mode, "normal")
        XCTAssertEqual(chain?.attempts.last?.delayMs, 1500)
        XCTAssertEqual(chain?.attempts.last?.message, "provider temporarily unavailable")
        XCTAssertEqual(chain?.attempts.last?.code, "RATE_LIMIT")
        XCTAssertEqual(chain?.turn, 1)
        XCTAssertEqual(chain?.step, 1)
        let failures = reducer.items().compactMap { if case .turnFailure(let f) = $0 { return f }; return nil }
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.message, "raw provider failure")
        XCTAssertEqual(failures.first?.code, "QUOTA")
        XCTAssertEqual(failures.first?.turn, 1)
        XCTAssertEqual(
            reducer.items().map { item -> String in
                switch item {
                case .retry: return "Retry"
                case .turnFailure: return "TurnFailure"
                default: return "Other"
                }
            },
            ["Retry", "TurnFailure"]
        )
        XCTAssertFalse(reducer.running)
    }

    func testSuccessfulRetryPreservesStartedHistoryAndTrajectoryFailure() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try event(1, "turn/start", #"{"turn":1}"#))
        _ = reducer.apply(try event(2, "step/start", #"{"turn":1,"step":1}"#))
        _ = reducer.apply(try scheduled(3))
        _ = reducer.apply(try started(4))
        _ = reducer.apply(try event(5, "assistant/message", #"{"turn":1,"step":1,"message":{"content":[{"type":"text","text":"done"}]}}"#))
        _ = reducer.apply(try event(6, "step/end", #"{"turn":1,"step":1}"#))
        _ = reducer.apply(try turnEnd(7))
        XCTAssertEqual(retries(reducer).first?.attempts.first?.state, .started)
        XCTAssertTrue(reducer.items().allSatisfy {
            if case .turnFailure = $0 { return false }
            if case .notice = $0 { return false }
            return true
        })
        XCTAssertFalse(reducer.running)
        let step = reducer.stepRecords().first
        XCTAssertEqual(step?.retry, 1)
        XCTAssertEqual(step?.maxRetries, 5)
        XCTAssertEqual(step?.retryDelayMs, 1500)
        XCTAssertEqual(step?.lastAttemptError, "provider temporarily unavailable")
    }

    func testClosingStepCancelsWaitingChainButNotOtherStepsOrStartedAttempts() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try scheduled(1, id: "waiting"))
        _ = reducer.apply(try scheduled(2, id: "started"))
        _ = reducer.apply(try started(3, id: "started"))
        _ = reducer.apply(try scheduled(4, id: "other-step", step: 2))
        _ = reducer.apply(try scheduled(5, id: "other-turn", turn: 2))
        _ = reducer.apply(try event(6, "step/end", #"{"turn":1,"step":1}"#))
        XCTAssertEqual(retries(reducer).map { $0.attempts.last?.state }, [.cancelled, .started, .scheduled, .scheduled])
        _ = reducer.apply(try turnEnd(7))
        XCTAssertEqual(retries(reducer).map { $0.attempts.last?.state }, [.cancelled, .started, .cancelled, .scheduled])
    }

    func testRetryIdentityNeverMergesDifferentIdsTurnsOrSteps() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try scheduled(1))
        _ = reducer.apply(try scheduled(2, id: "request-b"))
        _ = reducer.apply(try scheduled(3, turn: 2))
        _ = reducer.apply(try scheduled(4, step: 2))
        _ = reducer.apply(try started(5, turn: 2))
        XCTAssertEqual(retries(reducer).count, 4)
        XCTAssertEqual(Set(retries(reducer).map(\.key)).count, 4)
        XCTAssertEqual(retries(reducer).map { $0.attempts.first?.state }, [.scheduled, .scheduled, .started, .scheduled])
    }

    func testMissingRetryIdDoesNotCreateUncorrelatedChatRows() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try event(1, "llm/retry", #"{"turn":1,"step":1,"retry":1,"delayMs":100,"failure":{"message":"raw"}}"#))
        _ = reducer.apply(try event(2, "llm/retry-started", #"{"turn":1,"step":1,"retry":1}"#))
        _ = reducer.apply(try scheduled(3, id: ""))
        _ = reducer.apply(try started(4, id: ""))
        XCTAssertTrue(reducer.items().isEmpty)
        _ = reducer.apply(try turnEnd(5, error: true))
        XCTAssertEqual(reducer.items().compactMap { if case .turnFailure = $0 { return 1 }; return nil }.count, 1)
    }

    func testAlwaysModeHasNoSyntheticMaximum() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try scheduled(1, mode: "always", maximum: ""))
        let attempt = retries(reducer).first?.attempts.first
        XCTAssertEqual(attempt?.mode, "always")
        XCTAssertNil(attempt?.maxRetries)
    }

    func testDuplicateSequenceAndResumeDoNotDuplicateAttemptsOrFailure() throws {
        let reducer = TranscriptReducer()
        let first = try scheduled(1)
        let begin = try started(2)
        _ = reducer.apply(opening("snapshot", [first], cursor: 1))
        let key = retries(reducer).first?.key
        let beforeDuplicate = reducer.items()
        _ = reducer.apply(first)
        XCTAssertEqual(beforeDuplicate, reducer.items())
        _ = reducer.apply(opening("resume", [first, begin, try scheduled(3, retry: 2)], cursor: 3))
        _ = reducer.apply(opening("resume", [begin, try scheduled(3, retry: 2), try turnEnd(4, error: true)], cursor: 4))
        let beforeTerminalDuplicate = reducer.items()
        _ = reducer.apply(try turnEnd(4, error: true))
        XCTAssertEqual(beforeTerminalDuplicate, reducer.items())
        let chain = retries(reducer).first
        XCTAssertEqual(key, chain?.key)
        XCTAssertEqual(chain?.attempts.map(\.seq), [1, 3])
        XCTAssertEqual(chain?.attempts.map(\.state), [.started, .cancelled])
        XCTAssertEqual(reducer.items().compactMap { if case .turnFailure = $0 { return 1 }; return nil }.count, 1)
    }

    func testPrependMergesChainAcrossPagesAndRebuildsLiveIndex() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(opening("snapshot", [try started(6, retry: 3)], cursor: 6, more: true))
        XCTAssertTrue(retries(reducer).isEmpty)
        XCTAssertTrue(reducer.prepend(records: .array([try started(4, retry: 2), try scheduled(5, retry: 3)]), pageHasMore: true))
        let key = retries(reducer).first?.key
        XCTAssertTrue(reducer.prepend(records: .array([try started(2), try scheduled(3, retry: 2)]), pageHasMore: true))
        XCTAssertTrue(reducer.prepend(records: .array([try scheduled(1)]), pageHasMore: false))
        let chain = retries(reducer).first
        XCTAssertEqual(key, chain?.key)
        XCTAssertEqual(chain?.attempts.map(\.seq), [1, 3, 5])
        XCTAssertTrue(chain?.attempts.allSatisfy { $0.state == .started } == true)
        XCTAssertEqual(reducer.firstSeq, 1)
        XCTAssertFalse(reducer.hasMore)
        XCTAssertFalse(reducer.prepend(records: .array([try scheduled(1)]), pageHasMore: false))
        _ = reducer.apply(try scheduled(7, retry: 4))
        _ = reducer.apply(try started(8, retry: 4))
        XCTAssertEqual(retries(reducer).first?.attempts.count, 4)
        XCTAssertEqual(retries(reducer).first?.attempts.last?.state, .started)
    }

    func testPrependRetainsOrphanStartAndBoundaryPagesWithoutVisibleItems() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(opening("snapshot", [try turnEnd(8, error: true)], cursor: 8, more: true))
        XCTAssertTrue(reducer.prepend(records: .array([try event(7, "step/end", #"{"turn":1,"step":1}"#)]), pageHasMore: true))
        XCTAssertTrue(reducer.prepend(records: .array([try scheduled(5, retry: 2)]), pageHasMore: true))
        XCTAssertTrue(reducer.prepend(records: .array([try started(4)]), pageHasMore: true))
        XCTAssertTrue(reducer.prepend(records: .array([try scheduled(3)]), pageHasMore: false))
        XCTAssertEqual(retries(reducer).first?.attempts.map(\.state), [.started, .cancelled])
        XCTAssertEqual(
            reducer.items().map { item -> String in
                switch item {
                case .retry: return "Retry"
                case .turnFailure: return "TurnFailure"
                default: return "Other"
                }
            },
            ["Retry", "TurnFailure"]
        )
    }

    func testSnapshotResetDropsOldIndexesAndBoundaryEndpoints() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(opening("snapshot", [try scheduled(1), try started(2), try turnEnd(3)], cursor: 3))
        _ = reducer.apply(opening("snapshot", [try scheduled(1)], cursor: 1))
        XCTAssertEqual(retries(reducer).first?.attempts.first?.state, .scheduled)
        _ = reducer.apply(try started(2))
        XCTAssertEqual(retries(reducer).first?.attempts.first?.state, .started)
        _ = reducer.apply(opening("snapshot", [], cursor: 0))
        _ = reducer.apply(try scheduled(1, id: "new"))
        _ = reducer.apply(try turnEnd(2))
        XCTAssertEqual(retries(reducer).first?.retryId, "new")
        XCTAssertEqual(retries(reducer).first?.attempts.first?.state, .cancelled)
    }
}

final class ComposerMetricsTests: XCTestCase {
    private func json(_ value: String) throws -> JSONValue { try JSONValue.parse(value) }
    private func projection(_ r: TranscriptReducer, key: String, seq: Int, value: String) throws -> Bool {
        r.apply(try json(#"{"type":"projection","sessionId":"session","key":"\#(key)","seq":\#(seq),"value":\#(value)}"#))
    }
    private func stats(tokens: Int = 690, ms: Int = 10000) -> String {
        #"{"turns":8,"steps":15,"llmMs":18000,"toolMs":2400,"ttftMs":900,"ttftSteps":3,"decodeMs":\#(ms),"decodeTokens":\#(tokens)}"#
    }
    private let usage = #"{"uncachedInputTokens":800,"cacheReadTokens":0,"cacheWriteTokens":200,"outputTokens":690}"#
    private func opening(type: String = "snapshot", seq: Int = 50, values: String = "", records: String = "") throws -> JSONValue {
        try json(#"{"type":"\#(type)","cursor":\#(seq),"records":[\#(records)],"projections":{"asOfSeq":\#(seq),"values":{\#(values)}}}"#)
    }
    private func event(_ seq: Int, _ time: Int, _ type: String, _ data: String) -> String {
        #"{"type":"event","event":{"seq":\#(seq),"time":\#(time),"type":"\#(type)","data":\#(data)}}"#
    }
    private func start(_ seq: Int, turn: Int, time: Int) -> String {
        event(seq, time, "step/start", #"{"turn":\#(turn),"step":1}"#)
    }
    private func message(_ seq: Int, turn: Int, first: Int, end: Int, tokens: Int) -> String {
        event(seq, end, "assistant/message", #"{"turn":\#(turn),"step":1,"usage":{"inputTokens":50,"outputTokens":\#(tokens)},"stream":[{"type":"text-chunks","index":0,"time0":\#(first),"dt":[0],"texts":["reply"]}],"message":{"content":[{"type":"text","text":"reply"}]}}"#)
    }
    private func declaration(_ seq: Int, _ time: Int, _ callIds: String...) -> String {
        let blocks = callIds.map { #"{"type":"tool-call","id":"\#($0)","name":"read","arguments":"{}"}"# }.joined(separator: ",")
        return event(seq, time, "assistant/message", #"{"turn":1,"step":1,"message":{"content":[\#(blocks)]}}"#)
    }
    private func call(_ seq: Int, _ time: Int, id: String) -> String {
        event(seq, time, "tool/call", #"{"turn":1,"step":1,"callId":"\#(id)","name":"read","arguments":"{}"}"#)
    }
    private func result(_ seq: Int, _ time: Int, id: String, isError: Bool = false) -> String {
        event(seq, time, "tool/result", #"{"turn":1,"step":1,"message":{"role":"tool","source":{"callId":"\#(id)"},"isError":\#(isError),"content":[{"type":"text","text":"done"}]}}"#)
    }

    func testDurableProjectionSuppliesThreeIndependentReadings() throws {
        let r = TranscriptReducer()
        _ = r.apply(try opening(values: #""sessionStats":\#(stats()),"tokenUsage":\#(usage),"contextPressure":{"pressureTokens":12000,"projectedTokens":9000,"contextWindow":100000}"#))
        let m = r.composerMetrics
        XCTAssertTrue(m.activityIsWholeSession)
        XCTAssertEqual(m.activity?.tokensPerSecond, 69)
        XCTAssertEqual(m.activity?.turns, 8)
        XCTAssertEqual(m.activity?.steps, 15)
        XCTAssertEqual(m.activity?.meanTtftMs, 300)
        XCTAssertEqual(m.tokens?.billedInputTokens, 1000)
        XCTAssertEqual(m.tokens?.totalTokens, 1690)
        XCTAssertEqual(m.tokens?.cacheHitPercent, "0")
        XCTAssertEqual(m.context?.percent, 9)
        XCTAssertEqual(m.context?.usedTokens, 9000)
    }

    func testRealZeroIsDistinctFromUnavailable() throws {
        let r = TranscriptReducer()
        XCTAssertNil(r.composerMetrics.activity)
        XCTAssertNil(r.composerMetrics.tokens)
        XCTAssertNil(r.composerMetrics.context)
        _ = try projection(r, key: "sessionStats", seq: 1, value: stats(tokens: 0, ms: 1000))
        _ = try projection(r, key: "tokenUsage", seq: 1, value: usage)
        _ = try projection(r, key: "contextPressure", seq: 1, value: #"{"projectedTokens":0,"pressureTokens":9000,"contextWindow":100000}"#)
        XCTAssertEqual(r.composerMetrics.activity?.tokensPerSecond, 0)
        XCTAssertEqual(r.composerMetrics.tokens?.cacheHitPercent, "0")
        XCTAssertEqual(r.composerMetrics.context?.percent, 0)
        _ = try projection(r, key: "sessionStats", seq: 2, value: stats(ms: 0))
        XCTAssertNil(r.composerMetrics.activity?.tokensPerSecond)
    }

    func testProjectionSequenceIsPerKeyAndIndependentOfFollowCursor() throws {
        let r = TranscriptReducer()
        _ = r.apply(try opening(seq: 100))
        XCTAssertTrue(try projection(r, key: "sessionStats", seq: 80, value: stats()))
        XCTAssertTrue(try projection(r, key: "contextPressure", seq: 3, value: #"{"pressureTokens":9,"contextWindow":100}"#))
        XCTAssertFalse(try projection(r, key: "sessionStats", seq: 80, value: stats(tokens: 1)))
        XCTAssertFalse(try projection(r, key: "sessionStats", seq: 79, value: stats(tokens: 1)))
        XCTAssertEqual(r.composerMetrics.activity?.tokensPerSecond, 69)
        XCTAssertEqual(r.composerMetrics.context?.percent, 9)
        XCTAssertEqual(r.cursor, 100)
    }

    func testSnapshotAndResumeCannotOverwriteNewerPushButClearAbsentCapabilities() throws {
        let r = TranscriptReducer()
        _ = try projection(r, key: "sessionStats", seq: 60, value: stats())
        _ = try projection(r, key: "contextPressure", seq: 60, value: #"{"pressureTokens":9,"contextWindow":100}"#)
        _ = r.apply(try opening(seq: 50, values: #""sessionStats":\#(stats(tokens: 1))"#))
        XCTAssertEqual(r.composerMetrics.activity?.tokensPerSecond, 69)
        XCTAssertEqual(r.composerMetrics.context?.percent, 9)
        _ = r.apply(try opening(type: "resume", seq: 61, values: #""sessionStats":\#(stats(tokens: 700))"#))
        XCTAssertEqual(r.composerMetrics.activity?.tokensPerSecond, 70)
        XCTAssertNil(r.composerMetrics.context)
        _ = r.apply(try opening(type: "resume", seq: 61))
        XCTAssertNil(r.composerMetrics.activity)
    }

    func testFallbackWeightsAllLoadedTimedStepsInsteadOfLastStepOrWholeTurnTime() throws {
        let r = TranscriptReducer()
        _ = r.apply(try opening(seq: 4, records: "\(start(3, turn: 2, time: 1000)),\(message(4, turn: 2, first: 2000, end: 4000, tokens: 100))"))
        XCTAssertFalse(r.composerMetrics.activityIsWholeSession)
        XCTAssertEqual(r.composerMetrics.activity?.tokensPerSecond, 50)
        let page = try json("[\(start(1, turn: 1, time: 100)),\(message(2, turn: 1, first: 200, end: 1200, tokens: 200))]")
        _ = r.prepend(records: page, pageHasMore: false)
        let m = r.composerMetrics
        XCTAssertEqual(m.activity?.tokensPerSecond, 100)
        XCTAssertEqual(m.activity?.turns, 2)
        XCTAssertEqual(m.activity?.llmMs, 4100)
        XCTAssertEqual(m.activity?.meanTtftMs, 550)
        XCTAssertNil(m.tokens)
        _ = r.prepend(records: page, pageHasMore: false)
        XCTAssertEqual(m, r.composerMetrics)
    }

    func testSerialToolsUseDispatchTimesWithoutChangingCardCreationTimes() throws {
        let r = TranscriptReducer()
        let records = [
            start(1, turn: 1, time: 500),
            declaration(2, 1000, "first", "second"),
            call(3, 1000, id: "first"),
            result(4, 2000, id: "first"),
            call(5, 2000, id: "second"),
            result(6, 3000, id: "second"),
        ].joined(separator: ",")
        _ = r.apply(try opening(seq: 6, records: records))
        XCTAssertEqual(r.composerMetrics.activity?.toolMs, 2000)
        XCTAssertFalse(r.composerMetrics.activityIsWholeSession)
        let tools = r.items().compactMap { if case .tool(let t) = $0 { return t }; return nil }
        XCTAssertEqual(tools.map(\.startedAt), [1000, 1000])
        XCTAssertEqual(tools.map(\.endedAt), [2000, 3000])
        XCTAssertEqual(tools.map(\.status), [.ok, .ok])
    }

    func testCacheWriteParticipatesAndPartialHitsNeverRoundToFullHits() {
        XCTAssertEqual(ComposerTokenUsage(uncachedInputTokens: 0, cacheReadTokens: 50, cacheWriteTokens: 50, outputTokens: 5).cacheHitPercent, "50")
        XCTAssertEqual(ComposerTokenUsage(uncachedInputTokens: 0, cacheReadTokens: 50, cacheWriteTokens: 50, outputTokens: 5).totalTokens, 105)
        XCTAssertNil(formatComposerCacheHit(0, 0))
        XCTAssertEqual(formatComposerCacheHit(0, 100), "0")
        XCTAssertEqual(formatComposerCacheHit(100, 100), "100")
        XCTAssertEqual(formatComposerCacheHit(1, 2), "50")
        XCTAssertEqual(formatComposerCacheHit(999, 1000), "99.9")
        XCTAssertEqual(formatComposerCacheHit(9999, 10000), "99.99")
        XCTAssertEqual(formatComposerCacheHit(9_007_199_254_740_990, 9_007_199_254_740_991), "99.99999999999999")
        XCTAssertNil(formatComposerCacheHit(101, 100))
    }

    func testClearingConnectionGenerationAcceptsRestartedHostWatermarks() throws {
        let r = TranscriptReducer()
        _ = try projection(r, key: "contextPressure", seq: 1000, value: #"{"pressureTokens":90,"contextWindow":100}"#)
        r.clearComposerProjections()
        XCTAssertNil(r.composerMetrics.context)
        XCTAssertTrue(try projection(r, key: "contextPressure", seq: 1, value: #"{"pressureTokens":9,"contextWindow":100}"#))
        XCTAssertEqual(r.composerMetrics.context?.percent, 9)
    }

    func testMalformedOrPartialProjectionDoesNotInventZero() throws {
        let r = TranscriptReducer()
        _ = try projection(r, key: "tokenUsage", seq: 1, value: #"{"uncachedInputTokens":40,"cacheReadTokens":0,"outputTokens":1}"#)
        _ = try projection(r, key: "contextPressure", seq: 1, value: #"{"pressureTokens":50,"contextWindow":0}"#)
        _ = try projection(r, key: "sessionStats", seq: 1, value: #"{"decodeMs":1000,"decodeTokens":100}"#)
        XCTAssertNil(r.composerMetrics.tokens)
        XCTAssertNil(r.composerMetrics.activity)
        XCTAssertNil(r.composerMetrics.context)
        _ = try projection(r, key: "contextPressure", seq: 2, value: #"{"pressureTokens":-1,"contextWindow":100}"#)
        XCTAssertNil(r.composerMetrics.context)
    }
}

final class BatchEPolicyTests: XCTestCase {
    func testPermissionLabelOverridesOnlyConventionalBuiltins() {
        XCTAssertEqual(permissionLabel(value: "auto"), "自动审查")
        XCTAssertEqual(permissionLabel(value: "read-only"), "仅可查看")
        XCTAssertEqual(permissionLabel(value: "workspace-write"), "工作区内修改")
        XCTAssertEqual(permissionLabel(value: "danger-full-access"), "完全权限")
        XCTAssertEqual(
            permissionLabel(value: "read-only", option: PermissionOption(value: "read-only", name: "团队只读")),
            "团队只读"
        )
    }

    func testBuiltinCommandNames() {
        XCTAssertEqual(builtinCommandName("@deepseek-ai/dsh-command-goal"), "goal")
        XCTAssertEqual(builtinCommandName("@deepseek-ai/dsh-plan-mode"), "plan")
        XCTAssertEqual(builtinCommandName("@deepseek-ai/dsh-command-feedback"), "feedback")
        XCTAssertEqual(builtinCommandName("@deepseek-ai/dsh-command-compact"), "compact")
        XCTAssertEqual(builtinCommandName("@deepseek-ai/dsh-permission-presets"), "permission")
        XCTAssertEqual(builtinCommandName("@deepseek-ai/dsh-session-log-export"), "export")
        XCTAssertNil(builtinCommandName("@other/custom"))
    }

    func testTodoProgressOmitsZeroCounts() {
        let todos = [
            TodoItem(content: "a", status: "completed"),
            TodoItem(content: "b", status: "in_progress"),
            TodoItem(content: "c", status: "pending"),
        ]
        XCTAssertEqual(todoProgressLabel(todos, en: false), "1 已完成\u{2002}·\u{2002}1 进行中\u{2002}·\u{2002}1 待处理")
        XCTAssertEqual(todoProgressLabel([TodoItem(content: "a", status: "completed")], en: false), "1 已完成")
        XCTAssertEqual(todoProgressLabel([], en: false), "")
    }

    func testGoalPhaseAndQueueArgs() throws {
        XCTAssertEqual(goalPhaseLabel(phase: "active", activation: "armed"), "进行中的目标")
        XCTAssertEqual(goalPhaseLabel(phase: "active", activation: "disarmed"), "已暂停的目标")
        XCTAssertEqual(goalPhaseLabel(phase: "paused", activation: nil), "已暂停的目标")
        let args = queueUpdateArgs(sessionId: "s", itemId: "q1", action: .edit("hello"))
        XCTAssertEqual(args["action"]["kind"].str(), "edit")
        XCTAssertEqual(args["action"]["content"].arr()?.first?["text"].str(), "hello")
        let answers = userQuestionAnswerArgs(
            sessionId: "s",
            callId: "c",
            answers: [.object(["id": .string("q"), "selected": .array([.string("yes")])])]
        )
        XCTAssertEqual(answers["answers"]["answers"].arr()?.count, 1)
        let receipt = UploadReceipt.parse(.object([
            "receiptId": .string("r1"),
            "file": .object(["name": .string("notes.md"), "attachmentId": .string("a1")]),
        ]))
        XCTAssertEqual(receipt?.receiptId, "r1")
        XCTAssertEqual(receipt?.name, "notes.md")
        XCTAssertEqual(receipt?.attachmentId, "a1")
    }

    func testModelPickerOrdersProvidersAndFiltersByName() throws {
        let catalog = ModelCatalog.parse(try JSONValue.parse("""
        {"groups":[
          {"id":"team","name":"Team","models":[{"id":"pro","name":"DeepSeek Pro"},{"id":"plain","name":"Plain Model"}]},
          {"id":"deepseek-account","name":"Account","models":[{"id":"chat","name":"DeepSeek Chat"}]}
        ]}
        """))
        let ordered = modelPickerGroups(catalog.groups, query: "")
        XCTAssertEqual(ordered.map(\.id), ["deepseek-account", "team"])
        let filtered = modelPickerGroups(catalog.groups, query: "pro")
        XCTAssertEqual(filtered.flatMap(\.models).map(\.id), ["pro"])
        XCTAssertEqual(modelPickerProviderLabel("deepseek-account", hostName: "Account"), "DeepSeek 账号")
        XCTAssertEqual(modelPickerProviderLabel("deepseek-account", hostName: "Account", english: true), "DeepSeek Account")
    }

    func testPermissionSelectionWireContract() throws {
        let selection = try PermissionSelection.parse(try JSONValue.parse(#"{"current":"workspace-write"}"#))
        XCTAssertEqual(selection.currentValue, "workspace-write")
        XCTAssertThrowsError(try PermissionSelection.parse(try JSONValue.parse(#"{"value":"workspace-write"}"#)))
    }

    func testComposerTriggerAndOfficialMentionTokens() {
        XCTAssertEqual(composerTrigger("hello @src", cursor: 10)?.query, "src")
        XCTAssertEqual(composerTrigger("/plan", cursor: 5)?.kind, Character("/"))
        XCTAssertEqual(composerTrigger("see /tmp", cursor: 8)?.kind, Character("/"))
        XCTAssertEqual(composerTrigger("see /tmp", cursor: 8)?.query, "tmp")
        XCTAssertNil(composerTrigger("user@host", cursor: 9))
        XCTAssertEqual(fileReferenceToken("src/app.swift", directory: false), "@src/app.swift")
        XCTAssertEqual(fileReferenceToken("my file.swift", directory: false), "@\"my file.swift\"")
        XCTAssertEqual(fileReferenceToken("docs", directory: true), "@docs/")
        let next = replaceComposerToken("hello @sr", cursor: 9, token: "@src/app.swift")
        XCTAssertEqual(next.text, "hello @src/app.swift ")
        let session = composerReferences("@[昨日会话](dsh-session:abc123) more")
        XCTAssertEqual(session.first?.kind, .session)
        XCTAssertEqual(session.first?.label, "昨日会话")
        let file = composerReferences("@notes.md leftover")
        XCTAssertEqual(file.first?.kind, .file)
        XCTAssertEqual(file.first?.path, "notes.md")
        XCTAssertNil(fileReferenceToken("has\"quote", directory: false))
        XCTAssertEqual(queueUpdateArgs(sessionId: "s", itemId: "q", action: .remove)["action"]["kind"].str(), "remove")
        XCTAssertEqual(queueUpdateArgs(sessionId: "s", itemId: "q", action: .steer)["action"]["kind"].str(), "steer")
    }

    func testApprovalAndExportWireContracts() throws {
        XCTAssertEqual(try JSONValue.parse(#"{"accepted":true}"#)["accepted"].bool(), true)
        XCTAssertNotEqual(try JSONValue.parse(#"{"accepted":false}"#)["accepted"].bool(), true)
        XCTAssertNil(try JSONValue.parse(#"{}"#)["accepted"].bool())
        let export = jsonObject([
            "sessionId": .string("s"),
            "includeDescendants": .bool(true),
        ])
        XCTAssertEqual(export["sessionId"].str(), "s")
        XCTAssertEqual(export["includeDescendants"].bool(), true)
        XCTAssertEqual(builtinCommandName("@deepseek-ai/dsh-session-log-export"), "export")
    }
}
