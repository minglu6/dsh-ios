import XCTest

final class TrajectoryUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testLongSingleTurnSearchDetailsRequestsAndReturn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "trajectoryLarge"]
        app.launch()
        let trajectory = app.buttons["chatTab.trajectory"]
        XCTAssertTrue(trajectory.waitForExistence(timeout: 10))
        trajectory.tap()

        let first = app.buttons["trajRow.a3"]
        XCTAssertTrue(first.waitForExistence(timeout: 10), "A long single turn must enter without blocking")
        try capture(app, name: "trajectory-large-ledger")
        first.tap()
        XCTAssertTrue(app.staticTexts["第 1 轮 · 第 1 步"].waitForExistence(timeout: 5))
        closeDetail(app)
        XCTAssertTrue(first.isHittable)

        let search = app.textFields["搜索轨迹"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("trajectory-final-needle")
        let last = app.buttons["trajRow.a384"]
        XCTAssertTrue(last.waitForExistence(timeout: 10), "Search must include the end of the complete final answer")
        XCTAssertFalse(first.exists)
        last.tap()
        XCTAssertTrue(app.staticTexts["第 1 轮 · 第 128 步"].waitForExistence(timeout: 5))
        app.buttons["原始内容"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "trajectory-final-needle")).firstMatch.waitForExistence(timeout: 5))
        closeDetail(app)

        let request = app.buttons["请求 #128"]
        XCTAssertTrue(request.waitForExistence(timeout: 5), "The final row keeps its original request number")
        request.tap()
        try capture(app, name: "trajectory-large-request")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "结果", "助手消息")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        try capture(app, name: "trajectory-large-result-navigation")
        let rawResult = app.buttons["原始内容"].firstMatch
        XCTAssertTrue(rawResult.waitForExistence(timeout: 5), "Result navigation opens assistant content, not the request inspector")
        rawResult.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "trajectory-final-needle")).firstMatch.waitForExistence(timeout: 5))
        try capture(app, name: "trajectory-large-request-result")
        XCTAssertTrue(app.staticTexts["第 1 轮 · 第 128 步"].waitForExistence(timeout: 5))
        closeDetail(app)

        app.buttons["轮次"].tap()
        let turn = app.buttons["第 1 轮"]
        XCTAssertTrue(turn.waitForExistence(timeout: 5))
        turn.tap()
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        try capture(app, name: "trajectory-large-filtered")
        app.buttons["调用"].tap()
        XCTAssertTrue(last.isHittable, "Collapsing tools must preserve matching assistant rows")
        app.buttons["调用"].tap()
        app.buttons["时长"].tap()
        XCTAssertTrue(last.isHittable)

        search.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "trajectory-final-needle".count))
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        app.buttons["chatTab.chat"].tap()
        XCTAssertTrue(trajectory.isHittable)
        trajectory.tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Returning to the long ledger must remain responsive")
    }

    func testInspectorTabsMarkdownAndDismissal() throws {
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-UITestFixture", "-UITestScreen", "trajectoryDetail", appearance == "dark" ? "-UITestAppearanceDark" : "-UITestAppearanceLight"]
            app.launch()
            let tool = app.buttons["trajRow.t-read"]
            XCTAssertTrue(tool.waitForExistence(timeout: 10))
            tool.tap()

            let close = app.buttons["关闭详情"].firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            let ledger = app.scrollViews["trajectoryLedger"]
            XCTAssertEqual(close.frame.midY, ledger.frame.minY + 21, accuracy: 2, "Details stay inside the ledger, below its toolbar and timeline")
            let location = app.staticTexts["trajectoryInspector.location"]
            XCTAssertGreaterThan(location.frame.minX, ledger.frame.minX, "The narrow inspector leaves the ledger edge visible")
            XCTAssertTrue(app.buttons["chatTab.chat"].isHittable, "Inspecting a record must not present a modal over the conversation")
            let tabs = app.scrollViews["trajectoryInspector.tabs"]
            XCTAssertTrue(tabs.buttons["参数"].isHittable)
            try capture(app, name: "\(appearance)-trajectory-tool-overview")
            tabs.buttons["参数"].tap()
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "README.md")).firstMatch.waitForExistence(timeout: 5))
            tabs.buttons["计时"].tap()
            XCTAssertTrue(app.staticTexts["开始时间"].waitForExistence(timeout: 5))
            closeDetail(app)
            XCTAssertTrue(tool.isHittable, "Closing a detail must restore the same ledger")

            app.buttons["trajRow.a1"].tap()
            let previewTabs = app.scrollViews["trajectoryInspector.tabs"]
            previewTabs.buttons["预览"].tap()
            XCTAssertTrue(app.staticTexts["第一项"].waitForExistence(timeout: 5), "Preview renders Markdown list content")
            try capture(app, name: "\(appearance)-trajectory-markdown-preview")
            previewTabs.buttons["原始内容"].tap()
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "- 第一项")).firstMatch.waitForExistence(timeout: 5), "Raw content retains Markdown source")
            closeDetail(app)
            XCTAssertTrue(app.buttons["trajRow.a1"].isHittable)
            app.buttons["trajRow.a1"].tap()
            let restoredRaw = app.scrollViews["trajectoryInspector.tabs"].buttons["原始内容"]
            XCTAssertTrue(restoredRaw.waitForExistence(timeout: 5))
            XCTAssertTrue(restoredRaw.isSelected, "Reopening a record retains the last compatible detail tab")
            closeDetail(app)
            app.terminate()
        }
    }

    private func closeDetail(_ app: XCUIApplication) {
        let close = app.buttons["关闭详情"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
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
