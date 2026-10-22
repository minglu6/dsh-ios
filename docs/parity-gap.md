# iOS ↔ Android / desktop parity gap

Phone is a controller. Layout may change for a narrow portrait screen. Features, copy, icons, colors, states, and interactions follow the official desktop UI (`@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`) as already ported by [dsh-android](https://github.com/minglu6/dsh-android) `main` at **`ce7d345`** (#67 Host plugin `terminal.follow`→`retain`+`attach` only; last client UI commit remains `56dcaa9`).

**Do not invent** settings groups, credential pages, extra security, or placeholder shells. Hide only what desktop itself hides (local OS editor, keyboard shortcuts).

> **当前产品决定（2026-10-22）：iOS 已移除「附近设备」及 Bonjour 自动发现。** 保留扫码、配对链接、手动地址，以及已配对设备 TCP 探测与连接；本地网络权限仍用于连接局域网主机。主机地址变化后需手动修改已保存的地址或重新扫码。下方批次／轮次中的 NSD、附近设备、`NWBrowser` 等记录仅描述当时实现，不代表当前支持，也不是待补齐功能。

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
| R24 | Host `command/run`+`command/done` 折叠；GenericCommandCard；CompactionCommandCard 运行中「正在压缩…」 | done (#41) |
| R25 | fileOpen locale + PDF 失败句；Workbook excel locale 核对；用户气泡 referenceSummary | done (#42) |
| R26 | audit-only：turnNavigation / ask.review / hover chevron / toBottom / Settings 云端设备 保持 skip | done (NO_PR) |
| R27 | ConnectionsView 对齐 Android `ConnectionsScreen` / `ConnDeviceRow` | done (#43) |
| R28 | #43 后源码审计；npm `next` `0.2.1-rc.1` 无 locale/component API 增量 | done (#44) |
| R30 | 外观/字体只写本机 AppPrefs，不再读写 Host `ui-theme`（对齐 Android #63 外观 + 控制器字体） | done (#45) |
| R31 | 通用设置 `FontSettingsGroup`：步进器 +「更多字体设置」展开代码/终端字号与字体族 | done (#46) |
| R32 | 语言跟 Host `locale.preference`：`L.en` 写回 AppPrefs；离线不可改 | done (#47) |
| R33 | audit-only：Android `c5f8cdd` 无新 commit；`next` 当时 `0.2.1-rc.1` 无 API 增量 | done (NO_PR) |
| R34 | 落地页首条发送立刻 pending echo（Android `FirstPrompt` / 桌面 `echo`） | done (#48) |
| R35 | 助手消息行动作行补 branch（桌面 `MessageIconActions.onBranch` / Android `messageBranch`） | done (#49) |
| R36 | fork 子会话 `increaseTitle`（桌面 `increasedForkTitle`） | done (#50) |
| R37 | audit-only：Android 仍 `c5f8cdd`；Host 仍 alpha.5 | done (NO_PR) |
| R38 | audit-only：#50 后抽查；Android 仍 `c5f8cdd` | done (NO_PR) |
| R39 | 用户选择卡片 + `userQuestions`/`inbox` 投影恢复（Android `56dcaa9` / 桌面 `QuestionComposer`） | done (#51) |
| R40 | 计划 `plan.discuss` / `planReviewOf`；晚答 `QuestionReplyView` | done (#52) |
| R41 | landing 模型座显示推理强度；权限 chip 只留图标；抽屉脚设置与设备同一行 | done (#53) |
| R42 | 抽屉会话行时间/操作、官方文件夹图标、视图选项 popover、外观点一次生效、自动化任务页、右侧栏浏览器+会话诊断、CI 模拟器截图 | done (#53) |
| R43 | audit-only：#53 后源码对照 desktop alpha.5；`next` rc.2 无 locale/API 增量；Android #67 仅 Host plugin | done (NO_PR) |
| R44 | audit-only：#53 CI 截图视觉对照；mandated 项对齐 | done (NO_PR) |
| R45 | 视图选项 iPhone compact popover + 每行官方 leading 图标 | done (#54) |
| R46 | 空会话 HeroShell 整列居中 gap 12（#54 CI `*-landing.png` 标题与工作区之间仍是夹心空隙） | done (#55) |
| R47 | 抽屉脚设置齿轮改用官方 `IconSettingsOutlineMedium` | done (#56) |
| R48 | 抽屉新会话改用官方 `IconNewChatOutlineRegular` | done (#57) |
| R49 | 抽屉搜索改用官方 `IconSearchOutlineRegular` | done (#58) |
| R50 | 抽屉工作区「添加」改用官方 `IconProjectAddOutlineRegular` | done (#59) |
| R51 | composer `+` 改用官方 `IconPlusOutlineMedium` | done (#60) |
| R52 | composer 发送改用官方 InputBar 16×16 SVG | done (#61) |
| R53 | 轨迹工具栏搜索改用官方 `IconSearchOutlineRegular` size 11 | done (#62) |
| R54 | 轨迹时长 chip 改用桌面 TrajectoryToolbar 内联 clock SVG | done (#63) |
| R55 | Jobs 头栏 chip 改用桌面 JobListAction `IconChevronDownOutlineRegular` | done (#64) |
| R56 | landing composer 贴底 + 去掉多余分享按钮 | done (#65) |
| R57 | 用户复制键 / 远程主机名热区 / 诊断 OfficialGlyph / 视图选项图标 / 插件 tooltip | done (#66) |
| R58 | 打开抽屉 / 滚动时收键盘 | done (#67) |
| R59 | 权限选择器去掉系统 sheet；轨迹 KIND_ICON 官方 SVG | done (#68) |
| R60 | Start/Browser/Inspector 去 grabber sheet；Start 去装饰地球；设置权限 inline select；轨迹 assistant/context token；停止 rect rx=3；chat/slash 官方 chevron/check；截图补 feedback | done (#69) |
| R61 | 顶栏侧栏 / 消息复制·分支 / 返回 chevron / 浏览器工具栏 / 设置外观改官方 SVG | done (#70) |
| R62 | Composer / 模型选择器对齐桌面 Flash `1017` 绿色徽标 | done (#71) |
| R63 | 会话工具/Jobs/轨迹官方 SVG；远程主机配对链接粘贴；抽屉当前工作区文件夹色 + 官方 fill | done (#72) |
| R64 | 远程主机卡片间距；配对链接 sheet primitives；landing 工作区 chip 官方 chevron/check/plus | done (#73) |
| R65 | 远程主机附近设备电脑图标 + 管理 sheet 官方 trash/refresh/edit；进 CI 截图路径 | done (#74) |
| R66 | 配对链接输入框与按钮同一 22pt 边距；Todo/Goal/Queue dock 与设置壳模型行官方 SVG + CI `chatDock`/`settingsShell` | done (#75) |
| R66-fix | PairLinkSheet bounds host 不参与布局；小标签与标题 22pt 对齐 | done (#76) |
| R67 | `/` 菜单行官方 SVG（paperclip / paperPlane / compact / data Regular / permission FullAccess / download / goal / plan） | done (#77) |
| R68 | 计划 chip / 提及气泡 / 传统 FileGlyph / 反馈 ✓ / 风险圈叹号 / 目录 chevron 官方 SVG；CI `planMode` + `mention` | done (#78) |
| R69 | 终端不可用/断线/缺失态对齐 `ui-sidebar-terminal`；landing 顶栏补右侧栏按钮对齐 `ui-sidebar-right` | done (#79) |
| R70 | `CODE_FILE_ARTWORK` 官方语言图标 PDF；outline/l3 token；markdown fileChip 官方 BrowseOutline；风险 checkbox CSS | done (#80) |
| R71 | 触发行 TRIGGER_ICONS / 工作区 overflow ellipsis / 插件 add chevron / 文档预览 wrap·copy / 预设与模型 plus | done (#81) |
| R72 | `@` / `/` MenuView 描边与 mention crumbs 对齐桌面 `--dsw-alias-border-l1` | this PR |

---

## File map

| Surface | Official package | Android | iOS now |
| --- | --- | --- | --- |
| Transcript fold | `ui-chat` / `ui-conversation` | `protocol/Transcript.kt`, `Chat.kt`, `ChatProcess.kt` (Compacted still hidden; no CommandNode) | `protocol/…/Transcript.swift`, `ChatProcess.swift`, `Features/Chat/ChatView.swift` — chat shows desktop `CompactionItem` + `CommandNode` (`command/run`+`command/done`) + tool-change `ContextInjectionRow`; Android still folds Compacted |
| Message actions | `ui-chat` `MessageIconActions` | `Chat.kt` `MessageActions` | `ChatView` `MessageActions` (copy / like / dislike / branch + turn usage；无分享。会话行菜单仍保留无 seq 的 `sessions.fork`) |
| Trajectory | `ui-trajectory` | `Trajectory.kt` + Detail/Inspector/Request/Locales; `protocol/TrajectoryTimeline.kt` | `Features/Trajectory/` + `protocol/Trajectory.swift` / `TrajectoryRequest.swift` |
| WorkspaceChanges | Host `workspaceChanges.summary/diff` | `WorkspaceChanges.kt` | `Features/Chat/WorkspaceChanges.swift` + `protocol/WorkspaceChanges.swift` |
| Session Inspector | Android `SessionInspectorPanel`（桌面 Guide **无**此卡） | `SessionInspectorPanel.kt` / Log / Model / Navigation | Start 第四项「会话数据诊断」+ `DrawerPanel.inspector`；桌面 0.2.1-alpha.5 Guide 只有 files/terminal/browser |
| Browser | `ui-sidebar-browser` Guide `order: 30` | `BrowserPanel.kt` + `BrowserPolicy.kt` | Start 第三项「浏览器 / 浏览网页」+ 既有 `BrowserPanel` |
| Code preview | shiki offline preview | `CodePreview.kt` | `Features/Files/CodePreview.swift` + `CodePreviewAssets/` |
| Terminal | Host `terminalController` | `TerminalPanel.kt`, `TerminalView.kt`, `TerminalEmulator.kt` | `Features/Terminal/` + `protocol/TerminalEmulator.swift`; bundled MesloLGL DZ Nerd Font + CoreText cascade; default fg/bg follow appearance; ANSI 16 = desktop xterm.js Tango (#20) |
| Files | `workspaceFiles` | `FilesPanel.kt` | `Features/Files/` + workspace tree / browse |
| Jobs | `job-controller` | `JobsAction.kt`, jobs follow in `Pocket.kt` | header chip 锚定 popover + `JobsPanel`（两次 Button 点按停止） |
| Plugins | `ui-plugin-manager`, `ui-settings-plugins` | `PluginsScreen.kt`, `PluginInventory.kt` | `Features/Plugins/` + `PluginPolicy.swift` |
| Schedule | `ui-schedule` (sidebar, not settings) | `ScheduleScreen.kt`; drawer row | `Features/Schedule/ScheduleScreen.swift`; drawer only |
| Permissions | `ui-permission` | `PermissionUi.kt` `permissions.catalog/get/set` + risk sheet | `PermissionUi.swift` + composer chip MenuSurface + Settings `PermissionRow` inline select + `danger-full-access`/`auto` confirm |
| Model picker | composer model menu | `ModelPicker.kt` + effort pane + `ModelLabel.kt` Flash `1017` | `ModelPicker.swift` two-level picker; switching models clears effort; official Flash shows desktop `Tag` success `1017` |
| Composer dock | `ui-chat` | UserQ / Approval / Todo / Goal / Queue / Composer / Stats | same stack in `ChatView` + `ChatDock.swift` |
| Host UI | pocket `ui.open` | native plugin manager; no embedded WebView | same; desktop market has no `ui.open` banner |
| Markdown | `ui-chat` primitives | `Markdown.kt` | `protocol/Markdown.swift` + `Features/Chat/MarkdownView.swift` |
| Official icons | desktop `D.*` | Android vector set | `Design/Icons.swift` SF Symbol map |
| Connection keep-alive | — | `ConnectionService` FGS | `ConnectionKeeper` `beginBackgroundTask` + ping + `BGAppRefreshTask` `dev.dsh.pocket.ios.refresh` + path monitor + local notify |
| Controller connections | Host pocket `settings.section` `pocket` is QR on the **computer**; Android `ConnectionsScreen` | `Screens.kt` `ConnectionsScreen` / `ConnDeviceRow` + PairLinkSheet（`9aa43c4` / `33b97b2`） | `Features/Connections/ConnectionsView.swift` + `ConnectionsLayout.swift`：全屏「远程主机」；已配对 / 动作卡间距 12pt（`Card` 竖向 6）；无附近设备区；管理 sheet 官方 refresh/edit/trash（非 SF、非系统 NavigationStack）；删除无确认（Android 立即 `removeProfile`）；ConnSheet `T.Surface` + dragHandle 28pt 顶留白 + 取消 ≥44pt；动作卡 扫码 → 配对链接（`IconLinkOutlineRegular`）→ 输入地址（Material Keyboard）；配对链接 sheet 用桌面 Button/Input token + Android 48 高，**输入框与按钮同一 22pt 外沿**（去掉 ConnField 18 leftover），粘贴后进既有配对确认，不立刻连接。入口在抽屉脚，Settings 无连接分组 |

---

## 1. Chat

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| User bubble, pending echo | `Chat.kt` | `MessageRow` `.user`；跟随的 `session-reference` 在气泡下画 `message.referenceSummary`，Context 行仍隐藏 | **present** | **R25** |
| Assistant text stream | follow reducer | `.text` live/committed | **present** | — |
| Reasoning disclosure | Think icon + preview | 标题恒为「思考」/Think；运行中 TextShimmer 而非 spinner；收起默认；展开时 chevron 替换 Think 图标；正文 compact 三级色 13/20；预览为首行（流式为已完成段首行） | **present** | **D** / **R12** / **R13** |
| Tool row → inspector | `Chat.kt` tool card | `ToolProcessSummary` title/icon/receipt + inspect sheet | **present** | **D** |
| Process group fold | `ChatProcess.kt` | `foldChatItems` / `visibleChatRows` + `ProcessGroupView`；已完成回合为「已完成，用时」+ 右侧 chevron（无左侧图标）；步骤组标题 body 14 + ` · ` 细节；成员与组头同列（无额外缩进）；运行中 shimmer | **present** | **D** / **R13** |
| Notices (stopped / max-tokens / account) | reducer + official `message.*` | reducer emits; `.notice` / `RetryRow`（active vs scheduled 文案） / `TurnFailureRow`（`INTERRUPTED`/`ACCOUNT_SIGNED_OUT`=`taskStopped`） / `TurnMaxTokensRow`（title+hint 一行） | **present** | **E** / **R20** / **R23** |
| Slash command cards | desktop `CommandNode` / `GenericCommandCard` / `CompactionCommandCard` | `command/run`+`command/done` 按 `commandId` 折叠；通用卡 `command.*`；`/compact` 运行中「正在压缩…」，checkpoint 后只留 CompactionItem；`/permission` 隐藏 | **missing** → **present** | **R24** |
| Context tool-change row | desktop `ContextInjectionRow`; Android hides ordinary Context | `developer/message` / non-user `user/message` 的 `tool-addition`/`tool-removal` 可见；skill-catalog / time-context / session-reference / agent-instructions 仍隐藏（桌面 `isVisibleChatNode` 同样隐藏）；recall 标签投到用户气泡 | **missing** → **present** | **R23** / **R25** |
| Deliverables | `Item.Deliverable` | tap opens workspace file preview | **present** | **B** |
| Markdown / code block / tables | `Markdown.kt` | AST + GFM tables / code / file chips | **present** | **D** |
| Copy / like / dislike / branch | `MessageActions` + `FeedbackCategory` | desktop `MessageIconActions`：copy → extraActions（赞/踩，`ui-message-feedback`）→ branch → usage；无分享。无 `sessions.fork` 不画；无 `endSeq` 灰显。会话行菜单仍保留无 seq 的分叉 | **present** | **A** / **P1** / **R35** / **R56** |
| Message / trigger clock | `formatMessageClock` | 同日 `HH:mm`；同年 `clock.md`+时钟；跨年 `clock.ymd`+时钟（zh `m月d日` / `y年m月d日`，en `m/d` / `y-m-d`）；本地时区；无今天/昨天 | **present** | **R13** |
| Turn usage pill | `ComposerStats.kt` `TurnUsageAction` | `TurnUsagePanel`：chip `用量 {n} tok`；popover 在 pill 上方；表头图标 +「本轮用量」左、合计右；无「合计」行；推理挂在输出行 `（其中推理 {n} tok）` | **missing** → **present** | **E** / **R6** / **R12** |
| Composer statistics | Activity / Usage / Context pills | `ComposerStats` 单行 HStack；Activity / Token 用量 / ContextMeter 均为贴 chip 的 popover（在 chip **上方**）。用量 pill 用数据库图标；上下文为 14px 环 + 百分比；弹层文案 `stats.dialog.*` / `context.*`（「工具定义」「对话消息」） | **missing** → **present** | **E** / **R8** / **R11** / **R12** / **R18** |
| Composer queue / steer | busyEnter + `queue.update` | `busySend` + `PromptQueue` edit/remove/steer；排队行按桌面 `QueueDock` 画图片缩略图 / 文件芯片（有 `session.attachment` 或本地 preview） | **partial** → **present** | **E** / **R5** |
| `@` mentions | `MentionMenu.kt` official `@path` / `@"path"` / `@[title](dsh-session:…)` | same tokens + chip row + mention panel | **partial** → **present** | **E** |
| `/` commands | `CommandPopupSheet` `commands.list/execute` | 贴输入框弹层（#21）；`+` 与 `/` 同菜单；不接受附件的指令先 toast 官方句再执行；claimed `/goal` `/plan` 空参数时输入框上方 hint strip。R8：`ComposerTextView` `fixedSize` + 关滚动测高，空文本走 36/52 地板而不是 132 | **missing** → **present** | **E** / **P2** / **#21** / **R4** / **R5** / **R7** / **R8** |
| Header ⋯ overflow | Android `MoreSheet` (not desktop) | **removed** — desktop conversation header has no ⋯; export/feedback on `/` and `+`; rename/fork on the drawer row menu | **hide** | **P2** (#16) |
| Session image bubbles | `session.attachment` + ImageBubble | same cache + retry + original preview | **missing** → **present** | **G** |
| Attachments | `attachments.upload` | image picker + file importer + receipts；landing 无会话也可草稿非图文件，创建后上传 | **missing** → **present** | **E** / **R19** |
| User questions | `UserQuestionCard` `userQuestions.answer` + `UserQuestionStore` + `QuestionReplyRow` | composer 接管卡片；推荐首项默认草稿；多选保留选项+自定义、单选互斥；跳过 `{selected:[]}`；草稿按 request 保存在 AppModel；follow snapshot/resume/`userQuestions`+`inbox` 投影恢复待回答；工具行 `ask.rowTitle`「提问」；可回答时点行「回答」重开。计划审阅 `plan.discuss`「要求修改」且必须有 plan body。晚答 `user-question-reply` 画桌面 `QuestionReplyView` 气泡（仅 `surfaceOp=append` + `outcome=answered`）。无 `ask.review`、无 countdown / Take time | **partial** → **present** | **E** / **R19** / **R20** / **R39** / **R40** |
| Approvals | official `ApprovalCard` takes composer | official card; `accepted` callback clears busy, success drops the row | **partial** → **present** | **E** |
| TodoPanel | dock card above composer | `TodoPanel` expand in place | **missing** → **present** | **E** |
| Goal bar | `goals.get` / `goal.activation` CAS | `GoalBar` + `GoalSheet` pause/resume/clear/edit | **missing** → **present** | **E** |
| Permission mode | catalog/get/set + risk sheet | composer chip 为桌面 `PermissionSelect` 幽灵按钮 + 官方 SVG + EXP 8/500 + 自定义菜单（非系统 Menu，弹层在 chip **上方**，含 Auto review 全行）。**窄屏适配，用户已拍板**：操作栏只显示图标（无文字标签），菜单里保留文字，腾出的宽度给模型名。斜杠 `/permission` 按桌面 `popupSelect` 在弹层内原地列选项 + ✓；landing 选档写入 `draftPermission`，创建会话时 `permissions.set`；危险档确认（居中、先收键盘、不被键盘挡住）；Settings defaults（`auto` 不能当默认） | **partial** → **present** | **E** / **R7** / **R8** / **R13** / **R14** / **R41** |
| Turn trigger row | desktop `TurnTriggerNodeView` | 仅 `waking`（`inbox-next-turn.currentClaimed` 或 idle steer）画触发行；Host 注入的 skill-catalog / time-context 与未唤醒的 tool-jobs 继续隐藏 | **missing** → **present** | **R7** / **R8** |
| Session title live update | Android `refreshTitles` on status | `drawerSessionTitle` 优先非空 title；status 时重拉 `sessions.list`（停后再 4s）；follow `projection key=title` | **partial** → **present** | **R7** |
| Session list relative time | `formatSessionTime` / `timeLabel` | `relativeTime` 桶 + `time.now/{unit}`；空白会话不画时间；审批/计划待审/待回答用 `status.compact.*` 替换时间；标题栏无时钟 | **present** | **R13** |
| Model + effort | two-level picker | composer chip 锚定 `ModelSelect` 两级菜单（模型 / 有推理才出推理等级），弹层在 chip **上方**；空态「暂无可用模型」；landing / 首次连上在 `models.catalog` 到达后即用 catalog 默认模型+effort 显示并可改（不等 snapshot）；无会话时写入 `draftModel`；模型名占剩余宽度 | **partial** → **present** | **E** / **R13** / **R14** / **R41** |
| No “scroll to bottom” FAB | `followBottom` | auto-scroll only | **present** | — |

## 2. Trajectory

| Item | Android | iOS | Tag | Batch |
| --- | --- | --- | --- | --- |
| Build ledger from items | `Trajectory.kt` `buildTrajectory` | `Trajectory.swift` `buildTrajectory` | **present** | **A** |
| 7 cell kinds | system / user / context / compacted / message / tool / subtool | same kinds + reducer `system/message` / compaction | **present** | **A** |
| Compact ledger (事件 + 内容) | `Trajectory.kt` | `TrajRowView` | **present** | **A** |
| Toolbar 时长 / 轮次 / 调用 + search | `TrajectoryToolbar` port | same chips + search field | **present** | **A** |
| Swimlane overview | `TrajectoryTimeline.kt` | `TrajectoryTimeline.swift` + `SwimlaneChart` | **present** | **A** |
| Inspector tabs 概述 / 参数 / 结果 / Schema / 计时 | `TrajectoryDetail.kt` | `TrajectoryRecordInspector` + `TrajectoryInspectorFrame`；桌面 42pt 标题 / 34pt tabs / 概览 94pt 标签列。吞吐窗口 ≤0 用官方 `timingNotAvailable`「不可用」 | **present** | **A** / **R12** |
| JSON tree expand / copy | `TrajectoryJson.kt` | `TrajectoryJsonView` + protocol `TrajectoryJson.swift`；官方浅深主题属性／字符串／数字配色，无灰底圆角卡片 | **missing** → **present** | **H** |
| Request inspector | `TrajectoryRequest.kt` | ledger boundary chip + `TrajectoryRequestInspector` 概述/选项/用量/计时；与记录详情共用原位详情栏 | **missing** → **present** | **F** |
| Official locales | `TrajectoryLocales.kt` ← `ui-trajectory` `locales.ts` | `TrajL` | **present** | **A** |
| Chat / 轨迹 entry | session header + more sheet | session header tabs 对话 / 轨迹 | **present** | **A** |

2026-10-21：重新以官方 `ui-trajectory/TrajectoryTable.tsx` 和 `.module.css` 为权威。`TrajectoryInspectorLayout` 在轨迹区域内切换详情：窄屏 `min(92%, 420pt)` 右侧覆盖、宽屏分栏与拖动调宽，不使用 Android 的全屏 Dialog，也不使用 iOS sheet。记录页签保留最近兼容选择，请求入口按官方重置概述／计时；Markdown 预览与原文分离，请求选项不再截取前四行，Schema 展示真实 parameters。已完成本机 Swift 语法检查／协议构建与共享原生组件烟测；GitHub iOS 模拟器已实际验证轨迹详情、长轨迹请求跳转、标题完整弹层、历史名称滚动、轮次导航、尾部跟随及手动阅读。新建会话顶栏不再重复显示品牌字标，浅深主题截图通过。`TranscriptScrollHost` 直接管理原生刷新子视图，避免 SwiftUI 更新清空 `refreshControl` 属性；CI `39579724518` 的连续分页、旧 Host 分页锚点与首页浅深截图通过。尚未安装新版到用户 iPhone；模拟器通过不代表真机验收。

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
| Portrait / keyboard resize | Host PTY size | Apply Host snapshot dimensions and ordered state changes; primary-screen soft-line reflow with cursor mapping and bounded displaced-row retention | **present** | terminal repair |
| Native key input | Key events | `UIKeyInput` insertion / Delete / Return, no asynchronous TextField buffer reset; serial attachment-bound writes | **present** | terminal repair |

Current iOS context display: `ConversationContextRow` shows the active workspace and work mode below the conversation tabs. Existing sessions use Host metadata read-only (including blank sessions); landing keeps editable draft selectors. This extends the earlier landing-only preset presentation documented in the historical rounds below.

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
| Browser | `BrowserPanel.kt` + `BrowserTabs.kt` HTTP(S)-only, addresses-only checkpoints | implemented + Start Guide 第三项（桌面 `guide.title`「浏览器」） | **present** | **P1** / **H** / **R6** / **R42** |
| Session Inspector | `SessionInspectorPanel` raw/grouped + pick | Start 第四项「会话数据诊断」；**不是**桌面 Guide 卡 | **hide** → **present** | **R42** |

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
| General: fonts, transcript, collapse, busy, performance, log upload, link opening | `GeneralSettingsScreen` | appearance 3 cards; **appearance + fonts local only**（`AppPrefs`，不读写 Host `ui-theme`）；字号为桌面 `FontSizeRow` 步进器 + `px`，「更多字体设置」展开正文/代码/终端字体族与代码·终端字号（默认折叠）；语言跟 Host `locale.preference`（`L.en` 经 AppPrefs，离线不可改）；`collapseTiming` 与桌面一样写 Host `ui-chat.collapseTiming`（`next-input`）；链接行标题「网页链接默认打开方式」 | **present** | **D** / **P1** / **#20** / **R4** / **R30** / **R31** / **R32** |
| Offline gray-out (no unofficial banner) | Android `SettingsScaffold` invents 「远程主机未连接，需连接的操作暂不可用」; desktop has no such chrome | **desktop-first:** no top banner / no extra copy; status 「未连接」; Models / 内置插件 / Agent 预设 / drawer 插件·自动化 gray + unclickable; `lastOps` keeps rows | **missing** → **present** | **H** |
| Qoder CN card | `QoderConnectionCard.kt` last in `llm-qoder` | same PAT write-only + revision fence | **missing** → **present** | **H** |
| Models intro | `modelsSettingsIntro` | 「填入各提供商的 API 密钥即可使用其模型。」 | **partial** → **present** | **P1** / **H** |
| Permission defaults | desktop `PermissionRow` inline Select + risk | same; `auto` cannot be a default | **present** | **E** / **R60** |
| Models provider editor + keys | `ModelsSettingsScreen.kt` | `models.providers*` + `credentials.*` | **present** | **D** |
| 「移动端」 group / 代码自动换行 | Android still has these (audit S2/S5) | wrap is local; no extra mobile group copied | **present** | — |
| Version only on General | audit S3 | General only | **present** | — |
| Account / shortcuts / open config file | desktop-local | — | **hide** | — |
| Phone connection | connections | 抽屉脚（计算机名 + 状态），Settings 无「手机连接」分组。页面 chrome 对齐 Android `ConnectionsScreen`（#43）。用户决定不暴露「连接诊断」/ 复制诊断报告 | **present** | **R13** / **R27** |
| LAN / NSD discovery | `_dshpocket._tcp` protocol=1 + 64-hex instanceId | Removed by product decision; use QR, pairing link, or manual address; update saved addresses manually or rescan | **removed** (product decision) | Formerly **G** |
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
| `Transcript.kt` extra items (`System`, `Compacted`, `Retry`, `TurnFailure`, `Changes`; System folded; Compacted is desktop `CompactionItem` in chat; Retry/TurnFailure rendered; Changes cards when coding view is on; Context tool-addition/removal shown; CommandNode from `command/run`+`command/done`; session-reference labels on the user bubble) | Chat + trajectory | A / D / **E** / **F** / **R22** / **R23** / **R24** / **R25** |
| `TurnTokenUsage.kt` | Inspector + usage | **E done** (`TurnTokenUsage.swift`) |
| `ComposerMetrics.kt` | Composer statistics | **E done** (`ComposerMetrics.swift`) |
| `WorkspaceChanges.kt` | Changed-file cards | **F done** (`WorkspaceChanges.swift`) |
| `TranscriptPublisher` | 50ms assistant-stream coalescing | **F done** (`TranscriptPublisher.swift`) |
| `BrowserPolicy` / `CodePreview*` / `SessionInspector*` / `TrajectoryRequest` | Browser + preview + inspector + request leftover | **F done** |
| `PermissionModels.kt` | Permission pickers | **D done** (`PermissionModels.swift`) |
| `HostUi.kt` | Plugin/settings slots | **D done** (`HostUi.swift`); **E** adds `ui.close` |
| Session search / feedback / attachment / restore / presets / notify / reconnect | drawer + `/`/`+` + connection | **G done** (`SessionSearch` / `SessionFeedback` / `SessionAttachment` / `PresetPolicy` / `PairedDeviceStatus` / `ConnectionRestore` / `TaskNotify`); NSD and `LanDiscoveryPolicy` removed by product decision |

Existing iOS `DSHProtocol` now also covers permissions.get/set, queue.update, commands.list/execute, attachments.upload, userQuestions.answer, goals.get/edit/pause/resume/clear, references.files/sessions, session.export, session.attachment, sessions.search, sessionFeedback.record, workspace.unarchiveSession / insertBefore / insertSessionBefore, presets.list/read/settings, ui.close. Approval `accepted` is required (same as Android `Pocket.answer`).

---

## iOS entry rules (after a batch lands)

- Trajectory: session header tabs 对话 / 轨迹 — data is the current follow transcript (no extra Host op). Hidden when coding view is off.
- Opening a Session that the Host answers `session/not-found` for: drop the row (and refresh `sessions.list`), `sessions.clear()` if it was current, **no toast**. Desktop does not surface that wire code.
- Conversation header has no ⋯ overflow. Export and session feedback live on `/` and `+`. Rename, Copy Session ID, and session-level fork (no seq = last completed turn) live on the drawer session row menu. Assistant turn tails also expose desktop `message.branch` (`sessions.fork` + `endSeq`). Header title uses the same rule as the drawer: current blank → 「新会话」, any other missing title → 「未命名」.
- Terminal / files / jobs: expose when the matching op is in `hello.ops` (same as Android).
- Browser / Session Inspector: desktop Start and session ⋯ do not list them. Do not invent an entry; implementations stay unexposed.
- WorkspaceChanges: consume Host `workspace/changes`; chat cards when `showCodeWorkView` and `workspaceChanges.summary` is advertised; diff sheet needs `workspaceChanges.diff`. Keep the card outside the 「已完成」 fold (attach to the last answer when that answer is visible). Pocket wire flags are `absent | true | false` (Android); do not reject JSON `false`.
- Plugins: drawer when `plugins.list`; market enable when `plugins.setEnabled`; add when `plugins.install`; Settings 「内置插件」 when `plugins.inventory`. Do not embed a plugin WebView (desktop market has none).
- Schedule: **drawer only** (desktop sidebar). Do not add a Settings row.
- Permissions / models / commands / attachments / queue / goals / presets / session search / export / session feedback / unarchive / Host reorder: expose when the matching op is advertised.
- `ui-chat.collapseTiming` is Host-backed (`completion` / `next-input`), same as desktop `TranscriptViewRow`. Do not keep a phone-only copy.
- Appearance and fonts stay on the phone; they must not be written to the remote host.
- Language follows Host `locale.preference` (Android `SharedSetting.Language`). The picker is disabled when that Host field is not writable. `L.en` reads the resolved value via `AppPrefs.language`.
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
- iOS nearby-device discovery has been removed by product decision, not deferred for parity. Local Network permission (`NSLocalNetworkUsageDescription`) remains necessary for LAN host connections and paired-device TCP probes.
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
| 任务 popover | `arrowEdge: .top` + 无 `header` | `ui-jobs` `JobListAction` 从 chip 下方弹出，无返回箭头 | 内容自适应并受视口约束；返回箭头只保留在完整 Host 面板 |
| landing 完全权限确认 | `permission.access` / `currentSession` | `PermissionSelect` 用 `confirm.description`（智能体 / 当前任务）；`settings.permission` 的「新会话 / 后续任务」只给设置默认档。桌面 hero 已是空白会话 | landing 与会话同一套 |
| landing 草稿持久化 | `landingPermissionPersistsAcrossLaunch = false` | InputBar 仅在 `sessionId !== undefined` 时画权限；hero 的选择写在 Host 会话上 | 不写 UserDefaults；杀进程后回默认档 |
| waking | `InboxClaimState` + `applyInboxClaim` + `isWakingTurnTrigger` | `ui-chat` `inbox.ts` / `message.ts`（client.js ~10360–10491） | claim **替换** `currentClaimed`；idle steer 要求 step 1、`claimSeq > turnStart`、`claimedHuman == false`；id 不用 rpcId |

## Round 10 对照清单（桌面 `packages/client` + Round 9 实机 `REPORT_e133`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 已停止任务行 | `jobViewProjection` + `applyJobFollowProjection` | `dsh-jobs/view` `JobView`；`ui-jobs` `JobListAction` `isLive` / `jobDetail` / `dotState` / kill 仅 `running` | Host `job.list` / follow 的 killed `JobView`（`status`+`detail`+`finishedAt`，progress 清空）投影为橙点 + `signal: SIGTERM; cancelled by the user` 单行、无停止按钮。`exit.signal` 仍写成 live `status` 时同样投影。follow `opened` 不得把已结算行救回 running |
| 任务 popover 尺寸 | `JobsPopoverRoster` + `jobsPopoverWidth` / `jobsPopoverMaxHeight` | `JobListAction` `MenuSurface` + `useAnchoredPosition` | 保持单一列表身份并按内容收缩；宽不超过 500pt、两侧各留至少 16pt，高不超过 480pt并保留视口余量 |
| 底栏统计 | `composerStatisticsTokenUnit` | desktop statistics `tok` | 「25.4K tok · 缓存命中 48%」，不再用会被截断的 `tokens` |
| 触发行 | `TurnTriggerRow` `T.fill2` 圆角卡 | `TurnTriggerNodeView` 灰底圆角卡 | 左图标、右时间 + chevron |
| 完全权限确认 | `PermissionRiskDialog` | `RiskConfirmation` 居中对话框 | landing / 会话 / 设置同一套文案，不再整屏 sheet 把内容顶上去 |
| 应用内浏览器 | `keepsChatMounted` + `ChatView` 不卸载 | 桌面 sidebar 叠在会话上 | 关闭浏览器后滚动位置还在；会话仍按最后一行贴底 |
| waking step | `wakingTriggerStep` | `message.ts` `location.kind === "step" && step === 1` | 只有 `openStep`，不再把「有 turn 无 step」当成 step 1 |

## Round 11 对照清单（桌面 `packages/client` + Round 10 实机 `REPORT_b874`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Token 用量 | `ComposerStats` session usage `.popover` | desktop statistics chip `MenuSurface` | 贴 chip 的小气泡；表头 `Token 用量 {exact} tok`；无「合计」行；「缓存命中」不是「缓存命中率」；token 值带 `tok` |
| 已结束任务与清空 | Action 根持有 `JobListState`，面板共享过滤结果 | `JobListAction` 的 settled 单行、producer detail 与 client-side clear | 命令和退出原因在窄屏按桌面截断，保留状态点与耗时；清空仅隐藏已结束记录并同步入口计数，关闭重开不复活，进行中任务不受影响，新结束任务仍出现 |
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
| 抽屉脚顺序 | `SessionDrawer.footer` | `ui-settings-general` `SettingsRoot` `triggerRow`：Settings 左、trailing 动作右 | 设置与远程主机入口同一行；Settings 仍不含「手机连接」 |
| Agent 预设菜单 | `AgentPresetSeat` | `ui-agent-preset` `noDescription` / `seatHint` | 空描述「暂无描述。」；hint「选择新任务使用的 Agent 预设」 |
| 设置默认权限说明 | `SettingsPermissionSelect` | `settings.permission` `description` | 仅「选择新会话的默认权限模式」；触发器是桌面 36pt Select，不再弹 sheet |
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
- `fileOpen.title`/`fileOpen.unknown`、WorkbookPreview 句、`message.referenceSummary`：Round 25。
- `message.contextRecall` / `message.context.instructions.*`：普通 Context 行桌面 `isVisibleChatNode` 也隐藏；Round 25 只把 recall 标签投到用户气泡。
- Android `18af5a8`…`c5f8cdd`：无新交互。Desktop 仍赢过 Android（Compacted + CommandNode）。

## Round 25 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

Host-loaded dist-tag `alpha` 仍是 `0.2.1-alpha.5`（本轮 `npm view` + `ui-chat` / `ui-sidebar-documentpreview` pack 核对）。英文 `fileOpen.*` 是 `Couldn’t`（U+2019），不是 Round 24 leftover 里的 `Can't`。

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| PDF 打开失败 | `pdfDocumentOpenFailed` + `FilePreview` `PdfPreviewBody` | `ui-chat` `fileOpen.title` / `fileOpen.unknown`；`ui-sidebar-documentpreview` `sidebarPdf.failed` | PDFKit `nil` 无引擎 Error，用 `failed` 套 `fileOpen.title`：「无法显示 PDF：无法打开文件」/ `Cannot display PDF: Couldn’t open file`。去掉自撰 `Could not open file` |
| Workbook 失败句 | `workbookPreviewErrorMessage` | `sidebarExcel` `invalid` / `tooLarge`；`sidebarOffice` `changed`（chunk 读中途换源） | Round 24 当自撰的英文就是桌面 excel locale，保留；不另发明句 |
| 用户气泡引用摘要 | `applyingUserReferenceLabels` + `referenceSummaryText` | `ui-chat` `ReferenceLabelProjector` / `message.referenceSummary`；Host `SessionReferenceSource` | `user/message` `source.kind=session-reference` 仍隐藏为 Context 行（`isVisibleChatNode`）；`seq-1` 用户气泡下「引用会话 · {labels}」/ `Referenced session · {labels}`；分隔 zh `、` / en `, ` |
| 普通 Context 行 | `contextItemIsVisible` | `isVisibleChatNode`：无 tool-addition/removal 的 Context 隐藏 | `message.contextRecall` / `message.context.instructions.*` 只在可见 ContextInjectionRow 上用。普通 recall / agent-instructions **桌面也不画行**，不发明 |

本轮核对后**不改**、确认已对齐或平台/hide：

- `chat.turnNavigation.*`：桌面长 transcript 右侧跳轮 + `TurnNavigator`；phone 无源码级窄屏切片，不发明一层。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- 桌面 popover 系统箭头 / Think·CompactionItem·Command 收起无 hover 换 chevron：仍平台残留。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 绿点 / 会话行 spinner / 标题无 running spinner / 抽屉脚连接入口：已对齐。Android Settings「云端设备」不搬。
- Android `18af5a8`…`c5f8cdd`：无新交互（外观本机、发布 bump、`skills.list`、无 session 目录）。Desktop 仍赢。

## Round 27 对照清单（Android `ConnectionsScreen` @ `c5f8cdd`；桌面 Settings「手机连接」是 Host QR，不是 controller）

Merged as `#43` / `e55a2de`. Phone is the controller — this page twins Android `Screens.kt` `ConnectionsScreen` / `ConnDeviceRow`, **not** desktop `settings.section` id=`pocket`（Host 「手机连接」/ Phone connection QR）。

| 模块 | iOS | 对照的源码 | 对齐点 |
| --- | --- | --- | --- |
| 标题 | `L.connections()` | Android `L.connections()` | 「连接」/ Connections。`L.phoneConnection()` 仅 Host 文案存根，UI 不引用 |
| 空已配对 | `sortedProfiles.isEmpty` 不画节 | `if (sorted.isNotEmpty())` | 无设备时隐藏整块「已配对设备」，不留「未连接」占位 |
| 附近设备 | `model.nearby.isEmpty` 不画节 | `if (nearby.isNotEmpty())` | 空则隐藏；mDNS 未配对过滤不变 |
| 操作行 | 配对/附近之后一张卡：扫码 / 输入地址 | `ConnActionRow` 全宽 icon+title+chevron | 不再是顶栏并排黑 chip |
| 已配对行 | `ConnDeviceRow` + `connectionsStatusLine` | `buildConnStatusLine` / `ConnDeviceRow` | 8pt 状态点、名、`在线 · Tailscale · 当前`、`host:port`、非当前「切换」、管理 chevron。点行开管理，Switch 才连接 |
| Host 文案 | `nameHint` / `pairTimeout` | 既有 iOS copy | 用户可见 Host 称呼仍是「远程主机」 |
| Overflow | 无。用户决定去掉「连接诊断」/「复制诊断报告」，空 ⋯ 一并删除 | Android 另有 `NEARBY_WIFI_DEVICES` + 复制诊断报告 | iOS Local Network 由 `NWBrowser` 系统提示，无对等 request API |

## Round 28 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.1`）

`npm view`：`alpha` 仍是 `0.2.1-alpha.5`。`next` 已发 `0.2.1-rc.1`。对本轮 pack 的 ui-chat / conversation / workspace / sidebar / plugin-manager / jobs / commands / permission-presets / model-selection / agent-preset / plan / tool / primitives / deliverables / settings-plugins / sidebar-files / sidebar-documentpreview：locale 与组件文件相对 alpha.5 **无增量**（仅 `package.json` 版本/依赖，以及 `ui-sidebar` `localBuildVersion` 字符串 `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.1-ed75efe`）。没有新 package API 可搬。

Android `main` `729ef2e..c5f8cdd`（4 commits）仍是既有项：`18af5a8` 外观本机、`9e580d4` 发布 bump、`d30825c` `skills.list`、`c5f8cdd` 无 session 目录。无新 controller 交互（Settings 下的连接行见 skip）。

源码核对 **present**（相对桌面；连接页相对 Android `ConnectionsScreen`）：

| 项 | iOS 证据 | 对照 |
| --- | --- | --- |
| 未读绿点 | `CompletionReminders.accept` + `sidebarSessionLeading` + `SidebarSessionLeadingView` 14pt 槽、半径 `3/14`；idle+未归档才画 | `ui-workspace` `SessionStatusDots` / `StateDot` |
| 标题无 running spinner | `ChatView.header` 只有抽屉 / 标题或 crumbs / Start；运行态在 transcript `RunningStatusRow` | `ConversationSessionHeader` 无 spinner |
| 连接页（#43） | `ConnectionsView` + `ConnectionsLayout` | Android `ConnectionsScreen` / `ConnDeviceRow` |
| 抽屉脚连接入口 | `SessionDrawer.footer`：`footerPeerDevice` 在 Settings **同一行靠右**；`SettingsView` 仅 General/Models/Presets/Plugins | `ui-settings-general` `SettingsRoot` `triggerRow` |
| 鲸尾 shimmer | `RunningWhaleTail` + `TextShimmer` | `ui-chat` `RunningWhaleTail` / `TextShimmer` |
| 任务两次点按停止 | `jobKillPress` + `KILL_ARM_MS` 3s；`JobsPanel.killButton` 是 `Button`，不是 `TapGesture(count: 2)` | `ui-jobs` `JobListAction` `kill.confirm` |
| 插件 (i) | `PluginsScreen` `pluginInfoLabel` / `pluginInfoDescription` popover | `ui-plugin-manager` `infoLabel` / `infoDescription`（市场页，不是内置插件 inventory） |
| 侧栏打开链接 | `openChatLink`：`sidebar` → `BrowserPanel`；`new-tab` → 系统浏览器 | `ui-chat.linkOpening` |
| 斜杠完整目录、无计数 | landing 只注入 `/file` `/model`；goal/plan/… 与技能来自 `commands.list` / `skills.list`；`commandMenuSectionTitle` 无 N | Host catalog；桌面分组标题无 count |

本轮核对后**不改**（R26 skip 仍成立；桌面 rc.1 未提供新 API）：

- `chat.turnNavigation.*`：桌面长 transcript 右侧跳轮；phone 无源码级窄屏切片，不发明。
- `chat.toBottom` FAB：桌面跟随滚动按钮；phone 仍自动贴底，不发明。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 桌面 `DisclosureRow` hover 才把图标换成 chevron：触屏无 hover。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- Android Settings「移动端」分组下的「连接」（文档旧称「云端设备」）不搬。桌面 `ui-settings` **没有** controller 侧连接节；pocket `settings.section` id=`pocket` 是 **Host** QR「手机连接」，且 `installHostUi` 的 phone 窗口提前 return、不注册该节。iOS 入口只在抽屉脚。Desktop 赢。
- Android `18af5a8`…`c5f8cdd`：无新交互。

## Round 30 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.1`；Android `c5f8cdd`）

本轮**怀疑式**源码核对，不复读 R26–R28 的 NO_PR 句。发现可落地缺口：iOS 外观/字体仍走 Host `ui-theme` 镜像（`setAppearance` / `setFontSize*` 写 Host；`applyHostMirroredPrefs` 读 Host；断线 `!ready` 把外观打回「跟随系统」、字号打回 14）。对话渲染读 `AppPrefs.fontSize`，设置却不写 AppPrefs，离线改字号还会弹出「远程主机设置尚未连接…」。Android `#63` / `18af5a8` 已把外观改成本机；字体 Android 仍 Host-backed。控制器规则 + 硬约束「外观/字体保持本机」：iOS 两者都只写 `AppPrefs`，不 mutate Host。

### 必须核对

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 1. 桌面 package | **PASS**（无 locale/API 增量可搬） | Host 加载 dist-tag `alpha`=`0.2.1-alpha.5`。`npm view` `next`=`0.2.1-rc.1`，`latest` 仍是旧线（如 ui-chat `0.1.2-alpha.2`）。pack 对比 ui-chat / conversation / workspace / sidebar / plugin-manager / jobs / commands / permission-presets / model-selection / agent-preset / plan / tool / primitives / deliverables / settings-plugins / sidebar-files / sidebar-documentpreview / settings / trajectory / schedule：locale 与组件相对 alpha.5 **无增量**；仅 `package.json` 版本，以及 `ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.1-ed75efe`。 |
| 2. Android `729ef2e..c5f8cdd` | **PASS**（#63 外观本机此前未落地 → 本轮修；其余已有） | `#63` `18af5a8`：Android `SharedSetting` 去掉 `Appearance`；`AppPrefs.appearance` 本机。iOS 修前仍 `SharedSetting.appearance` + `hostSettings.write(.appearance)`。`#64` 发布 bump：无 UI。`#65` `d30825c` `skills.list`：iOS `PocketClient.listSkills` + `CommandPolicy` 技能组。`#66` `c5f8cdd` 无 sessionId 目录：`listCatalogArgs(nil)` → `{}`；`CommandMenuOverlay.load` `sessionId = model.chat?.sessionId`（landing 为 nil）；`commandMenuClientRows(landing:)` 只注入 `/file` `/model`，goal/plan/… 与技能来自 Host 目录。插件侧（Android `plugin/src/extra-ops.js`）才按默认 preset/workspace 列目录；iOS 客户端不硬编码。 |
| 3. Connections | **PASS** | `ConnectionsView` / `ConnDeviceRow` / `connectionsStatusLine` vs Android `Screens.kt` `ConnectionsScreen` / `ConnDeviceRow` / `buildConnStatusLine`：空配对/附近不画节；标题 `L.connections()`「连接」；底卡扫码/输入地址；行 8pt 点 + `在线 · route · 当前` + host:port + 非当前「切换」+ 管理 chevron。点行开管理，Switch 才 `connect`。Android `CompatibilityBanner` / `NEARBY_WIFI_DEVICES` 不搬（iOS 配对走 `compatibilityError`；Local Network 由系统提示）。 |
| 4. 矩阵 partial / 「留给」 | **PASS**（已对齐未改文档，或后续轮已闭环） | 表内现存 `**partial**` 均为 `**partial** → **present**`。Round 22「留给 Round 24+」的 CommandNode 已由 R24 落地。无未闭环 partial。 |
| 5. 交互小巧思 | **PASS** | 未读绿点：`CompletionReminders` + `sidebarSessionLeading` + `SidebarSessionLeadingView`（idle+未归档 3/14 of 14）。标题无 running spinner：`ChatView.header` 仅抽屉 / 标题或 crumbs / Start；运行态 `RunningStatusRow` 鲸尾 shimmer。云端设备不进设置：`SettingsView` 仅 General/Models/Presets/Plugins；入口 `SessionDrawer.footerPeerDevice` 在 Settings 同一行靠右。 |
| 6. Composer / 斜杠 / Ask / 用量 / 任务 / 轨迹 / 抽屉 / 设置抽查 | **PASS**（无新「桌面有、iOS 缺」的语义） | 斜杠分组「添加/指令/技能」无数量（`commandMenuSectionTitle`）。Ask 工具行 `ask.rowTitle`，无 `ask.review` 面板。用量 pill 上方 popover。任务两次 Button 点按停止。轨迹 `ui-trajectory` 账本+inspector。抽屉搜索/归档/footer。设置无 Account/shortcuts/open config。中文用户可见 Host 称呼为「远程主机」（`L.t`）；`L.phoneConnection()`「手机连接」仅 Host 文案存根，UI 用「连接」。 |

本轮修复：

| GAP | fix |
| --- | --- |
| 外观读写 Host `ui-theme.preference`；断线/Host 事件打回「跟随系统」 | `setAppearance` 只写 `AppPrefs`；`SharedSetting` 删除 appearance；`applyHostMirroredPrefs` 不再读 Host 外观 |
| 字号/字体写 Host；对话读 `AppPrefs` 却从未写入；离线改字号报 Host 未连接 | `setFontSize*` / family 只写 `AppPrefs`；删除全部 `ui-theme` SharedSetting；断线保留本机值 |
| 误把 Host 窗口 chrome 同步到手机 | `isPhoneLocalThemeField`；`HostSettings.write` 若再带入 phone-local 字段 `fatalError` |

本轮核对后**不改**（平台 / hide / 禁止发明）：

- `chat.turnNavigation.*`：桌面长 transcript 右侧跳轮；phone 不发明。
- `chat.toBottom` FAB：phone 仍自动贴底。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 桌面 `DisclosureRow` hover 才把图标换成 chevron：触屏无 hover。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- Android Settings「移动端」分组下的「连接」不搬。桌面 `ui-settings` 没有 controller 连接节；iOS 入口只在抽屉脚。
- Android 字体仍 Host-backed（`SharedSetting.FontSize`…）。冲突以控制器为准：Host `ui-theme` 是远程窗口 chrome，不写回 Host。
- Android `CompatibilityBanner`：iOS 在配对/连接失败时用 `compatibilityError`，不发明连接页横幅。

## Round 31 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.1`；Android `c5f8cdd`）

Host 加载 dist-tag `alpha` 仍是 `0.2.1-alpha.5`。`next`=`0.2.1-rc.1`，locale/组件相对 alpha.5 无增量。Android `729ef2e..c5f8cdd` 仍是 4 个提交（外观本机 / 发布 / skills.list / 无 session 目录），无新交互。

本轮**怀疑式**源码核对，不复读 R26–R30 的 NO_PR 句。发现可落地缺口：R30 把外观/字体**存储**改成本机，但通用设置仍是会话字号 **Menu 下拉**（`10…22 px`），没有桌面 `ui-theme` `FontSettingsGroup`。桌面/Android 是：会话字号步进器 + `px` +「更多字体设置」展开（默认折叠）正文/代码字体族、代码字号、终端字体族、终端字号。AppPrefs 与 setter 早已有代码/终端尺寸与字体族，对话代码块读 `LocalFonts.code()`，终端读 `terminalFontSize`，但用户不能改。

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 字号行 | `SettingsFontSizeRow` | `ui-theme` `FontSizeRow` / `FONT_SIZE_SPECS` | 步进 ±1；触屏常显箭头（桌面 hover 才显）；值与 `px` 分开；text 10–22 / code 10–16 / terminal 10–20；缺省 14/11/13 |
| 更多字体 | `fontsExpanded` 初值 false | `FontSettingsGroup` `useState(false)` | 每次进入通用设置折叠；aria「更多字体设置」 |
| 展开顺序 | textFamily → codeFamily → codeSize → terminalFamily → terminalSize | `FontSettingsGroup` 同序 | 文案 `settings.theme` zh/en 全句（不用 Android 缩短句） |
| 字体族 | `SettingsFontFamilyRow` | `FontFamilyRow` | blur / Enter 提交；`normalizeFontFamily`；max 200；占位「默认」 |
| 本机写入 | `setFontSize*` / `set*FontFamily` → `AppPrefs` | 控制器规则；Android 字体仍 Host-backed | 离线可改，不 mutate Host `ui-theme` |

本轮核对后**不改**（平台 / hide / 禁止发明）：

- `chat.turnNavigation.*`：桌面长 transcript 右侧跳轮；phone 不发明。
- `chat.toBottom` FAB：phone 仍自动贴底。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 桌面 `DisclosureRow` / `FontSizeRow` hover 才显步进箭头：触屏常显。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- Android Settings「移动端」分组下的「连接」不搬。
- Android `CompatibilityBanner`：不发明连接页横幅。

## Round 32 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.1`；Android `c5f8cdd`）

本轮**怀疑式**源码核对，不复读 R26–R31 的 NO_PR 句。#46 / `a30dc51` 已在 `main`。

### 直播版本

| 源 | 判定 | 证据 |
| --- | --- | --- |
| 桌面 dist-tag | **PASS**（无 locale/API/组件增量，不 bump） | 2026-10-17 `npm view`：`alpha`=`0.2.1-alpha.5`，`next`=`0.2.1-rc.1`，`latest` 仍是旧线。pack 对比 21 包（theme / settings / chat / conversation / workspace / sidebar / jobs / commands / tool / permission-presets / model-selection / plugin-manager / agent-preset / plan / primitives / deliverables / settings-plugins / sidebar-files / sidebar-documentpreview / trajectory / schedule）：locale 与组件相对 alpha.5 **无增量**。唯一文件差是 `ui-sidebar` `lib/client.js` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.1-ed75efe`。 |
| Android `main` | **PASS**（无新 commit） | `gh` tip 仍是 `c5f8cdd44689784376cf2a4ecab5117fc1b4c79b`（#66 无 session 目录）。`compare/c5f8cdd...main` `ahead_by: 0`。`729ef2e..c5f8cdd` 仍是 4 个提交：`18af5a8` 外观本机 / `9e580d4` 发布 / `d30825c` skills.list / `c5f8cdd` 无 session 目录。无新 controller UI。 |

### FontSettingsGroup / General（#46 后）

桌面 `ui-theme` `FontSettingsGroup` / `FontSizeRow` / `FontFamilyRow` / `FONT_SIZE_SPECS` / `settings.theme` zh+en（alpha.5 `client.js` ~1011–1356、1463–1516）。iOS `SettingsView` + `ThemeFontSettings.swift`。

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 会话字号步进器 + `px` | **PASS** | `SettingsFontSizeRow` role `.text`；范围 10–22 默认 14；触屏常显箭头（桌面 hover 才显） |
| 「更多字体设置」默认折叠 | **PASS** | `@State fontsExpanded = false`；`themeFontSettingsStartCollapsed`；aria `fontSize.more` |
| 展开顺序 | **PASS** | textFamily → codeFamily → codeSize → terminalFamily → terminalSize = 桌面 `FontSettingsGroup` |
| 代码/终端规格 | **PASS** | code 10–16/11；terminal 10–20/13 |
| 字体族 | **PASS** | blur/Enter 提交；`normalizeFontFamily` 与桌面同一套 generic + 去引号/控制符；max 200；占位「默认」 |
| 文案 | **PASS** | 全句桌面 `settings.theme`（不用 Android 缩短句） |
| 本机写入 | **PASS** | `setFontSize*` / family → `AppPrefs`；`SharedSetting` 无 ui-theme；`isPhoneLocalThemeField` |
| 外观三卡 | **PASS** | 浅色/深色/跟随系统；只写 `AppPrefs` |
| General 其余 Host 行 | **PASS** | 权限 / 语言 / 工作步骤 / collapseTiming / 代码工作视图 / 繁忙发送 / 性能 / session-log / 链接打开 / 代码换行 / 版本 |
| Settings 壳 | **PASS** | 仅 General / Models / Presets / Plugins。无 Account / shortcuts / open-config / 连接 |

### 抽查

| 项 | 判定 | 证据 |
| --- | --- | --- |
| Composer | **PASS** | 占位、计划 chip、权限/模型 chip 上方弹层、+ selector、测高 36/52、停止一次点按（任务才是两次） |
| 斜杠 | **PASS** | 添加/指令/技能无 N；landing 只注入 `/file` `/model`；其余来自 `commands.list` / `skills.list` |
| Ask 工具行 | **PASS** | `ask.rowTitle`「提问」；waiting/pending；trailing「回答」重开。无 `ask.review` 面板 |
| 用量 pill | **PASS** | 数据库图标；popover 在 chip 上方；本轮用量 `message.turnUsage.*` |
| 任务面板 | **PASS** | 进行中/已结束；`jobKillPress` 两次 Button，不是 `TapGesture(count: 2)`；SIGTERM 整句 |
| 轨迹 | **PASS** | 账本 + inspector；吞吐空窗 `timingNotAvailable` |
| 抽屉绿点 / spinner | **PASS** | idle+未归档 3/14 of 14 绿点；运行 spinner 仅会话行；标题栏无 running spinner |
| 连接入口 | **PASS** | `SessionDrawer.footerPeerDevice` 在 Settings **同一行靠右**。页面 `ConnectionsView` 对齐 Android `ConnectionsScreen`。Settings 无连接分组 |
| 中文 Host 称呼 | **PASS** | 用户可见「远程主机」。`L.phoneConnection()`「手机连接」仅 Host 存根 |

### 本轮修复

| GAP | fix |
| --- | --- |
| 语言选择写 Host `locale.preference`，但 `L.en` 读从未写入的 `AppPrefs.language`（#11 删了 AppPrefs 写），iOS 文案不随 Host/选择切换。Android `AppPrefs.language` getter 直接读 Host。 | `setLanguage` / `applyHostMirroredPrefs` 把解析后的语言写回 `AppPrefs`（`controllerLanguageIsZh`）。选择器 `enabled: shared.writable(.language)`（Android 离线不可改）。外观/字体仍只写本机，不碰 `ui-theme`。 |

### 本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*`：桌面长 transcript 右侧跳轮；phone 无窄屏切片，不发明。
- `chat.toBottom` FAB：phone 仍自动贴底。用户禁止。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 桌面 `DisclosureRow` / `FontSizeRow` hover 才换 chevron / 显步进箭头：触屏常显图标+箭头。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- Android Settings「移动端」分组下的「连接」/ 审批通知 / CompatibilityBanner：不搬。桌面 `ui-settings` 没有 controller 连接节；`installHostUi` phone 窗口不注册 Host QR「手机连接」。iOS 入口只在抽屉脚。
- Android 字体仍 Host-backed。冲突以控制器为准：外观/字体只写 `AppPrefs`。
- npm `next` `0.2.1-rc.1`：无新 API，Host 仍加载 `alpha.5`。

## Round 34 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `c5f8cdd`）

按 Android 提交逐条核对交互微细节。用户点名的绿点 / 会话行 spinner / 抽屉脚连接入口：**源码已对齐**，本轮不改。`next` 已从 Round 33 的 `0.2.1-rc.1` 升到 `0.2.1-rc.2`；pack 对比仍只有 `package.json` 与 `ui-sidebar` `localBuildVersion` 字符串，无 locale/组件增量。

Android `4052adb` / `50257c1` / `825b235`：落地页首条发送立刻画出 pending 用户气泡，同一 `requestId` 贯穿 create → follow → `prompt`。桌面 blank session 的 `TranscriptReducer.echo` 是同一交互。iOS 修前 `FirstPrompt` 只是空字段，`createSessionAndSend` 先清 composer 再等会话。

| 模块 | iOS | 对照的源码 | 对齐点 |
| --- | --- | --- | --- |
| 首条 pending echo | `FirstPrompt` + `firstPromptPendingItem` / `firstPromptVisibleItems` | Android `Pocket.newSession` / `ChatRoot.visibleChat`；桌面 `TranscriptReducer.echo` `Item.User.pending` | 点发送立刻切到对话、气泡 `local-{requestId}`、opacity 0.6；`initializeChat` 用同一 id seed，不重复行 |
| 发送中 | `firstPromptSendingLabel` | 桌面 `queue.sending`「发送中…」；Android `firstPromptStatus` | 会话尚未存在时没有 QueueDock，用同一句官方文案。失败自动把原文写回 composer（不发明「重新编辑」按钮） |
| 发送锁 | `firstPromptBlocksComposerActions` | Android `firstPrompt == null` 才允许 send/plus/perm/model/Start | 输入框仍可编辑下一条草稿；发送与斜杠/Start 锁住 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` FAB / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / Settings 嵌套「云端设备」：仍 **hide**。入口只在抽屉脚。
- Android `prepareSidebarSession`（打开文件/终端/@ 时先建空白会话）：桌面 landing 已有 blank session；iOS landing 用无会话 hero 替代（R19）。本轮只补首条 echo，不发明空白会话。
- 消息行 branch：R34 误读为「桌面只有 share」。桌面 `TurnTailNodeView` 在 `session/fork` 时接线 `onBranch`。留给 Round 35。
- 审批通知开关：Android 本机偏好，桌面 Settings 无此行。

## Round 35 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `c5f8cdd`）

直播核对（2026-10-17）：`alpha` 仍 `0.2.1-alpha.5`。`next` 仍 `0.2.1-rc.2`。pack 对比 ui-chat / conversation locale 与 `MessageIconActions` **无增量**（仅 `package.json`）。Android `main` tip 仍 `c5f8cdd`，其后 0 commits。

#48 后怀疑式重审：落地页 FirstPrompt echo / `queue.sending` / send·plus·perm·model·Start 锁已对齐。用户行无 `onBranch`（桌面 `UserMessageNodeView` 同样不传）。本轮发现 R34 把桌面消息行读成「只有 share」是错的。

| 模块 | iOS | 对照的源码 | 对齐点 |
| --- | --- | --- | --- |
| 助手消息行 branch | `MessageActions` + `messageBranchChrome` | 桌面 `ui-chat` `MessageIconActions` / `TurnTailNodeView`；Android `Chat.kt` `messageBranch` | 顺序 copy → 赞/踩 → branch → 用量 → 时钟。`sessions.fork` 才画；`endSeq` 有则 `forkCurrent(atSeq:)`，无则灰显 `message.branchUnavailable`。用户行不画。会话行菜单仍保留无 seq 分叉 |
| 文案 | `messageBranchLabel` | 桌面 `message.branch` / `message.branchUnavailable` | 「在新对话中分支」/「仅可从已完成轮次的最后一条消息分支」 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*`：桌面长 transcript 右侧跳轮；phone 无窄屏切片，不发明。
- `chat.toBottom` FAB：桌面无独立 FAB；phone 仍自动贴底。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 桌面 `DisclosureRow` hover 才把图标换成 chevron：触屏无 hover。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- Settings 下挂连接：必须留在抽屉脚。桌面 `ui-settings` 没有 controller 连接节。
- Android `CompatibilityBanner`：不发明连接页横幅。
- Android `prepareSidebarSession`：桌面 landing 已有 blank session；iOS landing 用无会话 hero 替代（R19）。不发明空白会话。
- 审批通知开关：Android 本机偏好，桌面 Settings 无此行。

## Round 36 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `c5f8cdd`）

直播核对（2026-10-17）：`alpha` 仍 `0.2.1-alpha.5`。`next` 仍 `0.2.1-rc.2`。21+ 包 pack 对比 locale / 组件相对 alpha.5 **无增量**（仅 `package.json`；`ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-…` → `0.2.1-rc.2-332895e`）。Android `main` tip 仍 `c5f8cdd`，`compare/c5f8cdd...main` `ahead_by: 0`。

#49 后怀疑式重审 MessageIconActions / TurnTail / FirstPrompt / composer / 会话行 / Connections：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| MessageIconActions 顺序 | **PASS** | 桌面 `ui-chat` `MessageIconActions`：copy → extraActions（赞/踩，`ui-message-feedback`）→ branch → usage+clock。iOS `MessageActions` 同序。用户行只 copy+start clock，无 `onBranch`（`UserMessageNodeView`） |
| TurnTail branch 接线 | **PASS** | `sessions.fork` 才画；`forkAt(data.seq)` = `turn/end` seq = iOS `endSeq`。无 `endSeq` 灰显 `message.branchUnavailable` |
| FirstPrompt echo | **PASS** | #48：pending `local-{requestId}`、`queue.sending`、send/plus/perm/model/Start 锁 |
| Composer / 会话行 / Connections | **PASS** | 无新「桌面有、iOS 缺」的可搬语义。连接入口仍在抽屉脚 |
| fork 子会话标题 | **GAP** | 桌面 `ISessions.fork({ increaseTitle: true })`（`dsh-client-runtime` `increasedForkTitle` / `SessionRuntime.fork`；`TurnTailNodeView` `forkAt` 与 `ui-workspace` `forkSession` 都传）。Host 请求只有 `sessionId`/`atSeq`。源列表有持久化 title 时把**子会话**改成 `Title (1)` / 递增 `(N)` 或 `（N）`。iOS 修前只 `sessions.fork` 后打开。Android `Pocket.forkSessionFrom` 同样没有，桌面赢 |

| 模块 | iOS | 对照的源码 | 对齐点 |
| --- | --- | --- | --- |
| fork 子会话标题 | `forkChildTitle` + `forkSession` 先 rename 再打开 | `dsh-client-runtime` `increasedForkTitle` / `SessionRuntime.fork`；`ui-chat` `forkAt` `increaseTitle: true` | 无持久化 title 跳过改名；`(N)` / `（N）` 递增保留括号样式；其它追加 ` (1)`；改名失败不打开（子会话已在列表） |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*`：桌面长 transcript 右侧跳轮；phone 无窄屏切片，不发明。
- `chat.toBottom` FAB：phone 仍自动贴底。
- `AskQuestionRow` `ask.review`：phone 不发明 review 面板。
- 桌面 `DisclosureRow` hover 才把图标换成 chevron：触屏无 hover。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：仍 **hide**。
- Settings 下挂连接：必须留在抽屉脚。桌面 `ui-settings` 没有 controller 连接节。
- Android `CompatibilityBanner`：不发明连接页横幅。
- Android `prepareSidebarSession`：不发明空白会话。
- 审批通知开关：Android 本机偏好，桌面 Settings 无此行。
- 会话行 pin：桌面行内 pin 标；iOS 置顶分区（窄屏布局）。菜单已有置顶。
- 桌面 `data-actions-reveal: hover`：触屏无 hover，助手行动作常显。

## Round 39 对照清单（桌面 `@deepseek-ai/dsh-client-ui-user-questions@0.2.1-alpha.5`；Android `56dcaa9`）

Android `c5f8cdd...56dcaa9` 一笔：`feat(android): 补齐用户选择卡片与桥接状态同步`。桌面 Host 仍加载 `alpha`=`0.2.1-alpha.5`（不 bump `next`）。冲突以桌面 `QuestionComposer` / `UserQuestionStore` 投影语义为准。

| 模块 | iOS | 对照的源码 | 对齐点 |
| --- | --- | --- | --- |
| 推荐选项 | `parseRecommendedLabel` + 首项默认草稿 | `ui-user-questions` `parseRecommendedLabel` / `recommendedFirstOption` | 只认选项末尾 `(recommended\|推荐)` / 全角括号；提交仍用 wire label；未提交 |
| 单选 / 多选 / 自定义 | `questionAnswers` | `QuestionComposer` `choose` / `draftCustom` / `submitDrafts` | 多选保留 selected+custom；单选自定义清空 selected；单选点选项立刻下一题 |
| 跳过 | `QuestionDraft.skipped` | `skipQuestion` → `{ selected: [] }` | 跳过只清当前题；最后一题跳过即提交；提交前检查全部 completed |
| 草稿恢复 | AppModel `questionDrafts` / `questionPageIndex` | desktop Session `createQuestionDraftStore`；Android `rememberSaveable` | 收起/切会话/重连同 request 保留页码与草稿。不跨设备同步 |
| 投影恢复 | `UserQuestionStore` | Android `UserQuestionStore`；桌面 `useProjection("userQuestions")` `view.active` + inbox `user-question-reply` | snapshot/resume/`userQuestions`/`inbox` 合并 live offer；continued 不被 foreground close 清掉；queued reply 隐藏；submitted 竞态；跨会话隔离；重连清 watermark |
| 卡片 chrome | `UserQuestionCard` 头/滚动体/脚 | desktop capped card；Android sticky header/footer | 长问题滚动不挡收起/提交。continued 用 `wait.continued` |
| 提交失败再投 | `question.state == continued` 解开 busy | desktop `error.resubmit` | waterfall 未确认但投影已 continued 时重开同一草稿 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `AskQuestionRow` `ask.review` 只读回看：phone 不发明 review 面板。
- 桌面 countdown / `wait.takeTime` / focus 暂停：Host 插件限时等待；Android `56dcaa9` 卡片也未画倒计时。
- `chat.turnNavigation.*` / `chat.toBottom` FAB / hover chevron：仍 skip。
- Account / shortcuts / open config / Settings 下挂连接 / CompatibilityBanner / 审批通知：仍 **hide**。
- 插件 `user-question-hook` / `parity-ops` 在 Host（dsh-android）；iOS 只消费 pocket 帧。

## Round 40 对照清单（桌面 `@deepseek-ai/dsh-client-ui-user-questions@0.2.1-alpha.5`；Android `56dcaa9`）

直播核对：`alpha` 仍 `0.2.1-alpha.5`。`next`=`0.2.1-rc.2`。ui-user-questions / ui-chat / ui-conversation pack 对比 locale 与组件相对 alpha.5 **无增量**（仅 `package.json` 版本）。Android `compare/56dcaa9...main` `ahead_by: 0`。`c5f8cdd...56dcaa9` 仍是 #51 已搬的那一笔（卡片 + Store + Host 插件）。Host 插件不搬。

#51 后怀疑式重审 QuestionComposer / UserQuestionStore / 投影：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 推荐首项 / 单选多选 / 跳过 / 草稿 / 重连 | **PASS** | `parseRecommendedLabel` / `questionAnswers` / `UserQuestionStore` 与桌面 `submitDrafts`、`useProjection("userQuestions")`+inbox 合并一致。无 pager 时 Next 以 `completed`（含 skipped）为准 |
| `plan.discuss` | **GAP → 本轮** | 桌面 `plan.discuss`「要求修改」/ Request changes；修前 iOS/Android 自撰「继续讨论」。动作仍是 dismiss/hide |
| `planReviewOf` | **GAP → 本轮** | 桌面要求 `detail != undefined`；修前 iOS 无 plan body 也走计划卡 |
| 晚答气泡 | **GAP → 本轮** | 桌面 `questionReplyDefinition` 独占 `user/message` `source.kind=user-question-reply`。iOS/Android 把它当普通 Context 藏掉。桌面赢：`surfaceOp=append` + `outcome=answered` 画 `QuestionReplyView` |

| 模块 | iOS | 对照的源码 | 对齐点 |
| --- | --- | --- | --- |
| 计划讨论 | `questionPlanDiscuss` | `ui-user-questions` `plan.discuss` | 「要求修改」/ Request changes；点按收起，不提交 skip |
| 计划路由 | `planReviewOf` | `planReviewOf` | 单题 + plan-review + 有 detail + ≤2 选项 + approve |
| 晚答气泡 | `Item.QuestionReply` + `QuestionReplyRow` | `QuestionReplyView` / `replyPairsOf` | 右对齐；收起摘要；展开问答对；复制 `replyClipboardText`。非 append / 非 answered 不画 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `AskQuestionRow` `ask.review` 只读回看：phone 不发明 review 面板。
- 桌面 countdown / `wait.takeTime` / focus 暂停：Host 插件限时等待；Android `56dcaa9` 卡片也未画倒计时。
- `chat.turnNavigation.*` / `chat.toBottom` FAB / hover chevron：仍 skip。
- Account / shortcuts / open config / Settings 下挂连接 / CompatibilityBanner / 审批通知：仍 **hide**。
- 插件 `user-question-hook` / `parity-ops` 在 Host（dsh-android）；iOS 只消费 pocket 帧。

## Round 41 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`）

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Composer 模型座 | `composerResolvedModel` / `modelEffortLabel` / `ModelChipMenu` | `ui-model-selection` `ModelSelect` trigger：`model.name` + effort（`reasoning.defaultEffort` / `effort.providerDefault`） | landing / 首次连上在 catalog 到后即显示默认模型名 + 推理强度，菜单可改；与 `models.catalog` default 及后续 `modelSelection` 投影同步 |
| 权限 chip | `permissionChipTriggerShowsLabel = false` | 桌面 `PermissionSelect` 触发器有文字；**窄屏适配，用户已拍板** | 操作栏只留图标；菜单仍有官方标签 |
| 模型名宽度 | `composerModelNameUsesRemainingWidth` | 窄栏下模型名尽量完整，截断只在真放不下 | 权限去文字后把剩余宽度给模型名 |
| 抽屉脚 | `SessionDrawer.footer` 同一 `HStack` | `ui-settings-general` `SettingsRoot` `.triggerRow`：Settings（`IconSettingsOutlineMedium` 16、高 42）+ 右侧 trailing 动作；`ui-sidebar` `.iconButton` 28 | 删掉 Settings 上方单独「云端设备」行；设置左、远程主机入口右 |

## Round 42 侧栏清单（桌面 `0.2.1-alpha.5` ↔ iOS）

源码：`dsh-web-app` `cordis.patch.yml` browser roster + `ui-sidebar-right` / `ui-sidebar` / `ui-workspace` / `ui-sidebar-files` / `ui-sidebar-terminal` / `ui-sidebar-browser` / `ui-schedule` / `ui-plugin-manager` / `ui-settings-general`。

### 左侧抽屉（桌面左栏）

| 入口 | 桌面 | iOS | 判定 |
| --- | --- | --- | --- |
| 工作区 / 会话列表 | `ui-workspace` 分组/树/扁平 + 搜索 + 视图选项 | `SessionDrawer` | **有**；本轮时间改同行、操作钮常显、视图选项改 popover |
| 插件 | `ui-plugin-manager` | `DrawerPanel.plugins`（`plugins.list`） | **有** |
| 自动化任务 | `ui-schedule` | `DrawerPanel.schedule`（`schedule.catalog`） | **有**；本轮去掉自创刷新/重复新建 |
| 设置 | `ui-settings-general` `triggerRow` | 抽屉脚左侧 Settings | **有** |
| 远程主机指示 | Settings trailing `ConnectionIndicator` | 抽屉脚右侧圆点 | **有**（窄屏用点，不是桌面图标） |

### 右侧栏 / 会话标题栏右上角（桌面 `ui-sidebar-right`）

| 面板 / tab | 桌面 | iOS | 判定 |
| --- | --- | --- | --- |
| 展开按钮 | header `conversation.session.header.corner` | `openStartPanel` | **有** |
| Guide / 开始 | compass + guide cards | `StartPanel` | **有** |
| 工作区文件 | `ui-sidebar-files` guide order 10「工作区文件」 | Start 第一项 + `FilesPanel` | **有** |
| 新建终端 | `ui-sidebar-terminal` guide order 20「新建终端」 | Start 第二项 + `TerminalPanel` | **有** |
| 浏览器 | `ui-sidebar-browser` guide order 30「浏览器」；web profile `disabled`，desktop 启用 | Start 第三项 + `BrowserPanel` | **本轮补入口** |
| 文档预览 | `ui-sidebar-documentpreview`（打开文件时的 tab，不是 Guide 卡） | 文件预览 sheet | **有**（形态不同：sheet 不是 dock tab） |
| 会话数据诊断 | **桌面 Guide / 右栏无此 tab**；Android `SessionInspectorPanel` | Start 第四项 + `SessionInspectorPanel` | **本轮按用户要求暴露**；文案用既有「会话数据诊断 / Session diagnostics」 |
| Jobs | `ui-jobs` 在会话 header，不是右栏 tab | header chip | **有** |
| 轨迹 | 对话内 tab，不是右栏 | 对话 / 轨迹 tabs | **有** |

### 终端 `follow` 根因（不改 `dsh-android`）

桌面 Host `0.2.1-alpha.5` `TerminalController` 只有 `@Remote` `attach` / `retain`（stream），**没有** `follow`。iOS pocket op 名是 `terminal.follow`。Mac mini 加载的 `~/repo/dsh-android/plugin/src/extra-ops.js` 把该 op 转成 `terminalController.follow(...)`，因此报 `is not a function or its return value is not async iterable`。建议补丁：plugin 改为调用 `attach`（或 `retain`），不要改 iOS 客户端协议名以外的 Host API。

### #13 新会话空页（HeroShell）

桌面 `HeroShell.module.css`：`.root` 把标题块 / 工作区行 / InputBar 卡当成一列居中（`align-items: center; justify-content: center; height: 100%`），`.stack` gap 12，headline 26/32/500，`hero.preview` 与标题同一行。iOS 原先用两个 `Spacer` 夹标题、Composer 钉底，中间空洞、上下挤。现 `emptyChat` 按同一 stack 重排；不新增元素、不用系统 tint。

### 工作区文件夹 / 模型 effort

抽屉工作区行、landing「project」chip、目录选择、文件树目录行都走 `OfficialGlyph.folderClose/Open`，禁止 SF `folder` / `folder.fill`。模型菜单只在 catalog 模型 `reasoning` 有 levels 时画「推理等级」；Gemini 无 reasoning 不画。fixture 默认 DeepSeek V4 Pro + `high`。

### CI 截图

`.github/workflows/ci.yml` job `screenshots`：macos-15 启动可用 iPhone 模拟器（优先 iPhone 17e），`xcodebuild test` 把 `TEST_RUNNER_DSH_SCREENSHOT_DIR` 传进 `dshUITests`（`-UITestFixture` 假主机：两工作区、已完成「你好」、带推理强度的模型），浅色/深色各一套，artifact `ios-simulator-screenshots`。Mac Studio 实机对照由 parent 另跑。

## Round 45 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-17）：main tip `ba155b56`（#53）。CI run 39054533362：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。26 包 pack 对比 locale / `.tsx` / CSS / 组件 API **无增量**（仅 `package.json` 版本；`ui-sidebar` `localBuildVersion`、`ui-settings-general` `CurrentVersionRow` 版本字符串）。Android `compare/ce7d345...main` `ahead_by: 0`。`56dcaa9...ce7d345` 仅 #67 Host plugin `terminal.follow`→`retain`+`attach`，无新 controller 交互。

#53 CI 截图怀疑式重审（相对 R43 源码 / R44 视觉 NO_PR）：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 抽屉脚「设置」+ 远程主机同一行靠右 | **PASS** | `light/dark-drawer.png`：设置左、8pt 绿点右。Settings 无「云端设备」分组 |
| OfficialGlyph 文件夹 | **PASS** | landing / drawer / start 工作区行走 `folderClose/Open`；CI 断言无 SF `folder` |
| effort 行仅 reasoning | **PASS** | `light-models.png` 有「推理等级」；`modelPickerRootShowsEffortOnlyWhenReasoning` |
| landing Hero 12pt stack、无中空夹心 | **PASS** | `light/dark-landing.png` 标题+预览版 / 工作区 / composer 一列居中 |
| 未读绿点 / 运行 spinner 仅会话行 | **PASS**（fixture 空闲，源码仍实现） | header 无 spinner；`sidebarSessionLeading` |
| 远程主机文案 | **PASS** | 用户可见「远程主机」；抽屉脚窄屏用点 |
| 鲸尾 / Jobs 两次点按 / Cmd+Enter / 插件 (i) / 侧栏链接 / 斜杠无 count | **PASS**（源码；本轮截图未覆盖运行态） | 与 R43 同 |
| 视图选项 | **GAP → 本轮** | `light/dark-viewOptions.png` 是 iPhone compact **整屏 sheet**。桌面 `ui-workspace` `ViewOptionsMenu` 是 sliders 锚定的 dense `Menu`（`min-width: 200`）。iOS 已用 `.popover` 但缺 `PopoverCompactAdaptation`（ModelPicker / Permission / Jobs / Plugins 已有）。排序/过滤行 `icon()` 误标 `"check"`、无 leading 图标；桌面每行都有官方 icon |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 视图选项形态 | `SessionDrawer` `.popover` + `PopoverCompactAdaptation` | `ui-workspace` `ViewOptionsMenu` `Menu` `dense` `align=end` `portal` | iPhone 保持 popover，不再整屏 sheet |
| 视图选项图标 | `OfficialGlyph` 9 行全有 leading | `IconFolderClose` / `IconWorkspaceTree` / `IconFlatList` / `IconChevronsUpDown` / `IconClock` / `IconArchiveOff` / `IconQueue` / `IconArchiveCheck` | 路径来自 `@deepseek-ai/dsh-client-ui-primitives@0.2.1-alpha.5`；`archive-off` 无 Canvas mask，slash 叠在盒上 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*`：桌面仍有右侧跳轮（`ui-chat` locale + `TurnNavigator`）。phone 无源码级窄屏切片，搬过去要自撰布局 → **不 shippable without inventing**。
- `chat.toBottom`：桌面仍有官方「回到底部」chevron 钮。phone 自动贴底。官方控件可搬、但不属于本轮缺口；保持 skip。
- `AskQuestionRow` `ask.review`：桌面仍有只读回看面板。phone 无该面板，不发明一层。
- hover chevron：桌面 `DisclosureRow` hover 才换标。触屏无 hover。
- Account / shortcuts / open config / open-in-desktop-editor / 快捷键设置页：桌面仍有，属 Host 本机 chrome → **hide**。
- FishLogo：桌面 Hero 有；#53 列的是 title / preview / workspace / InputBar，不发明 logo。
- Settings 齿轮仍 SF `gearshape`：桌面 `IconSettingsOutlineMedium`。R43 已记 leftover；本轮只修截图打脸的 ViewOptions。
- Android Settings「移动端 → 连接」/ CompatibilityBanner / 审批通知：不搬。
- permission / schedule / terminal / inspector CI 截图的系统蓝「取消」/ `transport:` 失败：fixture 无真 Host，不是 composer chip 缺口。

## Round 46 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-17）：iOS `main` tip `7b7f340`（#54 squash）。CI run 39066419702：`protocol` / `screenshots` / `ios` 全绿。`npm view` 34 个 `@deepseek-ai/dsh-client-ui-*`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。pack 对比 locale / `.tsx` / CSS / 组件 API **无增量**（仅 `package.json` 版本号与依赖 tag；`ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.2-332895e`；`ui-settings-general` `CurrentVersionRow` 版本字符串）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin `terminal.follow`→`retain`+`attach`，无新 iOS UI 可搬。

#54 CI 截图怀疑式重审（`ios-simulator-screenshots`）：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 视图选项 compact popover + 官方 leading | **PASS** | `light/dark-viewOptions.png`：sliders 锚定气泡，不是整屏 sheet。9 行 OfficialGlyph（folderClose / workspaceTree / flatList / chevronsUpDown / clockOutline / archiveOff / queue / archiveCheck）；选中勾在右侧，无 `icon()=="check"` 占位 |
| 抽屉脚设置 + 连接同一行靠右 | **PASS** | `light/dark-drawer.png`：设置左、8pt 绿点右。`sidebarFooterActionSharesSettingsRow` |
| OfficialGlyph 文件夹 | **PASS** | landing / drawer / start 工作区行走 `folderClose/Open`；CI 断言无 SF `folder` |
| 有 reasoning 才画推理行；权限 chip 仅图标 | **PASS** | `light-models.png` 有「推理等级」；`light-chat.png` / landing composer 权限座只有盾标，无文字。窄屏例外已拍板 |
| 空会话 HeroShell 居中 gap 12 | **GAP → 本轮** | `light/dark-landing.png` 标题与工作区之间仍是大块空白。#53 把 `landingHeadlineRow` 放进 `.frame(maxHeight: .infinity)`，剩余空间夹在标题和 InputBar 之间。桌面 `HeroShell.module.css` `.root` `justify-content:center` + `.stack` / `.body` `gap:12`；协议 `landingHeroCentersStack`：「Leftover viewport space sits *outside* that stack」 |
| 未读绿点 / 运行 spinner 仅会话行 | **PASS**（fixture 空闲，源码仍实现） | header 无 spinner；`sidebarSessionLeading` + `SidebarSessionLeadingView` |
| Settings 齿轮 | leftover | `light/dark-drawer.png` 仍 SF `gearshape`。桌面 `IconSettingsOutlineMedium` 路径可搬；本轮只修截图打脸的 Hero 夹心 |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 空会话 Hero | `RootView.emptyChat` 标题 / 工作区 / composer 同一 `VStack(spacing: 12)`，两侧 `Color.clear` 吃剩余高度 | `ui-conversation` `HeroShell.module.css` `.root` / `.stack` / `.body` | 不再把标题放进独立弹性区；斜杠菜单 overlay 在 composer 上方，不插入行间距 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Settings 齿轮仍 SF `gearshape`：记 leftover，路径在 `ui-primitives` `IconSettingsOutlineArtwork`，本轮不改。
- Android Settings「移动端 → 连接」不搬。

## Round 47 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-17）：iOS `main` tip `98be0ef`（#55 squash）。CI run 39070985009：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。pack 对比 ui-primitives / settings-general / chat / conversation / workspace / sidebar / jobs / commands / permission-presets / model-selection / user-questions / plugin-manager / agent-preset / plan / tool / deliverables / settings-plugins / sidebar-files / sidebar-documentpreview / trajectory / schedule：locale / `.tsx` / CSS / 组件 API **无增量**（仅 `package.json` 版本与依赖 tag；`ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.2-332895e`；`ui-settings-general` `CurrentVersionRow` 版本字符串）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin `terminal.follow`→`retain`+`attach`，无新 iOS UI 可搬。

#55 CI 截图怀疑式重审（`ios-simulator-screenshots`）：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 视图选项 compact popover + 官方 leading | **PASS** | `light/dark-viewOptions.png`：sliders 锚定气泡，不是整屏 sheet。9 行 OfficialGlyph；选中勾在右侧 |
| 抽屉脚设置 + 连接同一行靠右 | **PASS** | `light/dark-drawer.png`：设置左、8pt 绿点右。`sidebarFooterActionSharesSettingsRow` |
| OfficialGlyph 文件夹 | **PASS** | landing / drawer 工作区行走 `folderClose/Open`；CI 断言无 SF `folder` |
| 有 reasoning 才画推理行；权限 chip 仅图标 | **PASS** | `light-models.png` 有「推理等级」；landing / chat composer 权限座只有盾标。窄屏例外已拍板 |
| 空会话 HeroShell 居中 gap 12 | **PASS** | `light/dark-landing.png`：标题 / 工作区 / composer 同一列，剩余视口在 stack 外侧，不再夹在标题与 InputBar 之间 |
| 未读绿点 / 运行 spinner 仅会话行 | **PASS**（fixture 空闲，源码仍实现） | header 无 spinner；`sidebarSessionLeading` + `SidebarSessionLeadingView` |
| Settings 齿轮 | **GAP → 本轮** | `light/dark-drawer.png` 仍 SF `gearshape`。桌面 `ui-settings-general` `TriggerContent` / `SettingsRoot` 用 `IconSettingsOutlineMedium`（16，`ICON_MEDIUM_STROKE` 1.3）；路径来自 `ui-primitives` `IconSettingsOutlineArtwork` |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 抽屉脚设置齿轮 | `OfficialGlyph.settingsOutline` + `sidebarSettingsOutlineHubPath` / `RingPath` | `ui-primitives` `IconSettingsOutlineArtwork` / `IconSettingsOutlineMedium`；`ui-settings-general` `TriggerContent` `size: wide ? 16 : 18`（宽栏 16） | 删掉 SF `gearshape`；16×16 viewBox；Medium 线宽 1.3；SVG 默认 butt + miterLimit 10。CI drawer 断言 `official.settingsOutline`、禁止 `gearshape` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- permission / schedule / terminal / inspector CI 截图的系统蓝「取消」/ `transport:` 失败：fixture 无真 Host，不是 composer chip 缺口。
- 轨迹未知 cell 仍映射 SF `gearshape`（`TrajectoryView` fallback）：不是 Settings 触发器，本轮不扩。

## Round 48 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-17）：iOS `main` tip `1272c1a`（#56 squash）。CI run 39074757275：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。pack 对比 primitives / workspace / sidebar / chat / conversation / settings-general / model-selection：locale / `.tsx` / CSS / 组件 API **无增量**（仅 `package.json` 版本与依赖 tag；`ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.2-332895e`；`ui-settings-general` `CurrentVersionRow` 版本字符串）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin `terminal.follow`→`retain`+`attach`，无新 iOS UI 可搬。

#56 CI 截图怀疑式重审（`ios-simulator-screenshots`）：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 抽屉脚设置齿轮 OfficialGlyph.settingsOutline | **PASS** | `light/dark-drawer.png`：6 齿描边齿轮，不是 SF `gearshape`。CI 断言 `official.settingsOutline`、禁止 `gearshape` |
| 空会话 HeroShell 居中 gap 12 | **PASS** | `light/dark-landing.png`：标题 / 工作区 / composer 同一列，剩余视口在 stack 外侧 |
| 视图选项 compact popover + 官方 leading | **PASS** | `light/dark-viewOptions.png`：sliders 锚定气泡。9 行 OfficialGlyph |
| 有 reasoning 才画推理行；权限 chip 仅图标 | **PASS** | `light-models.png` 有「推理等级」；landing / chat composer 权限座只有盾标 |
| 抽屉脚设置 + 连接同一行靠右 | **PASS** | `light/dark-drawer.png`：设置左、8pt 绿点右 |
| 未读绿点 / 运行 spinner 仅会话行 | **PASS**（fixture 空闲，源码仍实现） | header 无 spinner；`sidebarSessionLeading` + `SidebarSessionLeadingView` |
| 抽屉新会话图标 | **GAP → 本轮** | `light/dark-drawer.png` 顶栏与工作区行仍是 SF `square.and.pencil`。桌面 `ui-sidebar` header / 窄栏 `SidebarRoot` 与 `ui-workspace` 工作区行用 `IconNewChatOutlineRegular`（`NewChatOutlineArtwork` 气泡 + 加号，16×16，`ICON_REGULAR_STROKE` 1） |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 抽屉新会话 | `OfficialGlyph.newChat` + `sidebarNewChatBubblePath` / plus 路径 | `ui-primitives` `NewChatOutlineArtwork` / `IconNewChatOutlineRegular`；`ui-sidebar` header Regular 16；`ui-workspace` 工作区行 Regular | 删掉 SF `square.and.pencil`；16×16 viewBox；Regular 线宽 1；SVG 默认 butt + miterLimit 10。CI drawer 断言 `official.newChat`、禁止 `square.and.pencil` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`（`TrajectoryView` fallback）：不是 Settings 触发器。
- permission / schedule / terminal / inspector CI 截图的系统蓝「取消」/ `transport:` 失败：fixture 无真 Host。
- 抽屉搜索仍 SF `magnifyingglass`：桌面有 `IconSearchOutlineRegular`，本轮只修截图打脸的新会话铅笔。

## Round 49 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-18）：iOS `main` tip `0546823`（#57 squash）。CI run 39078926786：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。pack 对比 primitives / workspace / sidebar / chat / conversation / settings-general / model-selection：locale / `.tsx` / CSS / 组件 API **无增量**（仅 `package.json` 版本；`ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.2-332895e`；`ui-settings-general` `CurrentVersionRow` 版本字符串）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin `terminal.follow`→`retain`+`attach`，无新 iOS UI 可搬。

#57 CI 截图怀疑式重审（`ios-simulator-screenshots`）：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 抽屉新会话 OfficialGlyph.newChat | **PASS** | `light/dark-drawer.png`：气泡+加号，不是 SF `square.and.pencil`。CI 断言 `official.newChat`、禁止 `square.and.pencil` |
| 抽屉脚设置齿轮 OfficialGlyph.settingsOutline | **PASS** | `light/dark-drawer.png`：6 齿描边齿轮。CI 断言 `official.settingsOutline`、禁止 `gearshape` |
| 空会话 HeroShell 居中 gap 12 | **PASS** | `light/dark-landing.png`：标题 / 工作区 / composer 同一列，剩余视口在 stack 外侧 |
| 视图选项 compact popover + 官方 leading | **PASS** | `light/dark-viewOptions.png`：sliders 锚定气泡。9 行 OfficialGlyph |
| 有 reasoning 才画推理行；权限 chip 仅图标 | **PASS** | `light-models.png` 有「推理等级」；landing / chat composer 权限座只有盾标 |
| 抽屉脚设置 + 连接同一行靠右 | **PASS** | `light/dark-drawer.png`：设置左、8pt 绿点右 |
| 未读绿点 / 运行 spinner 仅会话行 | **PASS**（fixture 空闲，源码仍实现） | header 无 spinner；`sidebarSessionLeading` + `SidebarSessionLeadingView` |
| 抽屉搜索图标 | **GAP → 本轮** | `light/dark-drawer.png` 搜索框仍是 SF `magnifyingglass`。桌面 `ui-workspace` `WorkspaceBrowser` 用 `IconSearchOutlineRegular`（`IconSearchOutlineArtwork` 圆环 + 斜柄，16×16，`ICON_REGULAR_STROKE` 1；宽栏 idle 14） |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 抽屉搜索 | `OfficialGlyph.searchOutline` + `sidebarSearchCirclePath` / `HandlePath` | `ui-primitives` `IconSearchOutlineArtwork` / `IconSearchOutlineRegular`；`ui-workspace` `WorkspaceBrowser` Regular 14（idle） | 删掉 SF `magnifyingglass`；16×16 viewBox；Regular 线宽 1；SVG 默认 butt + miterLimit 10。CI drawer 断言 `official.searchOutline`、禁止 `magnifyingglass` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`（`TrajectoryView` fallback）：不是 Settings 触发器。
- permission / schedule / terminal / inspector CI 截图的系统蓝「取消」/ `transport:` 失败：fixture 无真 Host。
- 插件库存 / 轨迹工具栏搜索、工作区「添加」SF `plus`：桌面另有 `IconSearchOutlineRegular` / `IconProjectAddOutlineRegular`，本轮只修截图打脸的抽屉搜索。

## Round 50 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-18）：iOS `main` tip `5a8638d`（#58 squash）。CI run 39082414773：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。pack 对比 primitives / workspace / sidebar / plugin-manager / trajectory：locale / `.tsx` / CSS / 组件 API **无增量**（仅 `package.json` 版本；`ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.2-332895e`）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin `terminal.follow`→`retain`+`attach`，无新 iOS UI 可搬。

#58 CI 截图怀疑式重审（`ios-simulator-screenshots`）：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 抽屉搜索 OfficialGlyph.searchOutline | **PASS** | `light/dark-drawer.png`：圆环+斜柄，不是 SF `magnifyingglass`。CI 断言 `official.searchOutline`、禁止 `magnifyingglass` |
| 抽屉新会话 OfficialGlyph.newChat | **PASS** | `light/dark-drawer.png`：气泡+加号。CI 断言 `official.newChat`、禁止 `square.and.pencil` |
| 抽屉脚设置齿轮 OfficialGlyph.settingsOutline | **PASS** | `light/dark-drawer.png`：6 齿描边齿轮。CI 断言 `official.settingsOutline`、禁止 `gearshape` |
| 空会话 HeroShell 居中 gap 12 | **PASS** | `light/dark-landing.png`：标题 / 工作区 / composer 同一列 |
| 视图选项 compact popover + 官方 leading | **PASS** | `light/dark-viewOptions.png`：sliders 锚定气泡。9 行 OfficialGlyph |
| 有 reasoning 才画推理行；权限 chip 仅图标 | **PASS** | `light-models.png` 有「推理等级」；landing / chat composer 权限座只有盾标 |
| 抽屉脚设置 + 连接同一行靠右 | **PASS** | `light/dark-drawer.png`：设置左、8pt 绿点右 |
| 未读绿点 / 运行 spinner 仅会话行 | **PASS**（fixture 空闲，源码仍实现） | header 无 spinner；`sidebarSessionLeading` + `SidebarSessionLeadingView` |
| 抽屉工作区「添加」 | **GAP → 本轮** | fixture 原先无 `workspace.create`，`light/dark-drawer.png` 看不到该钮。源码 `SessionDrawer` 仍 SF `plus`。桌面 `ui-workspace` `WorkspaceBrowser` headerActions 用 `IconProjectAddOutlineRegular`（`IconProjectAddOutlineArtwork` 填充文件夹 + 描边加号，16×16，`ICON_REGULAR_STROKE` 1；宽栏 16）。Android `dsh_project_add.xml` 同路径 |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 抽屉工作区添加 | `OfficialGlyph.projectAdd` + `sidebarProjectAddFolderPath` / plus 路径 | `ui-primitives` `IconProjectAddOutlineArtwork` / `IconProjectAddOutlineRegular`；`ui-workspace` `WorkspaceBrowser` header Regular 16；`.iconButton` 28×28 | 删掉 SF `plus`；16×16 viewBox；文件夹 fill、加号 Regular 线宽 1；SVG 默认 butt + miterLimit 10。fixture 打开 `workspace.create`。CI drawer 断言 `official.projectAdd` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`（`TrajectoryView` fallback）：桌面 `KIND_ICON` 无 unknown；`system` 才是 `IconSettingsOutlineRegular`，不是 Settings 触发器，不发明 fallback。
- permission / schedule / terminal / inspector CI 截图的系统蓝「取消」/ `transport:` 失败：fixture 无真 Host。
- 插件库存搜索仍 SF `magnifyingglass`：桌面 `ui-plugin-manager` 无该搜索槽，不发明。
- 轨迹工具栏搜索仍 SF `magnifyingglass`：桌面 `IconSearchOutlineRegular` size 11，但 CI 无轨迹屏；本轮只修源码+fixture 打脸的工作区添加。
- composer `+` 仍 SF `plus`：桌面 `IconPlusOutlineRegular`，视觉近似，本轮不扩。

## Round 51 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-18）：iOS `main` tip `4a2e0ff`（#59 squash）。CI run 39086343971：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。pack 对比 primitives `index.js` 与 conversation `client.js` **字节相同**（sha256 一致；locale / `.tsx` / CSS / 组件 API **无增量**）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin `terminal.follow`→`retain`+`attach`，无新 iOS UI 可搬。

#59 CI 截图怀疑式重审（`ios-simulator-screenshots`）：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 抽屉工作区添加 OfficialGlyph.projectAdd | **PASS** | `light/dark-drawer.png`：填充文件夹+加号。CI 断言 `official.projectAdd` |
| 抽屉搜索 OfficialGlyph.searchOutline | **PASS** | `light/dark-drawer.png`：圆环+斜柄。CI 断言 `official.searchOutline`、禁止 `magnifyingglass` |
| 抽屉新会话 OfficialGlyph.newChat | **PASS** | `light/dark-drawer.png`：气泡+加号。CI 断言 `official.newChat`、禁止 `square.and.pencil` |
| 抽屉脚设置齿轮 OfficialGlyph.settingsOutline | **PASS** | `light/dark-drawer.png`：6 齿描边齿轮。CI 断言 `official.settingsOutline`、禁止 `gearshape` |
| 空会话 HeroShell 居中 gap 12 | **PASS** | `light/dark-landing.png`：标题 / 工作区 / composer 同一列 |
| 视图选项 compact popover + 官方 leading | **PASS** | `light/dark-viewOptions.png`：sliders 锚定气泡。9 行 OfficialGlyph |
| 有 reasoning 才画推理行；权限 chip 仅图标 | **PASS** | `light-models.png` 有「推理等级」；landing / chat composer 权限座只有盾标 |
| 抽屉脚设置 + 连接同一行靠右 | **PASS** | `light/dark-drawer.png`：设置左、8pt 绿点右 |
| 未读绿点 / 运行 spinner 仅会话行 | **PASS**（fixture 空闲，源码仍实现） | header 无 spinner；`sidebarSessionLeading` + `SidebarSessionLeadingView` |
| composer 加号 | **GAP → 本轮** | `light/dark-landing.png` 与 `light/dark-chat.png` 仍是 SF `plus`（系统 13/medium）。桌面 `ui-conversation` InputBar `.add` 用 `IconPlusOutlineMedium`（**不是** Round 50 笔记里的 Regular）：`IconPlusOutlineArtwork` 两条轴对齐线 `M8 2V14` / `M2 8H14`，16×16，`ICON_MEDIUM_STROKE` 1.3，size 14，28 圆 `--dsw-specific-selector` |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| composer 加号 | `OfficialGlyph.plusOutline` + `composerAddPlusVerticalPath` / `HorizontalPath` | `ui-primitives` `IconPlusOutlineArtwork` / `IconPlusOutlineMedium`；`ui-conversation` InputBar Medium 14；`.add` 28×28 | 删掉 SF `plus`；16×16 viewBox；Medium 线宽 1.3；SVG 默认 butt + miterLimit 10。CI landing/chat 断言 `official.plusOutline`、禁止 `plus` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`（`TrajectoryView` fallback）：桌面 `KIND_ICON` 无 unknown；`system` 才是 `IconSettingsOutlineRegular`，不是 Settings 触发器，不发明 fallback。
- permission / schedule / terminal / inspector CI 截图的系统蓝「取消」/ `transport:` 失败：fixture 无真 Host。
- 插件库存搜索仍 SF `magnifyingglass`：桌面 `ui-plugin-manager` 无该搜索槽，不发明。
- 轨迹工具栏搜索仍 SF `magnifyingglass`：桌面 `IconSearchOutlineRegular` size 11，CI 无轨迹屏。
- composer 发送仍 SF `arrow.up`：桌面 InputBar primary 是内联 16×16 SVG（非 `IconSendOutlineRegular`），本轮只修截图打脸的加号。

## Round 52 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-18）：iOS `main` tip `95586bb`（#60 squash）。CI run 39093228926：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。pack 对比 primitives `index.js` 与 conversation `client.js` **字节相同**（sha256 一致；locale / `.tsx` / CSS / 组件 API **无增量**）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin，无新 iOS UI 可搬。

#60 后源码 + 桌面 pack 怀疑式重审：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| composer 加号 OfficialGlyph.plusOutline | **PASS** | `ComposerView` Medium 14 / 1.3；CI 断言 `official.plusOutline`、禁止 `plus` |
| 抽屉 settings/newChat/search/projectAdd OfficialGlyphs | **PASS** | #56–#59；CI drawer 断言 |
| HeroShell center gap 12；view-options compact popover | **PASS** | #55 / #54 |
| effort 仅 reasoning；permission chip 仅图标 | **PASS** | #53 |
| composer 发送 | **GAP → 本轮** | `ComposerView` 仍 SF `arrow.up` 13/semibold。桌面 InputBar `.primary` 是内联 16×16 filled SVG（`fill: currentColor`），**不是** `IconSendOutlineRegular`（QueueDock `queue.steer`）。path 与 Android `dsh_composer_send.xml` 字节对齐 |
| 轨迹工具栏搜索 SF `magnifyingglass` | **GAP（本轮不修）** | 桌面 `ui-trajectory` TrajectoryToolbar `IconSearchOutlineRegular` size 11；CI 无轨迹屏 |
| 插件库存搜索 SF | **skip** | 桌面 `ui-plugin-manager` 无 `IconSearch` / 搜索槽 |
| 轨迹未知 cell SF `gearshape` | **skip** | 桌面 `KIND_ICON` 无 unknown；不发明 fallback |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| composer 发送 | `OfficialGlyph.send` + `composerSendPath` | `ui-conversation` InputBar `.primary` 内联 `<path d>`；34×34 `--dsw-alias-button-info-fill`；图标 16×16 白填充 | 删掉 SF `arrow.up`；禁止用 primitives `IconSendOutlineArtwork`。CI landing/chat 断言 `official.send`、禁止 `arrow.up` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`：桌面 `KIND_ICON` 无 unknown，不发明 fallback。
- 插件库存搜索仍 SF：桌面 `ui-plugin-manager` 无该搜索槽。
- 轨迹工具栏搜索仍 SF `magnifyingglass`：桌面 `IconSearchOutlineRegular` size 11，CI 无轨迹屏；本轮只修截图打脸的发送。
- InputBar `.primary` 停止态圆角方块：同一按钮的另一态，fixture 不跑，本轮不扩。

## Round 53 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-18）：iOS `main` tip `4bd88f5`（#61 squash）。CI run 39096651151：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。primitives `index.js` 与 trajectory `client.js` **sha256 与 alpha.5 相同**（locale / 组件 API **无增量**）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin，无新 iOS UI 可搬。

#61 后源码 + 桌面 pack 怀疑式重审：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| composer 发送 OfficialGlyph.send | **PASS** | InputBar 内联 filled 16×16；CI landing/chat 断言 `official.send`、禁止 `arrow.up` |
| composer 加号 OfficialGlyph.plusOutline | **PASS** | Medium 14 / 1.3；CI 断言 `official.plusOutline`、禁止 `plus` |
| 抽屉 settings/newChat/search/projectAdd OfficialGlyphs | **PASS** | #56–#59；CI drawer 断言 |
| HeroShell center gap 12；view-options compact popover | **PASS** | #55 / #54 |
| effort 仅 reasoning；permission chip 仅图标 | **PASS** | #53 |
| 轨迹工具栏搜索 | **GAP → 本轮** | `TrajectoryView` 仍 SF `magnifyingglass`。桌面 `ui-trajectory` `TrajectoryToolbar` 用 `IconSearchOutlineRegular` size **11**（同一 `IconSearchOutlineArtwork` 圆环+斜柄，Regular 1；搜索槽 `--dsw-alias-label-caption`） |
| 插件库存搜索 SF | **skip** | 桌面 `ui-plugin-manager` 无 `IconSearch` / 搜索槽 |
| 轨迹未知 cell SF `gearshape` | **skip** | 桌面 `KIND_ICON` 无 unknown；不发明 fallback |
| 轨迹时长 chip SF `clock` | **GAP（本轮不修）** | 桌面是工具栏内联 16×16 clock SVG（`circle r=5.25` + `M8 4.75V8l2.25 1.5`），不是 primitives `IconClock*`；本轮只修已有 OfficialGlyph 的搜索 |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 轨迹工具栏搜索 | `OfficialGlyph.searchOutline` + `trajectoryToolbarSearchIconSizePoints` 11 | `ui-trajectory` TrajectoryToolbar `IconSearchOutlineRegular` size 11；`ui-primitives` `IconSearchOutlineArtwork` | 删掉 SF `magnifyingglass`；复用已锁定圆环/斜柄 path；Regular 线宽 1；颜色 `T.caption`（`--dsw-alias-label-caption`）。CI 新 `trajectory` 屏断言 `official.searchOutline`、禁止 `magnifyingglass` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`：桌面 `KIND_ICON` 无 unknown，不发明 fallback。
- 插件库存搜索仍 SF：桌面 `ui-plugin-manager` 无该搜索槽。
- 轨迹时长 chip 仍 SF `clock`：桌面是另一套内联 SVG，不是已有 OfficialGlyph；本轮不扩。
- InputBar `.primary` 停止态圆角方块：同一按钮的另一态，fixture 不跑。

## Round 54 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-18）：iOS `main` tip `07e84e9`（#62 squash）。CI run 39100569960：`protocol` / `screenshots` / `ios` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。primitives `lib/index.js` sha256 `333ea89e7518ec1f1d33111bb9c65d382454bcc3638ebac7116253c92fe5d566`；trajectory `lib/client.js` sha256 `b11426f89d3b4302964b491d7826a29fe3de390be4bbfae325375f54fe6919ad`（alpha.5 与 rc.2 **相同**）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin，无新 iOS UI 可搬。

#62 后源码 + 桌面 pack 怀疑式重审：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| composer 发送 OfficialGlyph.send | **PASS** | InputBar 内联 filled 16×16；CI landing/chat 断言 `official.send`、禁止 `arrow.up` |
| composer 加号 OfficialGlyph.plusOutline | **PASS** | Medium 14 / 1.3；CI 断言 `official.plusOutline`、禁止 `plus` |
| 抽屉 settings/newChat/search/projectAdd OfficialGlyphs | **PASS** | #56–#59；CI drawer 断言 |
| 轨迹工具栏搜索 OfficialGlyph.searchOutline size 11 | **PASS** | #62；CI trajectory 断言 `official.searchOutline`、禁止 `magnifyingglass` |
| HeroShell center gap 12；view-options compact popover | **PASS** | #55 / #54 |
| effort 仅 reasoning；permission chip 仅图标 | **PASS** | `modelEffortLabel` 无 reasoning 返回 nil；`permissionChipTriggerShowsLabel = false` |
| 轨迹时长 chip | **GAP → 本轮** | `TrajectoryView` 仍 SF `clock`。桌面 `TrajectoryToolbar` 时长 toggle 是同一控件：内联 16×16 SVG `circle r=5.25` + `M8 4.75V8l2.25 1.5`，CSS 12×12 / `stroke-width: 1.25px` / round，**不是** primitives `IconClockOutline*`（那是 view-options `clockOutline`） |
| 插件库存搜索 SF | **skip** | 桌面 `ui-plugin-manager` 无 `IconSearch` / 搜索槽 |
| 轨迹未知 cell SF `gearshape` | **skip** | 桌面 `KIND_ICON` 无 unknown；不发明 fallback |
| npm alpha / next | **PASS** | 无增量（主文件 sha256 一致） |
| Android `ce7d345` | **PASS** | 无新 client UI |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 轨迹时长 chip | `OfficialGlyph.trajectoryClock` + `trajectoryToolbarClock*` | `ui-trajectory` TrajectoryToolbar duration toggle 内联 `<circle cx=8 cy=8 r=5.25>` + `<path d="M8 4.75V8l2.25 1.5">`；`.toggleIcon` 12×12 / stroke 1.25px / round；`currentColor` = tertiary idle / primary pressed | 删掉 SF `clock`；禁止 primitives `IconClock*`；颜色 `T.text3` / 按下 `T.ink`。CI trajectory 断言 `official.trajectoryClock`、禁止 `clock` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`：桌面 `KIND_ICON` 无 unknown，不发明 fallback。
- 插件库存搜索仍 SF：桌面 `ui-plugin-manager` 无该搜索槽。
- InputBar `.primary` 停止态圆角方块：同一按钮的另一态，fixture 不跑。
- 轨迹 ledger `KIND_ICON` 已知 kind（user/sparkle/wrench/…）仍是 SF：本轮只修工具栏时长 clock；不扩一批 cell 图标。

## Round 55 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

直播核对（2026-10-18）：iOS `main` tip `10960ec`（#63 squash）。CI run 39104020345：`protocol` / `ios` / `screenshots` 全绿。`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。primitives `lib/index.js` sha256 `333ea89e7518ec1f1d33111bb9c65d382454bcc3638ebac7116253c92fe5d566`；trajectory `lib/client.js` sha256 `b11426f89d3b4302964b491d7826a29fe3de390be4bbfae325375f54fe6919ad`；jobs `lib/client.js` sha256 `ad8f57b1b5b9adcd09b197b97ced17e3da4b9dcd0615d25a07f1282beba89fc8`（alpha.5 与 rc.2 **相同**）。Android `main` `ce7d345`；`compare/ce7d345...main` `ahead_by: 0`。#67 仅 Host plugin，无新 iOS UI 可搬。

#63 后源码 + 桌面 pack 怀疑式重审：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 轨迹时长 chip OfficialGlyph.trajectoryClock | **PASS** | TrajectoryToolbar 内联 clock SVG；CI trajectory 断言 `official.trajectoryClock`、禁止 `clock` |
| composer 发送 / 加号 / 抽屉 settings/newChat/search/projectAdd | **PASS** | #56–#61；CI landing/chat/drawer 断言 |
| 轨迹工具栏搜索 OfficialGlyph.searchOutline size 11 | **PASS** | #62；CI trajectory 断言 |
| Jobs 头栏 chip | **GAP → 本轮** | iOS `JobsAction` 仍 SF `clock`（Android `JobsAction.kt` 同样自造 `D.clock`）。桌面 `ui-jobs` `JobListAction` trigger 是 `StateDot?` + count + `IconChevronDownOutlineRegular` size 12，**没有 clock**。路径 `M4 6L7.29289…L12 6`，Regular stroke 1，打开旋转 180° |
| 轨迹 ledger `KIND_ICON` 已知 kind | **skip（下一轮候选）** | 桌面 `KIND_ICON`：system=`IconSettingsOutlineRegular` 13 / user=`IconUserOutlineRegular` 13 / context=内联 InformationIcon / compacted=内联 CompactedIcon / message=`IconSparkleRegular` 13 / tool+subtool=内联 ToolWrenchIcon。iOS `KindBadge` 仍 SF。本轮只修 Jobs trigger |
| 轨迹未知 cell SF `gearshape` | **skip** | 桌面 `KIND_ICON` 无 unknown；不发明 fallback |
| InputBar `.primary` 停止态 | **skip** | 桌面同一 34 圆钮内联 `<rect x=3 y=3 w=10 h=10 rx=3>`；iOS 是 8×8 `RoundedRectangle`。fixture 会话不 `running`，`runningIdle` 不进截图 |
| 插件库存搜索 SF | **skip** | 桌面 `ui-plugin-manager` 无 `IconSearch` / 搜索槽 |
| `chat.turnNavigation.*` / `chat.toBottom` | **skip** | 桌面 `ui-conversation` locale / client 无这些 key（触屏无 hover 轮次条 / 回底 FAB） |
| `ask.review` | **skip** | locale 有 key；桌面 Ask 行是 hover「查看回答」，触屏无 hover |
| Account / shortcuts / CompatibilityBanner / 审批通知 / FishLogo | **hide** | 桌面本机 chrome；不发明 |
| Android Settings「移动端 → 连接」 | **skip** | 桌面没有该入口 |
| npm alpha / next | **PASS** | 无增量（主文件 sha256 一致） |
| Android `ce7d345` | **PASS** | 无新 client UI |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| Jobs 头栏 chip | `OfficialGlyph.jobsChevron` + `jobsActionTrigger*` | `ui-jobs` `JobListAction` trigger：`IconChevronDownOutlineRegular` size 12；`ui-primitives` `IconChevronDownOutlineArtwork` path `M4 6L7.29289 9.29289C7.68342 9.68342 8.31658 9.68342 8.70711 9.29289L12 6`；Regular `strokeWidth: 1`；打开 `.triggerOpen` `rotate(180deg)` | 删掉发明的 SF `clock`；顺序改为 count + chevron（对齐桌面，不是 Android 的 leading clock）；禁止该槽 `clock` / `chevron.down` / `IconClock*`。CI chat/trajectory 断言 `official.jobsChevron` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。
- 轨迹未知 cell 仍映射 SF `gearshape`：桌面 `KIND_ICON` 无 unknown，不发明 fallback。
- 插件库存搜索仍 SF：桌面 `ui-plugin-manager` 无该搜索槽。
- InputBar `.primary` 停止态圆角方块：fixture 不跑 `runningIdle`。
- 轨迹 ledger `KIND_ICON` 已知 kind（user/sparkle/wrench/…）仍是 SF：本轮只修 Jobs trigger chevron。

## Round 56 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

真机（iPhone，IPA @ `10960ec`）反馈：#60 把 landing 移出 GeometryReader 后双 `Spacer` 把 Hero+workspace+composer 整列垂直居中，Composer 下方半屏空白。另：多余分享按钮。

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 空会话 Composer 贴底 | **GAP → 本轮** | 真机截图 Composer 悬在中部。桌面 `HeroShell.module.css` `.root` 是 `justify-content:center`（宽屏）。窄屏参考 Android `Chat.kt`：`Box(weight(1f), Center) { Hero() }` + workspace 行 + Composer 在 Column 底部（`imePadding`）。用户要求输入框到底部，覆盖桌面居中 |
| 顶栏分享 | **GAP → 本轮** | iOS `sessionShare` / `OfficialGlyph.shareOutline` 在 `ConversationSessionHeader` 位置。桌面该处是 slots（`header.actions` / `utilities` / `corner`），没有 share glyph。导出是 `session-log-export` HeaderAction 更多菜单「下载 Session 日志」+ `/export`（`HeaderAction.d.ts` / README）。P2 已去掉 ⋯，顶栏分享图标是后来多出来的 |
| 消息行分享 | **GAP → 本轮** | iOS `MessageActions` `square.and.arrow.up` + `ShareSheet(text)`。桌面 `MessageIconActions` extraActions 只挂 `ui-message-feedback` 赞/踩（`MessageFeedbackActions.d.ts`）。Android `Chat.kt` `MessageActions` 无分享 |
| `/export` 导出 ZIP | **保留** | 桌面 `session-log-export` `/export` 下载 ZIP。iOS `exportSession()` + `ShareSheet(url)` 是把 ZIP 交给系统分享页，不是顶栏/消息行按钮 |

| 模块 | iOS | 对照的桌面 / Android 源码 | 对齐点 |
| --- | --- | --- | --- |
| 空会话 Hero | `RootView.emptyChat`：headline 在剩余高度里居中；workspace 行 `gap: 12` 贴在 composer 上方；composer 钉安全区底（与聊天页同一 `ComposerView`）。斜杠菜单 overlay 仍用 GeometryReader，composer 本身不进 GeometryReader | Android `Chat.kt` 405–413 + Composer；桌面 `HeroShell.module.css` / `EmptyHero.d.ts` | 不再双 Spacer 居中整列。CI landing 断言 `landingComposer` 底边距屏幕底 ≤ 40pt；保留 `official.plusOutline` / `official.send` |
| 顶栏分享 | 删除 `sessionShare` | `ui-conversation` `ConversationSessionHeader`；`session-log-export` `HeaderAction` | `conversationHeaderShowsShare = false`。CI landing/chat 禁止 `sessionShare` / `square.and.arrow.up` |
| 消息行分享 | 删除 share 按钮与 `D.share` / `OfficialGlyph.shareOutline` / `L.share` | `ui-chat` `MessageIconActions` + `ui-message-feedback` `MessageFeedbackActions`；Android `Chat.kt` `MessageActions` | `MessageActionPolicy.includesShare = false`；assistantRow = copy / like / dislike / branch |

本轮核对后**不改**（平台 / hide / 禁止发明）

- 桌面 HeaderAction 更多菜单「下载 Session 日志」：P2 已按「phone 无 ⋯」去掉；导出继续走 `/` `+` 的 `/export`，不发明顶栏 ⋯。
- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知 / FishLogo：仍 **hide** / 不发明。
- Android Settings「移动端 → 连接」不搬。

## Round 57 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

真机反馈（续 #65 未覆盖项 3–7，再加 landing FishLogo）。基线 `cursor/landing-composer-bottom-75e6` `bed6a75`（#65：landing composer 贴底 + 去掉分享）。本轮只修复制键 / 抽屉脚热区 / 诊断图标 / 视图选项图标 / 插件 tooltip / 空会话鲸鱼 logo。

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 用户气泡永久复制键 | **GAP → 本轮** | 桌面 `UserMessageNodeView` 无 copy；手机仅 start clock。iOS `MessageActions` 在用户气泡下常驻 `square.on.square`。`MessageActionPolicy.userRow = []` |
| 抽屉脚远程主机名 + 热区串扰 + 整页全屏连接 | **GAP → 本轮** | 桌面 `SettingsRoot` `triggerRow`：Settings 左、`ConnectionIndicator`（dot + 主机名）右。iOS 右侧只剩绿点，且 Settings 曾 `maxWidth: .infinity` 把热区铺满整行。拆成两个独立 Button，中间不可点 `Spacer(minLength: 16)`，高度 ≥ 44pt，按下用 `T.hoverBg`。点主机 → `push(.connections)` 关抽屉；`AppRoute.closesSessionDrawer` 保证连接页整页全屏（对齐 Android `Screen.Connections` + `drawer.close()`），禁止抽屉半屏遮挡 |
| composer 诊断 SF 图标 /「缓存命中中」 | **GAP → 本轮** | 桌面 `IconGaugeOutlineRegular` / `IconDatabaseOutlineRegular` 14×16 viewBox。iOS 用 SF `gauge.with.dots.needle.67percent` / `cylinder`。文案走 `composerCacheHitPill`（「缓存命中」，禁止「命中中」） |
| 视图选项图标 | **GAP → 本轮** | 9 行已是 OfficialGlyph，但 `IconSlidersTwoOutlineArtwork` 缺两个 stroked knobs（`r=1.45` at `(9.95,5)` / `(5.75,11)`），测试也未禁止 SF |
| 插件 (i) tooltip | **GAP → 本轮** | 桌面 `Tooltip.module.css`：`--dsw-alias-tooltip-bg` + `--dsw-static-neutral-bluish-00`、`--dsw-radius-sm` 6、13/20、`.bubble` padding `3px 7px`、PluginManagerPage `maxWidth: 300` / `side: bottom` / gap 8 / `openOnClick`。iOS 用系统 `.popover`，窄屏裁切。改成 header 下方自绘气泡，点 (i) 开关，点外侧 / 滚动关闭 |
| 空会话 landing 标题旁鲸鱼 | **GAP → 本轮** | 此前 hide。用户现要求桌面 EmptyHero `HeroFish`：primitives `FISH_LOGO_PATH` viewBox `23.16×17.04`、宽 34、fill `--dsw-alias-label-primary`、headline `align-items:center` + column-gap 10。禁止 SF `fish` / BrandWordmark 偏移鲸 path |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 用户消息 | `MessageActions(showsCopy: userMessageShowsPersistentCopy)` | `ui-chat` `UserMessageNodeView` | 无常驻 copy。CI chat 禁止 `userMessageCopy` |
| 抽屉脚 | `footerSettings` + `Spacer(minLength: 16)` + `footerPeerDevice`（dot + 截断名） | `ui-settings-general` `triggerRow` / `ConnectionIndicator` | 热区不相交、间隔 ≥ 16pt、高度 ≥ 44pt。CI 分别 tap → `settingsShell` / 全屏 `connectionsScreen` |
| 远程主机页 | 整窗 `ConnectionsView`；标题 `connectionsPageTitle`「远程主机」 | Android `Screen.Connections` + `drawer.close()`；桌面 Settings 是整栏不是 sheet。Host 侧 `pocket`「手机连接」QR 不搬 | `AppRoute.closesSessionDrawer`；CI `connections` 屏 + footer tap 断言占窗口 ≥ 98%×90%、无抽屉 chrome、标题「远程主机」 |
| 诊断行 | `OfficialGlyph.gaugeOutline` / `.databaseOutline` | primitives `IconGaugeOutlineArtwork` / `IconDatabaseOutlineArtwork` | CI chat 禁止 SF gauge/cylinder，断言 `official.gaugeOutline` / `official.databaseOutline` 与「缓存命中 69%」 |
| 视图选项 | `OfficialGlyph` + sliders knobs | `ui-workspace` `ViewOptionsMenu` + `IconSlidersTwoOutlineArtwork` | CI 禁止 SF slider/list/clock/archivebox；断言 official.* |
| 插件 tooltip | 自绘 `T.tooltipBg` 气泡 + `OfficialGlyph.infoOutline` | `ui-primitives` Tooltip + `ui-plugin-manager` `IconInfoOutlineRegular` size 11 | CI plugins 点 (i)，断言 `pluginInfoTooltip` 在屏幕内 |
| 空会话 Hero 鲸 | `OfficialGlyph.fishLogo` 在 `landingHeadline` 左侧 | `ui-conversation` EmptyHero `HeroFish` + primitives `FishLogo` / `FISH_LOGO_PATH` | CI landing 断言 `official.fishLogo` 在标题左侧、禁止 SF `fish` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- landing composer 贴底 / 顶栏与消息行分享：#65。
- 桌面 HeaderAction 更多菜单「下载 Session 日志」：仍不发明顶栏 ⋯。
- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- Account / shortcuts / open config / CompatibilityBanner / 审批通知：仍 **hide** / 不发明。
- FishLogo hover swim（桌面 SMIL + CSS）：phone 无 hover，只放静态 filled path。
- Android Settings「移动端 → 连接」不搬。
- 助手行 copy / like / dislike / branch 仍保留。

## Round 58 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

真机（深色）：会话 Composer 弹出输入法后再开左侧抽屉，键盘留在下半屏压住抽屉底栏（设置 / 远程主机名）和会话列表，且收不下去。

**现状（#65 / #66 之前也没有收键盘，这两轮把它撞到前台）：**

- Composer 是 `UITextView`（`ComposerTextView`）。抽屉是 `RootView` ZStack overlay，并不卸掉聊天页，UIKit first responder 继续占着 IME。
- 斜杠菜单的 `lockFirstResponder` 会吞掉 `resignFirstResponder`（连 `UIApplication.sendAction` 也被挡）。
- 聊天 `ScrollView` / 抽屉列表都没有 `scrollDismissesKeyboard`（只有权限确认对话框有）。
- 点 Composer 外空白、从抽屉进设置／远程主机，都没有统一结束焦点。
- **#65** 把 landing Composer 钉在安全区底，聚焦输入再开抽屉变成默认路径。
- **#66** 把抽屉脚做成「设置」+「绿点 + 远程主机名」两枚独立热区，卡住的键盘正好压住这两块。

Android `MainActivity` 窄屏是 `ModalNavigationDrawer`（按钮 / 手势滑出）；`Chat.kt` Column `imePadding()`。iOS 常规：开抽屉结束焦点；滚动 `scrollDismissesKeyboard(.immediately)`；点空白 resign。

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 打开抽屉收起 Composer 键盘 | **GAP → 本轮** | 真机截图 IME 压住设置 / mac mini。`openingSessionDrawerResignsComposer`：`showDrawer` 时 `resignKeyboard` + `Keyboard.dismiss()`（通知打穿 `lockFirstResponder`） |
| 抽屉搜索才弹键盘 | **GAP → 本轮** | 打开抽屉 `searchFocused = false`，只有点搜索框才聚焦。列表滚动 / 点空白 `scrollDismissesKeyboard(.immediately)` |
| 聊天页滚动 / 点空白收键盘 | **GAP → 本轮** | transcript `dshDismissesKeyboardOnScrollAndTap`；landing 标题剩余空白 `onTapGesture` |
| 进设置 / 远程主机不残留键盘 | **GAP → 本轮** | `AppModel.push` 在 `closesSessionDrawer` 时 `Keyboard.dismiss()`；底栏两键先 dismiss 再 push |

| 模块 | iOS | 对照 | 对齐点 |
| --- | --- | --- | --- |
| 抽屉 | 打开即结束 Composer 焦点；搜索框用户聚焦才出 IME | Android `ModalNavigationDrawer` + iOS 常规 | 无「收起键盘」按钮。CI：Composer 聚焦后点 `openDrawer`，`app.keyboards` 不存在或不可见 |
| 聊天 | 消息列表一滚动就收键盘；点列表空白收 | iOS `scrollDismissesKeyboard(.immediately)`（`.interactively` 只在拖进键盘区才收，CI 证实向上滑不收） | CI：chat 屏滚动 transcript 后键盘收起 |
| 远程主机 | 从抽屉进整页不留 IME | #66 整页 `ConnectionsView`；标题「远程主机」 | `leavingDrawerForSettingsOrHostResignsKeyboard` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- 不增加「收起键盘」或其它桌面没有的可见控件。
- landing composer 贴底 / 顶栏与消息行分享：#65。
- 抽屉脚热区 / 远程主机整页 / landing 鲸：#66。
- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。

自审补丁（Round 58）：

- 斜杠菜单选行 / Escape 不再收键盘（`/skill `、`/goal ` 插入后要接着打字，与 main 行为一致）；只有点菜单外空白才收。
- 点空白收键盘的 tap 只挂在被修饰的那个 `UIScrollView`（按窗口坐标匹配），不再退化挂到整个 window，免得点「发送」「+」、斜杠菜单行也把键盘收掉。

## Round 59 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5` / next=`0.2.1-rc.2`；Android `ce7d345`）

基线 `main` `77bba90`（#67 Round 58 收键盘）。怀疑式对照：桌面 pack 为第一依据；#67 CI `ios-simulator-screenshots` 逐屏看过；Android 只作参考。

### 必须核实

| 项 | 判定 | 证据 |
| --- | --- | --- |
| landing 标题文案 | **PASS（已对齐，不改字）** | 桌面 `ui-conversation` `client.js` `hero.headline` zh=「**探索未至之境**」、en=`Into the Unknown`。用户口中的「探索未知之境」与源码不一致。iOS `landingHeadline(english:)` 已逐字相同。CI landing 现断言标题含「探索未至之境」、禁止「探索未知之境」 |
| 抽屉底栏两枚独立按钮 + 远程主机整页 | **PASS（#66 仍成立）** | #67 `light/dark-drawer.png`：设置左、绿点+Mac mini 右，中间空白。`ScreenshotTests` 热区不相交、间隔 ≥16pt、高度 ≥44pt；footer tap 后 `connectionsScreen` 占窗 ≥98%×90%，标题「远程主机」，无抽屉 chrome |
| 开抽屉 / 进设置 / 进远程主机不留键盘 | **PASS（#67 无回归）** | `KeyboardDismissalTests` 原有抽屉+远程主机；本轮补「进设置」。`openingSessionDrawerResignsComposer` / `leavingDrawerForSettingsOrHostResignsKeyboard` |

### 本轮修

| 项 | 判定 | 证据 |
| --- | --- | --- |
| Composer 权限选择器 | **GAP → 本轮** | #67 `light/dark-permission.png` 是系统 sheet：蓝「取消」、大标题「访问模式」、红字 `transport: 未连接到远程主机`。桌面 `ui-permission-presets` `PermissionSelect` 是贴 chip 的 MenuSurface（与模型选择器相同）。iOS 聊天/landing 还叠了一层 `.sheet { PermissionPickerSheet }`，UITest `permission` 打开的是这层而不是 chip 菜单，且 `onAppear` 会 `reloadPermissionCatalog()` 打到空 transport。删掉聊天/landing 的系统 sheet；`/permission` 继续 slash 内 `popupSelect`；CI `permission` 打开 chip MenuSurface |
| 轨迹 ledger KIND_ICON | **GAP → 本轮** | #67 `*-trajectory.png` 用户行是绿色 SF person、助手行是 SF sparkle。桌面 `KIND_ICON`：system=`IconSettingsOutlineRegular` 13 / user=`IconUserOutlineRegular` 13 / context=InformationIcon / compacted=CompactedIcon / message=`IconSparkleRegular` 13 / tool+subtool=ToolWrenchIcon。窄表 `@container width<=620px` 只显示 19pt chip + 13pt 图标。`.user` 颜色是 `--dsw-alias-state-business-primary`（#4176E6）打在 business-tertiary 上，不是 success 绿。未知 kind 桌面无 fallback，不再画 SF `gearshape` |

| 模块 | iOS | 对照的桌面源码 | 对齐点 |
| --- | --- | --- | --- |
| 权限 chip | `PermissionChipMenu` Binding，无系统 sheet | `ui-permission-presets` `PermissionSelect` MenuSurface；`ui-commands` `/permission` `popupSelect` | `composerPermissionUsesSystemSheet = false`。CI permission：存在 `permissionPicker`、有「工作区内修改」、无「访问模式」、高度 < 70% 窗口 |
| 轨迹 kind chip | `OfficialGlyph` userOutline / sparkle / toolWrench / information / compacted / settingsOutlineRegular | `ui-trajectory` `client.js` `KIND_ICON` + `TrajectoryTable` `.kindTag` / `@container width<=620px`；primitives Regular artwork | CI trajectory 禁止 SF person/sparkle/wrench/gearshape；断言 `official.userOutline` / `official.sparkle` |
| landing 标题 | 仍「探索未至之境」 | `ui-conversation` `hero.headline` | 不改字。CI 禁止「探索未知之境」 |
| 浏览器 / 诊断 / 设置权限 sheet 的「关闭」「取消」 | `Text.foregroundStyle(T.ink)` + `.tint(T.ink)` | 禁止系统蓝强调色 | 仍是 sheet（未改成全页）；只去掉系统 tint |

本轮核对后**不改**（平台 / hide / 禁止发明）

- Account / shortcuts / open config / CompatibilityBanner / 审批通知：仍 **hide**。
- `chat.turnNavigation.*` / `chat.toBottom` / `ask.review` / hover chevron：仍 skip。
- 桌面 HeaderAction 更多菜单「下载 Session 日志」：仍不发明顶栏 ⋯。
- InputBar `.primary` 停止态圆角方块：fixture 不跑 `runningIdle`。
- 插件库存搜索仍 SF：桌面 `ui-plugin-manager` 无该搜索槽。
- Settings 默认权限仍走 `PermissionPickerSheet`（设置页点「权限」），不是 Composer chip；已去系统蓝。 → **R60 已改为桌面 `PermissionRow` inline Select**
- Start / Browser / Inspector 仍是 sheet（桌面是侧栏/菜单），未改成远程主机那样的全页。 → **R60 已改为 header 全屏页 / 全高侧栏式面板**
- Start 页顶上的大 globe：桌面 Guide 卡没有这枚装饰鲸/地球，列为剩余差异。 → **R60 已去掉装饰地球，按桌面 Guide 卡顶对齐**

## Round 60 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5`）

基线 `main` `8f2ea9c`（#68 Round 59）。桌面 pack 为第一依据；Android 只作参考。

### 本轮修

| 项 | 桌面源码 | iOS | 截图 |
| --- | --- | --- | --- |
| Start / Browser / Inspector 无 grabber sheet | `ui-sidebar-files` / `ui-sidebar-terminal` / `ui-sidebar-browser` Guide；desktop Start 是右侧栏默认页 | `HostSurfacePresentation.*UsesSystemSheet = false`；`model.push(.panel)` + `header()` 返回 | `light/dark-start.png` `*-browser.png` `*-inspector.png` |
| Start 去掉装饰地球、顶对齐 Guide 卡 | Guide cards 无 ornamental globe | `StartPanelPolicy.hasDecorativeGlobe = false`；`StartPanel` 顶对齐 12pt | `*-start.png` |
| 设置「权限」inline select | `ui-permission-presets` `PermissionRow.module.css` `.selector` 36 / radius-md 12 / pad 14 / gap 12 | `SettingsPermissionSelect` MenuSurface，删除 `PermissionPickerSheet` | `*-settings.png` |
| 轨迹 assistant / context 色 + Information 14 + chip radius-xs | `ui-trajectory` `.assistantVioletBright` / `.contextGreen`；InformationIcon 14；`--dsw-radius-xs` 4 | `srgbMix` token + `trajectoryKindIconSizePoints(for:)` + `dswRadiusXsPoints` | `*-trajectory.png` |
| Composer 停止内部 rect rx=3 | InputBar `.primary` 16×16 `<rect x=3 y=3 width=10 height=10 rx=3>` | `OfficialGlyph.stopRect` / `composerStopRect*` | `*-composerStop.png` |
| chat / slash 官方 chevron / check | primitives `IconChevronDownOutlineRegular` / `IconCheckOutlineArtwork` | `OfficialGlyph.chevronDown` / `.checkOutline` | `*-chat.png` `*-slash.png` `*-models.png` `*-permission.png` |
| 助手赞/踩可见 | `ui-message-feedback` Like/Dislike；`feedback.set` | fixture `ops` 含 `feedback.set` + `MessageFeedback` | `*-chat.png` |

本轮核对后**不改**（平台 / hide / 禁止发明）

- 插件列表搜索框（有意保留）。
- `turnNavigation` / `toBottom` FAB / `ask.review` / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state **行为**。
- 抽屉底栏「设置」与「绿点+远程主机名称」两枚独立按钮（间隔 ≥16pt）。
- 远程主机整页全屏；开抽屉 / 进设置 / 进远程主机收键盘。
- landing 鲸鱼 logo +「探索未至之境」；landing Composer 贴底。
- 权限 chip 只显示图标。

## Round 61 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*` alpha=`0.2.1-alpha.5`）

基线 `main` `4473e2f`（#69 Round 60）。桌面 pack 为第一依据；#69 CI `ios-simulator-screenshots` 逐屏看过；Android 只作参考。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 | 证据 |
| --- | --- | --- |
| landing 标题「探索未至之境」+ 鲸鱼 | **PASS** | `light/dark-landing.png`；`landingHeadline` + `official.fishLogo` |
| landing Composer 贴底 | **PASS** | composer 底边距窗口底 ≤ 40pt |
| 抽屉底栏两枚独立按钮 + 远程主机整页 | **PASS** | 设置 / 绿点+Mac mini；`connectionsScreen` 全屏标题「远程主机」 |
| 开抽屉 / 进设置 / 进远程主机不留键盘 | **PASS** | `KeyboardDismissalTests` |
| 聊天顶栏无分享；用户消息无常驻复制；权限 chip 只显示图标 | **PASS** | `*-chat.png` / `*-landing.png` |
| #69 已合项 | **PASS** | Start/Browser/Inspector 无 grabber；Start 无地球；设置权限 inline select；轨迹 color-mix；停止 rect rx=3；chevron/check/赞踩官方 SVG |

### 本轮修

| 屏幕 | 差异 | 桌面依据 |
| --- | --- | --- |
| landing / 聊天顶栏 | CI 仍是 SF `sidebar.left` / `sidebar.right`。改为 `IconPanelLeftOutline`；右侧 Start 为同一 artwork 水平镜像（primitives 无 PanelRight） | `ui-primitives` `IconPanelLeftOutlineArtwork` |
| 聊天助手行 | 复制 / 分支仍是 SF `square.on.square` / `arrow.triangle.branch`。改为 `IconCopyOutline` / `IconBranchOutline` | `ui-primitives` MessageIconActions / TurnTail |
| 设置 / Start / Browser / Inspector / 远程主机 / 插件 / 自动化 / 终端 | 返回仍是 SF `chevron.left`。改为 `IconChevronLeftOutline` | primitives Regular artwork |
| 浏览器 | 工具栏 plus / 前进后退 / 刷新 / 关闭 / 链接 / 外开仍是 SF。改为 plus / chevron L·R / refresh / close / link / right-up 官方 SVG | `ui-sidebar-browser` toolbar |
| 设置外观 | 浅色/深色/跟随系统仍是 SF sun/moon/desktopcomputer。改为 Light/Dark/Followsystem Medium | `ui-theme` AppearanceRow CUBES |
| 模型选择器 | 行尾用旋转的 chevronDown。改为 `IconChevronRightOutline` | primitives |
| XCUI 叶子 id | `openDrawer` / `openStartPanel` / `navBack` / `scheduleScreen` 父级 identifier 吞掉 `official.panelLeft`·`panelRight`·`chevronLeft`。Button 改 `.contain` + `.isButton`，与 `pluginInfoButton` 同模式 | 不改视觉，只让 CI 能看到官方 SVG |

本轮核对后**不改**（平台 / hide / 禁止发明）

- 插件列表搜索框（桌面 `ui-plugin-manager` 无该槽）。
- `turnNavigation` / `toBottom` FAB / `ask.review` / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state **行为**。
- 远程主机「扫码」行仍用 SF `qrcode.viewfinder`（桌面 primitives 无对应 QR artwork）。
- Inspector `viewfinder` / 类型过滤器；会话工具行 SF；Jobs 展开 chevron。
- 终端中间 ProgressView（品牌 tint，不发明 loading SVG 动画）。

## Round 62 对照清单（桌面 `@deepseek-ai/dsh-client-ui-deepseek-model-label-1017`；Android `33b97b2`）

基线 `main` `e2c3d9e`（#70 Round 61）。徽标几何跟桌面 `ui-primitives` `Tag` success，匹配条件跟 Android `ModelLabel.kt`。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| 抽屉底栏两枚独立按钮 + 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| landing 鲸鱼 logo +「探索未至之境」 | **PASS** |
| #68 / #69 / #70 已合项 | **PASS** |

### 本轮修

| 项 | 桌面 / Android | iOS |
| --- | --- | --- |
| Flash `1017` 绿色胶囊 | `Tag` success：`--dsw-alias-state-success-primary` 10% 底 + 同色字，11/17 Medium，padding 1×8，radius 999，gap 4。仅 `(deepseek-official\|deepseek-account) + deepseek-flash + DeepSeek-V4.1-Flash` | `modelReleaseBadge` + `ModelLabel`；Composer chip、选择器根「模型」行、列表项。徽标不进 route。无障碍读 catalog 原名 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- 插件列表搜索框（有意保留）。
- `turnNavigation` / `toBottom` FAB / `ask.review` / hover chevron。
- 抽屉底栏、远程主机全屏、键盘、鲸鱼 logo、「探索未至之境」、#68/#69/#70 已合项。

## Round 63 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android `33b97b2`）

基线 `main` `0b04aae`（#71 Round 62）。桌面是源。禁止自创颜色/图标；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69 Start/Browser/Inspector 全屏；#70 官方 SVG；#71 Flash 1017 | **PASS** |

### 本轮修：会话 / Jobs / 轨迹 leftover SF

| 屏幕 | 差异 | 桌面依据 |
| --- | --- | --- |
| chat 工具行 / PROCESS_ICONS | SF browse/terminal/curlybraces 等。改为 primitives PROCESS_ICONS | `ui-chat` PROCESS_ICONS + ToolRow |
| Jobs | 行 chevron / 停止仍像系统。改为 `IconChevronDownOutlineRegular` 旋转 + `IconStopFill` | `ui-jobs` JobListAction |
| 轨迹详情 | chevron / wrench / copy 改官方 | Trajectory detail + primitives |
| 插件内置刷新 | SF `arrow.clockwise` → `IconRefreshOutline` | plugin inventory |
| 压缩 / 命令卡 / 上下文注入 | `IconApiOutlineRegular` / `IconBrowseOutlineRegular` | CompactionItem / GenericCommandCard / ContextInjectionRow |

### 本轮修：远程主机配对链接（Android `9aa43c4` + `33b97b2`）

| 项 | Android / 桌面 | iOS |
| --- | --- | --- |
| 动作卡顺序 | 扫码 → 配对链接 → 输入地址 | 同序；扫码仍 SF `qrcode.viewfinder`（primitives 无 QR，有意 skip） |
| 配对链接行图标 | `D.link` = `IconLinkOutlineRegular` | `official.linkOutline` |
| 输入地址行图标 | Material `Icons.Outlined.Keyboard` 24×24 | `connections.keyboard`（照搬 Material path，不是 primitives，也不是 SF keyboard） |
| 配对链接流程 | `PairLinkSheet`：hint / 粘贴链接 / 下一步；解析失败出 `invalidPairingLink`；成功后预填配对确认，**不立刻连接** | 同文案、同按钮、同预填；`PairingUriPolicy` 对未完成百分号编码 fail-closed（`h=mac%`）。CI `22b3312` Dark：`replaceText` 中心 tap 使 caret 落在 `https://example.com` 中间，19 次 delete 删不干净，有效 URI 叠上去解析仍失败（无效文案残留、「下一步」禁用、未进预填）。不是二次解析缓存。TextField 改 `$text`；测试点右缘清空并用 predicate 等到 `value` 等于目标串。ConnActionRow `accessibilityLabel(title)` + contain/isButton（不用 Button+.contain，以免 tap 打到 glyph）。sheet 展开导出 `{light,dark}-pairingLink` |
| 页面 | 全屏 `ConnectionsScreen` | 仍全屏「远程主机」，无 sheet detent 列表 |

### 本轮修：抽屉工作区文件夹（桌面 `ui-workspace` `ProjectRowItem`）

| 项 | 桌面 | iOS |
| --- | --- | --- |
| 折叠 / 展开 logo | 折叠 `IconFolderCloseRegular`；展开填充 `IconFolderOpenRegular`（不是文件树 outline `folderOpen`） | `official.folderClose` / `official.folderOpenFill` |
| 「当前」条件 | `active = containsCurrentDescendant \|\| (expanded && containsCurrent)`。当前 = 拥有 `mainSessionId` 的工作区。祖先在子树折叠时保持高亮；当前行本身只在展开时高亮 | `workspaceGroupFolderIsActive` 同公式。landing `chat = nil` 不高亮 |
| 颜色 token | `.folder` `--dsw-alias-label-tertiary`；`.folderActive` `--dsw-alias-state-business-primary`（light `#4176E6` / dark `#7AAAFF`） | 闲置 `T.text3`；活动 `T.businessPrimary`。**不是** sidebar active 背景 `#E4EDFD` / `#353638` |
| 展开/收起 | hover 才把文件夹换成三角 chevron（skip） | 不发明常驻 chevron；展开态靠文件夹 open/close 本身 |

本轮核对后**不改**（平台 / hide / 禁止发明）

- 远程主机「扫码」无 primitives QR artwork。
- Inspector viewfinder / 类型过滤；终端中间 ProgressView。
- 工作区 hover-chevron 互换（触控无 hover）。
- 插件列表搜索框。
- `turnNavigation` / `toBottom` FAB / `ask.review` / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state **行为**。

## Round 64 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android `33b97b2` / `9aa43c4`）

基线 `main` `24948e1`（#72 Round 63）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69 Start/Browser/Inspector 全屏；#70 官方 SVG；#71 Flash 1017；#72 配对链接流程与当前工作区文件夹色 | **PASS** |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面 / Android | iOS | 处理 |
| --- | --- | --- | --- |
| 远程主机「已配对设备」卡 vs 扫码/配对链接/输入地址卡贴在一起 | Android `Card` `padding(vertical = 6.dp)`（`Screens.kt`）；两卡间距 12。桌面 `base.css` 只给 settings-card fill/stroke + `--dsw-radius-lg` | `VStack(spacing: 0)` + 全局 `card()` 无竖向 margin | `connCard` 外加 `connectionsCardVerticalPaddingPoints = 6`。CI `connectionsPairedCard`/`connectionsActionsCard` 间距 ≥11 |
| 配对链接 sheet 字号 / 圆角 / 禁用态 / 取消 | 桌面 `Button.module.css` 14/22、radius-md 12、`:disabled { opacity: 0.4 }`、outline 0.5px；`Input`/`ConnField` 14pt、pad 14×12。Android `PairLinkSheet` 标题 18 semibold、hint 13、按钮高 48。Android `PrimaryColors` Caption 禁用底 **不是** 桌面 | NavigationStack 系统栏；输入 `.body` 17；描边 1pt；按钮靠 padding 估高 | 去掉 NavigationStack；左上「取消」走 ghost 14/`T.ink`；输入 14 / pad 14×12；按钮高 48、字 14、圆角 12、描边 0.5、禁用 opacity 0.4 |
| landing 工作区 chip / AgentPresetSeat | 桌面 WorkspaceChip / WorkspacePicker：`IconChevronDownOutline` / `IconCheckOutline` / `IconPlusOutline` | SF `chevron.down` / `checkmark` / `plus` | 改官方 SVG。CI landing 禁 SF chevron/check，断言 `official.chevronDown` |

### 逐屏核对（light+dark）

| 屏 | 判定 | 说明 |
| --- | --- | --- |
| landing | **本轮修** | 工作区 chip 官方 chevron；标题/鲸/Composer 贴底不回归 |
| chat | **PASS** | #72 PROCESS_ICONS / 复制·分支；无分享、无用户常驻复制 |
| drawer | **PASS** | 设置 vs 绿点+主机名；当前工作区 `businessPrimary` 文件夹 |
| jobs | **PASS** | #72 官方 chevronDown / stopFill |
| trajectory / trajectoryDetail | **PASS** | #68/#72 KIND_ICON + 详情官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤无 primitives artwork |
| browser | **PASS** | #70 官方工具栏 |
| terminal | **skip** | 中间 ProgressView（不发明 loading SVG） |
| settings | **PASS** | #70 外观立方；权限 inline select。设置壳 `cpu`/`slider` 不在 CI `settings`（进的是通用页） |
| plugins / builtinPlugins | **skip / PASS** | 列表搜索框有意保留 SF；内置刷新已官方 |
| models / permission / slash | **PASS** | 官方 chevron/check；斜杠无数量 |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | 既有官方 SVG / 全屏 Start |
| connections / pairingLink | **本轮修** | 卡片 12pt 间距；配对 sheet primitives |

本轮核对后**不改**（平台 / hide / 禁止发明）

- `turnNavigation` / `toBottom` FAB / `ask.review` / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state **行为**。
- 插件列表搜索框（桌面 `ui-plugin-manager` 无该槽）。
- 扫码 QR / Inspector viewfinder / 终端 ProgressView（primitives 无 artwork）。
- Android `PrimaryColors` 禁用底 `Caption`：桌面 Button 是整钮 `opacity: 0.4`。
- 连接卡圆角保持 iOS `card()` radius-md 12（与设置卡同一套）；不单独改成 Android `R16`。
- 附近设备 `desktopcomputer`、管理 sheet `arrow.clockwise`/`trash`、Todo/Goal dock SF、设置壳 `cpu`：本轮未进 CI 主路径或缺一一对应 primitives，不发明。

## Round 65 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android `33b97b2`）

基线 `main` `b74d12f`（#73 Round 64）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69 Start/Browser/Inspector 全屏；#70 官方 SVG；#71 Flash 1017；#72 配对链接流程与当前工作区文件夹色；#73 卡片间距与配对 sheet primitives | **PASS** |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面 / Android | iOS | 处理 |
| --- | --- | --- | --- |
| 附近设备电脑图标 | Android `Icons.Outlined.Computer` 18 / `T.Accent`。primitives **无** IconComputer / IconLaptop / IconMonitor | SF `desktopcomputer`；未进 CI（附近列表空） | Material 24×24 path → `connections.computer`。CI fixture 种「客厅 Mac」，`connections` 禁 SF desktopcomputer，导出仍拍 `*-connections.png` |
| 管理 sheet 图标 | Android `ProfileManageSheet` `D.refresh` / `D.edit` / `D.trash` = primitives `IconRefreshOutlineRegular` / `IconEditOutlineRegular` / `IconTrashOutlineRegular`；`OptionRow` tint `T.Ink` | SF `arrow.clockwise` / `pencil` / `trash`，删除用自创 `T.err`；NavigationStack 系统取消栏 | 官方 SVG；删除改 `T.ink`；去掉 NavigationStack，ghost「取消」同配对 sheet。CI 打开 sheet，禁 SF，断言 `official.trashOutline` / refresh / edit，导出 `{light,dark}-manage.png` |
| paired→nearby 间距 | Android `ConnSectionTitle` 14/20 + pad 16/4，Card 竖向 6：6+16+20+4+6=52 | 标题用 14pt 默认行高（约 16.7），量到 48.5；断言曾放宽到 40–64 | 标题行高改 20。CI：标题 frame 夹在 paired/nearby 卡之间，间距 = `connectionsPairedNearbyGapPoints` ±2。nearby→actions 仍 11..<20 |
| 管理 / 配对 sheet 取消 | Android `PocketSheet` dragHandle `padding(top=10, bottom=14).size(40×4)`，`containerColor = T.Surface`。无取消行（下滑关） | 「取消」贴顶，命中约 29pt；背景 `T.bg` | 顶留白 `connectionsSheetDragHandleAreaPoints` 28；取消 `minHeight` 44 + `contentShape`。背景改 `T.surface`。manageAction 改为 Button |

### 逐屏核对（light+dark）

| 屏 | 判定 | 说明 |
| --- | --- | --- |
| landing | **PASS** | 标题/鲸/Composer 贴底；工作区 chip 官方 chevron |
| chat | **PASS** | 无分享、无用户常驻复制；Todo/Goal/Queue dock 有意 skip（fixture 无这些行） |
| drawer | **PASS** | 设置 vs 绿点+主机名；当前工作区 `businessPrimary` 文件夹 |
| jobs | **PASS** | 官方 chevronDown / stopFill |
| trajectory / trajectoryDetail | **PASS** | KIND_ICON + 详情官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤无 primitives artwork |
| browser | **PASS** | #70 官方工具栏 |
| terminal | **skip** | 中间 ProgressView（不发明 loading SVG） |
| settings | **PASS / skip** | 外观立方 + 权限 inline。设置壳模型行仍 SF `cpu`：CI `settings` 进的是通用页；桌面/Android 是 `IconDataOutlineMedium`，下轮若加 `settingsShell` 再搬 |
| plugins / builtinPlugins | **skip / PASS** | 列表搜索框有意保留 SF；内置刷新已官方 |
| models / permission / slash | **PASS** | 官方 chevron/check；斜杠无数量 |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | 既有官方 SVG / 全屏 Start |
| connections / pairingLink / nearby / manage | **本轮修** | 附近 Material Computer；ConnSectionTitle 14/20 + 16/4（paired→nearby 52pt 结构断言）；管理/配对 sheet `T.Surface` + PocketSheet dragHandle 28pt 顶留白 + 取消 ≥44pt；manageAction 为单一 Button |

### npm dist-tag（只报告，不 bump 基线）

`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`，`latest` 仍旧线。pack 对比 21 包 locale / `.tsx` / CSS / 组件 API **无增量**。仅 `package.json` 版本，以及 `ui-sidebar` `localBuildVersion` `0.2.1-alpha.5-aeba8e9` → `0.2.1-rc.2-332895e`、`ui-settings-general` `CurrentVersionRow` 版本字符串。

本轮核对后**不改**（平台 / hide / 禁止发明）

- `turnNavigation` / `toBottom` FAB / `ask.review` / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state **行为**。
- 插件列表搜索框（桌面 `ui-plugin-manager` 无该槽）。
- 扫码 QR / Inspector viewfinder / 终端 ProgressView（primitives 无 artwork）。
- Todo/Goal/Queue dock SF：桌面有 `IconChecklistOutline` / `IconGoalOutline` / `IconTrashOutline` / `IconEditOutline`，但 CI chat fixture 不画这些 dock，本轮不加行以免改 `*-chat.png`。
- 设置壳模型行 SF `cpu`：CI 进通用页；对应桌面 `IconDataOutlineMedium`。
- 工作区 hover-chevron 互换（触控无 hover）。

## Round 66 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android `33b97b2`）

基线 `main` `f423310`（#74 Round 65）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69 Start/Browser/Inspector 全屏；#70 官方 SVG；#71 Flash 1017；#72 配对链接流程与当前工作区文件夹色；#73 卡片间距与配对 sheet primitives；#74 附近电脑图标/管理 sheet 官方 SVG/取消 ≥44pt/分组标题行高 20 | **PASS** |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面 / Android | iOS | 处理 |
| --- | --- | --- | --- |
| 配对链接输入框 vs「粘贴链接 / 下一步」水平边距 | Android `PairLinkSheet`：`ConnField` 外沿 18、按钮行 22。桌面 Input wrap pad 只是内部 `0 8`，没有这层 sheet inset。Phone chrome 是 SheetTitle / hint / 按钮已经在用的 22 | 输入框贴 ~20pt（18 leftover），按钮 ~25pt（22） | 输入框改 `connectionsSheetContentPaddingPoints = 22`，与按钮同一 token。CI 用 `connectionsPairingLinkFieldBounds`（字段列 overlay 上的 UIKit host，**不是** ZStack 兄弟、**不是** TextField overlay）对按钮行 minX/maxX ±1pt |
| 配对链接 sheet 版式被撑开 | #74：输入框紧跟说明、按钮紧跟输入框。Android 按钮行 `padding(vertical = 14.dp)` | #75 `d41d329`：`PairingFieldBoundsHost().frame(maxHeight: .infinity)` 作 ZStack 兄弟吃掉底部 Spacer，输入框掉到中部、按钮贴底 | host 改挂字段列 `.overlay`，不参与布局。小标签去掉 ConnField 18 leftover 的 +4（26→22）与标题对齐。CI：hint→字段 ≤24pt；「粘贴链接」− 字段 ≈14±4；小标签 vs 标题 minX ±1pt。host 仅 UITestLaunch 时进无障碍树 |
| Todo / Goal / Queue dock SF | 桌面 `TodoPanel` / `GoalBar` / `QueueDock`：`IconChecklistOutlineRegular` / `IconGoalOutlineRegular` / `IconQueueOutlineRegular`（ChatLinesOutline，id 与视图选项 `official.queue` 分开）+ 队列动作 `IconEditOutline` / `IconTrashOutline` / `IconSendOutlineRegular`（不是 InputBar filled send） | SF `checklist` / `target` / `text.line.first.and.arrowtriangle.forward` / `pencil` / `trash` / `paperplane`；CI `chat` fixture 不画这些行 | 官方 SVG。steer 用 `official.sendOutline`。新 CI 屏 `chatDock`（light+dark），不改 `*-chat.png` |
| 设置壳模型行 SF `cpu` | 桌面/Android 设置壳「模型」是 `IconDataOutlineMedium`（fill 圆柱 + `ICON_MEDIUM_STROKE` 1.3 齿轮）。通用 `IconSettingsOutlineRegular`，预设 `IconAgentPresetOutline` | SF `cpu`；CI `settings` 进的是通用页 | `official.dataOutline` size 16。新 CI 屏 `settingsShell`。删掉无人调用的 SF `nav(_:system:)` |

### 有意 skip（桌面源码依据）

| 项 | 判定 | 依据 |
| --- | --- | --- |
| 管理 sheet「删除」无确认 | **skip** | Android `ProfileManageSheet` `ConnOptionRow(L.delete())` 直接 `Pocket.removeProfile; onDismiss()`，无 `AlertDialog`。桌面 Host `ui-settings` pocket 是电脑二维码页，不是这张手机管理 sheet，没有对应 Modal |
| `/` 菜单行图标仍 SF | **skip / 下轮** | 桌面/Android `CommandPopupSheet`：`D.paperclip` / `D.data` / `D.goal` / `D.plan` / `D.paperPlane` / `D.compact` / `D.permission` / `D.download` = primitives Outline。iOS `commandMenuIconSymbol` 仍是 SF。缺尚未提取的 `IconPaperclipOutline`；本轮不扩 slash 以免改 `*-slash.png` |
| 计划 chip `D.plan` SF | **skip** | 桌面 modes 行是 `IconPlanOutlineRegular`。CI `chat`/`landing` `planMode=false`，chip 不进截图 |
| 通用设置 Toggle / 语言 Picker | **skip** | 桌面 PreferenceRow 是自定义开关 / MenuSurface。Phone 映射为 `.labelsHidden()` Toggle 与 `Picker` `.tint(T.ink)`，不是系统蓝 ActionSheet。无 primitives 开关 artwork |
| Todo in_progress `ProgressView` | **skip** | primitives 无 loading artwork（与终端 ProgressView 同一铁律） |

### 逐屏核对（light+dark）

| 屏 | 判定 | 说明 |
| --- | --- | --- |
| landing | **PASS** | 标题/鲸/Composer 贴底；工作区 chip 官方 chevron |
| chat | **PASS** | 无分享、无用户常驻复制。dock 改走 `chatDock`，本屏不加行 |
| chatDock | **本轮修** | Todo/Goal/Queue 官方 SVG；禁 SF checklist/target/pencil/trash/paperplane |
| drawer | **PASS** | 设置 vs 绿点+主机名；当前工作区 `businessPrimary` 文件夹 |
| jobs | **PASS** | 官方 chevronDown / stopFill |
| trajectory / trajectoryDetail | **PASS** | KIND_ICON + 详情官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤无 primitives artwork |
| browser | **PASS** | #70 官方工具栏 |
| terminal | **skip** | 中间 ProgressView（不发明 loading SVG） |
| settings | **PASS** | 外观立方 + 权限 inline。仍进通用页 |
| settingsShell | **本轮修** | 模型 `IconDataOutlineMedium`；禁 SF cpu/slider/person.crop.circle |
| plugins / builtinPlugins | **skip / PASS** | 列表搜索框有意保留 SF；内置刷新已官方 |
| models / permission / slash | **PASS / skip** | 官方 chevron/check；斜杠无数量。slash 行图标仍 SF，见上 |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | 既有官方 SVG / 全屏 Start |
| connections / pairingLink / nearby / manage | **本轮修 / PASS** | 输入框与按钮 22pt 对齐 ±1pt。输入框紧跟说明、按钮紧跟输入框（#74 版式）。小标签与标题 22pt 对齐。删除无确认（Android 同源）。附近/管理 #74 不回归 |

### npm dist-tag（只报告，不 bump 基线）

`npm view @deepseek-ai/dsh-client-ui-primitives dist-tags`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`，`latest` 仍旧线 `0.0.1-rc.1`。`0.2.1-alpha.5` 之后没有新的 alpha。rc.2 相对 alpha.5 的 UI 增量与 #74 相同（只报告，不升级）。

本轮核对后**不改**（平台 / hide / 禁止发明）

- `turnNavigation` / `toBottom` FAB / `ask.review` / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state **行为**。
- 插件列表搜索框（桌面 `ui-plugin-manager` 无该槽）。
- 扫码 QR / Inspector viewfinder / 终端 ProgressView（primitives 无 artwork）。
- 管理 sheet 删除确认（Android 立即删除；桌面 pocket 不是这张 sheet）。
- `/` 菜单行 SF 图标（缺 paperclip 提取；下轮再搬）。
- 工作区 hover-chevron 互换（触控无 hover）。

## Round 67 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android 仅参考）

基线 `main` `c0eee71`（#76 Round 66 hotfix）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69 Start/Browser/Inspector 全屏；#70 官方 SVG；#71 Flash 1017；#72 配对链接流程与当前工作区文件夹色；#73 卡片间距与配对 sheet primitives；#74 附近电脑图标/管理 sheet 官方 SVG/取消 ≥44pt/分组标题行高 20；#75 配对 22pt inset + dock/设置壳官方 SVG；#76 PairLinkSheet 版式 | **PASS** |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面 | iOS | 处理 |
| --- | --- | --- | --- |
| `/` 菜单行图标仍 SF | `ui-commands` `HOST_FACES`：`IconGoalOutlineRegular` / `IconPlanOutlineRegular` / `IconPaperPlaneOutlineRegular` / `IconCompactOutlineRegular` / `PermissionIconFullAccessRegular` / `IconDownloadOutlineRegular`。`ui-conversation` `/file` = `IconPaperclipOutlineRegular`。`ui-model-selection` `/model` = `IconDataOutlineRegular`。`ui-input-trigger` MenuView `.itemIcon` 14×14 `size: 14` | `commandMenuIconSymbol` 仍是 SF `paperclip` / `cylinder.split.1x2` / `target` / `doc.text` / `paperplane` / `circle.circle` / `shield` / `square.and.arrow.down` | 提取官方 path。行图标改 `OfficialGlyph` Regular 14。模型行 Regular（设置壳仍 Medium）。技能行 `official.sparkle`。CI `*-slash.png` 断言 8 个 official.*，禁对应 SF |

### 有意 skip（桌面源码依据）

| 项 | 判定 | 依据 |
| --- | --- | --- |
| 管理 sheet「删除」无确认 | **skip** | Android `ProfileManageSheet` 直接 `removeProfile`。桌面 `ui-settings@0.2.1-alpha.5` pocket 是电脑二维码/设备页，无这张手机管理 sheet，也无 delete confirm Modal。不发明对话框 |
| #76 后 pairingLink inset | **PASS / 不改** | 标题 / hint / 字段列 / 按钮行都走 `connectionsSheetContentPaddingPoints = 22`。CI minX/maxX ±1pt、hint→字段 ≤24、按钮行 14±4、小标签 vs 标题 ±1pt 已锁 |
| 计划 chip `D.plan` SF | **skip** | 桌面 modes 行 `IconPlanOutlineRegular`。CI `chat`/`landing` `planMode=false` |
| 通用设置 Toggle / 语言 Picker | **skip** | 桌面 PreferenceRow 自定义开关 / MenuSurface。Phone `.labelsHidden()` Toggle 与 `Picker` `.tint(T.ink)`，不是系统蓝 ActionSheet |
| Todo in_progress / 终端 / slash loading `ProgressView` | **skip** | primitives 无 loading artwork |
| 扫码 QR / Inspector viewfinder / 类型过滤 | **skip** | primitives 无对应 artwork |
| 插件列表搜索框 SF magnifyingglass | **skip** | 桌面 `ui-plugin-manager` 无该槽 |
| `turnNavigation` / toBottom FAB / ask.review / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state | **skip** | 既定平台 / hide / 禁止发明 |
| 提及气泡 / 文件 `bubble.left` `doc`、变更卡 `doc.on.doc`、文件树 FileTypeIcon、反馈 checkmark、风险三角、目录选择 chevron/pencil | **skip** | 非本轮 slash 行；桌面 mention/file-type 另有 ReferenceIcon / CodeFileIcon，未进本轮提取 |

### 逐屏核对（light+dark）

| 屏 | 判定 | 说明 |
| --- | --- | --- |
| landing | **PASS** | 标题/鲸/Composer 贴底；工作区 chip 官方 chevron |
| chat | **PASS** | 无分享、无用户常驻复制。计划 chip 仍 skip |
| chatDock | **PASS** | #75 Todo/Goal/Queue 官方 SVG |
| drawer | **PASS** | 设置 vs 绿点+主机名；当前工作区 `businessPrimary` 文件夹 |
| jobs | **PASS** | 官方 chevronDown / stopFill |
| trajectory / trajectoryDetail | **PASS** | KIND_ICON + 详情官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤无 primitives artwork |
| browser | **PASS** | #70 官方工具栏；线性 ProgressView 是 WK 加载，无 primitives 进度条 artwork |
| terminal | **skip** | 中间 ProgressView（不发明 loading SVG） |
| settings | **PASS** | 外观立方 + 权限 inline。Toggle/Picker 有意 skip |
| settingsShell | **PASS** | 模型 `IconDataOutlineMedium` |
| plugins / builtinPlugins | **skip / PASS** | 列表搜索框有意保留 SF；内置刷新已官方 |
| models / permission | **PASS** | 官方 chevron/check |
| slash | **本轮修** | 行图标官方 SVG；无数量；权限 popupSelect 官方 check |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | 既有官方 SVG / 全屏 Start |
| connections / pairingLink / nearby / manage | **PASS** | #76 版式不回归。删除无确认（桌面无对应 Modal） |

### npm dist-tag（只报告，不 bump 基线）

`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`，`latest` 仍旧线。`0.2.1-alpha.5` 之后没有新的 alpha。primitives `lib/index.js` 与 commands `lib/client.js` 的 sha256 在 alpha.5 与 rc.2 **相同**（locale / 组件 API **无增量**）。只报告，不升级。

本轮核对后**不改**（平台 / hide / 禁止发明）

- `turnNavigation` / `toBottom` FAB / `ask.review` / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state **行为**。
- 插件列表搜索框（桌面 `ui-plugin-manager` 无该槽）。
- 扫码 QR / Inspector viewfinder / 终端 ProgressView（primitives 无 artwork）。
- 管理 sheet 删除确认（Android 立即删除；桌面 pocket 不是这张 sheet）。
- 工作区 hover-chevron 互换（触控无 hover）。

## Round 68 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android 仅参考）

基线 `main` `e61c87d`（#77 Round 67：`/` 菜单官方 SVG）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69 Start/Browser/Inspector 全屏；#70 官方 SVG；#71 Flash 1017；#72 配对链接流程与当前工作区文件夹色；#73 卡片间距与配对 sheet primitives；#74 附近电脑图标/管理 sheet 官方 SVG/取消 ≥44pt；#75 配对 22pt inset + dock/设置壳官方 SVG；#76 PairLinkSheet 版式；#77 `/` 菜单 8 个 official.* | **PASS** |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面源码 | iOS 原状 | 处理 |
| --- | --- | --- | --- |
| 计划 chip `D.plan` SF `doc.text` | `ui-plan` `PlanModeControl` / `PlanChip`：`IconPlanOutlineRegular` size 14（`IconListPenOutlineArtwork`，与 `/plan` 同行 Regular） | `ChatView` modes 行 `Image(systemName: D.plan)` | 换成 `OfficialGlyph.planOutline`。CI 加 `planMode` 屏：断言 `official.planOutline`、禁 `doc.text`、文案「计划」、占位「描述你的任务以生成计划」 |
| 提及气泡 `bubble.left` / `doc` | `ui-primitives` `ReferenceIconRegular`：`session`→`ChatLinesOutlineArtwork`（`IconQueueOutline`）、`file`→`BrowseOutlineArtwork`、`folder`→`FolderCloseArtwork`。`ReferenceChip` size 16；菜单行 14 | chip / 面板仍 SF | chip 16 / 面板 14 官方 SVG。CI 加 `mention` 屏：断言 `official.queueOutline` / `browseOutline` / `folderClose`，禁 `bubble.left` `doc` |
| 反馈选中 ✓ | `ui-input-trigger` MenuView 选中态 `IconCheckOutlineRegular` | `FeedbackCategorySheet` SF `checkmark` | `OfficialGlyph.checkOutline` 14 |
| 权限风险英雄图标 | `ui-primitives` `RiskConfirmation`：`IconWarningOutlineRegular` size 18（**圆圈+叹号**，不是三角） | `PermissionRiskSheet` SF `exclamationmark.triangle` | `OfficialGlyph.warningOutline` 18。勾选框仍是系统 checkbox（桌面是原生 `<input type="checkbox">`，primitives 无 checkbox artwork） |
| 文档预览缺字体 | `ui-sidebar-documentpreview` `IconWarningTriangleOutlineRegular` | `FilePreview` `OfficeFontWarning` SF 三角 | `OfficialGlyph.warningTriangle` |
| 目录选择 chevron / pencil / ✓ | 面包屑与列披露 `IconChevronRightOutlineRegular`；改路径 `IconEditOutlineRegular`；显示隐藏 `IconCheckOutlineRegular` | `WorkspaceDirectoryPicker` SF `chevron.right` / `pencil` / `checkmark` / `plus` | 换成官方 chevronRight / editOutline / checkOutline / plusOutline |
| 文件树传统类型 | `ui-primitives` `FileTypeIcon` `FileGlyph` 28×28 折角纸 + 分类 mark；`--dsw-static-neutral-00` 白标；`other` 折角 `--dsw-static-neutral-400` `#a2a4a6` | `FileTypeIcon` SF `doc.richtext` / `photo` / `tablecells` / … | 提取 `FILE_BODY`/`FILE_FOLD` 与 9 类 mark。树图标 16pt。文件夹仍官方 open/close。socket/fifo `warning` 用圆圈 `IconWarningOutline`（桌面 FileTypeIcon 无 warning 档，Host `other` 走 warning 语义） |
| 文件树工具栏 play/pause/reload | `ui-sidebar-files` header：`IconPauseOutlineRegular` / `IconPlayOutlineRegular` / `IconRefreshOutlineRegular` | `FilesPanel` SF `pause` / `play.fill` / `arrow.clockwise`；预览刷新同 SF | 换成官方 pause/play/refresh |

### 查过但本轮不提取（写明包/文件）

| 项 | 查过 | 结论 |
| --- | --- | --- |
| 语言 `CODE_FILE_ARTWORK`（python/go/swift/…） | `ui-primitives@0.2.1-alpha.5` `lib/index.js` `#region lib/types/code-file-icon-artwork.js`；`CodeFileIcon` 把整段 inner SVG（`text` / `clipPath` / `linearGradient` / 嵌套 `<svg>`）塞进 20×20 viewBox | 现有 `SVGPath` 只吃 path `d`，不能画这套全彩 markup。**不发明**简化图标。继续 `doc.fill`。下轮若加 WKWebView/`SVGRenderer` 再搬 |
| Markdown 行内 fileChip `Text(Image(systemName: "doc"))` | 桌面 `ReferenceChip` 用 `ReferenceIconRegular` size 16 | SwiftUI `Text` 拼接不能嵌 `Canvas` OfficialGlyph。不发明 raster 附件。**skip** |
| 变更卡 `doc.on.doc` / `doc.text` | `ui-chat` / `ui-workspace` 无独立「多文件叠层」artwork；单文件应对 `FileTypeIcon` | 多文件卡无官方叠层 SVG。**skip 不发明** |
| 权限确认勾选 `checkmark.square.fill` | `RiskConfirmation` 原生 checkbox | primitives 无 checkbox artwork。**skip** |

### 有意 skip（桌面源码依据）

| 项 | 判定 | 依据 |
| --- | --- | --- |
| 管理 sheet「删除」无确认 | **skip** | Android 立即 `removeProfile`。桌面 pocket 无这张 sheet / 无 delete Modal |
| 通用设置 Toggle / 语言 Picker | **skip** | 桌面 PreferenceRow 自定义开关 / MenuSurface。Phone `.labelsHidden()` Toggle + `Picker` `.tint(T.ink)`，不是系统蓝 ActionSheet |
| Todo in_progress / 终端 / slash loading `ProgressView` | **skip** | primitives 无 loading artwork |
| 扫码 QR / Inspector viewfinder / 类型过滤 | **skip** | primitives 无对应 artwork |
| 插件列表搜索框 SF magnifyingglass | **skip** | 桌面 `ui-plugin-manager` 无该槽 |
| `turnNavigation` / toBottom FAB / ask.review / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state | **skip** | 既定平台 / hide / 禁止发明 |

### 逐屏核对（light+dark）剩余 SF / 系统控件

| 屏 | 判定 | 剩余 SF / 系统控件 | 处理结论 |
| --- | --- | --- | --- |
| landing | **PASS** | 无计划 chip（`planMode=false`） | 标题/鲸/Composer 贴底 |
| chat | **PASS** | 无计划 chip | 无分享、无用户常驻复制 |
| planMode | **本轮修** | — | 官方 plan chip + 占位 |
| mention | **本轮修** | — | 官方 session/file/folder 提及图标 |
| chatDock | **PASS** | Todo `in_progress` `ProgressView` | 有意 skip |
| drawer | **PASS** | — | 设置 vs 绿点+主机名 |
| jobs | **PASS** | — | 官方 chevronDown / stopFill |
| trajectory / trajectoryDetail | **PASS** | — | KIND_ICON + 详情官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤 | primitives 无 artwork |
| browser | **PASS** | WK 线性 `ProgressView` | 无 primitives 进度条 |
| terminal | **skip** | 中间 `ProgressView` | 不发明 loading SVG |
| settings | **PASS** | Toggle / 语言 `Picker` | 有意 skip，非系统蓝 |
| settingsShell | **PASS** | — | 模型 `IconDataOutlineMedium` |
| plugins / builtinPlugins | **skip / PASS** | 列表搜索框 SF magnifyingglass | 桌面无该槽 |
| models / permission | **PASS** | — | 官方 chevron/check |
| slash | **PASS** | loading `ProgressView` | #77 行图标；loading skip |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | — | 既有官方 SVG / 全屏 Start |
| connections / pairingLink / nearby / manage | **PASS** | 管理删除无确认 | #76 版式不回归 |
| 文件树 / 目录选择 / 反馈 sheet / 风险 sheet | **本轮修** | 语言 CODE_FILE 仍 `doc.fill`；风险 checkbox 系统方框；预览 wrap/copy 仍 SF | 传统 FileGlyph + 工具栏 play/pause/refresh |

### npm dist-tag（只报告，不 bump 基线）

`npm view @deepseek-ai/dsh-client-ui-primitives`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`，`latest` 仍 `0.0.1-rc.1`。alpha.5 之后**没有新的 alpha**。rc.2 与 alpha.5 的 primitives `lib/index.js` / commands `lib/client.js` sha256 **相同**（locale / 组件 API 无增量）。**只报告，不升级基线。**

## Round 69 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android 仅参考）

基线 `main` `83e5e70`（#78 Round 68：计划 chip / 提及 / FileGlyph / 风险与目录官方 SVG）。本轮把 #79 rebase 到该 tip。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

真机反馈：新会话 landing 顶栏没有右侧栏按钮，对话页右上角有。同时对齐桌面终端不可用 / 断线 / 缺失空态。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页 | **PASS** |
| 开抽屉 / 滚动 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69–#77 既有对齐；#78 计划 chip / 提及 / FileGlyph / 风险圈叹号 / 目录 chevron；CI `planMode` + `mention` | **PASS**（rebase 后全部保留，断言未放宽、未删） |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面源码 | iOS 原状 | 处理 |
| --- | --- | --- | --- |
| 连接恢复后不重新 attach | Android `online` attach effect；桌面 `TerminalBody` `phase === "disconnected"` 点 `reconnect` → `model.connect()` | `isOnline` 回 true 不重开 follow | `terminalShouldAttachOnOnline`；`onChange(of: model.isOnline)` 重新 `openTerminal`。protocol 锁四态 |
| 传输掉线清画面 | 桌面 README.zh：暂时断线保留屏幕并提供 **重新连接**，不展示传输内部错误。`TerminalBody` `state.info !== void 0` 仍画 `TerminalScreen` | 掉线常清 `TerminalMeta` | `resetTerminalAttachment(keepScreen: true)`。状态行 `terminalDisconnectedCopy`「连接已断开。」+ outline「重新连接」。离线不画 `failed` 段 |
| `terminal.error` / attach 失败 | `t("failed")` =「终端错误：{message}」；`._UE8Aa_error` padding 10/12、`bg-l2`、`label-primary` | 只 toast，不进 `.error` 段 | `terminalFailure`；`terminalFailureCopy`。离线不显示。CI `terminalUnavailable` |
| 已回收终端死循环「重新连接」 | `state.issue === "missingTerminal"`：36×36 SVG `viewBox 0 0 28 28`、`#17191d` 底板、`m8 10 4 4-4 4M15 18h5` 白描、文案「此终端已不存在，请新建终端。」、primary md「新建终端」+ `IconPlusOutlineRegular` | `selectTerminal` 抛 `terminal/unavailable` 仍走重连 | `terminalMissing` 空态。英文跟桌面 `Open a new terminal.`（原 PR 误写成 `Create a new one.`，本轮改回） |
| 状态行系统蓝 + SF `arrow.clockwise` | `._UE8Aa_status`：`bg-l2`、`padding: 5px 12px`、`gap: 8px`、全宽。outline sm：高 28、字 12/18、横垫 10、`radius-sm` 6、描边 `0.5px` | 居中 / 系统蓝 / SF 刷新 | 左对齐 outline，`T.ink` / `T.border`。禁 `arrow.clockwise` |
| 无 `state.info` 仍画画布 | 桌面 `state.info !== void 0` 才 `TerminalScreen` | 空白 snapshot 也能开始选择 | 无 meta 不画 `TerminalView` / 快捷键条；`terminalGridIsBlank` 拒选 |
| 快捷键条键帽 / glyph | 桌面无键帽条（真键盘）。Android `TerminalView.kt` `TerminalKey` 英文 `Ctrl+V`/`Cmd+V`、`Copy`/`Cmd+C`，图标 20.dp | SF `keyboard` / `checkmark` | 官方 `keyboard` / `checkOutline` 20pt。会话菜单 check / plus 同官方 SVG |
| landing 无右侧栏按钮 | 对话顶栏已有 `OfficialGlyph.panelRight` 16 + `openStartPanel`（#70）。桌面新会话是空白 session，右侧栏始终可开 | `emptyChat` 顶栏只有 `panelLeft` | 与 ChatView 同一 `panelRight` / `openStartPanel`。CI 断言与 `panelLeft` 齐平且在窗口右半 |
| 无会话开「工作区文件 / 新建终端」 | 桌面 Guide 入口落在当前 session | landing 无 session | 先 `createAndOpenSession(workspaceId: draftWorkspaceId)`（`landingComposerNeedsWorkspace` 则 toast），再 push 面板。浏览器仍直接开 |

### 截图对照（旧 #79 CI `ios-simulator-screenshots` + 本轮源码；light+dark）

| 屏 | 判定 | 对照 |
| --- | --- | --- |
| `*-landing.png` | **PASS** | 顶栏左 `panelLeft`、右 `panelRight`，无 SF sidebar。标题「探索未至之境」+ 官方鲸。Composer 贴底。发送是官方实心圆，无系统蓝 |
| `*-terminalUnavailable.png` | **PASS** | 「终端错误：terminalController.follow(...) is not a function」。状态行左对齐 outline「重试」（无 `state.info` 且非断线 → `retry`）。无键帽条、无 SF `arrow.clockwise`/`keyboard`/`checkmark` |
| `*-terminalMissing.png` | **PASS** | 36pt 官方 SVG（深色圆角底板 + `>_`）。「此终端已不存在，请新建终端。」primary「+ 新建终端」（`button-primary-fill` `#0F1115` / dark `#F9FAFB`，不是系统蓝）。无「重新连接」 |
| `*-terminalDisconnected.png` | **PASS** | 「连接已断开。」+ outline「重新连接」。画面保留 `preserved-shell-output`。键帽条灰显英文 `Esc`/`Tab`/`Ctrl+C`/`Ctrl+D`/`Ctrl+V`/`Copy` + 官方 keyboard。头栏「离线」 |

### 查过但本轮不提取（写明包/文件）

| 项 | 查过 | 结论 |
| --- | --- | --- |
| outline 描边 `border-l3` | `ui-primitives` `Button.module.css` `.outline`：`0.5px solid var(--dsw-alias-border-l3)` | `DswColors` 只铺了 `borderL2` / `borderL4`（theme 注释仍 alpha.2）。配对链接等既有 outline 已用 `T.border`（l2）。**不发明** l3 色值 |
| 右侧栏 ExpandButton 用 `IconPanelLeft` | `ui-sidebar-right` `ExpandButton`：栏内折叠是 `IconPanelLeftOutlineRegular` | 手机顶栏按钮是**打开** Start，与 #70 ChatView `panelRight` 同一语义。不改成 panelLeft |
| 语言 CODE_FILE / Markdown 行内 fileChip / 变更卡叠层 / 风险 checkbox | #78 已记 | **不发明**。rebase 后原样保留 |

### 有意 skip（桌面源码依据）

| 项 | 判定 | 依据 |
| --- | --- | --- |
| 终端中间 `ProgressView` | **skip** | primitives 无 loading artwork。`terminalCenterLoadingUsesOfficialGlyph` 已锁 |
| 手机快捷键条 | **平台** | 桌面无此条；Android `33b97b2` `TerminalView.kt`。键帽保持英文 |
| 退出终端 `confirmationDialog` | **skip / 既有** | 桌面 close 走 Host cleanup，不是这张手机确认。本轮不改、不发明 Modal |
| 管理 sheet「删除」无确认 | **skip** | Android 立即 `removeProfile`。桌面 pocket 无这张 sheet |
| 通用设置 Toggle / 语言 Picker | **skip** | 非系统蓝 ActionSheet |
| `turnNavigation` / toBottom FAB / ask.review / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / stop-state | **skip** | 既定平台 / hide / 禁止发明 |

### 逐屏核对（light+dark）剩余 SF / 系统控件

| 屏 | 判定 | 剩余 SF / 系统控件 | 处理结论 |
| --- | --- | --- | --- |
| landing | **本轮修** | 无计划 chip（`planMode=false`） | 右侧栏按钮 + 标题/鲸/Composer 贴底 |
| chat / planMode / mention | **PASS** | — | #78 官方 plan / 提及；顶栏已有 panelRight |
| chatDock | **PASS** | Todo `in_progress` `ProgressView` | 有意 skip |
| drawer | **PASS** | — | 设置 vs 绿点+主机名 |
| jobs | **PASS** | — | 官方 chevronDown / stopFill |
| trajectory / trajectoryDetail | **PASS** | — | KIND_ICON + 详情官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤 | primitives 无 artwork |
| browser | **PASS** | WK 线性 `ProgressView` | 无 primitives 进度条 |
| terminal | **skip** | 中间 `ProgressView` | 不发明 loading SVG |
| terminalUnavailable / terminalMissing / terminalDisconnected | **本轮修** | 退出确认既有 `confirmationDialog` | 见上表 |
| settings | **PASS** | Toggle / 语言 `Picker` | 有意 skip，非系统蓝 |
| settingsShell | **PASS** | — | 模型 `IconDataOutlineMedium` |
| plugins / builtinPlugins | **skip / PASS** | 列表搜索框 SF magnifyingglass | 桌面无该槽 |
| models / permission | **PASS** | — | 官方 chevron/check |
| slash | **PASS** | loading `ProgressView` | #77 行图标；loading skip |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | — | 既有官方 SVG / 全屏 Start |
| connections / pairingLink / nearby / manage | **PASS** | 管理删除无确认 | #76 版式不回归 |
| 文件树 / 目录选择 / 反馈 sheet / 风险 sheet | **PASS** | 语言 CODE_FILE 仍 `doc.fill`；风险 checkbox 系统方框 | #78 保留 |

### npm dist-tag（只报告，不 bump 基线）

`npm view`：`alpha` 仍 `0.2.1-alpha.5`，`next` 仍 `0.2.1-rc.2`。`@deepseek-ai/dsh-client-ui-primitives` `latest` 仍 `0.0.1-rc.1`；`ui-sidebar-terminal` `latest` `0.1.6-alpha.1`；`ui-sidebar-right` `latest` `0.1.5-alpha.1`。alpha.5 之后**没有新的 alpha**。本轮 pack 核对：

- primitives `lib/index.js` sha256 `333ea89e7518ec1f1d33111bb9c65d382454bcc3638ebac7116253c92fe5d566`（与 #78 相同）
- sidebar-terminal `lib/client.js` sha256 `999adc8712854da63dd62944c51af1bf57fd9bdfcb65e7ad0d8c196f6e979b73`；`lib/client.terminal.js` sha256 `0821b155ce820424ff788474fedea3e6f606d95cea6ebe03b580660e7701eb6f`
- sidebar-right `lib/client.js` sha256 `55e410c962d9373ed6588b9ec6f5b848241e2979d1b7d578f149b2a23428ec14`

locale / 组件 API **无增量**。**只报告，不升级基线。**

## Round 70 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android 仅参考）

基线 `main` `da77aac`（#79 Round 69：终端三态 + landing `panelRight`）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| landing 顶栏左 `panelLeft` 右 `panelRight`（#79） | **PASS** |
| 终端三态（unavailable「终端错误：…」+ 左对齐 outline；missing 36pt 官方 SVG+「新建终端」；disconnected 保留画面+「重新连接」） | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页；开抽屉 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69–#78 既有官方 SVG 与 CI 断言（planMode / mention / `/` 菜单 8 个 `official.*` / PairLinkSheet 版式） | **PASS**（断言未放宽、未删） |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面源码 | iOS 原状 | 处理 |
| --- | --- | --- | --- |
| 语言 `CODE_FILE_ARTWORK` | `ui-primitives@0.2.1-alpha.5` `lib/index.js` `#region lib/types/code-file-icon-artwork.js`；`CodeFileIcon` 把 inner SVG（`text` / `clipPath` / `linearGradient` / 嵌套 `<svg>`）塞进 20×20 viewBox。`ui-sidebar-files` `FileTypeIcon` size **16**。`CODE_FILE_TYPE_SET` **48** 种 | 文件树语言种类 SF `doc.fill`。Round 68 以「SVGPath 只吃 path d」跳过 | 构建期用官方 markup 包 20×20 SVG，`cairosvg` 转 PDF 进 `Assets.xcassets`（`preserves-vector-representation` + `original`）。`FileTypeIcon` 走 `CodeFileArtworkIcon`。标识 `official.codeFile.{kind}`。未知种类走 `FileGlyph` `other`，不再 SF。CI 加 `files` 屏 |
| outline 描边 l3 | `Button.module.css` `.outline`：`0.5px solid var(--dsw-alias-border-l3)`。theme light `#0000001f`、dark `#ffffff29`。files header `border-bottom: .5px solid l3`。conversation header 同。ContextMeter `.track` `stroke: l3` width 2。Markdown `th` `border-bottom` l3、`td` l2。Input 是 **l4** | `DswColors` 只铺 l2/l4（注释仍 alpha.2）。outline / 文件树 Divider / ContextMeter / 对话 tab 底边用 `T.border`（l2） | 补 `borderL3` / `T.borderL3`。凡桌面 Button.outline、files header、conversation header、ContextMeter track、markdown `th` 改 l3。配对/重命名 **Input** 改 `T.borderStrong`（l4，`Input.module.css`）。注释改为 alpha.5。其余已铺 token 与 alpha.5 静态色值一致（别名多指向 `--dsw-static-*`，hex 未变） |
| Markdown 行内 fileChip | `ReferenceChip` / `ReferenceIconRegular` size 16 → file 用 `BrowseOutlineArtwork` | `Text(Image(systemName: "doc"))`。Round 68 以 Canvas 不能进 Text 跳过 | 同一套 BrowseOutline 导出 **template PDF** `officialBrowseOutline`，`Text(Image)` 可拼接。`Text(Image)` 附件**不会**把 catalog 名暴露成 XCUI Image，含 chip 的段落挂 `official.markdownFileChip`。CI `chat` 禁 SF `doc` 并断言该标识 |
| 权限风险 checkbox | `RiskConfirmation.module.css` `.acknowledgement input`：16×16、`margin: 3px 0 0`、`accent-color: var(--dsw-alias-button-primary-fill)`；label gap 10。primitives **无** checkbox SVG（原生 `<input type="checkbox">`） | SF `checkmark.square.fill` / `square`，色 `T.ink` | 照搬 CSS 尺寸/间距/强调色 `T.primaryButton`。勾选图形仍是平台原生 checkbox 类比（不发明勾选 artwork）。取消钮改为 outline **0.5pt l3** |
| 变更卡叠层 `doc.on.doc` | `ui-chat` 附件卡 / 文件引用用单文件 `FileTypeIcon`。primitives / ui-workspace **无**「多文件叠层」artwork | `doc.on.doc` / `doc.text` | **skip 不发明** |

### `CODE_FILE` 转换保真说明

48/48 均由官方 inner markup 包进 `viewBox 0 0 20 20` 后转 PDF，**没有手绘替代 path**。

| 元素 | 出现于 | 处理 |
| --- | --- | --- |
| `text`（Arial 字重 800/900） | css / env / ini / objective-c | cairosvg 把字形描成矢量轮廓写入 PDF，运行时不依赖 Arial |
| `clipPath` | javascript / typescript / swift / wasm | 保留；实例 id 换成 `ios-codeFile_*`，避免 PDF 内 id 碰撞 |
| `linearGradient` + `stop` | elixir / flutter / json / kotlin | 保留（含 `gradientUnits` / `gradientTransform`） |
| 嵌套 `<svg viewBox="0 0 128 128">` | clojure / cmake / csharp / dart / erlang / java / … | 保留 `x/y/width/height` 嵌套视口 |
| `fill-opacity` / `fill-rule` / `clip-rule` | elixir / json / powershell 等 | 随 markup 进 PDF |

未发现「无法忠实渲染、只能放弃」的元素。若某台渲染器对嵌套 SVG 的 `xlink` 不完整，以 Assets 里的 PDF 为准——本轮转换在 cairosvg 下全部成功。

### 查过但本轮不提取

| 项 | 查过 | 结论 |
| --- | --- | --- |
| 变更卡多文件叠层 | `ui-chat` `UserContent` 附件卡、`FileTypeIcon`；ui-workspace / ui-conversation 无 stacked-docs SVG | **skip 不发明** |
| checkbox 勾选图形 | `Checkbox.module.css` 只有 16×16 + `accent-color: brand-primary`；RiskConfirmation 用 `button-primary-fill` | 无 artwork。只搬 CSS |
| Switch / SegmentedTabs l3 | `Switch.module.css` track、`SegmentedTabs.module.css` border 用 l3 | 手机 Toggle / 无 SegmentedTabs。Toggle **有意 skip** |

### 有意 skip（桌面源码依据）

| 项 | 判定 | 依据 |
| --- | --- | --- |
| turnNavigation / toBottom FAB / ask.review / hover chevron / Account/shortcuts / CompatibilityBanner / 审批通知 / 插件列表搜索框 / stop-state | **skip** | 既定平台 / hide / 禁止发明 |
| 扫码 QR / Inspector viewfinder / 终端与 Todo ProgressView | **skip** | primitives 无 artwork |
| 管理 sheet 删除无确认 | **skip** | 桌面无对应 Modal |
| 手机终端快捷键条 | **平台** | 桌面无此条 |
| 通用设置 Toggle / 语言 Picker | **skip** | 非系统蓝 ActionSheet |

### 逐屏核对（light+dark）剩余 SF / 系统控件

| 屏 | 判定 | 剩余 SF / 系统控件 | 处理结论 |
| --- | --- | --- | --- |
| landing | **PASS** | 无计划 chip | 标题/鲸/Composer 贴底；顶栏 panelLeft+panelRight |
| chat | **本轮修** | waking 触发行 `triggerSymbol` SF（非 CODE_FILE） | fileChip 换官方 BrowseOutline；禁 `doc` |
| planMode / mention | **PASS** | — | #78 官方 plan / 提及 |
| chatDock | **PASS** | Todo `in_progress` `ProgressView` | 有意 skip |
| drawer | **PASS** | 工作区行 `ellipsis` 菜单钮 | 桌面行菜单是 overflow；primitives 无独立 ellipsis artwork。保持 |
| jobs | **PASS** | 列表 `ProgressView` | loading skip |
| trajectory / trajectoryDetail | **PASS** | 空态 `ProgressView` | KIND_ICON 官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤 | primitives 无 artwork |
| browser | **PASS** | WK 线性 `ProgressView` | 无 primitives 进度条 |
| terminal / terminalUnavailable / terminalMissing / terminalDisconnected | **PASS** | 中间 `ProgressView`；退出确认既有 | #79 三态不回归 |
| files | **本轮修** | 预览 wrap/copy/close 仍 SF（`text.justify.leading` / `square.on.square` / `xmark`） | 语言图标官方 PDF。预览工具条 primitives 无对应 artwork，保持 |
| settings | **PASS** | Toggle / 语言 `Picker` | 有意 skip |
| settingsShell | **PASS** | — | 模型 `IconDataOutlineMedium` |
| plugins / builtinPlugins | **skip / PASS** | 列表搜索框 magnifyingglass；部分 chevron.down | 桌面无该搜索槽；bundled 行 chevron 非本轮候选 |
| models | **PASS** | 自定义模型 `plus`；provider `Picker` | 添加行无独立 plus artwork 时沿用 `D.plus`；非系统蓝 |
| permission | **PASS** | 风险确认 checkbox 为平台方框（已按 CSS 上色） | 菜单官方 chevron/check |
| slash | **PASS** | loading `ProgressView` | #77 行图标 |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | schedule `Picker`/`ProgressView` | 既有官方 SVG / 全屏 Start |
| connections / pairingLink / nearby / manage | **PASS** | 扫码 `qrcode.viewfinder`；管理删除无确认 | QR skip；#76 版式；outline 改 l3、Input 改 l4 |

### npm dist-tag（只报告，不 bump 基线）

`npm view`（2026-10-19）：

| 包 | alpha | next | latest |
| --- | --- | --- | --- |
| `@deepseek-ai/dsh-client-ui-primitives` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.0.1-rc.1 |
| `@deepseek-ai/dsh-client-ui-theme` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.0.1-rc.1 |
| `@deepseek-ai/dsh-client-ui-chat` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.1.2-alpha.2 |
| `@deepseek-ai/dsh-client-ui-conversation` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.0.1-rc.1 |
| `@deepseek-ai/dsh-client-ui-sidebar-files` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.1.5-alpha.1 |

alpha.5 之后**没有新的 alpha**。rc.2 仍是 `next`，本轮不升级基线。UI 基线维持 `0.2.1-alpha.5`。

## Round 71 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；Android 仅参考）

基线 `main` `62a305d`（#80 Round 70：CODE_FILE 官方语言图标、outline l3、fileChip BrowseOutline）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 |
| --- | --- |
| landing「探索未至之境」+ whale | **PASS** |
| Composer 贴底 | **PASS** |
| landing 顶栏左 `panelLeft` 右 `panelRight`（#79） | **PASS** |
| 终端三态（#79） | **PASS** |
| 抽屉设置 vs 绿点+主机名独立热区 ≥16pt | **PASS** |
| 远程主机整页；开抽屉 / 进设置 / 进远程主机收键盘 | **PASS** |
| 权限 chip 只图标 + #68 菜单 | **PASS** |
| #69–#80 既有官方 SVG 与 CI 断言（planMode / mention / `/` 菜单 / PairLinkSheet / CODE_FILE） | **PASS**（断言未放宽、未删） |
| `/` 菜单全量不显示数量；聊天顶栏无分享；用户消息下无常驻复制 | **PASS** |

### 本轮修

| 项 | 桌面源码依据 | 处理 |
| --- | --- | --- |
| 触发行 SF `bolt.horizontal` / `clock.arrow.circlepath` / `person.crop.circle` | `ui-chat` `TurnTriggerNodeView` `TRIGGER_ICONS` size 14：request=`IconContextInjectionOutlineRegular`、goal=`IconGoalOutlineRegular`、agent=`IconPaperPlaneOutlineRegular`、team/subagent=`IconAgentPresetOutlineRegular`、github=`IconBranchOutlineRegular`、webhook=`IconGlobeOutlineRegular`、schedule=`IconClockOutlineRegular`、job=`IconQueueOutlineRegular`、plugin=`IconCordisPluginOutlineRegular`。CSS：`border .5px l1`、`radius-xl` 20、`turn-trigger-bg`（light markdown-code-block `#F9FAFB` / dark interactive-bg-hover `#14FFFFFF`）、header gap 10 / pad 12×16、chevron Regular 12 | 抽出 `IconContextInjectionOutline` path；其余复用已提取 glyph。卡面改官方 token。CI 加 `turnTrigger` 屏：断言 `official.contextInjection` +「收到执行请求」，禁 SF |
| 工作区行 SF `ellipsis` | `ui-primitives` `IconEllipsisOutlineArtwork`（会话行 overflow 已用同一套）。Round 70 误记「无独立 ellipsis artwork」 | 工作区菜单换成 `OfficialGlyph.ellipsis`。CI `drawer` 断言 `official.ellipsis`、禁 `ellipsis` |
| 插件添加 split SF `chevron.down` | `ui-plugin-manager` `AddPluginMenu` `IconChevronDownOutlineRegular`。库存分组/行披露同官方 chevron | `PluginAddMenu` + inventory 披露换成官方 chevronDown。CI `plugins` 断言 `official.chevronDown`、禁 `chevron.down` |
| 文档预览 wrap / copy / close SF | `ui-sidebar-documentpreview` wrap：`IconWrapFillRegular` / `IconNowrapFillRegular` 16；copy=`IconCopyOutlineRegular`；缺字体关闭=`IconCloseOutlineRegular` | 抽出 wrap/nowrap fill path。CI 加 `filePreview` 屏：断言 `official.wrapFill` / `copyOutline`，禁 `text.alignleft` / `square.on.square` |
| 模型添加 / 预设 refresh·plus·browse SF | 桌面 add 行 `IconPlusOutlineMedium`；预设头 `IconRefreshOutlineRegular`；查看配置 `IconBrowseOutlineRegular` | 换成已提取 official plus/refresh/browse。protocol 锁符号；CI 无独立 presets 屏，记入待办 |

### 查过但本轮不提取

| 项 | 查过 | 结论 |
| --- | --- | --- |
| 变更卡 `doc.on.doc` | `ui-chat` / `ui-workspace` 无叠层 artwork | **skip 不发明**（#80） |
| 风险 checkbox 勾选图形 | `RiskConfirmation` 原生 `<input type="checkbox">` | **skip**（#80 只搬 CSS） |
| `IconSearch` 插件库存搜索槽 | `ui-plugin-manager` 无该槽 | **skip**（手机过滤便利，保留 SF magnifyingglass） |

### 有意 skip（桌面源码依据）

| 项 | 判定 | 依据 |
| --- | --- | --- |
| turnNavigation / toBottom FAB / ask.review / hover chevron | **skip** | 桌面 `ui-conversation` 触屏无 hover 轮次条 / 回底 FAB。`ask.review` 是 hover「查看回答」 |
| Account/shortcuts / CompatibilityBanner / 审批通知 | **skip** | 桌面专属 / hide / 禁止发明 |
| 插件列表搜索框 SF magnifyingglass | **skip** | 桌面 `ui-plugin-manager` 无搜索槽 |
| stop-state InputBar | **已对齐** | #69 `official.stopRect`；`composerStop` 屏已锁。非本轮缺口 |
| 扫码 QR / Inspector viewfinder | **skip** | primitives 无 QR / viewfinder artwork |
| 终端与 Todo `ProgressView` | **skip** | primitives 无 loading artwork |
| 管理 sheet 删除无确认 | **skip** | Android 立即 `removeProfile`；桌面 pocket 无这张 sheet / 无 delete Modal |
| 手机终端快捷键条 | **平台** | 桌面无此条；#79 已换官方 keyboard/check |
| 通用设置 Toggle / 语言 Picker | **skip** | 非系统蓝 ActionSheet |

### 逐屏核对（light+dark）剩余 SF / 系统控件

| 屏 | 判定 | 剩余 SF / 系统控件 | 处理结论 |
| --- | --- | --- | --- |
| landing | **PASS** | 无计划 chip | 标题/鲸/Composer 贴底；顶栏 panelLeft+panelRight |
| chat | **PASS** | waking 触发行不在本屏 | 无分享、无用户常驻复制；fileChip 官方 BrowseOutline |
| turnTrigger | **本轮修** | — | 官方 ContextInjection + 桌面卡面 token |
| planMode / mention | **PASS** | — | #78 官方 plan / 提及 |
| chatDock | **PASS** | Todo `in_progress` `ProgressView` | 有意 skip |
| drawer | **本轮修** | — | 工作区 overflow 官方 ellipsis |
| jobs | **PASS** | 列表 `ProgressView` | loading skip |
| trajectory / trajectoryDetail | **PASS** | 空态 `ProgressView` | KIND_ICON 官方 SVG |
| inspector | **skip** | viewfinder / 类型过滤 | primitives 无 artwork |
| browser | **PASS** | WK 线性 `ProgressView` | 无 primitives 进度条 |
| terminal / 三态 | **PASS** | 中间 `ProgressView`；退出确认既有 | #79 不回归 |
| files | **PASS** | — | #80 CODE_FILE |
| filePreview | **本轮修** | 模式 Menu 系统 check | wrap/copy 官方 fill/outline |
| settings | **PASS** | Toggle / 语言 `Picker` | 有意 skip |
| settingsShell | **PASS** | — | 模型 `IconDataOutlineMedium` |
| plugins | **本轮修** | — | add split 官方 chevronDown |
| builtinPlugins | **skip / PASS** | 列表搜索框 magnifyingglass | 桌面无该槽；行 chevron 已官方 |
| models / permission | **PASS** | — | 官方 chevron/check |
| slash | **PASS** | loading `ProgressView` | #77 行图标 |
| schedule / sessionActions / viewOptions / start / composerStop | **PASS** | schedule `Picker`/`ProgressView` | 既有官方 SVG |
| connections / pairingLink / nearby / manage | **PASS** | 扫码 `qrcode.viewfinder`；管理删除无确认 | QR skip；#76 版式 |

### npm dist-tag（只报告，不 bump 基线）

`npm view`（2026-10-19）：

| 包 | alpha | next | latest |
| --- | --- | --- | --- |
| `@deepseek-ai/dsh-client-ui-primitives` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.0.1-rc.1 |
| `@deepseek-ai/dsh-client-ui-theme` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.0.1-rc.1 |
| `@deepseek-ai/dsh-client-ui-chat` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.1.2-alpha.2 |
| `@deepseek-ai/dsh-client-ui-conversation` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.0.1-rc.1 |
| `@deepseek-ai/dsh-client-ui-sidebar-files` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.1.5-alpha.1 |
| `@deepseek-ai/dsh-client-ui-plugin-manager` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.1.6-alpha.2 |
| `@deepseek-ai/dsh-client-ui-sidebar-documentpreview` | **0.2.1-alpha.5** | 0.2.1-rc.2 | 0.1.5-alpha.2 |

alpha.5 之后**没有新的 alpha**。rc.2 仍是 `next`，本轮不升级基线。UI 基线维持 `0.2.1-alpha.5`。

## Round 72 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；#83 合入后）

基线 `main` `68b155b`（#83 `@` mention 面板与原子 chip）。桌面是源。禁止自创颜色/图标/间距；无系统蓝；无 ActionSheet；文案「远程主机」。

直播核对（2026-10-19）：#83 squash `68b155b`。PR CI run `39203012376`：`protocol` / `ios` / `screenshots` 全绿。`npm pack` `@deepseek-ai/dsh-client-ui-input-trigger@0.2.1-alpha.5` `lib/client.js:1628`：

```
._3e4SsG_menu{…--dsw-elevation-stroke-color:var(--dsw-alias-border-l1);…box-shadow:var(--dsw-elevation-prominent);border:0;…}
._3e4SsG_crumbs{border-bottom:.5px solid var(--dsw-alias-border-l1);…}
```

`/` 与 `@` 共用同一 `MenuView`。

### 必须核实（已对齐，本轮不改）

| 项 | 判定 | 证据 |
| --- | --- | --- |
| landing `@` + 远程 `references.files` / `references.sessions` | **PASS** | `RootView.landingMentionMenuLayer`；`AppModel.prepareMentionSession` + `referenceFiles` / `referenceSessions`。CI `landingMention` |
| 面板分组 / 官方图标 / 原子 chip | **PASS** | `*-mention.png` / `mentionFiltered` / `mentionChip` / `mentionSent`：files→sessions，`official.browseOutline` / `folderClose` / `queueOutline`，气泡无生 markdown |
| landing 鲸 +「探索未至之境」仍在树里 | **PASS** | CI 断言 `official.fishLogo` + `landingHeadline`。窄屏 400pt 菜单盖住英雄区，不缩桌面 `max-height` |
| #82 Start「会话数据诊断」 | **PASS** | `*-startLanding.png` 第四卡 |

### 本轮修

| 项 | 桌面源码 | iOS 原状 | 处理 |
| --- | --- | --- | --- |
| MenuView 描边 | `--dsw-elevation-stroke-color: var(--dsw-alias-border-l1)`；`border: 0`；0.5px 在 elevation shadow | mention `T.settingsCardStroke`（l4 `#29000000`）；slash `T.border`（l2） | `@` / `/` 卡描边改 `T.borderL1`。protocol `inputTriggerMenuStrokeHex` 锁 `0x0A000000` / `0x0FFFFFFF` |
| mention crumbs 底边 | `border-bottom: .5px solid var(--dsw-alias-border-l1)` | `T.border`（l2） | 改 `T.borderL1`；`mentionMenuCrumbStrokeHex` 与描边同值 |

### 有意 skip（桌面源码依据）

| 项 | 判定 | 依据 |
| --- | --- | --- |
| turnNavigation / toBottom FAB / ask.review / hover chevron | **skip** | 桌面 hover / 触屏无对应窄屏切片 |
| Account / shortcuts / CompatibilityBanner / 审批通知 | **skip** | 桌面专属 / hide |
| 插件搜索 SF magnifyingglass | **skip** | `ui-plugin-manager` 无搜索槽 |
| Inspector viewfinder / QR `qrcode.viewfinder` | **skip** | primitives 无 artwork |
| ProgressView loading / 变更卡 `doc.on.doc` / 风险原生 checkbox | **skip** | 无 stacked-docs / checkbox / loading artwork |
| FilePreview / PluginInventory 系统 Menu check | **skip** | 系统 Menu |
| Settings Toggle / 语言 Picker / confirmationDialog | **skip** | 非系统蓝 ActionSheet；桌面无对应手机 Modal |
| 管理 sheet 删除无确认 / 手机终端快捷键条 | **skip** | 平台 / Android 立即 `removeProfile` |

## Round 73 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；#87 合入后）

基线 `main` `10f4240`（#87 用户气泡 hug）。桌面是源。禁止自创颜色/图标/间距；无系统蓝 ActionSheet；不改 composer IME；不恢复「连接诊断」。

CI `10f4240` artifact `ios-simulator-screenshots` 逐屏对照 `ui-input-trigger` `MenuView.module.css` `.menu { max-height:400px }`：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| 用户气泡 hug / 贴右 / 文字 start | **PASS** | #87 `*-chat.png` / `chatLong` / `mentionSent` |
| `@` / `/` MenuView 描边 l1 | **PASS** | #84 |
| `/` 菜单 hug 内容、上限 400 | **本轮修** | `*-slash.png` 被 `minHeight: availableHeight` 拉满 transcript；桌面 card 不 stretch |
| `@` 菜单 hug 内容、上限 400 | **本轮修** | `*-mention.png` / `landingMention` / `mentionFiltered` 空卡撑到 400pt cap |
| Settings Toggle / 系统 Menu check / confirmationDialog | **skip** | Round 72 |
| 变更卡单文件 `doc.text` | **GAP leftover → Round 74** | 桌面 `FileTypeIcon`；#90 不修 |
| Inspector SF viewfinder | **skip** | 无 artwork |

## Round 74 对照清单（桌面 `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5`；#90 合入后）

基线 `main` `f9f8457`（#90 MenuView hug 400）。桌面是源。禁止自创颜色/图标/间距；无系统蓝 ActionSheet；不改 composer IME；不恢复「连接诊断」。Composer 统计行居中、权限 chip 只图标、用户气泡 hug、`@` 面板照桌面。

CI `11c995e` / `f9f8457` artifact `ios-simulator-screenshots` 逐屏对照：

| 项 | 判定 | 证据 |
| --- | --- | --- |
| `/` `@` MenuView hug / ≤400 | **PASS** | #90 `*-slash.png` / `mention` / `mentionFiltered` / `landingMention` |
| 用户气泡 hug / 贴右 | **PASS** | #87 `*-chat.png` / `chatLong` / `mentionSent` |
| 变更卡单文件 `FileTypeIcon` | **本轮修** | `ChangesSummaryCard` 单文件仍 SF `doc.text`；桌面 `UserContent` `.fileCard` `.fileIcon` 是 `FileTypeIcon` 28×28。CI 加 `changesCard` 屏：断言 `official.fileMarkdown`，禁 `doc.text` |
| 变更卡多文件 `doc.on.doc` | **skip** | primitives / ui-workspace 无 stacked-docs artwork，不发明 |
| Inspector viewfinder / 插件库存 magnifyingglass | **skip** | 无 artwork / 桌面无该搜索槽 |
| Settings Toggle / 系统 Menu check | **skip** | Round 72 |

## #94 leftover — title-to-tab 15pt

#94 squash `3765a44`：#92 文件回到 `2a39d41`，设置卡裁切保留。header 间距当时没改——`4caed96` 只加 `minHeight` 30 就会让 models `typeText("保留草稿")` AX 超时。

根因（`4caed96` `*-models.png`）：model picker 叠在 composer 上（占位字从菜单后露出）。`modelChip` / `modelReleaseBadge` 在菜单开着时就在树上，等它们存在并不等于 popover 已关。title row 加高 8pt 把 chip（以及锚在它上面的菜单）往下推，盖住输入框，tap/`typeText` 跟拆除抢 AX（`{{inf, inf},{0,0}}` / Timed out while evaluating UI query）。

修：Flash 点完先等系统 `PopoverDismissRegion` 离开（8s，和其他 wait 同一预算；不是 skip/retry/放宽）。不要给 picker VStack 加 identifier——SwiftUI 会把它复制到「模型 / 推理等级」行上，子级 `modelPickerModel` 就丢了。再断言 composer 有限可点，然后 `typeText`。

header 只要变高（`minHeight` 30 或 `padding.bottom` 15 且 top 仍 10）composer 列就变矮：`input.typeText` 在键盘起来后重查 `composerInput` 会 AX 超时；`9b899f3` 连 IME mentionChip 的 `composerIme.setMarked` 也挂。桌面 15pt 用**等高**分配：`padding.top` 5 + `padding.bottom` 15（总垂直 20pt 与 `2a39d41` 相同）。Flash 后等 `PopoverDismissRegion` 离开，点中后再 `app.typeText`（不重查输入框）。草稿断言仍是 `contains("保留草稿")`。`conversationHeaderTitle` + `chatTab.chat` 断言 15±3。不加 wrapper / maxWidth / probe / `ignoresSafeArea` / 动画开关 / `sizeThatFits`。

