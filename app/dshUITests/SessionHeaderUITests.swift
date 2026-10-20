import XCTest

final class SessionHeaderUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testTeamAndCatalogUseDifferentDataAndNavigateRetainedChildren() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "sessionHeader"]
        app.launch()
        let team = app.buttons["conversationTeam"]
        XCTAssertTrue(team.waitForExistence(timeout: 10))
        let count = app.buttons["conversationSubagents"]
        XCTAssertTrue(count.label.contains("6 个子智能体"))
        XCTAssertEqual(app.descendants(matching: .any)["conversationPreset"].firstMatch.label, "标准模式")
        XCTAssertFalse(app.descendants(matching: .any)["conversationWorkspace"].exists)
        let title = app.descendants(matching: .any)["conversationHeaderTitle"].firstMatch
        let preset = app.descendants(matching: .any)["conversationPreset"].firstMatch
        let tabs = app.buttons["chatTab.chat"]
        XCTAssertGreaterThan(title.frame.width, 24, "Long titles retain a visible navigation label")
        XCTAssertGreaterThanOrEqual(team.frame.minX, title.frame.maxX)
        XCTAssertGreaterThanOrEqual(preset.frame.minX, team.frame.maxX)
        XCTAssertGreaterThanOrEqual(count.frame.minX, preset.frame.maxX)
        for control in [team, preset, count] {
            XCTAssertLessThan(control.frame.maxY, tabs.frame.minY, "Header actions belong above the tab strip")
            XCTAssertLessThan(abs(control.frame.midY - title.frame.midY), 8, "Header actions share the title row")
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        try capture(app, name: "session-header-actions")

        team.tap()
        XCTAssertTrue(app.staticTexts["Review session header"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["agentTeamMember_header-child-1"].exists)
        XCTAssertFalse(app.buttons["agentTeamMember_header-child-6"].exists)
        let popover = app.descendants(matching: .any)["agentTeamPopover"].firstMatch
        XCTAssertTrue(popover.exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertFalse(app.buttons["关闭"].exists)
        XCTAssertFalse(app.buttons["刷新"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["agentTeamCurrentTag"].firstMatch.exists)
        XCTAssertLessThan(popover.frame.height, app.frame.height * 0.8)
        try capture(app, name: "session-header-team")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: popover)
        waitForExpectations(timeout: 5)

        count.tap()
        let oneShot = app.buttons["subagentSession.header-child-6"]
        XCTAssertTrue(oneShot.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["subagentSession.ordinary-fork"].exists)
        try capture(app, name: "session-header-subagents")
        oneShot.tap()
        XCTAssertTrue(app.descendants(matching: .any)["subagentReadOnly"].waitForExistence(timeout: 5))
        app.buttons["conversationSubagents"].tap()
        let main = app.buttons["subagentMainSession"]
        XCTAssertTrue(main.waitForExistence(timeout: 5))
        XCTAssertTrue(main.isEnabled)
        main.tap()
        XCTAssertFalse(app.descendants(matching: .any)["subagentReadOnly"].exists)
    }

    func testSingleMemberTeamRemainsACompactDismissiblePopover() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "sessionHeaderCompactTeam"]
        app.launch()
        let team = app.buttons["conversationTeam"]
        XCTAssertTrue(team.waitForExistence(timeout: 10))
        team.tap()
        let popover = app.descendants(matching: .any)["agentTeamPopover"].firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["agentTeamCurrentTag"].firstMatch.exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertFalse(app.buttons["关闭"].exists)
        XCTAssertFalse(app.buttons["刷新"].exists)
        XCTAssertLessThan(popover.frame.height, app.frame.height * 0.5)
        XCTAssertLessThan(popover.frame.width, app.frame.width)
        try capture(app, name: "session-header-compact-team")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: popover)
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
