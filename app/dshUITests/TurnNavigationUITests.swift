import XCTest
import CoreFoundation

final class TurnNavigationUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSingleTurnHasNoDecorativeRail() {
        let app = launch("turnNavigationSingle")
        XCTAssertFalse(app.buttons["transcript-turn-21"].exists)
        XCTAssertFalse(app.buttons["transcriptScrollToBottom"].exists)
        capture(app, "single-turn-no-rail")
    }

    func testLoadedTurnTapAndLongPressPreview() {
        let app = launch()
        let mark = app.buttons["transcript-turn-8"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.press(forDuration: 0.8)
        XCTAssertTrue(app.descendants(matching: .any)["transcriptTurnPreview"].firstMatch.waitForExistence(timeout: 5))
        capture(app, "turn-preview-touch")
        mark.tap()
        waitValue(app, "activeTurn=8")
        waitValue(app, "follow=false")
        XCTAssertTrue(app.staticTexts["Navigation prompt 8"].isHittable)
        capture(app, "loaded-turn-jump")
    }

    func testUnloadedHostTurnPagesThenLandsAndCanReturnToTail() {
        let app = launch()
        let old = app.buttons["transcript-turn-3"]
        XCTAssertTrue(old.waitForExistence(timeout: 5), "Whole-log projection must expose the unloaded Host identity")
        XCTAssertFalse(app.buttons["transcript-turn-1"].exists, "Local ordinals must never replace sparse Host identities")
        old.tap()
        waitValue(app, "requests=1;responses=1;failures=0")
        waitValue(app, "activeTurn=3")
        XCTAssertTrue(app.staticTexts["Navigation prompt 3"].isHittable)
        capture(app, "unloaded-turn-paged-and-landed")
        app.buttons["transcriptScrollToBottom"].tap()
        waitValue(app, "follow=true")
        waitValue(app, "activeTurn=21")
        capture(app, "return-to-bottom")
    }

    func testTailFollowsNewHostTurn() {
        let app = launch()
        waitValue(app, "follow=true")
        appendHostTurn()
        XCTAssertTrue(app.buttons["transcript-turn-34"].waitForExistence(timeout: 5))
        waitValue(app, "activeTurn=34")
        XCTAssertFalse(app.buttons["transcriptScrollToBottom"].exists)
        capture(app, "tail-follows-new-turn")
    }

    func testManualReadingIsNotPulledToNewMessages() {
        let app = launch()
        let transcript = app.scrollViews["chatTranscript"]
        transcript.swipeDown()
        waitValue(app, "follow=false")
        XCTAssertTrue(app.buttons["transcriptScrollToBottom"].waitForExistence(timeout: 5))
        appendHostTurn()
        XCTAssertTrue(app.buttons["transcript-turn-34"].waitForExistence(timeout: 5))
        waitValue(app, "follow=false")
        XCTAssertFalse((transcript.value as? String ?? "").contains("activeTurn=34"))
        capture(app, "manual-reading-survives-new-turn")
        app.buttons["transcriptScrollToBottom"].tap()
        waitValue(app, "activeTurn=34")
        waitValue(app, "follow=true")
    }

    func testOlderHostOnlyShowsLoadedRealIdentitiesAndPullRefreshAddsEarlierTurn() {
        let app = launch("turnNavigationLegacy")
        XCTAssertTrue(app.buttons["transcript-turn-8"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["transcript-turn-3"].exists, "Missing Host outline is not permission to invent unseen turns")
        app.buttons["transcript-turn-8"].tap()
        waitValue(app, "activeTurn=8")
        let transcript = app.scrollViews["chatTranscript"]
        transcript.swipeDown()
        waitValue(app, "requests=1;responses=1;failures=0")
        XCTAssertTrue(app.buttons["transcript-turn-3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Navigation prompt 8"].isHittable, "Prepending must preserve the old reading anchor")
        capture(app, "legacy-host-pull-refresh-anchor")
    }

    private func launch(_ screen: String = "turnNavigation") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestAppearanceLight", "-UITestScreen", screen]
        app.launch()
        waitValue(app, "requests=0;responses=0;failures=0")
        waitValue(app, "activeTurn=21")
        return app
    }

    private func waitValue(_ app: XCUIApplication, _ fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", fragment), object: app.scrollViews["chatTranscript"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, fragment, file: file, line: line)
    }

    private func appendHostTurn() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: "dev.dsh.uitest.turnNavigation.append" as CFString), nil, nil, true)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
