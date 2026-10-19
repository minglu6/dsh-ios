import XCTest
@testable import DSHProtocol

final class ChatToolIconsTests: XCTestCase {
    func testProcessIconsMatchDesktopPROCESS_ICONS() {
        XCTAssertEqual(chatProcessOfficialSymbol("thinking"), "official.think")
        XCTAssertEqual(chatProcessOfficialSymbol("read"), "official.browseOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("readImage"), "official.browseOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("webFetch"), "official.browseOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("search"), "official.searchOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("edit"), "official.editOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("write"), "official.editOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("commands"), "official.apiOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("code"), "official.codeOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("webSearch"), "official.globeOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("subagents"), "official.agentPreset")
        XCTAssertEqual(chatProcessOfficialSymbol("plan"), "official.planOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("questions"), "official.questionOutline")
        XCTAssertEqual(chatProcessOfficialSymbol("tools"), "official.sparkle")
        for kind in chatProcessOfficialKinds {
            XCTAssertFalse(isForbiddenChatToolSystemSymbol(chatProcessOfficialSymbol(kind)))
        }
        XCTAssertTrue(isForbiddenChatToolSystemSymbol("doc.text.magnifyingglass"))
        XCTAssertTrue(isForbiddenChatToolSystemSymbol("terminal"))
        XCTAssertTrue(isForbiddenChatToolSystemSymbol("sparkle"))
    }

    func testToolRowIconsMatchDesktopPrimitives() {
        XCTAssertEqual(toolProcessOfficialSymbol(.browse), "official.browseOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.search), "official.searchOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.command), "official.apiOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.write), "official.editOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.edit), "official.editOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.code), "official.codeOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.generic), "official.sparkle")
        XCTAssertEqual(toolProcessOfficialSymbol(.users), "official.usersOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.checklist), "official.checklistOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.clock), "official.clockOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.goal), "official.goalOutline")
        XCTAssertEqual(toolProcessOfficialSymbol(.plugin), "official.cordisPlugin")
        XCTAssertEqual(toolProcessOfficialSymbol(.agent), "official.agentPreset")
        XCTAssertEqual(toolProcessOfficialSymbol(.branch), "official.branchOutline")
        XCTAssertEqual(
            toolProcessOfficialSymbol(toolProcessSummary(
                Item.Tool(key: "t", callId: "c", name: "read", arguments: #"{"path":"a.swift"}"#, status: .ok)
            ).icon),
            "official.browseOutline"
        )
        XCTAssertEqual(
            toolProcessOfficialSymbol(toolProcessSummary(
                Item.Tool(key: "t", callId: "c", name: "bash", arguments: #"{"command":"ls"}"#, status: .ok)
            ).icon),
            "official.apiOutline"
        )
    }

    func testArtworkPathsAreDesktopBytes() {
        XCTAssertEqual(markdownFileChipAssetName, "officialBrowseOutline")
        XCTAssertEqual(markdownFileChipAccessibilityIdentifier, "official.markdownFileChip")
        XCTAssertEqual(chatBrowseCaptionTopPath, "M4.9375 5.90295H11.0625")
        XCTAssertTrue(chatBrowsePagePath.hasPrefix("M12.5 1.32617"))
        XCTAssertEqual(chatEditStrokePath, "M7.7849 8.23878L13.888 2.13574")
        XCTAssertEqual(chatApiChevronPath, "M3 4L7 8L3 12")
        XCTAssertEqual(chatApiBarPath, "M9 12H13")
        XCTAssertEqual(chatCodeSlashLeftPath, "M6.27612 1.5L4.52612 14.5")
        XCTAssertTrue(chatQuestionRingPath.hasPrefix("M8 14.5C11.5899"))
        XCTAssertEqual(chatUsersHeadPath.contains("M6 8.25"), true)
        XCTAssertEqual(chatChecklistLineTopPath, "M7.5 4.5H13.5")
        XCTAssertTrue(chatGoalOuterArcPath.hasPrefix("M14.5001 8C14.5"))
        XCTAssertTrue(chatCordisPluginFillPath.hasPrefix("M3.16143 6.59068"))
        XCTAssertEqual(chatCordisPluginCircleRadius, 1.76221)
        XCTAssertTrue(jobsStopFillPath.hasPrefix("M12.5 2.5H3.5"))
        XCTAssertEqual(jobsStopFillSymbol(), "official.stopFill")
    }

    func testJobsRowAndSettledChevronsUseOfficialRotation() {
        XCTAssertEqual(jobsRowChevronIconSizePoints, 12)
        XCTAssertEqual(jobsRowChevronOpenRotationDegrees, 180)
        XCTAssertEqual(jobsSettledChevronCollapsedRotationDegrees, -90)
        XCTAssertEqual(jobsSettledChevronOpenRotationDegrees, 0)
        XCTAssertTrue(isForbiddenJobsRowChromeSymbol("chevron.down"))
        XCTAssertTrue(isForbiddenJobsRowChromeSymbol("chevron.right"))
        XCTAssertTrue(isForbiddenJobsRowChromeSymbol("stop.fill"))
        XCTAssertFalse(isForbiddenJobsRowChromeSymbol("official.chevronDown"))
    }

    func testBuiltinPluginRefreshUsesIconRefreshOutline() {
        XCTAssertTrue(builtinPluginRefreshUsesOfficialGlyph)
        XCTAssertEqual(builtinPluginRefreshSymbol(), "official.refreshOutline")
        XCTAssertTrue(isForbiddenBuiltinPluginRefreshSymbol("arrow.clockwise"))
        XCTAssertFalse(isForbiddenBuiltinPluginRefreshSymbol("official.refreshOutline"))
    }

    func testTrajectoryDetailChevronsMatchDesktop() {
        XCTAssertEqual(trajectoryDetailChevronIconSizePoints, 12)
        XCTAssertEqual(trajectoryThinkingChevronExpandedRotationDegrees, 90)
        XCTAssertTrue(isForbiddenTrajectoryDetailSystemSymbol("chevron.right"))
        XCTAssertTrue(isForbiddenTrajectoryDetailSystemSymbol("wrench.and.screwdriver"))
        XCTAssertFalse(isForbiddenTrajectoryDetailSystemSymbol("official.chevronRight"))
        XCTAssertFalse(isForbiddenTrajectoryDetailSystemSymbol("official.toolWrench"))
    }

    func testContextInjectionAndCommandCardsUseDesktopLeadingIcons() {
        XCTAssertEqual(contextInjectionOfficialSymbol(), "official.browseOutline")
        XCTAssertEqual(commandCardOfficialSymbol(), "official.apiOutline")
        XCTAssertFalse(isForbiddenChatToolSystemSymbol(contextInjectionOfficialSymbol()))
        XCTAssertFalse(isForbiddenChatToolSystemSymbol(commandCardOfficialSymbol()))
    }

    func testChatDockUsesDesktopOutlineIcons() {
        XCTAssertEqual(chatTodoDockSymbol(), "official.checklistOutline")
        XCTAssertEqual(chatGoalDockSymbol(), "official.goalOutline")
        XCTAssertEqual(chatQueueDockSymbol(), "official.queueOutline")
        XCTAssertNotEqual(chatQueueDockSymbol(), viewOptionsOfficialIdentifier(.filterShow))
        XCTAssertEqual(chatTodoPanelIdentifier(), "todoPanel")
        XCTAssertEqual(chatGoalBarIdentifier(), "goalBar")
        XCTAssertEqual(chatQueueDockIdentifier(), "promptQueue")
        XCTAssertEqual(queueSteerSendSymbol(), "official.sendOutline")
        XCTAssertEqual(queueActionIconSizePoints, 14)
        XCTAssertTrue(queueSteerSendFillPath.hasPrefix("M6.97211 1.94476"))
        XCTAssertEqual(queueSteerSendStemPath, "M7.97571 14.5732L8.02421 2.34139")
        XCTAssertTrue(isForbiddenChatDockSystemSymbol("checklist"))
        XCTAssertTrue(isForbiddenChatDockSystemSymbol("target"))
        XCTAssertTrue(isForbiddenChatDockSystemSymbol("trash"))
        XCTAssertTrue(isForbiddenChatDockSystemSymbol("pencil"))
        XCTAssertTrue(isForbiddenChatDockSystemSymbol("paperplane"))
        XCTAssertFalse(isForbiddenChatDockSystemSymbol("official.checklistOutline"))
        XCTAssertFalse(isForbiddenChatDockSystemSymbol(queueSteerSendSymbol()))
    }

    func testDocumentedSkipsHaveNoInventedArtwork() {
        XCTAssertFalse(connectionsScanUsesOfficialGlyph)
        XCTAssertTrue(connectionsScanSkipReason.contains("no QR"))
        XCTAssertFalse(connectionsNearbyUsesOfficialGlyph)
        XCTAssertTrue(connectionsNearbySkipReason.contains("no IconComputer"))
        XCTAssertEqual(connectionsNearbyComputerSymbol(), "connections.computer")
        XCTAssertTrue(isForbiddenConnectionsNearbySymbol("desktopcomputer"))
        XCTAssertFalse(isForbiddenConnectionsNearbySymbol("connections.computer"))
        XCTAssertEqual(connectionsManageTrashSymbol(), "official.trashOutline")
        XCTAssertEqual(connectionsManageRepairSymbol(), "official.refreshOutline")
        XCTAssertEqual(connectionsManageRenameSymbol(), "official.editOutline")
        XCTAssertTrue(isForbiddenConnectionsManageSymbol("trash"))
        XCTAssertTrue(isForbiddenConnectionsManageSymbol("arrow.clockwise"))
        XCTAssertTrue(isForbiddenConnectionsManageSymbol("pencil"))
        XCTAssertFalse(isForbiddenConnectionsManageSymbol("official.trashOutline"))
        XCTAssertFalse(inspectorPickUsesOfficialGlyph)
        XCTAssertFalse(inspectorTypeFilterUsesOfficialGlyph)
        XCTAssertTrue(inspectorPickSkipReason.contains("CodeBracketsArtwork"))
        XCTAssertTrue(inspectorTypeFilterSkipReason.contains("no type-filter"))
        XCTAssertEqual(inspectorPickSkipSymbol, "viewfinder")
        XCTAssertEqual(inspectorTypeFilterSkipSymbol, "line.3.horizontal.decrease")
        XCTAssertEqual(inspectorPickSkipIdentifier(), "inspector.viewfinder")
        XCTAssertEqual(inspectorTypeFilterSkipIdentifier(), "inspector.typeFilter")
        XCTAssertFalse(terminalCenterLoadingUsesOfficialGlyph)
        XCTAssertTrue(terminalCenterLoadingSkipReason.contains("no center spinner"))
    }
}
