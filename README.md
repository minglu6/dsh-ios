# dsh-ios

**English** | [简体中文](README.zh-CN.md)

Unofficial native iOS remote client for [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness). The phone is a control surface only: model calls, tool execution, files, terminals, and scheduled work run on the desktop Host. This repository is not developed or maintained by DeepSeek.

The app is written in SwiftUI (iOS 16+). It is not a WebView of the desktop UI, and it does not run a local Agent or Termux sidecar on the phone.

It speaks the same authenticated JSON/WebSocket protocol as [dsh-android](https://github.com/minglu6/dsh-android). Install the Host bridge from that repository (`dsh-plugin-pocket`); this repo does not ship a second plugin.

[Download IPA](https://github.com/minglu6/dsh-ios/releases/download/dsh-ios-latest/dsh-ios.ipa)

## Features

Available surfaces depend on the Host version and enabled plugins. The phone mirrors the desktop; layout is adapted for a narrow portrait touch screen.

| Area | This release |
| --- | --- |
| Connection | Pairing URI / QR / host:port + 6-digit code, LAN Bonjour `_dshpocket._tcp` (TXT `protocol=1` + 64-hex `instanceId`), unpaired nearby filter, paired-device TCP poll (10s, max 2), reconnect 1s→30s with Offline/Connecting restore gate, short iOS background task (not Android FGS), completion / approval local notifications |
| Sessions | Workspace grouping, pin / fork / archive / unarchive (archived rows are not openable), Host search + local title/path merge, drag reorder via `insertBefore` / `insertSessionBefore` when advertised, unread green dot, relative time. No session path, no chat “scroll to bottom” button |
| Chat | Streaming text and reasoning, Markdown / code / tables, official Think disclosure, tool-row receipts, ChatProcess fold, local echo, queue edit / steer, official approval card, user-question card, `/` commands, attachments, session image bubbles (`session.attachment`), official `@` mention tokens + chips, model + reasoning effort, permission-mode text chip, todo dock, goals, turn usage + composer stats, retry / turn-failure rows, WorkspaceChanges cards (when coding view is on). Export and session feedback live on `/` and `+`. Message actions: copy / like / dislike (when the remote host has `feedback.set`); branch lives on session ⋯ (`sessions.fork`). Opening the drawer, scrolling the transcript, or tapping outside the composer dismisses the keyboard |
| Trajectory | Chat / 轨迹 tab: compact ledger (7 cell kinds), toolbar 时长 / 轮次 / 调用 + search, swimlane, cell inspector 概述 / 参数 / 结果 / Schema / 计时, Request inspector 概述 / 选项 / 用量 / 计时 (official `ui-trajectory` copy). Hidden when coding view is off. Gap matrix: [docs/parity-gap.md](docs/parity-gap.md) |
| Configuration | General settings (appearance cards, font size in px, collapse timing, performance, permission, session log, link opening). Appearance and fonts stay on the phone and are not written to the remote host. Models page: provider editor + API keys (`models.providers*` / `credentials.*`). Agent presets (`presets.list` / `presets.read` / `presets.settings`) + official guide + Creator CTA. No invented “credentials” page |
| Host tools | Drawer shows the plugin manager (official catalog with switches, install / inspect / registries; settingsDescribe on bundle detail) when `plugins.list` is advertised, and scheduled tasks when `schedule.catalog` is advertised (drawer only; not a Settings row). Session Start panel matches desktop copy: workspace files + new terminal (no desktop shortcut suffixes). Desktop Start and ⋯ do not list browser / session inspector, so they stay unexposed. The Host PTY terminal and workspace file tree appear when those ops are advertised. File preview uses the same language table + isolated highlighter as Android, plus PDF / Office / XLS when those kinds apply. Session header shows the live jobs chip / panel when `jobs.list` is advertised. Gap matrix: [docs/parity-gap.md](docs/parity-gap.md) |

Host configuration is adopted from `plugins.settingsDescribe` and `settings.changed`. Normal use does not show a manual sync control.

The terminal forwards native key events directly: Return sends `\r`, Delete sends DEL, and multiline paste still requires confirmation. Snapshots use the remote PTY dimensions; size changes are applied in output-stream order. Primary-screen resizing reflows soft-wrapped lines and preserves the cursor, retaining up to 1,000 rows above and below the viewport for size restoration (not a scrollback browser). Full-screen applications remain responsible for redrawing their grid. The Start card omits desktop shortcuts and decorative chevrons; the terminal's session switcher remains.

Conversations show the current workspace and work mode below the Chat/Trajectory tabs, using the session's membership, directory and Agent preset rather than new-task drafts. Missing metadata is explicitly marked as unavailable. New tasks retain workspace and mode selectors, locked while the first message is being submitted; an unloaded preset catalog no longer hides the mode position.

## Architecture

```
iOS app (dev.dsh.pocket.ios)           Desktop
┌──────────────────────────┐          ┌─────────────────────────────────────┐
│ SwiftUI client           │  JSON    │ dsh Host                            │
│ display and control only │  over WS │  └─ dsh-plugin-pocket               │
│                          │◄────────►│      in-process Host services       │
│ protocol/ (DSHProtocol)  │ host:port│      authenticated JSON protocol    │
└──────────────────────────┘          └─────────────────────────────────────┘
```

The phone talks to `dsh-plugin-pocket` over `ws://host:port` (LAN or Tailscale). There is no independent iroh phone path and no Termux/node runtime in the IPA.

- Default plugin listen address is `0.0.0.0:7690`. Pairing advertises IPv4 only.
- When both a LAN IPv4 and a Tailscale address (`100.64.0.0/10` or `*.ts.net`) are available, desktop **Settings → Phone connection** switches **LAN / Tailscale**. The advertised address, QR code, and copy link change.
- The plugin advertises `_dshpocket._tcp`. The phone lists unpaired nearby hosts.
- The LAN path is `ws://` / HTTP and has no TLS. Pairing authenticates the device; it does not encrypt the wire. Cross-network use should be Tailscale or another trusted encrypted path. Do not expose port 7690 to the public internet.

## Download and install

Requirements:

- Phone: iOS 16 or later.
- Desktop: dsh installed and the Host kept running. The Android/plugin CI pins `@deepseek-ai/dsh@0.2.1-alpha.2`.
- Network: a reachable LAN, or the same Tailscale tailnet. The firewall must allow the bridge port (default TCP `7690`).

Latest unsigned IPA:

https://github.com/minglu6/dsh-ios/releases/download/dsh-ios-latest/dsh-ios.ipa

CI publishes a rolling prerelease tag `dsh-ios-latest`. The IPA is **unsigned**. Sign it with 轻松签 (or another sideload signer) before installing. Apple will not install an unsigned IPA through the normal App Store / Developer identity flow.

## Desktop plugin and pairing

Install the bridge from [dsh-android](https://github.com/minglu6/dsh-android), not from this repository.

```bash
git clone https://github.com/minglu6/dsh-android.git
cd dsh-android/plugin
npm install
npm run build:client
dsh plugin --profile desktop add "$PWD"
```

Restart the desktop Host. Management UI: desktop **Settings → Phone connection**.

### Pair the phone

1. On the computer, open **Settings → Phone connection**, choose LAN or Tailscale, and open the pairing window.
2. On the phone, open the host row at the bottom of the session drawer, then Phone connection. Use **Scan**, **Enter address**, or **Nearby devices**.
3. Scan the QR code or enter `dshpocket://pair?h=<host:port>&c=<6-digit-code>`. Leave the name empty to use the host address.
4. After the connection succeeds, select a workspace or session. Model providers and credentials are owned by the Host.

Pairing codes last 10 minutes, allow at most 3 attempts, and are consumed on success. Legacy iroh forms (`n=` / `nodeId#code`) are rejected.

Do not give the owner token to the phone. A paired device can control sessions, the terminal, and Host configuration. Device tokens are stored in the iOS Keychain.

## Build from source

Requires Xcode 16 (iOS 16 SDK) on macOS.

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

Unsigned IPA packaging (same as CI):

```bash
APP=derived/Build/Products/Release-iphoneos/dsh.app
mkdir Payload && cp -R "$APP" Payload/dsh.app
zip -qr dsh-ios.ipa Payload
```

| Path | Role |
| --- | --- |
| `protocol/` | Swift package: WebSocket client, protocol models, transcript reducer, pairing URI, reconnect / paging policy |
| `app/dsh/` | SwiftUI application (bundle id `dev.dsh.pocket.ios`, display name `dsh`) |
| `contract/` | Shared pairing-URI cases with dsh-android |
| `.github/workflows/ci.yml` | Protocol tests + unsigned IPA + rolling `dsh-ios-latest` release |

## CI

Pushes to `main` force-update the `dsh-ios-latest` prerelease with `dsh-ios.ipa`. Pull requests run the same checks and do not publish that tag.

## Limits

- The phone cannot run dsh locally. Sleeping the computer, quitting the Host, or losing the network stops remote control.
- iOS cannot keep a persistent “connected” notification the way Android ForegroundService does. `ConnectionKeeper` holds `beginBackgroundTask` with pings, then a `BGAppRefreshTask`; the WebSocket is not guaranteed after the system expires those windows.
- Nearby discovery uses Local Network + Bonjour, not Android `NEARBY_WIFI_DEVICES`.
- Upstream dsh is still alpha. Upgrade the app, the Android-hosted bridge, and dsh together.

## Acknowledgements

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness): Host behavior, interaction, and visual reference.
- [dsh-android](https://github.com/minglu6/dsh-android): pocket plugin, protocol, and mobile parity baseline this client follows.
