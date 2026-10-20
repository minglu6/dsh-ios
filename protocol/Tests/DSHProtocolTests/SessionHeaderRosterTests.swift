import XCTest
@testable import DSHProtocol

final class SessionHeaderRosterTests: XCTestCase {
    func testLegacyDiscoveryExcludesForksOtherParentsAndDuplicates() {
        let child = SessionSummary(sessionId: "child", title: "Worker", running: true, parentSessionId: "root", origin: "subagent")
        let sessions = [
            child, child,
            SessionSummary(sessionId: "fork", parentSessionId: "root", origin: "fork"),
            SessionSummary(sessionId: "other", parentSessionId: "elsewhere", origin: "subagent"),
            SessionSummary(sessionId: "root", parentSessionId: "root", origin: "subagent"),
        ]
        let rows = sessionHeaderSubagents(parentSessionId: "root", catalog: nil, sessions: sessions)
        XCTAssertEqual(rows.map(\.id), ["child"])
        XCTAssertEqual(rows.first?.running, true)
        XCTAssertEqual(rows.first?.mode, "unknown")
    }

    func testAuthoritativeEmptyCatalogDoesNotReviveRemovedChild() {
        let sessions = [SessionSummary(sessionId: "stale", parentSessionId: "root", origin: "subagent")]
        XCTAssertTrue(sessionHeaderSubagents(parentSessionId: "root", catalog: [], sessions: sessions).isEmpty)
    }

    func testCatalogPreservesExternalMembershipAndUnknownActivity() throws {
        var projection = SessionHeaderProjection()
        projection.apply(frame: try JSONValue.parse(#"{"kind":"sequenced","asOfSeq":8,"values":{"subagentCatalog":[{"id":"child","mode":"continuable","label":"Catalog name","createdAt":1},{"id":"external","mode":"external","createdAt":2}]}}"#))
        let rows = sessionHeaderSubagents(parentSessionId: "root", catalog: projection.subagents, sessions: [
            SessionSummary(sessionId: "child", title: "Earlier name", running: false, parentSessionId: "root", origin: "subagent"),
            SessionSummary(sessionId: "removed", parentSessionId: "root", origin: "subagent"),
        ])
        XCTAssertEqual(rows.map(\.id), ["child", "external"])
        XCTAssertEqual(rows[0].title, "Catalog name")
        XCTAssertEqual(rows[0].running, false)
        XCTAssertNil(rows[1].running)
        XCTAssertEqual(rows[1].mode, "external")
    }
}
