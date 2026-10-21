import XCTest
import CoreFoundation

final class TodoLifecycleUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testCompletedTurnKeepsDockAndHistoricalTool() {
        let app = launchCompletedRound()
        assertHistoricalToolReadable(app)
        app.buttons["chatTab.chat"].tap()
        XCTAssertTrue(todoPanel(app).waitForExistence(timeout: 5), "turn/end must keep the completed list for this round")
    }

    func testNullProjectionRemovesEntireDockButKeepsHistory() {
        assertClearsDock(action: "projectionNull")
    }

    func testEmptyProjectionRemovesEntireDockButKeepsHistory() {
        assertClearsDock(action: "projectionEmpty")
    }

    func testNextTurnStartRemovesEntireDockButKeepsHistory() {
        assertClearsDock(action: "turnStart")
    }

    func testSnapshotNullRemovesEntireDockButKeepsHistory() {
        assertClearsDock(action: "snapshotNull")
    }

    func testResumeNullRemovesEntireDockButKeepsHistory() {
        assertClearsDock(action: "resumeNull")
    }

    func testResumeWithoutTodosDoesNotClearCompletedDock() {
        let app = launchCompletedRound()
        post("resumeMissing")
        XCTAssertTrue(app.staticTexts["缺失投影仍保留任务"].waitForExistence(timeout: 5), "The real resume frame was not published")
        XCTAssertTrue(todoPanel(app).exists, "An omitted projection key is not an explicit clear")
        assertHistoricalToolReadable(app)
    }

    private func launchCompletedRound() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestAppearanceLight", "-UITestScreen", "todoLifecycle"]
        app.launch()
        XCTAssertTrue(todoPanel(app).waitForExistence(timeout: 10), "The completed todo/write must be published through the real reducer")
        XCTAssertTrue(app.staticTexts["2 已完成"].exists, "All-completed lists must remain visible, not be special-cased away")
        post("complete")
        XCTAssertTrue(app.staticTexts["本轮任务已完成"].waitForExistence(timeout: 5), "The follow event chain was not published")
        XCTAssertTrue(todoPanel(app).exists, "turn/end must not remove this round's completed tasks")
        return app
    }

    private func assertClearsDock(action: String) {
        let app = launchCompletedRound()
        let panel = todoPanel(app)
        post(action)
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: panel)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed, "\(action) must remove the complete dock, not only its rows")
        assertHistoricalToolReadable(app)
        app.buttons["chatTab.chat"].tap()
        XCTAssertFalse(todoPanel(app).exists, "Opening historical todo_write details must not restore the live dock")
    }

    private func assertHistoricalToolReadable(_ app: XCUIApplication) {
        let trajectory = app.buttons["chatTab.trajectory"]
        XCTAssertTrue(trajectory.waitForExistence(timeout: 5))
        trajectory.tap()
        let row = app.buttons["trajRow.ktodo-history"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Clearing the live list must retain the original todo_write event")
        row.tap()
        let parameters = app.buttons["参数"].firstMatch
        XCTAssertTrue(parameters.waitForExistence(timeout: 5))
        parameters.tap()
        let originalTask = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "保留本轮完成任务")).firstMatch
        for _ in 0..<3 {
            if originalTask.exists { break }
            let expand = app.buttons["展开"].firstMatch
            XCTAssertTrue(expand.exists, "The original todo parameters must remain inspectable")
            guard expand.exists else { return }
            expand.tap()
        }
        XCTAssertTrue(originalTask.waitForExistence(timeout: 5))
        let result = app.buttons["结果"].firstMatch
        XCTAssertTrue(result.exists)
        result.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "todo-history-result-retained")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["关闭详情"].firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    private func todoPanel(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["todoPanel"].firstMatch
    }

    /// The runner and app share the device's Darwin notification center, not process-local NotificationCenter.
    private func post(_ action: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: "dev.dsh.uitest.todoLifecycle.\(action)" as CFString),
            nil,
            nil,
            true
        )
    }
}
