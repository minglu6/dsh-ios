# iOS ↔ Android / desktop parity gap

Phone is a controller. Layout may change for a narrow portrait screen. Features, copy, icons, colors, states, and interactions follow the official desktop UI (`@deepseek-ai/dsh@0.2.1-alpha.2`, git `d743267`) as already ported by [dsh-android](https://github.com/minglu6/dsh-android) `main` @ `03ebc36`.

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
| D | Plugin manager + schedule + remaining official settings + chat polish | this PR |
| E / F / G | later surfaces (see Deferred) | queued |

---

## File map

| Surface | Official package | Android | iOS now |
| --- | --- | --- | --- |
| Transcript fold | `ui-chat` / `ui-conversation` | `protocol/Transcript.kt`, `Chat.kt`, `ChatProcess.kt` | `protocol/…/Transcript.swift`, `ChatProcess.swift`, `Features/Chat/ChatView.swift` |
| Message actions | `ui-chat` `MessageIconActions` | `Chat.kt` `MessageActions` | `ChatView` `MessageActions` (copy / like / dislike / branch) |
| Trajectory | `ui-trajectory` | `Trajectory.kt` + Detail/Inspector/Request/Locales; `protocol/TrajectoryTimeline.kt` | `Features/Trajectory/` + `protocol/Trajectory.swift` (request inspector leftover) |
| Terminal | Host `terminalController` | `TerminalPanel.kt`, `TerminalView.kt`, `TerminalEmulator.kt` | `Features/Terminal/` + `protocol/TerminalEmulator.swift`; default fg/bg follow appearance, Tokyo Night ANSI unchanged |
| Files | `workspaceFiles` | `FilesPanel.kt` | `Features/Files/` + workspace tree / browse |
| Jobs | `job-controller` | `JobsAction.kt`, jobs follow in `Pocket.kt` | header chip + `JobsPanel` (`jobs.list` / `follow` / `kill`) |
| Plugins | `ui-plugin-manager`, `ui-settings-plugins` | `PluginsScreen.kt`, `PluginInventory.kt` | `Features/Plugins/` + `PluginPolicy.swift` (install/uninstall/cancel/wait, registries, inspect, settingsDescribe/Mutate, PluginArtwork, inventory, HostUi) |
| Schedule | `ui-schedule` (sidebar, not settings) | `ScheduleScreen.kt`; drawer row | `Features/Schedule/ScheduleScreen.swift` + `SchedulePolicy.swift`; drawer only |
| Completion unread | `StateDot` `done` | `CompletionReminders.kt`, `Pocket.kt` `completion.view` | `CompletionReminders` epoch+revision |
| Settings general | `ui-settings-general` | `Screens.kt` `GeneralSettingsScreen`, `HostSettings.kt` | fonts / collapse / performance / permission / session log / link opening; **appearance + fonts stay local** (do not write the remote host) |
| Settings models | `ui-settings-models` | `ModelsSettingsScreen.kt` | `ModelsSettingsView` provider editor + `credentials.*` |
| Connections | pocket `settings.section` `pocket` | `Screens.kt` connections | pairing / diagnostics copy |
| Workspace drawer | `ui-workspace` | `WorkspaceNavigation.kt`, `Screens.kt` | entity groups / tree / rename / delete / add-workspace browse |
| Markdown | `ui-chat` primitives | `Markdown.kt` | `protocol/Markdown.swift` + `Features/Chat/MarkdownView.swift` |
| Host UI | pocket `ui.open` | `HostUi.kt` | `protocol/HostUi.swift` + `HostUiView` (ticket POST, 303, HttpOnly host-only cookie; never put bearer/ticket in the WebView URL) |

---

## 1. Chat

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| User bubble, pending echo | `Chat.kt` | `MessageRow` `.user` | **present** | — |
| Assistant text stream | follow reducer | `.text` live/committed | **present** | — |
| Reasoning disclosure | Think icon + preview | official Think / 思考 + preview; Markdown body | **partial** → **present** | **D** |
| Tool row → inspector | `Chat.kt` tool card | `ToolProcessSummary` title/icon/receipt + inspect sheet | **partial** → **present** | **D** |
| Process group fold | `ChatProcess.kt` | `foldChatItems` / `visibleChatRows` + `ProcessGroupView` | **missing** → **present** | **D** |
| Notices (stopped / max-tokens / account) | reducer + official `message.*` | reducer emits; `.notice` / retry / turnFailure | **partial** | A leftover |
| Deliverables | `Item.Deliverable` | tap opens workspace file preview | **present** | **B** |
| Markdown / code block / tables | `Markdown.kt` | AST + GFM tables / code / file chips | **partial** → **present** | **D** |
| Copy / like / dislike / branch | `MessageActions` + `FeedbackCategory` + `feedback.set` + `sessions.fork` | copy / like / dislike / branch; `canFork` needs `firstPrompt == nil` | **present** | **A** |
| Turn usage pill | `ComposerStats.kt` `TurnUsageAction` | missing (needs `TurnTokenUsage` + `PerformanceUsage.Detailed`) | **missing** | **E** leftover |
| Composer queue / steer | busyEnter | `busySend` | **present** | — |
| `@` mentions | `MentionMenu.kt` | `ComposerView` mention panel | **partial** | **E** leftover |
| No “scroll to bottom” FAB | `followBottom` | auto-scroll only | **present** | — |
| Approvals | `Chat.kt` permission sheet | inline allow/reject | **partial** | **E** leftover |

## 2. Trajectory

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Build ledger from items | `Trajectory.kt` `buildTrajectory` | `Trajectory.swift` `buildTrajectory` | **present** | **A** |
| 7 cell kinds | system / user / context / compacted / message / tool / subtool | same kinds + reducer `system/message` / compaction | **present** | **A** |
| Compact ledger (事件 + 内容) | `Trajectory.kt` | `TrajRowView` | **present** | **A** |
| Toolbar 时长 / 轮次 / 调用 + search | `TrajectoryToolbar` port | same chips + search field | **present** | **A** |
| Swimlane overview | `TrajectoryTimeline.kt` | `TrajectoryTimeline.swift` + `SwimlaneChart` | **present** | **A** |
| Inspector tabs 概述 / 参数 / 结果 / Schema / 计时 | `TrajectoryDetail.kt` | `TrajectoryDetailSheet` | **present** | **A** |
| Request inspector | `TrajectoryRequest.kt` | cell inspector only | **missing** | leftover (see Deferred) |
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
| Preview (md / text / image) | `FilePreview.kt` | md / text / image; PDF/Office stay unsupported | **present** | **B** |
| Workspace entities / tree | `WorkspaceNavigation.kt` | entity groups / tree / rename / delete / new session | **present** | **B** |
| Add workspace browse | `WorkspaceDirectoryPicker.kt` | `WorkspaceDirectorySheet` when `workspace.create` | **present** | **B** |
| Open-in-desktop-editor | desktop only | — | **hide** | — |
| WorkspaceChanges cards | `WorkspaceChanges.kt` | not in chat | **missing** | leftover (see Deferred) |

## 5. Jobs + unread

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Header jobs chip | `JobsAction.kt` | tabs-row chip (`jobs.list` advertised + non-empty / failed) | **present** | **C** |
| Failed refresh → 「任务状态不可用」 (not 0) | `JobsAction.kt:62-64` | same copy, stale running count discarded | **present** | **C** |
| `jobs.list` / `follow` / `kill` | `Pocket.kt` | `PocketClient` + `JobsPanel`; list+live follow share one roster | **present** | **C** |
| Unread green dot | `CompletionReminders` epoch+revision | epoch+revision; leading slot only | **present** | **C** |
| `completion.view` failure does not drop WS | `Pocket.kt` | `syncCompletionView` retry | **present** | — |
| `follow` without `maxMessages` | `PocketFollowTest` | `FollowRequest.args` | **present** | — |

## 6. Plugins + schedule + settings

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Drawer 插件 (`plugins.list`) | `Screens.kt` | shown if op advertised | **present** | **D** |
| Plugin manager (install / enable / inspect / uninstall / cancel / wait) | `PluginsScreen.kt` | `PluginsScreen` | **missing** → **present** | **D** |
| Registries + inspect | `PluginsScreen.kt` | `plugins.registries` / `plugins.inspect` | **missing** → **present** | **D** |
| Built-in plugin slots from Host describe | audit P1; no APK whitelist | `plugins.settingsDescribe` namespaces (not an officialConfigurations whitelist) | **missing** → **present** | **D** |
| PluginArtwork (SF Symbol kinds + sanitized SVG) | `PluginArtwork.kt` | `PluginArtwork.swift` | **missing** → **present** | **D** |
| Settings 「内置插件」 inventory | `PluginInventory.kt` | `PluginInventoryView` when `plugins.inventory` | **partial** → **present** | **D** |
| HostUi (`ui.open`) | `HostUi.kt` | ticket exchange + WKWebView; gated by `hello.ops` | **missing** → **present** | **D** |
| Drawer 自动化 (not a settings section) | `ScheduleScreen.kt` | drawer only; Settings 自动化 row removed | **partial** → **present** | **D** |
| Schedule catalog / edit / history | `ScheduleScreen.kt` | CAS update + delete + history; New → chat | **missing** → **present** | **D** |
| Agent presets | `AgentPresetSettingsScreen.kt` | hidden (no stub) | **missing** | **E** leftover |
| General: fonts, transcript, collapse, busy, performance, log upload, link opening | `GeneralSettingsScreen` | present; appearance/fonts **local only** | **partial** → **present** | **D** |
| Models provider editor + keys | `ModelsSettingsScreen.kt` | `models.providers*` + `credentials.*` | **partial** → **present** | **D** |
| 「移动端」 group / 代码自动换行 | Android still has these (audit S2/S5) | wrap is local; no extra mobile group copied | **present** | — |
| Version only on General | audit S3 | General only | **present** | — |
| Account / shortcuts / open config file | desktop-local | — | **hide** | — |
| Phone connection + 复制诊断报告 | connections | connections overflow | **present** | — |

---

## Protocol extras still on Android only

Port as the matching batch needs them (same JSON, no second protocol):

| Android `app/core/protocol` | Used by | Batch |
| --- | --- | --- |
| `TrajectoryTimeline.kt` | Trajectory swimlane | **A done** (`TrajectoryTimeline.swift`) |
| `Transcript.kt` extra items (`System`, `Compacted`, `Retry`, `TurnFailure`, `Changes`; System/Compacted folded, Retry/TurnFailure rendered, Changes still unused in chat) | Chat + trajectory | A / D; Changes → leftover |
| `TurnTokenUsage.kt` | Inspector + usage | **E** leftover |
| `WorkspaceChanges.kt` | Changed-file cards | leftover (see Deferred) |
| `PermissionModels.kt` | Permission pickers | **D done** (`PermissionModels.swift`) |
| `HostUi.kt` | Plugin/settings slots | **D done** (`HostUi.swift`) |

Existing iOS `DSHProtocol` already covers hello/pair, follow/history, prompt/cancel, models.catalog/select, models.providers*/settingsMutate/discover, approvals, workspace pin/archive, plugins.list / setEnabled / inventory / install / inspect / registries / uninstall / cancelInstall / waitForInstall / settingsDescribe / settingsMutate, schedule.catalog / create / update / delete / history, credentials.describe / set / unset, ui.open, permissions.catalog, jobs.list / follow / kill, completion.state / view.

---

## iOS entry rules (after a batch lands)

- Trajectory: session header / more menu — data is the current follow transcript (no extra Host op).
- Terminal / files / jobs: expose when the matching op is in `hello.ops` (same as Android).
- Plugins: drawer when `plugins.list`; Settings 「内置插件」 when `plugins.inventory`; HostUi when `ui.open`.
- Schedule: **drawer only** (desktop sidebar). Do not add a Settings row.
- Appearance and fonts stay on the phone; they must not be written to the remote host.
- Do not show a row that opens an empty TODO page.

## Deferred

- Batches **E / F / G**.
- Trajectory **request inspector**.
- Chat **WorkspaceChanges** cards (can be a follow-up PR).
- Turn usage pill, `@` mention polish, approval sheet chrome, Agent presets.
