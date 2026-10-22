# dsh-ios

[English](README.md) | **简体中文**

[DeepSeek Harness（dsh）](https://github.com/deepseek-ai/deepseek-harness) 的非官方原生 iOS 遥控客户端。手机仅作控制端：模型调用、工具执行、文件、终端与自动化任务仍在电脑远程主机上运行。本仓库不由 DeepSeek 官方开发或维护。

应用使用 SwiftUI（iOS 16+）实现。它不是把桌面网页套进 WebView，也不在手机上运行本地 Agent 或 Termux sidecar。

协议与 [dsh-android](https://github.com/minglu6/dsh-android) 相同：手机只连接该仓库里的桌面 **pocket 插件**（`dsh-plugin-pocket`）。本仓库不另起一套桥接。

[下载 IPA](https://github.com/minglu6/dsh-ios/releases/download/dsh-ios-latest/dsh-ios.ipa)

## 功能特性

可用能力取决于远程主机版本与已启用的插件。手机是桌面的控制器，只为窄屏／竖排／触摸调整布局，不增减功能或改语义。

| 领域 | 本版本 |
| --- | --- |
| 连接 | 配对链接／扫码／host:port + 6 位码、已配对设备 TCP 探测（10s、最多 2 路）、1s→30s 退避且仅 Offline/Connecting 恢复、短后台任务（不是 Android 前台服务）、完成／审批本地通知 |
| 会话 | 按工作区分组、置顶／Fork／归档／取消归档（归档行不可打开）、远程主机搜索＋本地标题／路径合并、公布 `insertBefore`／`insertSessionBefore` 时拖拽排序、完成未查看绿点、相对时间。无会话路径、无聊天「回到底部」按钮 |
| 聊天 | 流式正文与思考、Markdown／代码块／表格、官方思考区、工具行回执、进程组折叠、本地回显、排队编辑／插话、审批官方卡、用户提问卡、`/` 指令、附件上传、会话图片气泡（`session.attachment`）、`@` 官方 mention token 与 chip、模型＋思考强度、权限模式文案芯片、任务清单、目标、本轮用量与会话统计、重试／回合失败、工作区改动卡片（编码视图开启时）。导出与会话反馈走 `/` 与 `+`。消息动作：复制／赞／踩（远程主机有 `feedback.set` 时）；分支在会话 ⋯（`sessions.fork`）。打开抽屉、滚动消息列表或点 Composer 外空白会收起键盘 |
| 轨迹 | 对话／轨迹页签：紧凑账本（7 种格子）、工具栏时长／轮次／调用＋搜索、泳道、格子检视 概述／参数／结果／Schema／计时、请求检视 概述／选项／用量／计时（官方 `ui-trajectory` 文案）。编码视图关闭时隐藏。差距矩阵：[docs/parity-gap.md](docs/parity-gap.md) |
| 配置 | 通用设置（外观三块、字号 px、折叠时机、性能、权限、会话日志、链接打开位置）。外观与字体只保存在本机，不写入远程主机。模型页：提供商编辑＋密钥（`models.providers*`／`credentials.*`）。Agent 预设（`presets.list`／`presets.read`／`presets.settings`）＋官方引导＋创造模式入口。无自造「凭证」页 |
| 远程主机工具 | 抽屉在公布 `plugins.list` 时打开插件管理（内置插件配置／实验性插件与「更多」／已安装插件），在公布 `schedule.catalog` 时打开自动化任务（仅抽屉，设置里没有「自动化」行）。插件详情展示组件状态、可寻址开关、配置及来源／版本；添加插件使用桌面式居中弹窗，包含示例、安装源选择，检查合并进「安装」。会话「开始」面板对齐桌面文案：工作区文件＋新建终端（不展示桌面快捷键）。桌面开始与 ⋯ 都没有浏览器／会话诊断入口，故不暴露。PTY 终端与工作区文件树在公布对应 op 时出现。文件预览语言表与隔离高亮对齐 Android，并在对应类型上支持 PDF / Office / XLS。会话顶栏在公布 `jobs.list` 时显示实时任务 chip／面板。差距矩阵：[docs/parity-gap.md](docs/parity-gap.md) |

远程主机配置来自 `plugins.settingsDescribe` 与 `settings.changed`。正常态不放手动同步。

插件管理和模型设置仅保留原生页面，排版按桌面插件管理对齐，包括紧凑操作栏、分组插件行与居中安装弹窗。已移除自定义插件 Web 界面入口及其票据／Cookie 生命周期，不在手机中渲染第三方 Web 控件。

模型页对齐桌面端的行内编辑：保留提供商行上的编辑／删除入口，编辑卡默认只展开密钥，地址、名称、协议和模型目录收在「自定义设置」中，底部为取消／保存。保存后收起编辑卡，重新读取 Host 并按最新名称提示已保存；失败保留草稿，切换新增模式分别保留目录提供商和自定义 API 的草稿。模型目录支持增删、名称、K/M 容量、输入类型、Host schema 提供的推理档位，以及「获取可用模型」后显式选择添加；不覆盖已有模型的自定义字段。`ModelsSettingsUITests` 通过真实 `PocketClient` 与 DEBUG 内存 Host 覆盖保存回读、失败重试、取消、草稿隔离、模型编辑和候选采用，纳入 `settings-trajectory` 与完整 UI 测试范围。

任务栏遵循桌面生命周期：`todo/write` 更新整份清单，本轮全部完成和 `turn/end` 后仍保留；下一轮 `turn/start`，或远程主机通过 snapshot／resume／projection 明确发送 `todos: null`、`todos: []` 时移除整个任务栏。缺失投影键不等于清空，过期状态不会复活任务；清空不删除历史 `todo_write` 的参数和结果。`TodoLifecycleUITests` 通过 DEBUG fixture 将真实 follow 帧送入生产 reducer→AppModel 发布链路，覆盖完成保留、各类清空及历史轨迹可读性，不直接改写任务栏状态。

终端使用原生按键事件直接发送输入，回车发送 `\r`、退格发送 DEL，多行粘贴仍需确认。快照按远程 PTY 的行列数还原，尺寸变化按输出流顺序应用；主屏缩放会重排软折行并保留光标，视口上下各保留最多 1000 行用于尺寸恢复（不是滚动历史浏览器）。全屏应用仍按终端惯例自行重绘。「开始」页的新建终端卡片不显示桌面快捷键或装饰性倒三角，终端页的会话切换菜单保留。

终端页面直接使用连接模型的加载状态，快速失败后会退出“连接中”并提供重试，不再依赖页面内的状态镜像。离开终端页会取消尚未完成的挂接并释放订阅，不关闭远程 shell。

会话顶栏保持单行、高度 56pt：标题右侧为智能体团队、只读模式图标与子智能体目录，“对话／轨迹”页签另列于下方。模式参照 Android 的手机适配，在会话加载完成、非空且记录了模式时保留 14pt 图标和完整无障碍名称，不是按钮；官方桌面端显示图标加文字，但标题行容器不超过 540px 时隐藏整个模式标签。团队图标 14pt、点击区域 28pt、组内间距 8pt；抽屉和开始面板按钮各有独立的 48pt 点击区域，开始面板图标 15pt。子智能体保留 12pt 完整计数文案。已有会话与桌面一致，不在输入框上方另加工作空间／模式行；顶栏模式仅来自当前会话投影。可选择的工作区与模式菜单只用于新任务，组内间距 2pt、左／右内边距 20／16pt，与输入框间距 8pt；模式选项未就绪时不显示占位选择器。团队成员与共享任务读取 `agentTeam`，子智能体数量读取独立的 `subagentCatalog`，普通 fork 不计入子智能体。支持团队任务、成员切换、子级展开和返回主会话；一次性子智能体只读。完整增量更新与 catalog-only 子会话导航需要更新 `dsh-android/plugin`（`sessions.projections`、父子地址路由及投影透传），仅升级 IPA 不会更新运行中的桌面插件。

输入框下方统计遵循「设置 → 通用设置 → 性能与用量」：简洁模式的速度／缓存为普通读数，不使用禁用按钮；详细模式可打开有实际数据的会话耗时和 Token 用量详情。上下文占用在两种模式下均可打开明细。共享 Host 设置变化会即时更新统计栏，手机不会擅自修改该偏好。`ComposerStatsUITests` 覆盖模式切换、缺数据与弹层交互，已纳入 session-header、conversation 和完整 UI 测试范围。

统计详情采用向上锚定的非模态浮层：弹层打开时，一次点击旁边的指标即可切换，点击外部关闭。上下文数值与通用设置返回按钮保留独立的无障碍访问。

智能体团队使用顶部按钮锚定弹框，点击外部关闭，不使用独立页面，也不添加桌面没有的“关闭”“刷新”按钮。“当前会话”采用桌面同款浅蓝底胶囊标签；单成员时省略人数，空任务区只显示说明。

新建会话页顶栏不展示品牌字标，与 Android／桌面端一致；中央欢迎区与抽屉内的品牌标识保留。

抽屉顶部与工作区行的“新建会话”先打开新任务页，显示可选择的工作区和工作模式，不立即创建空白远程会话。工作区行预选对应工作区，顶部入口保留上次草稿选择；发送首条消息时沿用现有创建流程。切换会解除旧会话订阅并清除旧输入与附件，不停止远程任务；首条消息发送期间禁用新建入口。

会话标题支持点击查看锚定于标题的完整文本弹层；祖先面包屑保持导航行为。文字在气泡安全区内留白，避开箭头，按单词换行；短标题按内容收窄，超长标题纵向滚动。历史名称仅对当前选中的非空会话在溢出时以 30pt/s 持续循环滚动，首尾各停留 0.75 秒后重新开始；失选立即切回从开头显示、尾部省略的普通文本，不暂停在中途或保留末尾。开启“减少动态效果”时当前行静态展示、不循环，失选仍恢复普通文本。会话行尺寸、打开会话与菜单动作保持不变。

标题弹层在全文下显示最近更新时间（如“更新于2分钟前”）与当前状态；等待审批、计划待审、等待回答优先于运行中／空闲。状态随实时会话更新，时间每 30 秒刷新，不必关闭重开弹层；空白会话或缺少有效时间时隐藏时间，尚无状态来源时不伪造“空闲”。

会话正文增加右侧轮次刻度和桌面同款下箭头“回到底部”控件。刻度保留 Host 的真实轮次标识（包括不连续编号），有 `turnOutline` 投影时可加载未读历史后跳转；旧 Host 只显示已知已加载轮次。手机长按预览对应轮次，手动阅读或轮次跳转停止尾部跟随，回到底部后恢复。手机窄屏显示刻度是明确的触摸适配，官方桌面端在窄容器会隐藏它。CI 的 `ui_scope=conversation` 覆盖完整标题、导航及轨迹交互。

工作模式菜单使用桌面同款锚定浮层，最大宽度 360pt，按实际内容测高并限制在视口内，四周保留 12pt；空间不足时纵向滚动，模式名称及描述保持完整。

工作区目录选择器沿用桌面的居中弹窗，不使用系统 sheet；新建会话页与抽屉共用同一入口。弹窗最大 680×500pt、四周至少留白 24pt；“新建文件夹／取消”为中性色描边按钮，“打开／创建”为主色实心按钮。窄屏底栏自动换行、目录分栏可横向滚动并在进入目录时露出子列。新建文件夹使用居中子弹窗，点击遮罩仅关闭最上层；创建／打开期间禁止重复操作。

iOS 保留原有字号体系，默认正文／代码／终端字号为 14／11／13；不再整体放大。设置首页菜单与通用设置正文统一使用系统正文大小（默认 17pt），标题使用同款系统标题大小，行高可随辅助功能字号扩展。手动保存的个人字号保留，不向远程主机写入这些偏好。

编辑文件卡片与差异预览沿用 Android 的真实 Host 比较：多文件切换、双列行号、自动换行及 5000 行展示上限。获取失败保留错误与重试，不再静默丢掉卡片；普通预览及比较缓存按 Host／会话／文件身份隔离。缺少 `workspace/changes` 事件、桥接能力或 Host 已清理比较时，不从工具摘要伪造差异。

Python 等源代码预览保留 Android 的离线高亮资源与 CSP 隔离。原生端等待 renderer 的明确 ready 消息，确认 DOM 收到完整源码后才记录已发送；不把 WebView 的 `didFinish` 当作模块就绪。资源或脚本初始化失败会显示错误并允许重载，不再静默显示空白。

长会话轨迹按会话更新版本缓存完整派生结果，请求边界一次建索引，列表按行懒加载；选择、折叠和详情导航不重复构建全文。搜索仍覆盖完整内容，同数量流式内容替换、加载较早历史和会话切换都会使缓存失效。CI 可用 `run_ui_tests=true`、`ui_scope=settings-trajectory` 单独验收设置页面和多 MB 长轨迹交互，不替代全量 UI 回归。

轨迹记录／请求详情以官方桌面端为唯一样式与交互基准，Android 仅作移动适配参考：详情在轨迹列表内部右侧展开，窄屏宽度为 `min(92%, 420pt)`，宽屏采用可调宽度分栏，不再弹出系统半屏页面。42pt 标题栏与 34pt 标签栏固定，内容独立滚动；关闭恢复原列表，再次打开保留最近兼容的记录页签。概览字段、带语法颜色的 JSON、原始文本与 Markdown 预览采用桌面字号和平面背景。`TrajectoryUITests` 覆盖浅深主题下的详情导航、页签记忆、预览／原文切换及关闭；本机 macOS 原生视图烟测不代替 iOS 模拟器或真机验收。

历史分页不再显示“加载更早”按钮：对话、轨迹和会话记录检查器均在顶部下拉加载前一页，刷新指示器等待实际请求结束；加载保留原记录并恢复阅读锚点，失败后可再次下拉重试，末页不再请求。左侧会话列表在滚动到各分组末尾时自动分批显示其余会话，不再点击“展开其余”；工作区折叠、更多操作及搜索上限提示保持不变。CI 的 `ui_scope=pagination` 验证三类历史手势与列表自动续显。

对话下拉刷新由直接挂载的原生子视图管理，不占用 SwiftUI 会反复更新的 `refreshControl` 属性；正文测量变化时保持控件挂载，实际分页请求结束后才停止指示器。CI 的 `ui_scope=reading` 单独验证原生分页与首页截图，`ui_scope=conversation` 同时覆盖标题、轮次导航、轨迹及对话分页回归。

## 架构

```
iOS 应用（dev.dsh.pocket.ios）         桌面
┌──────────────────────────┐          ┌─────────────────────────────────────┐
│ SwiftUI 客户端           │  JSON    │ dsh 远程主机                        │
│ 仅负责展示与控制         │  over WS │  └─ dsh-plugin-pocket               │
│                          │◄────────►│      进程内调用远程主机服务         │
│ protocol/（DSHProtocol） │ host:port│      带鉴权的 JSON 协议             │
└──────────────────────────┘          └─────────────────────────────────────┘
```

手机通过 `ws://host:port`（局域网或 Tailscale）连接 `dsh-plugin-pocket`。没有独立的 iroh 手机链路，IPA 内不含 Termux／node 运行时。

- 插件默认监听 `0.0.0.0:7690`。配对只公布 IPv4。
- 同时存在局域网 IPv4 与 Tailscale 地址（`100.64.0.0/10` 或 `*.ts.net`）时，电脑 **设置 → 手机连接** 可切换 **局域网 / Tailscale**。公布地址、二维码与复制链接随之变化。
- iOS 通过扫码、配对链接或手动输入地址连接，不再通过 Bonjour 发现附近设备。主机地址变化后，需修改已保存的地址或重新扫码。
- 局域网路径为 `ws://`／HTTP，桥接本身不提供 TLS。配对用于设备鉴权，不等于传输加密。跨网络应使用 Tailscale 或已有可信加密链路。不要将 7690 端口直接暴露到公网。

## 下载与安装

运行前提：

- 手机：iOS 16 或更新版本。
- 电脑：已安装 dsh，且远程主机保持运行。Android／插件 CI 当前固定 `@deepseek-ai/dsh@0.2.1-alpha.2`。
- 网络：手机与电脑处于可互访的局域网，或同一可互访的 Tailscale 网络。防火墙需允许桥接端口（默认 TCP `7690`）。

1.0.0 正式版：[发布说明](https://github.com/minglu6/dsh-ios/releases/tag/v1.0.0) · [未签名 IPA](https://github.com/minglu6/dsh-ios/releases/download/v1.0.0/dsh-ios-v1.0.0.ipa)。

最新未签名 IPA：

https://github.com/minglu6/dsh-ios/releases/download/dsh-ios-latest/dsh-ios.ipa

CI 滚动更新预发布标签 `dsh-ios-latest`。产物**未签名**。请用「轻松签」或其他侧载签名工具签名后再安装。未签名 IPA 不能通过 App Store／开发者身份直接安装。

## 桌面插件安装与配对

桥接从 [dsh-android](https://github.com/minglu6/dsh-android) 安装，不要在本仓库另起协议。

```bash
git clone https://github.com/minglu6/dsh-android.git
cd dsh-android/plugin
npm install
npm run build:client
dsh plugin --profile desktop add "$PWD"
```

重启桌面远程主机。管理入口在电脑 **设置 → 手机连接**。

### 配对手机

1. 电脑打开 **设置 → 手机连接**，选择局域网或 Tailscale，并打开配对窗口。
2. 手机打开会话侧栏底部的主机信息，选择 **扫码** 或 **输入地址**。
3. **输入地址** 内可切换 **粘贴链接** 和 **手动输入**：前者使用独立的 `dshpocket://pair?h=<host:port>&c=<6位码>` 链接输入框，后者填写 IP、端口和 6 位配对码，两种输入互不混用。确认后点击 **开始配对**，粘贴不会自动连接。名称可留空，默认使用主机地址。
4. 连接成功后，选择工作区或会话即可使用。模型提供商和凭据由远程主机管理。

配对码有效期 10 分钟，最多尝试 3 次，成功后立即失效。旧的 iroh 形式（`n=` / `nodeId#code`）会被拒绝。

不要把 owner token 交给手机。已配对设备能够控制当前远程主机的会话、终端和配置。设备 token 存在 iOS Keychain。

## 从源码构建

需要 macOS 上的 Xcode 16（iOS 16 SDK）。

```bash
swift test --package-path protocol
xcodebuild \
  -project app/dsh.xcodeproj \
  -scheme dsh \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

未签名 IPA（与 CI 相同）：

```bash
APP=derived/Build/Products/Release-iphoneos/dsh.app
mkdir Payload && cp -R "$APP" Payload/dsh.app
zip -qr dsh-ios.ipa Payload
```

| 路径 | 职责 |
| --- | --- |
| `protocol/` | Swift 包：WebSocket 客户端、协议模型、会话折叠、配对 URI、重连／翻页策略 |
| `app/dsh/` | SwiftUI 应用（Bundle ID `dev.dsh.pocket.ios`，显示名 `dsh`） |
| `contract/` | 与 dsh-android 共享的配对 URI 用例 |
| `.github/workflows/ci.yml` | 协议测试 + 未签名 IPA + 滚动发布 `dsh-ios-latest` |

## CI

推送到 `main` 时会强制更新 `dsh-ios-latest` 预发布（`dsh-ios.ipa`）。PR 运行相同检查，但不发布该标签。

默认只运行协议测试和未签名 IPA 构建。模拟器截图及键盘／输入法 UI 测试改为按需执行：在 **Actions → ci → Run workflow** 中勾选 `run_ui_tests`。手动运行会上传产物，但不更新滚动发布。

同一事件、同一分支或 PR 的新运行会取消旧运行。IPA 本身已经 ZIP 压缩，上传产物时关闭重复压缩。

## 已知限制

- 不支持在手机本地运行 dsh。电脑休眠、远程主机退出或网络不可达时无法继续远程操作。
- iOS 没有 Android 前台服务那种常驻「已连接」通知。`ConnectionKeeper` 用 `beginBackgroundTask` 加 ping，再用 `BGAppRefreshTask`；系统回收后 WebSocket 不保证还在。
- 本地网络权限仍用于连接局域网主机及对已配对设备进行 TCP 探测，不再用于发现附近设备。
- 上游仍为 alpha。升级时应同时关注 App、dsh-android 中的桥接和 dsh 版本。

## 致谢

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)：远程主机能力、交互与视觉参考。
- [dsh-android](https://github.com/minglu6/dsh-android)：pocket 插件、协议与移动对齐基线。
