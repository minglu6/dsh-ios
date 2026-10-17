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
        XCTAssertTrue(composerAddButtonUsesFilledCircle)
        XCTAssertTrue(composerAddButtonUsesSelectorFill)
        XCTAssertEqual(composerAddButtonSelectorLightHex, 0xFFF5F6F7)
        XCTAssertEqual(composerAddButtonSelectorDarkHex, 0xFF353638)
        XCTAssertFalse(composerShowsAskChip)
        XCTAssertTrue(isAskUserQuestionTool("ask_user_question"))
        XCTAssertTrue(isAskUserQuestionTool("request_user_input"))
        XCTAssertFalse(isAskUserQuestionTool("bash"))
        XCTAssertTrue(
            askToolRowReopensComposer(
                toolName: "ask_user_question",
                callId: "c1",
                hiddenQuestionCallId: "c1"
            )
        )
        XCTAssertFalse(
            askToolRowReopensComposer(
                toolName: "ask_user_question",
                callId: "c1",
                hiddenQuestionCallId: nil
            )
        )
        XCTAssertFalse(
            askToolRowReopensComposer(
                toolName: "bash",
                callId: "c1",
                hiddenQuestionCallId: "c1"
            )
        )
        XCTAssertEqual(userQuestionCollapseId(questionId: "q1", callId: "c1"), "c1")
        XCTAssertEqual(userQuestionCollapseId(questionId: "q1", callId: nil), "q1")
        XCTAssertTrue(userQuestionIsCollapsed(questionId: "q1", callId: "c1", hiddenId: "c1"))
        XCTAssertTrue(userQuestionIsCollapsed(questionId: "q1", callId: "c1", hiddenId: "q1"))
        XCTAssertFalse(userQuestionIsCollapsed(questionId: "q1", callId: "c1", hiddenId: nil))
        XCTAssertFalse(userQuestionIsCollapsed(questionId: "q1", callId: "c1", hiddenId: "other"))
        XCTAssertTrue(landingAllowsDraftFileAttachments)
        XCTAssertFalse(landingFileAttachRequiresSession)
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
            .emptyArchived
        )
        XCTAssertEqual(
            drawerEmptyKind(online: false, archivedOnly: false, hasVisibleSessions: false),
            .empty
        )
        XCTAssertTrue(drawerEmptyIgnoresOnline)
        XCTAssertEqual(emptySessionsNone(english: false), "暂无会话")
        XCTAssertEqual(emptySessionsNone(english: true), "No sessions yet")
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

    func testSubagentHeaderCrumbsFollowDesktopAncestry() {
        let parent = SessionSummary(sessionId: "parent", title: "主任务")
        let child = SessionSummary(
            sessionId: "child",
            title: "子智能体",
            parentSessionId: "parent",
            origin: "subagent"
        )
        let crumbs = conversationHeaderAncestry(
            sessions: [parent, child],
            sessionId: "child",
            currentTitle: "子智能体",
            newSession: "新会话",
            untitled: "未命名"
        )
        XCTAssertTrue(conversationHeaderShowsCrumbs(crumbs))
        XCTAssertEqual(crumbs.map(\.sessionId), ["parent", "child"])
        XCTAssertEqual(crumbs.map(\.title), ["主任务", "子智能体"])
        XCTAssertEqual(crumbs.map(\.subagent), [false, true])
        XCTAssertEqual(crumbs.map(\.current), [false, true])
        XCTAssertEqual(sessionHierarchyAria(english: false), "会话层级")
        XCTAssertEqual(sessionHierarchyAria(english: true), "Session hierarchy")

        let regular = conversationHeaderAncestry(
            sessions: [parent],
            sessionId: "parent",
            currentTitle: "主任务",
            newSession: "新会话",
            untitled: "未命名"
        )
        XCTAssertFalse(conversationHeaderShowsCrumbs(regular))
        XCTAssertEqual(regular.map(\.sessionId), ["parent"])
        XCTAssertTrue(regular[0].current)
        XCTAssertTrue(
            conversationHeaderAncestry(
                sessions: [parent, child],
                sessionId: nil,
                currentTitle: "新会话",
                newSession: "新会话",
                untitled: "未命名"
            ).isEmpty
        )

        let loopA = SessionSummary(sessionId: "a", parentSessionId: "b", origin: "subagent")
        let loopB = SessionSummary(sessionId: "b", parentSessionId: "a", origin: "subagent")
        let loop = conversationHeaderAncestry(
            sessions: [loopA, loopB],
            sessionId: "a",
            currentTitle: "A",
            newSession: "新会话",
            untitled: "未命名"
        )
        XCTAssertEqual(Set(loop.map(\.sessionId)), ["a", "b"])
        XCTAssertEqual(loop.count, 2)
    }

    func testAskToolRowChromeMatchesDesktopAskQuestionRow() {
        XCTAssertEqual(askRowTitle(english: false), "提问")
        XCTAssertEqual(askRowTitle(english: true), "Ask question")
        XCTAssertEqual(toolProcessSummary(
            Item.Tool(key: "t", callId: "c1", name: "ask_user_question", arguments: #"{"q":"hi"}"#, status: .ok)
        ).title, "提问")
        XCTAssertEqual(toolProcessSummary(
            Item.Tool(key: "t", callId: "c1", name: "request_user_input", arguments: "{}", status: .ok),
            en: true
        ).title, "Ask question")

        let waiting = askToolRowChrome(
            name: "ask_user_question",
            status: .running,
            error: nil,
            result: nil,
            answerable: true,
            english: false
        )
        XCTAssertEqual(waiting?.title, "提问")
        XCTAssertEqual(waiting?.summary, "等待回答")
        XCTAssertEqual(waiting?.actionLabel, "回答")

        let pending = askToolRowChrome(
            name: "ask_user_question",
            status: .ok,
            error: nil,
            result: #"{"pending":true,"callId":"c1"}"#,
            answerable: true,
            english: false
        )
        XCTAssertEqual(pending?.summary, "已继续工作，仍可回答")
        XCTAssertEqual(pending?.actionLabel, "回答")
        XCTAssertTrue(isAskPendingResult(#"{"pending":true,"callId":"c1"}"#))
        XCTAssertFalse(isAskPendingResult(#"{"pending":false,"callId":"c1"}"#))
        XCTAssertFalse(isAskPendingResult("not-json"))

        let closed = askToolRowChrome(
            name: "ask_user_question",
            status: .ok,
            error: nil,
            result: #"{"pending":true,"callId":"c1"}"#,
            answerable: false,
            english: false
        )
        XCTAssertEqual(closed?.summary, "已结束")
        XCTAssertNil(closed?.actionLabel)

        XCTAssertEqual(
            askToolRowChrome(
                name: "ask_user_question",
                status: .error,
                error: "ASK_CANCELLED",
                result: nil,
                answerable: false,
                english: false
            )?.summary,
            "已取消"
        )
        XCTAssertEqual(
            askToolRowChrome(
                name: "ask_user_question",
                status: .error,
                error: "ASK_ABORTED",
                result: nil,
                answerable: false,
                english: true
            )?.summary,
            "interrupted"
        )
        XCTAssertNil(askToolRowChrome(
            name: "bash",
            status: .running,
            error: nil,
            result: nil,
            answerable: true,
            english: false
        ))
        XCTAssertTrue(askToolRowIsAnswerable(callId: "c1", questionId: "q1", activeCallIds: ["c1"]))
        XCTAssertTrue(askToolRowIsAnswerable(callId: nil, questionId: "q1", activeCallIds: ["q1"]))
        XCTAssertFalse(askToolRowIsAnswerable(callId: "c1", questionId: "q1", activeCallIds: []))
    }

    func testRetryAndTurnFailureMatchDesktopChatLocales() {
        XCTAssertEqual(retryAttemptLabel(state: .scheduled, active: true, english: false), "正在重试模型请求")
        XCTAssertEqual(retryAttemptLabel(state: .scheduled, active: false, english: false), "等待重试模型请求")
        XCTAssertEqual(retryAttemptLabel(state: .started, active: false, english: true), "Retried model request")
        XCTAssertEqual(retryAttemptLabel(state: .cancelled, active: false, english: false), "模型请求重试已取消")
        XCTAssertTrue(retryAttemptIsActive(state: .scheduled, isLast: true))
        XCTAssertFalse(retryAttemptIsActive(state: .scheduled, isLast: false))
        XCTAssertFalse(retryAttemptIsActive(state: .started, isLast: true))
        XCTAssertEqual(retryDelayMilliseconds(delayMs: 1500, english: false), "1500毫秒")
        XCTAssertEqual(retryDelayMilliseconds(delayMs: 1500, english: true), "1500ms")

        XCTAssertEqual(turnFailureTitle(code: "INTERRUPTED", english: false), "任务已停止")
        XCTAssertEqual(turnFailureTitle(code: "ACCOUNT_SIGNED_OUT", english: true), "Task stopped")
        XCTAssertEqual(turnFailureTitle(code: "MODEL", english: false), "本轮运行失败")
        XCTAssertFalse(turnFailureShowsCode("INTERRUPTED"))
        XCTAssertTrue(turnFailureShowsCode("ACCOUNT_SIGNED_OUT"))
        XCTAssertFalse(turnFailureShowsCode(nil))
        XCTAssertTrue(
            chatFailureMessage("wire", code: "INTERRUPTED", en: false)
                .contains("DSH 进程在本轮完成前退出")
        )
        XCTAssertEqual(chatFailureMessage("wire", code: "AUTH", en: false), "API 密钥无效")
        XCTAssertEqual(chatFailureMessage("wire", code: "QUOTA_EXCEEDED", en: false), "wire")
        XCTAssertEqual(chatFailureMessage("wire", code: "INVALID_API_KEY", en: false), "wire")
    }

    func testChangesDiffAndImageCopyMatchDesktopLocales() {
        XCTAssertEqual(messageImageLoading(english: false), "加载图片…")
        XCTAssertEqual(messageImageLoading(english: true), "Loading image…")
        XCTAssertEqual(messageImageFailed(english: false), "图片无法预览")
        XCTAssertEqual(messageImageFailed(english: true), "Image preview unavailable")

        XCTAssertEqual(changesDiffNoticeKind(nil), .missing)
        XCTAssertEqual(
            changesDiffNoticeKind(WorkspaceFileDiff(kind: "binary", path: "a", display: "a")),
            .binary
        )
        XCTAssertEqual(
            changesDiffNoticeKind(WorkspaceFileDiff(kind: "oversized", path: "a", display: "a")),
            .oversized
        )
        XCTAssertEqual(
            changesDiffNoticeKind(WorkspaceFileDiff(kind: "text", path: "a", display: "a", before: false, after: true)),
            .created
        )
        XCTAssertEqual(
            changesDiffNoticeKind(WorkspaceFileDiff(kind: "text", path: "a", display: "a", before: true, after: false)),
            .deleted
        )
        XCTAssertEqual(
            changesDiffNoticeKind(WorkspaceFileDiff(kind: "text", path: "a", display: "a", before: true, after: true)),
            .unchanged
        )
        XCTAssertEqual(
            changesDiffNoticeKind(WorkspaceFileDiff(kind: "text", path: "a", display: "a", before: true, after: true, coarse: true)),
            .coarse
        )
        XCTAssertNil(
            changesDiffNoticeKind(WorkspaceFileDiff(
                kind: "text",
                path: "a",
                display: "a",
                hunks: [WorkspaceDiffHunk(oldStart: 1, newStart: 1, lines: [" same"])]
            ))
        )
        XCTAssertEqual(changesDiffNoticeLabel(.missing, english: false), "这轮改动的内容已不可用")
        XCTAssertEqual(changesDiffNoticeLabel(.binary, english: false), "二进制文件，无法显示改动")
        XCTAssertEqual(changesDiffNoticeLabel(.oversized, english: false), "文件过大，无法显示改动")
        XCTAssertEqual(changesDiffNoticeLabel(.created, english: false), "本轮新建的文件")
        XCTAssertEqual(changesDiffNoticeLabel(.deleted, english: false), "本轮删除的文件")
        XCTAssertEqual(changesDiffNoticeLabel(.unchanged, english: false), "两侧内容相同")
        XCTAssertEqual(changesDiffNoticeLabel(.coarse, english: false), "逐行对比超时，按整个文件替换显示")
        XCTAssertEqual(changesDiffTruncatedLabel(count: 5000, english: false), "只显示前 5000 行")
        XCTAssertEqual(changesDiffTruncatedLabel(count: 5000, english: true), "Showing the first 5000 lines")
    }

    func testToolRowTitlesMatchDesktopConversationLocale() {
        XCTAssertEqual(toolRowTitle(name: "grep", english: false), "搜索文件内容")
        XCTAssertEqual(toolRowTitle(name: "grep", english: true), "Grep")
        XCTAssertEqual(toolRowTitle(name: "glob", english: false), "查找文件")
        XCTAssertEqual(toolRowTitle(name: "glob", english: true), "Glob")
        XCTAssertEqual(toolRowTitle(name: "web_search", english: false), "网页搜索")
        XCTAssertEqual(toolRowTitle(name: "web_fetch", english: false), "网页获取")
        XCTAssertEqual(toolRowTitle(name: "web_fetch", english: true), "Fetch")
        XCTAssertEqual(toolRowTitle(name: "pwsh", english: true), "Pwsh")
        XCTAssertEqual(toolRowTitle(name: "todo_write", english: true), "Update to-do list")
        XCTAssertEqual(toolRowTitle(name: "get_goal", english: true), "View goal")
        XCTAssertEqual(toolRowTitle(name: "schedule_create", english: true), "Create reminder")
        XCTAssertEqual(toolRowTitle(name: "schedule_list", english: true), "List reminders")
        XCTAssertEqual(toolRowTitle(name: "ralph", english: true), "Run ralph loop")
        XCTAssertEqual(toolRowTitle(name: "spawn_teammate", english: true), "Create teammate")
        XCTAssertEqual(toolRowTitle(name: "list_subagent_models", english: true), "List models")
        XCTAssertEqual(toolRowTitle(name: "cordis_inspect_self", english: true), "Inspect plugins")
        XCTAssertEqual(
            toolRowTitle(name: "lsp", arguments: #"{"operation":"goToDefinition"}"#, english: false),
            "查找定义"
        )
        XCTAssertEqual(
            toolRowTitle(name: "lsp", arguments: #"{"operation":"findReferences"}"#, english: true),
            "Find references"
        )
        XCTAssertEqual(
            toolRowTitle(name: "lsp", arguments: #"{"operation":"goToImplementation"}"#, english: false),
            "查找实现"
        )
        XCTAssertEqual(
            toolRowTitle(name: "lsp", arguments: #"{"operation":"hover"}"#, english: true),
            "Inspect symbol"
        )
        XCTAssertEqual(toolRowTitle(name: "lsp", english: false), "查询代码符号")
        XCTAssertEqual(toolRowTitle(name: "vendor.unknown", english: false), "工具调用")
        XCTAssertEqual(toolRowStateStatus(.preparing, english: false), "正在准备调用")
        XCTAssertEqual(toolRowStateStatus(.preparing, english: true), "Preparing tool call")
        XCTAssertEqual(toolRowStateStatus(.running, english: false), "运行中")
        XCTAssertEqual(toolRowStateStatus(.error, english: true), "Failed")
        XCTAssertNil(toolRowStateStatus(.ok, english: false))
        XCTAssertNil(toolRowStateStatus(.awaitingApproval, english: false))

        let preparingRead = toolProcessSummary(
            Item.Tool(
                key: "t",
                callId: "c1",
                name: "read",
                arguments: #"{"path":"src/a.ts"}"#,
                status: .preparing
            )
        )
        XCTAssertEqual(preparingRead.title, "读取")
        XCTAssertEqual(preparingRead.summary, "src/a.ts")
        XCTAssertNotEqual(preparingRead.title, preparingToolTitle("read"))

        let preparingBash = toolProcessSummary(
            Item.Tool(
                key: "t",
                callId: "c1",
                name: "bash",
                arguments: #"{"command":"npm test","description":"Run tests"}"#,
                status: .preparing
            ),
            en: true
        )
        XCTAssertEqual(preparingBash.title, "Bash")
        XCTAssertEqual(preparingBash.summary, "Run tests")
    }

    func testGoalPhaseMatchesDesktopDetailGoal() {
        XCTAssertEqual(goalPhaseLabel(phase: "active", activation: "armed", english: false), "进行中")
        XCTAssertEqual(goalPhaseLabel(phase: "active", activation: "disarmed", english: false), "等待继续")
        XCTAssertEqual(goalPhaseLabel(phase: "paused", activation: nil, english: false), "已暂停")
        XCTAssertEqual(goalPhaseLabel(phase: "blocked", activation: nil, english: false), "受阻")
        XCTAssertEqual(goalPhaseLabel(phase: "complete", activation: nil, english: false), "已完成")
        XCTAssertEqual(goalPhaseLabel(phase: nil, activation: nil, english: false), "没有目标")
        XCTAssertEqual(goalPhaseLabel(phase: "active", activation: "armed", english: true), "Active")
        XCTAssertEqual(goalPhaseLabel(phase: "active", activation: "disarmed", english: true), "Awaiting continuation")
        XCTAssertNotEqual(goalPhaseLabel(phase: "active", activation: "disarmed"), goalPhaseLabel(phase: "paused", activation: nil))
    }

    func testCompactionItemCopyAndVisibilityMatchDesktopChatLocale() {
        XCTAssertEqual(compactionRowTitle(sourceCommandId: nil, english: false), "上下文已压缩")
        XCTAssertEqual(compactionRowTitle(sourceCommandId: nil, english: true), "Context compacted")
        XCTAssertEqual(compactionRowTitle(sourceCommandId: "cmd-1", english: false), "compact")
        XCTAssertEqual(compactionRowTitle(sourceCommandId: "cmd-1", english: true), "compact")

        XCTAssertEqual(
            compactionRowSummary(
                shadowedItemCount: 12,
                shadowedTokenCount: 3400,
                fallbackSummary: nil,
                hasSummary: true,
                english: false
            ),
            "已压缩 12 条历史记录（约 3400 tokens）"
        )
        XCTAssertEqual(
            compactionRowSummary(
                shadowedItemCount: 12,
                shadowedTokenCount: 3400,
                fallbackSummary: nil,
                hasSummary: true,
                english: true
            ),
            "Compacted 12 history items (~3400 tokens)"
        )
        XCTAssertEqual(
            compactionRowSummary(
                shadowedItemCount: 12,
                shadowedTokenCount: nil,
                fallbackSummary: nil,
                hasSummary: true,
                english: false
            ),
            "点击查看压缩摘要"
        )
        XCTAssertEqual(
            compactionRowSummary(
                shadowedItemCount: nil,
                shadowedTokenCount: nil,
                fallbackSummary: nil,
                hasSummary: false,
                english: false
            ),
            "压缩摘要不可用"
        )
        XCTAssertEqual(
            compactionRowSummary(
                shadowedItemCount: nil,
                shadowedTokenCount: nil,
                fallbackSummary: nil,
                hasSummary: true,
                english: true
            ),
            "View compaction summary"
        )
        XCTAssertEqual(
            compactionRowSummary(
                shadowedItemCount: nil,
                shadowedTokenCount: nil,
                fallbackSummary: "kept the goal",
                hasSummary: false,
                english: false
            ),
            "kept the goal"
        )

        let running = Item.Compacted(key: "c1", compactionId: "id1", status: .running)
        XCTAssertFalse(compactionItemIsVisible(running))
        XCTAssertFalse(compactionRowIsExpandable(running))

        let landed = Item.Compacted(
            key: "c2", compactionId: "id2", status: .running, hasCheckpoint: true
        )
        XCTAssertTrue(compactionItemIsVisible(landed))

        let done = Item.Compacted(
            key: "c3",
            compactionId: "id3",
            status: .ok,
            summary: "Kept the goal.",
            shadowedItemCount: 4,
            shadowedTokenCount: 800
        )
        XCTAssertTrue(compactionItemIsVisible(done))
        XCTAssertTrue(compactionRowIsExpandable(done))
        XCTAssertEqual(
            compactionRowSummary(item: done, english: false),
            "已压缩 4 条历史记录（约 800 tokens）"
        )

        let failed = Item.Compacted(key: "c4", compactionId: "id4", status: .error)
        XCTAssertTrue(compactionItemIsVisible(failed))
        XCTAssertEqual(compactionRowSummary(item: failed, english: true), "Compaction summary unavailable")
    }

    func testCompactionSummaryParsesDesktopArrayAndShadowedCounts() throws {
        let data = try JSONValue.parse("""
        {
          "compactionId": "c1",
          "summary": [
            {"type":"text","text":"Keep "},
            {"type":"ignore","text":"nope"},
            {"type":"text","text":"the goal."}
          ],
          "shadowedSeqs": [1, 2, 3],
          "shadowedTokenCount": 900
        }
        """)
        XCTAssertEqual(compactionSummaryText(from: data["summary"]), "Keep the goal.")
        XCTAssertEqual(compactionShadowedItemCount(from: data), 3)
        XCTAssertEqual(compactionShadowedTokenCount(from: data), 900)

        let stringSummary = try JSONValue.parse(#"{"summary":"Keep the goal."}"#)
        XCTAssertNil(compactionSummaryText(from: stringSummary["summary"]))

        let badSeqs = try JSONValue.parse(#"{"shadowedSeqs":[1,-1],"shadowedTokenCount":-3}"#)
        XCTAssertNil(compactionShadowedItemCount(from: badSeqs))
        XCTAssertNil(compactionShadowedTokenCount(from: badSeqs))
    }

    func testCompactionCheckpointIsReplacementUserMessage() throws {
        let event = try JSONValue.parse("""
        {"type":"user/message","surfaceOp":"replace","seq":9,"data":{
          "source":{"kind":"compact-checkpoint","compactionId":"c1","sourceCommandId":"cmd-9"},
          "content":[{"type":"text","text":"<compaction>"}]
        }}
        """)
        XCTAssertTrue(isCompactionCheckpoint(event: event, data: event["data"]))
        XCTAssertEqual(compactionCheckpointId(from: event["data"]), "c1")
        XCTAssertEqual(compactionCheckpointCommandId(from: event["data"]), "cmd-9")

        let append = try JSONValue.parse("""
        {"type":"user/message","surfaceOp":"append","data":{
          "source":{"kind":"compact-checkpoint","compactionId":"c1"}
        }}
        """)
        XCTAssertFalse(isCompactionCheckpoint(event: append, data: append["data"]))

        let human = try JSONValue.parse("""
        {"type":"user/message","surfaceOp":"replace","data":{"source":{"kind":"user"}}}
        """)
        XCTAssertFalse(isCompactionCheckpoint(event: human, data: human["data"]))
    }

    func testFoldChatItemsUnhidesLandedCompactionItem() {
        let running = Item.Compacted(key: "cmp-run", compactionId: "r1", status: .running)
        let done = Item.Compacted(
            key: "cmp-done",
            compactionId: "d1",
            status: .ok,
            summary: "Kept the goal.",
            shadowedItemCount: 2,
            shadowedTokenCount: 40
        )
        let rows = foldChatItems(
            [
                .user(Item.User(key: "u", text: "hi")),
                .compacted(running),
                .compacted(done),
            ],
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        XCTAssertFalse(rows.contains { if case .compacted(let item) = $0 { return item.key == "cmp-run" }; return false })
        XCTAssertTrue(rows.contains { if case .compacted(let item) = $0 { return item.key == "cmp-done" }; return false })
        XCTAssertTrue(rows.contains { if case .user = $0 { return true }; return false })
    }

    func testTranscriptReducerBuildsDesktopCompactionMarker() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"compaction/start","seq":1,"time":10,"data":{"compactionId":"c1","turn":1}}}
        """)))
        XCTAssertEqual(foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false).count, 0)

        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"compaction/summary","seq":2,"time":11,"data":{
          "compactionId":"c1",
          "summary":[{"type":"text","text":"Kept the goal."}],
          "shadowedSeqs":[1,2,3,4],
          "shadowedTokenCount":1200
        }}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":3,"time":12,"surfaceOp":"replace","data":{
          "source":{"kind":"compact-checkpoint","compactionId":"c1"},
          "content":[{"type":"text","text":"<envelope>"}]
        }}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"compaction/end","seq":4,"time":13,"data":{"compactionId":"c1"}}}
        """)))

        let compacted = reducer.items().compactMap { item -> Item.Compacted? in
            if case .compacted(let value) = item { return value }
            return nil
        }
        XCTAssertEqual(compacted.count, 1)
        let marker = try XCTUnwrap(compacted.first)
        XCTAssertEqual(marker.status, .ok)
        XCTAssertEqual(marker.summary, "Kept the goal.")
        XCTAssertEqual(marker.shadowedItemCount, 4)
        XCTAssertEqual(marker.shadowedTokenCount, 1200)
        XCTAssertTrue(marker.hasCheckpoint)
        XCTAssertNil(marker.sourceCommandId)

        let users = reducer.items().compactMap { item -> Item.User? in
            if case .user(let user) = item { return user }
            return nil
        }
        XCTAssertTrue(users.isEmpty)

        let rows = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        guard case .compacted(let row) = try XCTUnwrap(rows.first) else {
            return XCTFail("expected CompactionItem row")
        }
        XCTAssertEqual(compactionRowTitle(sourceCommandId: row.sourceCommandId, english: false), "上下文已压缩")
        XCTAssertEqual(compactionRowSummary(item: row, english: false), "已压缩 4 条历史记录（约 1200 tokens）")
    }

    func testManualCompactCheckpointUsesCommandTitle() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"compaction/start","seq":1,"time":10,"data":{
          "compactionId":"c2","sourceCommandId":"cmd-compact"
        }}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":2,"time":11,"surfaceOp":"replace","data":{
          "source":{"kind":"compact-checkpoint","compactionId":"c2","sourceCommandId":"cmd-compact"},
          "content":[{"type":"text","text":"<envelope>"}]
        }}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"compaction/end","seq":3,"time":12,"data":{"compactionId":"c2"}}}
        """)))
        let marker = reducer.items().compactMap { item -> Item.Compacted? in
            if case .compacted(let value) = item { return value }
            return nil
        }.first
        XCTAssertEqual(marker?.sourceCommandId, "cmd-compact")
        XCTAssertEqual(compactionRowTitle(sourceCommandId: marker?.sourceCommandId, english: true), "compact")
    }

    func testContextToolChangeCopyMatchesDesktopChatLocale() {
        XCTAssertEqual(
            contextToolChangeTitle(added: ["bash"], removed: [], english: false),
            "已添加工具：bash"
        )
        XCTAssertEqual(
            contextToolChangeTitle(added: [], removed: ["web_search"], english: true),
            "Tool removed: web_search"
        )
        XCTAssertEqual(
            contextToolChangeTitle(added: ["bash", "read"], removed: [], english: false),
            "工具已更新"
        )
        XCTAssertEqual(
            contextToolChangeSummary(added: ["bash", "read"], removed: [], english: false),
            "新增 2 个"
        )
        XCTAssertEqual(
            contextToolChangeSummary(added: ["bash"], removed: ["web_search"], english: true),
            "1 added, 1 removed"
        )
        XCTAssertNil(contextToolChangeSummary(added: ["bash"], removed: [], english: false))
        XCTAssertFalse(contextToolChangeIsExpandable(added: ["bash"], removed: []))
        XCTAssertTrue(contextToolChangeIsExpandable(added: ["bash", "read"], removed: []))
        XCTAssertEqual(contextToolChangeAddedLine(names: ["bash", "read"], english: false), "新增：bash, read")
        XCTAssertEqual(contextToolChangeRemovedLine(names: ["web_search"], english: true), "Removed: web_search")
        XCTAssertEqual(maxTokensTitle(english: false), "已达到输出 token 上限")
        XCTAssertEqual(
            maxTokensHint(english: false),
            "回答被截断，已有输出保留在对话中。发送“继续”可让模型接着输出。"
        )
        XCTAssertEqual(maxTokensTitle(english: true), "Output token limit reached")
        XCTAssertEqual(messageStopped(english: true), "Stopped")
        XCTAssertEqual(
            noticeChatTitle(Item.Notice(key: "mt", text: "", kind: .maxTokens), english: false),
            "已达到输出 token 上限"
        )
    }

    func testFoldChatItemsShowsToolChangeContextAndHidesOrdinaryInjection() {
        let added = Item.Context(
            key: "d1",
            text: "",
            sourceKind: "developer",
            toolAdditions: ["bash"]
        )
        let mixed = Item.Context(
            key: "d2",
            text: "skills",
            sourceKind: "skill-catalog",
            toolAdditions: ["read"],
            toolRemovals: ["web_search"]
        )
        let hidden = Item.Context(key: "inj", text: "skills", sourceKind: "skill-catalog")
        let rows = foldChatItems(
            [.context(added), .context(mixed), .context(hidden)],
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        XCTAssertTrue(rows.contains { if case .context(let item) = $0 { return item.key == "d1" }; return false })
        XCTAssertTrue(rows.contains { if case .context(let item) = $0 { return item.key == "d2" }; return false })
        XCTAssertFalse(rows.contains { if case .context(let item) = $0 { return item.key == "inj" }; return false })
        XCTAssertFalse(rows.contains { if case .turnTrigger = $0 { return true }; return false })
        XCTAssertTrue(contextItemIsVisible(added))
        XCTAssertTrue(contextToolChangeIsExclusive(added))
        XCTAssertFalse(contextToolChangeIsExclusive(mixed))
        XCTAssertEqual(contextRowTitle(item: mixed, english: false), "上下文注入")
        XCTAssertEqual(contextRowTitle(item: added, english: false), "已添加工具：bash")
        XCTAssertFalse(contextItemIsVisible(hidden))
    }

    func testTranscriptReducerKeepsDeveloperToolChangeAndDropsEmptyText() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"developer/message","seq":1,"time":10,"data":{"message":{
          "id":"dev-1",
          "content":[{"type":"tool-addition","toolName":"bash"}],
          "source":{"kind":"developer"}
        }}}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"developer/message","seq":2,"time":11,"data":{"message":{
          "id":"dev-empty",
          "content":[{"type":"text","text":"   "}],
          "source":{"kind":"developer"}
        }}}}
        """)))
        let contexts = reducer.items().compactMap { item -> Item.Context? in
            if case .context(let value) = item { return value }
            return nil
        }
        XCTAssertEqual(contexts.count, 1)
        XCTAssertEqual(contexts[0].toolAdditions, ["bash"])
        XCTAssertEqual(contexts[0].toolRemovals, [])
        XCTAssertTrue(contexts[0].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let rows = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        guard case .context(let row) = try XCTUnwrap(rows.first) else {
            return XCTFail("expected ContextInjectionRow tool-change")
        }
        XCTAssertEqual(contextToolChangeTitle(item: row, english: false), "已添加工具：bash")
        XCTAssertNil(contextToolChangeSummary(item: row, english: false))
    }

    func testTurnEndMaxTokensIsOneNoticeAndSignedOutIsTurnError() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"turn/end","seq":1,"time":10,"data":{"turn":1,"reason":{"kind":"max-tokens"}}}}
        """)))
        let maxTokens = reducer.items().compactMap { item -> Item.Notice? in
            if case .notice(let value) = item { return value }
            return nil
        }
        XCTAssertEqual(maxTokens.map(\.kind), [.maxTokens])
        XCTAssertEqual(maxTokens.count, 1)

        let signedOut = TranscriptReducer()
        XCTAssertTrue(signedOut.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(signedOut.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"turn/end","seq":1,"time":10,"data":{"turn":2,"reason":{
          "kind":"aborted","reason":{"kind":"hook","reason":"deepseek-account/signed-out"}
        }}}}
        """)))
        let failures = signedOut.items().compactMap { item -> Item.TurnFailure? in
            if case .turnFailure(let value) = item { return value }
            return nil
        }
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].code, "ACCOUNT_SIGNED_OUT")
        XCTAssertEqual(turnFailureTitle(code: failures[0].code, english: false), "任务已停止")
        XCTAssertEqual(
            chatFailureMessage(failures[0].message, code: failures[0].code, en: false),
            "任务已因退出 DeepSeek 登录而停止。"
        )
        XCTAssertTrue(signedOut.items().allSatisfy { item in
            if case .notice = item { return false }
            return true
        })
    }

    func testCommandCardCopyMatchesDesktopChatLocale() {
        let running = Item.Command(key: "c1", commandId: "id1", name: "export")
        XCTAssertEqual(commandRowTitle(running, english: false), "export")
        XCTAssertEqual(commandRowSummary(running, english: false), "执行中…")
        XCTAssertEqual(commandRowSummary(running, english: true), "Running…")
        XCTAssertTrue(commandRowIsRunning(running))
        XCTAssertFalse(commandRowIsExpandable(running))
        XCTAssertEqual(commandRowStateLabel(running, english: false), "运行中")

        let compactRunning = Item.Command(key: "c2", commandId: "id2", name: "compact")
        XCTAssertEqual(commandRowSummary(compactRunning, english: false), "正在压缩…")
        XCTAssertEqual(commandRowSummary(compactRunning, english: true), "Compacting context…")

        let nameless = Item.Command(key: "c3", commandId: "id3")
        XCTAssertEqual(commandRowTitle(nameless, english: false), "指令")
        XCTAssertEqual(commandRowTitle(nameless, english: true), "Command")

        let failed = Item.Command(
            key: "c4", commandId: "id4", name: "export", outcomeKind: .error
        )
        XCTAssertEqual(commandRowSummary(failed, english: false), "指令失败")
        XCTAssertEqual(commandRowStateLabel(failed, english: true), "Failed")
        XCTAssertTrue(commandRowIsError(failed))

        let done = Item.Command(
            key: "c5", commandId: "id5", name: "export", outcomeKind: .success
        )
        XCTAssertEqual(commandRowSummary(done, english: false), "已完成")
        XCTAssertEqual(commandRowSummary(done, english: true), "Completed")

        let multiline = Item.Command(
            key: "c6",
            commandId: "id6",
            name: "export",
            outcomeKind: .success,
            outcomeText: "line1\nline2"
        )
        XCTAssertTrue(commandRowIsExpandable(multiline))
        XCTAssertEqual(commandRowSummary(multiline, english: false), "line1\nline2")
    }

    func testPermissionCommandAndCompactCheckpointFoldLikeDesktop() {
        let permission = Item.Command(key: "p", commandId: "perm-1", name: "permission")
        let compactRun = Item.Command(key: "cr", commandId: "cmd-c", name: "compact")
        let compactDone = Item.Command(
            key: "cd", commandId: "cmd-c", name: "compact", outcomeKind: .success
        )
        let checkpoint = Item.Compacted(
            key: "cmp",
            compactionId: "c1",
            status: .ok,
            sourceCommandId: "cmd-c",
            hasCheckpoint: true
        )
        let exportRun = Item.Command(key: "ex", commandId: "exp-1", name: "export")

        XCTAssertFalse(commandItemIsVisible(permission, compactCheckpointCommandIds: []))
        XCTAssertTrue(commandItemIsVisible(compactRun, compactCheckpointCommandIds: []))
        XCTAssertFalse(commandItemIsVisible(compactDone, compactCheckpointCommandIds: ["cmd-c"]))
        XCTAssertTrue(compactionItemIsVisible(checkpoint))

        let runningRows = foldChatItems(
            [.command(compactRun), .command(permission), .command(exportRun)],
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        XCTAssertEqual(runningRows.compactMap { row -> String? in
            if case .command(let item) = row { return item.commandId }
            return nil
        }, ["cmd-c", "exp-1"])

        let landedRows = foldChatItems(
            [.command(compactDone), .compacted(checkpoint)],
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        XCTAssertFalse(landedRows.contains { if case .command = $0 { return true }; return false })
        XCTAssertTrue(landedRows.contains { if case .compacted = $0 { return true }; return false })
    }

    func testManualCompactEndWithoutCheckpointStaysOnCommandCard() {
        let failedCompact = Item.Compacted(
            key: "cmp",
            compactionId: "c1",
            status: .error,
            sourceCommandId: "cmd-c"
        )
        let command = Item.Command(
            key: "cd",
            commandId: "cmd-c",
            name: "compact",
            outcomeKind: .error,
            outcomeText: "no compactable history"
        )
        XCTAssertFalse(compactionItemIsVisible(failedCompact))
        let rows = foldChatItems(
            [.command(command), .compacted(failedCompact)],
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        guard case .command(let row) = try? XCTUnwrap(rows.first) else {
            return XCTFail("expected GenericCommandCard for failed compact")
        }
        XCTAssertEqual(commandRowSummary(row, english: false), "no compactable history")
        XCTAssertFalse(rows.contains { if case .compacted = $0 { return true }; return false })
    }

    func testTranscriptReducerFoldsCommandRunAndDone() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"command/run","seq":1,"time":10,"data":{
          "commandId":"cmd-export","name":"export","args":" session"
        }}}
        """)))
        let running = reducer.items().compactMap { item -> Item.Command? in
            if case .command(let value) = item { return value }
            return nil
        }
        XCTAssertEqual(running.count, 1)
        XCTAssertEqual(running[0].name, "export")
        XCTAssertEqual(running[0].args, " session")
        XCTAssertNil(running[0].outcomeKind)
        XCTAssertEqual(
            commandRowSummary(try XCTUnwrap(running.first), english: false),
            "执行中…"
        )

        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"command/done","seq":2,"time":11,"data":{
          "commandId":"cmd-export","kind":"success","text":"exported\\n2 files"
        }}}
        """)))
        let done = try XCTUnwrap(reducer.items().compactMap { item -> Item.Command? in
            if case .command(let value) = item { return value }
            return nil
        }.first)
        XCTAssertEqual(done.outcomeKind, .success)
        XCTAssertEqual(done.outcomeText, "exported\n2 files")
        XCTAssertEqual(done.seq, 1)
        XCTAssertTrue(commandRowIsExpandable(done))

        let rows = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        guard case .command(let row) = try XCTUnwrap(rows.first) else {
            return XCTFail("expected CommandNode row")
        }
        XCTAssertEqual(commandRowTitle(row, english: false), "export")
    }

    func testTranscriptReducerWindowCutDoneAndManualCompact() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"command/done","seq":4,"time":20,"data":{
          "commandId":"only-done","kind":"error"
        }}}
        """)))
        let cut = try XCTUnwrap(reducer.items().compactMap { item -> Item.Command? in
            if case .command(let value) = item { return value }
            return nil
        }.first)
        XCTAssertNil(cut.name)
        XCTAssertEqual(cut.seq, 4)
        XCTAssertEqual(commandRowTitle(cut, english: true), "Command")
        XCTAssertEqual(commandRowSummary(cut, english: true), "Command failed")

        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"command/run","seq":5,"time":21,"data":{
          "commandId":"cmd-compact","name":"compact"
        }}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"compaction/start","seq":6,"time":22,"data":{
          "compactionId":"c9","sourceCommandId":"cmd-compact"
        }}}
        """)))
        var rows = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        XCTAssertTrue(rows.contains { if case .command(let item) = $0 { return item.commandId == "cmd-compact" }; return false })
        XCTAssertFalse(rows.contains { if case .compacted = $0 { return true }; return false })
        XCTAssertEqual(
            rows.compactMap { row -> String? in
                if case .command(let item) = row, item.commandId == "cmd-compact" {
                    return commandRowSummary(item, english: false)
                }
                return nil
            }.first,
            "正在压缩…"
        )

        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":7,"time":23,"surfaceOp":"replace","data":{
          "source":{"kind":"compact-checkpoint","compactionId":"c9","sourceCommandId":"cmd-compact"},
          "content":[{"type":"text","text":"<envelope>"}]
        }}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"command/done","seq":8,"time":24,"data":{
          "commandId":"cmd-compact","kind":"success","text":"kept the goal"
        }}}
        """)))
        rows = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        XCTAssertFalse(rows.contains { if case .command(let item) = $0 { return item.commandId == "cmd-compact" }; return false })
        guard case .compacted(let marker) = rows.first(where: { if case .compacted = $0 { return true }; return false }) else {
            return XCTFail("expected CompactionItem after checkpoint")
        }
        XCTAssertEqual(marker.commandOutcomeText, "kept the goal")
        XCTAssertEqual(compactionRowTitle(sourceCommandId: marker.sourceCommandId, english: false), "compact")
        XCTAssertEqual(compactionRowSummary(item: marker, english: false), "kept the goal")
    }

    func testFileOpenAndPdfFailedMatchDesktopLocales() {
        XCTAssertEqual(fileOpenTitle(english: false), "无法打开文件")
        XCTAssertEqual(fileOpenTitle(english: true), "Couldn\u{2019}t open file")
        XCTAssertEqual(fileOpenUnknown(english: false), "无法打开此文件")
        XCTAssertEqual(fileOpenUnknown(english: true), "Couldn\u{2019}t open this file")
        XCTAssertTrue(fileOpenTitle(english: true).contains("\u{2019}"))
        XCTAssertFalse(fileOpenTitle(english: true).contains("Could not open"))
        XCTAssertEqual(pdfFailedMessage("broken", english: true), "Cannot display PDF: broken")
        XCTAssertEqual(pdfFailedMessage("无法打开文件", english: false), "无法显示 PDF：无法打开文件")
        XCTAssertEqual(
            pdfDocumentOpenFailed(english: true),
            "Cannot display PDF: Couldn\u{2019}t open file"
        )
        XCTAssertEqual(pdfDocumentOpenFailed(english: false), "无法显示 PDF：无法打开文件")
    }

    func testSessionRecallLabelsProjectOntoUserAndStayHiddenAsContextRow() throws {
        XCTAssertEqual(
            sessionRecallLabels(source: try JSONValue.parse(#"""
            {"kind":"session-reference","form":"recall","references":[
              {"label":"Design notes","retainedMessages":3,"omittedMessages":1,"truncated":false},
              {"label":"Design notes","retainedMessages":1,"omittedMessages":0,"truncated":false},
              {"label":"Bug triage","retainedMessages":2,"omittedMessages":0,"truncated":true}
            ]}
            """#)),
            ["Design notes", "Bug triage"]
        )
        XCTAssertEqual(
            sessionRecallLabels(source: try JSONValue.parse(#"{"kind":"agent-instructions","changes":[]}"#)),
            []
        )
        XCTAssertEqual(
            referenceSummaryText(labels: ["Design notes", "Bug triage"], english: false),
            "引用会话 · Design notes、Bug triage"
        )
        XCTAssertEqual(
            referenceSummaryText(labels: ["Design notes", "Bug triage"], english: true),
            "Referenced session · Design notes, Bug triage"
        )
        XCTAssertNil(referenceSummaryText(labels: [], english: true))

        let user = Item.User(key: "u4", text: "look at that session", seq: 4)
        let recall = Item.Context(
            key: "x5",
            text: "recalled turns",
            sourceKind: "session-reference",
            seq: 5,
            recallLabels: ["Design notes", "Bug triage"]
        )
        let instructions = Item.Context(
            key: "x6",
            text: "<system-reminder>",
            sourceKind: "agent-instructions"
        )
        XCTAssertFalse(contextItemIsVisible(recall))
        XCTAssertFalse(contextItemIsVisible(instructions))
        let labeled = applyingUserReferenceLabels([.user(user), .context(recall), .context(instructions)])
        guard case .user(let projected) = labeled[0] else {
            return XCTFail("expected labeled user")
        }
        XCTAssertEqual(projected.referenceLabels, ["Design notes", "Bug triage"])
        let rows = foldChatItems(labeled, policy: presentationPolicyFor(.detailed), sessionRunning: false)
        XCTAssertEqual(rows.count, 1)
        guard case .user(let row) = rows[0] else {
            return XCTFail("expected user row only")
        }
        XCTAssertEqual(row.referenceLabels, ["Design notes", "Bug triage"])
        XCTAssertEqual(referenceSummaryText(labels: row.referenceLabels, english: false), "引用会话 · Design notes、Bug triage")
        XCTAssertFalse(rows.contains { if case .context = $0 { return true }; return false })
    }

    func testTranscriptReducerKeepsSessionReferenceForUserLabels() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":10,"time":30,"data":{"message":{
          "id":"u-ref",
          "content":[{"type":"text","text":"use that chat"}],
          "source":{"kind":"user"}
        }}}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":11,"time":31,"data":{"message":{
          "id":"recall-1",
          "content":[{"type":"text","text":"prior turns"}],
          "source":{"kind":"session-reference","form":"recall","references":[
            {"sessionId":"s-a","label":"Alpha","retainedMessages":2,"omittedMessages":0,"truncated":false}
          ]}
        }}}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":12,"time":32,"data":{"message":{
          "id":"instr-1",
          "content":[{"type":"text","text":"<system-reminder>loaded AGENTS.md"}],
          "source":{"kind":"agent-instructions","form":"instructions","changes":[
            {"action":"set","path":"AGENTS.md"}
          ]}
        }}}}
        """)))
        let contexts = reducer.items().compactMap { item -> Item.Context? in
            if case .context(let value) = item { return value }
            return nil
        }
        XCTAssertEqual(contexts.map(\.sourceKind), ["session-reference", "agent-instructions"])
        XCTAssertEqual(contexts[0].recallLabels, ["Alpha"])
        XCTAssertEqual(contexts[0].seq, 11)
        let rows = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        XCTAssertEqual(rows.count, 1)
        guard case .user(let user) = rows[0] else {
            return XCTFail("ordinary recall/instructions Context stays hidden")
        }
        XCTAssertEqual(user.referenceLabels, ["Alpha"])
        XCTAssertEqual(referenceSummaryText(labels: user.referenceLabels, english: true), "Referenced session · Alpha")

        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":20,"time":40,"data":{"message":{
          "id":"u-empty-recall",
          "content":[{"type":"text","text":"second mention"}],
          "source":{"kind":"user"}
        }}}}
        """)))
        XCTAssertTrue(reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":21,"time":41,"data":{"message":{
          "id":"recall-empty",
          "content":[],
          "source":{"kind":"session-reference","form":"recall","references":[
            {"sessionId":"s-b","label":"Gamma","retainedMessages":1,"omittedMessages":0,"truncated":false}
          ]}
        }}}}
        """)))
        let emptyRecall = reducer.items().compactMap { item -> Item.Context? in
            if case .context(let value) = item, value.seq == 21 { return value }
            return nil
        }
        XCTAssertEqual(emptyRecall.count, 1)
        XCTAssertEqual(emptyRecall[0].recallLabels, ["Gamma"])
        XCTAssertTrue(emptyRecall[0].text.isEmpty)
        let second = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        XCTAssertEqual(second.count, 2)
        guard case .user(let later) = second[1] else {
            return XCTFail("expected second user")
        }
        XCTAssertEqual(later.referenceLabels, ["Gamma"])
    }

    func testFirstPromptPendingItemMatchesReducerEchoIdentity() {
        let prompt = FirstPrompt(requestId: "rpc-first", text: "第一条消息", images: 1, files: 2)
        guard case .user(let synthetic) = firstPromptPendingItem(prompt) else {
            return XCTFail("expected pending user")
        }
        XCTAssertEqual(synthetic.key, "local-rpc-first")
        XCTAssertEqual(synthetic.text, "第一条消息")
        XCTAssertEqual(synthetic.images, 1)
        XCTAssertTrue(synthetic.pending)
        XCTAssertEqual(synthetic.requestId, "rpc-first")

        XCTAssertEqual(
            firstPromptVisibleItems(chatItems: [], prompt: prompt).map(\.key),
            ["local-rpc-first"]
        )
        let seeded = Item.user(Item.User(key: "local-rpc-first", text: "第一条消息", pending: true, requestId: "rpc-first"))
        XCTAssertEqual(
            firstPromptVisibleItems(chatItems: [seeded], prompt: prompt).map(\.key),
            ["local-rpc-first"]
        )
        XCTAssertTrue(firstPromptVisibleItems(chatItems: [], prompt: nil).isEmpty)
        XCTAssertTrue(firstPromptBlocksComposerActions(prompt))
        XCTAssertFalse(firstPromptBlocksComposerActions(nil))
        XCTAssertEqual(firstPromptSendingLabel(english: false), "发送中…")
        XCTAssertEqual(firstPromptSendingLabel(english: true), "Sending…")

        let reducer = TranscriptReducer()
        reducer.echo(text: prompt.text, requestId: prompt.requestId, images: prompt.images, files: prompt.files)
        let echoed = reducer.items()
        XCTAssertEqual(echoed.map(\.key), ["local-rpc-first"])
        guard case .user(let user) = echoed[0] else {
            return XCTFail("expected echo user")
        }
        XCTAssertEqual(user.key, synthetic.key)
        XCTAssertTrue(user.pending)
        XCTAssertEqual(user.requestId, prompt.requestId)
        reducer.echo(text: prompt.text, requestId: prompt.requestId)
        XCTAssertEqual(reducer.items().count, 1)
        let rows = foldChatItems(
            firstPromptVisibleItems(chatItems: [], prompt: prompt),
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        XCTAssertEqual(rows.map(\.key), ["local-rpc-first"])
        guard case .user(let visible) = rows[0] else {
            return XCTFail("pending first prompt must render as a user bubble")
        }
        XCTAssertTrue(visible.pending)
    }
}
