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
        XCTAssertTrue(DesktopSidebarInventory.desktopGuideIncludesSessionInspector)
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
        XCTAssertEqual(viewOptionsOfficialIdentifier(.groupWorkspace), "official.folderClose")
        XCTAssertEqual(viewOptionsOfficialIdentifier(.groupWorkspaceTree), "official.workspaceTree")
        XCTAssertEqual(viewOptionsOfficialIdentifier(.groupFlat), "official.flatList")
        XCTAssertEqual(viewOptionsOfficialIdentifier(.orderManual), "official.chevronsUpDown")
        XCTAssertEqual(viewOptionsOfficialIdentifier(.orderUpdated), "official.clockOutline")
        XCTAssertEqual(viewOptionsOfficialIdentifier(.filterHide), "official.archiveOff")
        XCTAssertEqual(viewOptionsOfficialIdentifier(.filterShow), "official.queue")
        XCTAssertEqual(viewOptionsOfficialIdentifier(.filterOnly), "official.archiveCheck")
        XCTAssertEqual(viewOptionsTriggerOfficialIdentifier(), "official.slidersTwo")
        XCTAssertEqual(viewOptionsSlidersKnobTopCenterX, 9.95)
        XCTAssertEqual(viewOptionsSlidersKnobBottomCenterX, 5.75)
        XCTAssertEqual(viewOptionsSlidersKnobRadius, 1.45)
        XCTAssertTrue(isForbiddenViewOptionsSystemSymbol("slider.horizontal.3"))
        XCTAssertTrue(isForbiddenViewOptionsSystemSymbol("list.bullet"))
        XCTAssertFalse(isForbiddenViewOptionsSystemSymbol("official.slidersTwo"))
    }

    func testWorkspaceGroupFolderMatchesDesktopProjectRow() {
        XCTAssertEqual(workspaceGroupFolderSymbol(collapsed: true), "official.folderClose")
        XCTAssertEqual(workspaceGroupFolderSymbol(collapsed: false), "official.folderOpenFill")
        XCTAssertEqual(workspaceGroupFolderIconSizePoints, 16)
        XCTAssertTrue(workspaceGroupFolderUsesBusinessPrimaryWhenActive())
        XCTAssertEqual(workspaceGroupFolderActiveColorHex(dark: false), 0x4176E6)
        XCTAssertEqual(workspaceGroupFolderActiveColorHex(dark: true), 0x7AAAFF)
        XCTAssertTrue(workspaceGroupFolderHoverChevronSwapIsSkip)
        XCTAssertTrue(isForbiddenWorkspaceGroupFolderSymbol("folder"))
        XCTAssertTrue(isForbiddenWorkspaceGroupFolderSymbol("folder.fill"))
        XCTAssertFalse(isForbiddenWorkspaceGroupFolderSymbol("official.folderOpenFill"))
        XCTAssertEqual(workspaceGroupFolderIconIdentifier("ws-ios"), "workspaceIcon.ws-ios")
        XCTAssertEqual(workspaceOverflowSymbol(), "official.ellipsis")
        XCTAssertTrue(isForbiddenWorkspaceOverflowSymbol("ellipsis"))
        XCTAssertFalse(isForbiddenWorkspaceOverflowSymbol("official.ellipsis"))
        XCTAssertTrue(iconEllipsisDotAPath.hasPrefix("M3 9C3.55228"))
        XCTAssertTrue(iconEllipsisDotBPath.hasPrefix("M8 9C8.55228"))
        XCTAssertTrue(iconEllipsisDotCPath.hasPrefix("M13 9C13.5523"))
        XCTAssertEqual(workspaceFolderOpenFillShadeOpacity, 0.16)
        XCTAssertTrue(workspaceFolderOpenFillShadePath.hasPrefix("M2.55912 7.93683"))
        XCTAssertTrue(workspaceFolderOpenFillPocketPath.hasPrefix("M13.6491 6.69446"))
        XCTAssertTrue(workspaceFolderOpenFillTabPath.hasPrefix("M4.7666 1.90137"))
        XCTAssertFalse(workspaceGroupFolderIsActive(containsCurrent: true, containsCurrentDescendant: false, expanded: false))
        XCTAssertTrue(workspaceGroupFolderIsActive(containsCurrent: true, containsCurrentDescendant: false, expanded: true))
        XCTAssertTrue(workspaceGroupFolderIsActive(containsCurrent: false, containsCurrentDescendant: true, expanded: false))
        XCTAssertFalse(workspaceGroupFolderIsActive(containsCurrent: false, containsCurrentDescendant: false, expanded: true))
    }

    func testSchedulePageDropsUnofficialChrome() {
        XCTAssertTrue(SchedulePagePolicy.headerNewActionUsesShortLabel)
        XCTAssertFalse(SchedulePagePolicy.showsUnofficialRefresh)
        XCTAssertFalse(SchedulePagePolicy.emptyRepeatsHeaderNewAction)
        XCTAssertEqual(SchedulePagePolicy.headerNewLabel(english: false), "新建")
        XCTAssertEqual(SchedulePagePolicy.emptyActionLabel(english: false), "新建自动化任务")
    }

}
