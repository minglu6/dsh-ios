import SwiftUI
import DSHProtocol

struct TerminalPanel: View {
    @ObservedObject var model: AppModel
    @State private var ownerSessionId: String
    @State private var opening = true
    @State private var attempt = 0
    @State private var forceNew = false
    @State private var requestedTerminalId: String?
    @State private var switcherOpen = false
    @State private var terminating = false
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
        let running = terminalPanelIsRunning(
            isOnline: model.isOnline,
            opening: opening,
            terminating: terminating,
            exited: model.terminalExited,
            state: current?.state
        )
        let hasScreen = current != nil
        let showScreen = hasScreen || model.terminalExited
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
                if showScreen {
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
        .onChange(of: attempt) { _ in attach() }
        .onChange(of: model.isOnline) { online in
            if terminalShouldAttachOnOnline(isOnline: online, exited: model.terminalExited) {
                attach()
            }
        }
        .onAppear { attach() }
        .onDisappear { model.closeTerminalFollow() }
        .task(id: "\(listAttempt)-\(model.isOnline)-\(ownerSessionId)") {
            if model.uiTestFixture {
                entries = model.uiTestTerminalEntries
                listing = false
                listError = nil
                return
            }
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
            Button {
                switcherOpen.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(current?.title?.nilIfBlank ?? L.terminal())
                        .font(.headline)
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                    OfficialGlyph(kind: .chevronDown, size: 12, color: T.text3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(current?.title?.nilIfBlank ?? L.terminal())
            .accessibilityIdentifier(terminalSwitcherButtonIdentifier())
            .popover(isPresented: $switcherOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                terminalSwitcherMenu(current: current)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(running ? T.ok : T.text3).frame(width: 6, height: 6)
                Text(statusLabel(running: running)).font(.system(size: 11)).foregroundStyle(T.text3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(T.surface)
    }

    @ViewBuilder
    private func statusLine(current: TerminalMeta?, hasScreen: Bool) -> some View {
        let ended = current?.state == "closed" || current?.state == "exited" || model.terminalExited
        let status: String? = {
            if !model.isOnline { return terminalDisconnectedCopy(english: L.en) }
            if opening { return terminalConnectingCopy(english: L.en) }
            if terminating { return L.terminalExitingEllipsis() }
            if model.terminalExited { return L.terminalExitedHint() }
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
                                        .stroke(T.borderL3, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
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

    private func statusLabel(running: Bool) -> String {
        if !model.isOnline { return L.terminalOffline() }
        if opening { return L.terminalConnecting() }
        if terminating { return L.terminalExiting() }
        if running { return L.terminalRunning() }
        return L.terminalStopped()
    }

    private func terminalSwitcherMenu(current: TerminalMeta?) -> some View {
        let canSwitch = model.isOnline && !opening && !terminating && model.ops.contains("terminal.follow")
        let canMutate = model.isOnline && !opening && !terminating
        return VStack(alignment: .leading, spacing: 0) {
            Text(L.terminalSessions())
                .font(.system(size: CGFloat(terminalSwitcherSectionFontSizePoints)))
                .foregroundStyle(T.text3)
                .padding(.horizontal, CGFloat(terminalSwitcherSectionPaddingXPoints))
                .padding(.vertical, CGFloat(terminalSwitcherSectionPaddingYPoints))
            if !model.isOnline {
                Text(L.connectToSwitchSessions())
                    .font(.system(size: CGFloat(terminalSwitcherSectionFontSizePoints)))
                    .foregroundStyle(T.text3)
                    .padding(.horizontal, CGFloat(terminalSwitcherSectionPaddingXPoints))
                    .padding(.vertical, CGFloat(terminalSwitcherSectionPaddingYPoints))
            } else if listing {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CGFloat(terminalSwitcherRowPaddingYPoints))
            } else if let listError {
                Text(listError)
                    .font(.system(size: CGFloat(terminalSwitcherRowFontSizePoints)))
                    .foregroundStyle(T.err)
                    .padding(.horizontal, CGFloat(terminalSwitcherRowPaddingXPoints))
                    .padding(.vertical, CGFloat(terminalSwitcherRowPaddingYPoints))
                switcherRow(title: L.retry(), icon: .refreshOutline, current: false, enabled: true) {
                    listAttempt += 1
                }
            } else if entries.isEmpty {
                Text(L.noRetainedSessions())
                    .font(.system(size: CGFloat(terminalSwitcherSectionFontSizePoints)))
                    .foregroundStyle(T.text3)
                    .padding(.horizontal, CGFloat(terminalSwitcherSectionPaddingXPoints))
                    .padding(.vertical, CGFloat(terminalSwitcherSectionPaddingYPoints))
            }
            ForEach(entries, id: \.sessionTerminalKey) { entry in
                let isCurrent = terminalSwitcherIsCurrent(
                    entry: entry,
                    currentSessionId: current?.sessionId,
                    currentId: current?.id
                )
                switcherRow(
                    title: terminalSwitcherTitle(entry),
                    icon: .terminalTab,
                    current: isCurrent,
                    enabled: canSwitch,
                    id: terminalSwitcherRowIdentifier(id: entry.id)
                ) {
                    if !isCurrent { openEntry(entry) }
                    switcherOpen = false
                }
            }
            Rectangle()
                .fill(T.border)
                .frame(height: CGFloat(terminalSwitcherSeparatorHeightPoints))
                .padding(.horizontal, CGFloat(terminalSwitcherSeparatorMarginXPoints))
                .padding(.vertical, CGFloat(terminalSwitcherSeparatorMarginYPoints))
            if model.ops.contains("terminal.create") {
                switcherRow(title: L.newTerminal(), icon: .plusOutline, current: false, enabled: canMutate) {
                    createTerminal()
                }
            }
            if let current, model.ops.contains("terminal.close") {
                switcherRow(title: L.close(), icon: nil, current: false, enabled: canMutate) {
                    closeCurrent(current)
                }
            }
        }
        .padding(CGFloat(terminalSwitcherMenuPaddingPoints))
        .frame(
            minWidth: CGFloat(terminalSwitcherMenuMinWidthPoints),
            maxWidth: CGFloat(terminalSwitcherMenuMaxWidthPoints)
        )
        .fixedSize(horizontal: false, vertical: true)
        .background(
            T.surface,
            in: RoundedRectangle(cornerRadius: CGFloat(terminalSwitcherMenuRadiusPoints), style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(terminalSwitcherMenuIdentifier())
        .modifier(PopoverCompactAdaptation())
    }

    private func switcherRow(
        title: String,
        icon: OfficialGlyph.Kind?,
        current: Bool,
        enabled: Bool,
        id: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: CGFloat(terminalSwitcherRowGapPoints)) {
                if let icon {
                    OfficialGlyph(kind: icon, size: CGFloat(terminalSwitcherIconSizePoints), color: T.ink)
                }
                Text(title)
                    .font(.system(size: CGFloat(terminalSwitcherRowFontSizePoints)))
                    .foregroundStyle(T.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if current {
                    OfficialGlyph(
                        kind: .checkOutline,
                        size: CGFloat(terminalSwitcherIconSizePoints),
                        color: T.ink
                    )
                }
            }
            .padding(.horizontal, CGFloat(terminalSwitcherRowPaddingXPoints))
            .padding(.vertical, CGFloat(terminalSwitcherRowPaddingYPoints))
            .frame(minHeight: CGFloat(terminalSwitcherRowMinHeightPoints), alignment: .center)
            .background(current ? T.hoverBg : Color.clear, in: RoundedRectangle(cornerRadius: CGFloat(terminalSwitcherRowRadiusPoints)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(current ? [.isSelected] : [])
        .accessibilityIdentifier(id ?? title)
    }

    private func attach() {
        if model.terminalAttachFrozen {
            opening = false
            return
        }
        model.terminalExited = false
        opening = model.isOnline
        if model.isOnline {
            model.openTerminal(sessionId: ownerSessionId, forceNew: forceNew, terminalId: requestedTerminalId)
        }
        forceNew = false
    }

    private func openEntry(_ entry: TerminalSessionEntry) {
        model.terminalExited = false
        requestedTerminalId = entry.id
        ownerSessionId = entry.sessionId
        attempt += 1
    }

    private func createTerminal() {
        switcherOpen = false
        model.terminalExited = false
        requestedTerminalId = nil
        forceNew = true
        attempt += 1
        listAttempt += 1
    }

    private func closeCurrent(_ current: TerminalMeta) {
        switcherOpen = false
        terminating = true
        model.terminalExited = true
        model.terminateTerminal(sessionId: current.sessionId, terminalId: current.id)
        requestedTerminalId = nil
        listAttempt += 1
        terminating = false
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
