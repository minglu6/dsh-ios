import XCTest
@testable import DSHProtocol

final class ComposerPickerParityTests: XCTestCase {
    func testConversationHeaderOmitsModelAndPresetOnPhone() {
        XCTAssertFalse(conversationHeaderShowsModelChip)
        XCTAssertFalse(conversationHeaderShowsAgentPreset)
        XCTAssertFalse(conversationHeaderShowsTimestamp)
        XCTAssertTrue(agentPresetSeatOnLandingOnly)
    }

    func testPhoneConnectionLivesInDrawerFooterNotSettings() {
        XCTAssertFalse(settingsIncludesPhoneConnection)
        XCTAssertTrue(phoneConnectionLivesInDrawerFooter)
    }

    func testPermissionCopyAndMenuMetricsMatchDesktop() {
        XCTAssertEqual(permissionLabel(value: "auto"), "自动审查")
        XCTAssertEqual(permissionLabel(value: "auto", english: true), "Auto review")
        XCTAssertEqual(permissionLabel(value: "read-only", english: true), "Read Only")
        XCTAssertEqual(permissionExpBadge("auto"), "EXP")
        XCTAssertNil(permissionExpBadge("read-only"))
        XCTAssertTrue(permissionHasGlyph("auto"))
        XCTAssertTrue(permissionHasGlyph("workspace-write"))
        XCTAssertFalse(permissionHasGlyph("custom"))
        XCTAssertTrue(permissionAutoHasIcon)
        XCTAssertEqual(permissionExpBadgeFontSizePoints, 8)
        XCTAssertEqual(permissionExpBadgeFontWeight, 500)
        XCTAssertEqual(permissionMenuMinWidthPoints, 144)
        XCTAssertEqual(permissionMenuRowMinHeightPoints, 34)
        XCTAssertEqual(permissionMenuIconSizePoints, 14)
        XCTAssertTrue(composerPickerPopoverOpensAbove)
        XCTAssertEqual(composerPickerPopoverOpensAbove, composerUsagePopoverOpensAbove)
        XCTAssertEqual(permissionMenuHeightPoints(optionCount: 0), 8)
        XCTAssertEqual(permissionMenuHeightPoints(optionCount: 4), 144)
        XCTAssertEqual(permissionAutoConfirmTitle(english: true), "Enable Auto review (experimental)?")
        XCTAssertEqual(permissionAutoConfirmEnable(english: true), "Enable Auto review")
        XCTAssertEqual(permissionAutoConfirmTitle(english: false), "确认启用自动审查（实验）？")
    }

    func testModelPickerCopyMatchesDesktopLocales() {
        XCTAssertEqual(modelPickerRootModelLabel(english: false), "模型")
        XCTAssertEqual(modelPickerRootEffortLabel(english: false), "推理等级")
        XCTAssertEqual(modelPickerRootEffortLabel(english: true), "Effort")
        XCTAssertEqual(modelPickerEmptyModels(english: false), "暂无可用模型")
        XCTAssertEqual(modelPickerEmptyModels(english: true), "No models available.")
        XCTAssertEqual(modelPickerSearchEmpty(english: false), "没有匹配的模型。")
        XCTAssertEqual(modelPickerEmptyEfforts(english: false), "当前模型未提供推理等级。")
        XCTAssertEqual(modelPickerEffortProviderDefault(english: false), "Default")
        XCTAssertEqual(modelPickerEffortProviderDefault(english: true), "Default")
        XCTAssertEqual(modelPickerSearchPlaceholder(english: false), "搜索模型…")
        XCTAssertTrue(modelPickerRootShowsEffortOnlyWhenReasoning)
        XCTAssertEqual(modelPickerMenuMinWidthPoints, 240)
        XCTAssertEqual(modelPickerRowMinHeightPoints, 34)
    }

    func testReasoningRowMatchesDesktopDisclosure() {
        XCTAssertEqual(reasoningTitle(english: false), "思考")
        XCTAssertEqual(reasoningTitle(english: true), "Think")
        XCTAssertFalse(reasoningDefaultExpanded)
        XCTAssertTrue(reasoningChevronReplacesIconWhenExpanded)
        XCTAssertTrue(reasoningUsesTextShimmerNotSpinner)
        XCTAssertTrue(reasoningBodyIsCompactMarkdown)
        XCTAssertEqual(reasoningBodyLeadingPoints, 22)
        XCTAssertEqual(reasoningIconSizePoints, 14)
        XCTAssertEqual(reasoningBodyFontSize(contentFontSize: 14), 13)
        XCTAssertEqual(reasoningPreview("alpha\nbeta", running: false), "alpha")
        XCTAssertEqual(reasoningPreview("**one**\n\ntwo", running: false), "one")
        XCTAssertEqual(
            reasoningPreview("done paragraph\n\nstill streaming", running: true),
            "done paragraph"
        )
        XCTAssertEqual(reasoningBodyLineHeightPoints, 20)
        XCTAssertTrue(processGroupTitleUsesContentFontSize)
        XCTAssertTrue(processGroupMembersShareColumn)
        XCTAssertEqual(messageTurnProcessSeparator, " · ")
        XCTAssertEqual(
            processGroupHeaderTitle(label: "正在分析需求", detail: "读 README"),
            "正在分析需求 · 读 README"
        )
        XCTAssertEqual(processGroupHeaderTitle(label: "已完成分析", detail: nil), "已完成分析")
    }

    func testSidebarLeadingGreenDotAndSessionOnlySpinner() {
        XCTAssertEqual(
            sidebarSessionLeading(running: false, archived: false, unread: true, awaitingApproval: false, awaitingAnswer: false),
            .unread
        )
        XCTAssertEqual(
            sidebarSessionLeading(running: true, archived: false, unread: true, awaitingApproval: false, awaitingAnswer: false),
            .running
        )
        XCTAssertEqual(
            sidebarSessionLeading(running: false, archived: true, unread: true, awaitingApproval: false, awaitingAnswer: false),
            .idle
        )
        XCTAssertEqual(
            sidebarSessionLeading(running: false, archived: false, unread: true, awaitingApproval: true, awaitingAnswer: false),
            .awaitingApproval
        )
        XCTAssertEqual(
            sidebarSessionLeading(running: true, archived: false, unread: false, awaitingApproval: false, awaitingAnswer: true),
            .awaitingAnswer
        )
        XCTAssertEqual(
            sidebarSessionLeading(running: false, archived: false, unread: false, awaitingApproval: false, awaitingAnswer: false),
            .idle
        )
        XCTAssertTrue(sidebarWorkspaceKeepsFolderIcon)
        XCTAssertTrue(sidebarIdleSessionHasNoBubble)
        XCTAssertTrue(sidebarArchivedIdleHasNoLeadingIcon)
        XCTAssertEqual(sidebarLeadingSlotWidthPoints, 16)
        XCTAssertEqual(sidebarLeadingSlotHeightPoints, 14)
        XCTAssertEqual(sidebarCompletionDotRadiusRatio, 3.0 / 14.0)
        XCTAssertEqual(sidebarCompletionUnreadLabel(english: false), "已完成，未查看")
        XCTAssertEqual(sidebarCompletionUnreadLabel(english: true), "Completed, unread")
    }

    func testAgentPresetSeatMetrics() {
        XCTAssertEqual(agentPresetSeatMinHeightPoints, 28)
        XCTAssertEqual(agentPresetSeatFontSizePoints, 13)
        XCTAssertEqual(agentPresetSeatFontWeight, 500)
    }
}
