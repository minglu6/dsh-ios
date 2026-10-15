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
| H | Android `d1d7ef8…729ef2e`: Qoder / command menu / files.follow / browser tabs / Office·PDF·XLS / offline gray-out / archived rename·fork | this PR |

---

## File map

| Surface | Official package | Android | iOS now |
| --- | --- | --- | --- |
| Transcript fold | `ui-chat` / `ui-conversation` | `protocol/Transcript.kt`, `Chat.kt`, `ChatProcess.kt` | `protocol/…/Transcript.swift`, `ChatProcess.swift`, `Features/Chat/ChatView.swift` |
| Message actions | `ui-chat` `MessageIconActions` | `Chat.kt` `MessageActions` | `ChatView` `MessageActions` (copy / like / dislike / branch + turn usage) |
| Trajectory | `ui-trajectory` | `Trajectory.kt` + Detail/Inspector/Request/Locales; `protocol/TrajectoryTimeline.kt` | `Features/Trajectory/` + `protocol/Trajectory.swift` / `TrajectoryRequest.swift` |
| WorkspaceChanges | Host `workspaceChanges.summary/diff` | `WorkspaceChanges.kt` | `Features/Chat/WorkspaceChanges.swift` + `protocol/WorkspaceChanges.swift` |
| Session Inspector | desktop session-inspector | `SessionInspectorPanel.kt` / Log / Model / Navigation | `Features/Inspector/` + `protocol/SessionInspectorLog.swift` / `SessionInspectorModel.swift` |
| Browser | local HTTP(S) panel | `BrowserPanel.kt` + `BrowserPolicy.kt` | `Features/Browser/BrowserPanel.swift` + `protocol/BrowserPolicy.swift` |
| Code preview | shiki offline preview | `CodePreview.kt` | `Features/Files/CodePreview.swift` + `CodePreviewAssets/` |
| Terminal | Host `terminalController` | `TerminalPanel.kt`, `TerminalView.kt`, `TerminalEmulator.kt` | `Features/Terminal/` + `protocol/TerminalEmulator.swift`; default fg/bg follow appearance, Tokyo Night ANSI unchanged |
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
| Copy / like / dislike / branch | `MessageActions` + `FeedbackCategory` | same; `canFork` needs `firstPrompt == nil` | **present** | **A** |
| Turn usage pill | `ComposerStats.kt` `TurnUsageAction` | same; only `PerformanceUsage.Detailed` | **missing** → **present** | **E** |
| Composer statistics | Activity / Usage / Context pills | `ComposerStats` + Host projections | **missing** → **present** | **E** |
| Composer queue / steer | busyEnter + `queue.update` | `busySend` + `PromptQueue` edit/remove/steer | **partial** → **present** | **E** |
| `@` mentions | `MentionMenu.kt` official `@path` / `@"path"` / `@[title](dsh-session:…)` | same tokens + chip row + mention panel | **partial** → **present** | **E** |
| `/` commands | `CommandPopupSheet` `commands.list/execute` | `CommandSheet` + builtin `goal/plan/feedback/compact/permission/export` (`session.export` share sheet) | **missing** → **present** | **E** |
| Header ⋯ export / session feedback | `MoreSheet` `session.export` + `sessionFeedback.record` | same; export always listed, feedback ops-gated | **missing** → **present** | **G** |
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
| Tokyo Night PTY emulator | `TerminalEmulator.kt` | `AnsiTerminal` | **present** | **B** |
| Default fg/bg follow appearance | canvas tokens | `T.ink` / `T.bg`; Tokyo Night ANSI palette unchanged | **present** | **D** |
| Top shortcut row; Tab → `\t` | `TerminalView.kt` | same two-row English keycaps; Tab sends `\t` | **present** | **B** |
| Tap cursor / long-press select | `TerminalView.kt` | tap / long-press + drag | **present** | **B** |
| Resume saved PTY identities | `Pocket.kt` | `TerminalStore` + `selectTerminal` | **present** | **B** |

## 4. Files / workspace

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| `files.list/read` listing | `FilesPanel.kt` | `FilesPanel` (shown when `files.list` advertised) | **present** | **B** |
| Preview (md / text / image / PDF / Office / XLS) | `FilePreview.kt` + `OfficePreview.kt` + `WorkbookPreview.kt` | same kinds; PDFKit pages; `office.*` lease → PDF; XLS FortuneSheet over `dsh-workbook-preview://` | **partial** → **present** | **B** / **F** / **H** |
| Workspace entities / tree | `WorkspaceNavigation.kt` | entity groups / tree / rename / delete / new session | **present** | **B** |
| Add workspace browse | `WorkspaceDirectoryPicker.kt` | `WorkspaceDirectorySheet` when `workspace.create` | **present** | **B** |
| Session search | `sessions.search` + local title/path merge | same debounce 250ms + snippets; unbounded while searching | **missing** → **present** | **G** |
| Unarchive / archived not openable | restore dialog; `workspace.unarchiveSession` | same; archived rows do not `openSession` | **missing** → **present** | **G** |
| Workspace / session reorder | Host `insertBefore` / `insertSessionBefore` (Android UI is local Manual) | drag/drop calls Host ops when advertised; Manual order still local | **missing** → **present** | **G** |
| NavigationPolicy | `workspaceDisplayTitle` / `visibleDrawerSession` / `reconcileSessionOrder` / `workspaceBranches` / `archiveActivityDescription` | same Swift ports in `Workspace.swift` | **partial** → **present** | **G** |
| Open-in-desktop-editor | desktop only | — | **hide** | — |
| WorkspaceChanges cards | `WorkspaceChanges.kt` | chat cards + review sheet (`workspaceChanges.summary/diff`); attached to last answer when `showCodeWorkView` | **missing** → **present** | **F** |
| File tree live updates | `files.follow` + `observeWorkspaceDirectory` | same; watch-unsupported falls back to list | **partial** → **present** | **F** / **H** |
| Browser | `BrowserPanel.kt` + `BrowserTabs.kt` HTTP(S)-only, addresses-only checkpoints | Start panel (no ops gate); multi-tab `{selected, pages:[{id,url,title}]}` | **missing** → **present** | **F** / **H** |
| Session Inspector | `SessionInspectorPanel` raw/grouped + pick | Start panel (no ops gate); pick overlay returns to inspector | **missing** → **present** | **F** |

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
| General: fonts, transcript, collapse, busy, performance, log upload, link opening | `GeneralHostSettings.kt` Host-mirrored; appearance override when offline | same; `HostSettings` writes `ui-theme` / `locale`; appearance in-memory when Host offline | **present** | **D** / **H** |
| Offline gray-out (no unofficial banner) | Android `SettingsScaffold` invents 「远程主机未连接，需连接的操作暂不可用」; desktop has no such chrome | **desktop-first:** no top banner / no extra copy; status 「未连接」; Models / 内置插件 / Agent 预设 / drawer 插件·自动化 gray + unclickable; `lastOps` keeps rows | **missing** → **present** | **H** |
| Qoder CN card | `QoderConnectionCard.kt` last in `llm-qoder` | same PAT write-only + revision fence | **missing** → **present** | **H** |
| Models intro | `L.modelsIntro()` | same official sentence | **partial** → **present** | **H** |
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
| Session search / feedback / attachment / restore / presets / NSD / notify / reconnect | drawer + header ⋯ + connection | **G done** (`SessionSearch` / `SessionFeedback` / `SessionAttachment` / `PresetPolicy` / `LanDiscoveryPolicy` / `PairedDeviceStatus` / `ConnectionRestore` / `TaskNotify`) |

Existing iOS `DSHProtocol` now also covers permissions.get/set, queue.update, commands.list/execute, attachments.upload, userQuestions.answer, goals.get/edit/pause/resume/clear, references.files/sessions, session.export, session.attachment, sessions.search, sessionFeedback.record, workspace.unarchiveSession / insertBefore / insertSessionBefore, presets.list/read/settings, ui.close. Approval `accepted` is required (same as Android `Pocket.answer`).

---

## iOS entry rules (after a batch lands)

- Trajectory: session header / more menu — data is the current follow transcript (no extra Host op). Hidden when coding view is off.
- Terminal / files / jobs: expose when the matching op is in `hello.ops` (same as Android).
- Browser / Session Inspector: Start panel always (no ops gate), same as Android GuideBody.
- WorkspaceChanges: chat cards when `showCodeWorkView` and `workspaceChanges.summary` is advertised; diff sheet needs `workspaceChanges.diff`.
- Plugins: drawer when `plugins.list`; market enable when `plugins.setEnabled`; add when `plugins.install`; Settings 「内置插件」 when `plugins.inventory`. Do not embed a plugin WebView (desktop market has none).
- Schedule: **drawer only** (desktop sidebar). Do not add a Settings row.
- Permissions / models / commands / attachments / queue / goals / presets / session search / export / session feedback / unarchive / Host reorder: expose when the matching op is advertised.
- Appearance / fonts / language write to Host when the namespace is writable. Offline appearance is an in-memory override only.
- Do not show a row that opens an empty TODO page.
- Do not invent banners, buttons, or copy that desktop does not have. Android `SettingsScaffold` / schedule offline banners are **not** official desktop chrome — iOS omits them.

## Batch H 对照清单（Android `729ef2e`）

| 模块 | iOS | 对照的 Android 源码 | 对齐点 |
| --- | --- | --- | --- |
| 模型选择 | `ModelPicker.swift`、`ModelsSettingsView.swift`、`QoderConnectionCard.swift`、`ModelPickerPolicy.swift` | `ModelPicker.kt`、`ModelPickerPolicy.kt`、`ModelsSettingsScreen.kt`、`QoderConnectionCard.kt`、`ModelSettingsForms.kt` | 两级 picker；`DeepSeek 账号` / `DeepSeek Account`；展开卡显示 route slug；官方 intro / 只读句；提供商「由主机配置管理」；Qoder CN PAT 只写 + revision fence，排在提供商列表之后 |
| 插件控件 | `PluginsScreen.swift`、`PluginInventoryView.swift`、`PluginPolicy.swift` | `PluginsScreen.kt`、`PluginInventory.kt`、desktop `ui-plugin-manager` | 官方市场「官方 N」/已安装 + 实验性徽章 + 刷新；添加菜单仅「第三方 / 创造模式」；详情配置组件；不嵌入 WebView；内置插件分组；离线不加顶栏横幅 |
| 命令菜单 | `ChatDock.swift` `CommandSheet`、`ChatView.swift` `commandLeading`、`CommandPolicy.swift` | `Sheets.kt` `CommandPopupSheet` / `commandMenuRows`、`Chat.kt` Plus/`/` 接线、`CommandMenuPolicyTest.kt` | `+` 与 `/` 共用同一菜单；空白 composer vs slash 前缀；`file`/`model` 客户端注入；无额外 plus 图片快捷入口；附件走系统文件选择（图片走 image、其余 upload） |
| 工作区更新 | `FilesPanel.swift`、`WorkspaceDirectory.swift` | `FilesPanel.kt`、`WorkspaceDirectorySubscription.kt`、`WorkspaceDirectorySubscriptionTest.kt` | `files.follow` + `observeWorkspaceDirectory`；watch-unsupported 回退 list；同路径刷新不清空列表；前台（`scenePhase.active` / Android `RESUMED`）才订阅 |
| 浏览器标签 | `BrowserPanel.swift`、`BrowserTabs.swift` | `BrowserPanel.kt`、`BrowserTabs.kt`、`BrowserTabsTest.kt` | 多标签、关闭/新建、地址栏后退前进刷新外开；checkpoint 仅 `{selected,pages:[{id,url,title}]}`；不恢复 WebView / 不自动联网 |
| Office / PDF / XLS | `FilePreview.swift`、`WorkbookPreview.swift`、`OfficePreview.swift`、`WorkbookPreview.swift`（protocol） | `FilePreview.kt`、`OfficePreview.kt`、`WorkbookPreview.kt` | `office.render/read/release` 租约；PDFKit 分页；缺失字体 popover 官方文案；XLS/XLSX FortuneSheet，资源走 `dsh-workbook-preview://` ↔ `https://workbook-preview.invalid`；错误原因仅官方句 |
| 离线灰态 | `SettingsView.swift`、`SessionDrawer.swift`、`ScheduleScreen.swift`、`PluginsScreen.swift` | desktop settings/plugin-manager (no banner); Android `SettingsPages.kt` `SettingsScaffold` banner is **not** copied | 状态处「未连接」（连接行 / 抽屉无 profile 名 / 空会话）；不设顶部横幅、不设说明文案；模型/内置插件/预设/抽屉插件·自动化灰显不可点；离线仍用 `lastOps` 显示入口；归档会话 rename/fork 有 ops 即显示，`enabled=online`（不因 archived 隐藏） |
| JSON 树 | `TrajectoryJsonView.swift`、`TrajectoryJson.swift` | `TrajectoryJson.kt`、`TrajectoryJsonTest.kt` | 展开/收起、可选中文本、点击复制 / 长按多模式；成功文案「复制成功」 |

## Deferred / hide leftovers

- Account / shortcuts / open config file / open-in-desktop-editor: desktop-local — **hide**.
- Keyboard shortcut settings: desktop-local — **hide**.
- Android ForegroundService persistent “已连接” notification: iOS has no equivalent; `ConnectionKeeper` uses `beginBackgroundTask` + ping, then `BGAppRefreshTask` `dev.dsh.pocket.ios.refresh`. The WS is not guaranteed after the system expires those windows.
- Nearby Wi-Fi (`NEARBY_WIFI_DEVICES`) is Android 13+; iOS uses Local Network + Bonjour (`NSLocalNetworkUsageDescription`).
- iOS CodePreview has no Meslo font file (CSS falls back to monospace). WKWebView cannot intercept `https://`; assets load over `dsh-code-preview://` mapped to the same Android `https://code-preview.invalid` policy used in tests.
- Embedded browser cannot intercept every subresource the way Android `shouldInterceptRequest` does; main-frame / navigation policy still uses `BrowserPolicy`. WKWebView cannot intercept `https://` for FortuneSheet; workbook assets load over `dsh-workbook-preview://` mapped to Android `https://workbook-preview.invalid`.
- Foundation `JSONSerialization` object key order is not insertion-stable; protocol tests compare parsed `JSONValue`, not pretty strings.
