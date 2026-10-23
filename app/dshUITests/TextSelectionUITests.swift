import XCTest

final class TextSelectionUITests: XCTestCase {
    func testUserMessageCopiesOnlyTheHeldWord() {
        let app = launch("chatLong")
        let text = app.textViews["userMentionText.run"].firstMatch
        assertRangeCopy(text, in: app)
    }

    func testMarkdownParagraphCopiesARangeInsteadOfTheWholeBlock() {
        let app = launch("chat")
        let paragraph = app.textViews["official.markdownFileChip"].firstMatch
        assertRangeCopy(paragraph, in: app)
    }

    func testOutputPinchReflowsTextWithoutChangingComposerAndKeepsRangeCopy() {
        let app = launch("chat")
        let paragraph = app.textViews["official.markdownFileChip"].firstMatch
        let composer = app.textViews["composerInput"].firstMatch
        XCTAssertTrue(paragraph.waitForExistence(timeout: 8))
        let source = paragraph.value as? String
        let initialHeight = paragraph.frame.height
        let composerHeight = composer.frame.height
        paragraph.pinch(withScale: 2, velocity: 1)
        let enlarged = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in paragraph.frame.height > initialHeight + 4 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enlarged], timeout: 4), .completed)
        XCTAssertEqual(paragraph.value as? String, source)
        XCTAssertEqual(composer.frame.height, composerHeight, accuracy: 1)
        let enlargedHeight = paragraph.frame.height
        paragraph.pinch(withScale: 0.7, velocity: -1)
        let reduced = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in paragraph.frame.height < enlargedHeight - 4 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [reduced], timeout: 4), .completed)
        assertRangeCopy(paragraph, in: app)
    }

    private func assertRangeCopy(_ target: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(target.waitForExistence(timeout: 8), "Expected a native selectable text view")
        let transcript = app.scrollViews["chatTranscript"].firstMatch
        for _ in 0..<4 where !target.isHittable { transcript.swipeDown() }
        XCTAssertTrue(target.isHittable)
        let source = target.value as? String ?? ""
        XCTAssertGreaterThan(source.count, 8)

        // Hold near the beginning of line one, not the attachment/link or blank padding.
        target.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 14, dy: 9)).press(forDuration: 1.1)
        let copy = menuAction(in: app, labels: ["复制", "Copy"])
        XCTAssertTrue(copy.waitForExistence(timeout: 4), "Native word selection must expose Copy")
        copy.tap()

        let composer = app.textViews["composerInput"].firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 4))
        composer.tap()
        composer.press(forDuration: 1.1)
        let paste = menuAction(in: app, labels: ["粘贴", "Paste"])
        XCTAssertTrue(paste.waitForExistence(timeout: 4))
        paste.tap()
        let populated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != ''"), object: composer
        )
        XCTAssertEqual(XCTWaiter.wait(for: [populated], timeout: 4), .completed)
        let copied = composer.value as? String ?? ""
        XCTAssertFalse(copied.isEmpty)
        XCTAssertTrue(source.contains(copied), "Copied range must come from the rendered text: \(copied)")
        XCTAssertLessThan(copied.count, source.count, "Long press must select a word/range, not copy the entire view")
    }

    private func menuAction(in app: XCUIApplication, labels: [String]) -> XCUIElement {
        let predicate = NSPredicate(format: "label IN %@", labels)
        let item = app.menuItems.matching(predicate).firstMatch
        if item.waitForExistence(timeout: 1) { return item }
        return app.buttons.matching(predicate).firstMatch
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestAppearanceLight", "-UITestScreen", screen]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        return app
    }
}
