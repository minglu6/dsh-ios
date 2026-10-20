import XCTest
@testable import DSHProtocol

final class WorkspaceChangesResponseTests: XCTestCase {
    func testOnlyExplicitNullMeansComparisonUnavailable() throws {
        XCTAssertNil(try WorkspaceChangesSummary.decodePocketResult(JSONValue.parse(#"{"summary":null}"#)))
        XCTAssertNil(try WorkspaceFileDiff.decodePocketResult(JSONValue.parse(#"{"diff":null}"#)))
        for raw in ["null", "{}", "[]", #"{"summary":{}}"#, #"{"summary":false}"#] {
            XCTAssertThrowsError(try WorkspaceChangesSummary.decodePocketResult(JSONValue.parse(raw)), raw)
        }
        for raw in ["null", "{}", "[]", #"{"diff":{}}"#, #"{"diff":false}"#] {
            XCTAssertThrowsError(try WorkspaceFileDiff.decodePocketResult(JSONValue.parse(raw)), raw)
        }
    }

    func testMalformedSummaryDoesNotShiftHostFileIndices() throws {
        let raw = #"{"summary":{"turn":1,"total":2,"added":1,"deleted":1,"files":[{"path":"a","display":"a","added":1,"deleted":0},{"path":"b","display":"b","added":"1","deleted":1}]}}"#
        XCTAssertThrowsError(try WorkspaceChangesSummary.decodePocketResult(JSONValue.parse(raw)))
    }

    func testPocketDiffDecodingPreservesFileIdentityAndEmptyExistenceStates() throws {
        for (before, after, notice) in [(false, true, ChangesDiffNotice.created), (true, false, .deleted), (true, true, .unchanged)] {
            let raw = """
            {"diff":{"kind":"text","path":"dir/empty.txt","display":"empty.txt","before":\(before),"after":\(after),"coarse":false,"hunks":[]}}
            """
            let diff = try XCTUnwrap(WorkspaceFileDiff.decodePocketResult(JSONValue.parse(raw)))
            XCTAssertEqual(diff.path, "dir/empty.txt")
            XCTAssertEqual(changesDiffNoticeKind(diff), notice)
            XCTAssertTrue(changeDiffLines(diff).isEmpty)
        }
        for kind in ["binary", "oversized"] {
            let raw = """
            {"diff":{"kind":"\(kind)","path":"asset","display":"asset"}}
            """
            let diff = try XCTUnwrap(WorkspaceFileDiff.decodePocketResult(JSONValue.parse(raw)))
            XCTAssertEqual(changesDiffNoticeKind(diff)?.rawValue, kind)
            XCTAssertTrue(changeDiffLines(diff).isEmpty)
        }
    }

    func testDiffLineCapSpansHunksWithoutShiftingAdditionOrDeletionNumbers() {
        let diff = WorkspaceFileDiff(kind: "text", path: "a", display: "a", hunks: [
            WorkspaceDiffHunk(oldStart: 5, newStart: 8, lines: ["-removed", "+replacement"]),
            WorkspaceDiffHunk(oldStart: 100, newStart: 200, lines: (0..<5000).map { "+line-\($0)" }),
        ])
        let lines = changeDiffLines(diff)
        XCTAssertEqual(lines.count, 5000)
        XCTAssertEqual(lines[0], ChangeDiffLine(old: 5, new: nil, text: "-removed"))
        XCTAssertEqual(lines[1], ChangeDiffLine(old: nil, new: 8, text: "+replacement"))
        XCTAssertEqual(lines.last, ChangeDiffLine(old: nil, new: 5197, text: "+line-4997"))
    }
}
