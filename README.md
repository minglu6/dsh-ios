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
| Connection | Pairing URI / QR / host:port + 6-digit code, LAN Bonjour `_dshpocket._tcp`, multi-host list, reconnect with backoff, **Copy diagnostic report** |
| Sessions | Workspace grouping, pin / fork / archive, unread green dot, relative time. No session path, no move up/down, no chat “scroll to bottom” button |
| Chat | Streaming text and reasoning, tool rows, local echo, queue / steer send, approvals, `@` file and session mentions, model picker, history page |
| Configuration | Host-mirrored general settings (appearance / language) and model catalog. No invented “credentials” page. Diagnostics live on Phone connection |
| Host tools | Drawer / settings show plugins and scheduled tasks only when the Host advertises those ops. Trajectory, PTY, file tree, and live jobs are not exposed until they have a real surface. Gap matrix: [docs/parity-gap.md](docs/parity-gap.md) |

Host configuration is adopted from `plugins.settingsDescribe` and `settings.changed`. Normal use does not show a manual sync control.

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
- Trajectory inspector, PTY terminal emulator, file tree, and live jobs watch are not in this first IPA; the protocol client already exposes the matching ops.
- Upstream dsh is still alpha. Upgrade the app, the Android-hosted bridge, and dsh together.

## Acknowledgements

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness): Host behavior, interaction, and visual reference.
- [dsh-android](https://github.com/minglu6/dsh-android): pocket plugin, protocol, and mobile parity baseline this client follows.
