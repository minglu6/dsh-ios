import XCTest

/// Round 58: composer IME must not cover the session drawer or survive a
/// transcript scroll. Software keyboard on the simulator (CI disables the
/// hardware keyboard).
final class KeyboardDismissalTests: XCTestCase {
    func testOpeningDrawerDismissesComposerKeyboard() {
        let app = launch(screen: "landing")
        focusComposer(app)
        assertKeyboardVisible(app, "landing composer did not show the keyboard")

        let open = app.buttons["openDrawer"]
        XCTAssertTrue(open.waitForExistence(timeout: 8), "openDrawer missing")
        open.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["drawerSettingsRow"].waitForExistence(timeout: 8),
            "drawer did not open"
        )
        assertKeyboardHidden(app, "keyboard still up after opening the drawer")
        XCTAssertFalse(
            app.keyboards.element.exists && app.keyboards.element.isHittable,
            "keyboard still covering the drawer footer"
        )
    }

    func testScrollingChatDismissesComposerKeyboard() {
        let app = launch(screen: "chat", extraChat: true)
        focusComposer(app)
        assertKeyboardVisible(app, "chat composer did not show the keyboard")

        let transcript = app.descendants(matching: .any)["chatTranscript"].firstMatch
        XCTAssertTrue(transcript.waitForExistence(timeout: 8), "chat transcript missing")
        transcript.swipeUp()

        assertKeyboardHidden(app, "keyboard still up after scrolling the message list")
    }

    func testOpeningRemoteHostFromDrawerDoesNotLeaveKeyboard() {
        let app = launch(screen: "landing")
        focusComposer(app)
        assertKeyboardVisible(app, "landing composer did not show the keyboard")

        let open = app.buttons["openDrawer"]
        XCTAssertTrue(open.waitForExistence(timeout: 8), "openDrawer missing")
        open.tap()
        assertKeyboardHidden(app, "keyboard still up after opening the drawer")

        let host = app.descendants(matching: .any)["drawerPeerDeviceRow"].firstMatch
        XCTAssertTrue(host.waitForExistence(timeout: 8), "drawer host hit missing")
        host.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["connectionsScreen"].firstMatch.waitForExistence(timeout: 8),
            "远程主机 page missing"
        )
        assertKeyboardHidden(app, "keyboard still up on 远程主机")
    }

    private func launch(screen: String, extraChat: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-UITestFixture",
            "-UITestAppearanceLight",
            "-UITestScreen", screen,
        ]
        if extraChat { args.append("-UITestKeyboard") }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "\(screen) did not reach foreground")
        return app
    }

    private func focusComposer(_ app: XCUIApplication) {
        let input = app.textViews["composerInput"]
        if input.waitForExistence(timeout: 8) {
            input.tap()
            return
        }
        let any = app.descendants(matching: .any)["composerInput"].firstMatch
        if any.waitForExistence(timeout: 4) {
            any.tap()
            return
        }
        let landing = app.descendants(matching: .any)["landingComposer"].firstMatch
        XCTAssertTrue(
            landing.waitForExistence(timeout: 8),
            "composerInput and landingComposer missing"
        )
        landing.tap()
    }

    private func assertKeyboardVisible(_ app: XCUIApplication, _ message: String) {
        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 8),
            message
        )
    }

    private func assertKeyboardHidden(_ app: XCUIApplication, _ message: String) {
        let keyboard = app.keyboards.element
        if keyboard.exists {
            XCTAssertTrue(keyboard.waitForNonExistence(timeout: 8), message)
        }
        if keyboard.exists {
            XCTAssertFalse(keyboard.isHittable, "\(message) (still visible)")
        }
    }
}
