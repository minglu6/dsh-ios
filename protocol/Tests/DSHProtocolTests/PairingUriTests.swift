import XCTest
@testable import DSHProtocol

final class PairingUriTests: XCTestCase {
    func testSharedContract() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "pairing-uri-cases", withExtension: "json"))
        let root = try JSONValue.parse(try Data(contentsOf: url))
        for caseItem in root["parse"].arr() ?? [] {
            let name = try XCTUnwrap(caseItem["name"].str())
            let input = try XCTUnwrap(caseItem["input"].str())
            let expected = caseItem["expected"]
            let parsed = PairingUriPolicy.parse(input)
            if expected.isNull {
                XCTAssertNil(parsed, name)
            } else {
                XCTAssertEqual(parsed?.host, expected["host"].str(), name)
                XCTAssertEqual(parsed?.port, expected["port"].int(), name)
                XCTAssertEqual(parsed?.code, expected["code"].str(), name)
            }
        }
    }

    func testUnfinishedPercentEscapeFailsClosed() {
        XCTAssertNil(PairingUriPolicy.parse("dshpocket://pair?h=mac%&c=012345"))
        XCTAssertNil(PairingUriPolicy.parse("dshpocket://pair?h=mac%3&c=012345"))
        XCTAssertEqual(
            PairingUriPolicy.parse("dshpocket://pair?h=mac.tail.ts.net%3A7690&c=012345")?.host,
            "mac.tail.ts.net"
        )
    }
}
