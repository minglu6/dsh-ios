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

    /// Extra chat rows so the transcript can scroll in keyboard XCUITests
    /// without changing screenshot fixtures.
    static var extraChatForKeyboard: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestKeyboard")
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
            "workspace.create", "feedback.set", "commands.list",
        ]
        commandEntries = [
            .object([
                "name": .string("permission"),
                "definitionId": .string("@deepseek-ai/dsh-permission-presets"),
            ]),
        ]
        hostSettings.installUITestFixture()
        feedback["m-assistant"] = MessageFeedback(
            messageId: "m-assistant",
            rating: "positive",
            version: "1"
        )

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
                "provider": .string("deepseek-official"),
                "model": .string("deepseek-v4-pro"),
                "reasoningEffort": .string("high"),
            ]),
            "groups": .array([
                .object([
                    "id": .string("deepseek-official"),
                    "name": .string("DeepSeek"),
                    "models": .array([
                        .object([
                            "id": .string("deepseek-flash"),
                            "name": .string("DeepSeek-V4.1-Flash"),
                        ]),
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
        modelChoice = ModelChoice(provider: "deepseek-official", model: "deepseek-v4-pro", name: "DeepSeek V4 Pro", effort: "high")
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
        var items: [Item] = [
            .user(Item.User(key: "u1", text: "你好", at: clock, messageId: "m-user")),
            .context(Item.Context(key: "c1", text: "上下文注入：工具定义已更新", at: clock + 1_000)),
            .tool(Item.Tool(
                key: "t-read",
                callId: "c-read",
                name: "read",
                arguments: #"{"path":"README.md"}"#,
                status: .ok,
                result: "ok",
                startedAt: clock + 1_500,
                endedAt: clock + 1_800,
                turn: 1,
                step: 1
            )),
            .text(Item.Text(key: "a1", text: "你好，我是 DeepSeek。", live: false, at: clock + 2_000, messageId: "m-assistant")),
        ]
        if UITestLaunch.extraChatForKeyboard {
            for i in 2...16 {
                let at = clock + Int64(i) * 1_000
                items.append(.user(Item.User(key: "u\(i)", text: "消息 \(i)", at: at, messageId: "m-user-\(i)")))
                items.append(.text(Item.Text(
                    key: "a\(i)",
                    text: "回复 \(i)。",
                    live: false,
                    at: at + 500,
                    messageId: "m-assistant-\(i)"
                )))
            }
        }
        chat = ChatState(
            sessionId: chatId,
            items: items,
            title: "你好",
            loaded: true,
            composerMetrics: ComposerMetrics(
                activity: ComposerActivity(
                    turns: 1,
                    steps: 2,
                    llmMs: 1000,
                    toolMs: 0,
                    ttftMs: 100,
                    ttftSteps: 1,
                    decodeMs: 1000,
                    decodeTokens: 216
                ),
                tokens: ComposerTokenUsage(
                    uncachedInputTokens: 31,
                    cacheReadTokens: 69,
                    cacheWriteTokens: 0,
                    outputTokens: 10
                ),
                context: ComposerContext(usedTokens: 2, contextWindow: 100)
            )
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
        case "chat", "trajectory", "trajectoryDetail":
            seedUITestJobs()
        case "chatDock":
            seedUITestChatDocks()
        case "jobs":
            seedUITestJobs()
            // `jobs.kill` only enables the stop control. Do not advertise
            // `jobs.list`: that starts `retainJobsWatch` with no Host client.
            ops.insert("jobs.kill")
        case "builtinPlugins":
            ops.insert("plugins.inventory")
            showDrawer = false
            push(.builtinPlugins)
        case "models", "permission":
            break
        case "connections":
            showDrawer = false
            nearby = [
                DiscoveredHost(
                    instanceId: String(repeating: "f", count: 64),
                    host: "192.168.1.42",
                    port: 7690,
                    deviceName: "客厅 Mac"
                ),
            ]
            push(.connections)
        case "settings", "general":
            showDrawer = false
            push(.general)
        case "settingsShell":
            showDrawer = false
            push(.settings)
        case "plugins":
            showDrawer = false
            push(.panel(.plugins))
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
            push(.panel(.inspector))
        case "start":
            showDrawer = false
            push(.panel(.start))
        case "composerStop":
            chat?.running = true
            composerText = ""
        case "slash":
            composerText = "/"
            // Desktop slash HOST_FACES + /file + /model + /feedback + /export.
            // Keep these ops on this screen only so other fixtures stay still.
            ops.formUnion(["attachments.upload", "sessionFeedback.record", "commands.execute"])
            commandEntries = [
                .object([
                    "name": .string("goal"),
                    "definitionId": .string("@deepseek-ai/dsh-command-goal"),
                ]),
                .object([
                    "name": .string("plan"),
                    "definitionId": .string("@deepseek-ai/dsh-plan-mode"),
                ]),
                .object([
                    "name": .string("compact"),
                    "definitionId": .string("@deepseek-ai/dsh-command-compact"),
                ]),
                .object([
                    "name": .string("permission"),
                    "definitionId": .string("@deepseek-ai/dsh-permission-presets"),
                ]),
            ]
        default:
            fatalError("UITestLaunch: unknown screen \(screen)")
        }
    }

    /// Desktop TodoPanel / GoalBar / QueueDock. Kept off the `chat` fixture so
    /// `*-chat.png` stays stable; `chatDock` is the dedicated screenshot path.
    fileprivate func seedUITestChatDocks() {
        guard var state = chat else {
            fatalError("UITestLaunch chatDock requires a chat session")
        }
        state.todos = [
            TodoItem(content: "核对配对链接边距", status: "in_progress"),
            TodoItem(content: "换成官方 SVG", status: "completed"),
            TodoItem(content: "截图断言", status: "pending"),
        ]
        state.goal = .object([
            "phase": .string("active"),
            "objective": .string("对齐桌面 Todo / Goal / Queue dock"),
            "revision": .number(1),
        ])
        state.queuedPrompts = [
            QueuedPrompt(id: "q-dock", text: "继续对照桌面源码", sending: false, editable: true),
        ]
        chat = state
        ops.insert("queue.update")
        goalActivation = "armed"
    }

    /// Desktop `JobListAction` only paints the header trigger when the
    /// session can see at least one job. Seed a live bash row so chat /
    /// trajectory screenshots lock the official chevron (not SF `clock`).
    /// Do not advertise `jobs.list`: that starts `retainJobsWatch`, which
    /// clears the snapshot and then has no Host client to refill it.
    fileprivate func seedUITestJobs() {
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
