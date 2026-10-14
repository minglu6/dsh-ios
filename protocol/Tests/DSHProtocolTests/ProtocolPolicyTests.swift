import XCTest
@testable import DSHProtocol

final class ProtocolPolicyTests: XCTestCase {
    func testVersionCompatibility() {
        let ok = HandshakeVersions(proto: 1, pluginVersion: "0.1.0", minimumAppVersion: "0.1.0")
        XCTAssertNil(VersionCompatibility.evaluate(appVersion: "0.1.0", handshake: ok))
        XCTAssertEqual(
            VersionCompatibility.evaluate(
                appVersion: "0.0.9",
                handshake: HandshakeVersions(proto: 1, pluginVersion: "0.1.0", minimumAppVersion: "0.1.0")
            )?.kind,
            .appTooOld
        )
        XCTAssertEqual(
            VersionCompatibility.evaluate(
                appVersion: "0.1.0",
                handshake: HandshakeVersions(proto: 1, pluginVersion: "0.0.1", minimumAppVersion: "0.1.0")
            )?.kind,
            .pluginTooOld
        )
        XCTAssertEqual(
            VersionCompatibility.evaluate(
                appVersion: "0.1.0",
                handshake: HandshakeVersions(proto: 2, pluginVersion: "0.1.0", minimumAppVersion: "0.1.0")
            )?.kind,
            .protocolUnsupported
        )
    }

    func testReconnectBackoff() {
        XCTAssertEqual(ReconnectBackoffPolicy.reset(), 1_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(1_000), 2_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(16_000), 30_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(30_000), 30_000)
    }

    func testHistoryPaging() {
        XCTAssertFalse(HistoryPagingPolicy.canLoadOlder(hasMore: true, loadingOlder: false, firstSeq: -1))
        XCTAssertTrue(HistoryPagingPolicy.canLoadOlder(hasMore: true, loadingOlder: false, firstSeq: 12))
        let req = HistoryPagingPolicy.pageRequest(cursor: 80, firstSeq: 12)
        XCTAssertEqual(req.throughSeq, 80)
        XCTAssertEqual(req.beforeSeq, 12)
        XCTAssertEqual(req.maxMessages, 100)
    }

    func testRouteClassification() {
        XCTAssertEqual(classifyWsRoute("127.0.0.1"), .wsLocal)
        XCTAssertEqual(classifyWsRoute("100.106.128.87"), .wsTailscale)
        XCTAssertEqual(classifyWsRoute("mac.tail1.ts.net"), .wsTailscale)
        XCTAssertEqual(classifyWsRoute("192.168.1.20"), .wsLan)
        XCTAssertEqual(transportPlan(host: "192.168.1.20", port: 7690).first?.absoluteString, "ws://192.168.1.20:7690")
    }

    func testHostPortParse() {
        XCTAssertEqual(parseHostPort("192.168.1.20:7690")?.0, "192.168.1.20")
        XCTAssertEqual(parseHostPort("192.168.1.20:7690")?.1, 7690)
        XCTAssertNil(parseHostPort("192.168.1.20:99999"))
        XCTAssertEqual(parseHostPort("ws://100.1.2.3:7690")?.0, "100.1.2.3")
    }

    func testTranscriptEchoAndSnapshot() throws {
        let reducer = TranscriptReducer()
        reducer.echo(text: "hello", requestId: "rpc-1", mode: "queue")
        XCTAssertEqual(reducer.items().count, 1)
        let snapshot = try JSONValue.parse("""
        {"type":"snapshot","cursor":2,"hasMore":false,"records":[
          {"type":"event","event":{"seq":1,"type":"turn/start","data":{"turn":1}}},
          {"type":"event","event":{"seq":2,"type":"user/message","data":{
            "content":[{"type":"text","text":"hello"}],
            "source":{"kind":"user","rpcId":"rpc-1"}
          }}}
        ],"projections":{"values":{}}}
        """)
        XCTAssertTrue(reducer.apply(snapshot))
        let users = reducer.items().compactMap { item -> Item.User? in
            if case .user(let user) = item { return user }
            return nil
        }
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.text, "hello")
        XCTAssertEqual(users.first?.pending, false)
    }

    func testAssistantStreamThenMessage() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"assistant-stream","frame":{"type":"start","revision":1,"attemptId":"a1","turn":1,"step":1,"startedAfterSeq":0}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"assistant-stream","frame":{"type":"chunk","revision":2,"attemptId":"a1","index":0,"chunk":{"type":"text-delta","index":0,"text":"Hi"}}}
        """)))
        let live = reducer.items().compactMap { item -> String? in
            if case .text(let text) = item { return text.text }
            return nil
        }
        XCTAssertEqual(live, ["Hi"])
    }
}
