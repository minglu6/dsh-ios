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
| R4 | collapseTiming 写回 Host；composer / 运行态 / 提问 / 任务输出 / 插件空态对齐桌面文案 | done (#22) |
| R5 | 文件树去 chevron + 自动刷新；排队附件缩略图/芯片；claimed `/goal` `/plan` 提示条；变更卡 pocket JSON `false` 旗标；斜杠技能组 + 键盘高度；无会话 landing | done (#23) |
| R6 | 鲸尾 shimmer；任务双击停止；Cmd/Ctrl+Enter；插件 (i)；侧栏浏览器；landing `/` 完整目录；变更卡 `.task` 锚点；技能按会话隔离；用量 popover；文件树滚动恢复 | done (#24) |
| R7 | 后台任务 chip 空 Group `.task`；「后台任务状态更新」；标题随 `sessions.list` / title projection 更新；权限 chip 锚定菜单；landing「标准模式」；composer 高度对齐桌面；去掉标题旁 spinner | done (#25) |
| R8 | waking 触发行；`/permission` popupSelect；composer 按内容测高；任务 popover；权限菜单固定顺序；统计单行；landing 权限写入新会话；停止为两次点按 | done (#26) |
| R9 | composer `sizeThatFits -> CGSize?`；任务 popover `arrowEdge: .top` 且无返回箭头；landing 风险文案跟桌面 hero；waking 与 `inbox.ts`/`message.ts` 对齐 | done (#27) |
| R10 | 已停止任务按 `JobView`/`exit` 投影；任务 popover 按内容收缩；底栏 `tok`；触发行灰卡；完全权限居中确认；浏览器关闭后保留对话位置；waking step 仅 `openStep` | done (#28) |
| R11 | 底栏 Token 用量贴 chip 的 popover；已结束任务 SIGTERM 整句；完全权限确认先收键盘 | done (#29) |
| R12 | Token 用量弹层在 chip 上方；表头图标 + 合计右对齐；本轮用量对齐 `message.turnUsage`；Think 展开保留图标；轨迹吞吐空窗用官方「不可用」；「已结束」一次点按展开 | done (#30) |
| R13 | 权限/模型 picker 对齐桌面 MenuSurface；去掉标题模型名与预设；landing AgentPresetSeat；连接入口回到抽屉脚；会话绿点/运行 spinner；Think 块对齐 ReasoningRow | done (#31) |
| R14 | 权限/模型 picker 弹层在 composer chip **上方**（同 Token 用量 `arrowEdge: .bottom`）；完全权限 / Auto review 确认不被键盘裁切 | done (#32) |
| R16 | landing 工作区 ghost chip + WorkspacePicker；计划 chip 进 composer modes 行；抽屉脚 footer.action 在 Settings 之上；+ aria / 插件添加 MenuSurface | done (#33) |
| R17 | 停止并归档确认；无工作区 landing 占位；停止 aria；会话「进行中」；搜索工作区上下文 | done (#34) |
| R18 | 会话统计 / 上下文弹层在 chip 上方；用量 pill 数据库图标；ContextMeter 环；归档不可打开文案；仅归档空态「查看其他会话」 | done (#35) |
| R19 | 离线空态 empty.none；landing 草稿附件；Ask 重开在工具行；subagent header crumbs；+ 按钮 selector 填充 | done (#36) |
| R20 | Ask 行「提问」+ waiting/pending；改动 diff.*；图片 image.failed；重试 scheduled；INTERRUPTED 失败 | done (#37) |
| R21 | 工具行 tool.title.* / preparing 保留标题；Goal `detail.goal.*` | done (#38) |
| R22 | Chat `CompactionItem` `message.compaction*` | done (#39) |
| R23 | ContextInjectionRow 工具变更行；TurnMaxTokensItem；signed-out TurnErrorItem | done (#40) |
| R24 | Host `command/run`+`command/done` 折叠；GenericCommandCard；CompactionCommandCard 运行中「正在压缩…」 | this PR |

---

## File map

| Surface | Official package | Android | iOS now |
| --- | --- | --- | --- |
| Transcript fold | `ui-chat` / `ui-conversation` | `protocol/Transcript.kt`, `Chat.kt`, `ChatProcess.kt` (Compacted still hidden; no CommandNode) | `protocol/…/Transcript.swift`, `ChatProcess.swift`, `Features/Chat/ChatView.swift` — chat shows desktop `CompactionItem` + `CommandNode` (`command/run`+`command/done`) + tool-change `ContextInjectionRow`; Android still folds Compacted |
| Message actions | `ui-chat` `MessageIconActions` | `Chat.kt` `MessageActions` | `ChatView` `MessageActions` (copy / like / dislike / share + turn usage; branch on the session row menu) |
| Trajectory | `ui-trajectory` | `Trajectory.kt` + Detail/Inspector/Request/Locales; `protocol/TrajectoryTimeline.kt` | `Features/Trajectory/` + `protocol/Trajectory.swift` / `TrajectoryRequest.swift` |
| WorkspaceChanges | Host `workspaceChanges.summary/diff` | `WorkspaceChanges.kt` | `Features/Chat/WorkspaceChanges.swift` + `protocol/WorkspaceChanges.swift` |
| Session Inspector | desktop session-inspector | `SessionInspectorPanel.kt` / Log / Model / Navigation | implemented, unexposed (desktop Start / ⋯ have no entry) |
| Browser | local HTTP(S) panel | `BrowserPanel.kt` + `BrowserPolicy.kt` | implemented, unexposed (desktop Start / ⋯ have no entry) |
| Code preview | shiki offline preview | `CodePreview.kt` | `Features/Files/CodePreview.swift` + `CodePreviewAssets/` |
| Terminal | Host `terminalController` | `TerminalPanel.kt`, `TerminalView.kt`, `TerminalEmulator.kt` | `Features/Terminal/` + `protocol/TerminalEmulator.swift`; bundled MesloLGL DZ Nerd Font + CoreText cascade; default fg/bg follow appearance; ANSI 16 = desktop xterm.js Tango (#20) |
| Files | `workspaceFiles` | `FilesPanel.kt` | `Features/Files/` + workspace tree / browse |
| Jobs | `job-controller` | `JobsAction.kt`, jobs follow in `Pocket.kt` | header chip 锚定 popover + `JobsPanel`（两次 Button 点按停止） |
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
| Reasoning disclosure | Think icon + preview | 标题恒为「思考」/Think；运行中 TextShimmer 而非 spinner；收起默认；展开时 chevron 替换 Think 图标；正文 compact 三级色 13/20；预览为首行（流式为已完成段首行） | **present** | **D** / **R12** / **R13** |
| Tool row → inspector | `Chat.kt` tool card | `ToolProcessSummary` title/icon/receipt + inspect sheet | **present** | **D** |
| Process group fold | `ChatProcess.kt` | `foldChatItems` / `visibleChatRows` + `ProcessGroupView`；已完成回合为「已完成，用时」+ 右侧 chevron（无左侧图标）；步骤组标题 body 14 + ` · ` 细节；成员与组头同列（无额外缩进）；运行中 shimmer | **present** | **D** / **R13** |
| Notices (stopped / max-tokens / account) | reducer + official `message.*` | reducer emits; `.notice` / `RetryRow`（active vs scheduled 文案） / `TurnFailureRow`（`INTERRUPTED`/`ACCOUNT_SIGNED_OUT`=`taskStopped`） / `TurnMaxTokensRow`（title+hint 一行） | **present** | **E** / **R20** / **R23** |
| Slash command cards | desktop `CommandNode` / `GenericCommandCard` / `CompactionCommandCard` | `command/run`+`command/done` 按 `commandId` 折叠；通用卡 `command.*`；`/compact` 运行中「正在压缩…」，checkpoint 后只留 CompactionItem；`/permission` 隐藏 | **missing** → **present** | **R24** |
| Context tool-change row | desktop `ContextInjectionRow`; Android hides ordinary Context | `developer/message` / non-user `user/message` 的 `tool-addition`/`tool-removal` 可见；skill-catalog / time-context 仍隐藏 | **missing** → **present** | **R23** |
| Deliverables | `Item.Deliverable` | tap opens workspace file preview | **present** | **B** |
| Markdown / code block / tables | `Markdown.kt` | AST + GFM tables / code / file chips | **present** | **D** |
| Copy / like / dislike / share | `MessageActions` + `FeedbackCategory` | desktop row is share (not branch); branch stays on the session row menu | **present** | **A** / **P1** |
| Message / trigger clock | `formatMessageClock` | 同日 `HH:mm`；同年 `clock.md`+时钟；跨年 `clock.ymd`+时钟（zh `m月d日` / `y年m月d日`，en `m/d` / `y-m-d`）；本地时区；无今天/昨天 | **present** | **R13** |
| Turn usage pill | `ComposerStats.kt` `TurnUsageAction` | `TurnUsagePanel`：chip `用量 {n} tok`；popover 在 pill 上方；表头图标 +「本轮用量」左、合计右；无「合计」行；推理挂在输出行 `（其中推理 {n} tok）` | **missing** → **present** | **E** / **R6** / **R12** |
| Composer statistics | Activity / Usage / Context pills | `ComposerStats` 单行 HStack；Activity / Token 用量 / ContextMeter 均为贴 chip 的 popover（在 chip **上方**）。用量 pill 用数据库图标；上下文为 14px 环 + 百分比；弹层文案 `stats.dialog.*` / `context.*`（「工具定义」「对话消息」） | **missing** → **present** | **E** / **R8** / **R11** / **R12** / **R18** |
| Composer queue / steer | busyEnter + `queue.update` | `busySend` + `PromptQueue` edit/remove/steer；排队行按桌面 `QueueDock` 画图片缩略图 / 文件芯片（有 `session.attachment` 或本地 preview） | **partial** → **present** | **E** / **R5** |
| `@` mentions | `MentionMenu.kt` official `@path` / `@"path"` / `@[title](dsh-session:…)` | same tokens + chip row + mention panel | **partial** → **present** | **E** |
| `/` commands | `CommandPopupSheet` `commands.list/execute` | 贴输入框弹层（#21）；`+` 与 `/` 同菜单；不接受附件的指令先 toast 官方句再执行；claimed `/goal` `/plan` 空参数时输入框上方 hint strip。R8：`ComposerTextView` `fixedSize` + 关滚动测高，空文本走 36/52 地板而不是 132 | **missing** → **present** | **E** / **P2** / **#21** / **R4** / **R5** / **R7** / **R8** |
| Header ⋯ overflow | Android `MoreSheet` (not desktop) | **removed** — desktop conversation header has no ⋯; export/feedback on `/` and `+`; rename/fork on the drawer row menu | **hide** | **P2** (#16) |
| Session image bubbles | `session.attachment` + ImageBubble | same cache + retry + original preview | **missing** → **present** | **G** |
| Attachments | `attachments.upload` | image picker + file importer + receipts；landing 无会话也可草稿非图文件，创建后上传 | **missing** → **present** | **E** / **R19** |
| User questions | `UserQuestionCard` `userQuestions.answer` | composer 接管卡片；工具行标题 `ask.rowTitle`「提问」；运行中「等待回答」、pending「已继续工作，仍可回答」；可回答时点行「回答」重开（桌面 `AskQuestionRow`，无 composer Ask chip，无 review 面板） | **missing** → **present** | **E** / **R19** / **R20** |
| Approvals | official `ApprovalCard` takes composer | official card; `accepted` callback clears busy, success drops the row | **partial** → **present** | **E** |
| TodoPanel | dock card above composer | `TodoPanel` expand in place | **missing** → **present** | **E** |
| Goal bar | `goals.get` / `goal.activation` CAS | `GoalBar` + `GoalSheet` pause/resume/clear/edit | **missing** → **present** | **E** |
| Permission mode | catalog/get/set + risk sheet | composer chip 为桌面 `PermissionSelect` 幽灵按钮 + 官方 SVG + EXP 8/500 + 自定义菜单（非系统 Menu，弹层在 chip **上方**，含 Auto review 全行）；斜杠 `/permission` 按桌面 `popupSelect` 在弹层内原地列选项 + ✓；landing 选档写入 `draftPermission`，创建会话时 `permissions.set`；危险档确认（居中、先收键盘、不被键盘挡住）；Settings defaults（`auto` 不能当默认） | **partial** → **present** | **E** / **R7** / **R8** / **R13** / **R14** |
| Turn trigger row | desktop `TurnTriggerNodeView` | 仅 `waking`（`inbox-next-turn.currentClaimed` 或 idle steer）画触发行；Host 注入的 skill-catalog / time-context 与未唤醒的 tool-jobs 继续隐藏 | **missing** → **present** | **R7** / **R8** |
| Session title live update | Android `refreshTitles` on status | `drawerSessionTitle` 优先非空 title；status 时重拉 `sessions.list`（停后再 4s）；follow `projection key=title` | **partial** → **present** | **R7** |
| Session list relative time | `formatSessionTime` / `timeLabel` | `relativeTime` 桶 + `time.now/{unit}`；空白会话不画时间；审批/计划待审/待回答用 `status.compact.*` 替换时间；标题栏无时钟 | **present** | **R13** |
| Model + effort | two-level picker | composer chip 锚定 `ModelSelect` 两级菜单（模型 / 有推理才出推理等级），弹层在 chip **上方**；空态「暂无可用模型」；landing 无会话时写入 `draftModel` | **partial** → **present** | **E** / **R13** / **R14** |
| No “scroll to bottom” FAB | `followBottom` | auto-scroll only | **present** | — |

## 2. Trajectory

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Build ledger from items | `Trajectory.kt` `buildTrajectory` | `Trajectory.swift` `buildTrajectory` | **present** | **A** |
| 7 cell kinds | system / user / context / compacted / message / tool / subtool | same kinds + reducer `system/message` / compaction | **present** | **A** |
| Compact ledger (事件 + 内容) | `Trajectory.kt` | `TrajRowView` | **present** | **A** |
| Toolbar 时长 / 轮次 / 调用 + search | `TrajectoryToolbar` port | same chips + search field | **present** | **A** |
| Swimlane overview | `TrajectoryTimeline.kt` | `TrajectoryTimeline.swift` + `SwimlaneChart` | **present** | **A** |
| Inspector tabs 概述 / 参数 / 结果 / Schema / 计时 | `TrajectoryDetail.kt` | `TrajectoryDetailSheet`。吞吐窗口 ≤0 用官方 `timingNotAvailable`「不可用」，不再自撰「时长过短」 | **present** | **A** / **R12** |
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
| `files.list/read` listing | `FilesPanel.kt` | `FilesPanel`（`files.list` 公布时）。原地展开/折叠；目录行只有开合文件夹图标（无 chevron）；file-icon 色（#20/#21/R5） | **present** | **B** / **P1** / **#20** / **#21** / **R5** |
| Preview (md / text / image / PDF / Office / XLS) | `FilePreview.kt` + `OfficePreview.kt` + `WorkbookPreview.kt` | same kinds; PDFKit pages; `office.*` lease → PDF; XLS FortuneSheet over `dsh-workbook-preview://` | **partial** → **present** | **B** / **F** / **H** |
| Workspace entities / tree | `WorkspaceNavigation.kt` | entity groups / tree / rename / delete / new session | **present** | **B** |
| Add workspace browse | `WorkspaceDirectoryPicker.kt` | `WorkspaceDirectorySheet` when `workspace.create` | **present** | **B** |
| Session search | `sessions.search` + local title/path merge | desktop `ui-workspace` Search: 250ms, NUL/500 UTF-16 sanitize, local metadata immediately, Host failure keeps local with no warning, cap 20 + 「仅显示前 n 条…」, empty 「无匹配会话」, clear drops Host hits, picking an unarchived row clears search | **missing** → **present** | **G** / **P2** (#16) |
| Unarchive / archived not openable | restore dialog; `workspace.unarchiveSession` | same; archived rows do not `openSession` | **missing** → **present** | **G** |
| Workspace / session reorder | Host `insertBefore` / `insertSessionBefore` (Android UI is local Manual) | drag/drop calls Host ops when advertised; Manual order still local | **missing** → **present** | **G** |
| NavigationPolicy | `workspaceDisplayTitle` / `visibleDrawerSession` / `reconcileSessionOrder` / `workspaceBranches` / `archiveActivityDescription` | same Swift ports in `Workspace.swift` | **partial** → **present** | **G** |
| Open-in-desktop-editor | desktop only | — | **hide** | — |
| WorkspaceChanges cards | `WorkspaceChanges.kt` | chat cards + review sheet (`workspaceChanges.summary/diff`); `workspace/changes` announcement; attached to last answer when visible, otherwise an independent card outside 「已完成」. Pocket JSON 的 `binary`/`oversized: false` 按 Android 接受（#19 只修了 `{summary:…}` 解包，运行时 Host 序列化带 false 仍整卡解析失败）。R5 实机：空 `Group` 上的 `.task` 不跑；R6 把 fetch 挂在 1pt 常驻锚点 | **missing** → **present** | **F** / P1 / **R5** / **R6** |
| File tree live updates | `files.follow` + `observeWorkspaceDirectory` | same; watch-unsupported 回退 list；工具栏 pause/play「自动刷新」按桌面 `DirectoryNode.setAutomatic`：关则保留 watch、不因 change 再 list | **partial** → **present** | **F** / **H** / **R5** |
| Browser | `BrowserPanel.kt` + `BrowserTabs.kt` HTTP(S)-only, addresses-only checkpoints | implemented (multi-tab `{selected, pages:[{id,url,title}]}`); chat HTTP(S) links open this panel when `linkOpening=sidebar` (desktop default). Start / ⋯ still have no entry | **present** | **P1** / **H** / **R6** |
| Session Inspector | `SessionInspectorPanel` raw/grouped + pick | implemented, unexposed — desktop Start / ⋯ have no entry | **hide** | **P1** |

## 5. Jobs + unread

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Header jobs chip | `JobsAction.kt` / desktop `JobListAction` | tabs-row chip；面板为进行中 / 已结束 + 两点击停止（`kill.confirm`）。R6 实机：空 `Group` 上的 `.task` 不跑、从不 `jobs.list`；R7 把 watch 挂在 1pt 常驻锚点（同变更卡）。插件 `jobs.list` / `follow` / `kill` 已转发，Host `{type:rows, jobs:[…], output.lossy:false}` 可解析。R10：行状态按桌面 `JobView`（`status`/`detail`/`progress`/`finishedAt`，必要时从 `exit` 投影）；killed 为橙点 + `signal: SIGTERM; cancelled by the user` 单行、无停止按钮。R11：popover 随屏宽放宽，已结束 detail 换行而不截成 `SIGTER…`。R12：「已结束」按桌面 `settledOpen ?? liveCount===0`，一次点按展开；popover 花名册保持同一 identity，不再 `ViewThatFits` 重挂载吃掉首点 | **present** | **C** / **R6** / **R7** / **R10** / **R11** / **R12** |
| Failed refresh → 「任务状态不可用」 (not 0) | `JobsAction.kt:62-64` | same copy, stale running count discarded | **present** | **C** |
| `jobs.list` / `follow` / `kill` | `Pocket.kt` | `PocketClient` + `JobsPanel`; list+live follow share one roster | **present** | **C** |
| Unread green dot | `CompletionReminders` epoch+revision | idle+未归档时 14pt 槽内 3/14 半径绿点；运行中为 StateDot spinner（仅会话行）；工作区保持文件夹 | **present** | **C** / **R13** |
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
| Phone connection + 复制诊断报告 | connections | 抽屉脚（计算机名 + 状态），Settings 无「手机连接」分组 | **present** | **R13** |
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
| `Transcript.kt` extra items (`System`, `Compacted`, `Retry`, `TurnFailure`, `Changes`; System folded; Compacted is desktop `CompactionItem` in chat; Retry/TurnFailure rendered; Changes cards when coding view is on; Context tool-addition/removal shown; CommandNode from `command/run`+`command/done`) | Chat + trajectory | A / D / **E** / **F** / **R22** / **R23** / **R24** |
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
- WorkspaceChanges: consume Host `workspace/changes`; chat cards when `showCodeWorkView` and `workspaceChanges.summary` is advertised; diff sheet needs `workspaceChanges.diff`. Keep the card outside the 「已完成」 fold (attach to the last answer when that answer is visible). Pocket wire flags are `absent | true | false` (Android); do not reject JSON `false`.
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
| 工作区更新 | `FilesPanel.swift`、`WorkspaceDirectory.swift` | `FilesPanel.kt`、`WorkspaceDirectorySubscription.kt`、`WorkspaceDirectorySubscriptionTest.kt`；desktop `ui-sidebar-files` | `files.follow` + `observeWorkspaceDirectory`；watch-unsupported 回退 list；同路径刷新不清空列表；前台才订阅；自动刷新 pause/play（R5） |
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

## Round 5 对照清单（桌面 `packages/client` @ current master）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 文件树目录行 | `FilesPanel` + `fileTreeFolderSymbol` | `ui-sidebar-files` `FilesBody.tsx` `Entry` | 目录行只有开/合文件夹图标，无 disclosure chevron；文件行不再预留 chevron 空位 |
| 自动刷新 | `FileAutoRefresh` + `directoryWatchShouldReload` | `store.ts` `autoRefresh`、`directory-node.ts` `setAutomatic`、`FilesBody.tsx` pause/play | 默认开；关后 watch 仍在，change 不 list；再开补一次 list。桌面把按钮包在 `<span hidden>`（测试要求不可见）；iOS 画出按钮，否则触屏无法用 |
| 排队附件 | `QueuedAttachment` / `PromptQueue` | `ui-conversation` `QueueDock.tsx` | 图片 24×24 缩略图（`session.attachment` 或本地 preview）；文件芯片 = 图标 + 名 + `fileSizeText`；无 durable ref 的块跳过 |
| claimed hint | `claimedComposerHint` 在输入框上方 | `InputBar.tsx` `--dsh-composer-hint` | `/goal` `/plan`（及 Host 中文名经 catalog `definitionId`）且参数为空才显示；有目标时用 `hint.goal.active` |
| 变更卡运行时 | `WorkspaceChanges.wireBoolFlag` + `parsePocketResult` | Host `workspace/changes` via pocket `follow`（plugin 不滤 type）；summary/diff via `workspaceChangesOps` | 插件 `d30825c` **有**转发：`plugin/index.js` `workspaceChangesOps`、`skillOps`；`server.js` `follow` 原样推 `sc.follow` 帧。缺卡是 iOS 把 JSON `false` 当畸形。 |
| 斜杠「技能」 | `skillCatalog` 预取 + `commandMenuDisplayRows` | desktop 三组 添加 / 指令 / 技能 | `skills.list` 有数据才出「技能」组，排在指令之后；首屏高度用 composer 上方全部可用高度 |
| 斜杠键盘高度 | `commandMenuAvailableHeight` | 贴 composer 上方的剩余视口 | 去掉 `max(240, 72%)` 地板（键盘升起后 240 会高于剩余高度） |
| 无会话首页 | `RootView.emptyChat` | `conversation` landing：`hero.headline` / `hero.preview` / `placeholder.hero` | 「探索未至之境」+「预览版」+ composer「描述你想要构建的内容, / 调用指令, @ 文件或对话」；发送即 `sessions.create` 再 prompt。抽屉仍保留「新会话」。 |

## Round 6 对照清单（桌面 `packages/client` @ current master）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 运行态鲸尾 | `RunningWhaleTail` + `TextShimmer` | `ui-chat` `RunningWhaleTail.tsx` / `TextShimmer` / APNG `running-whale@2x.png` | 60×50ms APNG 作 template mask；Reduce Motion 用 `REST_PATH` SVG |
| 任务面板 | `JobsPanel` + `JobKillPhase` | `ui-jobs` `JobListAction.tsx` | 进行中 / 已结束 {n} / 清空；两点击停止 `kill.confirm` / `KILL_ARM_MS` 3s |
| 占位与快捷键 | `composerPlaceholderKind` + `ComposerUITextView.keyCommands` | `ui-conversation` `InputBar` / `resolveSubmitMode` | `Cmd/Ctrl+Enter 插话发送全部排队消息`；硬件 Cmd/Ctrl+Enter |
| 插件 (i) | `PluginsScreen` popover | `ui-plugin-manager` `infoLabel` / `infoDescription` | 点按 / 长按弹出官方说明，无自撰横幅 |
| 链接 | `MarkdownView` + `openChatLink` | `ui-chat.linkOpening` | `sidebar` → 应用内 `BrowserPanel`；`new-tab` → 系统浏览器 |
| landing `/` | `commandMenuClientRows(landing:)` + 无 session 的 `commands.list` / `skills.list` | Host catalog；桌面 blank session | 无会话只注入桌面客户端贡献 /file、/model；goal/plan/feedback/compact/permission/export 与技能均来自无 session 的 `commands.list` / `skills.list`（需插件支持），不硬编码 |
| 变更卡 fetch | `ChangesCard` 1pt 锚点 + `changesCardMountsFetch` | `workspace/changes` → summary | `.task` 不依赖 summary；R5 seq 29 / turn closed / codeWork 会拉卡 |
| 斜杠高度 | `frame(height: availableHeight)` | composer 上方剩余视口 | 不再只露约 3 行 |
| 技能描述 | `commandMenuDescriptionLineLimit` = 2 | `InputBar.module.css` `line-clamp: 2` | 与桌面截断一致 |
| landing chip | `landingWorkspaceRow` + composer `defaultPermission` | `EmptyHero` WorkspaceChip | 「选择工作区」+「工作区内修改」。R7：「标准模式」改到 composer 上方与 project 并排，不再占顶栏 |
| 本轮用量 | `TurnUsageAction` `.popover` | desktop usage pill popover | 不再全屏 sheet |
| 文件树滚动 | `fileTreeOffsets` + `contentSize` 再恢复 | desktop sidebar files | 离开再进恢复 offset，内容未就绪时不把 0 写回 |
| 技能隔离 | `skillCatalogScopeKey` | 会话 / 子智能体 | 切会话先清空；失败置空；不回落全局 `skillEntries` |

## Round 7 对照清单（桌面 `packages/client` + Round 6 实机 `REPORT_ceae`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 后台任务 chip | `JobsAction` 1pt 锚点 + `jobsActionShouldWatch` | `ui-jobs` `JobListAction` `watchRows` 在挂载期间一直跑 | 空 roster 也 watch；chip 仅在有任务时出现。hello.ops 含 `jobs.list`（插件 `jobsOps` 已转发）。Host `{type:rows,id:bash-1,output.lossy:false}` 解析为 live chip |
| 后台任务状态更新 | `ChatRow.turnTrigger` + `TurnTriggerRow` | `ui-chat` `TurnTriggerNodeView` / `turn-trigger.ts` / `message.trigger.job` | 可折叠「⊙ 后台任务状态更新」+「这条通知触发了本轮回复。」 |
| 会话标题 | `conversationHeaderTitle` / `refreshSessionTitles` / title projection | Android `refreshTitles`；Host `projections.values.title` | 非空 title 压过 `blank`→「新会话」；status 时重拉 list，停后再等 4s |
| 权限 chip | `PermissionChipMenu` | desktop 贴着 chip 的小菜单 | 当前项 ✓；危险档仍走确认 sheet |
| landing 预设 | `landingWorkspaceRow` | `conversation.hero.agentPreset` | `project ⌄` 旁「标准模式 ⌄」 |
| Composer 高度 | `composerAddButtonPoints` 等 | `InputBar.module.css` 28 / 34 / 36 / 52 | 缩小空白，斜杠弹层不再只露约 3 行 |
| 标题旁 spinner | `ChatView` header | `ConversationSessionHeader` 无 running spinner | 运行态只留对话里的鲸尾，不去顶栏转圈 |

## Deferred / hide leftovers

- Account / shortcuts settings page / open config file / open-in-desktop-editor: desktop-local — **hide**.
- Keyboard shortcut *settings* page: desktop-local — **hide**. Touch Start also omits desktop chords (`⌘P` / `⌥⌘P` / Ctrl-`) next to 工作区文件 / 新建终端. Composer Cmd/Ctrl+Enter is wired.
- Android ForegroundService persistent “已连接” notification: iOS has no equivalent; `ConnectionKeeper` uses `beginBackgroundTask` + ping, then `BGAppRefreshTask` `dev.dsh.pocket.ios.refresh`. The WS is not guaranteed after the system expires those windows.
- Nearby Wi-Fi (`NEARBY_WIFI_DEVICES`) is Android 13+; iOS uses Local Network + Bonjour (`NSLocalNetworkUsageDescription`).
- CodePreview CSS names `DSH Meslo` at `/font/meslo.ttf`; `dsh-code-preview://` serves the same bundled Meslo Nerd TTF as `TerminalTypeface` (Android `@meslo` → `R.font.meslolgl_dz_nerd_regular`). WKWebView cannot intercept `https://`; assets load over `dsh-code-preview://` mapped to the same Android `https://code-preview.invalid` policy used in tests.
- Embedded browser cannot intercept every subresource the way Android `shouldInterceptRequest` does; main-frame / navigation policy still uses `BrowserPolicy`. WKWebView cannot intercept `https://` for FortuneSheet; workbook assets load over `dsh-workbook-preview://` mapped to Android `https://workbook-preview.invalid`.
- Foundation `JSONSerialization` object key order is not insertion-stable; protocol tests compare parsed `JSONValue`, not pretty strings.
- Desktop `ui-sidebar-files` auto-refresh control is in the DOM but `hidden` (tests assert it has no accessible name). iOS shows pause/play so the same `setAutomatic` gesture is reachable on touch.
- Desktop `DisclosureRow` `previewChevron` swaps the Think icon for a chevron on hover. Touch has no hover; iOS keeps the Think icon and a trailing chevron.

## Round 8 对照清单（桌面 `packages/client` + Round 7 实机 `REPORT_44aa`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 触发行 waking | `isWakingTurnTrigger` + `spliceInbox` | `ui-chat` client.js ~10470/10491；`inbox-next-turn.currentClaimed` 或 idle steer | 只有真正唤醒本轮的消息画「后台任务状态更新」等；skill-catalog / time-context / 额外 tool-jobs 不画「收到执行请求」 |
| `/permission` | `CommandMenuOverlay` `pickingPermission` | `ui-permission-presets` `popupSelect` | 斜杠弹层内原地列选项 + ✓ + 方向键 / Enter；危险档确认。去掉 chip 菜单自撰「加载权限模式…」「没有可用的权限模式」 |
| Composer 测高 | `composerTextFittedHeight` + `fixedSize` | `InputBar.module.css` 36 / 52 / 132 | 关滚动测内容高度；空文本走地板，不占 132pt 空白，斜杠列表不再只露约 3 行 |
| 任务面板 | `JobsAction` `.popover` + `PopoverCompactAdaptation` | `ui-jobs` `JobListAction` 贴 chip 的 popover | iPhone 不再整屏 sheet；■ 为两次 Button 点按（`jobKillPress`），不是 `TapGesture(count: 2)` |
| 权限菜单顺序 | `PermissionChipMenu` `.menuOrder(.fixed)` | 目录顺序 | landing / 会话同一顺序，不随弹出方向翻转 |
| 底栏统计 | `ComposerStats` 单行 | desktop statistics row | 去掉 `ViewThatFits`→`VStack` 的 3 行回退 |
| landing 权限 | `draftPermission` → `applyDraftPermission` | desktop hero 选档后写入即将创建的会话 | 无 `sessionId` 时记下草稿，`sessions.create` 后 `permissions.set` |

## Round 9 对照清单（桌面 `packages/client` + Round 8 实机 `REPORT_2c96`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Composer 换行 | `ComposerTextView.sizeThatFits -> CGSize?` | SwiftUI `UIViewRepresentable` 协议 | 返回非 Optional 时 SwiftUI 不调用，长文本不换行；空文本仍走 36/52 |
| 任务 popover | `arrowEdge: .top` + 无 `header` | `ui-jobs` `JobListAction` 从 chip 下方弹出，无返回箭头 | 320×420 内容完整；「<」只留在全屏 Host 面板 |
| landing 完全权限确认 | `permission.access` / `currentSession` | `PermissionSelect` 用 `confirm.description`（智能体 / 当前任务）；`settings.permission` 的「新会话 / 后续任务」只给设置默认档。桌面 hero 已是空白会话 | landing 与会话同一套 |
| landing 草稿持久化 | `landingPermissionPersistsAcrossLaunch = false` | InputBar 仅在 `sessionId !== undefined` 时画权限；hero 的选择写在 Host 会话上 | 不写 UserDefaults；杀进程后回默认档 |
| waking | `InboxClaimState` + `applyInboxClaim` + `isWakingTurnTrigger` | `ui-chat` `inbox.ts` / `message.ts`（client.js ~10360–10491） | claim **替换** `currentClaimed`；idle steer 要求 step 1、`claimSeq > turnStart`、`claimedHuman == false`；id 不用 rpcId |

## Round 10 对照清单（桌面 `packages/client` + Round 9 实机 `REPORT_e133`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 已停止任务行 | `jobViewProjection` + `applyJobFollowProjection` | `dsh-jobs/view` `JobView`；`ui-jobs` `JobListAction` `isLive` / `jobDetail` / `dotState` / kill 仅 `running` | Host `job.list` / follow 的 killed `JobView`（`status`+`detail`+`finishedAt`，progress 清空）投影为橙点 + `signal: SIGTERM; cancelled by the user` 单行、无停止按钮。`exit.signal` 仍写成 live `status` 时同样投影。follow `opened` 不得把已结算行救回 running |
| 任务 popover 尺寸 | `jobsPopoverSizesToContent` + `ViewThatFits` | `JobListAction` `MenuSurface` + `useAnchoredPosition` | 按内容收缩，不再固定 320×420 |
| 底栏统计 | `composerStatisticsTokenUnit` | desktop statistics `tok` | 「25.4K tok · 缓存命中 48%」，不再用会被截断的 `tokens` |
| 触发行 | `TurnTriggerRow` `T.fill2` 圆角卡 | `TurnTriggerNodeView` 灰底圆角卡 | 左图标、右时间 + chevron |
| 完全权限确认 | `PermissionRiskDialog` | `RiskConfirmation` 居中对话框 | landing / 会话 / 设置同一套文案，不再整屏 sheet 把内容顶上去 |
| 应用内浏览器 | `keepsChatMounted` + `ChatView` 不卸载 | 桌面 sidebar 叠在会话上 | 关闭浏览器后滚动位置还在；会话仍按最后一行贴底 |
| waking step | `wakingTriggerStep` | `message.ts` `location.kind === "step" && step === 1` | 只有 `openStep`，不再把「有 turn 无 step」当成 step 1 |

## Round 11 对照清单（桌面 `packages/client` + Round 10 实机 `REPORT_b874`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Token 用量 | `ComposerStats` session usage `.popover` | desktop statistics chip `MenuSurface` | 贴 chip 的小气泡；表头 `Token 用量 {exact} tok`；无「合计」行；「缓存命中」不是「缓存命中率」；token 值带 `tok` |
| 已结束任务 SIGTERM | `jobsPopoverWidth(screenWidth:)` + `jobsPopoverSettledDetailWraps` | `JobListAction` 整句 `signal: SIGTERM; cancelled by the user` | 窄屏换行，不再 `SIGTER…` |
| 完全权限确认键盘 | `permissionRiskDismissesKeyboard` + composer `resignKeyboard` | desktop `RiskConfirmation` 先 blur composer | 对话框出现前收起键盘（slash 菜单的 lockFirstResponder 也放开） |
| waking 回归表 | `WakingTurnTriggerTests` | `ui-chat` `inbox.ts` / `message.ts`（client.js ~10360–10491） | 一张表覆盖 next-turn claim、idle steer、skill-catalog / time-context、未认领 tool-jobs、claim 替换、无 step、canceled splice |

## Round 12 对照清单（桌面 `packages/client` + Round 11 实机）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Token 用量方向 | `composerUsagePopoverOpensAbove` → `arrowEdge: .bottom` | `ui-chat` `stat-dialog.ts` `useStatDialog` `side: 'top'` | 弹层在统计 chip **上方**，不被键盘挡住 |
| Token 用量表头 | `UsagePopoverHeader` | `StatsPills.tsx` `DialogPill` + `stat-dialog.module.css` `.title` / `.titleLabel` / `.titleValue` | 左侧数据库图标 +「Token 用量」；合计 `34,185 tok` 右对齐；无「合计」行 |
| 本轮用量 | `TurnUsageAction` | `TurnUsagePanel.tsx` + `locale.ts` `message.turnUsage.*` | 同样在 pill 上方；表头「本轮用量」+ 合计右对齐；`提供方 / 模型`；`缓存命中`；输出行后缀 `（其中推理 {n} tok）`；EN `Cached input` |
| Think 展开 | `ReasoningRow` | `ReasoningRow.tsx` + `DisclosureRow` `icon={THINK_ICON}` | R12 误读。R13 按 alpha.5 `DisclosureRow`：`open ? IconChevronUp : collapsedLeading`（展开 chevron-up 替换 Think；收起 Think，触屏无 hover 换 chevron） |
| 已结束展开 | `jobsSettledSectionExpanded` + `JobsPopoverRoster` | `JobListAction.tsx` `settledOpen ?? liveRows.length === 0`；`job-list-action.client.spec.tsx` 一次 click 展开 | 显式 toggle 优先；有 live 时默认折叠；点一次展开。popover 测高后同一 `ScrollView`，不再 `ViewThatFits` 在 `jobList` ↔ 滚动层之间重挂载。时钟只在有 live 行时走 |
| 轨迹吞吐空窗 | `formatThroughput` | `ui-trajectory` `timingNotAvailable` | `seconds <= 0` →「不可用」/ `Not available`，删除自撰「时长过短」 |

本轮源码对照后**不改**、留给实机 / 平台的项：

- 文件树滚动恢复：`fileTreeOffsets` + `fileTreeRestoredOffset` 已在 R6 / 测试里；无新代码缺口。
- 空 `Group` `.task`：变更卡 / 任务 chip 已用 1pt 锚点（R6/R7）。
- Account / shortcuts / open config / open-in-desktop-editor：仍 **hide**。
- 桌面 `DisclosureRow` / `ChatGroupSeat` hover 把图标换成 chevron：触屏无 hover，收起态保持图标（与 Android 触屏处理一致，桌面源码仍是 hover 才换）。

## Round 13 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

每条只引用桌面 package / 文件 / 符号；Android 只作「已移植项」核对，冲突以桌面为准。

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 权限 chip | `PermissionUi` + `OfficialGlyph` | `ui-permission-presets` `PermissionSelect` / `PermissionIcon*` / `Menu.module.css` | 幽灵触发 + 官方 SVG；Auto 有图标；EXP 8px/500/0.2；菜单 min 144 max 360、行 34、icon 14；文案 `自动审查`/`Auto review` |
| 模型 picker | `ModelPicker` `ModelChipMenu` | `ui-model-selection` `ModelSelect` | 两级弹层；根行「模型」/有推理才「推理等级」；空态「暂无可用模型」；搜索空「没有匹配的模型。」 |
| 会话标题 | `ChatView.header` | `ui-conversation` `ConversationSessionHeader` | 无模型 chip、无 Agent 预设、无时间戳 |
| Agent 预设 | `AgentPresetSeat` | `ui-agent-preset` `AgentPresetSeat` | 只在无会话 landing；minHeight 28、maxWidth 240、13/500 |
| 连接入口 | 抽屉脚 | Settings 仅 General/Models/Presets/Plugins；pocket 连接不是 Settings 分组 | Settings 去掉「手机连接」卡 |
| 会话 leading | `SidebarActivityIndicator` | `ui-workspace` `Rows.tsx` `SessionStatusDots` / `StateDot` | idle 空；未查看绿点 3/14 of 14；运行 spinner 仅会话行；工作区文件夹 |
| Think 标题 | `ReasoningRow` | `ui-chat` `ReasoningRow` `t("message.think")` | 恒为「思考」/Think；流式 vs 完成是 `TextShimmer`，不换文案 |
| Think 时长 | 不在 Think 行 | `TurnProcessNodeView` `message.turnProcess.took` | 「已完成，用时 」+ `formatRunDuration`；Think 行无 duration |
| Think shimmer | `TextShimmer` 1.5s / 0.3s delay | `ui-primitives` `TextShimmer` / `TextShimmer.module.css` | 运行中扫光；Reduce Motion 静态 |
| Think 默认/收起 | `@State open = false` + `collapseTiming` | `useDisclosure` `expandedVersion === version` 初值 null→收起；Turn 换代重置 | 默认收起；工作步骤收起时机仍是 Host `ui-chat.collapseTiming` |
| Think chevron | 展开 `chevron.up` 替换 Think | `ui-primitives` `DisclosureRow` `leading = open ? IconChevronUpOutlineRegular : collapsedLeading` | 收起 Think 图标；展开 chevron-up；无 hover 换标 |
| Think 正文 | `MarkdownView` `.compact` | `ReasoningContent` `MarkdownText variant="compact"` + `ReasoningRow.module.css` `.thinkBody` | 三级色、次级 13、行高 20、左缩进 22、上下 4 |
| Think 与工具组 | `ProcessGroupView` | `ChatGroupSeat` + `ProcessGroupHeader` | 组头 body 字号；细节 `message.turnProcess.separator` ` · `；成员与组头同列；组内 ReasoningRow 独立披露 |
| 会话列表时间 | `sessionRowTrailingLabel` | `ui-primitives` `relativeTime` + `ui-workspace` `Rows.tsx` `timeLabel` / `sessionStatuses` | 经过毫秒桶，不是日历今天/昨天；zh 刚刚/N分钟/小时/天/个月/年；en now/Nmin/h/d/mo/y；空白不画；待审批/计划待审/待回答替换时间 |
| 消息/触发器时间 | `formatMessageClock` | `ui-chat` `message-chrome.ts` `formatMessageClock` + `clock.md`/`clock.ymd` | 本地日历同日 `HH:mm`；同年日期+时钟；跨年日期+时钟；en `10/11 16:08` / `2025-1-3 09:05` |
| 会话标题栏时间 | 无 | `ConversationSessionHeader` 无 clock | 不发明 header 时间 |

## Round 14 对照清单（桌面 `MenuSurface` + Round 13 实机 `0e5b5b9`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 权限 picker 方向 | `PermissionChipMenu` `composerPickerPopoverOpensAbove` → `arrowEdge: .bottom` | `ui-permission-presets` `PermissionSelect` `MenuSurface` `side: 'top'` | 弹层在 composer chip **上方**；高度按目录行（含 Auto review）收缩，不被屏幕底裁切 |
| 模型 picker 方向 | `ModelChipMenu` 同一旗标 | `ui-model-selection` `ModelSelect` `MenuSurface` `side: 'top'` | 同上；两级菜单 maxHeight 360，内容不足时 hug |
| 危险档确认 | `PermissionRiskDialog` `permissionRiskStaysAboveKeyboard` | `RiskConfirmation` 视口居中 overlay | 先收键盘；忽略 keyboard safe area；内容超出则滚，勾选 / 确认可点 |

## Round 16 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| landing 工作区 chip | `LandingWorkspaceChip` | `ui-conversation` `WorkspaceChip` / `HeroShell.module.css` `.workspace` + `ui-workspace` `WorkspacePicker` | 幽灵触发 13/500/minHeight 28/maxWidth 360；自定义 popover 不是系统 Menu；文案 `hero.chooseWorkspace` / `menu.addWorkspace`「添加工作区…」；无工作区且可创建时直接开目录流 |
| 计划 chip | `ComposerView` modes 行 | `ui-plan` `PlanModeControl` + `InputBar.js` `.modes` | 可见「计划」；a11y `chip.on.aria`；tooltip `chip.on.title`；在权限 chip 旁，不在输入框上方 |
| + 按钮 | `ComposerView` plus | `InputBar` `input.commands` | aria「添加文件或调用指令」；landing `/file` 打开文件选择（图可挂草稿） |
| 权限 chip 目录 | `permissionChipRequiresCatalog` | `PermissionSelect` `catalog === null → null` | 目录未到不画死 chip |
| 抽屉脚顺序 | `SessionDrawer.footer` | `ui-sidebar` `SidebarRoot` `sidebar.footer.action` 然后 `sidebar.settings` | 主机/设备行在 Settings **之上**；Settings 仍不含「手机连接」 |
| Agent 预设菜单 | `AgentPresetSeat` | `ui-agent-preset` `noDescription` / `seatHint` | 空描述「暂无描述。」；hint「选择新任务使用的 Agent 预设」 |
| 设置默认权限说明 | `PermissionPickerSheet` | `settings.permission` `description` | 仅「选择新会话的默认权限模式」，去掉自撰「自动审查仅适用于…」 |
| 斜杠空态 | `CommandMenuOverlay` | `ui-commands` `status.loading` / `status.empty` | 「正在加载选项…」/「无选项」 |
| 插件添加菜单 | `PluginAddMenu` popover | `ui-plugin-manager` `AddPluginMenu` | 两行 MenuSurface：第三方 + 创造；不再用 confirmationDialog |

## Round 17 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 停止并归档 | `SessionDrawer` alert + `AppModel.archive` | `ui-workspace` `ArchiveConfirmForm` / `activityLine`；Host `workspace/session-active` | 拒绝时打开确认，不再 toast 自撰 activity 句；确认文案 `archive.confirm.*`；确认后 `stopActivity=true` |
| 归档成功 toast | `archiveSuccessToast` | `toast.archived` / `toast.stoppedAndArchived` + `undo` / `or` / `filter` | 「会话已归档，可撤销或筛选已归档会话」；点 toast 撤销（触屏对应桌面 undo 链） |
| 无工作区 landing | `landingComposerNeedsWorkspace` | `ConversationRoot` `inert` + `placeholder.workspace` / `draft.workspaceRequired` | 无工作区时占位「选择一个工作区开始」，发送/新建 toast「请先选择工作区」，不静默 create |
| 停止按钮 | `composerStopLabel` | `conversation` `input.stop` | aria「停止生成」/ Stop generating |
| 会话运行态 | `sidebarRunningLabel` | `ui-workspace` `status.running` | 读屏「进行中」，不是自撰「运行中」 |
| 搜索结果工作区 | `searchResultShowsWorkspaceContext` | `Rows.tsx` `SearchResultItem` `searchResultWorkspace` | 标题下工作区名，无则「未分组」 |

## Round 18 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 会话统计弹层 | `ComposerStats` activity `.popover` | `ui-chat` `ActivityPill` / `DialogPill` `useStatDialog` `side: 'top'` | 不再整屏 sheet；表头「会话统计」；行 `stats.dialog.llmTime` / `toolTime` / `ttft` / `speed`；不发明「已加载历史统计」 |
| Token 用量 pill 图标 | usage 触发器 `cylinder` | `StatsPills` `IconDatabaseOutlineRegular` | compact / detailed 触发器都是数据库图标，不再与 Activity 共用 gauge |
| 上下文环 | `ComposerContextRing` + percent | `ui-conversation` `ContextMeter` 14×14 r=5.5 2px；fill `stroke-linecap: round` | 触发器是环而不是 gauge pill；描边半径贴桌面 viewBox，fill 圆头 |
| 上下文弹层 | `contextPopover` `arrowEdge: .bottom` | `ContextMeter` `useAnchoredPosition` `side: "top"` | 标题按 `context.aria` 拆开「上下文已用」+ `45%`；右侧 `~used / window`；行 `context.system` / `context.tools`「工具定义」 / `context.messages`「对话消息」 |
| 归档不可打开 | `restoreArchivedBody` / `archivedNotOpenable` | `ui-workspace` `toast.archivedNotOpenable` | 「已归档对话暂时无法查看，请取消归档后查看」；触屏仍用恢复确认（点按对应桌面 toast + 菜单取消归档） |
| 仅归档空态 | `drawerEmptyKind` + `drawerShowsEmptySessions` + `empty.viewOthers` | `EmptySessions` / `groupByWorkspace` / `leaveArchivedOnly` | EmptySessions 只在 `groups.length === 0`（扁平 `rows.length === 0`）。隐藏/显示已归档时仍画空工作区表头；仅归档把无成员组丢掉后才出「暂无已归档会话」+「查看其他会话」（重置为隐藏已归档） |
| 停止失败 | `jobKillFailedLabel` | `ui-jobs` `kill.failed` | 「停止失败」，删除自撰「终止失败，请重试」 |

## Round 19 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 离线空花名册 | `drawerEmptyKind` / `emptySessionsNone` | `ui-workspace` `EmptySessions` `empty.none` / `empty.noneArchived` | 离线不再用 Batch H「连接后显示会话」；无行时仍是「暂无会话」/「暂无已归档会话」 |
| landing 草稿附件 | `attachFile` + `createSessionAndSend(draftFiles:)` | InputBar `addFiles` / `createDrafts`（hero 已有 blank session） | 无会话也可挂非图文件；`sessions.create` 后上传再 prompt。桌面 `sessionId === undefined` 时 `addFiles` 为空，iOS landing 替代 blank session |
| Ask 重开 | `askToolRowReopensComposer` + `ToolCard` trailing `ask.reopen` | `ui-tool` `AskQuestionRow` `rowActionLabel`；`conversation.input.left` 无占用者 | 去掉自撰 composer 全宽「回答」；点提问工具行重开卡片。桌面无 Ask composer chip |
| subagent crumbs | `conversationHeaderAncestry` | `ConversationSessionHeader` `deriveAncestry` / `session.hierarchy` | 当前会话 `origin=subagent` 时标题为「父 / 子」；父可点按打开。抽屉仍隐藏 subagent 行 |
| + 按钮填充 | `T.selector` 28pt `Circle` | InputBar `.add` `--dsw-specific-selector` `#f5f6f7` / `#353638` | 填充圆用 selector，不是 hover-solid `#f1f3f5` |

本轮核对后**不改**、确认已对齐或平台/hide：

- 工作区自动选中：landing 仍 `draftWorkspaceId ?? workspaces.first`，对应桌面 blank session 已属于某工作区；无工作区才 inert。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- 桌面 popover 系统箭头 / Think 收起无 hover 换 chevron：仍平台残留。
- Android `18af5a8` / `9e580d4` / `d30825c` / `c5f8cdd`：外观本机、发布流程、skills.list / 无 session 目录，iOS 已有；无新交互可搬。

## Round 20 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Ask 工具行 | `askToolRowChrome` + `ToolProcessSummary` | `ui-tool` `AskQuestionRow` + `conversation` `ask.*` | 标题「提问」/ Ask question；运行中「等待回答」；pending「已继续工作，仍可回答」；关闭「已结束」；ASK_CANCELLED / ASK_ABORTED。可回答时 trailing「回答」。桌面 `ask.review` 面板 phone 不实现 |
| 改动 diff | `changesDiffNoticeKind` / `changesDiffNoticeLabel` | `ui-deliverables` `diff.*` | 「这轮改动的内容已不可用」/「无法显示改动」/「本轮新建的文件」/「两侧内容相同」/「按整个文件替换显示」/「只显示前 {count} 行」 |
| 消息图 | `messageImageLoading` / `messageImageFailed` | `ui-chat` `image.loading` / `image.failed` | 「加载图片…」/「图片无法预览」。点按仍重试，文案不再自撰「点击重试」 |
| 重试行 | `retryAttemptLabel` / `retryDelayMilliseconds` | `ui-chat` `ModelRetryItem` | 当前 scheduled=`retry.active`「正在重试」；历史 scheduled=`retry.scheduled`「等待重试」；延迟 `{n}毫秒` |
| 回合失败 | `turnFailureTitle` / `chatFailureMessage` | `TurnErrorItem` / `failureMessage` | `INTERRUPTED` 标题「任务已停止」、正文 `failure.interrupted`、不画 code chip。只映射桌面代码（去掉 QUOTA_EXCEEDED / AUTH_ERROR / INVALID_API_KEY 兜底） |
| 鲸尾读屏 | `RunningStatusRow` | `chat.deepDivingFor` | accessibilityLabel 与可见「深度求索中，用时 … ···」同一句 |

本轮核对后**不改**、确认已对齐或平台/hide：

- 绿点 / 会话行 spinner / 标题无 running spinner / 抽屉脚连接入口：已对齐，Android 在 Settings 下挂「云端设备」不搬。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- 桌面 popover 系统箭头 / Think 收起无 hover 换 chevron：仍平台残留。
- `AskQuestionRow` `ask.review`「查看回答」打开桌面 review 面板：phone 无该面板，不发明一层。
- Android `18af5a8`…`c5f8cdd`：无新交互。

## Round 21 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 工具行标题 | `toolRowTitle` + `ToolProcessSummary` | `ui-conversation` `tool.title.*` / `todo.rowTitle`；`ui-tool` SearchRow / WebRow / DetailsRow `LSP_TITLE_KEYS` | grep「搜索文件内容」/glob「查找文件」/web_search「网页搜索」/web_fetch「网页获取」；EN Grep/Glob/Fetch/Pwsh；todo `Update to-do list`；schedule reminder；ralph loop；lsp `goToDefinition`/`findReferences`/`goToImplementation`/`hover` |
| 工具行 preparing | `toolProcessSummary` 不再换标题 | `ui-tool` `ToolRow`：`title = t(titleKey)`；`row.preparing` 仅 a11y | 准备中仍是「读取」+ 参数摘要，不是组头「准备读取文件」。读屏 `正在准备调用` |
| Goal 条 | `goalPhaseLabel` | `ui-conversation` `detail.goal.*` | 进行中 / 等待继续 / 已暂停 / 受阻 / 已完成 / 没有目标。disarmed ≠ paused |

本轮核对后**不改**、确认已对齐或平台/hide：

- 绿点 / 会话行 spinner / 标题无 running spinner / 抽屉脚连接入口：已对齐。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- 桌面 popover 系统箭头 / Think 收起无 hover 换 chevron：仍平台残留。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- Android `18af5a8`…`c5f8cdd`：无新交互。

## Round 22 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Chat 压缩行 | `CompactionRow` + `foldChatItems` | `ui-chat` `CompactionItem` / `message.compaction*`；`compactionDefinition` / `compactSummary` | 落地 marker 可见；标题「上下文已压缩」/ Context compacted；手动 `/compact` 标题 `compact`；完成「已压缩 {n} 条历史记录（约 {n} tokens）」；无计数时「点击查看压缩摘要」或「压缩摘要不可用」；有 summary 才可展开 Markdown。仅 `compaction/start` 的 running 行仍隐藏（桌面无 CompactionItem，要等 checkpoint） |
| compact-checkpoint | `applyCompactionCheckpoint` | `isCompactionCheckpoint` / `compactSource` `kind: compact-checkpoint` | replacement `user/message` 不画用户气泡，把 checkpoint 记在 Compacted 上。`surfaceOp` 必须存在且不是 `append` |
| 摘要字段 | `compactionSummaryText` / `shadowedSeqs` | `compactSummary` | `data.summary` 仅为 text block 数组（不用字符串兜底）；`shadowedItemCount` = `shadowedSeqs.length`；非负整数 `shadowedTokenCount` |

本轮核对后**不改**、确认已对齐或平台/hide：

- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- 桌面 popover 系统箭头 / Think 收起无 hover 换 chevron：仍平台残留。CompactionItem 同样无 hover，触屏保持 API/`curlybraces` 图标，不换成 chevron。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- `CompactionCommandCard` / `command/run` 运行中「正在压缩…」：桌面是 slash command 卡，不是 CompactionItem。iOS 没有 command 节点，不发明一层。留给 Round 24+（需先有 Host `command/run`/`command/done` 节点面）。
- Android `18af5a8`…`c5f8cdd`：无新交互。Desktop 仍赢过 Android 把 Compacted 折进 `isHidden`。

## Round 23 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 工具变更 context 行 | `ContextToolChangeRow` + `foldChatItems` | `ui-chat` `isVisibleChatNode` / `ContextInjectionRow`；`dsh-llm` `tool-addition`/`tool-removal` | 纯工具块：单条「已添加工具：{name}」/「已移除工具：{name}」不可展开；多条标题「工具已更新」+ `新增 {n} 个` / `移除 {n} 个` / `新增 {a} 个，移除 {r} 个`，展开 `新增：`/`移除：`。普通 skill-catalog / time-context 仍隐藏。混合块可见，标题 `message.contextInjection`「上下文注入」 |
| max-tokens 通知 | `TurnMaxTokensRow` | `ui-chat` `TurnMaxTokensItem` `message.maxTokens` / `message.maxTokens.hint` | 一条 warning 点 + 标题「已达到输出 token 上限」+ hint「回答被截断…发送“继续”…」；EN Output token limit reached。不再两条中文 footnote |
| 退出登录中止 | `TurnFailureRow` | `turn-error.js` `endFailure` aborted signed-out → `ACCOUNT_SIGNED_OUT` | 不再写成 notice；标题「任务已停止」、正文 `failure.accountSignedOut`、保留 code chip |
| 中断「已停止」 | `.notice` `.stopped` | `message.stopped` | 文案跟 locale，不再写死中文 |

本轮核对后**不改**、确认已对齐或平台/hide：

- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- 桌面 popover 系统箭头 / Think·CompactionItem 收起无 hover 换 chevron：仍平台残留。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 绿点 / 会话行 spinner / 标题无 running spinner / 抽屉脚连接入口：已对齐。Android Settings「云端设备」不搬。
- Android `18af5a8`…`c5f8cdd`：无新交互。Desktop 仍赢过 Android 把 Compacted 折进 `isHidden`。

## Round 24 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

Host-loaded dist-tag `alpha` 仍是 `0.2.1-alpha.5`（本轮核对）。

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Command 节点 | `Item.Command` + `TranscriptReducer` | `ui-conversation` `CommandNode`；`ui-chat` `commandDefinition` | log-only `command/run`+`command/done` 按 `commandId` 折叠；窗口切开：无 run 的 done 仍建节点（name/args null）；run 无 done 为执行中 |
| GenericCommandCard | `CommandRow` + `commandRow*` | `ui-chat` `GenericCommandCard` `command.*` | 标题 `name ?? 指令`；运行「执行中…」+ TextShimmer；成功无正文「已完成」；失败「指令失败」；`outcome.text` 含换行才可展开；错误色 `state-error-primary` |
| CompactionCommandCard | 同一 `CommandRow` + 既有 `CompactionRow` | `CompactionCommandCard` / `ManualCompactionNodeView` | `/compact` 运行中 `message.compaction.running`「正在压缩…」；checkpoint 后只画 CompactionItem（`commandTitle` + `fallbackSummary`=`outcome.text`）；失败/取消/无可压缩历史留 GenericCommandCard |
| permission 卡 | `commandItemIsVisible` | `isVisibleChatNode` | `name === "permission"` 隐藏 |
| 手动压缩 marker | `compactionItemIsVisible` | `compactionDefinition.match` 遇 `sourceCommandId` 返回 null | 有 `sourceCommandId` 的 Compacted 只在 `hasCheckpoint` 时可见 |

本轮核对后**不改**、确认已对齐或平台/hide：

- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- 桌面 popover 系统箭头 / Think·CompactionItem·Command 收起无 hover 换 chevron：仍平台残留。Command 触屏保持 API/`curlybraces` 图标。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 绿点 / 会话行 spinner / 标题无 running spinner / 抽屉脚连接入口：已对齐。Android Settings「云端设备」不搬。
- `chat.turnNavigation.*`：桌面长 transcript 跳轮，phone 不发明一层。
- `fileOpen.title`/`fileOpen.unknown`：PDF 失败英文仍是自撰 `Could not open file`（桌面 `Can't open file`）；WorkbookPreview 自撰整句。留给 Round 25。
- `message.contextRecall` / `message.referenceSummary` / `message.context.instructions.*`：非 tool-change 的 context 注入细节，桌面有、iOS 仍隐藏普通 Context。
- Android `18af5a8`…`c5f8cdd`：无新交互。Desktop 仍赢过 Android（Compacted + CommandNode）。
