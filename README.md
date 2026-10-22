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
| Connection | Pairing URI / QR / host:port + 6-digit code, paired-device TCP poll (10s, max 2), reconnect 1s→30s with Offline/Connecting restore gate, short iOS background task (not Android FGS), completion / approval local notifications |
| Sessions | Workspace grouping, pin / fork / archive / unarchive (archived rows are not openable), Host search + local title/path merge, drag reorder via `insertBefore` / `insertSessionBefore` when advertised, unread green dot, relative time. No session path, no chat “scroll to bottom” button |
| Chat | Streaming text and reasoning, Markdown / code / tables, official Think disclosure, tool-row receipts, ChatProcess fold, local echo, queue edit / steer, official approval card, user-question card, `/` commands, attachments, session image bubbles (`session.attachment`), official `@` mention tokens + chips, model + reasoning effort, permission-mode text chip, todo dock, goals, turn usage + composer stats, retry / turn-failure rows, WorkspaceChanges cards (when coding view is on). Export and session feedback live on `/` and `+`. Message actions: copy / like / dislike (when the remote host has `feedback.set`); branch lives on session ⋯ (`sessions.fork`). Opening the drawer, scrolling the transcript, or tapping outside the composer dismisses the keyboard |
| Trajectory | Chat / 轨迹 tab: compact ledger (7 cell kinds), toolbar 时长 / 轮次 / 调用 + search, swimlane, cell inspector 概述 / 参数 / 结果 / Schema / 计时, Request inspector 概述 / 选项 / 用量 / 计时 (official `ui-trajectory` copy). Hidden when coding view is off. Gap matrix: [docs/parity-gap.md](docs/parity-gap.md) |
| Configuration | General settings (appearance cards, font size in px, collapse timing, performance, permission, session log, link opening). Appearance and fonts stay on the phone and are not written to the remote host. Models page: provider editor + API keys (`models.providers*` / `credentials.*`). Agent presets (`presets.list` / `presets.read` / `presets.settings`) + official guide + Creator CTA. No invented “credentials” page |
| Host tools | Drawer shows the plugin manager (official catalog with switches, install / inspect / registries; settingsDescribe on bundle detail) when `plugins.list` is advertised, and scheduled tasks when `schedule.catalog` is advertised (drawer only; not a Settings row). Session Start panel matches desktop copy: workspace files + new terminal (no desktop shortcut suffixes). Desktop Start and ⋯ do not list browser / session inspector, so they stay unexposed. The Host PTY terminal and workspace file tree appear when those ops are advertised. File preview uses the same language table + isolated highlighter as Android, plus PDF / Office / XLS when those kinds apply. Session header shows the live jobs chip / panel when `jobs.list` is advertised. Gap matrix: [docs/parity-gap.md](docs/parity-gap.md) |

Host configuration is adopted from `plugins.settingsDescribe` and `settings.changed`. Normal use does not show a manual sync control.

The todo dock follows the desktop lifecycle: `todo/write` replaces the list, which remains visible when all tasks complete and after `turn/end`. The next `turn/start`, or an explicit `todos: null` / `todos: []` in a Host snapshot, resume, or projection, removes the entire dock. A missing projection key is not a clear, and stale state cannot revive old tasks. Historical `todo_write` arguments and results remain inspectable. `TodoLifecycleUITests` drives real follow frames through the production reducer→AppModel publication path using a DEBUG fixture, covering retention, clearing, and readable history without assigning dock state directly.

The background-jobs action follows desktop `JobListAction`: a neutral ongoing ring, full running-count label and chevron open an anchored roster. Live rows are two-line cards; settled rows stay compact and single-line with producer-owned exit details and elapsed time. The action owns shared clear/fold/output state, so clearing settled rows also updates the trigger and survives closing the popover, without deleting Host records or stopping live work. Output follows only visible observable rows; stopping requires two presses and converges through the real Host status. `JobsLifecycleUITests` covers the trigger, sections, local clear, output, stop and host/session isolation.

The terminal forwards native key events directly: Return sends `\r`, Delete sends DEL, and multiline paste still requires confirmation. Snapshots use the remote PTY dimensions; size changes are applied in output-stream order. Primary-screen resizing reflows soft-wrapped lines and preserves the cursor, retaining up to 1,000 rows above and below the viewport for size restoration (not a scrollback browser). Full-screen applications remain responsible for redrawing their grid. The Start card omits desktop shortcuts and decorative chevrons; the terminal's session switcher remains.

The terminal page reads loading state directly from the attachment model, so an immediate failure leaves Connecting and exposes Retry without waiting for a mirrored view state. Leaving the page cancels pending attachment work and releases the subscription without closing the remote shell.

Conversation actions keep a single 56pt header row above the Chat/Trajectory tabs: title, Agent Team, a passive preset indicator and the subagent catalog. Following Android's compact layout, the preset keeps a 14pt icon with the full mode name for accessibility when the session is loaded, nonblank and records a preset; it is not a button. Desktop instead shows icon plus text and hides that entire label below a 540px title-row container width. The Team icon is 14pt, its target is 28pt, and action spacing is 8pt. Drawer and Start controls have separate 48pt touch targets, with a 15pt Start icon. The catalog retains its complete count label in 12pt tertiary text. Existing sessions have no workspace/preset row above the composer, matching the desktop; the header preset comes only from the current session projection. Selectable workspace and preset menus belong to new tasks, with 2pt spacing, 20pt leading/16pt trailing insets and an 8pt gap above the composer. Missing preset options do not produce a placeholder selector. The Team roster/task board comes from `agentTeam`, separately from `subagentCatalog`; ordinary forks are not counted as subagents. Members and nested children can be opened, with navigation back to the lead; one-shot children are read-only. Complete live updates and catalog-only child navigation require the matching `dsh-android/plugin` update (`sessions.projections`, parent-address routing and projection forwarding). Installing an IPA does not update the running desktop plugin.

Composer statistics follow Settings → General → Performance & Usage. Compact speed/cache readings are plain text, not disabled buttons; Detailed exposes available session timing and token-usage dialogs. The context meter opens its breakdown in either mode. Changes to the shared Host preference update the row immediately; the phone does not silently change that preference. `ComposerStatsUITests` covers mode changes, missing data and popover interaction; it is included in the session-header, conversation and full UI scopes.

Statistics details use a nonmodal, upward-anchored portal: tapping a sibling metric switches the panel in one tap, and tapping outside dismisses it. Context values and the General Settings back control remain individually accessible.

Agent Team opens in a popover anchored to its header button and closes on an outside tap, not in a separate page. There are no extra Close or Refresh buttons. The current-session marker uses the desktop tinted-blue capsule; a lone member has no count, and an empty task board shows only its notice.

The new-session toolbar has no wordmark, matching Android and desktop. The centered hero and the drawer's branding remain unchanged.

New Session in the drawer header or a workspace row opens the draft landing page with selectable workspace and work mode, rather than immediately creating an empty remote session. A workspace row preselects its workspace; the header entry preserves the draft selection. The first message uses the existing creation flow. Leaving the previous conversation releases its subscription and clears its input and attachments without stopping remote work; new-session actions are disabled while the first message is sending.

Long conversation titles open their complete text in a header-anchored popover; ancestor breadcrumbs retain navigation. Text stays inside the bubble's safe area, clear of its arrow, with word wrapping and content-sized short titles; overflow scrolls vertically. Only the current nonblank session continuously loops an overflowing history title at 30pt/s, with a 0.75s pause at each end before restarting. Losing selection replaces the marquee with ordinary text from the beginning and a trailing ellipsis, rather than freezing the animation or retaining its tail. Reduce Motion keeps the current title static without looping; deselection still restores ordinary text. Row geometry, open-session actions and menu actions are unchanged.

The title popover shows the last-update age and current status below its full text. Pending approval, plan review and answers take precedence over Running/Idle. Live state updates in place and the age refreshes every 30 seconds without reopening the popover. Blank sessions or missing timestamps omit the time; unavailable state is not reported as Idle.

The transcript has a right-side turn rail and the desktop chevron return-to-bottom control. Marks retain Host turn identities, including sparse numbers; a supplied `turnOutline` exposes unloaded turns that can be paged in before jumping. Legacy Hosts show only known loaded turns. Long press previews a turn on touch screens. Manual reading and turn jumps stop tail following; returning to the bottom restores it. Showing the rail on phone widths is an intentional touch adaptation—the desktop hides it below its container breakpoint. CI `ui_scope=conversation` runs title, navigation and trajectory UI checks.

The work-mode menu uses a desktop-style anchored overlay, up to 360pt wide, measured to its content and bounded by the viewport with 12pt margins. Overflow scrolls vertically while keeping mode names and descriptions intact.

iOS retains the original typography system, with body/code/terminal defaults of 14/11/13pt and no app-wide enlargement. Settings-home navigation uses the same system body size as general settings (17pt by default), matching system headline titles and allowing rows to grow with Dynamic Type. Explicit personal font choices are preserved and never written to the remote host.

Edited-file cards and comparisons use the same real Host snapshots as Android: file switching, old/new line numbers, wrapping and a 5,000-line display limit. Failed reads remain visible and retryable rather than hiding the card; previews and comparison caches are isolated by Host/session/file identity. Missing events, capabilities or expired Host comparisons never produce fabricated diffs from tool summaries.

Source previews, including Python, retain Android's offline highlighting assets and the existing CSP isolation. Native delivery waits for an explicit renderer-ready message and only records a document as sent after its complete DOM text is acknowledged; WebView `didFinish` is not module readiness. Resource/script initialization failures expose an error and reload action instead of silently leaving a blank viewport.

Long-conversation trajectories cache complete derivations by chat-update revision, index request boundaries once, and load ledger rows lazily. Selection, collapsing and detail navigation reuse the snapshot. Search still covers full content; same-count streaming replacements, earlier-history loading and session changes invalidate the cache. CI supports `run_ui_tests=true` with `ui_scope=settings-trajectory` for focused settings and multi-MB trajectory interaction checks; this does not replace the full UI suite.

Trajectory record/request details follow the official desktop inspector, not Android sheet styling: an in-ledger right panel, a `min(92%, 420pt)` overlay on narrow layouts, and a resizable split on wide layouts. The 42pt header and 34pt tabs stay above independently scrolling content; closing restores the ledger without presenting another page. Details retain the last compatible record tab. Overview grids, syntax-colored JSON, raw text and rendered Markdown share desktop typography and flat surfaces. `TrajectoryUITests` covers detail navigation, tab persistence, Markdown/raw switching and dismissal in both appearances. Local macOS native-view smoke checks do not replace iOS simulator/device verification.

History pagination no longer shows a Load earlier button. Pull down at the top of Chat, Trajectory or Session Inspector to fetch the preceding page; the refresh indicator awaits the actual request. Existing records and reading anchors are retained, failed pulls can be retried, and exhausted histories make no further requests. The session drawer progressively reveals each group's remaining sessions as its visible boundary is reached, without Show more/less paging controls. Workspace collapsing, action menus and search-limit notices are unchanged. CI's `ui_scope=pagination` exercises history gestures and automatic roster expansion.

Chat's refresh control is a directly owned native subview rather than SwiftUI's reconciled `refreshControl` property. It stays attached while transcript measurements change and stops only after the actual page request completes. CI `ui_scope=reading` isolates native history loading and landing-toolbar screenshots; `ui_scope=conversation` also covers titles, navigation, trajectory and chat paging regressions.

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
- iOS connects using a QR code, pairing link, or manually entered address; it does not browse nearby hosts through Bonjour. If a host address changes, edit the saved address or scan a new QR code.
- The LAN path is `ws://` / HTTP and has no TLS. Pairing authenticates the device; it does not encrypt the wire. Cross-network use should be Tailscale or another trusted encrypted path. Do not expose port 7690 to the public internet.

## Download and install

Requirements:

- Phone: iOS 16 or later.
- Desktop: dsh installed and the Host kept running. The Android/plugin CI pins `@deepseek-ai/dsh@0.2.1-alpha.2`.
- Network: a reachable LAN, or the same Tailscale tailnet. The firewall must allow the bridge port (default TCP `7690`).

Version 1.0.0: [Release notes](https://github.com/minglu6/dsh-ios/releases/tag/v1.0.0) · [Unsigned IPA](https://github.com/minglu6/dsh-ios/releases/download/v1.0.0/dsh-ios-v1.0.0.ipa).

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
2. On the phone, open the host row at the bottom of the session drawer, then Phone connection. Use **Scan**, **Pairing link**, or **Enter address**.
3. Scan the QR code, paste `dshpocket://pair?h=<host:port>&c=<6-digit-code>`, or enter the host address and 6-digit code manually. Leave the name empty to use the host address.
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

Default runs keep protocol tests and the unsigned IPA build. Simulator screenshots and keyboard/IME UI tests are opt-in: use **Actions → ci → Run workflow** and enable `run_ui_tests`. Manual runs upload artifacts but do not publish the rolling release.

New runs cancel older runs for the same event and ref. IPA artifacts disable redundant upload compression because the IPA is already ZIP-compressed.

## Limits

- The phone cannot run dsh locally. Sleeping the computer, quitting the Host, or losing the network stops remote control.
- iOS cannot keep a persistent “connected” notification the way Android ForegroundService does. `ConnectionKeeper` holds `beginBackgroundTask` with pings, then a `BGAppRefreshTask`; the WebSocket is not guaranteed after the system expires those windows.
- Local Network permission is still required to connect to LAN hosts and probe paired devices over TCP; it is not used for nearby-device discovery.
- Upstream dsh is still alpha. Upgrade the app, the Android-hosted bridge, and dsh together.

## Acknowledgements

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness): Host behavior, interaction, and visual reference.
- [dsh-android](https://github.com/minglu6/dsh-android): pocket plugin, protocol, and mobile parity baseline this client follows.
