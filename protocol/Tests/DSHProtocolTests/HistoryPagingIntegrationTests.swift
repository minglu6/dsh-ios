import XCTest
@testable import DSHProtocol

final class HistoryPagingIntegrationTests: XCTestCase {
    func testConsecutiveOverlappingPagesKeepTranscriptAndInspectorInSync() {
        let reducer = TranscriptReducer()
        let inspector = SessionInspectorLog()
        let snapshot = opening(records: [message(21), message(22), message(23)])
        XCTAssertTrue(reducer.apply(snapshot))
        inspector.apply(snapshot)

        let firstRequest = HistoryPagingPolicy.pageRequest(cursor: reducer.cursor, firstSeq: reducer.firstSeq)
        XCTAssertEqual(firstRequest.beforeSeq, 21)
        let firstPage: JSONValue = .array([message(11), message(12), message(21)])
        XCTAssertTrue(reducer.prepend(records: firstPage, pageHasMore: true))
        inspector.prepend(firstPage)
        XCTAssertEqual(reducer.items().map(\.key), ["u11", "u12", "u21", "u22", "u23"])

        let secondRequest = HistoryPagingPolicy.pageRequest(cursor: reducer.cursor, firstSeq: reducer.firstSeq)
        XCTAssertEqual(secondRequest.beforeSeq, 11)
        XCTAssertEqual(secondRequest.throughSeq, firstRequest.throughSeq, "Prepending must not move the live cursor backwards")
        let secondPage: JSONValue = .array([message(1), message(2), message(11)])
        XCTAssertTrue(reducer.prepend(records: secondPage, pageHasMore: false))
        inspector.prepend(secondPage)
        let sequence: [Int64] = [1, 2, 11, 12, 21, 22, 23]
        XCTAssertEqual(reducer.items().map(\.key), sequence.map { "u\($0)" })
        XCTAssertEqual(inspector.snapshot().compactMap { $0["seq"].long() }, sequence)
        XCTAssertEqual(reducer.items().compactMap { item -> String? in
            guard case .user(let row) = item else { return nil }
            return row.text
        }, sequence.map { "Synthetic retained message \($0)" })
        XCTAssertFalse(HistoryPagingPolicy.canLoadOlder(hasMore: reducer.hasMore, loadingOlder: false, firstSeq: reducer.firstSeq))

        XCTAssertFalse(reducer.prepend(records: secondPage, pageHasMore: false))
        inspector.prepend(secondPage)
        XCTAssertEqual(reducer.items().count, sequence.count)
        XCTAssertEqual(inspector.snapshot().count, sequence.count)
    }

    func testEmptyTerminalPagePreservesExistingContentAndStopsPaging() {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(opening(records: [message(21), message(22)])))
        let originalKeys = reducer.items().map(\.key)
        XCTAssertFalse(HistoryPagingPolicy.canLoadOlder(hasMore: reducer.hasMore, loadingOlder: true, firstSeq: reducer.firstSeq))
        XCTAssertFalse(reducer.prepend(records: .array([]), pageHasMore: false))
        XCTAssertEqual(reducer.items().map(\.key), originalKeys)
        XCTAssertFalse(reducer.hasMore)
    }

    private func opening(records: [JSONValue]) -> JSONValue {
        .object([
            "type": .string("snapshot"), "cursor": .number(23),
            "hasMore": .bool(true), "records": .array(records), "projections": .object([:]),
        ])
    }

    private func message(_ seq: Int) -> JSONValue {
        .object([
            "type": .string("event"),
            "event": .object([
                "type": .string("user/message"), "seq": .number(Double(seq)),
                "data": .object([
                    "id": .string("synthetic-\(seq)"), "role": .string("user"),
                    "source": .object(["kind": .string("user")]),
                    "content": .array([.object(["type": .string("text"), "text": .string("Synthetic retained message \(seq)")])]),
                ]),
            ]),
        ])
    }
}
