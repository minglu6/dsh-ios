import XCTest

/// Boots the app against `AppModel.installUITestFixture` and captures the
/// screens parent / CI compare to desktop `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`.
final class ScreenshotTests: XCTestCase {
    private let screens = [
        "landing", "landingPreset", "drawer", "viewOptions", "sessionActions", "chat", "chatLong", "changesCard", "planMode", "mention",
        "landingMention", "mentionFiltered", "mentionChip", "mentionSent",
        "turnTrigger", "filePreview",
        "models", "permission", "start", "startLanding", "browser", "inspector",
        "settings", "settingsShell", "schedule", "terminal", "files", "trajectory", "plugins", "connections",
        "composerStop", "slash", "jobs", "builtinPlugins", "trajectoryDetail",
        "chatDock",
        "terminalUnavailable", "terminalMissing", "terminalDisconnected", "terminalExited",
        "terminalSwitcher",
    ]

    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testLightScreenshots() throws {
        try capture(appearance: "Light")
    }

    func testDarkScreenshots() throws {
        try capture(appearance: "Dark")
    }

    func testTerminalImmediateFailureLeavesConnectingAndOffersRetry() {
        let app = XCUIApplication()
        // This fixture reaches the real attach path without a client. The
        // failure can complete before SwiftUI observes the intermediate true.
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "terminal"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["terminalError"].waitForExistence(timeout: 10))
        let retry = app.buttons["重试"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isHittable)
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isHittable)
    }

    func testTerminalScreenRemainsVisibleWithKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "terminalSwitcher"]
        app.launch()
        let screen = app.descendants(matching: .any)["terminalScreen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10))
        XCTAssertTrue((screen.value as? String)?.contains("switcher-shell-output") == true)
        XCTAssertGreaterThan(screen.frame.height, 100)
        screen.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(screen.frame.height, 100)
        XCTAssertLessThanOrEqual(screen.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        XCTAssertTrue((screen.value as? String)?.contains("switcher-shell-output") == true)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "terminal-keyboard-screen"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testConversationPresetUsesSessionMetadataNotDraftSelection() {
        for screen in ["contextActive", "contextBlank", "contextOffline", "contextNoRoster", "contextUnknown"] {
            let app = XCUIApplication()
            app.launchArguments = ["-UITestFixture", "-UITestScreen", screen]
            app.launch()
            XCTAssertTrue(app.buttons["openDrawer"].waitForExistence(timeout: 15), screen)
            let preset = app.descendants(matching: .any)["conversationPreset"].firstMatch
            if screen == "contextUnknown" {
                XCTAssertFalse(preset.exists, screen)
            } else {
                XCTAssertTrue(preset.waitForExistence(timeout: 5), screen)
                XCTAssertEqual(preset.label, "标准模式", screen)
            }
            XCTAssertFalse(app.descendants(matching: .any)["conversationWorkspace"].exists, screen)
            XCTAssertFalse(app.buttons["draftWorkspace"].exists, screen)
            XCTAssertFalse(app.buttons["agentPresetSeat"].exists, screen)
            XCTAssertFalse(app.buttons["conversationPreset"].exists, screen)
            app.terminate()
        }
    }

    func testLandingContextRemainsSelectableAndVisibleWithoutMetadata() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "landing"]
        app.launch()
        let workspace = app.buttons["draftWorkspace"]
        let preset = app.buttons["agentPresetSeat"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 15))
        XCTAssertEqual(workspace.value as? String, "dsh-ios")
        XCTAssertEqual(preset.label, "标准模式")
        workspace.tap()
        let android = app.buttons.containing(.staticText, identifier: "dsh-android").firstMatch
        XCTAssertTrue(android.waitForExistence(timeout: 5))
        android.tap()
        XCTAssertEqual(workspace.value as? String, "dsh-android")
        preset.tap()
        let creator = app.buttons["agentPresetRow.cordis"]
        XCTAssertTrue(creator.waitForExistence(timeout: 5))
        creator.tap()
        XCTAssertEqual(preset.label, "创造模式")
        app.terminate()

        app.launchArguments = ["-UITestFixture", "-UITestScreen", "contextLandingEmpty"]
        app.launch()
        XCTAssertTrue(workspace.waitForExistence(timeout: 15))
        XCTAssertEqual(workspace.value as? String, "")
        XCTAssertTrue(preset.exists)
        XCTAssertEqual(preset.label, "选择工作模式")
        XCTAssertFalse(preset.isEnabled)
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
            if screen == "startLanding" {
                let open = app.descendants(matching: .any)["openStartPanel"]
                XCTAssertTrue(
                    open.waitForExistence(timeout: 8),
                    "\(appearance) startLanding missing openStartPanel"
                )
                open.firstMatch.tap()
                try assertHostSurfaceFullScreen(app, id: "startPanel", appearance: appearance)
                XCTAssertTrue(
                    app.descendants(matching: .any)["start.会话数据诊断"].waitForExistence(timeout: 8),
                    "\(appearance) startLanding missing 会话数据诊断"
                )
                XCTAssertFalse(
                    app.descendants(matching: .any)["start.连接诊断"].exists
                        || app.staticTexts["连接诊断"].exists
                        || app.buttons["连接诊断"].exists,
                    "\(appearance) startLanding still exposes 连接诊断"
                )
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
            if screen == "landing" || screen == "landingPreset" || screen == "landingMention" || screen == "drawer" {
                XCTAssertFalse(app.images["folder.fill"].exists, "\(appearance) \(screen) still exposes SF folder.fill")
                XCTAssertFalse(app.images["folder"].exists, "\(appearance) \(screen) still exposes SF folder")
            }
            if screen == "landing" || screen == "landingPreset" || screen == "landingMention" {
                let officialOpen = app.descendants(matching: .any)["official.folderOpen"]
                let officialClose = app.descendants(matching: .any)["official.folderClose"]
                XCTAssertTrue(
                    officialOpen.waitForExistence(timeout: 8) || officialClose.waitForExistence(timeout: 2),
                    "\(appearance) \(screen) missing official workspace-chip folder glyph"
                )
                XCTAssertFalse(app.images["chevron.down"].exists, "\(appearance) \(screen) still exposes SF chevron.down")
                XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) \(screen) still exposes SF checkmark")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronDown"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official workspace-chip chevron"
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
                XCTAssertFalse(app.images["ellipsis"].exists, "\(appearance) drawer still exposes SF ellipsis")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.ellipsis"].waitForExistence(timeout: 8),
                    "\(appearance) drawer missing official workspace overflow ellipsis"
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
                assertNoConnectionDiagnostics(app, appearance: appearance, screen: screen)
            }
            if screen == "landing" || screen == "landingPreset" || screen == "landingMention" || screen == "chat" || screen == "chatLong" || screen == "changesCard" || screen == "planMode" || screen == "mention" || screen == "mentionFiltered" || screen == "mentionChip" || screen == "mentionSent" || screen == "turnTrigger" || screen == "composerStop" || screen == "slash" || screen == "models" || screen == "permission" || screen == "trajectory" {
                XCTAssertFalse(app.images["sidebar.left"].exists, "\(appearance) \(screen) still exposes SF sidebar.left")
                XCTAssertFalse(app.images["sidebar.right"].exists, "\(appearance) \(screen) still exposes SF sidebar.right")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.panelLeft"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official panel-left glyph"
                )
            }
            if screen == "landing" || screen == "landingPreset" || screen == "landingMention" || screen == "chat" || screen == "chatLong" || screen == "changesCard" || screen == "planMode" || screen == "mention" || screen == "mentionFiltered" || screen == "mentionChip" || screen == "mentionSent" || screen == "turnTrigger" || screen == "composerStop" || screen == "slash" || screen == "models" || screen == "permission" || screen == "trajectory" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.panelRight"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official panel-right glyph"
                )
            }
            if screen == "landing" || screen == "landingPreset" || screen == "landingMention" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["openStartPanel"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing openStartPanel"
                )
                let panelLeft = app.descendants(matching: .any)["official.panelLeft"].firstMatch
                let panelRight = app.descendants(matching: .any)["official.panelRight"].firstMatch
                XCTAssertTrue(panelLeft.waitForExistence(timeout: 8), "\(appearance) \(screen) panelLeft gone before alignment")
                XCTAssertTrue(panelRight.exists, "\(appearance) \(screen) panelRight gone before alignment")
                XCTAssertEqual(
                    panelLeft.frame.midY,
                    panelRight.frame.midY,
                    accuracy: 2,
                    "\(appearance) landing panelRight is not level with panelLeft"
                )
                let window = app.windows.firstMatch.frame
                XCTAssertGreaterThan(
                    panelRight.frame.minX,
                    (window.minX + window.maxX) / 2,
                    "\(appearance) landing panelRight is not on the right"
                )
            }
            if screen == "landing" || screen == "landingPreset" || screen == "landingMention" || screen == "chat" || screen == "chatLong" || screen == "changesCard" || screen == "planMode" || screen == "mention" || screen == "mentionFiltered" || screen == "mentionChip" || screen == "mentionSent" {
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
            if screen == "chat" || screen == "chatLong" {
                // Fixture: one user bubble + one assistant reply. Only the
                // assistant MessageIconActions row may carry copy.
                let copyButtons = app.buttons.matching(
                    NSPredicate(format: "label == '复制' OR label == 'Copy'")
                ).count
                XCTAssertLessThanOrEqual(
                    copyButtons,
                    1,
                    "\(appearance) \(screen) exposes \(copyButtons) copy buttons (user bubble copy is back)"
                )
                XCTAssertFalse(app.images["gauge.with.dots.needle.67percent"].exists, "\(appearance) \(screen) still exposes SF gauge")
                XCTAssertFalse(app.images["cylinder"].exists, "\(appearance) \(screen) still exposes SF cylinder")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.gaugeOutline"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official activity gauge glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.databaseOutline"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official usage database glyph"
                )
                XCTAssertTrue(
                    app.staticTexts["缓存命中 69%"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing cache-hit pill copy"
                )
                XCTAssertFalse(app.staticTexts["缓存命中中 69%"].exists, "\(appearance) \(screen) has extra 中 in cache-hit copy")
                assertComposerStatsCentered(app, appearance: appearance, composerId: "chatComposer")
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
                XCTAssertFalse(app.images["chevron.down"].exists, "\(appearance) plugins still exposes SF chevron.down")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.chevronDown"].waitForExistence(timeout: 8),
                    "\(appearance) plugins missing official add-menu chevron"
                )
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
            if screen == "landing" || screen == "landingPreset" || screen == "landingMention" {
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
            if screen == "landingPreset" {
                try assertLandingAgentPresetMenu(app, appearance: appearance)
            }
            if screen == "chat" || screen == "chatLong" || screen == "trajectory" {
                assertConversationHeaderTabGap(app, appearance: appearance, screen: screen)
            }
            if screen == "chat" || screen == "chatLong" || screen == "changesCard" || screen == "planMode" || screen == "mention" || screen == "mentionFiltered" || screen == "mentionChip" || screen == "mentionSent" || screen == "turnTrigger" || screen == "trajectory" {
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
            if screen == "schedule" || screen == "terminal" || screen == "files"
                || screen == "terminalUnavailable" || screen == "terminalMissing"
                || screen == "terminalDisconnected" || screen == "terminalExited"
                || screen == "terminalSwitcher" {
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
            if screen == "terminalUnavailable" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["terminalError"].waitForExistence(timeout: 8)
                        || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "终端错误：")).firstMatch.waitForExistence(timeout: 2),
                    "\(appearance) terminalUnavailable missing 终端错误 paragraph"
                )
                let status = app.descendants(matching: .any)["terminalStatus"].firstMatch
                XCTAssertTrue(status.waitForExistence(timeout: 8), "\(appearance) terminalUnavailable missing status row")
                let window = app.windows.firstMatch.frame
                XCTAssertEqual(
                    status.frame.minX,
                    window.minX + 12,
                    accuracy: 2,
                    "\(appearance) terminalUnavailable status minX \(status.frame.minX) is not 12pt from the window"
                )
                XCTAssertFalse(app.images["arrow.clockwise"].exists, "\(appearance) terminalUnavailable still exposes SF arrow.clockwise")
                XCTAssertFalse(app.images["keyboard"].exists, "\(appearance) terminalUnavailable still exposes SF keyboard")
                XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) terminalUnavailable still exposes SF checkmark")
                XCTAssertFalse(
                    app.descendants(matching: .any)["terminalKeyBar"].exists,
                    "\(appearance) terminalUnavailable still shows the key bar"
                )
            }
            if screen == "terminalMissing" {
                XCTAssertTrue(
                    app.staticTexts["此终端已不存在，请新建终端。"].waitForExistence(timeout: 8)
                        || app.descendants(matching: .any)["terminalMissing"].waitForExistence(timeout: 2),
                    "\(appearance) terminalMissing missing 此终端已不存在 copy"
                )
                XCTAssertTrue(
                    app.buttons["新建终端"].waitForExistence(timeout: 8)
                        || app.descendants(matching: .any)["terminalNew"].waitForExistence(timeout: 2),
                    "\(appearance) terminalMissing missing 新建终端"
                )
                XCTAssertFalse(
                    app.buttons["重新连接"].exists || app.staticTexts["重新连接"].exists,
                    "\(appearance) terminalMissing still offers 重新连接"
                )
            }
            if screen == "terminalDisconnected" {
                XCTAssertTrue(
                    app.staticTexts["连接已断开。"].waitForExistence(timeout: 8),
                    "\(appearance) terminalDisconnected missing 连接已断开。"
                )
                let screenNode = app.descendants(matching: .any)["terminalScreen"].firstMatch
                XCTAssertTrue(screenNode.waitForExistence(timeout: 8), "\(appearance) terminalDisconnected missing preserved screen")
                let value = (screenNode.value as? String) ?? screenNode.label
                XCTAssertTrue(
                    value.contains("preserved-shell-output"),
                    "\(appearance) terminalDisconnected lost the screen text (got \(value))"
                )
            }
            if screen == "terminalSwitcher" {
                let trigger = app.descendants(matching: .any)["terminalSwitcherButton"].firstMatch
                XCTAssertTrue(trigger.waitForExistence(timeout: 8), "\(appearance) terminalSwitcher missing title trigger")
                trigger.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["terminalSwitcherMenu"].waitForExistence(timeout: 8),
                    "\(appearance) terminalSwitcher missing custom MenuSurface"
                )
                XCTAssertTrue(app.staticTexts["终端会话"].waitForExistence(timeout: 4), "\(appearance) terminalSwitcher missing 终端会话")
                let first = app.descendants(matching: .any)["terminalSwitcher.row.term-a"].firstMatch
                let second = app.descendants(matching: .any)["terminalSwitcher.row.term-b"].firstMatch
                XCTAssertTrue(first.waitForExistence(timeout: 8), "\(appearance) terminalSwitcher missing first zsh row")
                XCTAssertTrue(second.waitForExistence(timeout: 4), "\(appearance) terminalSwitcher missing second zsh row")
                XCTAssertGreaterThanOrEqual(
                    app.staticTexts.matching(NSPredicate(format: "label == %@", "zsh")).count,
                    2,
                    "\(appearance) terminalSwitcher does not list 2+ terminals"
                )
                XCTAssertTrue(first.isSelected, "\(appearance) terminalSwitcher current row is not marked selected")
                XCTAssertFalse(second.isSelected, "\(appearance) terminalSwitcher marked the inactive zsh row")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.checkOutline"].exists,
                    "\(appearance) terminalSwitcher missing current-item check"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.terminalTab"].exists,
                    "\(appearance) terminalSwitcher missing desktop TerminalIcon"
                )
                XCTAssertTrue(app.buttons["新建终端"].exists, "\(appearance) terminalSwitcher missing 新建终端")
                XCTAssertTrue(app.buttons["关闭"].exists, "\(appearance) terminalSwitcher missing 关闭")
                XCTAssertFalse(
                    app.staticTexts["关闭终端？"].exists || app.buttons["关闭终端？"].exists,
                    "\(appearance) terminalSwitcher still shows 关闭终端？ confirmation"
                )
                XCTAssertFalse(app.images["terminal"].exists, "\(appearance) terminalSwitcher still exposes SF terminal")
                XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) terminalSwitcher still exposes SF checkmark")
                XCTAssertFalse(app.images["plus"].exists, "\(appearance) terminalSwitcher still exposes SF plus")
                XCTAssertFalse(app.images["xmark"].exists, "\(appearance) terminalSwitcher still exposes SF xmark")
            }
            if screen == "terminalExited" {
                XCTAssertTrue(
                    app.staticTexts["已停止"].waitForExistence(timeout: 8),
                    "\(appearance) terminalExited missing 已停止"
                )
                XCTAssertFalse(
                    app.staticTexts["运行中"].exists,
                    "\(appearance) terminalExited still shows 运行中"
                )
                XCTAssertTrue(
                    app.staticTexts["终端已退出。可从菜单切换会话或新建终端。"].waitForExistence(timeout: 8),
                    "\(appearance) terminalExited missing exit copy"
                )
                let keyBar = app.descendants(matching: .any)["terminalKeyBar"].firstMatch
                XCTAssertTrue(keyBar.waitForExistence(timeout: 8), "\(appearance) terminalExited missing key bar")
                let keys = keyBar.buttons.allElementsBoundByIndex
                XCTAssertFalse(keys.isEmpty, "\(appearance) terminalExited key bar has no keys")
                for key in keys {
                    XCTAssertFalse(
                        key.isEnabled,
                        "\(appearance) terminalExited key still enabled: \(key.label)"
                    )
                }
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
                assertNoConnectionDiagnostics(app, appearance: appearance, screen: screen)
                XCTAssertFalse(
                    app.descendants(matching: .any)["official.ellipsis"].exists,
                    "\(appearance) connections still exposes overflow ellipsis for 连接诊断"
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
            if screen == "chat" || screen == "chatLong" {
                XCTAssertFalse(app.images["hand.thumbsup"].exists, "\(appearance) \(screen) still exposes SF thumbsup")
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
                XCTAssertFalse(app.images["doc"].exists, "\(appearance) chat markdown fileChip still uses SF doc")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.markdownFileChip"].waitForExistence(timeout: 8),
                    "\(appearance) chat markdown fileChip missing official BrowseOutline asset"
                )
                XCTAssertTrue(
                    app.staticTexts["第一项"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing markdown list item 第一项"
                )
                XCTAssertTrue(
                    app.staticTexts["第二项"].exists,
                    "\(appearance) \(screen) missing markdown list item 第二项"
                )
                if screen == "chat" {
                    try assertUserBubbleHugsContent(
                        app,
                        appearance: appearance,
                        screen: screen,
                        maxScreenFraction: 0.45
                    )
                }
                if screen == "chatLong" {
                    try assertUserBubbleWrapsLongMessage(app, appearance: appearance)
                }
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "changesCard" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["changesCard"].waitForExistence(timeout: 8),
                    "\(appearance) changesCard missing desktop FileTypeIcon card"
                )
                XCTAssertTrue(
                    app.staticTexts["README.md"].waitForExistence(timeout: 8),
                    "\(appearance) changesCard missing README.md title"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.fileMarkdown"].waitForExistence(timeout: 8),
                    "\(appearance) changesCard missing official FileTypeIcon markdown glyph"
                )
                XCTAssertFalse(
                    app.images["doc.text"].exists,
                    "\(appearance) changesCard still exposes SF doc.text"
                )
                XCTAssertFalse(
                    app.images["doc.on.doc"].exists,
                    "\(appearance) changesCard still exposes SF doc.on.doc"
                )
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "files" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.codeFile.python"].waitForExistence(timeout: 8),
                    "\(appearance) files missing official python CodeFileIcon"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.codeFile.go"].exists,
                    "\(appearance) files missing official go CodeFileIcon"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.codeFile.swift"].exists,
                    "\(appearance) files missing official swift CodeFileIcon"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.codeFile.node"].exists,
                    "\(appearance) files missing official node CodeFileIcon"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.fileMarkdown"].exists,
                    "\(appearance) files missing official markdown FileGlyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.folderClose"].exists,
                    "\(appearance) files missing official closed folder"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.warningOutline"].exists,
                    "\(appearance) files missing official warning for non-file entries"
                )
                XCTAssertFalse(app.images["doc.fill"].exists, "\(appearance) files still exposes SF doc.fill")
                XCTAssertFalse(app.images["doc"].exists, "\(appearance) files still exposes SF doc")
                XCTAssertFalse(app.images["folder"].exists, "\(appearance) files still exposes SF folder")
                XCTAssertTrue(app.staticTexts["main.py"].exists, "\(appearance) files missing seeded python row")
                XCTAssertTrue(app.staticTexts["工作区文件"].waitForExistence(timeout: 8), "\(appearance) files missing 工作区文件 title")
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
            if screen == "settingsShell" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["settingsShell"].waitForExistence(timeout: 15),
                    "\(appearance) settingsShell missing"
                )
                XCTAssertFalse(app.images["cpu"].exists, "\(appearance) settingsShell still exposes SF cpu")
                XCTAssertFalse(
                    app.images["slider.horizontal.3"].exists,
                    "\(appearance) settingsShell still exposes SF slider"
                )
                XCTAssertFalse(
                    app.images["person.crop.circle"].exists,
                    "\(appearance) settingsShell still exposes SF person.crop.circle"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.dataOutline"].waitForExistence(timeout: 8),
                    "\(appearance) settingsShell missing IconDataOutlineMedium"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.settingsOutlineRegular"].exists,
                    "\(appearance) settingsShell missing official settings glyph"
                )
                XCTAssertTrue(
                    app.staticTexts["模型"].waitForExistence(timeout: 4)
                        || app.buttons["模型"].waitForExistence(timeout: 2),
                    "\(appearance) settingsShell missing 模型 row"
                )
                XCTAssertTrue(
                    app.staticTexts["通用设置"].exists || app.buttons["通用设置"].exists,
                    "\(appearance) settingsShell missing 通用设置 row"
                )
                XCTAssertTrue(
                    app.staticTexts["Agent 预设"].exists || app.buttons["Agent 预设"].exists,
                    "\(appearance) settingsShell missing Agent 预设 row"
                )
                XCTAssertTrue(
                    app.staticTexts["内置插件"].exists || app.buttons["内置插件"].exists,
                    "\(appearance) settingsShell missing 内置插件 row"
                )
                try assertSettingsShellGeometry(app, appearance: appearance)
                assertNoConnectionDiagnostics(app, appearance: appearance, screen: screen)
            }
            if screen == "chatDock" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["todoPanel"].waitForExistence(timeout: 15),
                    "\(appearance) chatDock missing todoPanel"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["goalBar"].waitForExistence(timeout: 8),
                    "\(appearance) chatDock missing goalBar"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["promptQueue"].waitForExistence(timeout: 8),
                    "\(appearance) chatDock missing promptQueue"
                )
                XCTAssertFalse(app.images["checklist"].exists, "\(appearance) chatDock still exposes SF checklist")
                XCTAssertFalse(app.images["target"].exists, "\(appearance) chatDock still exposes SF target")
                XCTAssertFalse(
                    app.images["text.line.first.and.arrowtriangle.forward"].exists,
                    "\(appearance) chatDock still exposes SF queue lines"
                )
                XCTAssertFalse(app.images["pencil"].exists, "\(appearance) chatDock still exposes SF pencil")
                XCTAssertFalse(app.images["trash"].exists, "\(appearance) chatDock still exposes SF trash")
                XCTAssertFalse(app.images["paperplane"].exists, "\(appearance) chatDock still exposes SF paperplane")
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.checklistOutline"].waitForExistence(timeout: 8),
                    "\(appearance) chatDock missing official checklistOutline"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.goalOutline"].exists,
                    "\(appearance) chatDock missing official goalOutline"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.queueOutline"].exists,
                    "\(appearance) chatDock missing official queueOutline"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.editOutline"].exists,
                    "\(appearance) chatDock missing official editOutline"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.trashOutline"].exists,
                    "\(appearance) chatDock missing official trashOutline"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.sendOutline"].exists,
                    "\(appearance) chatDock missing official sendOutline"
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
                assertNoConnectionDiagnostics(app, appearance: appearance, screen: screen)
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
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.paperclipOutline"].waitForExistence(timeout: 8),
                    "\(appearance) slash missing official paperclip"
                )
                XCTAssertTrue(app.descendants(matching: .any)["official.goalOutline"].exists, "\(appearance) slash missing official goal")
                XCTAssertTrue(app.descendants(matching: .any)["official.planOutline"].exists, "\(appearance) slash missing official plan")
                XCTAssertTrue(app.descendants(matching: .any)["official.paperPlaneOutline"].exists, "\(appearance) slash missing official paper plane")
                XCTAssertTrue(app.descendants(matching: .any)["official.compactOutline"].exists, "\(appearance) slash missing official compact")
                XCTAssertTrue(app.descendants(matching: .any)["official.permissionFullAccess"].exists, "\(appearance) slash missing official permission")
                XCTAssertTrue(app.descendants(matching: .any)["official.dataOutline"].exists, "\(appearance) slash missing official data")
                XCTAssertTrue(app.descendants(matching: .any)["official.downloadOutline"].exists, "\(appearance) slash missing official download")
                XCTAssertFalse(app.images["paperclip"].exists, "\(appearance) slash still uses SF paperclip")
                XCTAssertFalse(app.images["target"].exists, "\(appearance) slash still uses SF target")
                XCTAssertFalse(app.images["doc.text"].exists, "\(appearance) slash still uses SF doc.text")
                XCTAssertFalse(app.images["paperplane"].exists, "\(appearance) slash still uses SF paperplane")
                XCTAssertFalse(app.images["circle.circle"].exists, "\(appearance) slash still uses SF circle.circle")
                XCTAssertFalse(app.images["shield"].exists, "\(appearance) slash still uses SF shield")
                XCTAssertFalse(app.images["cylinder.split.1x2"].exists, "\(appearance) slash still uses SF cylinder")
                XCTAssertFalse(app.images["square.and.arrow.down"].exists, "\(appearance) slash still uses SF download")
                XCTAssertTrue(app.staticTexts["权限"].waitForExistence(timeout: 8), "\(appearance) slash missing 权限")
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
                try assertInputTriggerMenuHugsContent(
                    app,
                    identifier: "slashMenu",
                    appearance: appearance,
                    screen: screen,
                    maxWindowFraction: 0.55
                )
            }
            if screen == "models" {
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "permission" {
                assertOfficialMenuChrome(app, appearance: appearance, screen: screen)
            }
            if screen == "planMode" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.planOutline"].waitForExistence(timeout: 8),
                    "\(appearance) planMode missing official plan chip glyph"
                )
                XCTAssertFalse(app.images["doc.text"].exists, "\(appearance) planMode still uses SF doc.text")
                XCTAssertTrue(
                    app.staticTexts["计划"].waitForExistence(timeout: 8),
                    "\(appearance) planMode missing 计划 chip label"
                )
                let placeholder = app.descendants(matching: .any)["composerPlaceholder"]
                XCTAssertTrue(
                    placeholder.waitForExistence(timeout: 8),
                    "\(appearance) planMode missing composer placeholder"
                )
                XCTAssertTrue(
                    placeholder.label == "描述你的任务以生成计划"
                        || app.staticTexts["描述你的任务以生成计划"].exists,
                    "\(appearance) planMode placeholder is not desktop plan copy (got \(placeholder.label))"
                )
            }
            if screen == "turnTrigger" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["turnTrigger"].waitForExistence(timeout: 8),
                    "\(appearance) turnTrigger row missing"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.contextInjection"].waitForExistence(timeout: 8),
                    "\(appearance) turnTrigger missing IconContextInjectionOutline"
                )
                XCTAssertTrue(
                    app.staticTexts["收到执行请求"].waitForExistence(timeout: 8),
                    "\(appearance) turnTrigger missing desktop message.trigger.request"
                )
                XCTAssertFalse(app.images["bolt.horizontal"].exists, "\(appearance) turnTrigger still uses SF bolt.horizontal")
                XCTAssertFalse(app.images["clock.arrow.circlepath"].exists, "\(appearance) turnTrigger still uses SF clock.arrow.circlepath")
                XCTAssertFalse(app.images["person.crop.circle"].exists, "\(appearance) turnTrigger still uses SF person.crop.circle")
                XCTAssertFalse(app.images["target"].exists, "\(appearance) turnTrigger still uses SF target")
            }
            if screen == "filePreview" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.wrapFill"].waitForExistence(timeout: 8),
                    "\(appearance) filePreview missing official wrapFill"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.copyOutline"].exists,
                    "\(appearance) filePreview missing official copyOutline"
                )
                XCTAssertFalse(app.images["text.alignleft"].exists, "\(appearance) filePreview still uses SF text.alignleft")
                XCTAssertFalse(app.images["text.justify.leading"].exists, "\(appearance) filePreview still uses SF text.justify.leading")
                XCTAssertFalse(app.images["square.on.square"].exists, "\(appearance) filePreview still uses SF square.on.square")
                XCTAssertTrue(app.staticTexts["main.py"].waitForExistence(timeout: 8), "\(appearance) filePreview missing main.py")
            }
            if screen == "mention" || screen == "landingMention" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["mentionMenu"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing desktop mentionMenu"
                )
                try assertInputTriggerMenuHugsContent(
                    app,
                    identifier: "mentionMenu",
                    appearance: appearance,
                    screen: screen,
                    maxWindowFraction: 0.42
                )
                XCTAssertTrue(
                    app.staticTexts["文件与文件夹"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing desktop Files & folders header"
                )
                XCTAssertTrue(
                    app.staticTexts["对话"].exists,
                    "\(appearance) \(screen) missing desktop Sessions header"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.queueOutline"].waitForExistence(timeout: 8),
                    "\(appearance) \(screen) missing official session ChatLines glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.browseOutline"].exists,
                    "\(appearance) \(screen) missing official file Browse glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.folderClose"].exists,
                    "\(appearance) \(screen) missing official folder Close glyph"
                )
                XCTAssertFalse(app.images["bubble.left"].exists, "\(appearance) \(screen) still uses SF bubble.left")
                XCTAssertFalse(app.images["doc"].exists, "\(appearance) \(screen) still uses SF doc")
            }
            if screen == "mentionFiltered" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["mentionMenu"].waitForExistence(timeout: 8),
                    "\(appearance) mentionFiltered missing desktop mentionMenu"
                )
                try assertInputTriggerMenuHugsContent(
                    app,
                    identifier: "mentionMenu",
                    appearance: appearance,
                    screen: screen,
                    maxWindowFraction: 0.32
                )
                XCTAssertTrue(
                    app.staticTexts["README.md"].waitForExistence(timeout: 8),
                    "\(appearance) mentionFiltered missing README.md row"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.browseOutline"].exists,
                    "\(appearance) mentionFiltered missing official file Browse glyph"
                )
                XCTAssertFalse(
                    app.descendants(matching: .any)["official.queueOutline"].exists,
                    "\(appearance) mentionFiltered still shows session rows when the query is a file prefix"
                )
            }
            if screen == "mentionChip" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["mentionChip.session"].waitForExistence(timeout: 8),
                    "\(appearance) mentionChip missing composer session chip"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.queueOutline"].exists,
                    "\(appearance) mentionChip missing official session ChatLines glyph"
                )
                XCTAssertFalse(
                    app.descendants(matching: .any)["mentionMenu"].exists,
                    "\(appearance) mentionChip still shows the menu after a committed chip"
                )
            }
            if screen == "mentionSent" {
                XCTAssertTrue(
                    app.descendants(matching: .any)["userMentionText"].waitForExistence(timeout: 8),
                    "\(appearance) mentionSent missing userMentionText"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["mentionChip.session"].exists,
                    "\(appearance) mentionSent missing session chip"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["mentionChip.file"].exists,
                    "\(appearance) mentionSent missing file chip"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.queueOutline"].exists,
                    "\(appearance) mentionSent missing official session ChatLines glyph"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.browseOutline"].exists,
                    "\(appearance) mentionSent missing official file Browse glyph"
                )
                XCTAssertFalse(
                    app.staticTexts["@[你好](dsh-session:s-hello)"].exists,
                    "\(appearance) mentionSent still shows raw session markdown"
                )
                try assertUserBubbleHugsContent(
                    app,
                    appearance: appearance,
                    screen: screen,
                    maxScreenFraction: 0.82
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
            if screen == "connections" {
                try assertManageSheet(app, appearance: appearance)
                try assertPairingLinkSheet(app, appearance: appearance)
            }
            if screen == "models" {
                try assertModelReleaseBadgeTracksSelection(app, appearance: appearance)
            }
            if screen == "slash" {
                let permission = app.staticTexts["权限"]
                XCTAssertTrue(permission.waitForExistence(timeout: 8), "\(appearance) slash missing 权限 after shot")
                permission.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["official.checkOutline"].waitForExistence(timeout: 8),
                    "\(appearance) slash permission missing official check"
                )
                XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) slash still uses SF checkmark")
            }
            if screen == "start" || screen == "startLanding" || screen == "browser" || screen == "inspector" {
                let back = app.buttons["navBack"]
                XCTAssertTrue(back.waitForExistence(timeout: 4), "\(appearance) \(screen) back gone before tap")
                back.tap()
                let surfaceId = (screen == "start" || screen == "startLanding")
                    ? "startPanel"
                    : (screen == "browser" ? "browserPanel" : "sessionInspector")
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
        assertNoConnectionDiagnostics(app, appearance: appearance, screen: "connections")
    }

    private func unionAccessibilityFrame(_ app: XCUIApplication, identifier: String) -> CGRect {
        let query = app.descendants(matching: .any).matching(identifier: identifier)
        var frame = CGRect.null
        for i in 0..<query.count {
            frame = frame.union(query.element(boundBy: i).frame)
        }
        return frame
    }

    /// Desktop `SettingsRoot.module.css` `.nav` gap 18, `.navCell` height 40,
    /// icon↔label gap 8. Phone header identifier is the full title bar so the
    /// measured gap is bar → card (not title-glyph box → card).
    private func assertSettingsShellGeometry(_ app: XCUIApplication, appearance: String) throws {
        let header = app.descendants(matching: .any)["settingsShellHeader"].firstMatch
        XCTAssertTrue(
            header.waitForExistence(timeout: 8),
            "\(appearance) settingsShell missing settingsShellHeader"
        )
        let card = app.descendants(matching: .any)["settingsNavCard"].firstMatch
        XCTAssertTrue(
            card.waitForExistence(timeout: 8),
            "\(appearance) settingsShell missing settingsNavCard"
        )
        let gap = card.frame.minY - header.frame.maxY
        XCTAssertEqual(
            gap,
            18,
            accuracy: 2,
            "\(appearance) settingsShell header-to-card gap \(gap) is not desktop .nav gap 18 (header \(header.frame) card \(card.frame))"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settingsNavRow.general"].waitForExistence(timeout: 8),
            "\(appearance) settingsShell missing settingsNavRow.general"
        )
        let general = unionAccessibilityFrame(app, identifier: "settingsNavRow.general")
        XCTAssertFalse(
            general.isNull,
            "\(appearance) settingsShell settingsNavRow.general frame is empty"
        )
        XCTAssertEqual(
            general.height,
            40,
            accuracy: 2,
            "\(appearance) settingsShell general row height \(general.height) is not desktop .navCell 40 (\(general))"
        )
        let models = unionAccessibilityFrame(app, identifier: "settingsNavRow.models")
        XCTAssertFalse(models.isNull, "\(appearance) settingsShell missing settingsNavRow.models")
        XCTAssertEqual(
            models.height,
            40,
            accuracy: 2,
            "\(appearance) settingsShell models row height \(models.height) is not desktop .navCell 40 (\(models))"
        )
        let icon = app.descendants(matching: .any)["official.settingsOutlineRegular"].firstMatch
        XCTAssertTrue(icon.exists, "\(appearance) settingsShell missing general icon for gap")
        let label = app.staticTexts["通用设置"].firstMatch
        XCTAssertTrue(label.exists, "\(appearance) settingsShell missing 通用设置 label for gap")
        let iconLabelGap = label.frame.minX - icon.frame.maxX
        XCTAssertEqual(
            iconLabelGap,
            8,
            accuracy: 2,
            "\(appearance) settingsShell icon-label gap \(iconLabelGap) is not desktop .navCell gap 8 (icon \(icon.frame) label \(label.frame))"
        )
        XCTAssertGreaterThan(
            header.frame.height,
            24,
            "\(appearance) settingsShell header height \(header.frame.height) collapsed under .navTitle line-height 24"
        )
        try assertSettingsNavCardCornersMatchPage(app, appearance: appearance, card: card)
    }

    /// Bounding-box corners sit outside `--dsw-radius-lg` 16. Those pixels
    /// must be page `--dsw-alias-bg-base` (21,21,23 dark / 255,255,255 light),
    /// not unclipped settings-card fill (44,44,46 dark).
    private func assertSettingsNavCardCornersMatchPage(
        _ app: XCUIApplication,
        appearance: String,
        card: XCUIElement
    ) throws {
        let shot = XCUIScreen.main.screenshot()
        let pagePoint = CGPoint(x: card.frame.midX, y: card.frame.minY - 8)
        XCTAssertGreaterThan(
            pagePoint.y,
            0,
            "\(appearance) settingsShell card is flush with the top; cannot sample page above the curve"
        )
        let page = try screenshotPixel(shot, at: pagePoint)
        let expected = appearance == "Dark"
            ? (r: 21, g: 21, b: 23)
            : (r: 255, g: 255, b: 255)
        XCTAssertLessThanOrEqual(
            abs(page.r - expected.r), 12,
            "\(appearance) settingsShell page sample at \(pagePoint) r=\(page.r) is not desktop bg-base \(expected)"
        )
        XCTAssertLessThanOrEqual(
            abs(page.g - expected.g), 12,
            "\(appearance) settingsShell page sample at \(pagePoint) g=\(page.g) is not desktop bg-base \(expected)"
        )
        XCTAssertLessThanOrEqual(
            abs(page.b - expected.b), 12,
            "\(appearance) settingsShell page sample at \(pagePoint) b=\(page.b) is not desktop bg-base \(expected)"
        )
        let inset: CGFloat = 1
        let corners = [
            CGPoint(x: card.frame.minX + inset, y: card.frame.minY + inset),
            CGPoint(x: card.frame.maxX - inset, y: card.frame.minY + inset),
            CGPoint(x: card.frame.minX + inset, y: card.frame.maxY - inset),
            CGPoint(x: card.frame.maxX - inset, y: card.frame.maxY - inset),
        ]
        for corner in corners {
            let pixel = try screenshotPixel(shot, at: corner)
            XCTAssertLessThanOrEqual(
                abs(pixel.r - page.r), 10,
                "\(appearance) settingsShell corner \(corner) r=\(pixel.r) is not page \(page) — card fill is not clipped to radius-lg 16"
            )
            XCTAssertLessThanOrEqual(
                abs(pixel.g - page.g), 10,
                "\(appearance) settingsShell corner \(corner) g=\(pixel.g) is not page \(page) — card fill is not clipped to radius-lg 16"
            )
            XCTAssertLessThanOrEqual(
                abs(pixel.b - page.b), 10,
                "\(appearance) settingsShell corner \(corner) b=\(pixel.b) is not page \(page) — card fill is not clipped to radius-lg 16"
            )
        }
    }

    private func screenshotPixel(_ screenshot: XCUIScreenshot, at point: CGPoint) throws -> (r: Int, g: Int, b: Int) {
        let image = screenshot.image
        guard let cgImage = image.cgImage else {
            throw ScreenshotPixelError.missingImage
        }
        let x = Int((point.x * image.scale).rounded())
        let y = Int((point.y * image.scale).rounded())
        guard x >= 0, y >= 0, x < cgImage.width, y < cgImage.height else {
            throw ScreenshotPixelError.outOfBounds(point: point, size: CGSize(width: cgImage.width, height: cgImage.height))
        }
        guard let crop = cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            throw ScreenshotPixelError.outOfBounds(point: point, size: CGSize(width: cgImage.width, height: cgImage.height))
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ScreenshotPixelError.missingColorSpace
        }
        guard let ctx = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenshotPixelError.missingContext
        }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    /// 「连接诊断」/ Copy diagnostic report must stay off every surface that
    /// used to host it. 「会话数据诊断」is a different feature.
    private func assertNoConnectionDiagnostics(_ app: XCUIApplication, appearance: String, screen: String) {
        for label in ["连接诊断", "复制诊断报告", "Connection diagnostics", "Copy diagnostic report"] {
            XCTAssertFalse(
                app.staticTexts[label].exists || app.buttons[label].exists || app.menuItems[label].exists,
                "\(appearance) \(screen) still exposes \(label)"
            )
        }
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
        let field = app.descendants(matching: .any)["connectionsPairingLinkField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4), "\(appearance) pairing-link field missing")
        let bounds = app.descendants(matching: .any)["connectionsPairingLinkFieldBounds"].firstMatch
        XCTAssertTrue(
            bounds.waitForExistence(timeout: 4),
            "\(appearance) pairing-link field bounds missing"
        )
        let fieldFrame = bounds.frame
        let pasteFrame = paste.firstMatch.frame
        let nextFrame = next.firstMatch.frame
        XCTAssertEqual(
            fieldFrame.minX,
            pasteFrame.minX,
            accuracy: 1,
            "\(appearance) pairing field minX \(fieldFrame.minX) != 粘贴链接 minX \(pasteFrame.minX)"
        )
        XCTAssertEqual(
            fieldFrame.maxX,
            nextFrame.maxX,
            accuracy: 1,
            "\(appearance) pairing field maxX \(fieldFrame.maxX) != 下一步 maxX \(nextFrame.maxX)"
        )
        let hintGap = fieldFrame.minY - hint.frame.maxY
        XCTAssertLessThanOrEqual(
            hintGap,
            24,
            "\(appearance) pairing field minY \(fieldFrame.minY) is \(hintGap)pt below hint maxY \(hint.frame.maxY)"
        )
        XCTAssertEqual(
            pasteFrame.minY - fieldFrame.maxY,
            14,
            accuracy: 4,
            "\(appearance) 粘贴链接 minY \(pasteFrame.minY) is \(pasteFrame.minY - fieldFrame.maxY)pt below field maxY \(fieldFrame.maxY), not Android button-row vertical 14"
        )
        let pairingTexts = app.staticTexts.matching(NSPredicate(format: "label == %@", "配对链接"))
        var titleMinX: CGFloat?
        var labelMinX: CGFloat?
        for index in 0..<pairingTexts.count {
            let frame = pairingTexts.element(boundBy: index).frame
            if frame.maxY <= hint.frame.minY + 1 {
                titleMinX = frame.minX
            } else if frame.minY >= hint.frame.maxY - 1 && frame.minY < fieldFrame.maxY {
                labelMinX = frame.minX
            }
        }
        let titleX = try XCTUnwrap(titleMinX, "\(appearance) pairing-link sheet title missing")
        let labelX = try XCTUnwrap(labelMinX, "\(appearance) pairing-link field label missing")
        XCTAssertEqual(
            labelX,
            titleX,
            accuracy: 1,
            "\(appearance) pairing field label minX \(labelX) != title minX \(titleX)"
        )
        XCTAssertFalse(next.firstMatch.isEnabled, "\(appearance) 下一步 enabled on empty pairing link")
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

    /// Desktop `InputBar.module.css` `.dock { justify-content: center }`.
    /// Measure the first/last pill so a full-width `maxWidth` container cannot
    /// satisfy a start-aligned row.
    private func assertComposerStatsCentered(
        _ app: XCUIApplication,
        appearance: String,
        composerId: String
    ) {
        let composer = app.descendants(matching: .any)[composerId].firstMatch
        XCTAssertTrue(
            composer.waitForExistence(timeout: 8),
            "\(appearance) missing \(composerId)"
        )
        let stats = app.descendants(matching: .any)["composerStats"].firstMatch
        XCTAssertTrue(
            stats.waitForExistence(timeout: 8),
            "\(appearance) missing composerStats under \(composerId)"
        )
        let leading = app.descendants(matching: .any)["official.gaugeOutline"].firstMatch
        let trailing = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "上下文已用 2%")
        ).firstMatch
        XCTAssertTrue(leading.exists, "\(appearance) composerStats missing leading gauge")
        XCTAssertTrue(
            trailing.waitForExistence(timeout: 8),
            "\(appearance) composerStats missing context meter"
        )
        let rowMidX = (leading.frame.minX + trailing.frame.maxX) / 2
        XCTAssertEqual(
            rowMidX,
            composer.frame.midX,
            accuracy: 1,
            "\(appearance) composerStats midX \(rowMidX) is not centered on \(composerId) midX \(composer.frame.midX) (pills \(leading.frame.minX)–\(trailing.frame.maxX) vs composer \(composer.frame))"
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

        // 4caed96 `*-models.png`: the picker sits on top of the composer
        // (placeholder peeks from behind the menu). `modelChip` and
        // `modelReleaseBadge` stay in the tree while the popover is open,
        // so waiting on them does not mean the menu has dismissed.
        // `minHeight: 30` on the title row lowers the chip — and the
        // popover with it — over the composer, so tap/typeText races AX.
        // Do not put an identifier on the picker VStack: SwiftUI copies it
        // onto the 模型 / 推理等级 rows and hides `modelPickerModel`.
        // `PopoverDismissRegion` is the system overlay the failure dump
        // already showed. Same 8s budget as every other wait; not a retry.
        let popover = app.descendants(matching: .any)["PopoverDismissRegion"]
        XCTAssertTrue(
            popover.waitForNonExistence(timeout: 8),
            "\(appearance) model picker still covering composer after Flash pick"
        )

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
        let inputFrame = input.frame
        XCTAssertTrue(
            inputFrame.minX.isFinite && inputFrame.minY.isFinite
                && inputFrame.width.isFinite && inputFrame.height.isFinite
                && inputFrame.width > 1 && inputFrame.height > 1,
            "\(appearance) composer input frame is not hittable (\(inputFrame))"
        )
        XCTAssertTrue(
            input.isHittable,
            "\(appearance) composer input is not hittable after picker dismiss (\(inputFrame))"
        )
        input.tap()
        // `input.typeText` re-queries composerInput after the keyboard is
        // up; that AX snapshot is what hung (4caed96 / a57438b / 9b899f3).
        // Type into the focused field instead. Draft assertion stays
        // `contains("保留草稿")` — same strictness, no retry/skip.
        app.typeText("保留草稿")
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

    /// Desktop title-text → tabs is 15. Header keeps the 2a39d41 20pt
    /// vertical budget (`padding.top` 5 + `padding.bottom` 15) so the
    /// composer column is not shorter.
    private func assertConversationHeaderTabGap(
        _ app: XCUIApplication,
        appearance: String,
        screen: String
    ) {
        let title = app.descendants(matching: .any)["conversationHeaderTitle"].firstMatch
        XCTAssertTrue(
            title.waitForExistence(timeout: 8),
            "\(appearance) \(screen) missing conversationHeaderTitle before tab-gap assertion"
        )
        let chatTab = app.descendants(matching: .any)["chatTab.chat"].firstMatch
        XCTAssertTrue(
            chatTab.waitForExistence(timeout: 8),
            "\(appearance) \(screen) missing chatTab.chat"
        )
        let gap = chatTab.frame.minY - title.frame.maxY
        XCTAssertEqual(
            gap,
            15,
            accuracy: 3,
            "\(appearance) \(screen) title-to-tab gap \(gap) is not desktop titleRow 30/20 leftover + tabs margin-top 10 (title \(title.frame) tab \(chatTab.frame))"
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

    private func assertLandingAgentPresetMenu(_ app: XCUIApplication, appearance: String) throws {
        var seat = app.descendants(matching: .any)["agentPresetSeat"].firstMatch
        if !seat.waitForExistence(timeout: 8) {
            seat = app.buttons["极简模式"].firstMatch
        }
        XCTAssertTrue(seat.waitForExistence(timeout: 8), "\(appearance) landingPreset missing agentPresetSeat")
        XCTAssertTrue(
            seat.label.contains("极简模式") || app.staticTexts["极简模式"].exists || app.buttons["极简模式"].exists,
            "\(appearance) landingPreset seat is not 极简模式 (got \(seat.label))"
        )
        seat.tap()
        let menu = app.descendants(matching: .any)["agentPresetMenu"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 8), "\(appearance) landingPreset missing agentPresetMenu")
        XCTAssertFalse(
            app.sheets.firstMatch.exists || app.alerts.firstMatch.exists,
            "\(appearance) landingPreset opened a system sheet/ActionSheet"
        )
        XCTAssertFalse(app.buttons["取消"].exists, "\(appearance) landingPreset still exposes system Cancel")
        let ids = ["standard", "ptc", "minimal", "cordis"]
        let titles = ["标准模式", "PTC 模式", "极简模式", "创造模式"]
        let descriptions = [
            "处理代码、文件和资料，适合大多数任务。Agent 会按需使用检索、编辑和终端等工具。",
            "包含标准模式的所有能力，更适合批量调用工具，并对结果进行筛选、整理、去重、统计或汇总的任务。",
            "Agent 仅使用终端工具完成任务，适合测试和对比其基础表现。",
            "用对话定制 DSH：让 Agent 编写插件，添加新功能或界面；也能组合工具和提示词，创建自己的模式。",
        ]
        let menuFrame = menu.frame
        XCTAssertGreaterThan(menuFrame.height, 200, "\(appearance) landingPreset menu is too short to hold four rows (\(menuFrame))")
        XCTAssertLessThan(
            menuFrame.height,
            app.windows.firstMatch.frame.height - 20,
            "\(appearance) landingPreset menu stretched to the window (\(menuFrame))"
        )
        var firstTop = CGFloat.greatestFiniteMagnitude
        var lastBottom: CGFloat = 0
        for (index, id) in ids.enumerated() {
            let row = app.descendants(matching: .any)["agentPresetRow.\(id)"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 4), "\(appearance) landingPreset missing row \(id)")
            var title = app.descendants(matching: .any)["agentPresetTitle.\(id)"].firstMatch
            if !title.waitForExistence(timeout: 2) {
                title = app.staticTexts[titles[index]].firstMatch
            }
            var desc = app.descendants(matching: .any)["agentPresetDesc.\(id)"].firstMatch
            if !desc.waitForExistence(timeout: 2) {
                desc = app.staticTexts[descriptions[index]].firstMatch
            }
            XCTAssertTrue(title.waitForExistence(timeout: 2), "\(appearance) landingPreset missing title \(id)")
            XCTAssertTrue(desc.waitForExistence(timeout: 2), "\(appearance) landingPreset missing description \(id)")
            XCTAssertTrue(
                title.label.contains(titles[index])
                    || title.label == titles[index]
                    || app.staticTexts[titles[index]].exists,
                "\(appearance) landingPreset title \(id) is not \(titles[index]) (got \(title.label))"
            )
            let descText = desc.label.isEmpty ? (desc.value as? String ?? "") : desc.label
            XCTAssertTrue(
                descText == descriptions[index] || app.staticTexts[descriptions[index]].exists,
                "\(appearance) landingPreset description \(id) was truncated (got \(descText))"
            )
            XCTAssertFalse(title.frame.isEmpty, "\(appearance) landingPreset title \(id) has an empty frame")
            XCTAssertFalse(desc.frame.isEmpty, "\(appearance) landingPreset description \(id) has an empty frame")
            XCTAssertGreaterThanOrEqual(
                title.frame.minY,
                menuFrame.minY - 1,
                "\(appearance) landingPreset title \(id) is clipped above the card (\(title.frame) vs \(menuFrame))"
            )
            XCTAssertLessThanOrEqual(
                title.frame.maxY,
                menuFrame.maxY + 1,
                "\(appearance) landingPreset title \(id) is clipped below the card (\(title.frame) vs \(menuFrame))"
            )
            XCTAssertGreaterThanOrEqual(
                desc.frame.minY,
                menuFrame.minY - 1,
                "\(appearance) landingPreset description \(id) is clipped above the card (\(desc.frame) vs \(menuFrame))"
            )
            XCTAssertLessThanOrEqual(
                desc.frame.maxY,
                menuFrame.maxY + 1,
                "\(appearance) landingPreset description \(id) is clipped below the card (\(desc.frame) vs \(menuFrame))"
            )
            XCTAssertGreaterThanOrEqual(
                title.frame.minX,
                menuFrame.minX - 1,
                "\(appearance) landingPreset title \(id) is clipped on the left (\(title.frame) vs \(menuFrame))"
            )
            XCTAssertLessThanOrEqual(
                desc.frame.maxX,
                menuFrame.maxX + 1,
                "\(appearance) landingPreset description \(id) is clipped on the right (\(desc.frame) vs \(menuFrame))"
            )
            firstTop = min(firstTop, title.frame.minY)
            lastBottom = max(lastBottom, desc.frame.maxY)
        }
        XCTAssertLessThanOrEqual(
            lastBottom - firstTop,
            menuFrame.height + 1,
            "\(appearance) landingPreset rows overflow the card and would scroll (\(firstTop)–\(lastBottom) vs \(menuFrame))"
        )
        XCTAssertGreaterThan(
            menu.frame.maxY,
            seat.frame.maxY,
            "\(appearance) landingPreset menu is not below the seat (desktop Menu side:bottom)"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["official.checkOutline"].waitForExistence(timeout: 4),
            "\(appearance) landingPreset missing official check on 极简模式"
        )
        XCTAssertFalse(app.images["checkmark"].exists, "\(appearance) landingPreset still exposes SF checkmark")
    }

    private func assertInputTriggerMenuHugsContent(
        _ app: XCUIApplication,
        identifier: String,
        appearance: String,
        screen: String,
        maxWindowFraction: CGFloat
    ) throws {
        let menu = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(
            menu.waitForExistence(timeout: 8),
            "\(appearance) \(screen) missing \(identifier)"
        )
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(
            menu.frame.height,
            40,
            "\(appearance) \(screen) \(identifier) collapsed (\(menu.frame) vs \(window))"
        )
        XCTAssertLessThan(
            menu.frame.height,
            window.height * maxWindowFraction,
            "\(appearance) \(screen) \(identifier) stretched to fill leftover height (\(menu.frame) vs \(window))"
        )
        XCTAssertLessThanOrEqual(
            menu.frame.height,
            424,
            "\(appearance) \(screen) \(identifier) exceeded desktop MenuView max-height 400 (\(menu.frame))"
        )
    }

    private func assertUserBubbleHugsContent(
        _ app: XCUIApplication,
        appearance: String,
        screen: String,
        maxScreenFraction: CGFloat
    ) throws {
        let bubble = app.descendants(matching: .any)["userMessageBubble"].firstMatch
        XCTAssertTrue(
            bubble.waitForExistence(timeout: 8),
            "\(appearance) \(screen) missing userMessageBubble"
        )
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(
            bubble.frame.width,
            window.width * maxScreenFraction,
            "\(appearance) \(screen) user bubble width \(bubble.frame.width) is not hugging content (window \(window.width))"
        )
        XCTAssertGreaterThan(
            bubble.frame.minX,
            window.maxX - window.width * maxScreenFraction - 40,
            "\(appearance) \(screen) user bubble is not trailing-aligned (\(bubble.frame) vs \(window))"
        )
        XCTAssertLessThan(
            window.maxX - bubble.frame.maxX,
            40,
            "\(appearance) \(screen) user bubble is not near the trailing edge (\(bubble.frame) vs \(window))"
        )
    }

    private func assertUserBubbleWrapsLongMessage(_ app: XCUIApplication, appearance: String) throws {
        let bubble = app.descendants(matching: .any)["userMessageBubble"].firstMatch
        XCTAssertTrue(
            bubble.waitForExistence(timeout: 8),
            "\(appearance) chatLong missing userMessageBubble"
        )
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(
            bubble.frame.width,
            window.width * 0.5,
            "\(appearance) chatLong bubble \(bubble.frame.width) did not use the desktop max width"
        )
        XCTAssertLessThanOrEqual(
            bubble.frame.width,
            window.width * 0.85,
            "\(appearance) chatLong bubble \(bubble.frame.width) stretched past the desktop 82% cap"
        )
        XCTAssertGreaterThan(
            bubble.frame.height,
            44,
            "\(appearance) chatLong bubble \(bubble.frame.height) did not wrap into multiple lines"
        )
        XCTAssertGreaterThan(
            bubble.frame.minX,
            window.minX + 24,
            "\(appearance) chatLong bubble is not trailing-capped (\(bubble.frame) vs \(window))"
        )
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

private enum ScreenshotPixelError: Error, CustomStringConvertible {
    case missingImage
    case missingColorSpace
    case missingContext
    case outOfBounds(point: CGPoint, size: CGSize)

    var description: String {
        switch self {
        case .missingImage:
            return "screenshot has no CGImage"
        case .missingColorSpace:
            return "sRGB color space is unavailable"
        case .missingContext:
            return "cannot create a 1×1 pixel context"
        case .outOfBounds(let point, let size):
            return "pixel \(point) is outside screenshot \(size)"
        }
    }
}
