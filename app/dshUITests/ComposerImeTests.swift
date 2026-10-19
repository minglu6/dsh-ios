import XCTest

/// P0: landing / chat composer must keep UIKit marked text alive so the
/// system Pinyin candidate bar can show. Simulator has no CJK keyboard in
/// CI, so the app applies `setMarkedText` / `unmarkText` under a fixture flag.
final class ComposerImeTests: XCTestCase {
    func testLandingMarkedTextSurvivesAndDoesNotOpenMentionMenu() {
        let app = launch(screen: "landing")
        focusComposer(app)

        tapImeControl(app, "composerIme.setMarked")
        let marked = app.descendants(matching: .any)["composerIme.marked"].firstMatch
        XCTAssertTrue(marked.waitForExistence(timeout: 8), "setMarkedText did not leave marked text in the landing composer")
        XCTAssertEqual(marked.value as? String, "nihao")
        XCTAssertFalse(
            app.descendants(matching: .any)["mentionMenu"].exists,
            "mention parsing ran while marked text was active"
        )

        tapImeControl(app, "composerIme.unmark")
        XCTAssertTrue(
            app.descendants(matching: .any)["composerIme.idle"].firstMatch.waitForExistence(timeout: 8),
            "unmarkText did not end composition"
        )
        XCTAssertFalse(app.descendants(matching: .any)["composerIme.marked"].exists)
        let committed = app.descendants(matching: .any)["composerIme.idle"].firstMatch
        XCTAssertEqual(committed.value as? String, "nihao")
        XCTAssertFalse(
            app.descendants(matching: .any)["mentionMenu"].exists,
            "plain pinyin commit must not open the mention panel"
        )
    }

    func testCommittedChipSurvivesMarkedTextThenConvertsAfterUnmark() {
        let app = launch(screen: "mentionChip")
        XCTAssertTrue(
            app.descendants(matching: .any)["mentionChip.session"].waitForExistence(timeout: 8),
            "mentionChip fixture missing session chip"
        )
        focusComposer(app)

        tapImeControl(app, "composerIme.setMarked")
        let marked = app.descendants(matching: .any)["composerIme.marked"].firstMatch
        XCTAssertTrue(marked.waitForExistence(timeout: 8), "setMarkedText cleared composition on a chip draft")
        XCTAssertEqual(marked.value as? String, "nihao")
        XCTAssertTrue(
            app.descendants(matching: .any)["mentionChip.session"].exists,
            "marked text rewrite dropped the session chip"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["mentionMenu"].exists,
            "mention parsing ran while marked text was active on a chip draft"
        )

        tapImeControl(app, "composerIme.unmark")
        XCTAssertTrue(
            app.descendants(matching: .any)["composerIme.idle"].firstMatch.waitForExistence(timeout: 8),
            "unmarkText did not end composition after a chip"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["mentionChip.session"].exists,
            "session chip missing after unmarkText"
        )
        let committed = app.descendants(matching: .any)["composerIme.idle"].firstMatch.value as? String ?? ""
        XCTAssertTrue(committed.contains("nihao"), "committed pinyin missing after unmark (got \(committed))")
    }

    private func launch(screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestFixture",
            "-UITestAppearanceLight",
            "-UITestScreen", screen,
            "-UITestComposerIme",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "\(screen) did not reach foreground")
        return app
    }

    private func tapImeControl(_ app: XCUIApplication, _ id: String) {
        let control = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 8), "\(id) missing")
        control.tap()
    }

    private func focusComposer(_ app: XCUIApplication) {
        let input = app.textViews["composerInput"]
        if input.waitForExistence(timeout: 8) {
            input.tap()
            return
        }
        let landing = app.descendants(matching: .any)["landingComposer"].firstMatch
        XCTAssertTrue(landing.waitForExistence(timeout: 8), "composerInput and landingComposer missing")
        landing.tap()
    }
}
