import XCTest
import CoreFoundation

final class SessionTitleUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    private let chinese = "会话标题完整阅读：核对多端交互、代码修改、历史记录复用与无障碍表现，确保最后一段内容仍然可以清楚阅读【中文末尾】"
    private let english = "Review conversation title overflow, history row reuse, accessibility and desktop parity without losing the final words [English tail]"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
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

    func testMixedTitleKeepsTextInsideBubble() throws {
        let app = launch(reduceMotion: true)
        app.buttons["openDrawer"].tap()
        let row = app.buttons["sessionRow.title-mixed"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let mixed = "地面洞察报告生成逻辑梳理与 Agent Skill 准备"
        try assertFullTitle(mixed, in: app, screenshot: "session-title-mixed")
    }

    func testTitleMetadataUpdatesWhilePopoverStaysOpen() throws {
        let app = launch(reduceMotion: true)
        app.buttons["conversationHeaderTitle"].tap()
        let status = app.staticTexts["conversationTitleStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "空闲")
        for expected in ["运行中", "空闲"] {
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(rawValue: "dev.dsh.uitest.sessionTitle.toggleRunning" as CFString),
                nil, nil, true
            )
            waitForLabel(expected, element: status)
            XCTAssertEqual(app.staticTexts["conversationTitleTime"].label, "更新于刚刚")
            XCTAssertEqual(app.staticTexts["conversationTitleFull"].label, chinese)
        }
        try capture(app, name: "session-title-live-metadata")
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
        input.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.15)).tap()
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
        let status = app.staticTexts["conversationTitleStatus"]
        XCTAssertTrue(status.exists)
        XCTAssertEqual(status.label, "空闲")
        XCTAssertGreaterThanOrEqual(status.frame.minY, full.frame.maxY)
        XCTAssertGreaterThanOrEqual(popover.frame.maxY - status.frame.maxY, 11)
        let time = app.staticTexts["conversationTitleTime"]
        if expected == "地面洞察报告生成逻辑梳理与 Agent Skill 准备" {
            XCTAssertFalse(time.exists, "Missing timestamps must not become an epoch date")
        } else {
            XCTAssertTrue(time.exists)
            XCTAssertGreaterThanOrEqual(time.frame.minY, full.frame.maxY)
            XCTAssertGreaterThanOrEqual(status.frame.minY, time.frame.maxY)
        }
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertLessThan(popover.frame.height, app.frame.height * 0.8)
        XCTAssertLessThan(popover.frame.width, app.frame.width)
        XCTAssertGreaterThanOrEqual(full.frame.minX - popover.frame.minX, 15)
        XCTAssertGreaterThanOrEqual(popover.frame.maxX - full.frame.maxX, 15)
        XCTAssertGreaterThanOrEqual(full.frame.minY - popover.frame.minY, 11, "Text must clear the popover arrow and top padding")
        XCTAssertGreaterThanOrEqual(popover.frame.maxY - full.frame.maxY, 11)
        XCTAssertTrue(app.frame.contains(popover.frame), "The full-title bubble must remain inside the screen")
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
