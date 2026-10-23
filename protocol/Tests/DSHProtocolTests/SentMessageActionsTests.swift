import XCTest
@testable import DSHProtocol

final class SentMessageActionsTests: XCTestCase {
    func testCommittedPlainTextAndCanonicalReferencesRemainReplayable() throws {
        let text = "请检查 @[设计会话](dsh-session:design-session) @\"spec files/design.md\"\n保留原始引用"
        let reducer = TranscriptReducer()
        reducer.apply(event(1, content: [textBlock(text)]))
        reducer.apply(.object([
            "type": .string("event"),
            "event": .object([
                "seq": .number(2), "type": .string("user/message"),
                "data": .object([
                    "id": .string("reference-context"),
                    "source": .object([
                        "kind": .string("session-reference"),
                        "references": .array([.object(["label": .string("设计会话")])]),
                    ]),
                    "content": .array([textBlock("Recalled context")]),
                ]),
            ]),
        ]))
        let user = try firstUser(reducer)
        XCTAssertEqual(user.text, text)
        XCTAssertTrue(user.textOnly)
        XCTAssertEqual(user.referenceLabels, ["设计会话"])
        XCTAssertNil(userMessageReplayUnavailable(user, english: false))
        XCTAssertNil(userMessageReplayUnavailable(Item.User(key: "plain", text: "hello"), english: true))
    }

    func testFileAndUnknownContentCannotBecomeTextOnlyOnCommitOrHistoryLoad() throws {
        for type in ["file", "image", "audio", "future-content"] {
            let blocks = [textBlock("Keep this attachment"), JSONValue.object([
                "type": .string(type),
                "attachment": .object(["attachmentId": .string("attachment-1")]),
            ])]
            let reducer = TranscriptReducer()
            reducer.echo(text: "Keep this attachment", requestId: "request-1", files: 1)
            reducer.apply(event(1, content: blocks, requestId: "request-1"))
            let committed = try firstUser(reducer)
            XCTAssertFalse(committed.pending, type)
            XCTAssertFalse(committed.textOnly, type)
            XCTAssertNotNil(userMessageReplayUnavailable(committed, english: false), type)

            let history = TranscriptReducer()
            history.apply(.object([
                "type": .string("snapshot"), "cursor": .number(1),
                "records": .array([event(1, content: blocks)]),
                "projections": .object([:]),
            ]))
            XCTAssertFalse(try firstUser(history).textOnly, type)
            XCTAssertNotNil(userMessageReplayUnavailable(try firstUser(history), english: true), type)
        }
    }

    func testPendingEchoAndImageMetadataCannotBeReplayed() throws {
        let reducer = TranscriptReducer()
        reducer.echo(text: "with file", requestId: "request-1", files: 1)
        let echo = try firstUser(reducer)
        XCTAssertFalse(echo.textOnly)
        XCTAssertNotNil(userMessageReplayUnavailable(echo, english: false))
        let plain = TranscriptReducer()
        plain.echo(text: "sending", requestId: "plain-request")
        XCTAssertNotNil(userMessageReplayUnavailable(try firstUser(plain), english: true))
        plain.apply(event(1, content: [textBlock("sending")], requestId: "plain-request"))
        XCTAssertNil(userMessageReplayUnavailable(try firstUser(plain), english: true))
        XCTAssertNotNil(userMessageReplayUnavailable(Item.User(key: "image", text: "look", images: 1), english: true))
        XCTAssertNotNil(userMessageReplayUnavailable(Item.User(
            key: "image-ref", text: "look", imageRefs: [ImageRef(attachmentId: "image-1")]
        ), english: true))
    }

    func testUnrecoverableReferenceLabelsAreExplicitlyRestricted() throws {
        let user = Item.User(key: "reference", text: "Continue the discussion", referenceLabels: ["Earlier session"])
        XCTAssertNotNil(userMessageReplayUnavailable(user, english: false))
        let partlyRecoverable = Item.User(
            key: "partial", text: "@[Design](dsh-session:design)", referenceLabels: ["Design", "Missing session"]
        )
        XCTAssertNotNil(userMessageReplayUnavailable(partlyRecoverable, english: true))
        XCTAssertNotNil(userMessageReplayUnavailable(Item.User(key: "empty", text: " \n"), english: true))
    }

    private func firstUser(_ reducer: TranscriptReducer) throws -> Item.User {
        try XCTUnwrap(applyingUserReferenceLabels(reducer.items()).compactMap { item -> Item.User? in
            if case .user(let user) = item { return user }
            return nil
        }.first)
    }

    private func textBlock(_ text: String) -> JSONValue {
        .object(["type": .string("text"), "text": .string(text)])
    }

    private func event(_ seq: Int, content: [JSONValue], requestId: String = "request-1") -> JSONValue {
        .object([
            "type": .string("event"),
            "event": .object([
                "seq": .number(Double(seq)), "type": .string("user/message"),
                "data": .object([
                    "id": .string("message-1"),
                    "source": .object(["kind": .string("user"), "rpcId": .string(requestId)]),
                    "content": .array(content),
                ]),
            ]),
        ])
    }
}
