import XCTest

/// Boots the app against `AppModel.installUITestFixture` and captures the
/// screens parent / CI compare to desktop `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`.
final class ScreenshotTests: XCTestCase {
    private let screens = [
        "landing", "drawer", "viewOptions", "sessionActions", "chat",
        "models", "permission", "start", "browser", "inspector",
        "settings", "schedule", "terminal", "trajectory", "plugins",
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
                XCTAssertFalse(app.images["slider.horizontal.3"].exists, "\(appearance) view options still exposes SF slider")
                XCTAssertFalse(app.images["list.bullet"].exists, "\(appearance) view options still exposes SF list.bullet")
                XCTAssertFalse(app.images["arrow.up.arrow.down"].exists, "\(appearance) view options still exposes SF arrows")
                XCTAssertFalse(app.images["clock"].exists, "\(appearance) view options still exposes SF clock")
                XCTAssertFalse(app.images["archivebox"].exists, "\(appearance) view options still exposes SF archivebox")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.workspaceTree"].waitForExistence(timeout: 8),
                    "\(appearance) view options missing official workspaceTree"
                )
                XCTAssertTrue(app.descendants(matching: .any)["official.flatList"].exists, "\(appearance) view options missing official flatList")
                XCTAssertTrue(app.descendants(matching: .any)["official.chevronsUpDown"].exists, "\(appearance) view options missing official chevrons")
                XCTAssertTrue(app.descendants(matching: .any)["official.clockOutline"].exists, "\(appearance) view options missing official clockOutline")
                XCTAssertTrue(app.descendants(matching: .any)["official.archiveOff"].exists, "\(appearance) view options missing official archiveOff")
                XCTAssertTrue(app.descendants(matching: .any)["official.queue"].exists, "\(appearance) view options missing official queue")
                XCTAssertTrue(app.descendants(matching: .any)["official.archiveCheck"].exists, "\(appearance) view options missing official archiveCheck")
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
            if screen == "drawer" {
                XCTAssertFalse(app.images["gearshape"].exists, "\(appearance) drawer still exposes SF gearshape")
                XCTAssertFalse(app.images["gearshape.fill"].exists, "\(appearance) drawer still exposes SF gearshape.fill")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.settingsOutline"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing official settings glyph"
                )
                XCTAssertFalse(app.images["square.and.pencil"].exists, "\(appearance) drawer still exposes SF square.and.pencil")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.newChat"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing official new-chat glyph"
                )
                XCTAssertFalse(app.images["magnifyingglass"].exists, "\(appearance) drawer still exposes SF magnifyingglass")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.searchOutline"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing official search glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.projectAdd"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing official project-add glyph"
                )
                // The trigger Button owns `viewOptionsButton`, which replaces the
                // inner OfficialGlyph id; assert the button and forbid SF slider.
                XCTAssertTrue(
                    app.buttons["viewOptionsButton"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing view-options trigger"
                )
                XCTAssertFalse(
                    app.images["slider.horizontal.3"].exists,
                    "\(appearance) drawer view-options trigger still SF slider"
                )
                let settingsHit = app.descendants(matching: .any)["drawerSettingsRow"]
                let hostHit = app.descendants(matching: .any)["drawerPeerDeviceRow"]
                XCTAssertTrue(settingsHit.waitForExistence(timeout: 8), "\(appearance) drawer settings hit missing")
                XCTAssertTrue(hostHit.waitForExistence(timeout: 8), "\(appearance) drawer host hit missing")
                XCTAssertTrue(
                    hostHit.label.contains("Mac mini")
                        || app.descendants(matching: .any)["drawerPeerDeviceName"].waitForExistence(timeout: 2)
                        || app.staticTexts["Mac mini"].waitForExistence(timeout: 2),
                    "\(appearance) drawer missing remote host name"
                )
                let settingsFrame = settingsHit.frame
                let hostFrame = hostHit.frame
                XCTAssertFalse(
                    settingsFrame.intersects(hostFrame),
                    "\(appearance) drawer settings/host hits overlap \(settingsFrame) \(hostFrame)"
                )
                XCTAssertGreaterThanOrEqual(
                    hostFrame.minX - settingsFrame.maxX,
                    16,
                    "\(appearance) drawer footer hits closer than 16pt"
                )
                XCTAssertGreaterThanOrEqual(settingsFrame.height, 44, "\(appearance) settings hit shorter than 44pt")
                XCTAssertGreaterThanOrEqual(hostFrame.height, 44, "\(appearance) host hit shorter than 44pt")
            }
            if screen == "landing" || screen == "chat" {
                XCTAssertFalse(app.images["plus"].exists, "\(appearance) \(screen) still exposes SF plus")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.plusOutline"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official composer plus glyph"
                )
                XCTAssertFalse(app.images["arrow.up"].exists, "\(appearance) \(screen) still exposes SF arrow.up")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.send"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official composer send glyph"
                )
                XCTAssertFalse(
                    app.images["square.and.arrow.up"].exists,
                    "\(appearance) \(screen) still exposes extra SF share"
                )
                XCTAssertFalse(
                    app.buttons["sessionShare"].exists,
                    "\(appearance) \(screen) still exposes extra header share"
                )
                XCTAssertFalse(
                    app.descendants(matching: .any)["sessionShare"].exists,
                    "\(appearance) \(screen) still exposes sessionShare"
                )
                XCTAssertFalse(
                    app.descendants(matching: .any)["userMessageCopy"].exists,
                    "\(appearance) \(screen) still exposes a user-bubble copy control"
                )
            }
            if screen == "chat" {
                // Fixture: one user bubble + one assistant reply. Only the
                // assistant MessageIconActions row may carry copy.
                let copyButtons = app.buttons.matching(
                    NSPredicate(format: "label == '复制' OR label == 'Copy'")
                ).count
                XCTAssertLessThanOrEqual(
                    copyButtons,
                    1,
                    "\(appearance) chat exposes \(copyButtons) copy buttons (user bubble copy is back)"
                )
                XCTAssertFalse(app.images["gauge.with.dots.needle.67percent"].exists, "\(appearance) chat still exposes SF gauge")
                XCTAssertFalse(app.images["cylinder"].exists, "\(appearance) chat still exposes SF cylinder")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.gaugeOutline"].waitForExistence(timeout: 8),
                    "\(appearance) chat missing official activity gauge glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.databaseOutline"].waitForExistence(timeout: 8),
                    "\(appearance) chat missing official usage database glyph"
                )
                XCTAssertTrue(
                    app.staticTexts["缓存命中 69%"].waitForExistence(timeout: 8),
                    "\(appearance) chat missing cache-hit pill copy"
                )
                XCTAssertFalse(app.staticTexts["缓存命中中 69%"].exists, "\(appearance) chat has extra 中 in cache-hit copy")
            }
            if screen == "plugins" {
                let info = app.buttons["pluginInfoButton"]
                XCTAssertTrue(info.waitForExistence(timeout: 15), "\(appearance) plugins missing (i)")
                XCTAssertFalse(app.images["info.circle"].exists, "\(appearance) plugins still exposes SF info.circle")
                XCTAssertFalse(app.images["arrow.clockwise"].exists, "\(appearance) plugins still exposes SF arrow.clockwise")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.infoOutline"].waitForExistence(timeout: 8),
                    "\(appearance) plugins missing official info glyph"
                )
                info.tap()
                let tip = app.descendants(matching: .any)["pluginInfoTooltip"]
                XCTAssertTrue(tip.waitForExistence(timeout: 8), "\(appearance) plugins tooltip missing")
                let window = app.windows.firstMatch.frame
                let tipFrame = tip.frame
                XCTAssertGreaterThanOrEqual(tipFrame.minX, window.minX, "\(appearance) tooltip clipped left")
                XCTAssertLessThanOrEqual(tipFrame.maxX, window.maxX, "\(appearance) tooltip clipped right")
                XCTAssertGreaterThanOrEqual(tipFrame.minY, window.minY, "\(appearance) tooltip clipped top")
                XCTAssertLessThanOrEqual(tipFrame.maxY, window.maxY, "\(appearance) tooltip clipped bottom")
            }
            if screen == "landing" {
                let composer = app.descendants(matching: .any)["landingComposer"]
                XCTAssertTrue(
                    composer.waitForExistence(timeout: 8),
                    "\(appearance) landing composer identifier missing"
                )
                XCTAssertGreaterThan(
                    composer.frame.height,
                    40,
                    "\(appearance) landing composer frame is empty"
                )
                // Protocol `landingComposerBottomGapMaxPoints`: card bottom vs
                // the window bottom. On a home-indicator phone the composer
                // sits on the safe-area floor, so this gap is the indicator
                // (~34pt) plus the 2pt card padding — still ≤ 40.
                let window = app.windows.firstMatch.frame
                let gap = window.maxY - composer.frame.maxY
                XCTAssertLessThanOrEqual(
                    gap,
                    40,
                    "\(appearance) landing composer floated off the bottom (gap \(gap))"
                )
            }
            if screen == "chat" || screen == "trajectory" {
                XCTAssertFalse(app.images["clock"].exists, "\(appearance) \(screen) still exposes SF clock on jobs chip")
                XCTAssertFalse(app.images["clock.fill"].exists, "\(appearance) \(screen) still exposes SF clock.fill on jobs chip")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.jobsChevron"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official jobs-trigger chevron"
                )
            }
            if screen == "models" {
                XCTAssertTrue(app.descendants(matching: .any)["modelChipEffort"].waitForExistence(timeout: 8), "\(appearance) model chip missing effort")
                XCTAssertTrue(app.descendants(matching: .any)["modelPickerEffort"].waitForExistence(timeout: 8), "\(appearance) model menu missing effort row")
            }
            if screen == "trajectory" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["chatTab.trajectory"].waitForExistence(timeout: 15),
                    "\(appearance) trajectory tab missing"
                )
                XCTAssertFalse(app.images["magnifyingglass"].exists, "\(appearance) trajectory still exposes SF magnifyingglass")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.searchOutline"].waitForExistence(timeout: 8),
                    "\(appearance) trajectory missing official search glyph"
                )
                XCTAssertFalse(app.images["clock"].exists, "\(appearance) trajectory still exposes SF clock")
                XCTAssertFalse(app.images["clock.fill"].exists, "\(appearance) trajectory still exposes SF clock.fill")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.trajectoryClock"].waitForExistence(timeout: 8),
                    "\(appearance) trajectory missing official duration-clock glyph"
                )
            }
            let shot = XCUIScreen.main.screenshot()
            let url = root.appendingPathComponent("\(appearance.lowercased())-\(screen).png")
            try shot.pngRepresentation.write(to: url)
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = "\(appearance.lowercased())-\(screen)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if screen == "drawer" {
                try assertDrawerFooterHitsNavigate(app, appearance: appearance)
            }
            app.terminate()
        }
    }

    private func assertDrawerFooterHitsNavigate(_ app: XCUIApplication, appearance: String) throws {
        let settings = app.descendants(matching: .any)["drawerSettingsRow"]
        XCTAssertTrue(settings.waitForExistence(timeout: 4), "\(appearance) settings hit gone before tap")
        settings.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["settingsShell"].waitForExistence(timeout: 8),
            "\(appearance) settings hit did not open Settings"
        )
        let back = app.buttons["navBack"]
        XCTAssertTrue(back.waitForExistence(timeout: 8), "\(appearance) settings back missing")
        back.tap()
        let open = app.buttons["openDrawer"]
        XCTAssertTrue(open.waitForExistence(timeout: 8), "\(appearance) openDrawer missing after settings")
        open.tap()
        let host = app.descendants(matching: .any)["drawerPeerDeviceRow"]
        XCTAssertTrue(host.waitForExistence(timeout: 8), "\(appearance) host hit missing after reopen")
        host.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["connectionsScreen"].waitForExistence(timeout: 8),
            "\(appearance) host hit did not open Connections"
        )
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
