import XCTest
@testable import DSHProtocol

final class DesktopUiParityTests: XCTestCase {
    func testMessageRowFollowsDesktopCopyLikeDislikeShare() {
        XCTAssertEqual(MessageActionPolicy.assistantRow, [.copy, .like, .dislike, .share])
        XCTAssertEqual(MessageActionPolicy.userRow, [.copy])
        XCTAssertFalse(MessageActionPolicy.includesBranch)
        XCTAssertTrue(MessageActionPolicy.assistantRow.contains(.share))
    }

    func testStartPanelMirrorsDesktopTwoColoredEntries() {
        XCTAssertEqual(
            StartPanelPolicy.entries(files: true, terminal: true),
            [.workspaceFiles, .newTerminal]
        )
        XCTAssertEqual(StartPanelPolicy.entries(files: true, terminal: false), [.workspaceFiles])
        XCTAssertEqual(StartPanelPolicy.entries(files: false, terminal: true), [.newTerminal])
        XCTAssertTrue(StartPanelPolicy.entries(files: false, terminal: false).isEmpty)
        XCTAssertFalse(StartPanelPolicy.includesBrowser)
        XCTAssertFalse(StartPanelPolicy.includesSessionInspector)
        XCTAssertEqual(StartPanelPolicy.desktopShortcut(.workspaceFiles), "⌘P")
        XCTAssertNil(StartPanelPolicy.desktopShortcut(.newTerminal))
        XCTAssertNil(StartPanelPolicy.shortcut(.workspaceFiles))
        XCTAssertNil(StartPanelPolicy.shortcut(.newTerminal))
        XCTAssertTrue(StartPanelPolicy.showsChevron(.newTerminal))
        XCTAssertFalse(StartPanelPolicy.showsChevron(.workspaceFiles))
    }

    func testComposerShowsConcreteModelNameNotSelectPrompt() {
        let catalog = ModelCatalog(
            groups: [
                ModelGroup(
                    id: "google",
                    name: "Google",
                    models: [
                        ModelInfo(
                            provider: "google",
                            id: "gemini-3-flash",
                            name: "Gemini 3 Flash",
                            description: nil,
                            efforts: [],
                            defaultEffort: nil,
                            hasReasoning: false
                        ),
                    ]
                ),
            ],
            defaultProvider: "google",
            defaultModel: "gemini-3-flash",
            failures: [],
            defaultEffort: nil
        )
        XCTAssertEqual(
            composerModelDisplayName(choiceName: "Gemini 3 Flash", catalog: catalog),
            "Gemini 3 Flash"
        )
        XCTAssertEqual(composerModelDisplayName(choiceName: "  ", catalog: catalog), "Gemini 3 Flash")
        XCTAssertEqual(composerModelDisplayName(choiceName: nil, catalog: catalog), "Gemini 3 Flash")
        XCTAssertNil(composerModelDisplayName(choiceName: nil, catalog: nil))
        XCTAssertNil(composerModelDisplayName(choiceName: "", catalog: ModelCatalog(
            groups: [], defaultProvider: nil, defaultModel: nil, failures: [], defaultEffort: nil
        )))
        XCTAssertEqual(
            composerModelDisplayName(
                choiceName: nil,
                catalog: ModelCatalog(
                    groups: [],
                    defaultProvider: nil,
                    defaultModel: "only-id",
                    failures: [],
                    defaultEffort: nil
                )
            ),
            "only-id"
        )
    }

    func testMixedLocaleCopyUsesVerificationAndSessionChinese() {
        XCTAssertEqual(pairingCodeFieldLabel(english: false), "验证码")
        XCTAssertEqual(pairingCodeFieldLabel(english: true), "Verification code")
        XCTAssertEqual(downloadSessionLogLabel(english: false), "下载会话日志")
        XCTAssertEqual(downloadSessionLogLabel(english: true), "Download session log")
        XCTAssertEqual(sessionLogUploadLabel(english: false), "在使用官方模型 API 时上传会话日志")
        XCTAssertEqual(modelsSettingsIntro(english: false), "填入各提供商的 API 密钥即可使用其模型。")
        XCTAssertEqual(
            modelsSettingsIntro(english: true),
            "Enter your API keys to use models from the following providers."
        )
        XCTAssertEqual(conversationFontSizeLabel(14), "14 px")
        XCTAssertEqual(ConversationFontSize.range, 10...22)
    }

    func testPermissionChipUsesWorkspaceWriteCopy() {
        XCTAssertEqual(permissionLabel(value: "workspace-write"), "工作区内修改")
    }

    func testDesktopDoesNotExposeBrowserOrInspectorOnStart() {
        XCTAssertFalse(StartPanelPolicy.includesBrowser)
        XCTAssertFalse(StartPanelPolicy.includesSessionInspector)
    }

    func testConversationHeaderHasNoOverflowMenu() {
        XCTAssertFalse(ConversationHeaderPolicy.includesOverflowMenu)
        XCTAssertFalse(conversationHeaderShowsModelChip)
        XCTAssertFalse(conversationHeaderShowsAgentPreset)
        XCTAssertFalse(conversationHeaderShowsTimestamp)
        XCTAssertFalse(settingsIncludesPhoneConnection)
        XCTAssertTrue(phoneConnectionLivesInDrawerFooter)
        XCTAssertTrue(sidebarFooterActionAboveSettings)
    }

    func testGeneralSettingsCopyMatchesDesktopLocale() {
        XCTAssertEqual(transcriptViewLabel(.compact, english: false), "简洁")
        XCTAssertEqual(transcriptViewLabel(.verbose, english: false), "完全展开")
        XCTAssertEqual(transcriptViewLabel(.compact, english: true), "Compact")
        XCTAssertEqual(transcriptViewLabel(.verbose, english: true), "Verbose")
        XCTAssertEqual(collapseTimingLabel(.completion, english: false), "回答结束后")
        XCTAssertEqual(collapseTimingLabel(.nextInput, english: false), "下次有新消息时")
        XCTAssertEqual(collapseTimingLabel(.completion, english: true), "On completion")
        XCTAssertEqual(collapseTimingLabel(.nextInput, english: true), "On next message")
        XCTAssertEqual(linkOpeningLabel("sidebar", english: false), "应用内侧边栏")
        XCTAssertEqual(linkOpeningLabel("sidebar", english: true), "In-App Sidebar")
        XCTAssertEqual(linkOpeningLabel("new-tab", english: false), "默认浏览器")
        XCTAssertEqual(linkOpeningLabel("new-tab", english: true), "Default Browser")
        XCTAssertEqual(linkOpeningValues, ["sidebar", "new-tab"])
        XCTAssertEqual(linkOpeningTitle(english: false), "网页链接默认打开方式")
        XCTAssertEqual(linkOpeningTitle(english: true), "Open chat links in")
        XCTAssertEqual(linkOpeningDescription(english: false), "对话中网页链接的打开位置")
        XCTAssertEqual(linkOpeningDescription(english: true), "Choose where to open web links")
        XCTAssertEqual(linkOpeningLabel("in-app", english: false), "in-app")
        XCTAssertEqual(linkOpeningLabel("system", english: true), "system")
        XCTAssertEqual(linkOpeningLabel("mystery", english: false), "mystery")
        XCTAssertEqual(workDetailsDescription(english: false), "选择希望看到多少工具调用细节")
        XCTAssertEqual(commandMenuIconSymbol("goal"), "target")
        XCTAssertEqual(commandMenuIconSymbol("plan"), "doc.text")
        XCTAssertEqual(commandMenuIconSymbol("compact"), "circle.circle")
        XCTAssertEqual(commandMenuIconSymbol("permission"), "shield")
        XCTAssertEqual(terminalTabTitle("zsh"), "zsh")
        XCTAssertEqual(terminalTabTitle("  "), "Terminal")
        XCTAssertEqual(terminalTabTitle(nil), "Terminal")
        XCTAssertEqual(CollapseTiming.nextInput.rawValue, "next-input")
        XCTAssertEqual(collapseTimingFromHost(nil), .completion)
        XCTAssertEqual(collapseTimingFromHost("next-input"), .nextInput)
        XCTAssertEqual(collapseTimingFromHost("nextInput"), .completion)
        XCTAssertEqual(composerPlaceholderText(planMode: false, english: false), "发消息或创建任务, / 调用指令, @ 文件或对话")
        XCTAssertEqual(composerPlaceholderText(planMode: true, english: false), "描述你的任务以生成计划")
        XCTAssertEqual(composerPlaceholderText(planMode: false, english: true), "Message or run a task, / commands, @ files or sessions")
        XCTAssertEqual(composerPlaceholderText(planMode: true, english: true), "describe your task to generate plan")
        XCTAssertEqual(
            composerPlaceholderText(planMode: false, english: false, hero: true),
            "描述你想要构建的内容, / 调用指令, @ 文件或对话"
        )
        XCTAssertEqual(
            composerPlaceholderText(planMode: false, english: true, hero: true),
            "Describe what you want to build, / commands, @ files or sessions"
        )
        XCTAssertEqual(landingHeadline(english: false), "探索未至之境")
        XCTAssertEqual(landingHeadline(english: true), "Into the Unknown")
        XCTAssertEqual(landingPreviewBadge(english: false), "预览版")
        XCTAssertEqual(landingPreviewBadge(english: true), "Preview")
        XCTAssertEqual(composerAddButtonPoints, 28)
        XCTAssertEqual(composerSendButtonPoints, 34)
        XCTAssertEqual(composerChipHeightPoints, 28)
        XCTAssertEqual(composerTextMinHeightPoints, 36)
        XCTAssertEqual(composerHeroTextMinHeightPoints, 52)
        XCTAssertEqual(composerCardPaddingTopPoints, 6)
        XCTAssertEqual(composerCardPaddingBottomPoints, 4)
        XCTAssertEqual(composerCardPaddingHorizontalPoints, 8)
        XCTAssertEqual(composerInnerSpacingPoints, 4)
        XCTAssertEqual(composerTextFittedHeight(contentHeight: 0, hero: false), composerTextMinHeightPoints)
        XCTAssertEqual(composerTextFittedHeight(contentHeight: 0, hero: true), composerHeroTextMinHeightPoints)
        XCTAssertEqual(composerTextFittedHeight(contentHeight: 20, hero: false), composerTextMinHeightPoints)
        XCTAssertEqual(composerTextFittedHeight(contentHeight: 80, hero: false), 80)
        XCTAssertEqual(composerTextFittedHeight(contentHeight: 200, hero: false), composerTextMaxHeightPoints)
        XCTAssertFalse(composerTextShouldScroll(fittedHeight: composerTextMinHeightPoints))
        XCTAssertTrue(composerTextShouldScroll(fittedHeight: composerTextMaxHeightPoints))
        let claimed = InboxClaimState(currentClaimed: ["m1"], claimSeq: 2, claimedHuman: false)
        XCTAssertTrue(isWakingTurnTrigger(sourceKind: "tool-jobs", messageId: "m1", nextTurn: claimed, nextStep: .empty, step: nil, turnStartSeq: nil))
        XCTAssertFalse(isWakingTurnTrigger(sourceKind: "skill-catalog", messageId: "m2", nextTurn: claimed, nextStep: .empty, step: nil, turnStartSeq: nil))
        XCTAssertFalse(isWakingTurnTrigger(sourceKind: "tool-jobs", messageId: "m3", nextTurn: claimed, nextStep: .empty, step: nil, turnStartSeq: nil))
        let steer = InboxClaimState(currentClaimed: ["steer"], claimSeq: 8, claimedHuman: false)
        XCTAssertTrue(isWakingTurnTrigger(sourceKind: "tool-jobs", messageId: "steer", nextTurn: .empty, nextStep: steer, step: 1, turnStartSeq: 5))
        XCTAssertFalse(isWakingTurnTrigger(sourceKind: "tool-jobs", messageId: "steer", nextTurn: .empty, nextStep: steer, step: 2, turnStartSeq: 5))
        XCTAssertFalse(isWakingTurnTrigger(sourceKind: "tool-jobs", messageId: "steer", nextTurn: .empty, nextStep: steer, step: 1, turnStartSeq: 9))
        XCTAssertFalse(isWakingTurnTrigger(
            sourceKind: "tool-jobs",
            messageId: "steer",
            nextTurn: .empty,
            nextStep: InboxClaimState(currentClaimed: ["steer"], claimSeq: 8, claimedHuman: true),
            step: 1,
            turnStartSeq: 5
        ))
        XCTAssertTrue(jobsPopoverArrowPointsDown)
        XCTAssertTrue(jobsPopoverSizesToContent)
        XCTAssertTrue(jobsPopoverKeepsRosterIdentity)
        XCTAssertLessThan(jobsPopoverMaxHeightPoints, 420)
        XCTAssertTrue(jobsPopoverSettledDetailWraps)
        XCTAssertEqual(jobsPopoverWidth(screenWidth: 320), 320)
        XCTAssertEqual(jobsPopoverWidth(screenWidth: 402), 378)
        XCTAssertEqual(jobsPopoverWidth(screenWidth: 800), 520)
        XCTAssertEqual(composerStatisticsTokenUnit, "tok")
        XCTAssertTrue(composerSessionUsageIsPopover)
        XCTAssertTrue(composerUsagePopoverOpensAbove)
        XCTAssertTrue(composerActivityPopoverOpensAbove)
        XCTAssertEqual(composerActivityPopoverOpensAbove, composerUsagePopoverOpensAbove)
        XCTAssertTrue(composerContextPopoverOpensAbove)
        XCTAssertEqual(composerContextPopoverOpensAbove, composerUsagePopoverOpensAbove)
        XCTAssertTrue(composerUsagePillUsesDatabaseIcon)
        XCTAssertTrue(composerContextUsesRingMeter)
        XCTAssertEqual(composerContextRingSizePoints, 14)
        XCTAssertEqual(composerContextRingRadiusPoints, 5.5)
        XCTAssertEqual(composerContextRingStrokePoints, 2)
        XCTAssertTrue(composerContextRingFillLineCapRound)
        XCTAssertEqual(composerActivityTitle(english: false), "会话统计")
        XCTAssertEqual(composerActivityTitle(english: true), "Session statistics")
        XCTAssertEqual(composerActivityLlmTime(english: false), "模型用时")
        XCTAssertEqual(composerActivityToolTime(english: false), "工具调用用时")
        XCTAssertEqual(composerActivityTtft(english: false), "首 token 平均（TTFT）")
        XCTAssertEqual(composerActivitySpeed(english: false), "输出速度（TPS）")
        XCTAssertEqual(composerActivityCounts(turns: 3, steps: 12, english: false), "3 轮 12 步")
        XCTAssertEqual(composerActivityCounts(turns: 3, steps: 12, english: true), "3 turns 12 steps")
        XCTAssertEqual(composerContextUsed(english: false), "上下文已用")
        XCTAssertEqual(composerContextAria(percent: "45%", english: false), "上下文已用 45%")
        XCTAssertEqual(composerContextAria(percent: "45%", english: true), "45% of context used")
        XCTAssertEqual(composerContextHeadline(english: false), ComposerContextHeadline(before: "上下文已用", after: ""))
        XCTAssertEqual(composerContextHeadline(english: true), ComposerContextHeadline(before: "", after: "of context used"))
        XCTAssertEqual(composerContextSystem(english: false), "系统提示词")
        XCTAssertEqual(composerContextTools(english: false), "工具定义")
        XCTAssertEqual(composerContextMessages(english: false), "对话消息")
        XCTAssertEqual(composerContextTools(english: true), "Tool definitions")
        XCTAssertEqual(composerContextMessages(english: true), "Messages")
        XCTAssertEqual(composerContextBreakdownLabel(.tools, english: false), "工具定义")
        XCTAssertTrue(composerUsagePopoverHeaderSplitsTotal)
        XCTAssertTrue(composerSessionUsageOmitsTotalRow)
        XCTAssertTrue(composerTurnUsageOmitsTotalRow)
        XCTAssertEqual(composerSessionUsageTitle(english: false), "Token 用量")
        XCTAssertEqual(composerSessionUsageTitle(english: true), "Token usage")
        XCTAssertEqual(composerSessionUsageTitleValue(exactTotal: "34,185"), "34,185 tok")
        XCTAssertEqual(composerTurnUsageTitle(english: false), "本轮用量")
        XCTAssertEqual(composerTurnUsageTitle(english: true), "Turn usage")
        XCTAssertEqual(composerTurnUsageConsumed(total: "1.2K tok", english: false), "用量 1.2K tok")
        XCTAssertEqual(composerTurnUsageConsumed(total: "1.2K tok", english: true), "Usage 1.2K tok")
        XCTAssertEqual(composerTurnUsageModelLabel(english: false), "提供方 / 模型")
        XCTAssertEqual(composerTurnUsageModelLabel(english: true), "Provider / model")
        XCTAssertEqual(composerTurnUsageReasoning(tokens: "128 tok", english: false), "（其中推理 128 tok）")
        XCTAssertEqual(composerTurnUsageReasoning(tokens: "128 tok", english: true), " (128 tok reasoning)")
        XCTAssertEqual(composerSessionUsageRowLabel(.cacheHit, english: false), "缓存命中")
        XCTAssertEqual(composerSessionUsageRowLabel(.cacheHit, english: true), "Cache hit")
        XCTAssertEqual(composerSessionUsageRowLabel(.uncachedInput, english: false), "未缓存输入")
        XCTAssertEqual(composerSessionUsageRowLabel(.cacheRead, english: false), "缓存读取")
        XCTAssertEqual(composerSessionUsageRowLabel(.cacheRead, english: true), "Cached input")
        XCTAssertEqual(composerSessionUsageRowLabel(.cacheWrite, english: false), "缓存写入")
        XCTAssertEqual(composerSessionUsageRowLabel(.output, english: false), "输出")
        XCTAssertEqual(composerSessionUsageTokenValue(exact: "12,345"), "12,345 tok")
        XCTAssertTrue(permissionRiskDismissesKeyboard)
        XCTAssertNil(wakingTriggerStep(openStep: nil, openTurn: 1))
        XCTAssertEqual(wakingTriggerStep(openStep: 1, openTurn: 1), 1)
        XCTAssertTrue(permissionRiskIsCenteredDialog)
        XCTAssertTrue(permissionRiskStaysAboveKeyboard)
        XCTAssertTrue(chatPreservesPositionAcrossBrowser)
        XCTAssertFalse(landingPermissionPersistsAcrossLaunch)
        XCTAssertEqual(
            permissionFullAccessRiskDescription(audience: .currentSession, english: false),
            "启用完全权限后，智能体将减少确认步骤，并且可以直接执行更多操作，包括敏感操作、文件修改或外部命令。仅建议在你信任当前任务时使用。"
        )
        XCTAssertEqual(
            permissionFullAccessRiskDescription(audience: .newSessionDefault, english: false),
            "启用完全权限后，新会话将减少确认步骤，并且可以直接执行更多操作，包括敏感操作、文件修改或外部命令。仅建议在你信任后续任务时使用。"
        )
        let first = applyInboxClaim(
            previous: .empty,
            removed: [InboxClaimIdentity(id: "m1", sourceKind: "tool-jobs")],
            insertedIds: [],
            outcome: nil,
            seq: 2
        )
        let replaced = applyInboxClaim(
            previous: first,
            removed: [InboxClaimIdentity(id: "m2", sourceKind: "tool-jobs")],
            insertedIds: [],
            outcome: nil,
            seq: 4
        )
        XCTAssertEqual(replaced.currentClaimed, ["m2"])
        XCTAssertFalse(replaced.currentClaimed.contains("m1"))
        let canceled = applyInboxClaim(
            previous: first,
            removed: [InboxClaimIdentity(id: "m9", sourceKind: "tool-jobs")],
            insertedIds: [],
            outcome: "canceled",
            seq: 3
        )
        XCTAssertEqual(canceled.currentClaimed, ["m1"])
        XCTAssertEqual(turnTriggerTitle(sourceKind: "tool-jobs", provider: nil, english: false), "后台任务状态更新")
        XCTAssertEqual(turnTriggerTitle(sourceKind: "tool-jobs", provider: nil, english: true), "Background task updated")
        XCTAssertEqual(turnTriggerExplanation(english: false), "这条通知触发了本轮回复。")
        XCTAssertEqual(turnTriggerIcon(sourceKind: "tool-jobs", provider: nil), .job)
        XCTAssertTrue(isTurnTriggerKind("tool-jobs"))
        XCTAssertFalse(isTurnTriggerKind("runtime-context"))
        XCTAssertEqual(commandMenuAvailableHeight(containerHeight: 180), 172)
        XCTAssertEqual(commandMenuAvailableHeight(containerHeight: 80), 72)
        XCTAssertEqual(commandMenuAvailableHeight(containerHeight: 4), 0)
        XCTAssertEqual(composerModelFallback(english: false), "请选择模型")
        XCTAssertEqual(composerModelFallback(english: true), "Select model")
        XCTAssertEqual(loadOlderLabel(loading: false, english: false), "加载更早")
        XCTAssertEqual(loadOlderLabel(loading: true, english: false), "加载中…")
        XCTAssertEqual(loadOlderLabel(loading: false, english: true), "Load earlier")
        XCTAssertEqual(deepDivingLabel(startedAtMs: nil, nowMs: 0, english: false), "深度求索中")
        XCTAssertEqual(deepDivingLabel(startedAtMs: 0, nowMs: 5_000, english: false), "深度求索中，用时 5秒 ···")
        XCTAssertEqual(deepDivingLabel(startedAtMs: 0, nowMs: 65_000, english: true), "Deep diving for 1m 5s ···")
        XCTAssertEqual(jobOutputGap(english: false), "……较早的输出已丢弃……")
        XCTAssertEqual(jobOutputGap(english: true), "… earlier output dropped …")
        XCTAssertEqual(askReopenLabel(english: false), "回答")
        XCTAssertEqual(askPendingDetail(english: false), "等待中的问题仍可在输入框中回答")
        XCTAssertEqual(askRowTitle(english: false), "提问")
        XCTAssertEqual(planChipTitle(english: false), "计划模式已开启 — 点击关闭（/plan off）")
        XCTAssertEqual(planChipLabel(english: false), "计划")
        XCTAssertEqual(planChipAria(english: false), "计划模式已开启，按下关闭")
        XCTAssertTrue(planChipLivesInComposerModesRow)
        XCTAssertTrue(sidebarFooterActionAboveSettings)
        XCTAssertEqual(composerCommandsAria(english: false), "添加文件或调用指令")
        XCTAssertEqual(addWorkspaceMenuLabel(english: false), "添加工作区…")
        XCTAssertEqual(pendingAttachmentsLabel(english: false), "待发送附件")
        XCTAssertEqual(pluginsEmptyLabel(english: false), "还没有安装任何插件。")
        XCTAssertEqual(pluginsEmptyLabel(english: true), "No plugins are installed yet.")
        XCTAssertEqual(messageFeedbackHint(english: false), "填写详情以帮助我们改进体验，提交内容会包括当前对话的日志")
        XCTAssertEqual(slashCommandName("/plan off"), "plan")
        XCTAssertNil(slashCommandName("hello"))
        XCTAssertTrue(commandRefusesAttachments(name: "plan", catalogRow: nil))
        XCTAssertFalse(commandRefusesAttachments(name: "file", catalogRow: nil))
        XCTAssertFalse(commandRefusesAttachments(
            name: "theme",
            catalogRow: jsonObject(["name": .string("theme"), "input": .object(["attachments": .bool(true)])])
        ))
        XCTAssertEqual(
            commandAttachmentsUnsupportedNotice(command: "goal", english: false),
            "/goal 不接受附件，请先移除附件"
        )
        XCTAssertEqual(autoRefreshLabel(english: false), "自动刷新")
        XCTAssertEqual(autoRefreshLabel(english: true), "Auto refresh")
        XCTAssertEqual(autoRefreshEnableLabel(english: false), "开启自动刷新")
        XCTAssertEqual(autoRefreshDisableLabel(english: false), "关闭自动刷新")
        XCTAssertEqual(queueImageLabel(english: false), "排队消息图片")
        XCTAssertEqual(queueFileLabel(name: "notes.md", english: false), "排队文件 notes.md")
        XCTAssertEqual(fileSizeText(512), "512 B")
        XCTAssertEqual(fileSizeText(1536), "1.5 KB")
        XCTAssertEqual(fileSizeText(1024), "1 KB")
        XCTAssertEqual(claimedComposerHint(text: "/goal", hasGoal: false, english: false), "输入目标，智能体将持续执行")
        XCTAssertEqual(claimedComposerHint(text: "/goal ", hasGoal: false, english: false), "输入目标，智能体将持续执行")
        XCTAssertEqual(
            claimedComposerHint(text: "/goal", hasGoal: true, english: false),
            "当前目标进行中。可输入 edit 修改 / pause 暂停 / resume 继续 / clear 清除"
        )
        XCTAssertEqual(claimedComposerHint(text: "/plan ", hasGoal: false, english: false), "描述你的任务以生成计划")
        XCTAssertNil(claimedComposerHint(text: "/goal 发布", hasGoal: false, english: false))
        XCTAssertNil(claimedComposerHint(text: "hello", hasGoal: false, english: false))
        XCTAssertEqual(
            claimedComposerHint(
                text: "/目标 ",
                catalog: [jsonObject([
                    "name": .string("目标"),
                    "definitionId": .string("@deepseek-ai/dsh-command-goal"),
                ])],
                hasGoal: false,
                english: false
            ),
            "输入目标，智能体将持续执行"
        )
        XCTAssertEqual(fileTreeFolderSymbol(expanded: false), "folder")
        XCTAssertEqual(fileTreeFolderSymbol(expanded: true), "folder.fill")
        XCTAssertFalse(autoRefreshLabel(english: false).contains("Host"))
        XCTAssertFalse(claimedComposerHint(text: "/goal", hasGoal: false, english: false)!.contains("Host"))
    }

    func testConversationHeaderTitleMatchesDrawerUntitledRules() {
        XCTAssertEqual(
            conversationHeaderTitle(sessionId: nil, title: nil, blank: false, newSession: "新会话", untitled: "未命名"),
            "新会话"
        )
        XCTAssertEqual(
            conversationHeaderTitle(sessionId: "b", title: nil, blank: true, newSession: "新会话", untitled: "未命名"),
            "新会话"
        )
        XCTAssertEqual(
            conversationHeaderTitle(sessionId: "u", title: nil, blank: false, newSession: "新会话", untitled: "未命名"),
            "未命名"
        )
        XCTAssertEqual(
            conversationHeaderTitle(sessionId: "n", title: "修 bug", blank: false, newSession: "新会话", untitled: "未命名"),
            "修 bug"
        )
        XCTAssertEqual(
            conversationHeaderTitle(
                sessionId: "b",
                title: "创建parity-r6-card.txt文件",
                blank: true,
                newSession: "新会话",
                untitled: "未命名"
            ),
            "创建parity-r6-card.txt文件"
        )
        XCTAssertEqual(sessionTitleRefreshDelayNanoseconds, 4_000_000_000)
        XCTAssertEqual(
            composerPlaceholderText(kind: .steerQueue, english: false),
            "Cmd/Ctrl+Enter 插话发送全部排队消息"
        )
        XCTAssertEqual(
            composerPlaceholderText(kind: .parentOffline, english: false),
            "父会话已离线，无法继续发送；仍可停止当前运行"
        )
        XCTAssertEqual(composerPlaceholderText(kind: .unavailable, english: false), "会话不可用")
        XCTAssertEqual(
            composerPlaceholderKind(
                parentOffline: false,
                unavailable: false,
                canSteerQueue: true,
                planMode: true,
                needsWorkspace: false,
                hero: true
            ),
            .steerQueue
        )
        XCTAssertEqual(
            composerPlaceholderKind(
                parentOffline: false,
                unavailable: false,
                canSteerQueue: false,
                planMode: false,
                needsWorkspace: true,
                hero: true
            ),
            .workspace
        )
        XCTAssertEqual(composerPlaceholderText(kind: .workspace, english: false), "选择一个工作区开始")
        XCTAssertEqual(composerPlaceholderText(kind: .workspace, english: true), "Choose a workspace to start")
        XCTAssertEqual(landingWorkspaceRequired(english: false), "请先选择工作区")
        XCTAssertEqual(composerStopLabel(english: false), "停止生成")
        XCTAssertEqual(composerStopLabel(english: true), "Stop generating")
        XCTAssertTrue(landingComposerNeedsWorkspace(selectedWorkspaceId: nil, workspaceCount: 0))
        XCTAssertFalse(landingComposerNeedsWorkspace(selectedWorkspaceId: nil, workspaceCount: 1))
        XCTAssertFalse(landingComposerNeedsWorkspace(selectedWorkspaceId: "w1", workspaceCount: 0))
        XCTAssertEqual(resolveSubmitMode(preferred: "queue", running: true, gesture: .chord, steeringAvailable: true), "steer")
        XCTAssertEqual(resolveSubmitMode(preferred: "steer", running: true, gesture: .chord, steeringAvailable: true), "queue")
        XCTAssertEqual(resolveSubmitMode(preferred: "steer", running: false, gesture: .chord, steeringAvailable: true), "queue")
        XCTAssertEqual(landingChooseWorkspace(english: false), "选择工作区")
        XCTAssertEqual(pluginInfoLabel(english: false), "插件说明")
        XCTAssertEqual(
            pluginInfoDescription(english: false),
            "在这里配置官方插件，安装和管理其他插件。内置插件列表及运行状态可在「设置 → 内置插件」中查看"
        )
        XCTAssertEqual(commandMenuDescriptionLineLimit, 2)
        XCTAssertTrue(runningWhaleRestPath.hasPrefix("M8.844"))
        XCTAssertTrue(composerParentOffline(origin: "subagent", parentSessionId: "p", parentListed: false, parentOffline: false))
        XCTAssertFalse(composerParentOffline(origin: "user", parentSessionId: "p", parentListed: false, parentOffline: true))
        XCTAssertEqual(chatLinkDestination(nil), .sidebar)
        XCTAssertEqual(chatLinkDestination("new-tab"), .newTab)
        XCTAssertTrue(isChatWebLink(URL(string: "https://example.com")!))
        XCTAssertFalse(isChatWebLink(URL(string: "dshfile://open")!))
        XCTAssertEqual(skillCatalogScopeKey(sessionId: nil, subagent: false), "landing")
        XCTAssertEqual(skillCatalogScopeKey(sessionId: "s1", subagent: true), "subagent:s1")
        XCTAssertEqual(listCatalogArgs(sessionId: nil), jsonObject([:]))
        XCTAssertEqual(listCatalogArgs(sessionId: "s1")["sessionId"].str(), "s1")
    }

    /// Round 5 real device: `workspace/changes` seq 29, turn 1 closed, codeWork on,
    /// lastAnswerKeys `[1:"t27.0"]` — fetch must be requested before any summary exists.
    func testChangesCardFetchDoesNotDependOnSummary() {
        XCTAssertTrue(changesCardShouldFetch(seq: 10, hasSummaryOp: true))
        XCTAssertFalse(changesCardShouldFetch(seq: nil, hasSummaryOp: true))
        XCTAssertFalse(changesCardShouldFetch(seq: 29, hasSummaryOp: false))
        XCTAssertTrue(changesCardMountsFetch(seq: 29, turnClosed: true, codeWork: true, hasSummaryOp: true))
        XCTAssertFalse(changesCardMountsFetch(seq: 29, turnClosed: false, codeWork: true, hasSummaryOp: true))
        XCTAssertFalse(changesCardMountsFetch(seq: 29, turnClosed: true, codeWork: false, hasSummaryOp: true))
        XCTAssertEqual(
            changesCardFetchIdentity(hostId: "h", sessionId: "s", seq: 29, hasSummaryOp: true),
            "h-s-29-true"
        )
        XCTAssertEqual(
            changesCardFetchIdentity(hostId: "h", sessionId: "s", seq: 29, hasSummaryOp: true),
            changesCardFetchIdentity(hostId: "h", sessionId: "s", seq: 29, hasSummaryOp: true)
        )
        XCTAssertGreaterThan(changesCardFetchAnchorPoints, 0)
        XCTAssertEqual(changesCardFetchAnchorPoints, 1)
    }

    func testTurnTriggerContextIsVisibleInFoldedChat() {
        let trigger = Item.Context(
            key: "x29",
            text: "bash-1 completed",
            sourceKind: "tool-jobs",
            at: 1_700_000_000_000,
            messageId: "m-wake",
            waking: true
        )
        let rows = foldChatItems(
            [.context(trigger), .text(Item.Text(key: "a1", text: "done", live: false, turn: 2))],
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        XCTAssertTrue(rows.contains { if case .turnTrigger(let item) = $0 { return item.sourceKind == "tool-jobs" }; return false })
        XCTAssertFalse(
            foldChatItems(
                [.context(Item.Context(key: "hidden", text: "cwd=/tmp", sourceKind: "runtime-context"))],
                policy: presentationPolicyFor(.detailed),
                sessionRunning: false
            ).contains { if case .turnTrigger = $0 { return true }; return false }
        )
        XCTAssertFalse(
            foldChatItems(
                [.context(Item.Context(key: "inj", text: "skills", sourceKind: "skill-catalog", messageId: "m-sk", waking: false))],
                policy: presentationPolicyFor(.detailed),
                sessionRunning: false
            ).contains { if case .turnTrigger = $0 { return true }; return false }
        )
    }

    func testTitleProjectionUpdatesReducerTitle() throws {
        let reducer = TranscriptReducer()
        XCTAssertTrue(reducer.apply(try JSONValue.parse(
            #"{"type":"projection","key":"title","seq":12,"value":"创建parity-r6-card.txt文件"}"#
        )))
        XCTAssertEqual(reducer.title, "创建parity-r6-card.txt文件")
        XCTAssertFalse(reducer.apply(try JSONValue.parse(
            #"{"type":"projection","key":"title","seq":11,"value":"stale"}"#
        )))
        XCTAssertEqual(reducer.title, "创建parity-r6-card.txt文件")
    }

    func testToolJobsUserMessageFoldsToTurnTrigger() throws {
        let reducer = TranscriptReducer()
        func ev(_ json: String) throws -> Bool { reducer.apply(try JSONValue.parse(json)) }
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":1,"time":1,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":0,"inserted":[{"id":"m-wake","content":[{"type":"text","text":"bash-1 completed"}],"source":{"kind":"tool-jobs"}}]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":2,"time":2,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":1,"inserted":[]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":3,"time":3,"type":"user/message","data":{"message":{"id":"m-wake","content":[{"type":"text","text":"bash-1 completed"}],"source":{"kind":"tool-jobs"}}}}}
        """))
        let rows = foldChatItems(
            reducer.items(),
            policy: presentationPolicyFor(.detailed),
            sessionRunning: false
        )
        XCTAssertEqual(rows.filter { if case .turnTrigger = $0 { return true }; return false }.count, 1)
        XCTAssertTrue(rows.contains { if case .turnTrigger(let item) = $0 { return item.sourceKind == "tool-jobs" && item.text == "bash-1 completed" }; return false })
    }

    func testInjectedSkillAndTimeContextStayHiddenAndOnlyWakingJobShows() throws {
        let reducer = TranscriptReducer()
        func ev(_ json: String) throws -> Bool { reducer.apply(try JSONValue.parse(json)) }
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":10,"time":10,"type":"user/message","data":{"message":{"id":"u1","content":[{"type":"text","text":"run two sleeps"}],"source":{"kind":"user"}}}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":11,"time":11,"type":"user/message","data":{"message":{"id":"m-skills","content":[{"type":"text","text":"Available skills: agent-browser"}],"source":{"kind":"skill-catalog"}}}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":12,"time":12,"type":"user/message","data":{"message":{"id":"m-time","content":[{"type":"text","text":"Current time: 2026-10-16"}],"source":{"kind":"time-context"}}}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":20,"time":20,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":0,"inserted":[{"id":"m-wake","content":[{"type":"text","text":"bash-1 completed"}],"source":{"kind":"tool-jobs"}}]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":21,"time":21,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":1,"inserted":[]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":22,"time":22,"type":"user/message","data":{"message":{"id":"m-wake","content":[{"type":"text","text":"bash-1 completed"}],"source":{"kind":"tool-jobs"}}}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":23,"time":23,"type":"user/message","data":{"message":{"id":"m-extra","content":[{"type":"text","text":"bash-2 completed"}],"source":{"kind":"tool-jobs"}}}}}
        """))
        let items = reducer.items()
        XCTAssertEqual(items.filter { if case .context(let c) = $0 { return c.waking } else { return false } }.count, 1)
        let rows = foldChatItems(items, policy: presentationPolicyFor(.detailed), sessionRunning: false)
        let triggers = rows.compactMap { row -> Item.Context? in
            if case .turnTrigger(let item) = row { return item }
            return nil
        }
        XCTAssertEqual(triggers.map(\.sourceKind), ["tool-jobs"])
        XCTAssertEqual(triggers.map(\.text), ["bash-1 completed"])
        XCTAssertFalse(rows.contains { if case .turnTrigger(let item) = $0 { return item.sourceKind == "skill-catalog" || item.sourceKind == "time-context" }; return false })
        XCTAssertFalse(rows.contains { if case .turnTrigger(let item) = $0 { return item.messageId == "m-extra" }; return false })
    }

    func testCanceledNextTurnSpliceDoesNotWakeAndNextStepInjectStaysHidden() throws {
        let reducer = TranscriptReducer()
        func ev(_ json: String) throws -> Bool { reducer.apply(try JSONValue.parse(json)) }
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":1,"time":1,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":0,"inserted":[{"id":"m-cancel","content":[{"type":"text","text":"canceled job"}],"source":{"kind":"tool-jobs"}}]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":2,"time":2,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":1,"inserted":[],"outcome":"canceled"}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":3,"time":3,"type":"user/message","data":{"message":{"id":"m-cancel","content":[{"type":"text","text":"canceled job"}],"source":{"kind":"tool-jobs"}}}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":4,"time":4,"type":"agent/inbox/spliced","data":{"target":"next-step","start":0,"removedCount":0,"inserted":[{"id":"m-skills","content":[{"type":"text","text":"Available skills"}],"source":{"kind":"skill-catalog"}}]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":5,"time":5,"type":"user/message","data":{"message":{"id":"m-skills","content":[{"type":"text","text":"Available skills"}],"source":{"kind":"skill-catalog"}}}}}
        """))
        let rows = foldChatItems(reducer.items(), policy: presentationPolicyFor(.detailed), sessionRunning: false)
        XCTAssertFalse(rows.contains { if case .turnTrigger = $0 { return true }; return false })
    }

    func testNextTurnClaimReplacesPreviousClaimAndRpcIdIsNotAnId() throws {
        let reducer = TranscriptReducer()
        func ev(_ json: String) throws -> Bool { reducer.apply(try JSONValue.parse(json)) }
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":1,"time":1,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":0,"inserted":[{"id":"m1","content":[{"type":"text","text":"first"}],"source":{"kind":"tool-jobs"}},{"id":"m2","content":[{"type":"text","text":"second"}],"source":{"kind":"tool-jobs"}}]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":2,"time":2,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":1,"inserted":[]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":3,"time":3,"type":"agent/inbox/spliced","data":{"target":"next-turn","start":0,"removedCount":1,"inserted":[]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":4,"time":4,"type":"user/message","data":{"message":{"id":"m1","content":[{"type":"text","text":"first"}],"source":{"kind":"tool-jobs"}}}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":5,"time":5,"type":"user/message","data":{"message":{"id":"m2","content":[{"type":"text","text":"second"}],"source":{"kind":"tool-jobs"}}}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":6,"time":6,"type":"user/message","data":{"message":{"content":[{"type":"text","text":"rpc only"}],"source":{"kind":"tool-jobs","rpcId":"m2"}}}}}
        """))
        let waking = reducer.items().compactMap { item -> Item.Context? in
            if case .context(let c) = item, c.waking { return c }
            return nil
        }
        XCTAssertEqual(waking.map(\.messageId), ["m2"])
        XCTAssertEqual(waking.map(\.text), ["second"])
    }

    func testIdleSteerWakesOnlyOnStepOneAfterTurnStart() throws {
        let reducer = TranscriptReducer()
        func ev(_ json: String) throws -> Bool { reducer.apply(try JSONValue.parse(json)) }
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":1,"time":1,"type":"agent/inbox/spliced","data":{"target":"next-step","start":0,"removedCount":0,"inserted":[{"id":"steer","content":[{"type":"text","text":"steer idle"}],"source":{"kind":"tool-jobs"}}]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":2,"time":2,"type":"turn/start","data":{"turn":1}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":3,"time":3,"type":"agent/inbox/spliced","data":{"target":"next-step","start":0,"removedCount":1,"inserted":[]}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":4,"time":4,"type":"step/start","data":{"turn":1,"step":1}}}
        """))
        XCTAssertTrue(try ev("""
        {"type":"event","event":{"seq":5,"time":5,"type":"user/message","data":{"message":{"id":"steer","content":[{"type":"text","text":"steer idle"}],"source":{"kind":"tool-jobs"}}}}}
        """))
        XCTAssertEqual(
            reducer.items().compactMap { item -> String? in
                if case .context(let c) = item, c.waking { return c.messageId }
                return nil
            },
            ["steer"]
        )
    }
}
