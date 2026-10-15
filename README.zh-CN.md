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
| 连接 | 配对链接／扫码／host:port + 6 位码、局域网 Bonjour `_dshpocket._tcp`、多主机、断线退避重连、**复制诊断报告** |
| 会话 | 按工作区分组、置顶／Fork／归档、完成未查看绿点、相对时间。无会话路径、无上移下移、无聊天「回到底部」按钮 |
| 聊天 | 流式正文与思考、工具行、本地回显、排队／插话发送、审批、`@` 文件与会话引用、模型选择、历史上翻。消息动作：复制／赞／踩（远程主机有 `feedback.set` 时）／分支（已完成轮次最后一条上的 `sessions.fork`） |
| 轨迹 | 对话／轨迹页签：紧凑账本（7 种格子）、工具栏时长／轮次／调用＋搜索、泳道、检视 概述／参数／结果／Schema／计时（官方 `ui-trajectory` 文案）。请求检视尚未做。差距矩阵：[docs/parity-gap.md](docs/parity-gap.md) |
| 配置 | 远程主机镜像的通用设置（外观／语言）与模型目录。无自造「凭证」页。诊断只在「手机连接」 |
| 远程主机工具 | 仅当远程主机公布对应 op 时，抽屉／设置才显示插件与自动化任务。会话「开始」面板在公布对应 op 时提供 PTY 终端与工作区文件树。实时任务留给后续批次。差距矩阵：[docs/parity-gap.md](docs/parity-gap.md) |

远程主机配置来自 `plugins.settingsDescribe` 与 `settings.changed`。正常态不放手动同步。

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
- 请求检视与实时任务订阅尚未进入本 IPA。轨迹账本＋格子检视、聊天消息动作、远程主机 PTY 终端与工作区文件树已有。
- 上游仍为 alpha。升级时应同时关注 App、dsh-android 中的桥接和 dsh 版本。

## 致谢

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)：远程主机能力、交互与视觉参考。
- [dsh-android](https://github.com/minglu6/dsh-android)：pocket 插件、协议与移动对齐基线。
