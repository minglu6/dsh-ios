import XCTest
@testable import DSHProtocol

final class ComposerImeTests: XCTestCase {
    func testSystemMustApplyFirstPinyinLetterBeforeMarkedRangeExists() {
        XCTAssertTrue(
            ImeComposition.shouldLetSystemApplyReplacement(isMarked: false, replacement: "n", interceptReturn: false),
            "first Pinyin letter arrives with markedTextRange == nil; intercepting it commits Latin and hides the candidate bar"
        )
        XCTAssertTrue(
            ImeComposition.shouldLetSystemApplyReplacement(isMarked: true, replacement: "ihao", interceptReturn: true)
        )
        XCTAssertFalse(
            ImeComposition.shouldLetSystemApplyReplacement(isMarked: false, replacement: "\n", interceptReturn: true)
        )
        XCTAssertFalse(
            ImeComposition.shouldLetSystemApplyReplacement(isMarked: false, replacement: "", interceptReturn: false),
            "deletions stay interceptable for atomic mention chips"
        )
    }

    func testMarkedTextSurvivesWithoutRewritingCommittedDraft() {
        var session = ComposerImeSession()
        session.setMarkedText("nihao")
        XCTAssertTrue(session.isComposing)
        XCTAssertEqual(session.markedText, "nihao")
        XCTAssertEqual(session.committedText, "")
        XCTAssertEqual(session.visibleText, "nihao")
        XCTAssertFalse(ImeComposition.shouldRewriteText(isMarked: session.isComposing))
        XCTAssertThrowsError(try session.applyCommitted(text: "nihao", cursor: 5)) { error in
            XCTAssertEqual(error as? ComposerImeError, .rewriteWhileComposing)
        }
        XCTAssertEqual(session.committedText, "", "applyCommitted must not swallow marked letters into the draft")
    }

    func testMentionParsingIsSkippedWhileMarkedAndRunsAfterUnmark() {
        var session = ComposerImeSession(text: "@")
        XCTAssertEqual(session.mentionQuery, "")
        session.setMarkedText("nihao")
        XCTAssertNil(session.mentionQuery, "mention parsing must wait until composition ends")
        XCTAssertEqual(session.committedText, "@")
        XCTAssertEqual(session.visibleText, "@nihao")
        session.unmarkText()
        XCTAssertFalse(session.isComposing)
        XCTAssertEqual(session.committedText, "@nihao")
        XCTAssertEqual(session.cursor, 6)
        XCTAssertEqual(session.mentionQuery, "nihao")
        XCTAssertTrue(session.projection.references.isEmpty, "live @ query stays editable text, not a chip")
    }

    func testChipConversionRunsAfterMarkedTextCommits() {
        let token = "@[你好](dsh-session:s-hello)"
        var session = ComposerImeSession(text: token + " ")
        XCTAssertEqual(session.projection.references.count, 1)
        XCTAssertEqual(session.projection.references[0].reference.kind, .session)
        XCTAssertFalse(session.projection.display.contains("dsh-session:"))
        session.setMarkedText("nihao")
        XCTAssertEqual(session.committedText, token + " ")
        XCTAssertEqual(session.projection.references.count, 1)
        XCTAssertNil(session.mentionQuery)
        session.unmarkText()
        XCTAssertEqual(session.committedText, token + " nihao")
        XCTAssertEqual(session.projection.references.count, 1)
        XCTAssertEqual(session.projection.references[0].reference.label, "你好")
        XCTAssertFalse(session.projection.display.contains("dsh-session:"))
        XCTAssertTrue(session.projection.display.hasSuffix("你好 nihao"))
        XCTAssertTrue(session.committedText.hasSuffix("nihao"))
    }

    func testFileChipSurvivesMarkedCompositionThenUnmark() {
        var session = ComposerImeSession(text: "@README.md ")
        XCTAssertEqual(session.projection.references.map(\.reference.kind), [.file])
        session.setMarkedText("nihao")
        XCTAssertEqual(session.projection.references.count, 1)
        XCTAssertNil(session.mentionQuery)
        session.unmarkText()
        XCTAssertEqual(session.committedText, "@README.md nihao")
        XCTAssertEqual(session.projection.references.map(\.reference.label), ["README.md"])
        XCTAssertFalse(session.projection.display.contains("@README.md"))
    }
}
