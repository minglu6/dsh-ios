# iOS ↔ Android / desktop parity gap

Phone is a controller. Layout may change for a narrow portrait screen. Features, copy, icons, colors, states, and interactions follow the official desktop UI (`@deepseek-ai/dsh@0.2.1-alpha.2`, git `d743267`) as already ported by [dsh-android](https://github.com/minglu6/dsh-android) `main` at **`729ef2e`**.

**Do not invent** settings groups, credential pages, extra security, or placeholder shells. Hide only what desktop itself hides (local OS editor, keyboard shortcuts).

| Tag | Meaning |
| --- | --- |
| **present** | iOS already matches Android/desktop semantics (layout may differ) |
| **partial** | Entry or a thin slice exists; missing chrome, locales, or Host ops |
| **missing** | No user-visible surface; must implement and expose |
| **hide** | Desktop-local chrome; keep hidden on the phone |

Android docs this matrix follows: `docs/feature-parity.md`, `docs/desktop-parity.md`, `docs/trajectory-parity.md`, `docs/audit/2026-10-14-parity-audit.md`.

## Planned PRs

| Batch | Scope | Status |
| --- | --- | --- |
| A | Trajectory ledger + inspector; chat message actions (copy / like / dislike / branch) | done (#3) |
| B | Host PTY terminal + workspace file tree | done (#4) |
| C | Live jobs panel + completion unread green-dot sync | done (#5) |
| D | Plugin manager + schedule + remaining official settings + chat polish | done (#6) |
| E | Permissions + ModelPicker + questions/commands/attachments/queue/goals + Todo/stats/retry + mention/approval/HostUi close | done (#7) |
| F | WorkspaceChanges + TrajectoryRequest leftover + Session Inspector + Browser + CodePreview + transcript publisher | done (#8) |
| G | session search/export, Agent presets, NSD, notifications, unarchive, drag reorder, NavigationPolicy | done (#9) |
| P0 | Brand wordmark + official plugin market | done (#12) |
| P1 | Chat share row, composer model/permission chips, Start IA, settings shell | done (#13) |
| H | Android `d1d7ef8…729ef2e`: Qoder / command menu / files.follow / browser tabs / Office·PDF·XLS / offline gray-out / archived rename·fork | done (#11) |
| P1-fix | WorkspaceChanges independent cards; hide Start desktop shortcuts | done (#15) |
| R3-P1 | 变更卡解析 / 抽屉安全区 / 会话列表刷新 / 技能组 / 工作步骤默认 detailed | done (#19) |
| P2 | `session/not-found` silent drop; terminal Meslo Nerd cascade; drawer search cap/clear/empty; remove header ⋯ | done (#16) |
| P2-visual | xterm Tango ANSI; terminal tab title / 关闭; file-icon 色; 设置 locales; 链接打开两项 | done (#20) |
| tree/slash | 文件树原地展开；斜杠菜单贴输入框 | done (#21) |
| R4 | collapseTiming 写回 Host；composer / 运行态 / 提问 / 任务输出 / 插件空态对齐桌面文案 | this PR |

---

## File map

| Surface | Official package | Android | iOS now |
| --- | --- | --- | --- |
| Transcript fold | `ui-chat` / `ui-conversation` | `protocol/Transcript.kt`, `Chat.kt`, `ChatProcess.kt` | `protocol/…/Transcript.swift`, `ChatProcess.swift`, `Features/Chat/ChatView.swift` |
| Message actions | `ui-chat` `MessageIconActions` | `Chat.kt` `MessageActions` | `ChatView` `MessageActions` (copy / like / dislike / share + turn usage; branch on the session row menu) |
| Trajectory | `ui-trajectory` | `Trajectory.kt` + Detail/Inspector/Request/Locales; `protocol/TrajectoryTimeline.kt` | `Features/Trajectory/` + `protocol/Trajectory.swift` / `TrajectoryRequest.swift` |
| WorkspaceChanges | Host `workspaceChanges.summary/diff` | `WorkspaceChanges.kt` | `Features/Chat/WorkspaceChanges.swift` + `protocol/WorkspaceChanges.swift` |
| Session Inspector | desktop session-inspector | `SessionInspectorPanel.kt` / Log / Model / Navigation | implemented, unexposed (desktop Start / ⋯ have no entry) |
| Browser | local HTTP(S) panel | `BrowserPanel.kt` + `BrowserPolicy.kt` | implemented, unexposed (desktop Start / ⋯ have no entry) |
| Code preview | shiki offline preview | `CodePreview.kt` | `Features/Files/CodePreview.swift` + `CodePreviewAssets/` |
| Terminal | Host `terminalController` | `TerminalPanel.kt`, `TerminalView.kt`, `TerminalEmulator.kt` | `Features/Terminal/` + `protocol/TerminalEmulator.swift`; bundled MesloLGL DZ Nerd Font + CoreText cascade; default fg/bg follow appearance; ANSI 16 = desktop xterm.js Tango (#20) |
| Files | `workspaceFiles` | `FilesPanel.kt` | `Features/Files/` + workspace tree / browse |
| Jobs | `job-controller` | `JobsAction.kt`, jobs follow in `Pocket.kt` | header chip + `JobsPanel` (`jobs.list` / `follow` / `kill`) |
| Plugins | `ui-plugin-manager`, `ui-settings-plugins` | `PluginsScreen.kt`, `PluginInventory.kt` | `Features/Plugins/` + `PluginPolicy.swift` |
| Schedule | `ui-schedule` (sidebar, not settings) | `ScheduleScreen.kt`; drawer row | `Features/Schedule/ScheduleScreen.swift`; drawer only |
| Permissions | `ui-permission` | `PermissionUi.kt` `permissions.catalog/get/set` + risk sheet | `PermissionUi.swift` + session picker + Settings defaults + `danger-full-access`/`auto` confirm |
| Model picker | composer model menu | `ModelPicker.kt` + effort pane | `ModelPicker.swift` two-level picker; switching models clears effort |
| Composer dock | `ui-chat` | UserQ / Approval / Todo / Goal / Queue / Composer / Stats | same stack in `ChatView` + `ChatDock.swift` |
| Host UI | pocket `ui.open` | native plugin manager; no embedded WebView | same; desktop market has no `ui.open` banner |
| Markdown | `ui-chat` primitives | `Markdown.kt` | `protocol/Markdown.swift` + `Features/Chat/MarkdownView.swift` |
| Official icons | desktop `D.*` | Android vector set | `Design/Icons.swift` SF Symbol map |
| Connection keep-alive | — | `ConnectionService` FGS | `ConnectionKeeper` `beginBackgroundTask` + ping + `BGAppRefreshTask` `dev.dsh.pocket.ios.refresh` + path monitor + local notify |

---

## 1. Chat

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| User bubble, pending echo | `Chat.kt` | `MessageRow` `.user` | **present** | — |
| Assistant text stream | follow reducer | `.text` live/committed | **present** | — |
| Reasoning disclosure | Think icon + preview | official Think / 思考 + preview; Markdown body | **present** | **D** |
| Tool row → inspector | `Chat.kt` tool card | `ToolProcessSummary` title/icon/receipt + inspect sheet | **present** | **D** |
| Process group fold | `ChatProcess.kt` | `foldChatItems` / `visibleChatRows` + `ProcessGroupView` | **present** | **D** |
| Notices (stopped / max-tokens / account) | reducer + official `message.*` | reducer emits; `.notice` / `RetryRow` / `TurnFailureRow` | **present** | **E** |
| Deliverables | `Item.Deliverable` | tap opens workspace file preview | **present** | **B** |
| Markdown / code block / tables | `Markdown.kt` | AST + GFM tables / code / file chips | **present** | **D** |
| Copy / like / dislike / share | `MessageActions` + `FeedbackCategory` | desktop row is share (not branch); branch stays on the session row menu | **present** | **A** / **P1** |
| Turn usage pill | `ComposerStats.kt` `TurnUsageAction` | same; only `PerformanceUsage.Detailed` | **missing** → **present** | **E** |
| Composer statistics | Activity / Usage / Context pills | `ComposerStats` + Host projections | **missing** → **present** | **E** |
| Composer queue / steer | busyEnter + `queue.update` | `busySend` + `PromptQueue` edit/remove/steer | **partial** → **present** | **E** |
| `@` mentions | `MentionMenu.kt` official `@path` / `@"path"` / `@[title](dsh-session:…)` | same tokens + chip row + mention panel | **partial** → **present** | **E** |
| `/` commands | `CommandPopupSheet` `commands.list/execute` | 贴输入框弹层（#21）；`+` 与 `/` 同菜单；不接受附件的指令先 toast 官方句再执行 | **missing** → **present** | **E** / **P2** / **#21** / **R4** |
| Header ⋯ overflow | Android `MoreSheet` (not desktop) | **removed** — desktop conversation header has no ⋯; export/feedback on `/` and `+`; rename/fork on the drawer row menu | **hide** | **P2** (#16) |
| Session image bubbles | `session.attachment` + ImageBubble | same cache + retry + original preview | **missing** → **present** | **G** |
| Attachments | `attachments.upload` | image picker + file importer + receipts | **missing** → **present** | **E** |
| User questions | `UserQuestionCard` `userQuestions.answer` | same card / plan-review / skip+submit | **missing** → **present** | **E** |
| Approvals | official `ApprovalCard` takes composer | official card; `accepted` callback clears busy, success drops the row | **partial** → **present** | **E** |
| TodoPanel | dock card above composer | `TodoPanel` expand in place | **missing** → **present** | **E** |
| Goal bar | `goals.get` / `goal.activation` CAS | `GoalBar` + `GoalSheet` pause/resume/clear/edit | **missing** → **present** | **E** |
| Permission mode | catalog/get/set + risk sheet | session picker + Settings defaults (`auto` not a default) | **partial** → **present** | **E** |
| Model + effort | two-level picker | `ModelPicker` root / models / effort | **partial** → **present** | **E** |
| No “scroll to bottom” FAB | `followBottom` | auto-scroll only | **present** | — |

## 2. Trajectory

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Build ledger from items | `Trajectory.kt` `buildTrajectory` | `Trajectory.swift` `buildTrajectory` | **present** | **A** |
| 7 cell kinds | system / user / context / compacted / message / tool / subtool | same kinds + reducer `system/message` / compaction | **present** | **A** |
| Compact ledger (事件 + 内容) | `Trajectory.kt` | `TrajRowView` | **present** | **A** |
| Toolbar 时长 / 轮次 / 调用 + search | `TrajectoryToolbar` port | same chips + search field | **present** | **A** |
| Swimlane overview | `TrajectoryTimeline.kt` | `TrajectoryTimeline.swift` + `SwimlaneChart` | **present** | **A** |
| Inspector tabs 概述 / 参数 / 结果 / Schema / 计时 | `TrajectoryDetail.kt` | `TrajectoryDetailSheet` | **present** | **A** |
| JSON tree expand / copy | `TrajectoryJson.kt` | `TrajectoryJsonView` + protocol `TrajectoryJson.swift` | **missing** → **present** | **H** |
| Request inspector | `TrajectoryRequest.kt` | ledger boundary chip + Request sheet 概述/选项/用量/计时; overview parentRequest | **missing** → **present** | **F** |
| Official locales | `TrajectoryLocales.kt` ← `ui-trajectory` `locales.ts` | `TrajL` | **present** | **A** |
| Chat / 轨迹 entry | session header + more sheet | session header tabs 对话 / 轨迹 | **present** | **A** |

## 3. Terminal

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| `terminal.list/create/follow/write/resize/close` | `PocketClient` + `TerminalPanel.kt` | `PocketClient` + `TerminalPanel` (shown when ops advertised) | **present** | **B** |
| PTY emulator + Tango ANSI | `TerminalEmulator.kt` | `AnsiTerminal` + xterm.js Tango 16（#20） | **present** | **B** / **#20** |
| Nerd / Powerline glyphs | bundled `MesloLGL DZ Nerd Font` | same TTF + CoreText cascade (`TerminalTypeface`) | **partial** → **present** | **P2** (#16) |
| Default fg/bg follow appearance | canvas tokens | `T.ink` / `T.bg`; ANSI 16 = xterm.js Tango（#20）；默认 fg/bg 仍跟浅/深色 | **present** | **D** / **#20** |
| Top shortcut row; Tab → `\t` | `TerminalView.kt` | same two-row English keycaps; Tab sends `\t`. Tab title is shell name only; 退出 → 关闭（#20） | **present** | **B** / **P1** / **#20** |
| Tap cursor / long-press select | `TerminalView.kt` | tap / long-press + drag | **present** | **B** |
| Resume saved PTY identities | `Pocket.kt` | `TerminalStore` + `selectTerminal` | **present** | **B** |

## 4. Files / workspace

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| `files.list/read` listing | `FilesPanel.kt` | `FilesPanel`（`files.list` 公布时）。原地展开/折叠 + 桌面 file-icon 色（#20/#21） | **present** | **B** / **P1** / **#20** / **#21** |
| Preview (md / text / image / PDF / Office / XLS) | `FilePreview.kt` + `OfficePreview.kt` + `WorkbookPreview.kt` | same kinds; PDFKit pages; `office.*` lease → PDF; XLS FortuneSheet over `dsh-workbook-preview://` | **partial** → **present** | **B** / **F** / **H** |
| Workspace entities / tree | `WorkspaceNavigation.kt` | entity groups / tree / rename / delete / new session | **present** | **B** |
| Add workspace browse | `WorkspaceDirectoryPicker.kt` | `WorkspaceDirectorySheet` when `workspace.create` | **present** | **B** |
| Session search | `sessions.search` + local title/path merge | desktop `ui-workspace` Search: 250ms, NUL/500 UTF-16 sanitize, local metadata immediately, Host failure keeps local with no warning, cap 20 + 「仅显示前 n 条…」, empty 「无匹配会话」, clear drops Host hits, picking an unarchived row clears search | **missing** → **present** | **G** / **P2** (#16) |
| Unarchive / archived not openable | restore dialog; `workspace.unarchiveSession` | same; archived rows do not `openSession` | **missing** → **present** | **G** |
| Workspace / session reorder | Host `insertBefore` / `insertSessionBefore` (Android UI is local Manual) | drag/drop calls Host ops when advertised; Manual order still local | **missing** → **present** | **G** |
| NavigationPolicy | `workspaceDisplayTitle` / `visibleDrawerSession` / `reconcileSessionOrder` / `workspaceBranches` / `archiveActivityDescription` | same Swift ports in `Workspace.swift` | **partial** → **present** | **G** |
| Open-in-desktop-editor | desktop only | — | **hide** | — |
| WorkspaceChanges cards | `WorkspaceChanges.kt` | chat cards + review sheet (`workspaceChanges.summary/diff`); `workspace/changes` announcement; attached to last answer when visible, otherwise an independent card outside 「已完成」 | **missing** → **present** | **F** / P1 |
| File tree live updates | `files.follow` + `observeWorkspaceDirectory` | same; watch-unsupported falls back to list | **partial** → **present** | **F** / **H** |
| Browser | `BrowserPanel.kt` + `BrowserTabs.kt` HTTP(S)-only, addresses-only checkpoints | implemented (multi-tab `{selected, pages:[{id,url,title}]}`); unexposed — desktop Start / ⋯ have no entry | **hide** | **P1** / **H** |
| Session Inspector | `SessionInspectorPanel` raw/grouped + pick | implemented, unexposed — desktop Start / ⋯ have no entry | **hide** | **P1** |

## 5. Jobs + unread

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Header jobs chip | `JobsAction.kt` | tabs-row chip (`jobs.list` advertised + non-empty / failed) | **present** | **C** |
| Failed refresh → 「任务状态不可用」 (not 0) | `JobsAction.kt:62-64` | same copy, stale running count discarded | **present** | **C** |
| `jobs.list` / `follow` / `kill` | `Pocket.kt` | `PocketClient` + `JobsPanel`; list+live follow share one roster | **present** | **C** |
| Unread green dot | `CompletionReminders` epoch+revision | epoch+revision; leading slot only | **present** | **C** |
| Task / approval local notifications | `ConnectionService` + `TaskNotifyTexts` | UNUserNotificationCenter; same titles/tags; no ForegroundService | **missing** → **present** | **G** |
| `completion.view` failure does not drop WS | `Pocket.kt` | `syncCompletionView` retry | **present** | — |
| `follow` without `maxMessages` | `PocketFollowTest` | `FollowRequest.args` | **present** | — |

## 6. Plugins + schedule + settings

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Drawer 插件 (`plugins.list`) | `Screens.kt` | shown if op advertised | **present** | **D** |
| Plugin manager (official market + switch + add) | `PluginsScreen.kt` | desktop `ui-plugin-manager`: 「官方 N」 rows (icon / name / 实验性 / description / toggle), subtitle, refresh, 「+ 添加插件」; config namespaces are not the hub | **present** | **D** / P0 |
| Registries + inspect | `PluginsScreen.kt` | `plugins.registries` / `plugins.inspect` | **present** | **D** |
| Built-in plugin slots from Host describe | audit P1; no APK whitelist | `plugins.settingsDescribe` on bundle detail 「配置组件」, not a market list | **present** | **D** / P0 |
| PluginArtwork (desktop canvas kinds + sanitized SVG) | `PluginArtwork.kt` | `PluginArtwork.swift` official 36×36 paths; metadata SVG when Host provides it | **present** | **D** / P0 |
| Settings 「内置插件」 inventory | `PluginInventory.kt` session/global groups | same grouping + preset picker; no unofficial offline banner | **present** | **D** / **H** |
| Plugin add menu | `PluginAddMenu` 第三方 / 创造模式 | same two entries on the official market header | **partial** → **present** | **H** |
| HostUi (`ui.open`) | Android native manager; no pocket WebView chrome | no embedded plugin WebView; desktop market has no `ui.open` banner | **present** | **E** / **H** / P0 |
| Drawer 自动化 (not a settings section) | `ScheduleScreen.kt` | drawer only; Settings 自动化 row removed | **present** | **D** |
| Schedule catalog / edit / history | `ScheduleScreen.kt` | CAS update + delete + history; New → chat | **present** | **D** |
| Agent presets | `AgentPresetSettingsScreen.kt` | Settings row + guide + Creator CTA when `presets.list`/`presets.settings` | **missing** → **present** | **G** |
| General: fonts, transcript, collapse, busy, performance, log upload, link opening | `GeneralSettingsScreen` | appearance 3 cards + `14 px` menu; fonts **local only**; `collapseTiming` 与桌面一样写 Host `ui-chat.collapseTiming`（`next-input`）；链接行标题「网页链接默认打开方式」 | **present** | **D** / **P1** / **#20** / **R4** |
| Offline gray-out (no unofficial banner) | Android `SettingsScaffold` invents 「远程主机未连接，需连接的操作暂不可用」; desktop has no such chrome | **desktop-first:** no top banner / no extra copy; status 「未连接」; Models / 内置插件 / Agent 预设 / drawer 插件·自动化 gray + unclickable; `lastOps` keeps rows | **missing** → **present** | **H** |
| Qoder CN card | `QoderConnectionCard.kt` last in `llm-qoder` | same PAT write-only + revision fence | **missing** → **present** | **H** |
| Models intro | `modelsSettingsIntro` | 「填入各提供商的 API 密钥即可使用其模型。」 | **partial** → **present** | **P1** / **H** |
| Permission defaults | `PermissionPickerSheet(forDefaults)` + risk | same; `auto` cannot be a default | **partial** → **present** | **E** |
| Models provider editor + keys | `ModelsSettingsScreen.kt` | `models.providers*` + `credentials.*` | **present** | **D** |
| 「移动端」 group / 代码自动换行 | Android still has these (audit S2/S5) | wrap is local; no extra mobile group copied | **present** | — |
| Version only on General | audit S3 | General only | **present** | — |
| Account / shortcuts / open config file | desktop-local | — | **hide** | — |
| Phone connection + 复制诊断报告 | connections | connections overflow | **present** | — |
| LAN / NSD discovery | `_dshpocket._tcp` protocol=1 + 64-hex instanceId | same TXT gate; unpaired filter; address bind | **partial** → **present** | **G** |
| Paired-device online poll | TCP probe, 10s, max 2 | same policy (`PairedDeviceStatusPolicy`) | **missing** → **present** | **G** |
| Reconnect restore gate | `ConnectionRestorePolicy` Offline/Connecting only | same; `NWPathMonitor` wakes the loop | **partial** → **present** | **G** |
| Background keep-alive | Android ForegroundService | `beginBackgroundTask` + ping for the system window, then `BGAppRefreshTask` for a later lightweight reconnect/status refresh; **not** FGS | **present** (platform) | **G** |
| Official `D.*` icons | Android vector set | `Design/Icons.swift` SF Symbol map for search / more / archive / preset / download | **partial** → **present** | **G** |

---

## Protocol extras still on Android only

Port as the matching batch needs them (same JSON, no second protocol):

| Android `app/core/protocol` | Used by | Batch |
| --- | --- | --- |
| `TrajectoryTimeline.kt` | Trajectory swimlane | **A done** (`TrajectoryTimeline.swift`) |
| `Transcript.kt` extra items (`System`, `Compacted`, `Retry`, `TurnFailure`, `Changes`; System/Compacted folded, Retry/TurnFailure rendered, Changes cards in chat when coding view is on) | Chat + trajectory | A / D / **E** / **F** |
| `TurnTokenUsage.kt` | Inspector + usage | **E done** (`TurnTokenUsage.swift`) |
| `ComposerMetrics.kt` | Composer statistics | **E done** (`ComposerMetrics.swift`) |
| `WorkspaceChanges.kt` | Changed-file cards | **F done** (`WorkspaceChanges.swift`) |
| `TranscriptPublisher` | 50ms assistant-stream coalescing | **F done** (`TranscriptPublisher.swift`) |
| `BrowserPolicy` / `CodePreview*` / `SessionInspector*` / `TrajectoryRequest` | Browser + preview + inspector + request leftover | **F done** |
| `PermissionModels.kt` | Permission pickers | **D done** (`PermissionModels.swift`) |
| `HostUi.kt` | Plugin/settings slots | **D done** (`HostUi.swift`); **E** adds `ui.close` |
| Session search / feedback / attachment / restore / presets / NSD / notify / reconnect | drawer + `/`/`+` + connection | **G done** (`SessionSearch` / `SessionFeedback` / `SessionAttachment` / `PresetPolicy` / `LanDiscoveryPolicy` / `PairedDeviceStatus` / `ConnectionRestore` / `TaskNotify`) |

Existing iOS `DSHProtocol` now also covers permissions.get/set, queue.update, commands.list/execute, attachments.upload, userQuestions.answer, goals.get/edit/pause/resume/clear, references.files/sessions, session.export, session.attachment, sessions.search, sessionFeedback.record, workspace.unarchiveSession / insertBefore / insertSessionBefore, presets.list/read/settings, ui.close. Approval `accepted` is required (same as Android `Pocket.answer`).

---

## iOS entry rules (after a batch lands)

- Trajectory: session header tabs 对话 / 轨迹 — data is the current follow transcript (no extra Host op). Hidden when coding view is off.
- Opening a Session that the Host answers `session/not-found` for: drop the row (and refresh `sessions.list`), `sessions.clear()` if it was current, **no toast**. Desktop does not surface that wire code.
- Conversation header has no ⋯ overflow. Export and session feedback live on `/` and `+`. Rename, fork, and Copy Session ID live on the drawer session row menu. Header title uses the same rule as the drawer: current blank → 「新会话」, any other missing title → 「未命名」.
- Terminal / files / jobs: expose when the matching op is in `hello.ops` (same as Android).
- Browser / Session Inspector: desktop Start and session ⋯ do not list them. Do not invent an entry; implementations stay unexposed.
- WorkspaceChanges: consume Host `workspace/changes`; chat cards when `showCodeWorkView` and `workspaceChanges.summary` is advertised; diff sheet needs `workspaceChanges.diff`. Keep the card outside the 「已完成」 fold (attach to the last answer when that answer is visible).
- Plugins: drawer when `plugins.list`; market enable when `plugins.setEnabled`; add when `plugins.install`; Settings 「内置插件」 when `plugins.inventory`. Do not embed a plugin WebView (desktop market has none).
- Schedule: **drawer only** (desktop sidebar). Do not add a Settings row.
- Permissions / models / commands / attachments / queue / goals / presets / session search / export / session feedback / unarchive / Host reorder: expose when the matching op is advertised.
- `ui-chat.collapseTiming` is Host-backed (`completion` / `next-input`), same as desktop `TranscriptViewRow`. Do not keep a phone-only copy.
- Appearance and fonts stay on the phone; they must not be written to the remote host.
- Do not show a row that opens an empty TODO page.
- Do not invent banners, buttons, or copy that desktop does not have. Android `SettingsScaffold` / schedule offline banners are **not** official desktop chrome — iOS omits them.

## Batch H 对照清单（Android `729ef2e`）

| 模块 | iOS | 对照的 Android 源码 | 对齐点 |
| --- | --- | --- | --- |
| 模型选择 | `ModelPicker.swift`、`ModelsSettingsView.swift`、`QoderConnectionCard.swift`、`ModelPickerPolicy.swift` | `ModelPicker.kt`、`ModelPickerPolicy.kt`、`ModelsSettingsScreen.kt`、`QoderConnectionCard.kt`、`ModelSettingsForms.kt` | 两级 picker；`DeepSeek 账号` / `DeepSeek Account`；展开卡显示 route slug；官方 intro / 只读句；提供商「由主机配置管理」；Qoder CN PAT 只写 + revision fence，排在提供商列表之后 |
| 插件控件 | `PluginsScreen.swift`、`PluginInventoryView.swift`、`PluginPolicy.swift` | `PluginsScreen.kt`、`PluginInventory.kt`、desktop `ui-plugin-manager` | 官方市场「官方 N」/已安装 + 实验性徽章 + 刷新；添加菜单仅「第三方 / 创造模式」；详情配置组件；不嵌入 WebView；内置插件分组；离线不加顶栏横幅 |
| 命令菜单 | `ChatDock.swift` `CommandSheet`、`ChatView.swift` `commandLeading`、`CommandPolicy.swift` | `Sheets.kt` `CommandPopupSheet` / `commandMenuRows`、`Chat.kt` Plus/`/` 接线、`CommandMenuPolicyTest.kt`；desktop `ui-commands` | `+` 与 `/` 共用同一菜单；空白 composer vs slash 前缀；`file`/`model`/`feedback`/`export` 在 ops 允许且 Host 目录未给出时注入；无会话顶栏 ⋯；无额外 plus 图片快捷入口；附件走系统文件选择（图片走 image、其余 upload） |
| 工作区更新 | `FilesPanel.swift`、`WorkspaceDirectory.swift` | `FilesPanel.kt`、`WorkspaceDirectorySubscription.kt`、`WorkspaceDirectorySubscriptionTest.kt` | `files.follow` + `observeWorkspaceDirectory`；watch-unsupported 回退 list；同路径刷新不清空列表；前台（`scenePhase.active` / Android `RESUMED`）才订阅 |
| 浏览器标签 | `BrowserPanel.swift`、`BrowserTabs.swift` | `BrowserPanel.kt`、`BrowserTabs.kt`、`BrowserTabsTest.kt` | 实现保留：多标签 checkpoint 仅地址；**不**挂开始面板 / 会话⋯（桌面无入口） |
| Office / PDF / XLS | `FilePreview.swift`、`WorkbookPreview.swift`、`OfficePreview.swift`、`WorkbookPreview.swift`（protocol） | `FilePreview.kt`、`OfficePreview.kt`、`WorkbookPreview.kt` | `office.render/read/release` 租约；PDFKit 分页；缺失字体 popover 官方文案；XLS/XLSX FortuneSheet，资源走 `dsh-workbook-preview://` ↔ `https://workbook-preview.invalid`；错误原因仅官方句 |
| 离线灰态 | `SettingsView.swift`、`SessionDrawer.swift`、`ScheduleScreen.swift`、`PluginsScreen.swift` | desktop settings/plugin-manager (no banner); Android `SettingsPages.kt` `SettingsScaffold` banner is **not** copied | 状态处「未连接」（连接行 / 抽屉无 profile 名 / 空会话）；不设顶部横幅、不设说明文案；模型/内置插件/预设/抽屉插件·自动化灰显不可点；离线仍用 `lastOps` 显示入口；归档会话 rename/fork 有 ops 即显示，`enabled=online`（不因 archived 隐藏） |
| JSON 树 | `TrajectoryJsonView.swift`、`TrajectoryJson.swift` | `TrajectoryJson.kt`、`TrajectoryJsonTest.kt` | 展开/收起、可选中文本、点击复制 / 长按多模式；成功文案「复制成功」 |

## Round 4 对照清单（桌面 `packages/client` @ `86a40220`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 收起时机 | `HostSettings` `.collapse`、`CollapseTiming.nextInput = "next-input"` | `ui-chat` `chat-settings.ts` / `TranscriptViewRow.tsx` | 读写 Host `ui-chat.collapseTiming`；缺省 `completion` |
| 链接打开 | `linkOpeningTitle` / `linkOpeningDescription` | `ui-chat` `locale.ts` `settings.links.*` | 标题「网页链接默认打开方式」/ Open chat links in；说明 Choose where to open web links |
| Composer | `composerPlaceholderText` / `composerModelFallback` / 计划芯片 | `ui-conversation` `InputBar.tsx`、`ui-plan` `locales.ts`、`ui-model-selection` `trigger.fallback` | 计划占位「描述你的任务以生成计划」；未选模型「请选择模型」；计划芯片无额外「退出」 |
| 运行态 | `RunningStatusRow` + `deepDivingLabel` | `ui-chat` `RunningStatus.tsx` / `message-chrome.ts` | 对话底部「深度求索中」/「深度求索中，用时 … ···」 |
| 历史 | `loadOlderLabel` | `ui-chat` `ChatView.tsx` `chat.loadOlder` | 空闲「加载更早」，加载中「加载中…」 |
| 提问 / 反馈 | `ask.*` / `messageFeedbackHint` | `ui-conversation` / `ui-message-feedback` locales | 「提问」「回答」「等待中的问题仍可在输入框中回答」；反馈 hint 含日志句 |
| 斜杠附件 | `commandRefusesAttachments` | `ui-commands` `notice.attachmentsUnsupported` | `/{command} 不接受附件，请先移除附件`；草稿保留 |
| 任务输出 | `jobOutputGap` | `ui-jobs` `output.gap` | 「……较早的输出已丢弃……」 |
| 插件空态 | `pluginsEmptyLabel` | `ui-plugin-manager` `empty` | 「还没有安装任何插件。」 |
| 轨迹空账本 | `TrajectoryView` 始终画工具栏 | `ui-trajectory`（无 empty key） | 不再发明「暂无轨迹」空页；加载中「正在加载轨迹…」 |

## Deferred / hide leftovers

- Account / shortcuts / open config file / open-in-desktop-editor: desktop-local — **hide**.
- Keyboard shortcut settings: desktop-local — **hide**. Touch Start also omits desktop chords (`⌘P` / `⌥⌘P` / Ctrl-`) next to 工作区文件 / 新建终端.
- Android ForegroundService persistent “已连接” notification: iOS has no equivalent; `ConnectionKeeper` uses `beginBackgroundTask` + ping, then `BGAppRefreshTask` `dev.dsh.pocket.ios.refresh`. The WS is not guaranteed after the system expires those windows.
- Nearby Wi-Fi (`NEARBY_WIFI_DEVICES`) is Android 13+; iOS uses Local Network + Bonjour (`NSLocalNetworkUsageDescription`).
- CodePreview CSS names `DSH Meslo` at `/font/meslo.ttf`; `dsh-code-preview://` serves the same bundled Meslo Nerd TTF as `TerminalTypeface` (Android `@meslo` → `R.font.meslolgl_dz_nerd_regular`). WKWebView cannot intercept `https://`; assets load over `dsh-code-preview://` mapped to the same Android `https://code-preview.invalid` policy used in tests.
- Embedded browser cannot intercept every subresource the way Android `shouldInterceptRequest` does; main-frame / navigation policy still uses `BrowserPolicy`. WKWebView cannot intercept `https://` for FortuneSheet; workbook assets load over `dsh-workbook-preview://` mapped to Android `https://workbook-preview.invalid`.
- Foundation `JSONSerialization` object key order is not insertion-stable; protocol tests compare parsed `JSONValue`, not pretty strings.
