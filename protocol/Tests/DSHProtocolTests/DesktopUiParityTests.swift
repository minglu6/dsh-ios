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
    }
}
