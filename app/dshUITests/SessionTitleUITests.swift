import XCTest

final class SessionTitleUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    private let chinese = "会话标题完整阅读：核对多端交互、代码修改、历史记录复用与无障碍表现，确保最后一段内容仍然可以清楚阅读【中文末尾】"
    private let english = "Review conversation title overflow, history row reuse, accessibility and desktop parity without losing the final words [English tail]"
    private var launchedApp: XCUIApplication?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        if let app = launchedApp, (testRun?.failureCount ?? 0) > 0 {
            let name = "session-title-failure-\(self.name.replacingOccurrences(of: "/", with: "-"))"
            try? capture(app, name: name)
            let hierarchy = app.debugDescription
            let attachment = XCTAttachment(string: hierarchy)
            attachment.name = "\(name)-hierarchy"
            attachment.lifetime = .keepAlways
            add(attachment)
            if let root = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"] {
                try? hierarchy.write(
                    to: URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("\(name)-hierarchy.txt"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        }
        launchedApp = nil
        super.tearDown()
    }

    func testFullChineseAndEnglishTitlesStayAnchoredAndDismissOutside() throws {
        let app = launch(reduceMotion: true)
        try assertFullTitle(chinese, in: app, screenshot: "session-title-chinese")
        app.buttons["openDrawer"].tap()
        let row = app.buttons["sessionRow.title-english"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertFalse(app.scrollViews["sessionList"].exists, "A title remains part of the row's open-session action")
        try assertFullTitle(english, in: app, screenshot: "session-title-english")
    }

    func testOnlyOverflowingHistoryTitlesRevealWithoutRelayingOutRows() throws {
        let app = launch()
        app.buttons["openDrawer"].tap()
        let chineseTitle = title("s-hello", in: app)
        let englishTitle = title("title-english", in: app)
        XCTAssertTrue(chineseTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(chineseTitle.label, chinese)
        XCTAssertEqual(englishTitle.label, english)
        XCTAssertEqual(title("title-short", in: app).value as? String, "resting")
        XCTAssertEqual(title("title-short-english", in: app).value as? String, "resting")
        let row = app.buttons["sessionRow.s-hello"]
        let originalFrame = row.frame
        try capture(app, name: "session-history-marquee")
        waitForValue("revealed", element: chineseTitle, timeout: 90)
        waitForValue("revealed", element: englishTitle, timeout: 90)
        XCTAssertEqual(row.frame, originalFrame, "Only the glyph layer travels; row geometry must stay fixed")
        try capture(app, name: "session-history-marquee-tail")
        app.buttons["sessionRowMore"].firstMatch.tap()
        XCTAssertTrue(app.buttons["重命名"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["sessionList"].exists, "Opening the menu must not open a conversation")
        try capture(app, name: "session-history-title-menu")
    }

    func testReducedMotionRevealsTailWithoutAnimationAndKeepsFullAccessibleNames() throws {
        let app = launch(reduceMotion: true)
        app.buttons["openDrawer"].tap()
        let chineseTitle = title("s-hello", in: app)
        XCTAssertTrue(chineseTitle.waitForExistence(timeout: 5))
        waitForValue("reducedMotion", element: chineseTitle)
        waitForValue("reducedMotion", element: title("title-english", in: app))
        XCTAssertEqual(chineseTitle.label, chinese)
        XCTAssertEqual(title("title-english", in: app).label, english)
        XCTAssertEqual(title("title-short", in: app).value as? String, "resting")
        try capture(app, name: "session-history-reduced-motion")
        app.buttons["sessionRow.title-short"].tap()
        try assertFullTitle("短标题", in: app, screenshot: "session-title-short")
        app.buttons["openDrawer"].tap()
        app.buttons["sessionRow.title-short-english"].tap()
        try assertFullTitle("Hello", in: app, screenshot: "session-title-short-english")
    }

    func testTitleChangesResetReusedHeaderAndHistoryTitles() throws {
        let app = launch(reduceMotion: true, changing: true)
        try assertFullTitle(chinese, in: app, screenshot: "session-title-before-update")
        let input = app.textViews["composerInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("short")
        let header = app.buttons["conversationHeaderTitle"]
        waitForLabel("短标题", element: header)
        app.buttons["openDrawer"].tap()
        let reused = title("s-hello", in: app)
        XCTAssertTrue(reused.waitForExistence(timeout: 5))
        XCTAssertEqual(reused.label, "短标题")
        waitForValue("resting", element: reused)
        app.buttons["sessionRow.s-hello"].tap()
        try assertFullTitle("短标题", in: app, screenshot: "session-title-reused-short")
        input.tap()
        input.typeText(" english")
        waitForLabel(english, element: header)
        try assertFullTitle(english, in: app, screenshot: "session-title-reused-english")
        app.buttons["openDrawer"].tap()
        let updated = title("s-hello", in: app)
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        XCTAssertEqual(updated.label, english)
        waitForValue("reducedMotion", element: updated)
        try capture(app, name: "session-history-reused-english")
    }

    private func launch(reduceMotion: Bool = false, changing: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        launchedApp = app
        app.launchArguments = ["-UITestFixture", "-UITestScreen", changing ? "sessionTitlesChanging" : "sessionTitles"]
        if reduceMotion { app.launchArguments.append("-UITestTitleReduceMotion") }
        app.launch()
        XCTAssertTrue(app.buttons["conversationHeaderTitle"].waitForExistence(timeout: 10))
        return app
    }

    private func title(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["sessionRecordTitle.\(id)"].firstMatch
    }

    private func assertFullTitle(_ expected: String, in app: XCUIApplication, screenshot: String) throws {
        let header = app.buttons["conversationHeaderTitle"]
        XCTAssertEqual(header.label, expected)
        header.tap()
        let full = app.staticTexts["conversationTitleFull"]
        XCTAssertTrue(full.waitForExistence(timeout: 5))
        XCTAssertEqual(full.label, expected)
        XCTAssertTrue(full.isHittable, "The complete title must be visible in the anchored popover")
        let popover = app.descendants(matching: .any)["conversationTitlePopover"].firstMatch
        XCTAssertTrue(popover.exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertLessThan(popover.frame.height, app.frame.height * 0.8)
        XCTAssertLessThan(popover.frame.width, app.frame.width)
        XCTAssertFalse(app.buttons["关闭"].exists)
        XCTAssertFalse(app.buttons["刷新"].exists)
        try capture(app, name: screenshot)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.6)).tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: full)
        waitForExpectations(timeout: 5)
    }

    private func waitForValue(_ value: String, element: XCUIElement, timeout: TimeInterval = 5) {
        expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    private func waitForLabel(_ label: String, element: XCUIElement) {
        expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    private func capture(_ app: XCUIApplication, name: String) throws {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let root = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"] {
            let directory = URL(fileURLWithPath: root, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
