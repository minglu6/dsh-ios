import XCTest

final class ComposerStatsUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testCompactReadingsAreNotButtonsButContextOpensRealDetails() {
        let app = launch("statsCompact")
        XCTAssertTrue(element(app, "composerStats.activity").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["254 tok/s"].exists)
        XCTAssertFalse(app.buttons["composerStats.activity"].exists)
        XCTAssertFalse(app.buttons["composerStats.usage"].exists)
        app.staticTexts["254 tok/s"].tap()
        XCTAssertFalse(element(app, "composerStats.activityDialog").exists)
        element(app, "composerStats.usage").tap()
        XCTAssertFalse(element(app, "composerStats.usageDialog").exists)

        let context = app.buttons["composerStats.context"]
        XCTAssertTrue(context.isEnabled)
        context.tap()
        assertContext(app, anchor: context)
        dismissOutside(app, dialog: "composerStats.contextDialog")
    }

    func testDetailedPillsOpenAboveAnchorAndShowExclusiveSessionDetails() {
        let app = launch("statsDetailed")
        let activity = app.buttons["composerStats.activity"]
        XCTAssertTrue(activity.waitForExistence(timeout: 10))
        XCTAssertTrue(activity.isEnabled)
        activity.tap()
        let activityDialog = assertAbove(app, dialog: "composerStats.activityDialog", anchor: activity)
        XCTAssertTrue(activityDialog.staticTexts["模型用时"].exists)
        XCTAssertTrue(activityDialog.staticTexts["32.5秒"].exists)
        XCTAssertTrue(activityDialog.staticTexts["4.3秒"].exists)
        XCTAssertTrue(activityDialog.staticTexts["0.9秒"].exists)
        XCTAssertTrue(activityDialog.staticTexts["254 tok/s"].exists)

        let usage = app.buttons["composerStats.usage"]
        usage.tap()
        let usageDialog = assertAbove(app, dialog: "composerStats.usageDialog", anchor: usage)
        XCTAssertFalse(activityDialog.exists)
        XCTAssertTrue(usageDialog.staticTexts["500,806 tok"].exists)
        XCTAssertTrue(usageDialog.staticTexts["92%"].exists)
        XCTAssertTrue(usageDialog.staticTexts["38,903 tok"].exists)
        XCTAssertTrue(usageDialog.staticTexts["456,192 tok"].exists)
        XCTAssertTrue(usageDialog.staticTexts["5,711 tok"].exists)
        XCTAssertFalse(usageDialog.staticTexts["缓存写入"].exists)

        let context = app.buttons["composerStats.context"]
        context.tap()
        assertContext(app, anchor: context)
        XCTAssertFalse(usageDialog.exists)
        XCTAssertFalse(activityDialog.exists)
        dismissOutside(app, dialog: "composerStats.contextDialog")
        activity.tap()
        XCTAssertTrue(activityDialog.waitForExistence(timeout: 5))
        dismissOutside(app, dialog: "composerStats.activityDialog")
        usage.tap()
        XCTAssertTrue(usageDialog.waitForExistence(timeout: 5))
        dismissOutside(app, dialog: "composerStats.usageDialog")
    }

    func testDetailedActivityWithoutDecodeSpeedStillOpensTimingRows() {
        let app = launch("statsNoSpeed")
        let activity = app.buttons["composerStats.activity"]
        XCTAssertTrue(activity.waitForExistence(timeout: 10))
        XCTAssertTrue(activity.isEnabled)
        activity.tap()
        let dialog = assertAbove(app, dialog: "composerStats.activityDialog", anchor: activity)
        XCTAssertTrue(dialog.staticTexts["32.5秒"].exists)
        XCTAssertTrue(dialog.staticTexts["0.9秒"].exists)
        XCTAssertFalse(dialog.staticTexts["输出速度（TPS）"].exists)
    }

    func testUntimedActivityStaysPlainAndMissingMetricsDoNotCreateDialogs() {
        let untimed = launch("statsUntimed")
        let reading = element(untimed, "composerStats.activity")
        XCTAssertTrue(reading.waitForExistence(timeout: 10))
        XCTAssertFalse(untimed.buttons["composerStats.activity"].exists)
        reading.tap()
        XCTAssertFalse(element(untimed, "composerStats.activityDialog").exists)
        XCTAssertFalse(element(untimed, "composerStats.usage").exists)
        XCTAssertFalse(untimed.buttons["composerStats.context"].exists)
        untimed.terminate()

        let missing = launch("statsMissing")
        XCTAssertTrue(element(missing, "chatComposer").waitForExistence(timeout: 10))
        XCTAssertFalse(element(missing, "composerStats").exists)
        XCTAssertFalse(element(missing, "composerStats.activityDialog").exists)
        XCTAssertFalse(element(missing, "composerStats.usageDialog").exists)
        XCTAssertFalse(element(missing, "composerStats.contextDialog").exists)
    }

    func testUsageKeepsOutputOnlyAndOptionalCacheWriteBoundaries() {
        let outputOnly = launch("statsOutputOnly")
        let outputUsage = outputOnly.buttons["composerStats.usage"]
        XCTAssertTrue(outputUsage.waitForExistence(timeout: 10))
        outputUsage.tap()
        let outputDialog = assertAbove(outputOnly, dialog: "composerStats.usageDialog", anchor: outputUsage)
        XCTAssertTrue(outputDialog.staticTexts["输出"].exists)
        XCTAssertTrue(outputDialog.staticTexts["500 tok"].firstMatch.exists)
        XCTAssertFalse(outputDialog.staticTexts["缓存命中"].exists)
        XCTAssertFalse(outputDialog.staticTexts["缓存写入"].exists)
        outputOnly.terminate()

        let cacheWrite = launch("statsCacheWrite")
        let writeUsage = cacheWrite.buttons["composerStats.usage"]
        XCTAssertTrue(writeUsage.waitForExistence(timeout: 10))
        writeUsage.tap()
        let writeDialog = assertAbove(cacheWrite, dialog: "composerStats.usageDialog", anchor: writeUsage)
        XCTAssertTrue(writeDialog.staticTexts["缓存写入"].exists)
        XCTAssertTrue(writeDialog.staticTexts["1,300 tok"].exists)
    }

    func testRealSettingsSwitchChangesReadingAndButtonSemantics() {
        let app = launch("statsCompact")
        XCTAssertTrue(element(app, "composerStats.activity").waitForExistence(timeout: 10))
        changePerformance(app, to: "详细")
        let activity = app.buttons["composerStats.activity"]
        XCTAssertTrue(activity.waitForExistence(timeout: 5))
        activity.tap()
        XCTAssertTrue(element(app, "composerStats.activityDialog").waitForExistence(timeout: 5))
        dismissOutside(app, dialog: "composerStats.activityDialog")

        changePerformance(app, to: "简洁")
        XCTAssertTrue(app.staticTexts["254 tok/s"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["composerStats.activity"].exists)
        XCTAssertFalse(app.buttons["composerStats.usage"].exists)
        XCTAssertTrue(app.buttons["composerStats.context"].isEnabled)
        XCTAssertFalse(element(app, "composerStats.activityDialog").exists)
    }

    private func launch(_ screen: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", screen]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @discardableResult
    private func assertAbove(_ app: XCUIApplication, dialog: String, anchor: XCUIElement) -> XCUIElement {
        let panel = element(app, dialog)
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertLessThanOrEqual(panel.frame.maxY, anchor.frame.minY)
        XCTAssertGreaterThanOrEqual(panel.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(panel.frame.maxX, app.frame.maxX)
        capture(app, suffix: dialog)
        return panel
    }

    private func assertContext(_ app: XCUIApplication, anchor: XCUIElement) {
        let dialog = assertAbove(app, dialog: "composerStats.contextDialog", anchor: anchor)
        XCTAssertTrue(dialog.staticTexts["~54.7K / 1M"].exists)
        XCTAssertTrue(dialog.staticTexts["~1K"].exists)
        XCTAssertTrue(dialog.staticTexts["~15K"].exists)
        XCTAssertTrue(dialog.staticTexts["~38.7K"].exists)
    }

    private func capture(_ app: XCUIApplication, suffix: String) {
        let screenshot = app.screenshot()
        let filename = "\(suffix)-\(name.filter { $0.isLetter || $0.isNumber })"
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)
        if let root = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"] {
            do {
                let directory = URL(fileURLWithPath: root, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(filename).png"))
            } catch {
                XCTFail("Could not save statistics screenshot: \(error)")
            }
        }
    }

    private func dismissOutside(_ app: XCUIApplication, dialog: String) {
        let panel = element(app, dialog)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)
        waitForExpectations(timeout: 5)
    }

    private func changePerformance(_ app: XCUIApplication, to mode: String) {
        element(app, "openDrawer").tap()
        let settings = element(app, "drawerSettingsRow")
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let general = element(app, "settingsNavRow.general")
        XCTAssertTrue(general.waitForExistence(timeout: 5))
        general.tap()
        let preference = app.staticTexts["性能与用量"]
        for _ in 0..<8 {
            if preference.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(preference.isHittable)
        preference.tap()
        let option = app.buttons[mode]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["取消"])
        waitForExpectations(timeout: 5)
        element(app, "navBack").tap()
        XCTAssertTrue(element(app, "settingsShell").waitForExistence(timeout: 5))
        element(app, "navBack").tap()
    }
}
