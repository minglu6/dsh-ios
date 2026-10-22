import XCTest

final class ModelsSettingsUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSaveReadsBackRenamedProviderAndPreservesUneditedFields() {
        let app = launch()
        open("alpha", in: app)
        showCustomSettings(in: app)
        replace("models.displayName", with: "Alpha Renamed", in: app)
        replace("models.baseURL", with: "https://renamed.example/v1", in: app)
        replace("models.apiKey", with: "synthetic-renamed-key", in: app)
        tap("models.save", in: app)

        waitForStatus(app, containing: "settingsWrites=1;credentialWrites=1;failures=0;contractErrors=0;")
        waitForStatus(app, containing: "readbacks=1;lastRead=alpha;")
        waitForStatus(app, containing: "preserved=true")
        let notice = element(app, "models.savedNotice")
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(notice.label.contains("Alpha Renamed"), "Success notice must use the name read back from the Host")
        XCTAssertFalse(element(app, "models.save").exists, "Successful save must close the editor")

        open("alpha", in: app)
        showCustomSettings(in: app)
        assertValue("models.displayName", equals: "Alpha Renamed", in: app)
        assertValue("models.baseURL", equals: "https://renamed.example/v1", in: app)
        XCTAssertFalse((element(app, "models.apiKey").value as? String ?? "").contains("synthetic-renamed-key"), "Host credentials must never be sent back to the form")
        assertCleanContract(app)
        capture(app, name: "models-save-readback")
    }

    func testFailedSaveRetainsAllDraftsAndRetrySucceeds() {
        let app = launch(failFirst: true)
        open("alpha", in: app)
        showCustomSettings(in: app)
        replace("models.displayName", with: "Retained Draft", in: app)
        replace("models.baseURL", with: "https://retained.example/v1", in: app)
        replace("models.apiKey", with: "synthetic-retained-key", in: app)
        let keyValue = element(app, "models.apiKey").value as? String
        tap("models.save", in: app)

        waitForStatus(app, containing: "settingsWrites=0;credentialWrites=0;failures=1;contractErrors=0;")
        XCTAssertTrue(element(app, "models.error").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "models.save").exists)
        XCTAssertFalse(element(app, "models.savedNotice").exists)
        assertValue("models.displayName", equals: "Retained Draft", in: app)
        assertValue("models.baseURL", equals: "https://retained.example/v1", in: app)
        XCTAssertEqual(element(app, "models.apiKey").value as? String, keyValue)
        capture(app, name: "models-save-failure-retains-draft")

        tap("models.save", in: app)
        waitForStatus(app, containing: "settingsWrites=1;credentialWrites=1;failures=1;contractErrors=0;")
        waitForStatus(app, containing: "readbacks=1;lastRead=alpha;")
        XCTAssertTrue(element(app, "models.savedNotice").waitForExistence(timeout: 10))
        open("alpha", in: app)
        showCustomSettings(in: app)
        assertValue("models.displayName", equals: "Retained Draft", in: app)
        assertCleanContract(app)
    }

    func testCancelDoesNotWriteSettingsOrCredentials() {
        let app = launch()
        open("alpha", in: app)
        showCustomSettings(in: app)
        replace("models.displayName", with: "Must Not Persist", in: app)
        replace("models.baseURL", with: "https://cancelled.example/v1", in: app)
        replace("models.apiKey", with: "synthetic-cancelled-key", in: app)
        tap("models.cancel", in: app)
        XCTAssertFalse(element(app, "models.save").exists)
        XCTAssertFalse(element(app, "models.savedNotice").exists)
        open("alpha", in: app)
        showCustomSettings(in: app)
        assertValue("models.displayName", equals: "Alpha", in: app)
        assertValue("models.baseURL", equals: "https://alpha.example/v1", in: app)
        waitForStatus(app, containing: "settingsWrites=0;credentialWrites=0;failures=0;contractErrors=0;")
    }

    func testSwitchingProviderCannotCarryAnotherProvidersDraft() {
        let app = launch()
        open("alpha", in: app)
        showCustomSettings(in: app)
        replace("models.displayName", with: "Alpha Unsaved", in: app)
        replace("models.baseURL", with: "https://alpha-unsaved.example/v1", in: app)
        replace("models.apiKey", with: "synthetic-alpha-unsaved", in: app)
        let alphaKey = element(app, "models.apiKey").value as? String

        open("beta", in: app)
        showCustomSettings(in: app)
        assertValue("models.displayName", equals: "Beta", in: app)
        assertValue("models.baseURL", equals: "https://beta.example/v1", in: app)
        XCTAssertNotEqual(element(app, "models.apiKey").value as? String, alphaKey)
        replace("models.displayName", with: "Beta Renamed", in: app)
        tap("models.save", in: app)
        waitForStatus(app, containing: "settingsWrites=1;credentialWrites=0;failures=0;contractErrors=0;")
        XCTAssertTrue(element(app, "models.savedNotice").waitForExistence(timeout: 10))
        open("alpha", in: app)
        showCustomSettings(in: app)
        assertValue("models.displayName", equals: "Alpha", in: app)
        assertValue("models.baseURL", equals: "https://alpha.example/v1", in: app)
        assertCleanContract(app)
    }

    func testAddCatalogAndCustomModesPreserveSeparateDrafts() {
        let app = launch()
        tap("models.add", in: app)
        let modes = app.segmentedControls["models.add.mode"]
        XCTAssertTrue(modes.waitForExistence(timeout: 10))
        selectCatalog("openai", in: app)
        replace("models.apiKey", with: "synthetic-catalog-draft", in: app)
        let catalogKey = element(app, "models.apiKey").value as? String
        XCTAssertNotNil(catalogKey)

        reveal(modes, in: app, towardTop: true)
        modes.buttons.element(boundBy: 1).tap()
        replace("models.add.route", with: "custom-gateway", in: app)
        replace("models.displayName", with: "Custom Draft", in: app)
        replace("models.baseURL", with: "https://custom-draft.example/v1", in: app)
        replace("models.apiKey", with: "synthetic-custom-draft-longer", in: app)
        let customKey = element(app, "models.apiKey").value as? String

        reveal(modes, in: app, towardTop: true)
        modes.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "models.add.catalog").waitForExistence(timeout: 10))
        XCTAssertEqual(element(app, "models.apiKey").value as? String, catalogKey, "Catalog key must survive switching through custom mode")
        reveal(modes, in: app, towardTop: true)
        modes.buttons.element(boundBy: 1).tap()
        assertValue("models.add.route", equals: "custom-gateway", in: app)
        assertValue("models.displayName", equals: "Custom Draft", in: app)
        assertValue("models.baseURL", equals: "https://custom-draft.example/v1", in: app)
        XCTAssertEqual(element(app, "models.apiKey").value as? String, customKey, "Custom credentials must remain separate from catalog credentials")
        waitForStatus(app, containing: "settingsWrites=0;credentialWrites=0;failures=0;contractErrors=0;")
        capture(app, name: "models-add-preserved-custom-draft")
        tap("models.cancel", in: app)
        XCTAssertFalse(element(app, "models.add.route").exists)
        assertCleanContract(app)
    }

    func testModelEditsPersistAndInvalidCapacityBlocksSave() {
        let app = launch()
        open("alpha", in: app)
        showCustomSettings(in: app)
        replace("providerModels.row.0.id", with: "alpha-renamed-model", in: app)
        replace("providerModels.row.0.name", with: "Renamed Model", in: app)
        tap("providerModels.row.0.options", in: app)
        replace("providerModels.row.0.contextWindow", with: "invalid", in: app)
        XCTAssertFalse(element(app, "models.save").isEnabled)
        replace("providerModels.row.0.contextWindow", with: "256K", in: app)
        tap("models.save", in: app)
        XCTAssertTrue(element(app, "models.savedNotice").waitForExistence(timeout: 10))
        open("alpha", in: app)
        showCustomSettings(in: app)
        assertValue("providerModels.row.0.id", equals: "alpha-renamed-model", in: app)
        assertValue("providerModels.row.0.name", equals: "Renamed Model", in: app)
        tap("providerModels.row.0.options", in: app)
        assertValue("providerModels.row.0.contextWindow", equals: "256K", in: app)
        assertCleanContract(app)
    }

    func testDiscoveryRequiresExplicitAdoptionAndKeepsExistingModelEdits() {
        let app = launch()
        open("alpha", in: app)
        showCustomSettings(in: app)
        replace("providerModels.row.0.name", with: "My Model Name", in: app)
        tap("providerModels.discover", in: app)
        XCTAssertTrue(element(app, "providerModels.picker").waitForExistence(timeout: 10))
        tap("providerModels.picker.candidate.alpha-chat", in: app)
        tap("providerModels.picker.adopt", in: app)
        assertValue("providerModels.row.0.name", equals: "My Model Name", in: app)
        XCTAssertFalse(element(app, "providerModels.row.1.id").exists)
        waitForStatus(app, containing: "settingsWrites=0;credentialWrites=0;")
        tap("models.save", in: app)
        XCTAssertTrue(element(app, "models.savedNotice").waitForExistence(timeout: 10))
        open("alpha", in: app)
        showCustomSettings(in: app)
        assertValue("providerModels.row.0.name", equals: "My Model Name", in: app)
    }

    private func launch(failFirst: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "modelsSettings"]
        if failFirst { app.launchArguments.append("-UITestModelsFailFirst") }
        app.launch()
        XCTAssertTrue(element(app, "models.edit.alpha").waitForExistence(timeout: 15))
        waitForStatus(app, containing: "contractErrors=0;")
        return app
    }

    private func open(_ route: String, in app: XCUIApplication) {
        tap("models.edit.\(route)", in: app, towardTop: true)
        XCTAssertTrue(element(app, "models.cancel").waitForExistence(timeout: 10))
        waitForStatus(app, containing: "lastRead=\(route);")
    }

    private func showCustomSettings(in app: XCUIApplication) {
        if !element(app, "models.displayName").exists {
            tap("models.customSettings", in: app)
        }
        XCTAssertTrue(element(app, "models.displayName").waitForExistence(timeout: 5))
    }

    private func selectCatalog(_ route: String, in app: XCUIApplication) {
        tap("models.add.catalog", in: app)
        let option = element(app, "models.add.catalog.\(route)")
        if option.waitForExistence(timeout: 2) { option.tap() }
        else {
            let label = route == "openai" ? "Openai" : "Anthropic"
            let button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            button.tap()
        }
        waitForStatus(app, containing: "lastRead=\(route);")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, in app: XCUIApplication, towardTop: Bool = false) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing control: \(id)")
        reveal(target, in: app, towardTop: towardTop)
        XCTAssertTrue(target.isHittable, "Control cannot be reached: \(id)")
        target.tap()
    }

    private func replace(_ id: String, with text: String, in app: XCUIApplication) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing field: \(id)")
        reveal(target, in: app)
        target.tap()
        // A select-all gesture clears secure and ordinary text fields without
        // confusing placeholders with actual contents.
        target.press(forDuration: 1.1)
        let selectAll = app.menuItems.matching(NSPredicate(format: "label IN %@", ["全选", "Select All"])).firstMatch
        if selectAll.waitForExistence(timeout: 1) {
            selectAll.tap()
            target.typeText(text)
        } else {
            let existing = target.value as? String ?? ""
            target.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count + 80) + text)
        }
    }

    private func assertValue(_ id: String, equals value: String, in app: XCUIApplication) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.value as? String, value, "Unexpected draft in \(id)")
    }

    private func reveal(_ target: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<8 {
            if target.isHittable { return }
            if towardTop { app.swipeDown() } else { app.swipeUp() }
        }
        for _ in 0..<8 {
            if target.isHittable { return }
            if towardTop { app.swipeUp() } else { app.swipeDown() }
        }
    }

    private func waitForStatus(_ app: XCUIApplication, containing text: String) {
        let status = element(app, "models.fixtureStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (status.value as? String ?? status.label).contains(text)
        }, object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, "Expected \(text), got \(status.value ?? status.label)")
    }

    private func assertCleanContract(_ app: XCUIApplication) {
        waitForStatus(app, containing: "contractErrors=0;")
        waitForStatus(app, containing: "preserved=true")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
