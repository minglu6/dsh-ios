import XCTest
@testable import DSHProtocol

final class TerminalTypefaceTests: XCTestCase {
    func testCascadeLeadsWithBundledNerdFace() {
        XCTAssertEqual(TerminalTypefacePolicy.bundledFamily, "MesloLGLDZ Nerd Font")
        XCTAssertEqual(TerminalTypefacePolicy.bundledPostScript, "MesloLGLDZNF-Regular")
        XCTAssertEqual(TerminalTypefacePolicy.cascadeFamilies.first, TerminalTypefacePolicy.bundledFamily)
        XCTAssertTrue(TerminalTypefacePolicy.cascadeFamilies.contains("Menlo"))
        XCTAssertTrue(TerminalTypefacePolicy.cascadeFamilies.contains("Apple Symbols"))
        XCTAssertEqual(TerminalTypefacePolicy.uiAppFontPath, "Fonts/MesloLGLDZNerdFont-Regular.ttf")
        XCTAssertEqual(TerminalTypefacePolicy.bundleSubdirectory, "Fonts")
    }
}
