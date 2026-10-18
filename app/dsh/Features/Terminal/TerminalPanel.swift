import SwiftUI
import DSHProtocol

struct TerminalPanel: View {
    @ObservedObject var model: AppModel
    @State private var ownerSessionId: String
    @State private var opening = true
    @State private var attempt = 0
    @State private var forceNew = false
    @State private var requestedTerminalId: String?
    @State private var exitTarget: TerminalMeta?
    @State private var terminating = false
    @State private var exited = false
    @State private var entries: [TerminalSessionEntry] = []
    @State private var listing = false
    @State private var listError: String?
    @State private var listAttempt = 0

    init(model: AppModel) {
        self.model = model
        let sessionId = model.chat?.sessionId ?? ""
        let owner = model.activeId.flatMap { TerminalStore.panelOwner(hostId: $0, contextSessionId: sessionId) } ?? sessionId
        _ownerSessionId = State(initialValue: owner)
    }

    var body: some View {
        let current = model.terminalMeta.flatMap { $0.sessionId == ownerSessionId && !opening ? $0 : nil }
        let running = model.isOnline && !opening && !terminating && current?.state == "running"
        let hasScreen = current != nil
        VStack(spacing: 0) {
            headerBar(current: current, running: running)
            if model.terminalMissing {
                missingTerminal
            } else {
                statusLine(current: current, hasScreen: hasScreen)
                if let failure = model.terminalFailure, model.isOnline {
                    Text(terminalFailureCopy(message: failure, english: L.en))
                        .font(.system(size: CGFloat(terminalBodyFontSizePoints)))
                        .foregroundStyle(T.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, CGFloat(terminalErrorPaddingXPoints))
                        .padding(.vertical, CGFloat(terminalErrorPaddingYPoints))
                        .background(T.surface2)
                        .accessibilityIdentifier("terminalError")
                }
                if hasScreen {
                    TerminalView(model: model, enabled: running, platform: model.terminalPlatform)
                } else {
                    Spacer()
                    // Skip: desktop terminal has no center spinner
                    // (`terminalCenterLoadingUsesOfficialGlyph`).
                    if opening && model.isOnline { ProgressView().tint(T.accent) }
                    Spacer()
                }
            }
        }
        .background(T.bg)
        .confirmationDialog(L.exitTerminalTitle(), isPresented: Binding(
            get: { exitTarget != nil },
            set: { if !$0 { exitTarget = nil } }
        ), titleVisibility: .visible) {
            Button(L.exitTerminal(), role: .destructive) {
                guard let target = exitTarget else { return }
                exitTarget = nil
                terminating = true
                Task {
                    model.terminateTerminal(sessionId: target.sessionId, terminalId: target.id)
                    exited = true
                    requestedTerminalId = nil
                    listAttempt += 1
                    terminating = false
                }
            }
            Button(L.cancel(), role: .cancel) { exitTarget = nil }
        } message: {
            Text(L.exitTerminalBody())
        }
        .onChange(of: attempt) { _ in attach() }
        .onChange(of: model.isOnline) { online in
            if terminalShouldAttachOnOnline(isOnline: online, exited: exited) {
                attach()
            }
        }
        .onAppear { attach() }
        .onDisappear { model.closeTerminalFollow() }
        .task(id: "\(listAttempt)-\(model.isOnline)-\(ownerSessionId)") {
            guard model.isOnline, model.ops.contains("terminal.list") else { return }
            listing = true
            listError = nil
            do {
                entries = try await model.terminalSessions(sessionId: model.chat?.sessionId ?? ownerSessionId).entries
            } catch is CancellationError {
                return
            } catch {
                listError = error.localizedDescription.isEmpty ? L.cannotLoadTerminalSessions() : error.localizedDescription
            }
            listing = false
        }
        .onChange(of: model.terminalMeta?.id) { _ in
            if model.terminalMeta?.sessionId == ownerSessionId {
                opening = false
                if let host = model.activeId, let chat = model.chat?.sessionId {
                    TerminalStore.setPanelOwner(hostId: host, contextSessionId: chat, ownerSessionId: ownerSessionId)
                }
            }
        }
        .onChange(of: model.terminalOpening) { value in
            if !value { opening = false }
        }
    }

    private func headerBar(current: TerminalMeta?, running: Bool) -> some View {
        HStack(spacing: 8) {
            Button { model.pop() } label: { OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink) }
            Menu {
                Text(L.terminalSessions()).font(.caption).foregroundStyle(T.text3)
                if !model.isOnline {
                    Text(L.connectToSwitchSessions()).font(.caption).foregroundStyle(T.text3)
                } else if listing {
                    ProgressView()
                } else if let listError {
                    Text(listError).foregroundStyle(T.err)
                    Button(L.retry()) { listAttempt += 1 }
                } else if entries.isEmpty {
                    Text(L.noRetainedSessions()).font(.caption).foregroundStyle(T.text3)
                }
                ForEach(entries, id: \.sessionTerminalKey) { entry in
                    let isCurrent = current?.sessionId == entry.sessionId && current?.id == entry.id
                    Button {
                        if !isCurrent { openEntry(entry) }
                    } label: {
                        HStack(spacing: 8) {
                            if isCurrent {
                                OfficialGlyph(kind: .checkOutline, size: 14, color: T.ink)
                            }
                            Text(entryLabel(entry))
                        }
                    }
                    .disabled(!(model.isOnline && !opening && !terminating && model.ops.contains("terminal.follow")))
                }
                Divider()
                if model.ops.contains("terminal.create") {
                    Button {
                        createTerminal()
                    } label: {
                        HStack(spacing: CGFloat(dswButtonIconGapPoints)) {
                            OfficialGlyph(kind: .plusOutline, size: 14, color: T.ink)
                            Text(L.newTerminal())
                        }
                    }
                    .disabled(!(model.isOnline && !opening && !terminating))
                }
                if current != nil, model.ops.contains("terminal.close") {
                    Button(L.close()) { exitTarget = current }
                        .disabled(!(model.isOnline && !opening && !terminating))
                }
            } label: {
                HStack(spacing: 4) {
                    Text(current?.title?.nilIfBlank ?? L.terminal())
                        .font(.headline)
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                    OfficialGlyph(kind: .chevronDown, size: 12, color: T.text3)
                }
            }
            .accessibilityLabel(current?.title?.nilIfBlank ?? L.terminal())
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(running ? T.ok : T.text3).frame(width: 6, height: 6)
                Text(statusLabel).font(.system(size: 11)).foregroundStyle(T.text3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(T.surface)
    }

    @ViewBuilder
    private func statusLine(current: TerminalMeta?, hasScreen: Bool) -> some View {
        let ended = current?.state == "closed" || current?.state == "exited" || exited
        let status: String? = {
            if !model.isOnline { return terminalDisconnectedCopy(english: L.en) }
            if opening { return terminalConnectingCopy(english: L.en) }
            if terminating { return L.terminalExitingEllipsis() }
            if exited { return L.terminalExitedHint() }
            if current?.state == "closed" || current?.state == "exited" { return L.terminalEnded() }
            return nil
        }()
        let retry = !ended && !opening && !terminating && (!model.isOnline || current == nil || current?.state == "failed")
        if status != nil || retry {
            HStack(spacing: 0) {
                HStack(spacing: CGFloat(terminalStatusGapPoints)) {
                    if let status {
                        Text(status)
                            .font(.system(size: CGFloat(terminalBodyFontSizePoints)))
                            .foregroundStyle(T.ink)
                    }
                    if retry {
                        Button {
                            attempt += 1
                        } label: {
                            Text(terminalRetryLabel(hasScreenInfo: hasScreen, disconnected: !model.isOnline, english: L.en))
                                .font(.system(size: CGFloat(dswButtonSmFontSizePoints)))
                                .foregroundStyle(T.ink)
                                .frame(height: CGFloat(dswButtonSmHeightPoints))
                                .padding(.horizontal, CGFloat(dswButtonSmHorizontalPaddingPoints))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusSmPoints))
                                        .stroke(T.border, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("terminalStatus")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CGFloat(terminalStatusPaddingXPoints))
            .padding(.vertical, CGFloat(terminalStatusPaddingYPoints))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.surface2)
        }
    }

    private var missingTerminal: some View {
        VStack(spacing: CGFloat(terminalEmptyGapPoints)) {
            TerminalMissingArtwork()
            Text(terminalMissingCopy(english: L.en))
                .font(.system(size: CGFloat(terminalBodyFontSizePoints)))
                .foregroundStyle(T.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(CGFloat(terminalBodyFontSizePoints) * (terminalEmptyMessageLineHeight - 1))
                .accessibilityIdentifier("terminalMissing")
            Button(action: createTerminal) {
                HStack(spacing: CGFloat(dswButtonIconGapPoints)) {
                    OfficialGlyph(kind: .plusOutline, size: 16, color: T.onPrimary)
                    Text(L.newTerminal())
                        .font(.system(size: CGFloat(dswButtonFontSizePoints)))
                        .foregroundStyle(T.onPrimary)
                }
                .padding(.horizontal, CGFloat(dswButtonMdHorizontalPaddingPoints))
                .frame(height: CGFloat(dswButtonMdHeightPoints))
                .background(T.primaryButton, in: RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusMdPoints)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.newTerminal())
            .accessibilityIdentifier("terminalNew")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CGFloat(terminalEmptyPaddingPoints))
    }

    private var statusLabel: String {
        if !model.isOnline { return L.terminalOffline() }
        if opening { return L.terminalConnecting() }
        if terminating { return L.terminalExiting() }
        if model.terminalMeta?.state == "running" && !opening && !terminating { return L.terminalRunning() }
        return L.terminalStopped()
    }

    private func entryLabel(_ entry: TerminalSessionEntry) -> String {
        terminalTabTitle(entry.title)
    }

    private func attach() {
        guard !exited else { return }
        if model.terminalAttachFrozen {
            opening = false
            return
        }
        opening = model.isOnline
        if model.isOnline {
            model.openTerminal(sessionId: ownerSessionId, forceNew: forceNew, terminalId: requestedTerminalId)
        }
        forceNew = false
    }

    private func openEntry(_ entry: TerminalSessionEntry) {
        exited = false
        requestedTerminalId = entry.id
        ownerSessionId = entry.sessionId
        attempt += 1
    }

    private func createTerminal() {
        exited = false
        requestedTerminalId = nil
        forceNew = true
        attempt += 1
    }
}

/// Desktop `TerminalBody` missing-terminal SVG (`client.terminal.js` ~13292).
private struct TerminalMissingArtwork: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / CGFloat(terminalMissingArtViewBox)
            var ctx = context
            ctx.scaleBy(x: scale, y: scale)
            var plate = Path()
            plate.addRoundedRect(
                in: CGRect(
                    x: terminalMissingArtRectX,
                    y: terminalMissingArtRectY,
                    width: terminalMissingArtRectWidth,
                    height: terminalMissingArtRectHeight
                ),
                cornerSize: CGSize(width: terminalMissingArtRectRadius, height: terminalMissingArtRectRadius)
            )
            ctx.fill(plate, with: .color(Color(hex: terminalMissingArtFillHex)))
            ctx.stroke(
                Path(SVGPath.cgPath(terminalMissingArtPromptPath)),
                with: .color(Color(hex: terminalMissingArtStrokeHex)),
                style: StrokeStyle(
                    lineWidth: CGFloat(terminalMissingArtStrokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(width: CGFloat(terminalMissingArtSizePoints), height: CGFloat(terminalMissingArtSizePoints))
        .accessibilityHidden(true)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
