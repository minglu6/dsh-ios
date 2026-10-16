import XCTest
@testable import DSHProtocol

final class SessionNotFoundTests: XCTestCase {
    func testMatchesSlashAndHyphenWireCodesAndPrefixedToast() {
        XCTAssertTrue(SessionNotFoundPolicy.matches(code: "session/not-found"))
        XCTAssertTrue(SessionNotFoundPolicy.matches(code: "session-not-found"))
        XCTAssertTrue(SessionNotFoundPolicy.matches(
            PocketError(code: "session/not-found", message: "session has no live agent")
        ))
        XCTAssertTrue(SessionNotFoundPolicy.matches(
            code: nil,
            message: "session/not-found: Session not found."
        ))
        XCTAssertFalse(SessionNotFoundPolicy.matches(code: "session/queue-item-not-found"))
        XCTAssertFalse(SessionNotFoundPolicy.matches(
            PocketError(code: "session/steer-unavailable", message: "gone")
        ))
        XCTAssertFalse(SessionNotFoundPolicy.matches(code: "transport", message: "closed"))
    }

    func testDropFromListClearsCurrentAndLeavesOtherSelection() {
        let rows = [
            SessionSummary(sessionId: "alive", title: "A"),
            SessionSummary(sessionId: "stale", title: "Old"),
        ]
        let gone = SessionNotFoundPolicy.drop(missingId: "stale", from: rows, currentId: "stale")
        XCTAssertEqual(gone.sessions.map(\.sessionId), ["alive"])
        XCTAssertNil(gone.currentId)
        XCTAssertTrue(gone.droppedCurrent)

        let other = SessionNotFoundPolicy.drop(missingId: "stale", from: rows, currentId: "alive")
        XCTAssertEqual(other.sessions.map(\.sessionId), ["alive"])
        XCTAssertEqual(other.currentId, "alive")
        XCTAssertFalse(other.droppedCurrent)

        let again = SessionNotFoundPolicy.drop(missingId: "stale", from: gone.sessions, currentId: nil)
        XCTAssertEqual(again.sessions.map(\.sessionId), ["alive"])
        XCTAssertFalse(again.droppedCurrent)
    }

    func testDropRemovesMembershipFromWorkspaceProjection() {
        let workspaces = [
            WorkspaceView(workspaceId: "w", path: "/repo", title: "Repo", sessionIds: ["stale", "alive"]),
        ]
        XCTAssertEqual(
            SessionNotFoundPolicy.drop(sessionId: "stale", from: workspaces).first?.sessionIds,
            ["alive"]
        )
    }
}
