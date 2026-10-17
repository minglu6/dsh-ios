import XCTest

/// Boots the app against `AppModel.installUITestFixture` and captures the
/// screens parent / CI compare to desktop `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`.
final class ScreenshotTests: XCTestCase {
    private let screens = [
        "landing", "drawer", "viewOptions", "sessionActions", "chat",
        "models", "permission", "start", "browser", "inspector",
        "settings", "schedule", "terminal",
    ]

    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testLightScreenshots() throws {
        try capture(appearance: "Light")
    }

    func testDarkScreenshots() throws {
        try capture(appearance: "Dark")
    }

    private func capture(appearance: String) throws {
        let root = try screenshotRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = [
                "-UITestFixture",
                "-UITestAppearance\(appearance)",
                "-UITestScreen", screen,
            ]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "\(appearance) \(screen) did not reach foreground")
            if screen == "viewOptions" {
                let button = app.buttons["viewOptionsButton"]
                XCTAssertTrue(button.waitForExistence(timeout: 15), "view options trigger missing")
                button.tap()
                XCTAssertTrue(app.descendants(matching: .any)["viewOptionsMenu"].waitForExistence(timeout: 8))
            }
            if screen == "sessionActions" {
                var row = app.descendants(matching: .any)["sessionRow.s-hello"]
                if !row.waitForExistence(timeout: 8) {
                    let open = app.buttons["openDrawer"]
                    if open.waitForExistence(timeout: 4) { open.tap() }
                }
                row = app.descendants(matching: .any)["sessionRow.s-hello"]
                XCTAssertTrue(row.waitForExistence(timeout: 15), "fixture session row missing")
                XCTAssertTrue(
                    waitAny(app, row, id: "sessionRowActions", timeout: 8)
                        || waitAny(app, row, id: "sessionRowPin", timeout: 2),
                    "session row action tray missing"
                )
                XCTAssertTrue(waitAny(app, row, id: "sessionRowPin", timeout: 4), "pin action missing")
                XCTAssertTrue(waitAny(app, row, id: "sessionRowArchive", timeout: 4), "archive action missing")
                XCTAssertTrue(waitAny(app, row, id: "sessionRowMore", timeout: 4), "more action missing")
            }
            if screen == "start" {
                XCTAssertTrue(app.descendants(matching: .any)["startPanel"].waitForExistence(timeout: 15))
            }
            if screen == "landing" || screen == "drawer" {
                XCTAssertFalse(app.images["folder.fill"].exists, "\(appearance) \(screen) still exposes SF folder.fill")
                XCTAssertFalse(app.images["folder"].exists, "\(appearance) \(screen) still exposes SF folder")
                let officialOpen = app.descendants(matching: .any)["official.folderOpen"]
                let officialClose = app.descendants(matching: .any)["official.folderClose"]
                XCTAssertTrue(
                    officialOpen.waitForExistence(timeout: 8) || officialClose.waitForExistence(timeout: 2),
                    "\(appearance) \(screen) missing official folder glyph"
                )
            }
            if screen == "models" {
                XCTAssertTrue(app.descendants(matching: .any)["modelChipEffort"].waitForExistence(timeout: 8), "\(appearance) model chip missing effort")
                XCTAssertTrue(app.descendants(matching: .any)["modelPickerEffort"].waitForExistence(timeout: 8), "\(appearance) model menu missing effort row")
            }
            let shot = XCUIScreen.main.screenshot()
            let url = root.appendingPathComponent("\(appearance.lowercased())-\(screen).png")
            try shot.pngRepresentation.write(to: url)
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = "\(appearance.lowercased())-\(screen)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    /// Parent `sessionRowActions` can stay missing on iOS 18 even with
    /// `.contain`; query the pin/archive/more children as the fallback.
    @discardableResult
    private func waitAny(_ app: XCUIApplication, _ row: XCUIElement, id: String, timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)[id].waitForExistence(timeout: timeout)
            || row.descendants(matching: .any)[id].waitForExistence(timeout: 1)
            || app.buttons[id].waitForExistence(timeout: 1)
    }

    private func screenshotRoot() throws -> URL {
        // CI exports DSH_SCREENSHOT_DIR / TEST_RUNNER_DSH_SCREENSHOT_DIR in the
        // shell before xcodebuild. Do not pass TEST_RUNNER_* as a build setting.
        guard let raw = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"], !raw.isEmpty else {
            throw ScreenshotExportError.missingDirectory
        }
        return URL(fileURLWithPath: raw, isDirectory: true)
    }
}

private enum ScreenshotExportError: Error, CustomStringConvertible {
    case missingDirectory

    var description: String {
        "DSH_SCREENSHOT_DIR is missing; pass TEST_RUNNER_DSH_SCREENSHOT_DIR to xcodebuild"
    }
}
