import XCTest

/// Boots the app against `AppModel.installUITestFixture` and captures the
/// screens parent / CI compare to desktop `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`.
final class ScreenshotTests: XCTestCase {
    private let screens = [
        "landing", "drawer", "viewOptions", "sessionActions", "chat",
        "models", "permission", "start", "browser", "inspector",
        "settings", "schedule", "terminal", "trajectory", "plugins", "connections",
        "composerStop", "slash", "jobs", "builtinPlugins", "trajectoryDetail",
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
                // Intentional skip: no viewfinder / type-filter artwork in primitives.
                // SF images live inside Buttons, so they are not `app.images[...]`.
                XCTAssertTrue(
                    app.descendants(matching: .any)["inspector.viewfinder"].waitForExistence(timeout: 8),
                    "\(appearance) inspector pick skip lost; do not invent a viewfinder SVG"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["inspector.typeFilter"].exists,
                    "\(appearance) inspector type-filter skip lost; do not invent a filter SVG"
                )
            }
            if screen == "landing" || screen == "drawer" {
                XCTAssertFalse(app.images["folder.fill"].exists, "\(appearance) \(screen) still exposes SF folder.fill")
                XCTAssertFalse(app.images["folder"].exists, "\(appearance) \(screen) still exposes SF folder")
            }
            if screen == "landing" {
                let officialOpen = app.descendants(matching: .any)["official.folderOpen"]
                let officialClose = app.descendants(matching: .any)["official.folderClose"]
                XCTAssertTrue(
                    officialOpen.waitForExistence(timeout: 8) || officialClose.waitForExistence(timeout: 2),
                    "\(appearance) landing missing official workspace-chip folder glyph"
                )
                XCTAssertFalse(app.images["chevron.down"].exists, "\(appearance) landing still exposes SF chevron.down")
                XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) landing still exposes SF checkmark")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronDown"].waitForExistence(timeout: 8),
                    "\(appearance) landing missing official workspace-chip chevron"
                )
            }
            if screen == "drawer" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.folderOpenFill"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing desktop IconFolderOpenRegular fill glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["workspaceIcon.ws-ios"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing current workspace folder (ws-ios)"
                )
                XCTAssertFalse(
                    app.images["chevron.right"].exists,
                    "\(appearance) drawer invented a workspace expand chevron; hover-chevron swap is skip"
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
                let modelRow = app.descendants(matching: .any)["modelPickerModel"]
                XCTAssertTrue(modelRow.waitForExistence(timeout: 8), "\(appearance) model menu missing 模型 row")
                modelRow.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["modelReleaseBadge"].waitForExistence(timeout: 8),
                    "\(appearance) Flash list missing modelReleaseBadge"
                )
                XCTAssertTrue(
                    app.staticTexts["DeepSeek-V4.1-Flash"].waitForExistence(timeout: 4)
                        || app.buttons["DeepSeek-V4.1-Flash"].waitForExistence(timeout: 2),
                    "\(appearance) Flash catalog name missing beside the badge"
                )
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
            if screen == "terminal" {
                // Intentional skip: desktop sidebar-terminal has no center spinner.
                // Do not invent a rotating official.loadingOutline.
                XCTAssertFalse(
                    app.descendants(matching: .any)["official.loadingOutline"].exists,
                    "\(appearance) terminal invented a loading SVG; keep the system ProgressView skip"
                )
            }
            if screen == "connections" {
                assertConnectionsIsFullScreen(app, appearance: appearance)
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) connections still exposes SF chevron.left")
                XCTAssertFalse(app.images["link"].exists, "\(appearance) connections still exposes SF link")
                XCTAssertFalse(app.images["keyboard"].exists, "\(appearance) connections still exposes SF keyboard")
                XCTAssertFalse(app.images["keyboard.fill"].exists, "\(appearance) connections still exposes SF keyboard.fill")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) connections missing official back chevron"
                )
                XCTAssertTrue(
                    app.staticTexts["扫码"].waitForExistence(timeout: 8)
                        || app.buttons["扫码"].waitForExistence(timeout: 2),
                    "\(appearance) connections missing 扫码"
                )
                XCTAssertTrue(
                    app.staticTexts["配对链接"].exists || app.buttons["配对链接"].exists,
                    "\(appearance) connections missing 配对链接"
                )
                XCTAssertTrue(
                    app.staticTexts["输入地址"].exists || app.buttons["输入地址"].exists,
                    "\(appearance) connections missing 输入地址"
                )
                let scan = app.descendants(matching: .any)["connectionsAction.scan"].firstMatch
                let pairing = app.descendants(matching: .any)["connectionsAction.pairingLink"].firstMatch
                let address = app.descendants(matching: .any)["connectionsAction.enterAddress"].firstMatch
                XCTAssertTrue(scan.waitForExistence(timeout: 8), "\(appearance) connections missing scan row")
                XCTAssertTrue(pairing.exists, "\(appearance) connections missing pairing-link row")
                XCTAssertTrue(address.exists, "\(appearance) connections missing enter-address row")
                XCTAssertLessThan(scan.frame.minY, pairing.frame.minY, "\(appearance) connections pairing-link is not after 扫码")
                XCTAssertLessThan(pairing.frame.minY, address.frame.minY, "\(appearance) connections 输入地址 is not after 配对链接")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.linkOutline"].exists,
                    "\(appearance) connections missing official link glyph on 配对链接"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["connections.keyboard"].exists,
                    "\(appearance) connections missing Android keyboard glyph on 输入地址"
                )
                XCTAssertTrue(
                    app.staticTexts["附近设备"].waitForExistence(timeout: 8),
                    "\(appearance) connections missing 附近设备"
                )
                XCTAssertTrue(
                    app.staticTexts["客厅 Mac"].waitForExistence(timeout: 4)
                        || app.buttons["客厅 Mac"].waitForExistence(timeout: 2),
                    "\(appearance) connections missing nearby 客厅 Mac"
                )
                XCTAssertFalse(app.images["desktopcomputer"].exists, "\(appearance) nearby still exposes SF desktopcomputer")
                XCTAssertTrue(
                    app.descendants(matching: .any)["connections.computer"].waitForExistence(timeout: 8),
                    "\(appearance) nearby missing Material Computer glyph"
                )
                let nearbyCard = app.descendants(matching: .any)["connectionsNearbyCard"].firstMatch
                XCTAssertTrue(nearbyCard.waitForExistence(timeout: 4), "\(appearance) connections missing 附近设备 card")
                XCTAssertTrue(
                    app.descendants(matching: .any)["connectionsNearbyRow"].waitForExistence(timeout: 4),
                    "\(appearance) connections missing nearby row"
                )
                // Intentional skip: primitives have no QR artwork.
                XCTAssertTrue(
                    app.images["qrcode.viewfinder"].exists,
                    "\(appearance) connections scan skip lost; do not invent a QR SVG"
                )
                let pairedCard = app.descendants(matching: .any)["connectionsPairedCard"].firstMatch
                let actionsCard = app.descendants(matching: .any)["connectionsActionsCard"].firstMatch
                XCTAssertTrue(pairedCard.waitForExistence(timeout: 4), "\(appearance) connections missing 已配对设备 card")
                XCTAssertTrue(actionsCard.exists, "\(appearance) connections missing action card")
                let nearbyGap = nearbyCard.frame.minY - pairedCard.frame.maxY
                let actionsGap = actionsCard.frame.minY - nearbyCard.frame.maxY
                let nearbyTitle = app.staticTexts["附近设备"].firstMatch
                XCTAssertTrue(nearbyTitle.exists, "\(appearance) 附近设备 title missing after card query")
                XCTAssertGreaterThan(
                    nearbyTitle.frame.minY,
                    pairedCard.frame.maxY,
                    "\(appearance) 附近设备 title is not below paired card (\(nearbyTitle.frame) vs paired \(pairedCard.frame))"
                )
                XCTAssertLessThan(
                    nearbyTitle.frame.maxY,
                    nearbyCard.frame.minY,
                    "\(appearance) 附近设备 title is not above nearby card (\(nearbyTitle.frame) vs nearby \(nearbyCard.frame))"
                )
                // Card 6 + ConnSectionTitle 16+20+4 + Card 6 = connectionsPairedNearbyGapPoints.
                XCTAssertEqual(
                    nearbyGap,
                    52,
                    accuracy: 2,
                    "\(appearance) paired/nearby gap \(nearbyGap) is not ConnSectionTitle 6+16+20+4+6"
                )
                XCTAssertGreaterThanOrEqual(
                    actionsGap,
                    11,
                    "\(appearance) nearby/actions cards almost touch (gap \(actionsGap); Android Card vertical 6+6)"
                )
                XCTAssertLessThan(
                    actionsGap,
                    20,
                    "\(appearance) nearby/actions gap \(actionsGap) is not the 12pt Card stack"
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
                XCTAssertFalse(app.images["doc.text.magnifyingglass"].exists, "\(appearance) chat still exposes SF browse")
                XCTAssertFalse(app.images["terminal"].exists, "\(appearance) chat still exposes SF terminal")
                XCTAssertFalse(app.images["curlybraces"].exists, "\(appearance) chat still exposes SF curlybraces")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.browseOutline"].waitForExistence(timeout: 8),
                    "\(appearance) chat missing official read/browse tool glyph"
                )
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "jobs" {
                let trigger = app.descendants(matching: .any)["official.jobsChevron"]
                XCTAssertTrue(trigger.waitForExistence(timeout: 8), "\(appearance) jobs trigger missing")
                trigger.firstMatch.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronDown"].waitForExistence(timeout: 8),
                    "\(appearance) jobs row missing official chevronDown"
                )
                XCTAssertFalse(app.images["chevron.down"].exists, "\(appearance) jobs still exposes SF chevron.down")
                XCTAssertFalse(app.images["chevron.right"].exists, "\(appearance) jobs still exposes SF chevron.right")
                XCTAssertFalse(app.images["stop.fill"].exists, "\(appearance) jobs still exposes SF stop.fill")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.stopFill"].waitForExistence(timeout: 8),
                    "\(appearance) jobs missing official stopFill kill glyph"
                )
            }
            if screen == "builtinPlugins" {
                XCTAssertFalse(app.images["arrow.clockwise"].exists, "\(appearance) builtin plugins still exposes SF arrow.clockwise")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.refreshOutline"].waitForExistence(timeout: 8),
                    "\(appearance) builtin plugins missing official refresh"
                )
                XCTAssertFalse(app.images["chevron.left"].exists, "\(appearance) builtin plugins still exposes SF chevron.left")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronLeft"].waitForExistence(timeout: 8),
                    "\(appearance) builtin plugins missing official back chevron"
                )
            }
            if screen == "trajectoryDetail" {
                let row = app.descendants(matching: .any)["trajRow.t-read"]
                XCTAssertTrue(row.waitForExistence(timeout: 15), "\(appearance) trajectory tool row missing")
                row.firstMatch.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronRight"].waitForExistence(timeout: 8),
                    "\(appearance) trajectory detail missing official chevronRight"
                )
                XCTAssertFalse(app.images["chevron.right"].exists, "\(appearance) trajectory detail still exposes SF chevron.right")
                XCTAssertFalse(app.images["chevron.down"].exists, "\(appearance) trajectory detail still exposes SF chevron.down")
                XCTAssertFalse(app.images["wrench.and.screwdriver"].exists, "\(appearance) trajectory detail still exposes SF wrench")
                XCTAssertFalse(app.images["square.on.square"].exists, "\(appearance) trajectory detail still exposes SF copy")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.copyOutline"].waitForExistence(timeout: 8),
                    "\(appearance) trajectory detail missing official copyOutline"
                )
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
            if screen == "connections" {
                try assertManageSheet(app, appearance: appearance)
                try assertPairingLinkSheet(app, appearance: appearance)
            }
            if screen == "models" {
                try assertModelReleaseBadgeTracksSelection(app, appearance: appearance)
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

    /// Android `ProfileManageSheet`: desktop `D.refresh` / `D.edit` / `D.trash`
    /// on ConnOptionRow (`T.Ink`), not SF symbols or a system NavigationStack.
    private func assertManageSheet(_ app: XCUIApplication, appearance: String) throws {
        let pairedRow = app.descendants(matching: .any)["connectionsPairedRow"].firstMatch
        XCTAssertTrue(
            pairedRow.waitForExistence(timeout: 8),
            "\(appearance) paired Mac mini row missing"
        )
        pairedRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["connectionsManageSheet"].waitForExistence(timeout: 8),
            "\(appearance) manage sheet missing"
        )
        let manageCancel = app.descendants(matching: .any)["connectionsManageCancel"].firstMatch
        XCTAssertTrue(
            manageCancel.waitForExistence(timeout: 4)
                || app.buttons["取消"].waitForExistence(timeout: 2),
            "\(appearance) manage sheet missing 取消"
        )
        let manageCancelFrame = manageCancel.exists ? manageCancel : app.buttons["取消"].firstMatch
        XCTAssertGreaterThanOrEqual(
            manageCancelFrame.frame.height,
            44,
            "\(appearance) manage 取消 height \(manageCancelFrame.frame.height) is under 44pt"
        )
        XCTAssertTrue(
            app.staticTexts["重新配对"].waitForExistence(timeout: 4)
                || app.descendants(matching: .any)["connectionsManageRepair"].waitForExistence(timeout: 2),
            "\(appearance) manage sheet missing 重新配对"
        )
        XCTAssertTrue(
            app.staticTexts["重命名"].exists
                || app.descendants(matching: .any)["connectionsManageRename"].exists,
            "\(appearance) manage sheet missing 重命名"
        )
        XCTAssertTrue(
            app.staticTexts["删除"].exists
                || app.descendants(matching: .any)["connectionsManageDelete"].exists,
            "\(appearance) manage sheet missing 删除"
        )
        XCTAssertFalse(app.images["trash"].exists, "\(appearance) manage still exposes SF trash")
        XCTAssertFalse(app.images["arrow.clockwise"].exists, "\(appearance) manage still exposes SF arrow.clockwise")
        XCTAssertFalse(app.images["pencil"].exists, "\(appearance) manage still exposes SF pencil")
        XCTAssertTrue(
            app.descendants(matching: .any)["official.trashOutline"].waitForExistence(timeout: 8),
            "\(appearance) manage missing official trashOutline"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["official.refreshOutline"].exists,
            "\(appearance) manage missing official refreshOutline"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["official.editOutline"].exists,
            "\(appearance) manage missing official editOutline"
        )
        try saveNamedScreenshot(appearance, "manage")
        let cancel = app.descendants(matching: .any)["connectionsManageCancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            app.buttons["取消"].firstMatch.tap()
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["connectionsManageSheet"].firstMatch.waitForNonExistence(timeout: 8),
            "\(appearance) manage sheet stayed after 取消"
        )
    }

    /// Android `PairLinkSheet`: paste/type `dshpocket://pair`, then Continue
    /// prefills pair confirmation and does not connect.
    private func assertPairingLinkSheet(_ app: XCUIApplication, appearance: String) throws {
        let pairingRow = app.descendants(matching: .any)["connectionsAction.pairingLink"].firstMatch
        let pairingTitle = app.staticTexts["配对链接"].firstMatch
        let pairingButton = app.buttons["配对链接"].firstMatch
        XCTAssertTrue(
            pairingRow.waitForExistence(timeout: 4)
                || pairingTitle.waitForExistence(timeout: 2)
                || pairingButton.waitForExistence(timeout: 2),
            "\(appearance) 配对链接 row title missing"
        )
        if pairingRow.exists {
            pairingRow.tap()
        } else if pairingButton.exists {
            pairingButton.tap()
        } else {
            pairingTitle.tap()
        }
        let hint = app.staticTexts["在电脑「设置 → 手机连接」复制配对链接，然后粘贴到这里。"]
        XCTAssertTrue(
            hint.waitForExistence(timeout: 8),
            "\(appearance) pairing-link sheet missing"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["connectionsPairLinkSheet"].waitForExistence(timeout: 4),
            "\(appearance) connectionsPairLinkSheet identifier missing"
        )
        let pairCancel = app.descendants(matching: .any)["connectionsPairLinkCancel"].firstMatch
        XCTAssertTrue(
            pairCancel.waitForExistence(timeout: 4)
                || app.buttons["取消"].waitForExistence(timeout: 2),
            "\(appearance) pairing-link sheet missing 取消"
        )
        let pairCancelFrame = pairCancel.exists ? pairCancel : app.buttons["取消"].firstMatch
        XCTAssertGreaterThanOrEqual(
            pairCancelFrame.frame.height,
            44,
            "\(appearance) pairing-link 取消 height \(pairCancelFrame.frame.height) is under 44pt"
        )
        try saveNamedScreenshot(appearance, "pairingLink")
        let paste = app.descendants(matching: .any)["connectionsPastePairingLink"]
        let next = app.descendants(matching: .any)["connectionsReviewPairingLink"]
        XCTAssertTrue(paste.waitForExistence(timeout: 4), "\(appearance) 粘贴链接 missing")
        XCTAssertTrue(next.waitForExistence(timeout: 4), "\(appearance) 下一步 missing")
        XCTAssertEqual(
            paste.firstMatch.frame.height,
            48,
            accuracy: 2,
            "\(appearance) 粘贴链接 height \(paste.firstMatch.frame.height) is not Android PairLinkSheet 48"
        )
        XCTAssertEqual(
            next.firstMatch.frame.height,
            48,
            accuracy: 2,
            "\(appearance) 下一步 height \(next.firstMatch.frame.height) is not Android PairLinkSheet 48"
        )
        XCTAssertFalse(next.firstMatch.isEnabled, "\(appearance) 下一步 enabled on empty pairing link")
        let field = app.descendants(matching: .any)["connectionsPairingLinkField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4), "\(appearance) pairing-link field missing")
        replaceText(field, with: "https://example.com")
        XCTAssertTrue(
            app.descendants(matching: .any)["connectionsInvalidPairingLink"].waitForExistence(timeout: 4)
                || app.staticTexts["请输入有效的 dshpocket://pair 链接，需包含主机地址和六位配对码。"].waitForExistence(timeout: 2),
            "\(appearance) invalid pairing-link copy missing"
        )
        XCTAssertFalse(next.firstMatch.isEnabled, "\(appearance) 下一步 enabled on invalid pairing link")
        replaceText(field, with: "dshpocket://pair?h=192.168.1.20:7690&c=654321")
        let invalid = app.descendants(matching: .any)["connectionsInvalidPairingLink"].firstMatch
        XCTAssertTrue(
            invalid.waitForNonExistence(timeout: 4),
            "\(appearance) invalid pairing-link copy stayed after a valid paste"
        )
        waitUntil(timeout: 4) { next.firstMatch.isEnabled }
        XCTAssertTrue(next.firstMatch.isEnabled, "\(appearance) 下一步 disabled on valid pairing link")
        next.firstMatch.tap()
        let address = app.descendants(matching: .any)["connectionsAddressField"].firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 8), "\(appearance) pair sheet address missing after 下一步")
        XCTAssertEqual(address.value as? String, "192.168.1.20:7690", "\(appearance) pair sheet did not prefill host:port")
        let code = app.descendants(matching: .any)["connectionsCodeField"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 4), "\(appearance) pair sheet code missing after 下一步")
        XCTAssertEqual(code.value as? String, "654321", "\(appearance) pair sheet did not prefill pairing code")
        XCTAssertTrue(
            app.buttons["开始配对"].waitForExistence(timeout: 4) || app.staticTexts["开始配对"].waitForExistence(timeout: 2),
            "\(appearance) pair sheet missing 开始配对"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["connectionsScreen"].firstMatch.waitForExistence(timeout: 2),
            "\(appearance) pairing-link flow left 远程主机"
        )
    }

    /// Pairing-link placeholder (`connectionsPairingLinkFieldHint`). Empty
    /// SwiftUI TextFields report this as `value`.
    private let pairingLinkPlaceholder = "dshpocket://pair?h=…&c=…"

    private func pairingLinkFieldValue(_ element: XCUIElement) -> String {
        let raw = (element.value as? String) ?? ""
        return (raw.isEmpty || raw == pairingLinkPlaceholder) ? "" : raw
    }

    /// Wait on an XCUI predicate. Do not sleep — CI Dark failed at 22b3312
    /// because the field never became the valid URI, not because 4s was short.
    @discardableResult
    private func waitUntil(timeout: TimeInterval, _ predicate: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in predicate() },
            object: nil
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Center-tap + N deletes leaves the caret mid-string, so the next URL
    /// concatenates (`https://example.comdshpocket://…`) and parse stays nil.
    /// Put the caret at the trailing edge, wait until the field is actually
    /// empty, then wait until `value` equals the intended string.
    private func replaceText(_ element: XCUIElement, with value: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 4), "pairing-link field missing before replace")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        var current = pairingLinkFieldValue(element)
        if !current.isEmpty {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            waitUntil(timeout: 4) { self.pairingLinkFieldValue(element).isEmpty }
            current = pairingLinkFieldValue(element)
            if !current.isEmpty {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 8))
                waitUntil(timeout: 4) { self.pairingLinkFieldValue(element).isEmpty }
            }
        }
        XCTAssertEqual(
            pairingLinkFieldValue(element),
            "",
            "pairing-link field still \(pairingLinkFieldValue(element)) before typing \(value)"
        )
        element.typeText(value)
        XCTAssertTrue(
            waitUntil(timeout: 4) { self.pairingLinkFieldValue(element) == value },
            "pairing-link field was \(pairingLinkFieldValue(element)), expected \(value)"
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

    private func assertModelReleaseBadgeTracksSelection(_ app: XCUIApplication, appearance: String) throws {
        let flash = "DeepSeek-V4.1-Flash"
        let pro = "DeepSeek V4 Pro"
        let badge = app.descendants(matching: .any)["modelReleaseBadge"]
        XCTAssertTrue(
            badge.waitForExistence(timeout: 8),
            "\(appearance) Flash list missing modelReleaseBadge before switching"
        )
        let flashRow = app.buttons[flash].firstMatch
        XCTAssertTrue(
            flashRow.waitForExistence(timeout: 8) || app.staticTexts[flash].waitForExistence(timeout: 2),
            "\(appearance) Flash option missing"
        )
        if flashRow.exists {
            flashRow.tap()
        } else {
            app.staticTexts[flash].firstMatch.tap()
        }

        XCTAssertTrue(
            badge.waitForExistence(timeout: 8),
            "\(appearance) composer chip missing modelReleaseBadge after picking Flash"
        )
        let chip = app.buttons["modelChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 8), "\(appearance) model chip missing after Flash pick")
        XCTAssertTrue(
            chip.label.contains(flash),
            "\(appearance) model chip accessible name dropped catalog name (got \(chip.label))"
        )
        XCTAssertFalse(
            chip.label.contains("1017"),
            "\(appearance) model chip accessible name leaked the release badge (got \(chip.label))"
        )

        let input = app.textViews["composerInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 8), "\(appearance) composer input missing")
        input.tap()
        input.typeText("保留草稿")
        let transcript = app.descendants(matching: .any)["chatTranscript"]
        if transcript.waitForExistence(timeout: 2) {
            transcript.tap()
        }

        chip.tap()
        let modelRow = app.descendants(matching: .any)["modelPickerModel"]
        XCTAssertTrue(modelRow.waitForExistence(timeout: 8), "\(appearance) 模型 row missing after reopen")
        XCTAssertTrue(
            badge.waitForExistence(timeout: 8),
            "\(appearance) root 模型 row missing modelReleaseBadge while Flash is current"
        )
        modelRow.tap()
        let proRow = app.buttons[pro].firstMatch
        XCTAssertTrue(
            proRow.waitForExistence(timeout: 8) || app.staticTexts[pro].waitForExistence(timeout: 2),
            "\(appearance) Pro option missing"
        )
        if proRow.exists {
            proRow.tap()
        } else {
            app.staticTexts[pro].firstMatch.tap()
        }

        XCTAssertFalse(
            badge.waitForExistence(timeout: 3),
            "\(appearance) modelReleaseBadge stayed after leaving Flash"
        )
        let draft = input.value as? String ?? input.label
        XCTAssertTrue(
            draft.contains("保留草稿"),
            "\(appearance) composer draft changed while switching models (got \(draft))"
        )
        XCTAssertTrue(
            chip.label.contains(pro),
            "\(appearance) model chip accessible name is not Pro after switching (got \(chip.label))"
        )
        XCTAssertFalse(chip.label.contains("1017"), "\(appearance) Pro chip still exposes 1017")
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

    private func saveNamedScreenshot(_ appearance: String, _ name: String) throws {
        let root = try screenshotRoot()
        let shot = XCUIScreen.main.screenshot()
        let url = root.appendingPathComponent("\(appearance.lowercased())-\(name).png")
        try shot.pngRepresentation.write(to: url)
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(appearance.lowercased())-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
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
