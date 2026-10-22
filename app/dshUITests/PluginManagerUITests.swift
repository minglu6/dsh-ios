import XCTest

final class PluginManagerUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHeaderAvoidsUnnecessaryWrappingAndKeepsNativeAddActionReachable() {
        let app = launch()
        let title = app.staticTexts["pluginPageTitle"]
        let add = app.buttons["pluginAddButton"]
        let basic = element(app, "pluginGroup.basic")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(add.isHittable)
        XCTAssertFalse(element(app, "hostUiEntry.plugins").exists)
        if app.windows.firstMatch.frame.width >= 390 {
            XCTAssertEqual(title.frame.midY, add.frame.midY, accuracy: 4)
            XCTAssertLessThanOrEqual(basic.frame.minY - add.frame.maxY, 56)
        } else {
            XCTAssertGreaterThan(add.frame.minY, title.frame.maxY)
        }
        add.tap()
        let dialog = element(app, "pluginInstallDialog")
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        app.buttons["pluginInstallClose"].tap()
        assertAbsent(dialog)
        XCTAssertTrue(add.isHittable)
        attach(app, name: "plugin-manager-native-header")
    }

    func testModelsHasNoCustomPluginWebEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "settingsShell", "-UITestAppearanceLight"]
        app.launch()
        let models = element(app, "settingsNavRow.models")
        XCTAssertTrue(models.waitForExistence(timeout: 15))
        models.tap()
        XCTAssertTrue(element(app, "modelsSettings").waitForExistence(timeout: 15))
        XCTAssertFalse(element(app, "hostUiEntry.models").exists)
    }

    func testMainGroupsExcludeHeldBackPackageAndMoreShowsIt() {
        let app = launch()
        for group in ["basic", "extensions", "bundles"] {
            reveal(element(app, "pluginGroup.\(group)"), in: app)
        }
        reveal(package(app, "@deepseek-ai/dsh-experimental-agent-team-profile"), in: app)
        reveal(package(app, "dsh-plugin-example"), in: app)
        XCTAssertFalse(package(app, "@deepseek-ai/dsh-experimental-cot-translation-bundle").exists)
        attach(app, name: "plugin-manager-main")

        openMore(app)
        reveal(package(app, "@deepseek-ai/dsh-experimental-cot-translation-bundle"), in: app)
        XCTAssertTrue(app.buttons["pluginMoreBack"].isHittable)
        XCTAssertFalse(element(app, "pluginGroup.basic").exists)
        attach(app, name: "plugin-manager-more")
        app.buttons["pluginMoreBack"].tap()
        XCTAssertTrue(element(app, "pluginGroup.basic").waitForExistence(timeout: 5))
        XCTAssertFalse(package(app, "@deepseek-ai/dsh-experimental-cot-translation-bundle").exists)
    }

    func testMainPackageDetailReturnsToMainList() {
        let app = launch()
        openPackage(app, "@deepseek-ai/dsh-experimental-agent-team-profile")
        XCTAssertTrue(app.staticTexts["智能体团队"].firstMatch.exists)
        XCTAssertTrue(element(app, "pluginDetailToggle").isEnabled)
        XCTAssertFalse(element(app, "pluginGroup.basic").exists)

        app.buttons["pluginDetailBack"].tap()
        assertAbsent(element(app, "pluginPackageDetail"))
        XCTAssertTrue(element(app, "pluginGroup.basic").exists)
        XCTAssertTrue(element(app, "pluginGroup.extensions").exists)
        XCTAssertTrue(element(app, "pluginGroup.bundles").exists)
        reveal(package(app, "@deepseek-ai/dsh-experimental-agent-team-profile"), in: app)
        XCTAssertFalse(app.buttons["pluginMoreBack"].exists)
    }

    func testHeldBackPackageDetailReturnsToMoreBeforeMain() {
        let app = launch()
        openMore(app)
        openPackage(app, "@deepseek-ai/dsh-experimental-cot-translation-bundle")
        XCTAssertTrue(app.staticTexts["思考翻译"].firstMatch.exists)
        app.buttons["pluginDetailBack"].tap()

        assertAbsent(element(app, "pluginPackageDetail"))
        XCTAssertTrue(app.buttons["pluginMoreBack"].waitForExistence(timeout: 5))
        reveal(package(app, "@deepseek-ai/dsh-experimental-cot-translation-bundle"), in: app)
        XCTAssertFalse(element(app, "pluginGroup.basic").exists)
        app.buttons["pluginMoreBack"].tap()
        XCTAssertTrue(element(app, "pluginGroup.basic").waitForExistence(timeout: 5))
        XCTAssertFalse(package(app, "@deepseek-ai/dsh-experimental-cot-translation-bundle").exists)
    }

    func testInstalledPackageShowsSourceVersionAndAddressableComponents() {
        let app = launch()
        openPackage(app, "dsh-plugin-example")
        reveal(element(app, "pluginComponents"), in: app)
        XCTAssertTrue(app.staticTexts["示例组件"].exists)
        XCTAssertTrue(app.staticTexts["示例主题"].exists)

        let liveToggle = element(app, "pluginRowToggle.include:example-main")
        reveal(liveToggle, in: app)
        XCTAssertTrue(liveToggle.isEnabled)
        let unavailableToggle = element(app, "pluginRowToggle.example-theme")
        reveal(unavailableToggle, in: app)
        XCTAssertFalse(unavailableToggle.isEnabled)
        XCTAssertTrue(app.buttons["pluginConfigure.example-main"].exists)

        reveal(element(app, "pluginSource"), in: app)
        let source = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "dsh-plugin-example@^1.2.0")).firstMatch
        let version = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "1.2.3")).firstMatch
        XCTAssertTrue(source.exists)
        XCTAssertTrue(version.exists)
        XCTAssertTrue(app.buttons["pluginDetailUninstall"].exists)
        attach(app, name: "plugin-manager-installed-detail")
        app.buttons["pluginDetailBack"].tap()
        assertAbsent(element(app, "pluginPackageDetail"))
        reveal(package(app, "dsh-plugin-example"), in: app)
    }

    func testBuiltinConfigurationOpensAndReturnsWithoutSaving() {
        let app = launch()
        let items = [
            ("subagent", "subagent.maxDepth"),
            ("web-search", "web-search-deepseek.baseURL"),
            ("agent-loop", "agent-loop.maxParallelToolCalls"),
            ("shell", "bash-sandbox.timeoutMs"),
        ]
        for (id, field) in items {
            let entry = app.buttons["pluginBuiltin.\(id)"]
            reveal(entry, in: app)
            entry.tap()
            let configuration = element(app, "pluginBuiltinConfiguration")
            XCTAssertTrue(configuration.waitForExistence(timeout: 5))
            reveal(element(app, "pluginBuiltinField.\(field)"), in: app)
            XCTAssertFalse(element(app, "pluginGroup.basic").exists)
            XCTAssertTrue(app.buttons["pluginBuiltinBack"].isHittable)
            attach(app, name: "plugin-manager-builtin-\(id)")
            app.buttons["pluginBuiltinBack"].tap()
            assertAbsent(configuration)
            XCTAssertTrue(element(app, "pluginGroup.basic").exists)
            reveal(entry, in: app)
        }
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "plugins", "-UITestAppearanceLight"]
        app.launch()
        XCTAssertTrue(app.buttons["pluginAddButton"].waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "pluginGroup.basic").waitForExistence(timeout: 5))
        return app
    }

    private func openMore(_ app: XCUIApplication) {
        let more = app.buttons["pluginMore"]
        reveal(more, in: app)
        more.tap()
        XCTAssertTrue(app.buttons["pluginMoreBack"].waitForExistence(timeout: 5))
    }

    private func openPackage(_ app: XCUIApplication, _ name: String) {
        let entry = package(app, name)
        reveal(entry, in: app)
        entry.tap()
        XCTAssertTrue(element(app, "pluginPackageDetail").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pluginDetailBack"].isHittable)
    }

    private func package(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons["pluginPackage.\(name)"]
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func reveal(_ target: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<8 {
            if target.exists && target.isHittable { return }
            scroll.swipeUp()
        }
        for _ in 0..<8 {
            if target.exists && target.isHittable { return }
            scroll.swipeDown()
        }
        XCTAssertTrue(target.exists, "Missing UI element: \(target)")
        XCTAssertTrue(target.isHittable, "UI element cannot be reached: \(target)")
    }

    private func assertAbsent(_ target: XCUIElement) {
        let absent = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [absent], timeout: 5), .completed)
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
