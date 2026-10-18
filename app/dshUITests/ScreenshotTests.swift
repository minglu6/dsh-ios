import XCTest

/// Boots the app against `AppModel.installUITestFixture` and captures the
/// screens parent / CI compare to desktop `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`.
final class ScreenshotTests: XCTestCase {
    private let screens = [
        "landing", "drawer", "viewOptions", "sessionActions", "chat",
        "models", "permission", "start", "browser", "inspector",
        "settings", "schedule", "terminal", "trajectory", "plugins", "connections",
        "composerStop", "slash",
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
                try assertHostSurfaceFullScreen(app, id: "startPanel", appearance: appearance)
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) start still exposes SF chevron.left")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) start missing official back chevron"
                )
                let files = app.descendants(matching: .any)["start.工作区文件"]
                XCTAssertTrue(files.waitForExistence(timeout: 8), "\(appearance) start missing workspace card")
                let panel = app.descendants(matching: .any)["startPanel"].firstMatch
                XCTAssertLessThan(
                    files.frame.minY - panel.frame.minY,
                    120,
                    "\(appearance) start left a large blank above the Guide cards (\(files.frame) vs \(panel.frame))"
                )
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "browser" {
                try assertHostSurfaceFullScreen(app, id: "browserPanel", appearance: appearance)
                XCTAssertFalse(app.images["plus"].exists, "\(appearance) browser still exposes SF plus")
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) browser still exposes SF chevron.left")
                XCTAssertFalse(app.images["chevron.right"].exists, "\(appearance) browser still exposes SF chevron.right")
                XCTAssertFalse(app.images["arrow.clockwise"].exists, "\(appearance) browser still exposes SF arrow.clockwise")
                XCTAssertFalse(app.images["link"].exists, "\(appearance) browser still exposes SF link")
                XCTAssertFalse(app.images["arrow.up.right"].exists, "\(appearance) browser still exposes SF arrow.up.right")
                XCTAssertFalse(app.images["xmark"].exists, "\(appearance) browser still exposes SF xmark")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) browser missing official chevronLeft"
                )
                XCTAssertTrue(app.descendants(matching: .any)["official.chevronRight"].exists, "\(appearance) browser missing official chevronRight")
                XCTAssertTrue(app.descendants(matching: .any)["official.refreshOutline"].exists, "\(appearance) browser missing official refresh")
                XCTAssertTrue(app.descendants(matching: .any)["official.linkOutline"].exists, "\(appearance) browser missing official link")
                XCTAssertTrue(app.descendants(matching: .any)["official.rightUp"].exists, "\(appearance) browser missing official right-up")
                XCTAssertTrue(app.descendants(matching: .any)["official.closeOutline"].exists, "\(appearance) browser missing official close")
            }
            if screen == "inspector" {
                try assertHostSurfaceFullScreen(app, id: "sessionInspector", appearance: appearance)
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) inspector still exposes SF chevron.left")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) inspector missing official back chevron"
                )
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
            if screen == "landing" || screen == "chat" || screen == "composerStop" || screen == "slash" || screen == "models" || screen == "permission" || screen == "trajectory" {
                XCTAssertFalse(app.images["sidebar.left"].exists, "\(appearance) \(screen) still exposes SF sidebar.left")
                XCTAssertFalse(app.images["sidebar.right"].exists, "\(appearance) \(screen) still exposes SF sidebar.right")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.panelLeft"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official panel-left glyph"
                )
            }
            if screen == "chat" || screen == "composerStop" || screen == "slash" || screen == "models" || screen == "permission" || screen == "trajectory" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.panelRight"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official panel-right glyph"
                )
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
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) plugins still exposes SF chevron.left")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) plugins missing official back chevron"
                )
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
                XCTAssertFalse(app.images["fish"].exists, "\(appearance) landing still exposes SF fish")
                XCTAssertFalse(app.images["fish.fill"].exists, "\(appearance) landing still exposes SF fish.fill")
                XCTAssertFalse(app.images["fish.circle"].exists, "\(appearance) landing still exposes SF fish.circle")
                let fish = app.descendants(matching: .any)["official.fishLogo"].firstMatch
                XCTAssertTrue(
                    fish.waitForExistence(timeout: 8),
                    "\(appearance) landing missing official whale glyph beside the headline"
                )
                let title = app.descendants(matching: .any)["landingHeadline"].firstMatch
                XCTAssertTrue(
                    title.waitForExistence(timeout: 8),
                    "\(appearance) landing headline missing"
                )
                XCTAssertTrue(
                    title.label.contains("探索未至之境")
                        || app.staticTexts["探索未至之境"].waitForExistence(timeout: 2),
                    "\(appearance) landing headline is not desktop hero.headline 探索未至之境 (got \(title.label))"
                )
                XCTAssertFalse(
                    app.staticTexts["探索未知之境"].exists,
                    "\(appearance) landing used the misremembered 探索未知之境 copy"
                )
                XCTAssertLessThan(
                    fish.frame.maxX,
                    title.frame.minX + 1,
                    "\(appearance) landing whale is not to the left of the headline"
                )
                let fishGap = title.frame.minX - fish.frame.maxX
                XCTAssertGreaterThanOrEqual(fishGap, 4, "\(appearance) landing whale/title overlap (gap \(fishGap))")
                XCTAssertLessThanOrEqual(fishGap, 16, "\(appearance) landing whale/title gap \(fishGap) is not the desktop 10pt column-gap")
                XCTAssertLessThan(
                    abs(fish.frame.midY - title.frame.midY),
                    12,
                    "\(appearance) landing whale is not vertically aligned with the headline"
                )
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
            if screen == "permission" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["permissionPicker"].waitForExistence(timeout: 8),
                    "\(appearance) permission chip menu missing"
                )
                XCTAssertTrue(
                    app.staticTexts["工作区内修改"].waitForExistence(timeout: 4)
                        || app.descendants(matching: .any)["permissionPicker"].firstMatch.label.contains("工作区内修改"),
                    "\(appearance) permission menu missing desktop catalog labels"
                )
                XCTAssertFalse(
                    app.staticTexts["访问模式"].exists,
                    "\(appearance) permission still presents the system Access-mode sheet"
                )
                XCTAssertFalse(
                    app.staticTexts["transport: 未连接到远程主机"].exists,
                    "\(appearance) permission menu reloaded the catalog over a missing transport"
                )
                let window = app.windows.firstMatch.frame
                let picker = app.descendants(matching: .any)["permissionPicker"].firstMatch.frame
                XCTAssertLessThan(
                    picker.height / window.height,
                    0.7,
                    "\(appearance) permission picker looks like a full-screen sheet (\(picker) vs \(window))"
                )
            }
            if screen == "schedule" || screen == "terminal" {
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) \(screen) still exposes SF chevron.left")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official back chevron"
                )
            }
            if screen == "connections" {
                assertConnectionsIsFullScreen(app, appearance: appearance)
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) connections still exposes SF chevron.left")
                XCTAssertFalse(app.images["link"].exists, "\(appearance) connections still exposes SF link")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) connections missing official back chevron"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.linkOutline"].exists,
                    "\(appearance) connections missing official address-link glyph"
                )
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
                XCTAssertFalse(app.images["person"].exists, "\(appearance) trajectory still exposes SF person")
                XCTAssertFalse(app.images["sparkle"].exists, "\(appearance) trajectory still exposes SF sparkle")
                XCTAssertFalse(app.images["sparkles"].exists, "\(appearance) trajectory still exposes SF sparkles")
                XCTAssertFalse(app.images["wrench.and.screwdriver"].exists, "\(appearance) trajectory still exposes SF wrench")
                XCTAssertFalse(app.images["gearshape"].exists, "\(appearance) trajectory still exposes SF gearshape")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.userOutline"].waitForExistence(timeout: 8),
                    "\(appearance) trajectory missing official user kind glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.sparkle"].exists,
                    "\(appearance) trajectory missing official assistant sparkle glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.information"].exists,
                    "\(appearance) trajectory missing 14px desktop InformationIcon"
                )
            }
            if screen == "chat" {
                XCTAssertFalse(app.images["hand.thumbsup"].exists, "\(appearance) chat still exposes SF thumbsup")
                XCTAssertFalse(app.images["hand.thumbsup.fill"].exists, "\(appearance) chat still exposes SF thumbsup.fill")
                XCTAssertFalse(app.images["hand.thumbsdown"].exists, "\(appearance) chat still exposes SF thumbsdown")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.likeFill"].waitForExistence(timeout: 8),
                    "\(appearance) chat missing official like glyph after feedback.set"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.dislikeOutline"].exists,
                    "\(appearance) chat missing official dislike glyph"
                )
                XCTAssertFalse(app.images["square.on.square"].exists, "\(appearance) chat still exposes SF square.on.square")
                XCTAssertFalse(app.images["doc.on.doc"].exists, "\(appearance) chat still exposes SF doc.on.doc")
                XCTAssertFalse(app.images["arrow.triangle.branch"].exists, "\(appearance) chat still exposes SF branch")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.copyOutline"].waitForExistence(timeout: 8),
                    "\(appearance) chat missing official copy glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.branchOutline"].exists,
                    "\(appearance) chat missing official branch glyph"
                )
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "settings" {
                XCTAssertFalse(app.images["sun.max"].exists, "\(appearance) settings still exposes SF sun.max")
                XCTAssertFalse(app.images["moon"].exists, "\(appearance) settings still exposes SF moon")
                XCTAssertFalse(app.images["desktopcomputer"].exists, "\(appearance) settings still exposes SF desktopcomputer")
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) settings still exposes SF chevron.left")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.appearanceLight"].waitForExistence(timeout: 8),
                    "\(appearance) settings missing official light cube"
                )
                XCTAssertTrue(app.descendants(matching: .any)["official.appearanceDark"].exists, "\(appearance) settings missing official dark cube")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.appearanceFollowSystem"].exists,
                    "\(appearance) settings missing official follow-system cube"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) settings missing official back chevron"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["settingsPermissionSelect"].waitForExistence(timeout: 15),
                    "\(appearance) settings missing desktop PermissionRow select"
                )
                XCTAssertFalse(app.staticTexts["访问模式"].exists, "\(appearance) settings still presents Access-mode sheet")
                XCTAssertFalse(app.staticTexts["默认权限"].exists, "\(appearance) settings still presents Default-permission sheet")
                app.descendants(matching: .any)["settingsPermissionSelect"].firstMatch.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["settingsPermissionMenu"].waitForExistence(timeout: 8),
                    "\(appearance) settings permission menu missing"
                )
                XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) settings permission still uses SF checkmark")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.checkOutline"].exists,
                    "\(appearance) settings permission missing official check"
                )
                let window = app.windows.firstMatch.frame
                let menu = app.descendants(matching: .any)["settingsPermissionMenu"].firstMatch.frame
                XCTAssertLessThan(
                    menu.height / window.height,
                    0.7,
                    "\(appearance) settings permission looks like a sheet (\(menu) vs \(window))"
                )
            }
            if screen == "composerStop" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.stopRect"].waitForExistence(timeout: 8),
                    "\(appearance) composer stop missing desktop rect rx=3 glyph"
                )
                XCTAssertFalse(
                    app.descendants(matching: .any)["official.send"].exists,
                    "\(appearance) running composer still shows send instead of stop"
                )
            }
            if screen == "slash" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["slashMenu"].waitForExistence(timeout: 15),
                    "\(appearance) slash menu missing"
                )
                let permission = app.staticTexts["权限"]
                XCTAssertTrue(permission.waitForExistence(timeout: 8), "\(appearance) slash missing 权限")
                permission.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.checkOutline"].waitForExistence(timeout: 8),
                    "\(appearance) slash permission missing official check"
                )
                XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) slash still uses SF checkmark")
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "models" {
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "permission" {
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
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
            if screen == "start" || screen == "browser" || screen == "inspector" {
                let back = app.buttons["navBack"]
                XCTAssertTrue(back.waitForExistence(timeout: 4), "\(appearance) \(screen) back gone before tap")
                back.tap()
                let surfaceId = screen == "start" ? "startPanel" : (screen == "browser" ? "browserPanel" : "sessionInspector")
                XCTAssertFalse(
                    app.descendants(matching: .any)[surfaceId].waitForExistence(timeout: 4),
                    "\(appearance) \(screen) did not dismiss after back"
                )
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
        assertConnectionsIsFullScreen(app, appearance: appearance)
    }

    /// Drawer footer Host entry must replace the window with `ConnectionsView`,
    /// not leave the session drawer or a sheet detent covering the list.
    private func assertConnectionsIsFullScreen(_ app: XCUIApplication, appearance: String) {
        let query = app.descendants(matching: .any).matching(identifier: "connectionsScreen")
        XCTAssertTrue(
            query.firstMatch.waitForExistence(timeout: 8),
            "\(appearance) connections page missing"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["drawerSettingsRow"].exists,
            "\(appearance) connections still has the session drawer on screen"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["drawerPeerDeviceRow"].exists,
            "\(appearance) connections still shows drawer host chrome"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["viewOptionsButton"].exists,
            "\(appearance) connections still shows drawer chrome"
        )
        XCTAssertTrue(
            app.staticTexts["远程主机"].waitForExistence(timeout: 4)
                || app.descendants(matching: .any)["connectionsTitle"].waitForExistence(timeout: 2),
            "\(appearance) connections missing 远程主机 title"
        )
        let window = app.windows.firstMatch.frame
        var frame = CGRect.null
        for i in 0..<query.count {
            frame = frame.union(query.element(boundBy: i).frame)
        }
        XCTAssertGreaterThanOrEqual(
            frame.width / window.width,
            0.98,
            "\(appearance) connections is not full width (\(frame) vs \(window))"
        )
        XCTAssertGreaterThanOrEqual(
            frame.height / window.height,
            0.90,
            "\(appearance) connections is not full height (\(frame) vs \(window))"
        )
        XCTAssertLessThanOrEqual(
            frame.minY - window.minY,
            40,
            "\(appearance) connections looks like a sheet (origin \(frame.minY) vs window \(window.minY))"
        )
    }

    private func assertHostSurfaceFullScreen(_ app: XCUIApplication, id: String, appearance: String) throws {
        let query = app.descendants(matching: .any).matching(identifier: id)
        XCTAssertTrue(
            query.firstMatch.waitForExistence(timeout: 15),
            "\(appearance) \(id) missing"
        )
        XCTAssertTrue(
            app.buttons["navBack"].waitForExistence(timeout: 8),
            "\(appearance) \(id) missing back/close"
        )
        let window = app.windows.firstMatch.frame
        var frame = CGRect.null
        for i in 0..<query.count {
            frame = frame.union(query.element(boundBy: i).frame)
        }
        XCTAssertGreaterThanOrEqual(
            frame.width / window.width,
            0.98,
            "\(appearance) \(id) is not full width (\(frame) vs \(window))"
        )
        XCTAssertGreaterThanOrEqual(
            frame.height / window.height,
            0.90,
            "\(appearance) \(id) is not full height (\(frame) vs \(window))"
        )
        XCTAssertLessThanOrEqual(
            frame.minY - window.minY,
            100,
            "\(appearance) \(id) looks like a grabber sheet (origin \(frame.minY) vs window \(window.minY))"
        )
    }

    private func assertOfficialMenuChrome(_ app: XCUIApplication, appearance: String, screen: String) {
        XCTAssertFalse(
            app.images["chevron.down"].exists,
            "\(appearance) \(screen) still exposes SF chevron.down"
        )
        XCTAssertFalse(
            app.images["chevron.up"].exists,
            "\(appearance) \(screen) still exposes SF chevron.up"
        )
        XCTAssertFalse(
            app.images["chevron.left"].exists,
            "\(appearance) \(screen) still exposes SF chevron.left"
        )
        XCTAssertFalse(
            app.images["chevron.right"].exists,
            "\(appearance) \(screen) still exposes SF chevron.right"
        )
        XCTAssertFalse(
            app.images["checkmark"].exists,
            "\(appearance) \(screen) still exposes SF checkmark"
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
