import XCTest
@testable import DSHProtocol

final class TerminalTypefaceTests: XCTestCase {
    func testCascadeLeadsWithBundledNerdFace() {
        XCTAssertEqual(TerminalTypefacePolicy.bundledFamily, "MesloLGLDZ Nerd Font")
        XCTAssertEqual(TerminalTypefacePolicy.bundledPostScript, "MesloLGLDZNF-Regular")
        XCTAssertEqual(TerminalTypefacePolicy.cascadeFamilies.first, TerminalTypefacePolicy.bundledFamily)
        XCTAssertTrue(TerminalTypefacePolicy.cascadeFamilies.contains("Menlo"))
        XCTAssertTrue(TerminalTypefacePolicy.cascadeFamilies.contains("Apple Symbols"))
        XCTAssertEqual(TerminalTypefacePolicy.uiAppFontPath, "Fonts/MesloLGLDZNerdFont-Regular.ttf")
        XCTAssertEqual(TerminalTypefacePolicy.bundleSubdirectory, "Fonts")
    }

    func testCellWidthNeverDropsBelowOne() {
        XCTAssertEqual(TerminalCellLayout.cellWidth(glyphWidth: 8.25), 8.25)
        XCTAssertEqual(TerminalCellLayout.cellWidth(glyphWidth: 0.2), 1)
        XCTAssertEqual(TerminalCellLayout.cellWidth(glyphWidth: 0), 1)
    }

    func testCellHeightPicksLineHeightOrAspect() {
        XCTAssertEqual(TerminalCellLayout.inset, 8)
        XCTAssertEqual(TerminalCellLayout.lineHeightMultiple, 1.35)
        XCTAssertEqual(TerminalCellLayout.minHeightToWidth, 1.6)
        XCTAssertEqual(
            TerminalCellLayout.cellHeight(lineHeight: 10, cellWidth: 8),
            13.5,
            accuracy: 1e-12,
            "10 * 1.35 = 13.5 beats 8 * 1.6 = 12.8"
        )
        XCTAssertEqual(
            TerminalCellLayout.cellHeight(lineHeight: 8, cellWidth: 10),
            16,
            accuracy: 1e-12,
            "10 * 1.6 = 16 beats 8 * 1.35 = 10.8"
        )
        XCTAssertEqual(
            TerminalCellLayout.cellHeight(lineHeight: 16, cellWidth: 13.5),
            21.6,
            accuracy: 1e-12
        )
    }

    func testGridUsesInsetAndTruncatesTowardZero() {
        XCTAssertEqual(TerminalCellLayout.columns(viewportWidth: 800, cellWidth: 10), 78)
        XCTAssertEqual(TerminalCellLayout.rows(viewportHeight: 600, cellHeight: 20), 29)
        XCTAssertEqual(TerminalCellLayout.columns(viewportWidth: 26.9, cellWidth: 10), 2)
        XCTAssertEqual(TerminalCellLayout.columns(viewportWidth: 36, cellWidth: 10), 2)
        XCTAssertEqual(TerminalCellLayout.rows(viewportHeight: 35.9, cellHeight: 20), 1)
        XCTAssertEqual(TerminalCellLayout.rows(viewportHeight: 36, cellHeight: 20), 1)
        XCTAssertEqual(TerminalCellLayout.columns(viewportWidth: 46, cellWidth: 10), 3)
        XCTAssertEqual(TerminalCellLayout.rows(viewportHeight: 56, cellHeight: 20), 2)
        XCTAssertEqual(TerminalCellLayout.columns(viewportWidth: 1, cellWidth: 100), 2)
        XCTAssertEqual(TerminalCellLayout.rows(viewportHeight: 1, cellHeight: 100), 1)
    }

    func testHitTestingFloorsFromInsetOrigin() {
        XCTAssertEqual(TerminalCellLayout.column(x: 8, cellWidth: 10), 0)
        XCTAssertEqual(TerminalCellLayout.row(y: 8, cellHeight: 20), 0)
        XCTAssertEqual(TerminalCellLayout.column(x: 17.9, cellWidth: 10), 0)
        XCTAssertEqual(TerminalCellLayout.column(x: 18, cellWidth: 10), 1)
        XCTAssertEqual(TerminalCellLayout.row(y: 27.9, cellHeight: 20), 0)
        XCTAssertEqual(TerminalCellLayout.row(y: 28, cellHeight: 20), 1)
        XCTAssertEqual(TerminalCellLayout.column(x: 7.9, cellWidth: 10), -1)
        XCTAssertEqual(TerminalCellLayout.row(y: -12, cellHeight: 20), -1)
    }

    func testMemoReusesValueForSameSizeAndPreparesOnce() {
        let memo = TerminalTypefaceMemo<String>()
        var prepares = 0
        var creates = 0
        let first = memo.value(for: 13, prepare: { prepares += 1 }, create: { creates += 1; return "a" })
        let second = memo.value(for: 13, prepare: { prepares += 1 }, create: { creates += 1; return "b" })
        XCTAssertEqual(first, "a")
        XCTAssertEqual(second, "a")
        XCTAssertEqual(prepares, 1)
        XCTAssertEqual(creates, 1)
    }

    func testMemoCreatesPerSizeAndStandalonePrepareWins() {
        let memo = TerminalTypefaceMemo<Int>()
        var prepares = 0
        memo.prepare { prepares += 1 }
        memo.prepare { prepares += 1 }
        XCTAssertEqual(memo.value(for: 13, prepare: { prepares += 1 }, create: { 1 }), 1)
        XCTAssertEqual(memo.value(for: 14, prepare: { prepares += 1 }, create: { 2 }), 2)
        XCTAssertEqual(memo.value(for: 13, prepare: { prepares += 1 }, create: { 99 }), 1)
        XCTAssertEqual(prepares, 1)
    }

    func testMemoConcurrentSameSizeCreatesOnce() {
        let memo = TerminalTypefaceMemo<Int>()
        let group = DispatchGroup()
        let tally = NSLock()
        var creates = 0
        var prepares = 0
        for _ in 0..<64 {
            group.enter()
            DispatchQueue.global().async {
                _ = memo.value(
                    for: 13,
                    prepare: {
                        tally.lock()
                        prepares += 1
                        tally.unlock()
                    },
                    create: {
                        tally.lock()
                        creates += 1
                        tally.unlock()
                        return 7
                    }
                )
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(prepares, 1)
        XCTAssertEqual(creates, 1)
    }
}
