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
        XCTAssertTrue(sidebarFooterActionAboveSettings)
    }

    func testLandingWorkspaceChipMatchesDesktopHeroChip() {
        XCTAssertTrue(workspaceChipUsesGhostTrigger)
        XCTAssertFalse(workspaceChipUsesSystemMenu)
        XCTAssertEqual(workspaceChipMinHeightPoints, 28)
        XCTAssertEqual(workspaceChipMaxWidthPoints, 360)
        XCTAssertEqual(workspaceChipFontSizePoints, 13)
        XCTAssertEqual(workspaceChipFontWeight, 500)
        XCTAssertEqual(workspaceChipIconSizePoints, 16)
        XCTAssertEqual(workspaceChipChevronSizePoints, 12)
        XCTAssertTrue(workspaceChipOpensDirectoryFlowDirectly(workspaceCount: 0, canCreate: true))
        XCTAssertFalse(workspaceChipOpensDirectoryFlowDirectly(workspaceCount: 1, canCreate: true))
        XCTAssertFalse(workspaceChipOpensDirectoryFlowDirectly(workspaceCount: 0, canCreate: false))
        XCTAssertEqual(addWorkspaceMenuLabel(english: false), "添加工作区…")
        XCTAssertEqual(addWorkspaceMenuLabel(english: true), "Add workspace…")
        XCTAssertEqual(workspacePickerLoading(english: false), "正在加载工作区…")
        XCTAssertEqual(landingChooseWorkspace(english: false), "选择工作区")
    }

    func testPlanChipCopyAndModesRowMatchDesktop() {
        XCTAssertEqual(planChipLabel(english: false), "计划")
        XCTAssertEqual(planChipLabel(english: true), "Plan")
        XCTAssertEqual(planChipAria(english: false), "计划模式已开启，按下关闭")
        XCTAssertEqual(planChipAria(english: true), "Plan mode on, press to turn off")
        XCTAssertEqual(planChipTitle(english: false), "计划模式已开启 — 点击关闭（/plan off）")
        XCTAssertTrue(planChipLivesInComposerModesRow)
        XCTAssertEqual(planChipHeightPoints, 28)
        XCTAssertEqual(planChipFontSizePoints, 13)
        XCTAssertTrue(permissionChipRequiresCatalog)
        XCTAssertEqual(composerCommandsAria(english: false), "添加文件或调用指令")
        XCTAssertEqual(composerCommandsAria(english: true), "Add files or run commands")
        XCTAssertEqual(commandMenuStatusLoading(english: false), "正在加载选项…")
        XCTAssertEqual(commandMenuStatusEmpty(english: false), "无选项")
        XCTAssertEqual(commandMenuStatusEmpty(english: true), "No options")
    }

    func testAgentPresetAndPluginAddCopyMatchDesktopLocales() {
        XCTAssertEqual(agentPresetSeatHint(english: false), "选择新任务使用的 Agent 预设")
        XCTAssertEqual(agentPresetNoDescription(english: false), "暂无描述。")
        XCTAssertEqual(agentPresetNoDescription(english: true), "No description.")
        XCTAssertEqual(pluginAddInstallExisting(english: false), "安装第三方插件")
        XCTAssertEqual(pluginAddInstallExistingDescription(english: false), "支持 npm 包、Git 仓库和本地目录")
        XCTAssertEqual(pluginAddCreatePlugin(english: false), "让 Agent 创建插件")
        XCTAssertEqual(pluginAddChooseMethod(english: false), "选择添加插件方式")
        XCTAssertEqual(pluginAddCreatePluginDescription(english: false), "进入创造模式，制作属于你的 DSH 插件")
        XCTAssertEqual(pluginAddCreatePluginChecking(english: false), "正在确认创造模式是否可用")
        XCTAssertEqual(pluginAddCreatePluginUnavailable(english: false), "暂时不可用，请重新打开菜单重试")
        XCTAssertEqual(pluginAddCreatePluginMissing(english: false), "当前配置未提供创造模式")
        XCTAssertTrue(pluginAddMenuUsesMenuSurface)
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
        XCTAssertEqual(sidebarRunningLabel(english: false), "进行中")
        XCTAssertEqual(sidebarRunningLabel(english: true), "Running")
        XCTAssertTrue(searchResultShowsWorkspaceContext)
        XCTAssertEqual(
            drawerEmptyKind(online: true, archivedOnly: true, hasVisibleSessions: false),
            .emptyArchived
        )
        XCTAssertEqual(
            drawerEmptyKind(online: true, archivedOnly: false, hasVisibleSessions: false),
            .empty
        )
        XCTAssertEqual(
            drawerEmptyKind(online: false, archivedOnly: true, hasVisibleSessions: false),
            .offline
        )
        XCTAssertNil(drawerEmptyKind(online: true, archivedOnly: true, hasVisibleSessions: true))
        XCTAssertFalse(
            drawerShowsEmptySessions(
                hasVisibleSessions: false,
                groupByWorkspace: true,
                hasWorkspaces: true,
                archivedOnly: false
            )
        )
        XCTAssertTrue(
            drawerShowsEmptySessions(
                hasVisibleSessions: false,
                groupByWorkspace: true,
                hasWorkspaces: true,
                archivedOnly: true
            )
        )
        XCTAssertTrue(
            drawerShowsEmptySessions(
                hasVisibleSessions: false,
                groupByWorkspace: false,
                hasWorkspaces: true,
                archivedOnly: false
            )
        )
        XCTAssertTrue(
            drawerShowsEmptySessions(
                hasVisibleSessions: false,
                groupByWorkspace: true,
                hasWorkspaces: false,
                archivedOnly: false
            )
        )
        XCTAssertFalse(
            drawerShowsEmptySessions(
                hasVisibleSessions: true,
                groupByWorkspace: true,
                hasWorkspaces: true,
                archivedOnly: true
            )
        )
        XCTAssertEqual(emptyArchivedViewOthers(english: false), "查看其他会话")
        XCTAssertEqual(emptyArchivedViewOthers(english: true), "View other sessions")
        XCTAssertTrue(emptyArchivedViewOthersResetsToHide)
        XCTAssertEqual(
            archivedNotOpenable(english: false),
            "已归档对话暂时无法查看，请取消归档后查看"
        )
        XCTAssertEqual(
            archivedNotOpenable(english: true),
            "Archived sessions cannot be opened. Unarchive it to view."
        )
    }

    func testAgentPresetSeatMetrics() {
        XCTAssertEqual(agentPresetSeatMinHeightPoints, 28)
        XCTAssertEqual(agentPresetSeatFontSizePoints, 13)
        XCTAssertEqual(agentPresetSeatFontWeight, 500)
    }
}
