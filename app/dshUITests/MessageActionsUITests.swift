import XCTest

final class MessageActionsUITests: XCTestCase {
    func testEditingUsesSeparateDraftAndLeavesComposerUntouched() {
        let app = launch(screen: "chat")
        let composer = app.textViews["composerInput"]
        XCTAssertTrue(composer.waitForExistence(timeout: 8))
        composer.tap()
        composer.typeText("Keep this composer draft")
        let draft = composer.value as? String

        openMenu(app, key: "u1")
        let edit = app.buttons["userMessageEdit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let editor = app.textViews["userMessageEditInput"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "你好")
        editor.tap()
        editor.typeText(" edited")
        XCTAssertTrue((editor.value as? String ?? "").contains("edited"))
        app.buttons["关闭"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, draft)
    }

    func testCanonicalMentionTokensSurviveOpeningEditor() {
        let app = launch(screen: "mentionSent")
        openMenu(app, key: "u-mention")
        app.buttons["userMessageEdit"].tap()
        let editor = app.textViews["userMessageEditInput"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "@[你好](dsh-session:s-hello) @README.md")
    }

    func testResendReportsUnavailableTransportWithoutChangingComposer() {
        let app = launch(screen: "chat")
        let composer = app.textViews["composerInput"]
        XCTAssertTrue(composer.waitForExistence(timeout: 8))
        composer.tap()
        composer.typeText("Do not consume this draft")
        let draft = composer.value as? String
        openMenu(app, key: "u1")
        let copy = app.buttons["userMessageCopy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(copy.isEnabled)
        let resend = app.buttons["userMessageResend"]
        XCTAssertTrue(resend.waitForExistence(timeout: 5))
        resend.tap()
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "未连接到远程主机")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5), "resend failure was not shown")
        XCTAssertEqual(composer.value as? String, draft)
    }

    private func openMenu(_ app: XCUIApplication, key: String) {
        let menu = app.descendants(matching: .any)["userMessageMenu.\(key)"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        if !menu.isHittable {
            app.swipeDown()
        }
        menu.tap()
    }

    private func launch(screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestAppearanceLight", "-UITestScreen", screen]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        return app
    }
}
