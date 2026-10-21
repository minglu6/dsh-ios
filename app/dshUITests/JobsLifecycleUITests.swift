import XCTest
import CoreFoundation

final class JobsLifecycleUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testLiveTriggerAndSettledFoldUseDesktopSemantics() {
        let app = launch()
        XCTAssertEqual(trigger(app).label, "1 个后台任务运行中")
        trigger(app).tap()
        let section = app.buttons["jobs.settled.toggle"]
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        XCTAssertEqual(section.value as? String, "collapsed")
        XCTAssertTrue(app.buttons["jobs.row.jobs-live"].exists)
        XCTAssertFalse(app.buttons["jobs.row.jobs-output"].exists)
        section.tap()
        XCTAssertTrue(app.buttons["jobs.row.jobs-output"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3分3秒"].exists, "Elapsed time comes from the producer timestamps")
        XCTAssertTrue(app.staticTexts["exit code: 0"].firstMatch.exists)
        XCTAssertFalse(app.buttons["jobs.row.jobs-static"].exists, "A settled job with output.total=0 is not interactive")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "jobs-live-and-compact-settled"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testClearPersistsAfterCloseProtectsLiveAndAllowsLaterSettlements() {
        let app = launch()
        trigger(app).tap()
        app.buttons["jobs.settled.clear"].tap()
        XCTAssertEqual(trigger(app).label, "1 个后台任务运行中")
        XCTAssertFalse(app.buttons["jobs.settled.toggle"].exists)
        closePopover(app)
        trigger(app).tap()
        XCTAssertTrue(app.buttons["jobs.row.jobs-live"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["jobs.settled.toggle"].exists, "Closing must not resurrect the cleared tail")
        post("settle")
        waitForLabel(trigger(app), "1 个后台任务")
        XCTAssertTrue(app.buttons["jobs.settled.clear"].waitForExistence(timeout: 5))
        app.buttons["jobs.settled.clear"].tap()
        waitForAbsence(trigger(app))
        post("new")
        XCTAssertTrue(trigger(app).waitForExistence(timeout: 5))
        XCTAssertEqual(trigger(app).label, "1 个后台任务")
        trigger(app).tap()
        XCTAssertTrue(app.staticTexts["echo newly finished"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["jobs.row.jobs-output"].exists)
    }

    func testOutputFollowsRealFramesAndCollapsesWithoutChangingRoster() {
        let app = launch()
        trigger(app).tap()
        let live = app.buttons["jobs.row.jobs-live"]
        live.tap()
        XCTAssertTrue(output(app, "jobs-live").waitForExistence(timeout: 5))
        post("output")
        XCTAssertTrue(app.staticTexts["job-frame-first"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["job-frame-second"].exists)
        live.tap()
        waitForAbsence(output(app, "jobs-live"))
        XCTAssertEqual(trigger(app).label, "1 个后台任务运行中")
        app.buttons["jobs.settled.toggle"].tap()
        let retained = app.buttons["jobs.row.jobs-output"]
        retained.tap()
        post("output")
        XCTAssertTrue(output(app, "jobs-output").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["job-frame-first"].waitForExistence(timeout: 5))
        app.buttons["jobs.settled.clear"].tap()
        waitForAbsence(output(app, "jobs-output"))
        XCTAssertTrue(live.exists)
    }

    func testStopRequiresSecondPressExpiresAndShowsRealNoClientFailure() {
        let app = launch()
        trigger(app).tap()
        let stop = app.buttons["jobs.stop.jobs-live"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertEqual(stop.value as? String, "armed")
        XCTAssertTrue(app.staticTexts["确认停止"].exists)
        waitForValue(stop, "idle", timeout: 5)
        stop.tap()
        stop.tap()
        waitForValue(stop, "failed", timeout: 5)
        XCTAssertEqual(stop.label, "停止失败")
        waitForValue(stop, "idle", timeout: 6)
        XCTAssertEqual(trigger(app).label, "1 个后台任务运行中", "A rejected kill must not invent a settlement")
    }

    func testStoppingRetainsLiveCountAndSettlementOpensTailByDefault() {
        let app = launch()
        trigger(app).tap()
        post("stopping")
        waitForAbsence(app.buttons["jobs.stop.jobs-live"])
        XCTAssertTrue(app.buttons["jobs.row.jobs-live"].exists)
        XCTAssertEqual(trigger(app).label, "1 个后台任务运行中")
        post("settle")
        waitForLabel(trigger(app), "3 个后台任务")
        waitForValue(app.buttons["jobs.settled.toggle"], "expanded", timeout: 5)
        XCTAssertTrue(app.buttons["jobs.row.jobs-output"].exists)
        XCTAssertFalse(app.buttons["jobs.row.jobs-live"].exists, "The settled output.total=0 row becomes static")
    }

    func testSessionChangeResetsLocalClearFoldAndOutput() { assertScopeReset("session") }
    func testHostChangeResetsLocalClearFoldAndOutput() { assertScopeReset("host") }

    func testFullHostPanelKeepsJobsAndInlineOutput() {
        let app = launch(screen: "jobsHost")
        XCTAssertTrue(app.staticTexts["后台任务"].waitForExistence(timeout: 5))
        let live = app.buttons["jobs.row.jobs-live"]
        XCTAssertTrue(live.waitForExistence(timeout: 5))
        live.tap()
        post("output")
        XCTAssertTrue(app.staticTexts["job-frame-first"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["jobs.stop.jobs-live"].exists)
        app.buttons["jobs.settled.clear"].tap()
        XCTAssertTrue(live.exists)
    }

    private func assertScopeReset(_ action: String) {
        let app = launch()
        trigger(app).tap()
        app.buttons["jobs.settled.toggle"].tap()
        app.buttons["jobs.settled.clear"].tap()
        app.buttons["jobs.row.jobs-live"].tap()
        post("output")
        XCTAssertTrue(app.staticTexts["job-frame-first"].waitForExistence(timeout: 5))
        post(action)
        waitForAbsence(output(app, "jobs-live"))
        XCTAssertTrue(trigger(app).waitForExistence(timeout: 5))
        trigger(app).tap()
        let section = app.buttons["jobs.settled.toggle"]
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        XCTAssertEqual(section.value as? String, "collapsed", "An explicit fold choice must not cross scope")
        section.tap()
        XCTAssertTrue(app.buttons["jobs.row.jobs-output"].waitForExistence(timeout: 5), "Cleared ids must not cross scope")
        XCTAssertFalse(app.staticTexts["job-frame-first"].exists, "Prior scope output must not cross scope")
    }

    private func launch(screen: String = "jobsLifecycle") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestAppearanceLight", "-UITestScreen", screen]
        app.launch()
        if screen == "jobsLifecycle" { XCTAssertTrue(trigger(app).waitForExistence(timeout: 10)) }
        return app
    }

    private func trigger(_ app: XCUIApplication) -> XCUIElement { app.buttons["official.jobsChevron"].firstMatch }
    private func output(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)["jobs.output.\(id)"].firstMatch
    }
    private func closePopover(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        waitForAbsence(app.buttons["jobs.row.jobs-live"])
    }
    private func waitForAbsence(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }
    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
    private func post(_ action: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: "dev.dsh.uitest.jobsLifecycle.\(action)" as CFString),
            nil, nil, true
        )
    }
}
