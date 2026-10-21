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
        let preview = app.descendants(matching: .any)["transcriptTurnPreview"].firstMatch
        let appeared = preview.waitForExistence(timeout: 5)
        capture(app, "turn-preview-touch")
        if !appeared { diagnose(app, elements: [mark, preview]) }
        XCTAssertTrue(appeared)
        waitValue(app, "activeTurn=21")
        waitValue(app, "follow=true")
        mark.tap()
        waitValue(app, "activeTurn=8")
        waitValue(app, "follow=false")
        waitValue(app, "landing=false")
        assertPromptHittable(app, turn: 8, screenshot: "loaded-turn-jump")
    }

    func testUnloadedHostTurnPagesThenLandsAndCanReturnToTail() {
        let app = launch()
        let old = app.buttons["transcript-turn-3"]
        XCTAssertTrue(old.waitForExistence(timeout: 5), "Whole-log projection must expose the unloaded Host identity")
        XCTAssertFalse(app.buttons["transcript-turn-1"].exists, "Local ordinals must never replace sparse Host identities")
        old.tap()
        waitValue(app, "requests=1;responses=1;failures=0")
        waitValue(app, "activeTurn=3")
        waitValue(app, "landing=false")
        assertPromptHittable(app, turn: 3, screenshot: "unloaded-turn-paged-and-landed")
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
        waitValue(app, "landing=false")
        assertPromptHittable(app, turn: 8, screenshot: "legacy-host-before-pull")
        let transcript = app.scrollViews["chatTranscript"]
        let start = transcript.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = transcript.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        waitValue(app, "requests=1;responses=1;failures=0")
        XCTAssertTrue(app.buttons["transcript-turn-3"].waitForExistence(timeout: 5))
        waitValue(app, "firstSeq=300;loading=false")
        waitValue(app, "landing=false")
        assertPromptHittable(app, turn: 8, screenshot: "legacy-host-pull-refresh-anchor")
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
        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            capture(app, "turn-navigation-state-failure-\(line)")
            diagnose(app, elements: [])
        }
        XCTAssertEqual(result, .completed, fragment, file: file, line: line)
    }

    private func assertPromptHittable(_ app: XCUIApplication, turn: Int, screenshot: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        let prompt = app.staticTexts["Navigation prompt \(turn)"]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            prompt.exists && prompt.isHittable
        }, object: prompt)
        let result = XCTWaiter.wait(for: [visible], timeout: 5)
        capture(app, screenshot)
        if result != .completed { diagnose(app, elements: [prompt, app.buttons["transcript-turn-\(turn)"]]) }
        XCTAssertEqual(result, .completed, "The actual Host prompt must be hittable after landing", file: file, line: line)
    }

    private func diagnose(_ app: XCUIApplication, elements: [XCUIElement]) {
        let transcript = app.scrollViews["chatTranscript"]
        print("Transcript frame: \(transcript.frame); state: \(transcript.value as? String ?? "")")
        for element in elements {
            print("Element \(element.identifier): exists=\(element.exists); frame=\(element.frame); hittable=\(element.isHittable)")
        }
        print(app.debugDescription)
    }

    private func appendHostTurn() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: "dev.dsh.uitest.turnNavigation.append" as CFString), nil, nil, true)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let root = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"] {
            do {
                let directory = URL(fileURLWithPath: root, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
            } catch { XCTFail("Could not export turn navigation screenshot: \(error)") }
        }
    }
}
