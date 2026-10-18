import Foundation
import UIKit
import DSHProtocol

enum UITestLaunch {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestFixture")
    }

    static var appearance: Appearance {
        if ProcessInfo.processInfo.arguments.contains("-UITestAppearanceDark") { return .dark }
        if ProcessInfo.processInfo.arguments.contains("-UITestAppearanceLight") { return .light }
        return .light
    }

    static var screen: String {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-UITestScreen"), index + 1 < args.count else {
            return "landing"
        }
        return args[index + 1]
    }
}

extension AppModel {
    func installUITestFixture() {
        uiTestFixture = true
        language = .zh
        AppPrefs.language = .zh
        TrajL.en = false
        appearance = UITestLaunch.appearance
        AppPrefs.appearance = appearance
        ThemeStateHolder.shared.resolve(
            appearance: appearance,
            systemDark: UITestLaunch.appearance == .dark
        )

        let profile = Profile(
            id: "fixture-host",
            name: "Mac mini",
            deviceId: "fixture",
            host: "127.0.0.1",
            port: 8787,
            instanceId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            lastUsedAt: 1
        )
        profiles = [profile]
        activeId = profile.id
        status[profile.id] = .online
        ops = [
            "plugins.list", "schedule.catalog", "files.list",
            "terminal.create", "terminal.follow", "terminal.list",
            "workspace.pinSession", "workspace.archiveSession", "workspace.unarchiveSession",
            "sessions.rename", "sessions.fork", "sessions.create",
            "session.export", "models.catalog", "permissions.catalog",
            "workspace.create",
        ]

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let chatId = "s-hello"
        sessions = [
            SessionSummary(sessionId: chatId, title: "你好", running: false, blank: false, updatedAt: now - 5 * 60_000),
            SessionSummary(sessionId: "s-blank", title: nil, running: false, blank: true, updatedAt: now),
            SessionSummary(sessionId: "s-old", title: "读 README", running: false, blank: false, updatedAt: now - 43 * 60_000),
        ]
        workspaces = [
            WorkspaceView(workspaceId: "ws-ios", path: "/Users/dev/dsh-ios", title: "dsh-ios", sessionIds: [chatId, "s-blank"]),
            WorkspaceView(workspaceId: "ws-android", path: "/Users/dev/dsh-android", title: "dsh-android", sessionIds: ["s-old"]),
        ]
        catalog = ModelCatalog.parse(.object([
            "default": .object([
                "provider": .string("deepseek"),
                "model": .string("deepseek-v4-pro"),
                "reasoningEffort": .string("high"),
            ]),
            "groups": .array([
                .object([
                    "id": .string("deepseek"),
                    "name": .string("DeepSeek"),
                    "models": .array([
                        .object([
                            "id": .string("deepseek-v4-pro"),
                            "name": .string("DeepSeek V4 Pro"),
                            "reasoning": .object([
                                "defaultEffort": .string("high"),
                                "efforts": .array([
                                    .object(["id": .string("high"), "name": .string("高")]),
                                    .object(["id": .string("max"), "name": .string("最高")]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ]))
        modelChoice = ModelChoice(provider: "deepseek", model: "deepseek-v4-pro", name: "DeepSeek V4 Pro", effort: "high")
        draftModel = modelChoice
        do {
            permissionCatalog = try PermissionCatalog.parse(.object([
                "options": .array([
                    .object(["value": .string("workspace-write"), "name": .string("工作区内修改")]),
                    .object(["value": .string("read-only"), "name": .string("只读")]),
                ]),
                "defaultOptions": .array([
                    .object(["value": .string("workspace-write"), "name": .string("工作区内修改")]),
                    .object(["value": .string("read-only"), "name": .string("只读")]),
                ]),
                "defaultPreset": .string("workspace-write"),
            ]))
        } catch {
            fatalError("UITest fixture permission catalog is invalid: \(error)")
        }
        sessionPermission = "workspace-write"
        sessionGroupBy = .workspace
        archivedFilter = .hide
        collapsedWorkspaces = []
        pinnedIds = []
        archivedIds = []

        let clock = now - 5 * 60_000
        chat = ChatState(
            sessionId: chatId,
            items: [
                .user(Item.User(key: "u1", text: "你好", at: clock, messageId: "m-user")),
                .text(Item.Text(key: "a1", text: "你好，我是 DeepSeek。", live: false, at: clock + 2_000, messageId: "m-assistant")),
            ],
            title: "你好",
            loaded: true
        )

        showDrawer = false
        routeStack = []
        applyUITestScreen(UITestLaunch.screen)
    }

    fileprivate func applyUITestScreen(_ screen: String) {
        switch screen {
        case "landing":
            chat = nil
            firstPrompt = nil
        case "drawer", "viewOptions", "sessionActions":
            showDrawer = true
        case "chat", "trajectory":
            seedUITestJobs()
        case "models", "permission":
            break
        case "settings", "general":
            showDrawer = false
            push(.general)
        case "schedule":
            showDrawer = false
            push(.panel(.schedule))
        case "terminal":
            showDrawer = false
            push(.panel(.terminal))
        case "files":
            showDrawer = false
            push(.panel(.files))
        case "browser":
            showDrawer = false
            push(.panel(.browser))
        case "inspector":
            showDrawer = false
        case "start":
            break
        default:
            fatalError("UITestLaunch: unknown screen \(screen)")
        }
    }

    /// Desktop `JobListAction` only paints the header trigger when the
    /// session can see at least one job. Seed a live bash row so chat /
    /// trajectory screenshots lock the official chevron (not SF `clock`).
    fileprivate func seedUITestJobs() {
        ops.insert("jobs.list")
        jobs = [
            JobRow(
                id: "bash-1",
                status: "running",
                title: "sleep 600",
                kind: "bash",
                startedAt: Int64(Date().timeIntervalSince1970 * 1000) - 12_000
            )
        ]
    }
}
