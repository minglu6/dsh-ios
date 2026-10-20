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
| 连接 | 配对链接／扫码／host:port + 6 位码、局域网 Bonjour `_dshpocket._tcp`（TXT `protocol=1` + 64 位 hex `instanceId`）、未配对附近过滤、已配对设备 TCP 探测（10s、最多 2 路）、1s→30s 退避且仅 Offline/Connecting 恢复、短后台任务（不是 Android 前台服务）、完成／审批本地通知 |
| 会话 | 按工作区分组、置顶／Fork／归档／取消归档（归档行不可打开）、远程主机搜索＋本地标题／路径合并、公布 `insertBefore`／`insertSessionBefore` 时拖拽排序、完成未查看绿点、相对时间。无会话路径、无聊天「回到底部」按钮 |
| 聊天 | 流式正文与思考、Markdown／代码块／表格、官方思考区、工具行回执、进程组折叠、本地回显、排队编辑／插话、审批官方卡、用户提问卡、`/` 指令、附件上传、会话图片气泡（`session.attachment`）、`@` 官方 mention token 与 chip、模型＋思考强度、权限模式文案芯片、任务清单、目标、本轮用量与会话统计、重试／回合失败、工作区改动卡片（编码视图开启时）。导出与会话反馈走 `/` 与 `+`。消息动作：复制／赞／踩（远程主机有 `feedback.set` 时）；分支在会话 ⋯（`sessions.fork`）。打开抽屉、滚动消息列表或点 Composer 外空白会收起键盘 |
| 轨迹 | 对话／轨迹页签：紧凑账本（7 种格子）、工具栏时长／轮次／调用＋搜索、泳道、格子检视 概述／参数／结果／Schema／计时、请求检视 概述／选项／用量／计时（官方 `ui-trajectory` 文案）。编码视图关闭时隐藏。差距矩阵：[docs/parity-gap.md](docs/parity-gap.md) |
| 配置 | 通用设置（外观三块、字号 px、折叠时机、性能、权限、会话日志、链接打开位置）。外观与字体只保存在本机，不写入远程主机。模型页：提供商编辑＋密钥（`models.providers*`／`credentials.*`）。Agent 预设（`presets.list`／`presets.read`／`presets.settings`）＋官方引导＋创造模式入口。无自造「凭证」页 |
| 远程主机工具 | 抽屉在公布 `plugins.list` 时打开插件管理（官方市场列表＋开关、安装／检视／来源库；settingsDescribe 在插件详情「配置组件」），在公布 `schedule.catalog` 时打开自动化任务（仅抽屉，设置里没有「自动化」行）。会话「开始」面板对齐桌面文案：工作区文件＋新建终端（不展示桌面快捷键）。桌面开始与 ⋯ 都没有浏览器／会话诊断入口，故不暴露。PTY 终端与工作区文件树在公布对应 op 时出现。文件预览语言表与隔离高亮对齐 Android，并在对应类型上支持 PDF / Office / XLS。会话顶栏在公布 `jobs.list` 时显示实时任务 chip／面板。差距矩阵：[docs/parity-gap.md](docs/parity-gap.md) |

远程主机配置来自 `plugins.settingsDescribe` 与 `settings.changed`。正常态不放手动同步。

终端使用原生按键事件直接发送输入，回车发送 `\r`、退格发送 DEL，多行粘贴仍需确认。快照按远程 PTY 的行列数还原，尺寸变化按输出流顺序应用；主屏缩放会重排软折行并保留光标，视口上下各保留最多 1000 行用于尺寸恢复（不是滚动历史浏览器）。全屏应用仍按终端惯例自行重绘。「开始」页的新建终端卡片不显示桌面快捷键或装饰性倒三角，终端页的会话切换菜单保留。

终端页面直接使用连接模型的加载状态，快速失败后会退出“连接中”并提供重试，不再依赖页面内的状态镜像。离开终端页会取消尚未完成的挂接并释放订阅，不关闭远程 shell。

会话页在对话／轨迹页签下显示当前工作区与工作模式：读取当前会话的归属、目录和 Agent 预设，不借用新任务草稿；元数据缺失时明确提示未提供。新任务页仍可选择工作区和工作模式，首条消息提交中锁定选择，预设目录尚未加载时不再隐藏模式位置。

工作模式菜单在确定宽度下按实际内容测高，高度上限为 400pt；空间不足时纵向滚动，模式名称及描述不再从弹层上下边缘被裁掉。

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
- 插件通过 mDNS 广播 `_dshpocket._tcp`。手机可从「附近设备」列出尚未配对的主机。
- 局域网路径为 `ws://`／HTTP，桥接本身不提供 TLS。配对用于设备鉴权，不等于传输加密。跨网络应使用 Tailscale 或已有可信加密链路。不要将 7690 端口直接暴露到公网。

## 下载与安装

运行前提：

- 手机：iOS 16 或更新版本。
- 电脑：已安装 dsh，且远程主机保持运行。Android／插件 CI 当前固定 `@deepseek-ai/dsh@0.2.1-alpha.2`。
- 网络：手机与电脑处于可互访的局域网，或同一可互访的 Tailscale 网络。防火墙需允许桥接端口（默认 TCP `7690`）。

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
2. 手机打开会话侧栏底部的主机信息，进入手机连接，选择 **扫码**、**输入地址**；同一局域网也可从 **附近设备** 发现主机。
3. 扫描二维码或输入 `dshpocket://pair?h=<host:port>&c=<6位码>`。名称可留空，默认使用主机地址。
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

## 已知限制

- 不支持在手机本地运行 dsh。电脑休眠、远程主机退出或网络不可达时无法继续远程操作。
- iOS 没有 Android 前台服务那种常驻「已连接」通知。`ConnectionKeeper` 用 `beginBackgroundTask` 加 ping，再用 `BGAppRefreshTask`；系统回收后 WebSocket 不保证还在。
- 附近发现走本地网络＋Bonjour，不是 Android 的 `NEARBY_WIFI_DEVICES`。
- 上游仍为 alpha。升级时应同时关注 App、dsh-android 中的桥接和 dsh 版本。

## 致谢

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)：远程主机能力、交互与视觉参考。
- [dsh-android](https://github.com/minglu6/dsh-android)：pocket 插件、协议与移动对齐基线。
