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

    func testCommittedInputMapsNewlineAndEmptyBackspace() {
        XCTAssertEqual(terminalCommittedInput(""), "\u{007f}")
        XCTAssertEqual(terminalCommittedInput(terminalImeAnchor), "")
        XCTAssertEqual(terminalCommittedInput("\(terminalImeAnchor)echo\n"), "echo\r")
        XCTAssertEqual(terminalCommittedInput("\(terminalImeAnchor)ok"), "ok")
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

    func testCJKWideCells() {
        let term = AnsiTerminal(cols: 8, rows: 2)
        term.write("中")
        XCTAssertTrue(term.cell(0, 0).wide)
        XCTAssertTrue(term.cell(0, 1).spacer)
        XCTAssertEqual(term.cursorX, 2)
        XCTAssertEqual(terminalCharWidth("中"), 2)
        XCTAssertEqual(terminalCharWidth("A"), 1)
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
        XCTAssertEqual(fileTypeSymbol("folder"), "folder.fill")
        XCTAssertEqual(fileTypeSymbol("markdown"), "doc.richtext")
        XCTAssertEqual(fileTypeSymbol("warning"), "exclamationmark.triangle")
        XCTAssertEqual(fileTypeSymbol("other"), "doc")
        XCTAssertEqual(fileTypeSymbol("flutter"), "doc")
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
