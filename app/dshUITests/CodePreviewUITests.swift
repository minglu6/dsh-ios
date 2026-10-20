import XCTest

final class CodePreviewUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testLongPythonSourceRendersWrapsAndSurvivesPlainHighlightSwitches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", "filePreviewPython"]
        app.launch()

        let viewport = app.webViews["codePreviewViewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(viewport.frame.height, 200, "The source viewport must receive layout height")
        assertSource("CODE_PREVIEW_BEGIN: 地面洞察报告生成 CLI", in: viewport)
        assertSource("CODE_PREVIEW_LITERAL: </script><img src=x onerror=alert(1)> & \"引号\"", in: viewport)
        assertSource("CODE_PREVIEW_UNICODE: 日本語 café λ — 中文", in: viewport)
        assertSource("CODE_PREVIEW_END: 完整源文件结束", in: viewport)
        XCTAssertFalse(app.staticTexts["codePreviewError"].exists)

        // This is a source DOM node inside WKWebView, not native filename/language chrome.
        let longLine = source("CODE_PREVIEW_WRAP:", in: viewport)
        let unwrappedHeight = longLine.frame.height
        app.buttons["自动换行"].tap()
        let wraps = NSPredicate { _, _ in longLine.frame.height > unwrappedHeight * 2 }
        expectation(for: wraps, evaluatedWith: longLine)
        waitForExpectations(timeout: 10)
        XCTAssertLessThanOrEqual(longLine.frame.maxX, viewport.frame.maxX + 2)
        XCTAssertTrue(app.buttons["取消自动换行"].exists)

        chooseMode("纯文本", in: app)
        assertSource("CODE_PREVIEW_BEGIN: 地面洞察报告生成 CLI", in: viewport)
        assertSource("</script><img src=x onerror=alert(1)>", in: viewport)
        assertSource("CODE_PREVIEW_END: 完整源文件结束", in: viewport)
        app.buttons["取消自动换行"].tap()
        XCTAssertTrue(app.buttons["自动换行"].exists)

        chooseMode("代码", in: app)
        assertSource("CODE_PREVIEW_BEGIN: 地面洞察报告生成 CLI", in: viewport)
        assertSource("CODE_PREVIEW_UNICODE: 日本語 café λ — 中文", in: viewport)
        assertSource("CODE_PREVIEW_END: 完整源文件结束", in: viewport)
        XCTAssertFalse(app.staticTexts["codePreviewError"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "python-source-wkwebview-highlight"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        if let root = ProcessInfo.processInfo.environment["DSH_SCREENSHOT_DIR"] {
            let directory = URL(fileURLWithPath: root, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: directory.appendingPathComponent("python-source-wkwebview-highlight.png"))
        }
    }

    private func source(_ text: String, in viewport: XCUIElement) -> XCUIElement {
        viewport.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func assertSource(_ text: String, in viewport: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(source(text, in: viewport).waitForExistence(timeout: 20),
                      "Missing actual WKWebView source: \(text)", file: file, line: line)
    }

    private func chooseMode(_ mode: String, in app: XCUIApplication) {
        app.buttons["打开方式"].tap()
        let choice = app.buttons[mode]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
    }
}
