import XCTest
@testable import DSHProtocol

final class TodoLifecycleTests: XCTestCase {
    func testCompletedTodosRemainThroughTurnEndAndClearOnNextTurnStart() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(event(1, "turn/start", data: ["turn": .number(1)])))
        XCTAssertTrue(reducer.apply(write(2, value: list(status: "in_progress"))))
        XCTAssertEqual(reducer.todosSnapshot(), [TodoItem(content: "Ship change", status: "in_progress")])
        XCTAssertTrue(reducer.apply(write(3, value: list())))
        XCTAssertTrue(reducer.apply(event(4, "turn/end", data: ["turn": .number(1)])))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
        XCTAssertFalse(reducer.running)

        XCTAssertTrue(reducer.apply(event(5, "turn/start", data: ["turn": .number(2)])))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertTrue(reducer.running)
    }

    func testSnapshotExplicitNullOrEmptyOverridesHistoricalCompletedTodos() {
        for value in [JSONValue.null, .array([])] {
            let reducer = TranscriptReducer()
            XCTAssertTrue(reducer.apply(opening(
                cursor: 4,
                records: [write(2, value: list()), event(3, "turn/end")],
                values: ["todos": value]
            )))
            XCTAssertTrue(reducer.todosSnapshot().isEmpty)
            XCTAssertEqual(reducer.cursor, 4)
        }
    }

    func testSnapshotMissingTodosKeepsHistoricalFold() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(cursor: 4, records: [write(2, value: list()), event(3, "turn/end")])))
        XCTAssertEqual(reducer.todosSnapshot(), completed)

        XCTAssertTrue(reducer.apply(opening(cursor: 6, records: [write(2, value: list()), event(5, "turn/start")])))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
    }

    func testStreamProjectionNullAndEmptyClearWithoutMovingHistoryCursor() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(cursor: 100)))
        XCTAssertTrue(reducer.apply(projection(10, value: list())))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
        XCTAssertTrue(reducer.apply(projection(11, value: .null)))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertTrue(reducer.apply(projection(12, value: list())))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
        XCTAssertTrue(reducer.apply(projection(13, value: .array([]))))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertEqual(reducer.cursor, 100)
    }

    func testTodoWriteEmptyArrayClearsCurrentList() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(write(1, value: list())))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
        XCTAssertTrue(reducer.apply(write(2, value: .array([]))))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
    }

    func testStaleProjectionCannotReviveTodosAfterNewTurn() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(write(10, value: list())))
        XCTAssertTrue(reducer.apply(event(11, "turn/start")))
        XCTAssertFalse(reducer.apply(projection(10, value: list())))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertFalse(reducer.apply(write(10, value: list())))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
    }

    func testNewerProjectionSurvivesOlderTodoAndTurnEventsWithoutSkippingHistory() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(cursor: 10)))
        XCTAssertTrue(reducer.apply(projection(20, value: list(content: "New turn", status: "pending"))))
        XCTAssertTrue(reducer.apply(write(11, value: list())))
        XCTAssertTrue(reducer.apply(event(12, "turn/start", data: ["turn": .number(2)])))
        XCTAssertEqual(reducer.todosSnapshot(), [TodoItem(content: "New turn", status: "pending")])
        XCTAssertEqual(reducer.cursor, 12)
        XCTAssertTrue(reducer.running)
        XCTAssertEqual(reducer.turnRecords().map(\.turn), [2])
        XCTAssertTrue(reducer.apply(event(21, "turn/start", data: ["turn": .number(3)])))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
    }

    func testNewerClearProjectionCannotBeOverwrittenByOlderTodoEvent() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(cursor: 10)))
        XCTAssertTrue(reducer.apply(projection(20, value: .null)))
        XCTAssertTrue(reducer.apply(write(11, value: list())))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertEqual(reducer.cursor, 11)
    }

    func testSameCutProjectionIsIdempotentAndDoesNotRejectFollowingEvent() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(projection(10, value: list())))
        XCTAssertTrue(reducer.apply(projection(10, value: list())))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
        XCTAssertTrue(reducer.apply(write(10, value: list())))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
        XCTAssertEqual(reducer.cursor, 10)
        XCTAssertTrue(reducer.apply(event(11, "turn/start")))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
    }

    func testSnapshotResetsProjectionWatermarkForNewConnection() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(projection(200, value: list())))
        XCTAssertTrue(reducer.apply(opening(cursor: 10, values: ["todos": .null])))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertTrue(reducer.apply(projection(11, value: list(content: "Reconnected", status: "pending"))))
        XCTAssertEqual(reducer.todosSnapshot(), [TodoItem(content: "Reconnected", status: "pending")])
        XCTAssertEqual(reducer.cursor, 10)
    }

    func testReconnectResumeAcceptsLowerProjectionWatermarkWithoutRewindingHistoryCursor() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(cursor: 100, records: [write(10, value: list())])))
        XCTAssertTrue(reducer.apply(projection(200, value: list())))
        reducer.clearComposerProjections()
        XCTAssertTrue(reducer.apply(opening(type: "resume", cursor: 100, asOfSeq: 20, values: ["todos": .null])))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertFalse(reducer.apply(projection(19, value: list())))
        XCTAssertTrue(reducer.apply(projection(21, value: list(content: "Reconnected", status: "pending"))))
        XCTAssertEqual(reducer.todosSnapshot(), [TodoItem(content: "Reconnected", status: "pending")])
        XCTAssertEqual(reducer.cursor, 100)
    }

    func testSameConnectionResumeCannotOverwriteNewerProjection() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(cursor: 10)))
        XCTAssertTrue(reducer.apply(projection(30, value: list())))
        XCTAssertTrue(reducer.apply(opening(type: "resume", cursor: 20, asOfSeq: 20, values: ["todos": .null])))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
        XCTAssertFalse(reducer.apply(projection(29, value: .null)))
        XCTAssertEqual(reducer.todosSnapshot(), completed)
    }

    func testResumeNullAndEmptyOverrideCompletedListButMissingKeyKeepsIt() {
        for value in [JSONValue.null, .array([])] {
            let reducer = TranscriptReducer()
            XCTAssertTrue(reducer.apply(write(1, value: list())))
            XCTAssertTrue(reducer.apply(opening(type: "resume", cursor: 2)))
            XCTAssertEqual(reducer.todosSnapshot(), completed)
            XCTAssertTrue(reducer.apply(opening(type: "resume", cursor: 3, values: ["todos": value])))
            XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        }
    }

    func testResumeReplaysNewTurnBeforeMissingProjectionBaseline() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(write(1, value: list())))
        XCTAssertTrue(reducer.apply(opening(type: "resume", cursor: 3, records: [event(2, "turn/start"), event(3, "turn/end")])))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
    }

    func testReconnectPreservesDurableTodoEventBarrierWhenDroppingOldProjectionWatermark() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(write(10, value: list())))
        XCTAssertTrue(reducer.apply(projection(100, value: .null)))
        XCTAssertTrue(reducer.apply(event(20, "turn/start")))
        reducer.clearComposerProjections()
        XCTAssertTrue(reducer.apply(opening(type: "resume", cursor: 20, asOfSeq: 15, values: ["todos": list()])))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertFalse(reducer.apply(projection(19, value: list())))
        XCTAssertTrue(reducer.apply(projection(21, value: list(content: "Current", status: "pending"))))
        XCTAssertEqual(reducer.todosSnapshot(), [TodoItem(content: "Current", status: "pending")])
    }

    func testPrependingOldCompletedTodoHistoryDoesNotReviveClearedList() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(cursor: 30, records: [event(20, "turn/start")], values: ["todos": .null])))
        XCTAssertTrue(reducer.prepend(records: .array([
            event(1, "turn/start", data: ["turn": .number(1)]),
            write(2, value: list()),
            event(3, "turn/end", data: ["turn": .number(1)]),
        ]), pageHasMore: false))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
        XCTAssertEqual(reducer.cursor, 30)
        XCTAssertEqual(reducer.firstSeq, 1)
        XCTAssertFalse(reducer.apply(projection(2, value: list())))
        XCTAssertTrue(reducer.todosSnapshot().isEmpty)
    }

    private var completed: [TodoItem] {
        [TodoItem(content: "Ship change", status: "completed")]
    }

    private func list(content: String = "Ship change", status: String = "completed") -> JSONValue {
        .array([.object(["content": .string(content), "status": .string(status)])])
    }

    private func write(_ seq: Int, value: JSONValue) -> JSONValue {
        event(seq, "todo/write", data: ["todos": value])
    }

    private func event(_ seq: Int, _ type: String, data: [String: JSONValue] = [:]) -> JSONValue {
        .object([
            "type": .string("event"),
            "event": .object([
                "seq": .number(Double(seq)), "type": .string(type), "data": .object(data),
            ]),
        ])
    }

    private func projection(_ seq: Int, value: JSONValue) -> JSONValue {
        .object([
            "type": .string("projection"), "key": .string("todos"),
            "seq": .number(Double(seq)), "value": value,
        ])
    }

    private func opening(
        type: String = "snapshot",
        cursor: Int,
        asOfSeq: Int? = nil,
        records: [JSONValue] = [],
        values: [String: JSONValue] = [:]
    ) -> JSONValue {
        .object([
            "type": .string(type), "cursor": .number(Double(cursor)), "records": .array(records),
            "projections": .object([
                "asOfSeq": .number(Double(asOfSeq ?? cursor)), "values": .object(values),
            ]),
        ])
    }
}
