import XCTest
@testable import DSHProtocol

final class MentionPolicyTests: XCTestCase {
    func testDesktopMenuMetricsComeFromInputTriggerMenuView() {
        XCTAssertEqual(mentionMenuMaxHeightPoints, 400)
        XCTAssertEqual(inputTriggerMenuCardMaxHeight(availableHeight: 0), 400)
        XCTAssertEqual(inputTriggerMenuCardMaxHeight(availableHeight: 600), 400)
        XCTAssertEqual(inputTriggerMenuCardMaxHeight(availableHeight: 180), 180)
        XCTAssertEqual(inputTriggerMenuCardMaxHeight(availableHeight: 400), 400)
        XCTAssertEqual(mentionMenuPaddingPoints, 4)
        XCTAssertEqual(mentionMenuGapAboveComposerPoints, 4)
        XCTAssertEqual(mentionMenuSurfaceRadiusPoints, 12)
        XCTAssertEqual(mentionMenuRowRadiusPoints, 8)
        XCTAssertEqual(mentionMenuRowMinHeightPoints, 34)
        XCTAssertEqual(mentionMenuRowPaddingVerticalPoints, 6)
        XCTAssertEqual(mentionMenuRowPaddingHorizontalPoints, 8)
        XCTAssertEqual(mentionMenuRowGapPoints, 6)
        XCTAssertEqual(mentionMenuItemFontSizePoints, 13)
        XCTAssertEqual(mentionMenuItemLineHeightPoints, 20)
        XCTAssertEqual(mentionMenuItemNameMaxWidthFraction, 0.4)
        XCTAssertEqual(mentionMenuDescriptionFontSizePoints, 12)
        XCTAssertEqual(mentionMenuSectionTitleFontSizePoints, 11)
        XCTAssertEqual(mentionMenuSectionTitleLineHeightPoints, 16)
        XCTAssertEqual(mentionMenuSectionTitleFontWeight, 500)
        XCTAssertEqual(mentionMenuIconSizePoints, 14)
        XCTAssertEqual(mentionChipIconSizePoints, 16)
        XCTAssertEqual(mentionComposerChipIconSizePoints, 14)
        XCTAssertEqual(mentionComposerChipMaxWidthPoints, 240)
        XCTAssertEqual(mentionComposerChipGapPoints, 3)
        XCTAssertEqual(mentionComposerChipPaddingHorizontalPoints, 4)
        XCTAssertEqual(mentionComposerChipRadiusPoints, 6)
        XCTAssertEqual(mentionMenuIdentifier(), "mentionMenu")
        XCTAssertEqual(mentionChipIdentifier(.session), "mentionChip.session")
        XCTAssertEqual(userMessageBubbleIdentifier(), "userMessageBubble")
        XCTAssertEqual(mentionReferenceOfficialSymbol(.session), "official.queueOutline")
        XCTAssertEqual(mentionReferenceOfficialSymbol(.file), "official.browseOutline")
        XCTAssertEqual(mentionReferenceOfficialSymbol(.directory), "official.folderClose")
        XCTAssertEqual(inputTriggerMenuStrokeHex(dark: false), 0x0A000000)
        XCTAssertEqual(inputTriggerMenuStrokeHex(dark: true), 0x0FFFFFFF)
        XCTAssertEqual(mentionMenuCrumbStrokeHex(dark: false), inputTriggerMenuStrokeHex(dark: false))
        XCTAssertEqual(mentionMenuCrumbStrokeHex(dark: true), inputTriggerMenuStrokeHex(dark: true))
        XCTAssertEqual(mentionMenuStrokeWidthPoints, 0.5)
    }

    func testDesktopCopyAndGroupingOrder() {
        XCTAssertEqual(mentionSectionTitle(.files, english: false), "文件与文件夹")
        XCTAssertEqual(mentionSectionTitle(.files, english: true), "Files & folders")
        XCTAssertEqual(mentionSectionTitle(.sessions, english: false), "对话")
        XCTAssertEqual(mentionSectionTitle(.sessions, english: true), "Sessions")
        XCTAssertEqual(mentionSectionTitle(.subagents, english: false), "子智能体")
        XCTAssertEqual(mentionSectionTitle(.subagents, english: true), "Subagents")
        XCTAssertEqual(mentionCrumbRootLabel(english: false), "工作区")
        XCTAssertEqual(mentionDrillHint(english: true), "Browse folder")
        XCTAssertEqual(mentionDrillKey(), "Tab")
        XCTAssertEqual(mentionNoCwdLabel(english: false), "（无工作目录）")
    }

    func testFileAndSessionRowsMatchDesktopReferenceSource() {
        let file = FileReference(path: "src/Main.kt", kind: "file")
        let folder = FileReference(path: "design docs", kind: "directory")
        XCTAssertEqual(mentionFileRow(file, quoted: false, withLocation: true)?.title, "Main.kt")
        XCTAssertEqual(mentionFileRow(file, quoted: false, withLocation: true)?.description, "src")
        XCTAssertEqual(mentionFileRow(file, quoted: false, withLocation: false)?.description, nil)
        XCTAssertEqual(mentionFileRow(folder, quoted: false, withLocation: true)?.title, "design docs/")
        XCTAssertEqual(mentionFileRow(folder, quoted: false, withLocation: true)?.mention, "@\"design docs/\"")
        XCTAssertEqual(mentionFileRow(folder, quoted: false, withLocation: true)?.drill, "@\"design docs/")
        let forced = mentionFileRow(FileReference(path: "src", kind: "directory"), quoted: true, withLocation: true)
        XCTAssertEqual(forced?.mention, "@\"src/\"")
        XCTAssertEqual(forced?.drill, "@\"src/")
    }

    func testRowsAreFilesThenSubagentsThenSessionsAndQuotedDropsSessions() {
        let files = [FileReference(path: "README.md", kind: "file")]
        let sessions = [
            SessionReference.parse(.object([
                "mention": .string("@[Child](dsh-session:child)"),
                "title": .string("Child"),
                "sessionId": .string("child"),
                "kind": .string("subagent"),
            ]))!,
            SessionReference.parse(.object([
                "mention": .string("@[Design](dsh-session:other)"),
                "title": .string("Design"),
                "sessionId": .string("other"),
            ]))!,
        ]
        let listed = [
            SessionSummary(sessionId: "child", title: "Child", parentSessionId: "current", origin: "subagent"),
            SessionSummary(sessionId: "other", title: "Design", cwd: "/tmp/other"),
        ]
        let rows = mentionRows(
            files: files,
            sessions: sessions,
            listed: listed,
            currentSessionId: "current",
            query: "",
            quoted: false,
            drilled: false,
            now: 0,
            english: false
        )
        XCTAssertEqual(rows.map(\.section), [MentionSection.files, .subagents, .sessions])
        XCTAssertEqual(rows.map(\.title), ["README.md", "Child", "Design"])
        XCTAssertEqual(
            mentionRows(
                files: files,
                sessions: sessions,
                listed: listed,
                currentSessionId: "current",
                query: "src/",
                quoted: true,
                drilled: false,
                now: 0,
                english: false
            ).map(\.section),
            [MentionSection.files]
        )
    }

    func testDrilledBreadcrumbReturnsEveryAncestor() {
        let crumbs = mentionCrumbs(query: "design docs/nested/", quoted: true, drilled: true, english: false)
        XCTAssertEqual(crumbs.map(\.label), ["工作区", "design docs", "nested"])
        XCTAssertEqual(crumbs.map(\.drill), ["@\"", "@\"design docs/", "@\"design docs/nested/"])
        XCTAssertTrue(mentionCrumbs(query: "design docs/nested/", quoted: true, drilled: false, english: false).isEmpty)
    }

    func testTriggerRulesAndCanonicalSerialization() {
        XCTAssertEqual(composerTrigger("@", cursor: 1)?.query, "")
        XCTAssertEqual(composerTrigger("请检查 @", cursor: 5)?.query, "")
        XCTAssertEqual(composerTrigger("请检查 @Ma", cursor: 7)?.query, "Ma")
        XCTAssertNil(composerTrigger("user@host", cursor: 9))
        XCTAssertNil(composerTrigger("@[hello](dsh-session:InMxIg)", cursor: 28))
        let session = "@[昨日会话](dsh-session:abc123)"
        XCTAssertEqual(composerReferences(session).first?.kind, .session)
        XCTAssertEqual(composerReferences(session).first?.label, "昨日会话")
        XCTAssertEqual(mentionPromptText(session + " more"), session + " more")
        XCTAssertEqual(mentionPromptReferences(session + " @README.md").map(\.kind), [.session, .file])
        XCTAssertEqual(fileReferenceToken("src/app.swift", directory: false), "@src/app.swift")
        XCTAssertEqual(fileReferenceToken("my file.swift", directory: false), "@\"my file.swift\"")
        XCTAssertEqual(fileReferenceToken("docs", directory: true), "@docs/")
        XCTAssertEqual(
            composerReferences("@[你好](dsh-session:s-hello) @README.md").map(\.kind),
            [.session, .file]
        )
    }

    func testProjectionHidesCanonicalTokensAndKeepsLiveQueryEditable() {
        let session = "@[研发\\] 讨论](dsh-session:InMxIg)"
        let text = "请看 @\"目录 name/设计.kt\" @src/main/ \(session) 然后继续"
        let projection = mentionProjection(text, cursor: text.count)
        XCTAssertEqual(projection.original, text)
        XCTAssertEqual(projection.references.map(\.reference.label), ["设计.kt", "main/", "研发] 讨论"])
        XCTAssertEqual(projection.references.map(\.reference.kind), [.file, .directory, .session])
        XCTAssertFalse(projection.display.contains("dsh-session:"))
        XCTAssertFalse(projection.display.contains("目录 name/"))
        for live in ["@src/", "看 @\"目录 name/", "mail@example.com"] {
            let open = mentionProjection(live, cursor: live.count)
            XCTAssertEqual(open.display, live)
            XCTAssertTrue(open.references.isEmpty)
        }
        XCTAssertEqual(mentionProjection("@\"folder name/a.kt\"", cursor: 19).references.count, 1)
        XCTAssertEqual(mentionProjection("@[会话](dsh-session:InMxIg)", cursor: 24).references.count, 1)
    }

    func testBackspaceDeletesWholeChipAndKeepsWirePayload() {
        let session = "@[中文](dsh-session:InMxIg)"
        let text = "前 \(session) 后"
        let projection = mentionProjection(text, cursor: text.count)
        let ref = projection.references.single().reference
        let deleted = mentionKeyEdit(
            text: text,
            cursor: ref.end,
            selectionStart: ref.end,
            projection: projection,
            backspace: true,
            deleteForward: false,
            moveLeft: false,
            moveRight: false,
            shift: false
        )
        XCTAssertEqual(deleted?.text, "前  后")
        XCTAssertEqual(deleted?.cursor, ref.start)
        let left = mentionKeyEdit(
            text: text,
            cursor: ref.end,
            selectionStart: ref.end,
            projection: projection,
            backspace: false,
            deleteForward: false,
            moveLeft: true,
            moveRight: false,
            shift: false
        )
        XCTAssertEqual(left?.cursor, ref.start)
        XCTAssertEqual(mentionPromptText(text), text)
    }

    func testRemovingTrailingSpaceKeepsCommittedFileReference() {
        let original = "@src/a.kt "
        let first = mentionProjection(original, cursor: original.count)
        XCTAssertEqual(first.references.count, 1)
        let next = mentionProjection("@src/a.kt", cursor: 9, previous: first)
        XCTAssertEqual(next.references.count, 1)
        XCTAssertEqual(next.references[0].reference.canonical, "@src/a.kt")
    }

    func testHighlightWrapsLikeDesktopMenu() {
        XCTAssertEqual(mentionDefaultHighlight(rowCount: 3), 0)
        XCTAssertNil(mentionDefaultHighlight(rowCount: 0))
        XCTAssertEqual(mentionMoveHighlight(current: 0, direction: 1, rowCount: 3), 1)
        XCTAssertEqual(mentionMoveHighlight(current: 2, direction: 1, rowCount: 3), 0)
        XCTAssertEqual(mentionMoveHighlight(current: 0, direction: -1, rowCount: 3), 2)
    }
}

private extension Array {
    func single() -> Element {
        XCTAssertEqual(count, 1)
        return self[0]
    }
}
