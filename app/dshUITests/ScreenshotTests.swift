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
        let root = screenshotRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = [
                "-UITestFixture",
                "-UITestAppearance\(appearance)",
                "-UITestScreen", screen,
            ]
            app.launch()
            if screen == "viewOptions" {
                let button = app.buttons["viewOptionsButton"]
                XCTAssertTrue(button.waitForExistence(timeout: 4), "view options trigger missing")
                button.tap()
                XCTAssertTrue(app.descendants(matching: .any)["viewOptionsMenu"].waitForExistence(timeout: 3))
            }
            if screen == "sessionActions" {
                XCTAssertTrue(app.descendants(matching: .any)["sessionRowActions"].waitForExistence(timeout: 4))
            }
            if screen == "start" {
                let open = app.buttons["openStartPanel"]
                if open.waitForExistence(timeout: 4) { open.tap() }
                XCTAssertTrue(app.descendants(matching: .any)["startPanel"].waitForExistence(timeout: 4))
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

    private func screenshotRoot() -> URL {
        if let raw = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"], !raw.isEmpty {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("screenshots", isDirectory: true)
    }
}
