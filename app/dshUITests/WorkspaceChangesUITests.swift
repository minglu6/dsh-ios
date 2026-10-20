import XCTest

final class WorkspaceChangesUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testChangesCardOpensComparisonAndSwitchesFileSemantics() {
        let app = launch("changesReview")
        let card = app.buttons["changesCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.staticTexts["-previousValue"].waitForExistence(timeout: 5))
        let replacement = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "+replacementValue")).firstMatch
        XCTAssertTrue(replacement.exists)
        XCTAssertLessThanOrEqual(replacement.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThan(replacement.frame.height, 30, "Long diff source must wrap vertically")

        selectFile(1, app: app)
        XCTAssertTrue(app.staticTexts["+new-file-content"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本轮新建的文件"].exists)
        XCTAssertFalse(app.staticTexts["-previousValue"].exists)

        selectFile(2, app: app)
        XCTAssertTrue(app.staticTexts["-deleted-file-content"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本轮删除的文件"].exists)
        XCTAssertFalse(app.staticTexts["+new-file-content"].exists)

        for (index, label) in [(3, "二进制文件，无法显示改动"), (4, "文件过大，无法显示改动"), (5, "两侧内容相同"), (6, "这轮改动的内容已不可用")] {
            selectFile(index, app: app)
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["-deleted-file-content"].exists)
        }
        XCTAssertTrue(app.buttons["changesDiffRetry"].exists)
        selectFile(0, app: app)
        XCTAssertTrue(app.staticTexts["-previousValue"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "workspace-changes-wrapped-diff"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSummaryAndDiffFailuresRemainVisibleAndRetryable() {
        let app = launch("changesRetry")
        let summaryRetry = app.buttons["changesSummaryRetry"]
        XCTAssertTrue(summaryRetry.waitForExistence(timeout: 10))
        summaryRetry.tap()
        let card = app.buttons["changesCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["-previousValue"].waitForExistence(timeout: 5))
        selectFile(1, app: app)
        let retry = app.buttons["changesDiffRetry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture: diff temporarily unavailable"].exists)
        XCTAssertFalse(app.staticTexts["-previousValue"].exists)
        retry.tap()
        XCTAssertTrue(app.staticTexts["+new-file-content"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Fixture: diff temporarily unavailable"].exists)
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", screen]
        app.launch()
        return app
    }

    private func selectFile(_ index: Int, app: XCUIApplication) {
        let picker = app.buttons["changesFilePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let file = app.buttons["changesFile:\(index)"]
        XCTAssertTrue(file.waitForExistence(timeout: 5))
        file.tap()
    }
}
