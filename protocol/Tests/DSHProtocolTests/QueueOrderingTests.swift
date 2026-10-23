import XCTest
@testable import DSHProtocol

final class QueueOrderingTests: XCTestCase {
    func testEnqueueAndDeleteInEitherDeliveryOrder() throws {
        for projectionFirst in [false, true] {
            let reducer = TranscriptReducer()
            reducer.setRunning(true)
            reducer.echo(text: "same text", requestId: "r1")
            let message = message("m1", request: "r1")
            let insert = splice(seq: 1, inserted: [message])
            let snapshot = projection(seq: 1, messages: [message])
            for frame in projectionFirst ? [snapshot, insert] : [insert, snapshot] { reducer.apply(frame) }
            XCTAssertEqual(reducer.queueMessages().map(\.id), ["m1"])
            XCTAssertFalse(try XCTUnwrap(reducer.queueMessages().first).sending)
            let remove = splice(seq: 2, removed: 1, canceled: true)
            let empty = projection(seq: 2)
            for frame in projectionFirst ? [empty, remove] : [remove, empty] { reducer.apply(frame) }
            XCTAssertEqual(reducer.queueMessages().map(\.id), [])
        }
    }

    func testFutureProjectionDoesNotReplayInsertionsOrLoseLaterEdits() {
        let reducer = TranscriptReducer()
        reducer.setRunning(true)
        reducer.echo(text: "same text", requestId: "r1")
        let first = message("m1", request: "r1")
        let second = message("m2", request: "r2")
        reducer.apply(projection(seq: 3, messages: [second]))
        reducer.apply(splice(seq: 1, inserted: [first]))
        reducer.apply(splice(seq: 2, start: 1, inserted: [second]))
        reducer.apply(splice(seq: 3, removed: 1, canceled: true))
        XCTAssertEqual(reducer.queueMessages().map(\.id), ["m2"])
        let edited = message("m2", request: "r2", text: "edited")
        reducer.apply(splice(seq: 4, removed: 1, inserted: [edited], canceled: true))
        XCTAssertEqual(reducer.queueMessages().map(\.text), ["edited"])
        reducer.apply(projection(seq: 2, messages: [first, second]))
        XCTAssertEqual(reducer.queueMessages().map(\.text), ["edited"])
    }

    func testIdenticalTextRemainsTwoIndependentlyRemovableMessages() {
        let reducer = TranscriptReducer()
        let first = message("m1", request: "r1")
        let second = message("m2", request: "r2")
        reducer.apply(projection(seq: 2, messages: [first, second]))
        reducer.apply(splice(seq: 1, inserted: [first]))
        reducer.apply(splice(seq: 2, start: 1, inserted: [second]))
        XCTAssertEqual(reducer.queueMessages().map(\.id), ["m1", "m2"])
        reducer.apply(splice(seq: 3, removed: 1, canceled: true))
        XCTAssertEqual(reducer.queueMessages().map(\.id), ["m2"])
    }

    func testSnapshotSeedsSubsequentRemoval() {
        let reducer = TranscriptReducer()
        let first = message("m1", request: "r1")
        reducer.apply(.object([
            "type": .string("snapshot"), "cursor": .number(10), "records": .array([]),
            "projections": .object(["asOfSeq": .number(10), "values": .object([
                "inbox": inbox([first])
            ])])
        ]))
        XCTAssertEqual(reducer.queueMessages().map(\.id), ["m1"])
        reducer.apply(splice(seq: 11, removed: 1, canceled: true))
        XCTAssertEqual(reducer.queueMessages().map(\.id), [])
    }

    func testProjectionAheadOfClaimPreservesWakingMessage() {
        let reducer = TranscriptReducer()
        let notice: JSONValue = .object([
            "id": .string("notice"), "source": .object(["kind": .string("tool-jobs")]),
            "content": .array([.object(["type": .string("text"), "text": .string("job finished")])])
        ])
        reducer.apply(splice(seq: 1, inserted: [notice]))
        reducer.apply(projection(seq: 2))
        reducer.apply(splice(seq: 2, removed: 1))
        reducer.apply(.object(["type": .string("event"), "event": .object([
            "seq": .number(3), "type": .string("user/message"), "data": notice
        ])]))
        let waking = reducer.items().compactMap { item -> Bool? in
            if case .context(let context) = item, context.messageId == "notice" { return context.waking }
            return nil
        }
        XCTAssertEqual(waking, [true])
        XCTAssertEqual(reducer.queueMessages().map(\.id), [])
    }

    private func message(_ id: String, request: String, text: String = "same text") -> JSONValue {
        .object(["id": .string(id), "source": .object(["kind": .string("user"), "rpcId": .string(request)]),
                 "content": .array([.object(["type": .string("text"), "text": .string(text)])])])
    }

    private func inbox(_ messages: [JSONValue]) -> JSONValue {
        .object(["next-turn": .array(messages), "next-step": .array([])])
    }

    private func projection(seq: Int, messages: [JSONValue] = []) -> JSONValue {
        .object(["type": .string("projection"), "key": .string("inbox"),
                 "seq": .number(Double(seq)), "value": inbox(messages)])
    }

    private func splice(seq: Int, start: Int = 0, removed: Int = 0, inserted: [JSONValue] = [], canceled: Bool = false) -> JSONValue {
        .object(["type": .string("event"), "event": .object([
            "seq": .number(Double(seq)), "type": .string("agent/inbox/spliced"), "data": .object([
                "target": .string("next-turn"), "start": .number(Double(start)), "removedCount": .number(Double(removed)),
                "inserted": .array(inserted), "outcome": canceled ? .string("canceled") : .null
            ])
        ])])
    }
}
