import XCTest
@testable import DSHProtocol

final class HostUiTransportTests: XCTestCase {
    func testOpeningTimeoutReleasesWaiterSoAnotherEndpointCanBeTried() async {
        let waiter = WebSocketOpenWaiter()
        let completed = expectation(description: "Opening timeout returns")
        let task = Task {
            defer { completed.fulfill() }
            do {
                try await withTimeout(ms: 10) { try await waiter.wait() }
                XCTFail("An unopened WebSocket cannot succeed")
            } catch let error as PocketError {
                XCTAssertEqual(error.code, "timeout")
            } catch { XCTFail("Unexpected timeout error: \(error)") }
        }
        await fulfillment(of: [completed], timeout: 1)
        // Also release work on regression so a failed assertion cannot strand the suite.
        waiter.fail(CancellationError())
        await task.value
    }

    func testCancelledOpenDoesNotWaitForURLSessionDelegateCompletion() async {
        let waiter = WebSocketOpenWaiter()
        let completed = expectation(description: "Cancelled open returns")
        let task = Task {
            defer { completed.fulfill() }
            do {
                try await waiter.wait()
                XCTFail("Cancelled open cannot succeed")
            } catch is CancellationError {} catch { XCTFail("Unexpected cancellation error: \(error)") }
        }
        task.cancel()
        await fulfillment(of: [completed], timeout: 1)
        waiter.fail(CancellationError())
        await task.value
    }
}
