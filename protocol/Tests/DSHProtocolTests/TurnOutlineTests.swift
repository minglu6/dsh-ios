import XCTest
@testable import DSHProtocol

final class TurnOutlineTests: XCTestCase {
    func testWholeLogProjectionUsesHostIdentitiesAndLatestPerKeySequence() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(snapshot(outline: .array([entry(21, 2100), entry(3, 300)]))))
        XCTAssertEqual(reducer.turnOutline().map(\.turn), [3, 21])
        XCTAssertFalse(reducer.apply(projection(seq: 10, value: .array([entry(999, 999)]))))
        XCTAssertEqual(reducer.turnOutline().map(\.turn), [3, 21])
        XCTAssertTrue(reducer.apply(projection(seq: 11, value: .null)))
        XCTAssertTrue(reducer.turnOutline().isEmpty)
    }

    func testMalformedCoordinatesDropButMalformedPreviewsRemainNavigable() {
        let store = TurnOutlineProjectionStore()
        store.apply(.array([
            .object(["turn": .string("3"), "seq": .number(3)]),
            .object(["turn": .number(4), "seq": .number(-0.0)]),
            .object(["turn": .number(5), "seq": .number(2.5)]),
            .object(["turn": .number(6), "seq": .number(9_007_199_254_740_992)]),
            .object(["turn": .number(21), "seq": .number(2100), "prompt": .bool(true)]),
            entry(21, 2200),
        ]), seq: 1)
        XCTAssertEqual(store.entries, [TurnOutlineEntry(turn: 21, seq: 2200)])
    }

    func testMissingResumeProjectionClearsObsoleteOutlineAndSnapshotResetsSequence() {
        let reducer = TranscriptReducer()
        reducer.apply(snapshot(outline: .array([entry(3, 300)])))
        reducer.apply(.object(["type": .string("resume"), "cursor": .number(11),
            "records": .array([]), "projections": .object(["asOfSeq": .number(11), "values": .object([:])])]))
        XCTAssertTrue(reducer.turnOutline().isEmpty)
        reducer.apply(snapshot(outline: .array([entry(8, 800)])))
        XCTAssertEqual(reducer.turnOutline().map(\.turn), [8])
    }

    func testLoadedRowsMergeWithUnloadedOutlineAndSteeringKeepsTurn() {
        let rows: [ChatRow] = [
            .user(Item.User(key: "pending", text: "Not a Host turn", pending: true)),
            .user(Item.User(key: "idle", text: "Before known boundary", seq: 10)),
            .user(Item.User(key: "u8", text: "First prompt", seq: 801)),
            .user(Item.User(key: "steering", text: "Steer within turn", seq: 802)),
            .answer(Item.Text(key: "a8", text: "Readable answer", live: false, turn: 8)),
        ]
        let marks = transcriptTurnMarks(rows: rows, turns: [TurnRecord(turn: 8, startSeq: 800, endSeq: 803)],
            outline: [TurnOutlineEntry(turn: 3, seq: 300, prompt: "Unloaded prompt"), TurnOutlineEntry(turn: 8, seq: 800)])
        XCTAssertEqual(marks.map(\.turn), [3, 8])
        XCTAssertNil(marks[0].anchorKey)
        XCTAssertEqual(marks[0].seq, 300)
        XCTAssertEqual(marks[1].anchorKey, "u8")
        XCTAssertEqual(marks[1].prompt, "First prompt")
        XCTAssertEqual(marks[1].response, "Readable answer")
    }

    func testLegacyHostDoesNotInventUnknownTurns() {
        let rows: [ChatRow] = [.user(Item.User(key: "u", text: "No identity", seq: 1)),
            .answer(Item.Text(key: "a", text: "Host turn 21", live: false, turn: 21))]
        let marks = transcriptTurnMarks(rows: rows, turns: [], outline: [])
        XCTAssertEqual(marks.map(\.turn), [21])
        XCTAssertEqual(marks.first?.anchorKey, "a")
    }

    private func entry(_ turn: Int, _ seq: Int) -> JSONValue {
        .object(["turn": .number(Double(turn)), "seq": .number(Double(seq))])
    }
    private func snapshot(outline: JSONValue) -> JSONValue {
        .object(["type": .string("snapshot"), "cursor": .number(10), "records": .array([]),
            "projections": .object(["asOfSeq": .number(10), "values": .object(["turnOutline": outline])])])
    }
    private func projection(seq: Int, value: JSONValue) -> JSONValue {
        .object(["type": .string("projection"), "key": .string("turnOutline"), "seq": .number(Double(seq)), "value": value])
    }
}
