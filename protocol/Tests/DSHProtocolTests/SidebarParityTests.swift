import XCTest
@testable import DSHProtocol

final class SidebarParityTests: XCTestCase {
    func testRightGuideOrderMatchesDesktopProviders() {
        XCTAssertEqual(DesktopSidebarInventory.rightGuideCards.map(\.order), [10, 20, 30])
        XCTAssertEqual(DesktopSidebarInventory.rightGuideCards.map(\.zh), ["工作区文件", "新建终端", "浏览器"])
        XCTAssertEqual(DesktopSidebarInventory.rightGuideCards.map(\.en), ["Workspace files", "New terminal", "Browser"])
        XCTAssertEqual(DesktopSidebarInventory.officialGuideKinds(), ["workspace", "new", "browser"])
    }

    func testSessionInspectorIsNotADesktopGuideCard() {
        XCTAssertFalse(DesktopSidebarInventory.desktopGuideIncludesSessionInspector)
        let inspector = DesktopSidebarInventory.entries.first { $0.surface == .rightSessionInspector }
        XCTAssertEqual(inspector?.official, false)
        XCTAssertEqual(inspector?.zh, "会话数据诊断")
        XCTAssertEqual(inspector?.en, "Session diagnostics")
    }

    func testViewOptionsIsGroupedLikeDesktopWorkspaceMenu() {
        XCTAssertEqual(ViewOptionsMenuPolicy.rows(in: .groupBy), [.groupWorkspace, .groupWorkspaceTree, .groupFlat])
        XCTAssertEqual(ViewOptionsMenuPolicy.rows(in: .orderBy), [.orderManual, .orderUpdated])
        XCTAssertEqual(ViewOptionsMenuPolicy.rows(in: .filter), [.filterHide, .filterShow, .filterOnly])
        XCTAssertEqual(ViewOptionsMenuPolicy.title(.groupBy, english: false), "分组方式")
        XCTAssertEqual(ViewOptionsMenuPolicy.label(.filterShow, english: false), "全部对话（显示已归档）")
        XCTAssertEqual(ViewOptionsMenuPolicy.icon(.groupWorkspace), "folderClose")
        XCTAssertEqual(ViewOptionsMenuPolicy.icon(.orderManual), "chevronsUpDown")
        XCTAssertEqual(ViewOptionsMenuPolicy.icon(.orderUpdated), "clockOutline")
        XCTAssertEqual(ViewOptionsMenuPolicy.icon(.filterHide), "archiveOff")
        XCTAssertEqual(ViewOptionsMenuPolicy.icon(.filterShow), "queue")
        XCTAssertEqual(ViewOptionsMenuPolicy.icon(.filterOnly), "archiveCheck")
        XCTAssertFalse(ViewOptionsRow.allCases.contains { ViewOptionsMenuPolicy.icon($0) == "check" })
        XCTAssertTrue(viewOptionsUsesCompactPopover)
        XCTAssertTrue(viewOptionsEveryRowHasOfficialLeadingIcon)
        XCTAssertEqual(viewOptionsMenuMinWidthPoints, 200)
        XCTAssertEqual(viewOptionsMenuRowMinHeightPoints, 34)
    }

    func testSchedulePageDropsUnofficialChrome() {
        XCTAssertTrue(SchedulePagePolicy.headerNewActionUsesShortLabel)
        XCTAssertFalse(SchedulePagePolicy.showsUnofficialRefresh)
        XCTAssertFalse(SchedulePagePolicy.emptyRepeatsHeaderNewAction)
        XCTAssertEqual(SchedulePagePolicy.headerNewLabel(english: false), "新建")
        XCTAssertEqual(SchedulePagePolicy.emptyActionLabel(english: false), "新建自动化任务")
    }

}
