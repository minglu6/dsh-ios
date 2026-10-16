import SwiftUI
import DSHProtocol

struct TerminalPanel: View {
    @ObservedObject var model: AppModel
    @State private var ownerSessionId: String
    @State private var opening = true
    @State private var attempt = 0
    @State private var forceNew = false
    @State private var requestedTerminalId: String?
    @State private var everAttached = false
    @State private var exitTarget: TerminalMeta?
    @State private var terminating = false
    @State private var exited = false
    @State private var operationError: String?
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
        let canOpen = model.isOnline && !opening && !terminating
        VStack(spacing: 0) {
            headerBar(current: current, running: running)
            statusLine(current: current, running: running, canOpen: canOpen)
            if current != nil || everAttached {
                TerminalView(model: model, enabled: running, platform: model.terminalPlatform)
            } else {
                Spacer()
                if opening && model.isOnline { ProgressView().tint(T.accent) }
                Spacer()
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
                everAttached = true
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
            Button { model.pop() } label: { Image(systemName: "chevron.left").foregroundStyle(T.ink) }
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
                        if isCurrent {
                            Label(entryLabel(entry), systemImage: "checkmark")
                        } else {
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
                        Label(L.newTerminal(), systemImage: "plus")
                    }
                    .disabled(!(model.isOnline && !opening && !terminating))
                }
                if current != nil, model.ops.contains("terminal.close") {
                    Button(L.exitTerminal()) { exitTarget = current }
                        .disabled(!(model.isOnline && !opening && !terminating))
                }
            } label: {
                HStack(spacing: 4) {
                    Text(current?.title?.nilIfBlank ?? L.terminal())
                        .font(.headline)
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(T.text3)
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

    private func statusLine(current: TerminalMeta?, running: Bool, canOpen: Bool) -> some View {
        let status: String? = {
            if !model.isOnline { return L.disconnectedReattach() }
            if opening { return L.terminalConnectingEllipsis() }
            if terminating { return L.terminalExitingEllipsis() }
            if exited { return L.terminalExitedHint() }
            if current == nil { return L.terminalUnavailable() }
            if current?.state == "closed" || current?.state == "exited" { return L.terminalEnded() }
            if current?.state != "running" { return L.terminalUnavailable() }
            return nil
        }()
        return VStack(alignment: .leading, spacing: 4) {
            if let operationError {
                Text(operationError).font(.system(size: 12)).foregroundStyle(T.err).padding(.horizontal, 16).padding(.vertical, 8)
            } else if let status {
                Text(status).font(.system(size: 12)).foregroundStyle(T.text3).padding(.horizontal, 16).padding(.vertical, 8)
            }
            if !running && canOpen && !exited {
                Button {
                    attempt += 1
                } label: {
                    Label(L.reconnect(), systemImage: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(T.accent)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var statusLabel: String {
        if !model.isOnline { return L.terminalOffline() }
        if opening { return L.terminalConnecting() }
        if terminating { return L.terminalExiting() }
        if model.terminalMeta?.state == "running" && !opening && !terminating { return L.terminalRunning() }
        return L.terminalStopped()
    }

    private func entryLabel(_ entry: TerminalSessionEntry) -> String {
        let title = entry.title?.nilIfBlank ?? "Terminal"
        return "\(title) · \(entry.id.prefix(8))"
    }

    private func attach() {
        guard !exited else { return }
        opening = model.isOnline
        operationError = nil
        if model.isOnline {
            model.openTerminal(sessionId: ownerSessionId, forceNew: forceNew, terminalId: requestedTerminalId)
        }
        forceNew = false
    }

    private func openEntry(_ entry: TerminalSessionEntry) {
        exited = false
        everAttached = false
        requestedTerminalId = entry.id
        ownerSessionId = entry.sessionId
        attempt += 1
    }

    private func createTerminal() {
        everAttached = false
        exited = false
        requestedTerminalId = nil
        forceNew = true
        attempt += 1
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
