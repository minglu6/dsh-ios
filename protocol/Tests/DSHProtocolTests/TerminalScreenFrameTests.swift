import XCTest
@testable import DSHProtocol

final class TerminalScreenFrameTests: XCTestCase {
    func testSnapshotUsesHostCoordinatesBeforeReplayingAnsi() {
        let terminal = AnsiTerminal(cols: 4, rows: 2)
        terminal.write("old")
        applyTerminalScreenFrame(frame("snapshot", cols: 12, rows: 4, screen: "abcdefghijkl\u{001b}[2;9HEND"), to: terminal)
        XCTAssertEqual(terminal.cols, 12)
        XCTAssertEqual(terminal.rows, 4)
        XCTAssertEqual(terminal.plainText(), "abcdefghijkl\n        END")
        XCTAssertEqual(terminal.cursorX, 11)
        XCTAssertEqual(terminal.cursorY, 1)
    }

    func testStateResizePrecedesOutputAtNewCoordinates() {
        let terminal = AnsiTerminal(cols: 12, rows: 4)
        applyTerminalScreenFrame(frame("snapshot", cols: 12, rows: 4, screen: "abcdefghijkl"), to: terminal)
        applyTerminalScreenFrame(frame("state", cols: 6, rows: 4), to: terminal)
        applyTerminalScreenFrame(jsonObject([
            "type": .string("output"), "data": .string("\u{001b}[3;1Hpwd\r\n/result")
        ]), to: terminal)
        XCTAssertEqual(terminal.plainText(), "ghijkl\npwd\n/resul\nt")
        XCTAssertEqual(terminal.cursorX, 1)
        XCTAssertEqual(terminal.cursorY, 3)
    }

    func testMetadataOnlyStateDoesNotResetScreen() {
        let terminal = AnsiTerminal(cols: 12, rows: 4)
        terminal.write("keep")
        let revision = terminal.revision
        applyTerminalScreenFrame(jsonObject([
            "type": .string("state"), "info": jsonObject(["state": .string("exited")])
        ]), to: terminal)
        XCTAssertEqual(terminal.plainText(), "keep")
        XCTAssertEqual(terminal.cursorX, 4)
        XCTAssertEqual(terminal.revision, revision)
    }

    func testCommittedInputPreservesTextAndNormalizesEachReturnOnce() {
        XCTAssertEqual(terminalInputText("printf x\r\nprintf y\nprintf z\r"), "printf x\rprintf y\rprintf z\r")
        XCTAssertEqual(terminalInputText(""), "")
        XCTAssertEqual(terminalInputText("\u{200B}pwd"), "\u{200B}pwd", "committed input has no synthetic sentinel to strip")
        XCTAssertEqual(terminalInputText("\u{007f}"), "\u{007f}")
    }

    private func frame(_ type: String, cols: Int, rows: Int, screen: String? = nil) -> JSONValue {
        jsonObject([
            "type": .string(type),
            "info": jsonObject(["cols": .number(Double(cols)), "rows": .number(Double(rows))]),
            "screen": screen.map(JSONValue.string),
        ])
    }
}
