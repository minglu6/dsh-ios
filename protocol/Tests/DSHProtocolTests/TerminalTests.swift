import XCTest
@testable import DSHProtocol

final class TerminalTests: XCTestCase {
    func testPlainWriteAndSnapshot() {
        let term = AnsiTerminal(cols: 40, rows: 8)
        term.write("original output")
        XCTAssertEqual(term.plainText(), "original output")
        XCTAssertEqual(term.cursorX, "original output".count)
        XCTAssertEqual(term.cursorY, 0)
    }

    func testTabIsRealTabStopNotSpaces() {
        let term = AnsiTerminal(cols: 40, rows: 4)
        term.write("ab\tcd")
        XCTAssertEqual(term.cursorX, 10)
        XCTAssertEqual(term.cell(0, 0).ch, "a")
        XCTAssertEqual(term.cell(0, 1).ch, "b")
        XCTAssertEqual(term.cell(0, 2).ch, " ")
        XCTAssertEqual(term.cell(0, 8).ch, "c")
    }

    func testCSIAndColors() {
        let term = AnsiTerminal(cols: 20, rows: 4)
        term.write("\u{001b}[31;1mhi\u{001b}[0m")
        XCTAssertEqual(term.cell(0, 0).ch, "h")
        XCTAssertEqual(term.cell(0, 0).fg, 1)
        XCTAssertTrue(term.cell(0, 0).bold)
        XCTAssertEqual(term.cell(0, 1).ch, "i")
        XCTAssertEqual(term.cell(0, 2).fg, -1)
        XCTAssertFalse(term.cell(0, 2).bold)
    }

    func testTapMovesCursorOnSameRowOnly() {
        let term = AnsiTerminal(cols: 40, rows: 8)
        term.write("original output")
        XCTAssertEqual(
            term.tapInput(row: 0, column: 0),
            String(repeating: "\u{001b}[D", count: "original output".count)
        )
        term.write("\r\ncurrent")
        XCTAssertNil(term.tapInput(row: 0, column: 0), "other rows must not send history navigation")
    }

    func testSgrMouseClick() {
        let term = AnsiTerminal(cols: 40, rows: 8)
        term.write("hello\u{001b}[?1000;1006h")
        XCTAssertEqual(term.tapInput(row: 0, column: 0), "\u{001b}[<0;1;1M\u{001b}[<0;1;1m")
    }

    func testWordSelectionFreezesCopiedText() {
        let term = AnsiTerminal(cols: 40, rows: 8)
        term.write("original output")
        let grid = term.snapshot()
        let range = grid.wordAt(grid.position(row: 0, col: 0))
        XCTAssertEqual(grid.selectedText(anchor: range.lowerBound, end: range.upperBound), "original")
        term.write(" changed")
        XCTAssertEqual(grid.selectedText(anchor: range.lowerBound, end: range.upperBound), "original")
        let full = grid.position(row: 0, col: 0)...grid.position(row: 0, col: 20)
        XCTAssertEqual(grid.selectedText(anchor: full.lowerBound, end: full.upperBound).trimmingCharacters(in: .whitespaces), "original output")
    }

    func testSelectTerminalNeverSubstitutesMissingIdentity() {
        let first = TerminalSessionEntry(sessionId: "owner", id: "first", state: "running")
        let selected = TerminalSessionEntry(sessionId: "owner", id: "selected", state: "exited")
        XCTAssertEqual(try selectTerminal(entries: [first, selected], savedId: "selected", explicitId: nil)?.id, "selected")
        XCTAssertEqual(try selectTerminal(entries: [first, selected], savedId: "selected", explicitId: "first")?.id, "first")
        XCTAssertEqual(try selectTerminal(entries: [selected], savedId: nil, explicitId: nil)?.id, "selected")
        XCTAssertNil(try selectTerminal(entries: [], savedId: nil, explicitId: nil))
        XCTAssertThrowsError(try selectTerminal(entries: [first], savedId: "gone", explicitId: nil))
        XCTAssertThrowsError(try selectTerminal(entries: [first], savedId: "first", explicitId: "gone"))
    }

    func testIdentityStoreDoesNotCrossOwners() {
        var owners: [SavedTerminalOwner] = []
        owners = TerminalIdentityStore.record(owners: owners, sessionId: "same", terminalId: "first", selected: true)
        owners = TerminalIdentityStore.record(owners: owners, sessionId: "same", terminalId: "selected", selected: true)
        XCTAssertEqual(owners.first { $0.sessionId == "same" }?.selectedId, "selected")
        XCTAssertEqual(Set(owners.first { $0.sessionId == "same" }?.ids ?? []), ["first", "selected"])
        owners = TerminalIdentityStore.reconcile(owners: owners, sessionId: "same", ids: ["first"])
        XCTAssertNil(owners.first { $0.sessionId == "same" }?.selectedId)
        owners = TerminalIdentityStore.reconcile(owners: owners, sessionId: "prior", ids: [])
        XCTAssertEqual(owners.map(\.sessionId), ["same"])
    }

    func testAlternateScreenAndResize() {
        let term = AnsiTerminal(cols: 10, rows: 3)
        term.write("keep")
        term.write("\u{001b}[?1049h")
        XCTAssertTrue(term.alternateScreen)
        term.write("alt")
        XCTAssertEqual(term.plainText().split(separator: "\n").first.map(String.init), "alt")
        term.write("\u{001b}[?1049l")
        XCTAssertFalse(term.alternateScreen)
        XCTAssertTrue(term.plainText().contains("keep"))
        term.resize(newCols: 12, newRows: 5)
        XCTAssertEqual(term.cols, 12)
        XCTAssertEqual(term.rows, 5)
        XCTAssertTrue(term.plainText().contains("keep"))
    }

    func testResizeReflowsSoftLinesWithoutJoiningHardLines() {
        let term = AnsiTerminal(cols: 10, rows: 6)
        term.write("abcdefghijklmnop\r\nNEXT")
        term.resize(newCols: 6, newRows: 6)
        XCTAssertEqual(term.plainText(), "abcdef\nghijkl\nmnop\nNEXT")
        XCTAssertEqual(term.snapshot().wrapped, [6, 6, 0, 0, 0, 0])
        XCTAssertEqual(term.cursorX, 4)
        XCTAssertEqual(term.cursorY, 3)
        XCTAssertEqual(term.snapshot().selectedText(anchor: 0, end: 23), "abcdefghijklmnop\nNEXT")
        term.resize(newCols: 10, newRows: 6)
        XCTAssertEqual(term.plainText(), "abcdefghij\nklmnop\nNEXT")
        XCTAssertEqual(term.cursorX, 4)
        XCTAssertEqual(term.cursorY, 2)
    }

    func testResizeMapsCursorWithinLongLineAndSavedCursor() {
        let term = AnsiTerminal(cols: 12, rows: 4)
        term.write("abcdefghijkl\u{001b}[1;8H\u{001b}7")
        term.resize(newCols: 5, newRows: 4)
        XCTAssertEqual(term.plainText(), "abcde\nfghij\nkl")
        XCTAssertEqual(term.cursorX, 2)
        XCTAssertEqual(term.cursorY, 1)
        term.write("\u{001b}[1;1H\u{001b}8Z")
        XCTAssertEqual(term.plainText(), "abcde\nfgZij\nkl")
        term.resize(newCols: 12, newRows: 4)
        XCTAssertEqual(term.plainText(), "abcdefgZijkl")
        XCTAssertEqual(term.cursorX, 8)
        XCTAssertEqual(term.cursorY, 0)
    }

    func testResizePreservesPendingWrapAtRightMargin() {
        let term = AnsiTerminal(cols: 8, rows: 4)
        term.write("abcdefgh")
        term.resize(newCols: 4, newRows: 4)
        XCTAssertEqual(term.cursorX, 4)
        XCTAssertEqual(term.cursorY, 1)
        term.resize(newCols: 8, newRows: 4)
        XCTAssertEqual(term.cursorX, 8)
        XCTAssertEqual(term.cursorY, 0)
        term.write("I")
        XCTAssertEqual(term.plainText(), "abcdefgh\nI")
        XCTAssertEqual(term.snapshot().wrapped[0], 8)
    }

    func testResizeRetainsBottomContentAndRestoresDisplacedRows() {
        let term = AnsiTerminal(cols: 8, rows: 4)
        term.write("one\r\ntwo\r\nthree\r\nfour")
        term.resize(newCols: 8, newRows: 2)
        XCTAssertEqual(term.plainText(), "three\nfour")
        XCTAssertEqual(term.cursorX, 4)
        XCTAssertEqual(term.cursorY, 1)
        term.resize(newCols: 8, newRows: 4)
        XCTAssertEqual(term.plainText(), "one\ntwo\nthree\nfour")
        XCTAssertEqual(term.cursorY, 3)
    }

    func testResizeRetainsRowsBelowCursorWithoutHidingCursor() {
        let term = AnsiTerminal(cols: 8, rows: 4)
        term.write("one\r\ntwo\r\nthree\r\nfour\u{001b}[1;2H")
        term.resize(newCols: 8, newRows: 2)
        XCTAssertEqual(term.plainText(), "one\ntwo")
        XCTAssertEqual(term.cursorX, 1)
        XCTAssertEqual(term.cursorY, 0)
        term.resize(newCols: 8, newRows: 4)
        XCTAssertEqual(term.plainText(), "one\ntwo\nthree\nfour")
        XCTAssertEqual(term.cursorX, 1)
        XCTAssertEqual(term.cursorY, 0)
    }

    func testNarrowViewportRetainsWrappedPrefixForWidening() {
        let term = AnsiTerminal(cols: 12, rows: 2)
        term.write("abcdefghijkl")
        term.resize(newCols: 3, newRows: 2)
        XCTAssertEqual(term.plainText(), "ghi\njkl")
        XCTAssertEqual(term.cursorX, 3)
        XCTAssertEqual(term.cursorY, 1)
        term.write("M")
        XCTAssertEqual(term.plainText(), "jkl\nM")
        term.resize(newCols: 12, newRows: 2)
        XCTAssertEqual(term.plainText(), "abcdefghijkl\nM")
        XCTAssertEqual(term.cursorX, 1)
        XCTAssertEqual(term.cursorY, 1)
    }

    func testResizeKeepsWideCharactersAndSoftWrapPaddingIntact() {
        let term = AnsiTerminal(cols: 6, rows: 5)
        term.write("\u{001b}[31mabc中界Z")
        term.resize(newCols: 4, newRows: 5)
        XCTAssertEqual(term.plainText(), "abc\n中界\nZ")
        XCTAssertEqual(term.snapshot().wrapped, [3, 4, 0, 0, 0])
        XCTAssertEqual(term.snapshot().selectedText(anchor: 0, end: 11), "abc中界Z")
        XCTAssertEqual(term.cursorX, 1)
        XCTAssertEqual(term.cursorY, 2)
        for r in 0..<term.rows {
            for c in 0..<term.cols {
                if term.cell(r, c).wide {
                    XCTAssertLessThan(c + 1, term.cols)
                    XCTAssertTrue(term.cell(r, c + 1).spacer)
                    XCTAssertEqual(term.cell(r, c).fg, 1)
                }
                if term.cell(r, c).spacer {
                    XCTAssertGreaterThan(c, 0)
                    XCTAssertTrue(term.cell(r, c - 1).wide)
                }
            }
        }
        term.resize(newCols: 6, newRows: 5)
        XCTAssertEqual(term.plainText(), "abc中\n界Z")
        XCTAssertEqual(term.snapshot().wrapped[0], 5)
        XCTAssertEqual(term.cursorX, 3)
        XCTAssertEqual(term.cursorY, 1)
    }

    func testAlternateResizeCropsGridButReflowsInactivePrimary() {
        let term = AnsiTerminal(cols: 8, rows: 4)
        term.write("abcdefghij")
        term.write("\u{001b}[?1049h123中")
        term.resize(newCols: 4, newRows: 2)
        XCTAssertEqual(term.plainText(), "123")
        XCTAssertFalse(term.cell(0, 3).wide)
        XCTAssertEqual(term.cursorX, 3)
        term.write("\u{001b}[2J\u{001b}[?1049l")
        XCTAssertEqual(term.plainText(), "efgh\nij")
        XCTAssertEqual(term.cursorX, 2)
        XCTAssertEqual(term.cursorY, 1)
        term.resize(newCols: 8, newRows: 4)
        XCTAssertEqual(term.plainText(), "abcdefgh\nij")
        XCTAssertEqual(term.cursorX, 2)
        XCTAssertEqual(term.cursorY, 1)
    }

    func testSnapshotClearDiscardsResizeHistory() {
        let term = AnsiTerminal(cols: 12, rows: 2)
        term.write("abcdefghijkl")
        term.resize(newCols: 3, newRows: 2)
        term.applySnapshot("new")
        term.resize(newCols: 12, newRows: 4)
        XCTAssertEqual(term.plainText(), "new")
    }

    func testResizeRetainedHistoryIsBounded() {
        let term = AnsiTerminal(cols: 4, rows: 1_200)
        term.write(String(repeating: "old\r\n", count: 1_199) + "END")
        term.resize(newCols: 4, newRows: 1)
        XCTAssertEqual(term.plainText(), "END")
        XCTAssertEqual(term.cursorY, 0)
        term.resize(newCols: 4, newRows: 1_200)
        let restored = term.plainText().split(separator: "\n")
        XCTAssertEqual(restored.count, 1_001)
        XCTAssertEqual(restored.last, "END")
        XCTAssertEqual(term.cursorY, 1_000)
    }

    func testResizeWideMarginAtMinimumWidth() {
        let term = AnsiTerminal(cols: 4, rows: 4)
        term.write("中界")
        term.resize(newCols: 1, newRows: 4)
        XCTAssertEqual(term.cols, 2)
        XCTAssertEqual(term.plainText(), "中\n界")
        XCTAssertEqual(term.cursorX, 2)
        XCTAssertEqual(term.cursorY, 1)
        term.resize(newCols: 4, newRows: 4)
        XCTAssertEqual(term.plainText(), "中界")
        XCTAssertEqual(term.cursorX, 4)
        XCTAssertEqual(term.cursorY, 0)
    }

    func testCJKWideCells() {
        let term = AnsiTerminal(cols: 8, rows: 2)
        term.write("中")
        XCTAssertTrue(term.cell(0, 0).wide)
        XCTAssertTrue(term.cell(0, 1).spacer)
        XCTAssertEqual(term.cursorX, 2)
        XCTAssertEqual(terminalCharWidth("中"), 2)
        XCTAssertEqual(terminalCharWidth("A"), 1)
    }

    func testBlankSnapshotRefusesSelection() {
        let empty = AnsiTerminal(cols: 40, rows: 8)
        XCTAssertTrue(terminalGridIsBlank(empty.snapshot()))
        empty.write("original output")
        XCTAssertFalse(terminalGridIsBlank(empty.snapshot()))
    }

    func testAttachOnOnlineMatchesAndroidEffect() {
        XCTAssertTrue(terminalShouldAttachOnOnline(isOnline: true, exited: false))
        XCTAssertFalse(terminalShouldAttachOnOnline(isOnline: false, exited: false))
        XCTAssertFalse(terminalShouldAttachOnOnline(isOnline: true, exited: true))
        XCTAssertFalse(terminalShouldAttachOnOnline(isOnline: false, exited: true))
    }

    func testDesktopTerminalCopyAndKeycaps() {
        XCTAssertEqual(terminalDisconnectedCopy(english: false), "连接已断开。")
        XCTAssertEqual(terminalDisconnectedCopy(english: true), "Disconnected.")
        XCTAssertEqual(terminalConnectingCopy(english: false), "正在连接…")
        XCTAssertEqual(terminalFailureCopy(message: "follow is not a function", english: false), "终端错误：follow is not a function")
        XCTAssertEqual(terminalFailureCopy(message: "boom", english: true), "Terminal error: boom")
        XCTAssertEqual(terminalMissingCopy(english: false), "此终端已不存在，请新建终端。")
        XCTAssertEqual(terminalMissingCopy(english: true), "This terminal no longer exists. Open a new terminal.")
        XCTAssertEqual(terminalRetryLabel(hasScreenInfo: true, disconnected: false, english: false), "重新连接")
        XCTAssertEqual(terminalRetryLabel(hasScreenInfo: false, disconnected: true, english: false), "重新连接")
        XCTAssertEqual(terminalRetryLabel(hasScreenInfo: false, disconnected: false, english: false), "重试")
        XCTAssertEqual(terminalKeyPasteLabel(platform: "darwin"), "Cmd+V")
        XCTAssertEqual(terminalKeyPasteLabel(platform: "linux"), "Ctrl+V")
        XCTAssertEqual(terminalKeyCopyLabel(platform: "darwin"), "Cmd+C")
        XCTAssertEqual(terminalKeyCopyLabel(platform: nil), "Copy")
        XCTAssertEqual(terminalMissingArtSizePoints, 36)
        XCTAssertEqual(terminalMissingArtViewBox, 28)
        XCTAssertEqual(terminalMissingArtFillHex, 0xFF17191D)
        XCTAssertEqual(terminalStatusPaddingXPoints, 12)
        XCTAssertEqual(terminalStatusPaddingYPoints, 5)
        XCTAssertEqual(terminalStatusGapPoints, 8)
        XCTAssertEqual(terminalErrorPaddingYPoints, 10)
        XCTAssertEqual(terminalEmptyGapPoints, 16)
        XCTAssertEqual(terminalEmptyPaddingPoints, 24)
        XCTAssertEqual(terminalKeyGlyphSizePoints, 20)
        XCTAssertEqual(terminalMissingIdentityCode, "terminal/unavailable")
        XCTAssertFalse(terminalCloseAsksConfirmation)
        XCTAssertFalse(terminalSwitcherUsesSystemMenu)
        XCTAssertFalse(terminalTitleFollowsOscCwdOrProcess)
        XCTAssertEqual(terminalSwitcherStrokeWidthPoints, mentionMenuStrokeWidthPoints)
        XCTAssertEqual(terminalSwitcherStrokeWidthPoints, 0.5)
        XCTAssertEqual(terminalSwitcherStrokeHex(dark: false), inputTriggerMenuStrokeHex(dark: false))
        XCTAssertEqual(terminalSwitcherStrokeHex(dark: true), inputTriggerMenuStrokeHex(dark: true))
        XCTAssertEqual(terminalSwitcherStrokeHex(dark: false), 0x0A000000)
        XCTAssertEqual(terminalSwitcherStrokeHex(dark: true), 0x0FFFFFFF)
        XCTAssertEqual(terminalSwitcherShadowRadiusPoints, mentionMenuShadowRadiusPoints)
        XCTAssertEqual(terminalSwitcherShadowYPoints, mentionMenuShadowYPoints)
        XCTAssertEqual(terminalSwitcherShadowOpacity, mentionMenuShadowOpacity)
        XCTAssertEqual(terminalSwitcherMenuPaddingPoints, 4)
        XCTAssertEqual(terminalSwitcherMenuMinWidthPoints, 144)
        XCTAssertEqual(terminalSwitcherMenuMaxWidthPoints, 360)
        XCTAssertEqual(terminalSwitcherMenuRadiusPoints, 12)
        XCTAssertEqual(terminalSwitcherRowMinHeightPoints, 34)
        XCTAssertEqual(terminalSwitcherRowPaddingYPoints, 6)
        XCTAssertEqual(terminalSwitcherRowPaddingXPoints, 8)
        XCTAssertEqual(terminalSwitcherRowGapPoints, 6)
        XCTAssertEqual(terminalSwitcherRowFontSizePoints, 13)
        XCTAssertEqual(terminalSwitcherRowLineHeightPoints, 20)
        XCTAssertEqual(terminalSwitcherRowRadiusPoints, 12)
        XCTAssertEqual(terminalSwitcherSectionFontSizePoints, 11)
        XCTAssertEqual(terminalSwitcherSectionLineHeightPoints, 15)
        XCTAssertEqual(terminalSwitcherIconSizePoints, 14)
        XCTAssertEqual(terminalTabIconSizePoints, 16)
        XCTAssertEqual(terminalTabIconPromptPath, "M3 4L7 8L3 12")
        XCTAssertEqual(terminalTabIconCursorPath, "M9 12H13")
        XCTAssertEqual(terminalTabIconSymbol(), "official.terminalTab")
        XCTAssertTrue(isForbiddenTerminalSwitcherSystemSymbol("terminal"))
        XCTAssertTrue(isForbiddenTerminalSwitcherSystemSymbol("checkmark"))
        XCTAssertTrue(isForbiddenTerminalSwitcherSystemSymbol("plus"))
        XCTAssertTrue(isForbiddenTerminalSwitcherSystemSymbol("xmark"))
        XCTAssertFalse(isForbiddenTerminalSwitcherSystemSymbol("official.terminalTab"))
    }

    func testSwitcherLabelsMatchDesktopTabTitleWithoutInventedIndex() throws {
        let zshA = TerminalSessionEntry(sessionId: "s", id: "t1", title: "zsh", state: "running", cwd: "/Users/dev/dsh-ios")
        let zshB = TerminalSessionEntry(sessionId: "s", id: "t2", title: "zsh", state: "running", cwd: "/tmp")
        let bash = TerminalSessionEntry(sessionId: "s", id: "t3", title: "bash", shellName: "zsh")
        let unnamed = TerminalSessionEntry(sessionId: "s", id: "t4", title: "  ", shellName: "fish")
        let fallback = TerminalSessionEntry(sessionId: "s", id: "t5")
        XCTAssertEqual(terminalSwitcherTitle(zshA), "zsh")
        XCTAssertEqual(terminalSwitcherTitle(unnamed), "fish")
        XCTAssertEqual(terminalSwitcherTitle(fallback), "Terminal")
        XCTAssertEqual(terminalSwitcherTitle(title: nil, shellName: "zsh"), "zsh")
        XCTAssertEqual(
            terminalSwitcherLabels([zshA, zshB, bash]),
            ["zsh", "zsh", "bash"],
            "desktop TerminalTitle keeps shell.name; dockkit does not number duplicates"
        )
        XCTAssertTrue(terminalSwitcherIsCurrent(entry: zshA, currentSessionId: "s", currentId: "t1"))
        XCTAssertFalse(terminalSwitcherIsCurrent(entry: zshB, currentSessionId: "s", currentId: "t1"))
        let row = try TerminalSessionEntry.parse(
            sessionId: "s",
            value: .object([
                "id": .string("host-1"),
                "title": .string("zsh"),
                "state": .string("running"),
                "cwd": .string("/Users/dev/dsh-ios"),
                "shell": .object([
                    "path": .string("/bin/zsh"),
                    "args": .array([]),
                    "name": .string("zsh"),
                ]),
            ])
        )
        XCTAssertEqual(row.shellName, "zsh")
        XCTAssertEqual(row.cwd, "/Users/dev/dsh-ios")
        XCTAssertEqual(terminalSwitcherTitle(row), "zsh")
        XCTAssertEqual(terminalSwitcherRowIdentifier(id: "t1"), "terminalSwitcher.row.t1")
        XCTAssertEqual(terminalSwitcherMenuIdentifier(), "terminalSwitcherMenu")
        XCTAssertEqual(terminalSwitcherButtonIdentifier(), "terminalSwitcherButton")
    }

    func testSwitcherTitleStaysShellNameUntilHostRename() {
        XCTAssertFalse(
            terminalTitleFollowsOscCwdOrProcess,
            "desktop never writes info.title from OSC 0/2, cwd, or process"
        )
        let first = TerminalSessionEntry(
            sessionId: "s", id: "a", title: "zsh", state: "running",
            cwd: "/Users/dev/one", shellName: "zsh"
        )
        let second = TerminalSessionEntry(
            sessionId: "s", id: "b", title: "zsh", state: "running",
            cwd: "/tmp", shellName: "zsh"
        )
        XCTAssertEqual(
            terminalSwitcherLabels([first, second]),
            ["zsh", "zsh"],
            "two default zsh sessions stay identical; only the Menu check distinguishes"
        )
        XCTAssertTrue(terminalSwitcherIsCurrent(entry: first, currentSessionId: "s", currentId: "a"))
        XCTAssertFalse(terminalSwitcherIsCurrent(entry: second, currentSessionId: "s", currentId: "a"))
        let renamed = TerminalSessionEntry(
            sessionId: "s", id: "b", title: "build", state: "running",
            cwd: "/tmp", shellName: "zsh"
        )
        XCTAssertEqual(
            terminalSwitcherLabels([first, renamed]),
            ["zsh", "build"],
            "Host rename() is the only post-create title mutation; paint info.title when it arrives"
        )
    }

    func testCloseFollowDropsMetaWhileDisconnectKeepsIt() {
        XCTAssertTrue(terminalResetKeepsMeta(keepMeta: true))
        XCTAssertFalse(terminalResetKeepsMeta(keepMeta: false))
        XCTAssertTrue(
            terminalPanelIsRunning(
                isOnline: true, opening: false, terminating: false, exited: false, state: "running"
            )
        )
        XCTAssertFalse(
            terminalPanelIsRunning(
                isOnline: true, opening: false, terminating: false, exited: true, state: "running"
            ),
            "explicit close must not stay running after closeTerminalFollow"
        )
        XCTAssertFalse(
            terminalPanelIsRunning(
                isOnline: true, opening: false, terminating: false, exited: false, state: nil
            )
        )
    }
}

final class WorkspaceTests: XCTestCase {
    func testBranchesDoNotMergeSameBasename() {
        let tree = workspaceBranches(["/a/project", "/b/project", "/a/project-other"])
        XCTAssertEqual(Set(tree.map(\.path)), ["/a/project", "/a/project-other", "/b/project"])
        XCTAssertTrue(tree.allSatisfy { $0.children.isEmpty })
        let nested = workspaceBranches(["/a", "/a/project"])
        XCTAssertEqual(nested.map(\.path), ["/a"])
        XCTAssertEqual(nested.first?.children.map(\.path), ["/a/project"])
    }

    func testDisplayTitleLocalizesDefaultWorkspace() {
        XCTAssertEqual(
            workspaceDisplayTitle(title: nil, path: #"C:\Users\x\default-workspace"#, localizedDefault: "默认工作区"),
            "默认工作区"
        )
        XCTAssertEqual(
            workspaceDisplayTitle(title: "我的工程", path: #"D:\projects\default-workspace"#, localizedDefault: "默认工作区"),
            "我的工程"
        )
        XCTAssertEqual(
            workspaceDisplayTitle(title: nil, path: #"\\server\share\project"#, localizedDefault: "默认工作区"),
            "project"
        )
    }

    func testFilesParentAndRelativeGuard() {
        XCTAssertNil(workspaceFilesParentPath(""))
        XCTAssertEqual(workspaceFilesParentPath("src/app"), "src")
        XCTAssertEqual(workspaceFilesParentPath("src"), "")
        XCTAssertTrue(workspaceFileListIsRelative("src/app"))
        XCTAssertFalse(workspaceFileListIsRelative("/etc"))
        XCTAssertFalse(workspaceFileListIsRelative("foo/../bar"))
        XCTAssertFalse(workspaceFileListIsRelative(#"C:\windows"#))
    }

    func testPreviewKinds() {
        XCTAssertEqual(previewKindFor("notes.md"), .text)
        XCTAssertEqual(previewKindFor("photo.PNG"), .image)
        XCTAssertEqual(previewKindFor("report.PDF"), .pdf)
        XCTAssertEqual(previewKindFor("report.DOCX"), .office)
        XCTAssertEqual(previewKindFor("archive.zip"), .unsupported)
        XCTAssertEqual(classifyFileType("/project/package.json"), "node")
        XCTAssertEqual(classifyFileType("Dockerfile.dev"), "docker")
        XCTAssertEqual(classifyFileType("README"), "markdown")
        XCTAssertEqual(classifyFileType(#"C:\project\Main.kt"#), "kotlin")
        XCTAssertEqual(classifyFileType("app.component.ts"), "angular")
        XCTAssertEqual(classifyFileType("notes.mdx"), "markdown")
        XCTAssertEqual(fileTypeAccent("pdf"), 0xEC1313)
        XCTAssertEqual(fileTypeAccent("folder"), 0xF7AD31)
        XCTAssertEqual(fileTypeAccent("python"), 0x3776AB)
        XCTAssertEqual(fileTypeKind(path: "notes.md", type: "directory"), "folder")
        XCTAssertEqual(fileTypeKind(path: "notes.md", type: "file"), "markdown")
        XCTAssertEqual(fileTypeKind(path: "docker.sock", type: "other"), "warning")
        XCTAssertEqual(fileTypeKind(path: "pipe", type: "fifo"), "warning")
        XCTAssertEqual(fileTypeSymbol("folder"), "official.folderOpen")
        XCTAssertEqual(fileTypeSymbol("markdown"), "official.fileMarkdown")
        XCTAssertEqual(fileTypeSymbol("image"), "official.fileImage")
        XCTAssertEqual(fileTypeSymbol("pdf"), "official.filePdf")
        XCTAssertEqual(fileTypeSymbol("excel"), "official.fileExcel")
        XCTAssertEqual(fileTypeSymbol("warning"), "official.warningOutline")
        XCTAssertEqual(fileTypeSymbol("other"), "official.fileOther")
        XCTAssertEqual(fileTypeSymbol("html"), "official.fileHtml")
        XCTAssertEqual(fileTypeSymbol("code"), "official.fileCode")
        XCTAssertEqual(fileTypeSymbol("python"), "official.codeFile.python")
        XCTAssertEqual(fileTypeSymbol("xml"), "official.codeFile.xml")
        XCTAssertEqual(fileTypeSymbol("flutter"), "official.codeFile.flutter")
        XCTAssertEqual(fileTypeSymbol("objective-c"), "official.codeFile.objective-c")
        XCTAssertEqual(fileTypeCodeFileAssetName("python"), "codeFile_python")
        XCTAssertEqual(fileTypeCodeFileAssetName("objective-c"), "codeFile_objective_c")
        XCTAssertTrue(fileTypeHasCodeFileArtwork("python"))
        XCTAssertTrue(fileTypeHasCodeFileArtwork("yaml"))
        XCTAssertFalse(fileTypeHasCodeFileArtwork("markdown"))
        XCTAssertTrue(fileTypeHasTraditionalGlyph("markdown"))
        XCTAssertTrue(fileTypeHasTraditionalGlyph("other"))
        XCTAssertFalse(fileTypeHasTraditionalGlyph("python"))
        XCTAssertEqual(fileTypeSymbol("unknown-kind"), "official.fileOther")
        XCTAssertTrue(isForbiddenTraditionalFileTypeSystemSymbol("doc.richtext"))
        XCTAssertTrue(isForbiddenTraditionalFileTypeSystemSymbol("exclamationmark.triangle"))
        XCTAssertFalse(isForbiddenTraditionalFileTypeSystemSymbol("official.fileMarkdown"))
        XCTAssertTrue(isForbiddenCodeFileSystemSymbol("doc.fill"))
        XCTAssertTrue(isForbiddenCodeFileSystemSymbol("doc"))
        XCTAssertTrue(fileGlyphBodyPath.hasPrefix("M8.48924 28H19.5108"))
        XCTAssertTrue(fileGlyphFoldPath.hasPrefix("M26.3909 7.37445"))
        XCTAssertEqual(fileGlyphMutedFoldHex, 0xFFA2A4A6)
        XCTAssertEqual(fileTreeFileIconSizePoints, 16)
        XCTAssertEqual(filesAutoRefreshSymbol(enabled: true), "official.pauseOutline")
        XCTAssertEqual(filesAutoRefreshSymbol(enabled: false), "official.playOutline")
        XCTAssertEqual(filesReloadSymbol(), "official.refreshOutline")
        XCTAssertTrue(isForbiddenFilesToolbarSystemSymbol("pause"))
        XCTAssertTrue(isForbiddenFilesToolbarSystemSymbol("play.fill"))
        XCTAssertTrue(isForbiddenFilesToolbarSystemSymbol("arrow.clockwise"))
        XCTAssertEqual(documentPreviewWrapSymbol(wrapped: false), "official.wrapFill")
        XCTAssertEqual(documentPreviewWrapSymbol(wrapped: true), "official.nowrapFill")
        XCTAssertEqual(documentPreviewCopySymbol(copied: false), "official.copyOutline")
        XCTAssertEqual(documentPreviewCopySymbol(copied: true), "official.checkOutline")
        XCTAssertEqual(documentPreviewCloseSymbol(), "official.closeOutline")
        XCTAssertEqual(documentPreviewWrapIconSizePoints, 16)
        XCTAssertTrue(isForbiddenDocumentPreviewSystemSymbol("text.alignleft"))
        XCTAssertTrue(isForbiddenDocumentPreviewSystemSymbol("text.justify.leading"))
        XCTAssertTrue(isForbiddenDocumentPreviewSystemSymbol("square.on.square"))
        XCTAssertTrue(isForbiddenDocumentPreviewSystemSymbol("xmark"))
        XCTAssertTrue(iconWrapCurvePath.hasPrefix("M10.9999 8C"))
        XCTAssertEqual(iconWrapRailLeftPath, "M2 15H1V1H2V15Z")
        XCTAssertTrue(iconNowrapArrowPath.hasPrefix("M12.3535 7.64645"))
        XCTAssertTrue(iconPlayOutlineTrianglePath.hasPrefix("M10.3329 7.91346"))
        XCTAssertEqual(iconPauseOutlineLeftPath, "M6.5 5V11")
        XCTAssertEqual(fileTypeAccent("warning"), 0xCFD3D6)
        XCTAssertEqual(fileTypeAccent("flutter"), 0xCFD3D6)
        XCTAssertEqual(fileTypeAccent("unknown-kind"), fileTypeAccent("other"))
        XCTAssertEqual(Tango.ansi[1], TermRGB.rgb(0xCC0000))
        XCTAssertEqual(Tango.ansi[2], TermRGB.rgb(0x4E9A06))
        XCTAssertEqual(Tango.ansi[3], TermRGB.rgb(0xC4A000))
        XCTAssertEqual(Tango.ansi[4], TermRGB.rgb(0x3465A4))
        XCTAssertEqual(Tango.ansi[5], TermRGB.rgb(0x75507B))
        XCTAssertEqual(Tango.ansi[6], TermRGB.rgb(0x06989A))
        XCTAssertEqual(Tango.ansi[9], TermRGB.rgb(0xEF2929))
        XCTAssertEqual(Tango.ansi[10], TermRGB.rgb(0x8AE234))
        XCTAssertEqual(Tango.ansi[11], TermRGB.rgb(0xFCE94F))
        XCTAssertEqual(Tango.ansi[12], TermRGB.rgb(0x729FCF))
        XCTAssertEqual(Tango.ansi[13], TermRGB.rgb(0xAD7FA8))
        XCTAssertEqual(Tango.ansi[14], TermRGB.rgb(0x34E2E2))
        XCTAssertEqual(xterm256(1), Tango.ansi[1])
        for path in ["README.md", "main.py", "app.go", "Cargo.toml", "Makefile", ".gitignore", "photo.svg"] {
            let kind = classifyFileType(path)
            _ = fileTypeAccent(kind)
            _ = fileTypeSymbol(kind)
        }
        let codeKinds = [
            "angular", "c", "clojure", "cmake", "cpp", "csharp", "css", "dart",
            "docker", "elixir", "env", "erlang", "flutter", "git", "go", "graphql",
            "haskell", "ini", "java", "javascript", "json", "kotlin", "lua",
            "makefile", "node", "objective-c", "perl", "php", "powershell",
            "protobuf", "python", "r", "react", "ruby", "rust", "scala", "shell",
            "solidity", "sql", "svelte", "swift", "toml", "typescript", "vue",
            "wasm", "xml", "yaml", "zig",
        ]
        XCTAssertEqual(codeKinds.count, 48)
        for kind in codeKinds {
            XCTAssertTrue(fileTypeHasCodeFileArtwork(kind), kind)
            XCTAssertEqual(fileTypeSymbol(kind), "official.codeFile.\(kind)", kind)
            XCTAssertFalse(fileTypeHasTraditionalGlyph(kind), kind)
            XCTAssertTrue(fileTypeCodeFileAssetName(kind).hasPrefix("codeFile_"), kind)
        }
    }

    func testDelimitedPreview() throws {
        XCTAssertEqual(
            try parseDelimitedPreview("name,description,\r\n\"A,B\",\"first\nsecond \"\"quoted\"\"\",\r\n", delimiter: ","),
            [["name", "description", ""], ["A,B", "first\nsecond \"quoted\"", ""]]
        )
        XCTAssertEqual(try parseDelimitedPreview("a\tb", delimiter: "\t"), [["a", "b"]])
        XCTAssertEqual(try parseDelimitedPreview("\"\"", delimiter: ","), [[""]])
        XCTAssertEqual(try parseDelimitedPreview("", delimiter: ","), [])
        XCTAssertThrowsError(try parseDelimitedPreview("a,\"unfinished", delimiter: ","))
        XCTAssertThrowsError(try parseDelimitedPreview(String(repeating: "x,", count: 128), delimiter: ","))
    }

    func testDirectoryStateNavigation() async throws {
        let root = WorkspaceDirectoryEntry(name: "/", path: "/", hidden: false)
        let home = WorkspaceDirectoryEntry(name: "home", path: "/home", hidden: false)
        let alpha = WorkspaceDirectoryEntry(name: "alpha", path: "/home/alpha", hidden: false)
        let beta = WorkspaceDirectoryEntry(name: "beta", path: "/home/beta", hidden: false)
        let hidden = WorkspaceDirectoryEntry(name: ".secret", path: "/home/.secret", hidden: true)
        func level(_ entry: WorkspaceDirectoryEntry, _ entries: [WorkspaceDirectoryEntry] = []) -> WorkspaceDirectoryLevel {
            WorkspaceDirectoryLevel(
                path: entry.path,
                home: home.path,
                crumbs: entry.path == home.path ? [root, home] : [root, home, entry],
                entries: entries,
                truncated: false
            )
        }
        let homeLevel = level(home, [alpha, beta, hidden])
        let listings: [String: WorkspaceDirectoryLevel] = [
            home.path: homeLevel,
            alpha.path: level(alpha),
            beta.path: level(beta),
        ]
        let state = WorkspaceDirectoryState { listings[$0 ?? home.path]! }
        await state.navigate()
        await waitUntil { !state.loading }
        await state.navigate(path: alpha.path, base: state.parent)
        await waitUntil { !state.loading }
        XCTAssertEqual(state.parent?.path, home.path)
        XCTAssertEqual(state.child?.path, alpha.path)
        XCTAssertEqual(state.target, alpha.path)
        await state.navigate(path: home.path)
        await waitUntil { !state.loading }
        XCTAssertNil(state.selected)
        XCTAssertNil(state.child)
        XCTAssertEqual(state.target, home.path)
        state.beginEdit()
        state.edit("/home/.s")
        XCTAssertEqual(state.visibleEntries(homeLevel).map(\.path), [hidden.path])
        state.edit("/home/not-present")
        XCTAssertEqual(state.visibleEntries(homeLevel).map(\.name), ["alpha", "beta"])
        state.dispose()
    }
}

private func waitUntil(_ timeoutNs: UInt64 = 3_000_000_000, predicate: () -> Bool) async {
    let start = DispatchTime.now().uptimeNanoseconds
    while !predicate() {
        if DispatchTime.now().uptimeNanoseconds - start > timeoutNs {
            XCTFail("timed out waiting for directory state")
            return
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
