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

    /// Drive composer `setMarkedText` / `unmarkText` from XCUITest without a
    /// software CJK keyboard on the simulator.
    static var composerIme: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestComposerIme")
    }

    /// Multi-line CJK used by `chatLong` screenshots. Must wrap inside the
    /// desktop `.userStack` max-width instead of stretching full bleed.
    static let longUserMessage =
        "这是一条很长的用户消息，用来确认气泡会在桌面 max-width 内换行，而不是从左侧一直撑到右缘。第二句继续写，避免单行把布局测成未换行。"
}

extension Notification.Name {
    static let dshComposerImeSetMarked = Notification.Name("dsh.composerIme.setMarked")
    static let dshComposerImeUnmark = Notification.Name("dsh.composerIme.unmark")
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
        presetRoster = [
            jsonObject(["id": .string("standard"), "isDefault": .bool(true)]),
            jsonObject(["id": .string("cordis")]),
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
            .text(Item.Text(
                key: "a1",
                text: "你好，我是 DeepSeek。[README.md](README.md)\n\n- 第一项\n- 第二项",
                live: false,
                at: clock + 2_000,
                messageId: "m-assistant"
            )),
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
            ),
            agentPreset: "standard"
        )

        showDrawer = false
        routeStack = []
        applyUITestScreen(UITestLaunch.screen)
    }

    fileprivate func applyUITestScreen(_ screen: String) {
        switch screen {
        case "sessionHeader":
            seedUITestSessionHeader()
        case "sessionHeaderCompactTeam":
            seedUITestSessionHeader(compactTeam: true)
        case "contextActive", "contextBlank", "contextOffline", "contextUnknown", "contextNoRoster":
            draftWorkspaceId = "ws-android"
            draftPreset = "cordis"
            if screen == "contextBlank" {
                chat = ChatState(sessionId: "s-blank", loaded: true, agentPreset: "standard")
            }
            if screen == "contextOffline", let activeId {
                status[activeId] = .offline
            }
            if screen == "contextUnknown" {
                workspaces = []
                chat?.agentPreset = nil
                chat?.loaded = false
            }
            if screen == "contextNoRoster" { presetRoster = [] }
        case "contextLandingEmpty":
            chat = nil
            firstPrompt = nil
            workspaces = []
            presetRoster = []
        case "landing", "startLanding":
            chat = nil
            firstPrompt = nil
        case "landingPreset":
            chat = nil
            firstPrompt = nil
            seedUITestAgentPresets()
        case "landingMention":
            chat = nil
            firstPrompt = nil
            seedUITestMentionComposer(
                text: "@",
                files: [
                    uiTestFileMention("README.md"),
                    uiTestFileMention("src/", directory: true),
                ],
                sessions: [uiTestSessionMention()]
            )
        case "drawer", "viewOptions", "sessionActions":
            showDrawer = true
            // Desktop workspace-row overflow (`IconEllipsisOutline`). Off other
            // screens so `*-chat.png` / files / connections stay still.
            ops.formUnion(["workspace.rename", "workspace.delete"])
        case "chat", "chatLong", "changesCard", "changesReview", "changesRetry", "trajectory", "trajectoryDetail", "planMode", "mention", "mentionFiltered", "mentionChip", "mentionSent", "turnTrigger":
            seedUITestJobs()
            if screen == "turnTrigger" { seedUITestTurnTrigger() }
            if ["changesCard", "changesReview", "changesRetry"].contains(screen) {
                seedUITestChangesCard()
                if screen != "changesCard" { seedUITestChangesReview(retry: screen == "changesRetry") }
            }
            if screen == "chatLong" {
                guard var state = chat else {
                    fatalError("UITestLaunch chatLong requires a chat session")
                }
                guard case .user(var user) = state.items.first else {
                    fatalError("UITestLaunch chatLong requires the fixture user row")
                }
                user.text = UITestLaunch.longUserMessage
                state.items[0] = .user(user)
                chat = state
            }
            if screen == "planMode" {
                chat?.planMode = true
                composerText = ""
                composerCursor = 0
            }
            if screen == "mention" {
                seedUITestMentionComposer(
                    text: "@[你好](dsh-session:s-hello) @README.md @",
                    files: [
                        uiTestFileMention("README.md"),
                        uiTestFileMention("src/", directory: true),
                    ],
                    sessions: [uiTestSessionMention()]
                )
            }
            if screen == "mentionFiltered" {
                seedUITestMentionComposer(
                    text: "@READ",
                    files: [uiTestFileMention("README.md")],
                    sessions: []
                )
            }
            if screen == "mentionChip" {
                seedUITestMentionComposer(
                    text: "@[你好](dsh-session:s-hello) ",
                    files: [],
                    sessions: []
                )
            }
            if screen == "mentionSent" {
                composerText = ""
                composerCursor = 0
                guard var state = chat else {
                    fatalError("UITestLaunch mentionSent requires a chat session")
                }
                guard case .user(let user) = state.items.first else {
                    fatalError("UITestLaunch mentionSent requires the fixture user row")
                }
                state.items = [
                    .user(Item.User(
                        key: "u-mention",
                        text: "@[你好](dsh-session:s-hello) @README.md",
                        at: user.at,
                        messageId: "m-mention"
                    )),
                ]
                chat = state
            }
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
            ops.insert("plugins.inventory")
            ops.insert("presets.list")
            push(.settings)
        case "plugins":
            ops.insert("plugins.install")
            showDrawer = false
            push(.panel(.plugins))
        case "schedule":
            showDrawer = false
            push(.panel(.schedule))
        case "terminal":
            showDrawer = false
            push(.panel(.terminal))
        case "terminalSwitcher":
            showDrawer = false
            ops.insert("terminal.close")
            terminalAttachFrozen = true
            terminalOpening = false
            terminalFailure = nil
            terminalMissing = false
            terminalExited = false
            terminal.write("switcher-shell-output")
            terminalRevision = terminal.revision
            let sessionId = chat?.sessionId ?? ""
            uiTestTerminalEntries = [
                TerminalSessionEntry(
                    sessionId: sessionId,
                    id: "term-a",
                    title: "zsh",
                    state: "running",
                    cwd: "/Users/dev/dsh-ios",
                    shellName: "zsh"
                ),
                TerminalSessionEntry(
                    sessionId: sessionId,
                    id: "term-b",
                    title: "zsh",
                    state: "running",
                    cwd: "/tmp",
                    shellName: "zsh"
                ),
            ]
            terminalMeta = TerminalMeta(
                sessionId: sessionId,
                id: "term-a",
                attachmentId: "attach-a",
                title: "zsh",
                state: "running",
                cwd: "/Users/dev/dsh-ios"
            )
            push(.panel(.terminal))
        case "terminalUnavailable":
            showDrawer = false
            terminalAttachFrozen = true
            terminalOpening = false
            terminalFailure = "terminalController.follow(...) is not a function"
            terminalMissing = false
            terminalMeta = nil
            push(.panel(.terminal))
        case "terminalMissing":
            showDrawer = false
            terminalAttachFrozen = true
            terminalOpening = false
            terminalMissing = true
            terminalFailure = nil
            terminalMeta = nil
            push(.panel(.terminal))
        case "terminalDisconnected":
            showDrawer = false
            terminalAttachFrozen = true
            terminalOpening = false
            if let hostId = activeId {
                status[hostId] = .offline
            }
            terminalFailure = nil
            terminalMissing = false
            terminal.write("preserved-shell-output")
            terminalRevision = terminal.revision
            terminalMeta = TerminalMeta(
                sessionId: chat?.sessionId ?? "",
                id: "term-saved",
                attachmentId: "attach-saved",
                title: "Terminal",
                state: "running",
                cwd: "/Users/dev/dsh-ios"
            )
            push(.panel(.terminal))
        case "terminalExited":
            showDrawer = false
            terminalAttachFrozen = true
            terminalOpening = false
            terminalFailure = nil
            terminalMissing = false
            terminalExited = true
            terminal.write("closed-shell-output")
            terminalRevision = terminal.revision
            terminalMeta = nil
            push(.panel(.terminal))
        case "filePreviewPython":
            ops.remove("files.list")
            codeWordWrap = false
            if let index = sessions.firstIndex(where: { $0.sessionId == chat?.sessionId }) {
                sessions[index].cwd = "/Users/dev/dsh-ios"
            }
            uiTestFilePreviewText = CodePreviewFixture.python
            filePreview = FilePreviewRef(sessionId: chat?.sessionId ?? "", path: CodePreviewFixture.path)
            showDrawer = false
            push(.panel(.files))
        case "filePreview":
            ops.remove("files.list")
            codeWordWrap = false
            let filesCwd = "/Users/dev/dsh-ios"
            if let index = sessions.firstIndex(where: { $0.sessionId == chat?.sessionId }) {
                sessions[index].cwd = filesCwd
            }
            uiTestFilePreviewText = "print(\"hello\")\n"
            filePreview = FilePreviewRef(sessionId: chat?.sessionId ?? "", path: "main.py")
            showDrawer = false
            push(.panel(.files))
        case "files":
            // Host `files.list` would overwrite the seeded tree. Keep the
            // op off this screen only so other fixtures stay still.
            ops.remove("files.list")
            let filesCwd = "/Users/dev/dsh-ios"
            if let index = sessions.firstIndex(where: { $0.sessionId == chat?.sessionId }) {
                sessions[index].cwd = filesCwd
            }
            var tree = FileTreeState.root
            fileTreeApplyListing(
                &tree,
                path: "",
                entries: [
                    WorkspaceFileEntry(name: "src", type: "directory"),
                    WorkspaceFileEntry(name: "main.py", type: "file"),
                    WorkspaceFileEntry(name: "app.go", type: "file"),
                    WorkspaceFileEntry(name: "Content.swift", type: "file"),
                    WorkspaceFileEntry(name: "package.json", type: "file"),
                    WorkspaceFileEntry(name: "README.md", type: "file"),
                    WorkspaceFileEntry(name: "docker.sock", type: "other"),
                ],
                truncated: false
            )
            fileTreeStates[fileTreeCacheKey(sessionId: chat?.sessionId, cwd: filesCwd)] = tree
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
            composerCursor = 0
        case "slash":
            composerText = "/"
            composerCursor = 1
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

    fileprivate func seedUITestMentionComposer(
        text: String,
        files: [FileReference],
        sessions: [SessionReference]
    ) {
        composerText = text
        composerCursor = text.count
        mentionQuery = mentionMenuTrigger(text, cursor: text.count)?.query
        mentionDrilled = false
        fileMentions = files
        sessionMentions = sessions
    }

    fileprivate func uiTestFileMention(_ path: String, directory: Bool = false) -> FileReference {
        FileReference.parse(.object([
            "path": .string(path),
            "kind": .string(directory ? "directory" : "file"),
        ]))!
    }

    fileprivate func uiTestSessionMention() -> SessionReference {
        SessionReference.parse(.object([
            "mention": .string("@[你好](dsh-session:s-hello)"),
            "title": .string("你好"),
            "sessionId": .string("s-hello"),
        ]))!
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
    /// Desktop `TurnTriggerNodeView` default icon is `IconContextInjectionOutline`.
    /// Kept off `chat` so `*-chat.png` stays stable.
    fileprivate func seedUITestTurnTrigger() {
        guard var state = chat else {
            fatalError("UITestLaunch turnTrigger requires a chat session")
        }
        let at = state.items.compactMap { item -> Int64? in
            switch item {
            case .user(let user): return user.at
            case .text(let text): return text.at
            default: return nil
            }
        }.min() ?? Int64(Date().timeIntervalSince1970 * 1000)
        state.items.insert(
            .context(Item.Context(
                key: "trig-request",
                text: "open-step claimed",
                sourceKind: "execution-request",
                at: at - 1_000,
                messageId: "m-trigger",
                waking: true
            )),
            at: 0
        )
        chat = state
    }

    /// Single-file workspace-changes card: desktop `UserContent` `.fileCard`
    /// paints `FileTypeIcon`, not SF `doc.text`.
    fileprivate func seedUITestChangesCard() {
        guard var state = chat else {
            fatalError("UITestLaunch changesCard requires a chat session")
        }
        guard case .text(var assistant) = state.items.last(where: {
            if case .text = $0 { return true }
            return false
        }) else {
            fatalError("UITestLaunch changesCard requires the fixture assistant row")
        }
        assistant.turn = 1
        guard let assistantIndex = state.items.lastIndex(where: {
            if case .text(let text) = $0 { return text.key == assistant.key }
            return false
        }) else {
            fatalError("UITestLaunch changesCard could not re-find the assistant row")
        }
        state.items[assistantIndex] = .text(assistant)
        state.items.append(.changes(Item.Changes(key: "ch1", turn: 1, seq: 29)))
        state.turns = [TurnRecord(turn: 1, startSeq: 1, endSeq: 30, startedAt: assistant.at, endedAt: (assistant.at ?? 0) + 1_000)]
        state.lastAnswerKeys = [1: assistant.key]
        chat = state
        ops.formUnion(["workspaceChanges.summary", "workspaceChanges.diff"])
        uiTestChangesSummary = WorkspaceChangesSummary(
            turn: 1,
            cwd: "/Users/dev/dsh-ios",
            files: [
                WorkspaceChangedFile(
                    path: "README.md",
                    display: "README.md",
                    added: 4,
                    deleted: 0
                ),
            ],
            total: 1,
            added: 4,
            deleted: 0
        )
        uiTestChangesDiffs = [
            0: WorkspaceFileDiff(
                kind: "text", path: "README.md", display: "README.md", before: false,
                hunks: [WorkspaceDiffHunk(oldStart: 0, newStart: 1, lines: ["+# dsh-ios", "+", "+Native iOS client.", "+Pocket workspace changes."])]
            ),
        ]
    }

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

    /// Built-in roster so landing can open `AgentPresetSeat`. Regular
    /// `landing` / `landingMention` stay empty so those screenshots do not
    /// pick up the chip.
    fileprivate func seedUITestAgentPresets() {
        presetRoster = ["standard", "ptc", "minimal", "cordis"].map { id in
            .object(["id": .string(id)])
        }
        draftPreset = "minimal"
    }
}
