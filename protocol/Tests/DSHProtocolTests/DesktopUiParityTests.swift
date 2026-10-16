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
        XCTAssertEqual(linkOpeningDescription(english: false), "对话中网页链接的打开位置")
        XCTAssertEqual(linkOpeningDescription(english: true), "Where web links in the conversation open")
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
