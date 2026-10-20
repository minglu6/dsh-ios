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
        XCTAssertTrue(app.navigationBars["请求 #128"].waitForExistence(timeout: 5))
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "结果", "助手消息")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.navigationBars["助手"].waitForExistence(timeout: 5))
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

        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "trajectory-final-needle".count))
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        app.buttons["chatTab.chat"].tap()
        XCTAssertTrue(trajectory.isHittable)
        trajectory.tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Returning to the long ledger must remain responsive")
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
