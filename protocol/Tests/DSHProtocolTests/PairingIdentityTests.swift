import XCTest
@testable import DSHProtocol

final class PairingIdentityTests: XCTestCase {
    func testPairRequestDeviceNameIsNotHostRemark() throws {
        let remark = "macmini"
        let phone = "iPhone"
        let names = try pairingNames(hostRemark: remark, host: "192.168.1.20", clientDeviceName: phone)
        XCTAssertEqual(names.localHostRemark, remark)
        XCTAssertEqual(names.clientDeviceName, phone)
        XCTAssertNotEqual(names.clientDeviceName, remark)
        XCTAssertNotEqual(names.clientDeviceName, names.localHostRemark)

        let handshake = pocketHandshake(auth: names.pairAuth(code: "654321"), appVersion: "0.1.0")
        XCTAssertEqual(handshake.op, "pair")
        XCTAssertEqual(handshake.args["name"].str(), phone)
        XCTAssertNotEqual(handshake.args["name"].str(), remark)
        XCTAssertEqual(handshake.args["code"].str(), "654321")
        XCTAssertEqual(handshake.args["app"].str(), "dsh-ios")
        if case .pair(_, let deviceName) = names.pairAuth(code: "654321") {
            XCTAssertEqual(deviceName, phone)
            XCTAssertNotEqual(deviceName, remark)
        } else {
            XCTFail("pairAuth must produce Auth.pair")
        }
    }

    func testLocalHostRemarkDefaultsToHostAddress() throws {
        let names = try pairingNames(hostRemark: "  ", host: "192.168.1.20", clientDeviceName: "iPhone")
        XCTAssertEqual(names.localHostRemark, "192.168.1.20")
        XCTAssertEqual(names.clientDeviceName, "iPhone")
        XCTAssertNotEqual(names.clientDeviceName, names.localHostRemark)
        XCTAssertNotEqual(
            pocketHandshake(auth: .pair(code: "123456", deviceName: names.clientDeviceName), appVersion: "0.1.0")
                .args["name"].str(),
            names.localHostRemark
        )
    }

    func testClipProfileNameTrimsAndTruncatesTo64() throws {
        XCTAssertEqual(try clipProfileName("  Mac  "), "Mac")
        XCTAssertEqual(try clipProfileName(String(repeating: "x", count: 80)), String(repeating: "x", count: 64))
        XCTAssertThrowsError(try clipProfileName("   ")) { error in
            XCTAssertEqual((error as? PocketError)?.code, "bad-request")
        }
        XCTAssertThrowsError(try pairingNames(hostRemark: "macmini", host: "192.168.1.20", clientDeviceName: "  "))
    }

    func testHelloHandshakeDoesNotCarryDeviceName() {
        let handshake = pocketHandshake(auth: .token("tok"), appVersion: "0.1.0")
        XCTAssertEqual(handshake.op, "hello")
        XCTAssertTrue(handshake.args["name"].isNull)
        XCTAssertEqual(handshake.args["token"].str(), "tok")
    }

    func testPocketClientPairSendsClientDeviceNameNotHostRemark() async throws {
        let transport = PairingFakeTransport()
        let client = PocketClient(appVersion: "1.2.3")
        let remark = "macmini"
        let names = try pairingNames(hostRemark: remark, host: "10.0.0.2", clientDeviceName: "iPad")
        XCTAssertNotEqual(names.clientDeviceName, remark)
        let hello = try await client.connect(
            transport: transport,
            auth: names.pairAuth(code: "123456")
        )
        let pair = try XCTUnwrap(transport.requests.first { $0["op"].str() == "pair" })
        XCTAssertEqual(pair["args"]["name"].str(), "iPad")
        XCTAssertNotEqual(pair["args"]["name"].str(), remark)
        XCTAssertEqual(pair["args"]["code"].str(), "123456")
        XCTAssertEqual(pair["args"]["app"].str(), "dsh-ios")
        XCTAssertEqual(pair["args"]["appVersion"].str(), "1.2.3")
        XCTAssertEqual(hello.deviceId, "paired-device")
        XCTAssertEqual(hello.issuedToken, "paired-token")
        client.close()
    }
}

private final class PairingFakeTransport: FrameTransport, @unchecked Sendable {
    let route = Route.wsLocal
    let endpointURL: URL? = nil
    var closeReason: String?
    var closed = false
    var requests: [JSONValue] = []
    private let lock = NSLock()
    private var frames: [String] = []
    private var waiter: CheckedContinuation<String, Error>?

    func send(_ text: String) async throws {
        let request = try JSONValue.parse(text)
        lock.lock()
        requests.append(request)
        lock.unlock()
        if request["op"].str() == "pair" {
            emit(jsonObjectKeeping([
                "id": request["id"],
                "ok": .bool(true),
                "result": jsonObject([
                    "proto": .number(1),
                    "deviceId": .string("paired-device"),
                    "token": .string("paired-token"),
                ]),
            ]))
        }
    }

    func ping() async throws {}

    func receive() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if !frames.isEmpty {
                let frame = frames.removeFirst()
                lock.unlock()
                continuation.resume(returning: frame)
            } else if closed {
                lock.unlock()
                continuation.resume(throwing: PocketError(code: "transport", message: "closed"))
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }

    func close() {
        lock.lock()
        closed = true
        let pending = waiter
        waiter = nil
        lock.unlock()
        pending?.resume(throwing: PocketError(code: "transport", message: "closed"))
    }

    private func emit(_ frame: JSONValue) {
        let text = (try? frame.encodeString()) ?? "{}"
        lock.lock()
        if let waiter {
            self.waiter = nil
            lock.unlock()
            waiter.resume(returning: text)
        } else {
            frames.append(text)
            lock.unlock()
        }
    }
}
