import XCTest

final class SessionDrawerPagingUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testFlatListRevealsEveryBatchWithoutManualPaging() {
        let app = launch(workspace: false)
        let list = app.scrollViews["sessionList"]
        XCTAssertTrue(app.buttons["sessionRow.paging-pinned"].isHittable)
        XCTAssertFalse(app.buttons["sessionRow.paging-a-30"].exists, "Do not render the whole roster at launch")
        assertNoManualPaging(app)
        XCTAssertFalse(app.buttons["收起"].exists)
        reveal("paging-a-6", in: app, list: list)
        reveal("paging-a-16", in: app, list: list)
        reveal("paging-a-30", in: app, list: list)
        reveal("paging-b-6", in: app, list: list)
        reveal("paging-b-30", in: app, list: list)
        reveal("paging-c-12", in: app, list: list)
        reveal("paging-running", in: app, list: list)
        XCTAssertFalse(app.buttons["sessionRow.paging-archived-1"].exists)
        assertNoManualPaging(app)
        capture(app, name: "drawer-paging-flat")
    }

    func testWorkspacePagingIsViewportDrivenAndDoesNotOpenCollapsedGroups() {
        let app = launch(workspace: true)
        let list = app.scrollViews["sessionList"]
        XCTAssertFalse(app.buttons["sessionRow.paging-a-30"].exists)
        XCTAssertFalse(app.buttons["sessionRow.paging-b-30"].exists, "A non-lazy group must not exhaust every page from onAppear")
        XCTAssertFalse(app.buttons["sessionRow.paging-c-1"].exists)
        reveal("paging-a-6", in: app, list: list)
        reveal("paging-a-16", in: app, list: list)
        reveal("paging-a-30", in: app, list: list)
        reveal("paging-running", in: app, list: list)
        reveal("paging-b-6", in: app, list: list)
        reveal("paging-b-16", in: app, list: list)
        reveal("paging-b-30", in: app, list: list)
        let collapsed = app.buttons["workspaceIcon.paging-c"]
        scroll(until: collapsed, in: list)
        XCTAssertTrue(collapsed.isHittable)
        XCTAssertEqual(collapsed.label, "展开")
        XCTAssertFalse(app.buttons["sessionRow.paging-c-1"].exists)
        assertNoManualPaging(app)

        // A workspace's own collapse/expand remains independent of pagination.
        collapsed.tap()
        reveal("paging-c-6", in: app, list: list)
        reveal("paging-c-12", in: app, list: list)
        capture(app, name: "drawer-paging-workspace")
        scroll(until: collapsed, in: list, upwards: false)
        collapsed.tap()
        XCTAssertFalse(app.buttons["sessionRow.paging-c-1"].exists)
    }

    func testGroupingArchiveAndSearchChangesKeepTheirOwnRows() {
        let app = launch(workspace: false)
        let list = app.scrollViews["sessionList"]
        reveal("paging-a-16", in: app, list: list)
        scroll(until: app.buttons["sessionRow.paging-pinned"], in: list, upwards: false)
        choose("按工作区", in: app)
        XCTAssertTrue(app.buttons["workspaceIcon.paging-a"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sessionRow.paging-b-30"].exists)
        XCTAssertFalse(app.buttons["sessionRow.paging-c-1"].exists)
        reveal("paging-a-6", in: app, list: list)
        scroll(until: app.buttons["sessionRow.paging-pinned"], in: list, upwards: false)
        choose("仅显示已归档", in: app)
        reveal("paging-archived-6", in: app, list: list)
        reveal("paging-archived-12", in: app, list: list)
        XCTAssertFalse(app.buttons["sessionRow.paging-a-1"].exists)
        XCTAssertFalse(app.buttons["sessionRow.paging-pinned"].exists)
        choose("隐藏已归档", in: app)
        scroll(until: app.buttons["sessionRow.paging-pinned"], in: list, upwards: false)
        let search = app.textFields["sessionSearch"]
        search.tap()
        search.typeText("B 会话 30")
        let match = app.buttons["sessionRow.paging-b-30"]
        XCTAssertTrue(match.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sessionRow.paging-a-1"].exists)
        XCTAssertFalse(app.buttons["sessionRow.paging-archived-1"].exists)
        app.buttons["清除搜索"].tap()
        XCTAssertTrue(app.buttons["workspaceIcon.paging-a"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sessionRow.paging-c-1"].exists)
        XCTAssertTrue(app.buttons["sessionRowMore"].firstMatch.exists, "Keep ordinary session action menus")
        assertNoManualPaging(app)
        capture(app, name: "drawer-paging-filtered")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let root = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"] {
            do {
                let directory = URL(fileURLWithPath: root, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
            } catch { XCTFail("Could not export drawer pagination screenshot: \(error)") }
        }
    }

    private func launch(workspace: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestFixture", "-UITestScreen",
            workspace ? "sessionDrawerPagingWorkspace" : "sessionDrawerPagingFlat",
        ]
        app.launch()
        XCTAssertTrue(app.scrollViews["sessionList"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ id: String, in app: XCUIApplication, list: XCUIElement) {
        let row = app.buttons["sessionRow.\(id)"]
        scroll(until: row, in: list)
        XCTAssertTrue(row.isHittable, "Scrolling should reveal \(id) without a load button")
        XCTAssertEqual(app.buttons.matching(identifier: "sessionRow.\(id)").count, 1)
    }

    private func scroll(until target: XCUIElement, in list: XCUIElement, upwards: Bool = true) {
        for _ in 0..<70 {
            if target.exists && target.isHittable { return }
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upwards ? 0.75 : 0.35))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upwards ? 0.35 : 0.75))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Could not scroll to \(target.identifier)")
    }

    private func choose(_ label: String, in app: XCUIApplication) {
        app.buttons["viewOptionsButton"].tap()
        let option = app.buttons[label]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
    }

    private func assertNoManualPaging(_ app: XCUIApplication) {
        let paging = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label == %@",
            "展开其余", "Show ", "Show less"
        ))
        XCTAssertEqual(paging.count, 0)
    }
}
