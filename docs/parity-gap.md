# iOS ↔ Android / desktop parity gap

Phone is a controller. Layout may change for a narrow portrait screen. Features, copy, icons, colors, states, and interactions follow the official desktop UI (`@deepseek-ai/dsh@0.2.1-alpha.2`, git `d743267`) as already ported by [dsh-android](https://github.com/minglu6/dsh-android) `main`.

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
| E | Permissions + ModelPicker + questions/commands/attachments/queue/goals + Todo/stats/retry + mention/approval/HostUi close | this PR |
| F / G | later surfaces (see Deferred) | queued |

---

## File map

| Surface | Official package | Android | iOS now |
| --- | --- | --- | --- |
| Transcript fold | `ui-chat` / `ui-conversation` | `protocol/Transcript.kt`, `Chat.kt`, `ChatProcess.kt` | `protocol/…/Transcript.swift`, `ChatProcess.swift`, `Features/Chat/ChatView.swift` |
| Message actions | `ui-chat` `MessageIconActions` | `Chat.kt` `MessageActions` | `ChatView` `MessageActions` (copy / like / dislike / branch + turn usage) |
| Trajectory | `ui-trajectory` | `Trajectory.kt` + Detail/Inspector/Request/Locales; `protocol/TrajectoryTimeline.kt` | `Features/Trajectory/` + `protocol/Trajectory.swift` (request inspector leftover) |
| Terminal | Host `terminalController` | `TerminalPanel.kt`, `TerminalView.kt`, `TerminalEmulator.kt` | `Features/Terminal/` + `protocol/TerminalEmulator.swift`; default fg/bg follow appearance, Tokyo Night ANSI unchanged |
| Files | `workspaceFiles` | `FilesPanel.kt` | `Features/Files/` + workspace tree / browse |
| Jobs | `job-controller` | `JobsAction.kt`, jobs follow in `Pocket.kt` | header chip + `JobsPanel` (`jobs.list` / `follow` / `kill`) |
| Plugins | `ui-plugin-manager`, `ui-settings-plugins` | `PluginsScreen.kt`, `PluginInventory.kt` | `Features/Plugins/` + `PluginPolicy.swift` |
| Schedule | `ui-schedule` (sidebar, not settings) | `ScheduleScreen.kt`; drawer row | `Features/Schedule/ScheduleScreen.swift`; drawer only |
| Permissions | `ui-permission` | `PermissionUi.kt` `permissions.catalog/get/set` + risk sheet | `PermissionUi.swift` + session picker + Settings defaults + `danger-full-access`/`auto` confirm |
| Model picker | composer model menu | `ModelPicker.kt` + effort pane | `ModelPicker.swift` two-level picker; switching models clears effort |
| Composer dock | `ui-chat` | UserQ / Approval / Todo / Goal / Queue / Composer / Stats | same stack in `ChatView` + `ChatDock.swift` |
| Host UI | pocket `ui.open` | `HostUiScreen.kt` (`ui.close` on dismiss) | `HostUiView` ticket POST + `ui.close` on dismiss |
| Markdown | `ui-chat` primitives | `Markdown.kt` | `protocol/Markdown.swift` + `Features/Chat/MarkdownView.swift` |

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
| Plugin manager (install / enable / inspect / uninstall / cancel / wait) | `PluginsScreen.kt` | `PluginsScreen` | **present** | **D** |
| Registries + inspect | `PluginsScreen.kt` | `plugins.registries` / `plugins.inspect` | **present** | **D** |
| Built-in plugin slots from Host describe | audit P1; no APK whitelist | `plugins.settingsDescribe` namespaces | **present** | **D** |
| PluginArtwork (SF Symbol kinds + sanitized SVG) | `PluginArtwork.kt` | `PluginArtwork.swift` | **present** | **D** |
| Settings 「内置插件」 inventory | `PluginInventory.kt` | `PluginInventoryView` when `plugins.inventory` | **present** | **D** |
| HostUi (`ui.open`) | `HostUi.kt` + `ui.close` on dismiss | ticket exchange + WKWebView + `ui.close` | **partial** → **present** | **E** |
| Drawer 自动化 (not a settings section) | `ScheduleScreen.kt` | drawer only; Settings 自动化 row removed | **present** | **D** |
| Schedule catalog / edit / history | `ScheduleScreen.kt` | CAS update + delete + history; New → chat | **present** | **D** |
| Agent presets | `AgentPresetSettingsScreen.kt` | hidden (no stub) | **missing** | leftover (see Deferred) |
| General: fonts, transcript, collapse, busy, performance, log upload, link opening | `GeneralSettingsScreen` | present; appearance/fonts **local only** | **present** | **D** |
| Permission defaults | `PermissionPickerSheet(forDefaults)` + risk | same; `auto` cannot be a default | **partial** → **present** | **E** |
| Models provider editor + keys | `ModelsSettingsScreen.kt` | `models.providers*` + `credentials.*` | **present** | **D** |
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
| `Transcript.kt` extra items (`System`, `Compacted`, `Retry`, `TurnFailure`, `Changes`; System/Compacted folded, Retry/TurnFailure rendered, Changes still unused in chat) | Chat + trajectory | A / D / **E**; Changes → leftover |
| `TurnTokenUsage.kt` | Inspector + usage | **E done** (`TurnTokenUsage.swift`) |
| `ComposerMetrics.kt` | Composer statistics | **E done** (`ComposerMetrics.swift`) |
| `WorkspaceChanges.kt` | Changed-file cards | leftover (see Deferred) |
| `PermissionModels.kt` | Permission pickers | **D done** (`PermissionModels.swift`) |
| `HostUi.kt` | Plugin/settings slots | **D done** (`HostUi.swift`); **E** adds `ui.close` |

Existing iOS `DSHProtocol` now also covers permissions.get/set, queue.update, commands.list/execute, attachments.upload, userQuestions.answer, goals.get/edit/pause/resume/clear, references.files/sessions, session.export, ui.close. Approval `accepted` is required (same as Android `Pocket.answer`).

---

## iOS entry rules (after a batch lands)

- Trajectory: session header / more menu — data is the current follow transcript (no extra Host op).
- Terminal / files / jobs: expose when the matching op is in `hello.ops` (same as Android).
- Plugins: drawer when `plugins.list`; Settings 「内置插件」 when `plugins.inventory`; HostUi when `ui.open`.
- Schedule: **drawer only** (desktop sidebar). Do not add a Settings row.
- Permissions / models / commands / attachments / queue / goals: expose when the matching op is advertised.
- Appearance and fonts stay on the phone; they must not be written to the remote host.
- Do not show a row that opens an empty TODO page.

## Deferred

- Batches **F / G**.
- Trajectory **request inspector**.
- Chat **WorkspaceChanges** cards.
- **Agent presets**.
- Session Inspector / browser surfaces.
