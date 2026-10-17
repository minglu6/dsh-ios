import XCTest
@testable import DSHProtocol

final class UserQuestionStoreTests: XCTestCase {
    private let store = UserQuestionStore()

    private func json(_ text: String) throws -> JSONValue {
        try JSONValue.parse(text)
    }

    private func question(id: String = "call", state: String = "open") -> String {
        """
        {"callId":"\(id)","state":"\(state)","questions":[{"id":"q","question":"Choose an update","options":[{"label":"Rebase (推荐)","description":"Keep the local commit"},{"label":"Merge"}]}]}
        """
    }

    private func baseline(seq: Int, active: String, inbox: String = "{}", session: String = "s1") throws {
        store.apply(
            sessionId: session,
            frame: try json(
                """
                {"type":"snapshot","cursor":\(seq),"projections":{"asOfSeq":\(seq),"values":{"userQuestions":{"active":[\(active)],"settled":[]},"inbox":\(inbox)}}}
                """
            )
        )
    }

    private func projection(seq: Int, active: String, session: String = "s1") throws {
        store.apply(
            sessionId: session,
            frame: try json(
                """
                {"type":"projection","sessionId":"\(session)","key":"userQuestions","seq":\(seq),"value":{"active":[\(active)],"settled":[]}}
                """
            )
        )
    }

    private func inbox(seq: Int, value: String) throws {
        store.apply(
            sessionId: "s1",
            frame: try json(
                """
                {"type":"projection","sessionId":"s1","key":"inbox","seq":\(seq),"value":\(value)}
                """
            )
        )
    }

    func testOpeningExistingSessionRecoversQuestionsWithoutAnOfferPush() throws {
        try baseline(seq: 20, active: question())
        let recovered = store.questions()
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(recovered[0].sessionId, "s1")
        XCTAssertEqual(recovered[0].callId, "call")
        XCTAssertEqual(recovered[0].questions[0].options.first?.description, "Keep the local commit")
        XCTAssertEqual(recovered[0].state, "open")
    }

    func testContinuedProjectionSurvivesForegroundCloseAndClosesWhenAnsweredElsewhere() throws {
        store.offer(try json(
            """
            {"questionId":"call","sessionId":"s1","callId":"call","wait":{"callId":"call"},"questions":[{"id":"q","question":"Choose"}]}
            """
        ))
        try baseline(seq: 20, active: question())
        try projection(seq: 22, active: question(state: "continued"))
        store.close(questionId: "call")
        XCTAssertEqual(store.questions().single().state, "continued")
        try projection(seq: 21, active: question())
        XCTAssertEqual(store.questions().single().state, "continued")
        try projection(seq: 23, active: "")
        XCTAssertTrue(store.questions().isEmpty)
    }

    func testQueuedReplySuppressesDuplicateAnswerAndDiscardReopensQuestion() throws {
        let reply = """
        {"next-step":[{"id":"reply","source":{"kind":"user-question-reply","callId":"call"}}]}
        """
        try baseline(seq: 20, active: question(state: "continued"), inbox: reply)
        XCTAssertTrue(store.questions().isEmpty)
        try inbox(seq: 21, value: "{}")
        XCTAssertEqual(store.questions().single().callId, "call")
        store.submitted(sessionId: "s1", callId: "call")
        XCTAssertTrue(store.questions().isEmpty)
        try projection(seq: 22, active: question(state: "continued"))
        XCTAssertTrue(store.questions().isEmpty)
        try inbox(seq: 23, value: reply)
        try inbox(seq: 24, value: "{}")
        XCTAssertEqual(store.questions().single().callId, "call")
        try inbox(seq: 22, value: reply)
        XCTAssertEqual(store.questions().single().callId, "call")
    }

    func testContinuedTransitionReleasesUnconfirmedForegroundSubmission() throws {
        try baseline(seq: 20, active: question())
        store.submitted(sessionId: "s1", callId: "call")
        try projection(seq: 21, active: question())
        XCTAssertTrue(store.questions().isEmpty)
        try projection(seq: 22, active: question(state: "continued"))
        XCTAssertEqual(store.questions().single().state, "continued")
    }

    func testSessionsRemainIsolatedAndReconnectAllowsLowerHostWatermark() throws {
        try baseline(seq: 50, active: question(id: "first"))
        try baseline(seq: 80, active: question(id: "second"), session: "s2")
        try projection(seq: 51, active: "")
        XCTAssertEqual(store.questions().single().sessionId, "s2")
        store.clear()
        try baseline(seq: 2, active: question(id: "restored", state: "continued"))
        XCTAssertEqual(store.questions().single().callId, "restored")
        store.close(questionId: "restored", sessionId: "s2")
        XCTAssertEqual(store.questions().single().callId, "restored")
        store.apply(
            sessionId: "s1",
            frame: try json(
                """
                {"type":"projection","sessionId":"s2","key":"userQuestions","seq":99,"value":{"active":[]}}
                """
            )
        )
        XCTAssertEqual(store.questions().single().callId, "restored")
    }

    func testCopiedCallIdsRemainScopedToTheirSession() throws {
        try baseline(seq: 10, active: question(), session: "s1")
        try baseline(seq: 10, active: question(), session: "s2")
        XCTAssertEqual(Set(store.questions().compactMap(\.sessionId)), ["s1", "s2"])
        store.submitted(sessionId: "s1", callId: "call")
        XCTAssertEqual(store.questions().single().sessionId, "s2")
        store.close(questionId: "call", sessionId: "s1")
        XCTAssertEqual(store.questions().single().sessionId, "s2")
    }

    func testSnapshotWithoutUserQuestionsKeyLeavesLiveOffer() throws {
        store.offer(try json(
            """
            {"questionId":"call","sessionId":"s1","callId":"call","wait":{"callId":"call"},"questions":[{"id":"q","question":"Choose"}]}
            """
        ))
        store.apply(
            sessionId: "s1",
            frame: try json(
                """
                {"type":"snapshot","cursor":10,"projections":{"asOfSeq":10,"values":{"title":"keep"}}}
                """
            )
        )
        XCTAssertEqual(store.questions().single().questionId, "call")
    }

    func testLegacyUnkeyedOfferSurvivesSnapshotUntilExplicitClose() throws {
        store.offer(try json(
            """
            {"questionId":"legacy","sessionId":"s1","questions":[{"id":"q","question":"Choose"}]}
            """
        ))
        try baseline(seq: 10, active: "")
        XCTAssertEqual(store.questions().single().questionId, "legacy")
        store.close(questionId: "legacy")
        XCTAssertTrue(store.questions().isEmpty)
    }
}

private extension Array where Element == UserQuestion {
    func single() -> UserQuestion {
        XCTAssertEqual(count, 1)
        return self[0]
    }
}

final class UserQuestionDraftTests: XCTestCase {
    func testParseRecommendedLabelMatchesDesktopSuffix() {
        XCTAssertEqual(parseRecommendedLabel("First (recommended)  ").recommended, true)
        XCTAssertEqual(parseRecommendedLabel("First（推荐）").recommended, true)
        XCTAssertEqual(parseRecommendedLabel("Use existing setup （ReCoMmEnDeD）").recommended, true)
        XCTAssertEqual(parseRecommendedLabel("Recommended approach").recommended, false)
        let stripped = parseRecommendedLabel("Rebase (推荐)")
        XCTAssertEqual(stripped.label, "Rebase")
        XCTAssertTrue(stripped.recommended)
    }

    func testOnlyMarkedFirstOptionCreatesDefaultAndExplicitEmptyDraftWins() {
        let unmarked = UserQuestionItem(
            id: "one",
            question: "Choose",
            options: [
                UserQuestionOption(label: "First"),
                UserQuestionOption(label: "Second (推荐)"),
            ],
            multiSelect: false
        )
        XCTAssertFalse(initialQuestionDraft(unmarked).answered)
        let marked = UserQuestionItem(
            id: "one",
            question: "Choose",
            options: [UserQuestionOption(label: "First (推荐)")],
            multiSelect: false
        )
        XCTAssertEqual(initialQuestionDraft(marked).selected, ["First (推荐)"])
        let question = UserQuestion(
            questionId: "q",
            sessionId: "s1",
            callId: "call",
            questions: [marked]
        )
        let empty = questionAnswers(question, drafts: ["one": QuestionDraft()])
        XCTAssertEqual(empty[0]["selected"].arr()?.count, 0)
    }

    func testQuestionAnswersSkipCustomAndMultiselectRulesMatchDesktop() {
        let question = UserQuestion(
            questionId: "q",
            sessionId: "s1",
            callId: "call",
            questions: [
                UserQuestionItem(
                    id: "one",
                    question: "Single",
                    options: [UserQuestionOption(label: "A (推荐)")],
                    multiSelect: false
                ),
                UserQuestionItem(
                    id: "two",
                    question: "Multiple",
                    options: [UserQuestionOption(label: "B")],
                    multiSelect: true
                ),
                UserQuestionItem(
                    id: "three",
                    question: "Skipped",
                    options: [UserQuestionOption(label: "C")],
                    multiSelect: false
                ),
            ]
        )
        let drafts: [String: QuestionDraft] = [
            "one": QuestionDraft(selected: [], custom: " custom one "),
            "two": QuestionDraft(selected: ["B"], custom: "extra"),
            "three": QuestionDraft(skipped: true),
        ]
        let answers = questionAnswers(question, drafts: drafts)
        XCTAssertEqual(answers[0]["selected"].arr()?.count, 0)
        XCTAssertEqual(answers[0]["custom"].str(), "custom one")
        XCTAssertEqual(answers[1]["selected"].arr()?.compactMap { $0.str() }, ["B"])
        XCTAssertEqual(answers[1]["custom"].str(), "extra")
        XCTAssertEqual(answers[2]["selected"].arr()?.count, 0)
        XCTAssertTrue(answers[2]["custom"].isNull)
        XCTAssertEqual(firstIncompleteQuestionIndex(question, drafts: [
            "one": QuestionDraft(),
            "two": QuestionDraft(selected: ["B"]),
        ]), 0)
        XCTAssertNil(firstIncompleteQuestionIndex(question, drafts: drafts))
    }

    func testQuestionComposerCopyMatchesDesktopLocales() {
        XCTAssertEqual(questionRecommendedBadge(english: false), "推荐")
        XCTAssertEqual(questionRecommendedBadge(english: true), "Recommended")
        XCTAssertEqual(questionUnansweredError(english: false), "请选择一个选项或填写自定义答案。")
        XCTAssertEqual(questionIncompleteError(english: false), "请先完成这道问题。")
        XCTAssertEqual(questionWaitContinued(english: false), "已继续工作，仍可回答")
        XCTAssertEqual(questionWaitContinued(english: true), "Work continued — you can still answer")
        XCTAssertEqual(questionResubmitHint(english: false), "回答未送达，工作已继续，请再提交一次。")
        XCTAssertEqual(questionPreviousLabel(english: true), "Previous question")
        XCTAssertEqual(askPendingDetail(english: false), "等待中的问题仍可在输入框中回答")
    }
}
