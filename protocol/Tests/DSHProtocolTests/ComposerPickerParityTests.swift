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
            .unchanged
        )
        XCTAssertEqual(
            changesDiffNoticeKind(WorkspaceFileDiff(
                kind: "text",
                path: "a",
                display: "a",
                hunks: [WorkspaceDiffHunk(oldStart: 1, newStart: 1, lines: ["-old", "+new"])],
                coarse: true
            )),
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
}
