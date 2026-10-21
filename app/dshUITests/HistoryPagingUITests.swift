import XCTest

final class HistoryPagingUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    func testChatPullsConsecutivePagesAndStopsAtEnd() {
        exercise(.chat, failFirst: false)
    }

    func testTrajectoryPullsConsecutivePagesAndStopsAtEnd() {
        exercise(.trajectory, failFirst: false)
    }

    func testInspectorPullsConsecutivePagesAndStopsAtEnd() {
        exercise(.inspector, failFirst: false)
    }

    func testChatFailedPullCanRetryWithoutLosingContent() {
        exercise(.chat, failFirst: true)
    }

    func testTrajectoryFailedPullCanRetryWithoutLosingContent() {
        exercise(.trajectory, failFirst: true)
    }

    func testInspectorFailedPullCanRetryWithoutLosingContent() {
        exercise(.inspector, failFirst: true)
    }

    private enum Screen: String {
        case chat = "historyPagingChat"
        case trajectory = "historyPagingTrajectory"
        case inspector = "historyPagingInspector"

        var scrollID: String {
            switch self {
            case .chat: return "chatTranscript"
            case .trajectory: return "trajectoryLedger"
            case .inspector: return "sessionInspectorRecords"
            }
        }
    }

    private func exercise(_ screen: Screen, failFirst: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-UITestScreen", screen.rawValue]
        if failFirst { app.launchArguments.append("-UITestHistoryFailFirst") }
        app.launch()
        if screen == .trajectory {
            let tab = app.buttons["chatTab.trajectory"]
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            tab.tap()
        }
        let scroll = app.scrollViews[screen.scrollID]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        waitForStatus(scroll, requests: 0, responses: 0, failures: 0)
        let original = record(21, in: scroll, screen: screen)
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        XCTAssertTrue(original.isHittable)

        if failFirst {
            pull(scroll)
            waitForStatus(scroll, requests: 1, responses: 0, failures: 1)
            XCTAssertTrue(original.isHittable, "Failed loading must not discard the current transcript")
            XCTAssertFalse(record(11, in: scroll, screen: screen).exists)
        }

        let firstRequest = failFirst ? 2 : 1
        pull(scroll)
        waitForStatus(scroll, requests: firstRequest, responses: 1, failures: failFirst ? 1 : 0)
        // The UI intentionally restores the old leading row instead of jumping
        // to the newly prepended page or to the bottom.
        let retained = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: original)
        XCTAssertEqual(XCTWaiter.wait(for: [retained], timeout: 5), .completed)

        // The old anchor is now below the new first page. Scroll toward the top
        // before the next pull; the request counter tells us when a real wire
        // request has started, so no loader is invoked directly by the test.
        let secondRequest = firstRequest + 1
        for _ in 0..<5 {
            pull(scroll)
            if status(scroll).contains("requests=\(secondRequest);") { break }
        }
        waitForStatus(scroll, requests: secondRequest, responses: 2, failures: failFirst ? 1 : 0)
        reveal(record(1, in: scroll, screen: screen), in: scroll, towardTop: true)
        XCTAssertTrue(record(1, in: scroll, screen: screen).isHittable)
        XCTAssertEqual(recordMatches(1, in: scroll, screen: screen).count, 1, "A page must not append duplicate rows")
        reveal(record(11, in: scroll, screen: screen), in: scroll, towardTop: false)
        XCTAssertEqual(recordMatches(11, in: scroll, screen: screen).count, 1, "The intermediate page must survive another prepend")

        for _ in 0..<3 { pull(scroll) }
        waitForStatus(scroll, requests: secondRequest, responses: 2, failures: failFirst ? 1 : 0)
        reveal(record(23, in: scroll, screen: screen), in: scroll, towardTop: false)
        XCTAssertTrue(record(23, in: scroll, screen: screen).isHittable, "The latest original content must remain available")
        XCTAssertEqual(recordMatches(23, in: scroll, screen: screen).count, 1)
        capture(app, name: "history-paging-\(screen.rawValue)-\(failFirst ? "retry" : "success")")
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
            } catch { XCTFail("Could not export pagination screenshot: \(error)") }
        }
    }

    private func recordMatches(_ seq: Int, in scroll: XCUIElement, screen: Screen) -> XCUIElementQuery {
        if screen == .trajectory {
            return scroll.buttons.matching(identifier: "trajRow.u\(seq)")
        }
        if screen == .inspector {
            return scroll.descendants(matching: .any).matching(identifier: "inspectorRecord.event:\(seq)")
        }
        return scroll.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "History record \(seq) —"))
    }

    private func record(_ seq: Int, in scroll: XCUIElement, screen: Screen) -> XCUIElement {
        recordMatches(seq, in: scroll, screen: screen).firstMatch
    }

    private func pull(_ scroll: XCUIElement) {
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, towardTop: Bool) {
        for _ in 0..<8 {
            if element.isHittable { return }
            if towardTop { scroll.swipeDown() } else { scroll.swipeUp() }
        }
    }

    private func status(_ scroll: XCUIElement) -> String {
        scroll.value as? String ?? ""
    }

    private func waitForStatus(_ scroll: XCUIElement, requests: Int, responses: Int, failures: Int) {
        let firstSeq = responses == 0 ? 21 : (responses == 1 ? 11 : 1)
        let expected = "requests=\(requests);responses=\(responses);failures=\(failures);firstSeq=\(firstSeq);loading=false"
        let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: scroll)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 10), .completed, "Expected actual Host transport state \(expected), got \(status(scroll))")
    }
}
