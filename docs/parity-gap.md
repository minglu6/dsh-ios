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
| A | Trajectory ledger + inspector; chat message actions (copy / like / dislike / branch) | next (#2) → this PR |
| B | Host PTY terminal + workspace file tree | queued |
| C | Live jobs panel + completion unread green-dot sync | queued |
| D | Plugin manager + schedule + remaining official settings | queued |

---

## File map

| Surface | Official package | Android | iOS now |
| --- | --- | --- | --- |
| Transcript fold | `ui-chat` / `ui-conversation` | `protocol/Transcript.kt`, `Chat.kt`, `ChatProcess.kt` | `protocol/…/Transcript.swift`, `Features/Chat/ChatView.swift` |
| Message actions | `ui-chat` `MessageIconActions` | `Chat.kt` `MessageActions` | copy-only on assistant text → `ChatView` `MessageActions` (copy / like / dislike / branch) |
| Trajectory | `ui-trajectory` | `Trajectory.kt` + Detail/Inspector/Request/Locales; `protocol/TrajectoryTimeline.kt` | hidden; no builder → `Features/Trajectory/` + `protocol/Trajectory.swift` |
| Terminal | Host `terminalController` | `TerminalPanel.kt`, `TerminalView.kt`, `TerminalEmulator.kt` | hidden |
| Files | `workspaceFiles` | `FilesPanel.kt` | hidden |
| Jobs | `job-controller` | `JobsAction.kt`, jobs follow in `Pocket.kt` | hidden |
| Plugins | `ui-plugin-manager`, `ui-settings-plugins` | `PluginsScreen.kt`, `PluginInventory.kt` | thin `plugins.list` when advertised |
| Schedule | `ui-schedule` (sidebar, not settings) | `ScheduleScreen.kt`; drawer row | thin list when advertised |
| Completion unread | `StateDot` `done` | `CompletionReminders.kt`, `Pocket.kt` `completion.view` | `unreadIds` set, no epoch/revision |
| Settings general | `ui-settings-general` | `Screens.kt` `GeneralSettingsScreen`, `HostSettings.kt` | appearance + language + version only |
| Settings models | `ui-settings-models` | `ModelsSettingsScreen.kt` | catalog list, no provider editor |
| Connections | pocket `settings.section` `pocket` | `Screens.kt` connections | pairing / diagnostics copy |
| Workspace drawer | `ui-workspace` | `WorkspaceNavigation.kt`, `Screens.kt` | grouping / pin / fork / archive; no browse add-workspace |
| Markdown | `ui-chat` primitives | `Markdown.kt` | `Text(...)` only |

---

## 1. Chat

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| User bubble, pending echo | `Chat.kt` | `MessageRow` `.user` | **present** | — |
| Assistant text stream | follow reducer | `.text` live/committed | **present** | — |
| Reasoning disclosure | Think icon + preview | `DisclosureGroup` + `L.reasoning()` | **partial** | A / D |
| Tool row → inspector | `Chat.kt` tool card | name / args / result snippet | **partial** | A / D |
| Process group fold | `ChatProcess.kt` | missing | **missing** | D |
| Notices (stopped / max-tokens / account) | reducer + official `message.*` | reducer emits; plain `.notice` | **partial** | A |
| Deliverables | `Item.Deliverable` | row exists, no file open | **partial** | B |
| Markdown / code block / tables | `Markdown.kt` | raw `Text` | **partial** | D |
| Copy / like / dislike / branch | `MessageActions` + `FeedbackCategory` + `feedback.set` + `sessions.fork` | copy / like / dislike (category+note sheet; retap clears) / branch; `canFork` needs `firstPrompt == nil` | **missing** → **present** | **A** |
| Turn usage pill | `ComposerStats.kt` `TurnUsageAction` | missing (needs `TurnTokenUsage` + `PerformanceUsage.Detailed`) | **missing** | D |
| Composer queue / steer | busyEnter | `busySend` | **present** | — |
| `@` mentions | `MentionMenu.kt` | `ComposerView` mention panel | **partial** | D |
| No “scroll to bottom” FAB | `followBottom` | auto-scroll only | **present** | — |
| Approvals | `Chat.kt` permission sheet | inline allow/reject | **partial** | D |

## 2. Trajectory

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Build ledger from items | `Trajectory.kt` `buildTrajectory` | none → `Trajectory.swift` `buildTrajectory` | **missing** → **present** | **A** |
| 7 cell kinds | system / user / context / compacted / message / tool / subtool | none → same kinds + reducer `system/message` / compaction | **missing** → **present** | **A** |
| Compact ledger (事件 + 内容) | `Trajectory.kt` | none → `TrajRowView` | **missing** → **present** | **A** |
| Toolbar 时长 / 轮次 / 调用 + search | `TrajectoryToolbar` port | none → same chips + search field | **missing** → **present** | **A** |
| Swimlane overview | `TrajectoryTimeline.kt` | none → `TrajectoryTimeline.swift` + `SwimlaneChart` | **missing** → **present** | **A** |
| Inspector tabs 概述 / 参数 / 结果 / Schema / 计时 | `TrajectoryDetail.kt` | none → `TrajectoryDetailSheet` | **missing** → **present** | **A** |
| Request inspector | `TrajectoryRequest.kt` | none → not yet (cell inspector only) | **missing** | **A** leftover |
| Official locales | `TrajectoryLocales.kt` ← `ui-trajectory` `locales.ts` | none → `TrajL` | **missing** → **present** | **A** |
| Chat / 轨迹 entry | session header + more sheet | hidden → session header tabs 对话 / 轨迹 | **missing** → **present** | **A** |

## 3. Terminal

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| `terminal.list/create/follow/write/resize/close` | `PocketClient` + `TerminalPanel.kt` | client stubs only | **missing** | **B** |
| Tokyo Night PTY emulator | `TerminalEmulator.kt` | none | **missing** | **B** |
| Top shortcut row; Tab → `\t` | `TerminalView.kt` | none | **missing** | **B** |
| Tap cursor / long-press select | `TerminalView.kt` | none | **missing** | **B** |
| Resume saved PTY identities | `Pocket.kt` | none | **missing** | **B** |

## 4. Files / workspace

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| `files.list/read` listing | `FilesPanel.kt` | none | **missing** | **B** |
| Preview (md / text / image) | `FilePreview.kt` | none | **missing** | **B** |
| Workspace entities / tree | `WorkspaceNavigation.kt` | flat-ish groups | **partial** | **B** |
| Add workspace browse | `WorkspaceDirectoryPicker.kt` | none | **missing** | **B** |
| Open-in-desktop-editor | desktop only | — | **hide** | — |

## 5. Jobs + unread

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Header jobs chip | `JobsAction.kt` | hidden | **missing** | **C** |
| Failed refresh → 「任务状态不可用」 (not 0) | `JobsAction.kt:62-64` | none | **missing** | **C** |
| `jobs.list` / `follow` / `kill` | `Pocket.kt` | none | **missing** | **C** |
| Unread green dot | `CompletionReminders` epoch+revision | `unreadIds` overwrite | **partial** | **C** |
| `completion.view` failure does not drop WS | `Pocket.kt` | `syncCompletionView` retry | **present** | — |
| `follow` without `maxMessages` | `PocketFollowTest` | `FollowRequest.args` | **present** | — |

## 6. Plugins + schedule + settings

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Drawer 插件 (`plugins.list`) | `Screens.kt` | shown if op advertised | **partial** | **D** |
| Plugin manager (install / enable / inspect) | `PluginsScreen.kt` | name + enabled text | **missing** | **D** |
| Built-in plugin slots from Host describe | audit P1; no APK whitelist | none | **missing** | **D** |
| Settings 「内置插件」 inventory | `PluginInventory.kt` | same thin list | **partial** | **D** |
| Drawer 自动化 (not a settings section) | `ScheduleScreen.kt` | settings + drawer if advertised | **partial** | **D** |
| Schedule catalog / edit / history | `ScheduleScreen.kt` | list only | **missing** | **D** |
| Agent presets | `AgentPresetSettingsScreen.kt` | hidden (no stub) | **missing** | **D** |
| General: fonts, transcript, collapse, busy, performance, log upload | `GeneralSettingsScreen` | appearance / language / version | **partial** | **D** |
| Models provider editor + keys | `ModelsSettingsScreen.kt` | catalog read-only | **partial** | **D** |
| 「移动端」 group / 代码自动换行 | Android still has these (audit S2/S5) | **not copied** | **present** | — |
| Version only on General | audit S3 | General only | **present** | — |
| Account / shortcuts / open config file | desktop-local | — | **hide** | — |
| Phone connection + 复制诊断报告 | connections | connections overflow | **present** | — |

---

## Protocol extras still on Android only

Port as the matching batch needs them (same JSON, no second protocol):

| Android `app/core/protocol` | Used by | Batch |
| --- | --- | --- |
| `TrajectoryTimeline.kt` | Trajectory swimlane | A → **A done** (`TrajectoryTimeline.swift`) |
| `Transcript.kt` extra items (`System`, `Compacted`, `Retry`, `TurnFailure`, `Changes`; System/Compacted folded, Retry/TurnFailure/Changes still unused in chat) | Chat + trajectory | A / D |
| `TurnTokenUsage.kt` | Inspector + usage | A / D |
| `WorkspaceChanges.kt` | Changed-file cards | B / D |
| `PermissionModels.kt` | Permission pickers | D |
| `HostUi.kt` | Plugin/settings slots | D |

Existing iOS `DSHProtocol` already covers hello/pair, follow/history, prompt/cancel, models.catalog/select, approvals, workspace pin/archive, `plugins.list` / `setEnabled`, `schedule.list`.

---

## iOS entry rules (after a batch lands)

- Trajectory: session header / more menu — data is the current follow transcript (no extra Host op).
- Terminal / files / jobs: expose when the matching op is in `hello.ops` (same as Android).
- Plugins: drawer when `plugins.list`; Settings 「内置插件」 when `plugins.inventory`.
- Schedule: **drawer only** (desktop sidebar). Do not add a Settings row.
- Do not show a row that opens an empty TODO page.
