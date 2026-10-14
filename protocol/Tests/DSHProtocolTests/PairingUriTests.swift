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
}
