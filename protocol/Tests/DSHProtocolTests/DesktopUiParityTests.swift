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
}
