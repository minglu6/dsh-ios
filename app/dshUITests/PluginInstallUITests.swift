import XCTest

final class PluginInstallUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCenteredDialogValidatesInputAndCanCloseAndReopenInBothAppearances() {
        for appearance in ["Light", "Dark"] {
            let app = launch(appearance: appearance)
            let dialog = openDialog(app)
            XCTAssertFalse(app.sheets.firstMatch.exists)
            XCTAssertGreaterThan(dialog.frame.minX, app.frame.minX)
            XCTAssertLessThan(dialog.frame.maxX, app.frame.maxX)
            XCTAssertGreaterThan(dialog.frame.minY, app.frame.minY)
            XCTAssertLessThan(dialog.frame.maxY, app.frame.maxY)
            XCTAssertEqual(dialog.frame.midX, app.frame.midX, accuracy: 4)
            XCTAssertEqual(dialog.frame.midY, app.frame.midY, accuracy: app.frame.height * 0.1)
            attach(app, name: "plugin-install-\(appearance.lowercased())")

            let spec = app.textFields["pluginInstallSpec"]
            let run = app.buttons["pluginInstallRun"]
            XCTAssertTrue(spec.exists)
            assertEnabled(run, false)
            spec.tap()
            spec.typeText("   ")
            assertEnabled(run, false)
            spec.typeText("dsh-plugin-whale-pet")
            assertEnabled(run, true)
            XCTAssertEqual(spec.value as? String, "   dsh-plugin-whale-pet")
            XCTAssertTrue(app.buttons["pluginInstallClose"].isHittable)

            app.buttons["pluginInstallClose"].tap()
            assertAbsent(dialog)
            XCTAssertTrue(app.buttons["pluginAddButton"].isHittable)
            let reopened = openDialog(app)
            XCTAssertTrue(reopened.exists)
            XCTAssertFalse(app.sheets.firstMatch.exists)
            app.buttons["pluginInstallClose"].tap()
            assertAbsent(reopened)
            app.terminate()
        }
    }

    func testGuideFillsTheRealPackageExampleAndCollapsesWithoutClosingDialog() {
        let app = launch()
        let dialog = openDialog(app)
        let guide = element(app, "pluginInstallGuide")
        XCTAssertFalse(guide.exists)
        let spec = app.textFields["pluginInstallSpec"]
        spec.tap()
        spec.typeText("replace-this-package")

        app.buttons["pluginInstallGuideToggle"].tap()
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        let example = app.buttons["pluginInstallExample.0"]
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        example.tap()
        XCTAssertEqual(spec.value as? String, "dsh-plugin-whale-pet")
        assertEnabled(app.buttons["pluginInstallRun"], true)
        XCTAssertTrue(dialog.exists)
        attach(app, name: "plugin-install-guide")

        app.buttons["pluginInstallGuideToggle"].tap()
        assertAbsent(guide)
        XCTAssertEqual(spec.value as? String, "dsh-plugin-whale-pet")
        XCTAssertTrue(dialog.exists)
    }

    func testRegistrySelectionValidatesCustomURLAndDismissesOnlyItsPanel() {
        let app = launch()
        let dialog = openDialog(app)
        let spec = app.textFields["pluginInstallSpec"]
        spec.tap()
        spec.typeText("dsh-plugin-whale-pet")
        let run = app.buttons["pluginInstallRun"]
        assertEnabled(run, true)

        let toggle = app.buttons["pluginInstallRegistryToggle"]
        let panel = element(app, "pluginInstallRegistryPanel")
        toggle.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(dialog.exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        app.buttons["pluginInstallRegistryOption.custom"].tap()
        let custom = app.textFields["pluginInstallRegistryCustom"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        assertEnabled(run, false)
        custom.tap()
        let invalidURL = "file:///tmp/plugin-registry"
        custom.typeText(invalidURL)
        assertEnabled(run, false)
        custom.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: invalidURL.count))
        let registryURL = "https://registry.npmjs.org"
        custom.typeText(registryURL)
        assertEnabled(run, true)
        XCTAssertEqual(custom.value as? String, registryURL)
        attach(app, name: "plugin-install-registry")

        toggle.tap()
        assertAbsent(panel)
        XCTAssertTrue(dialog.exists)
        XCTAssertEqual(spec.value as? String, "dsh-plugin-whale-pet")
        toggle.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(custom.value as? String, registryURL)
        app.buttons["pluginInstallRegistryOption.default"].tap()
        assertEnabled(run, true)
        spec.tap()
        assertAbsent(panel)
        XCTAssertTrue(dialog.exists)
        XCTAssertTrue(app.buttons["pluginInstallClose"].isHittable)
        app.buttons["pluginInstallClose"].tap()
        assertAbsent(dialog)
    }

    private func launch(appearance: String = "Light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "plugins", "-UITestAppearance\(appearance)"]
        app.launch()
        XCTAssertTrue(app.buttons["pluginAddButton"].waitForExistence(timeout: 15))
        return app
    }

    @discardableResult
    private func openDialog(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["pluginAddButton"].tap()
        let dialog = element(app, "pluginInstallDialog")
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        return dialog
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func assertEnabled(_ element: XCUIElement, _ enabled: Bool) {
        XCTAssertTrue(element.exists)
        let expected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == %@", NSNumber(value: enabled)),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
    }

    private func assertAbsent(_ element: XCUIElement) {
        let absent = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [absent], timeout: 5), .completed)
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
