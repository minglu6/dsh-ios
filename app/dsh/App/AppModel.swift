import Foundation
import Network
import SwiftUI
import UIKit
import DSHProtocol

enum Dot: String {
    case online, connecting, offline, unauthorized
}

/// Desktop `ArchiveConfirmForm` pending request (Host `workspace/session-active`).
struct ArchiveConfirmRequest: Equatable, Identifiable {
    var session: SessionSummary
    var details: JSONValue?
    var id: String { session.sessionId }
}

struct ChatState {
    var sessionId: String
    var items: [Item] = []
    var queuedPrompts: [QueuedPrompt] = []
    var title: String?
    var running = false
    var loaded = false
    var hasMore = false
    var firstSeq: Int64 = -1
    var loadingOlder = false
    var todos: [TodoItem] = []
    var planMode = false
    var steps: [StepRecord] = []
    var turns: [TurnRecord] = []
    /// Last committed assistant text key per turn; filled in `publishChat`.
    var lastAnswerKeys: [Int: String] = [:]
    var composerMetrics = ComposerMetrics()
    var turnTokenUsage: [Int: TurnTokenUsage] = [:]
    var inspectorRecords: [JSONValue] = []
    var goal: JSONValue?
    var agentPreset: String?
}

enum AttachStatus: String, Equatable {
    case pending, uploading, ready, failed
}

struct PendingAttach: Equatable, Identifiable {
    var id = UUID()
    var name: String
    var isImage: Bool
    var mediaType: String
    var data: Data
    var receiptId: String?
    var status: AttachStatus
}

struct ModelChoice: Equatable {
    var provider: String
    var model: String
    var name: String
    var effort: String?
}

enum DrawerPanel: String, Identifiable {
    case plugins, schedule, files, terminal, trajectory, jobs, settings, browser, inspector, start
    var id: String { rawValue }
}

struct FilePreviewRef: Equatable, Identifiable {
    var sessionId: String
    var path: String
    var id: String { "\(sessionId)\n\(path)" }
}

struct JobDetailState: Equatable {
    var jobId: String
    var status: String
    var output: [String]
    var error: String?
}

struct ExportShare: Identifiable {
    let id = UUID()
    let url: URL
}

enum AppRoute: Equatable {
    case sessions
    case chat
    case connections
    case pair
    case settings
    case general
    case models
    case builtinPlugins
    case presets
    case diagnostics
    case panel(DrawerPanel)
}

extension AppRoute {
    /// Full-screen routes that must not sit under the session drawer overlay.
    /// Matches Android `Screen.Connections` / `Screen.Settings`: replace chat
    /// and close the drawer — never a half-sheet beside it.
    var closesSessionDrawer: Bool {
        switch self {
        case .chat, .sessions: return false
        case .panel(.browser): return false
        default: return true
        }
    }

    /// Drawer overlay is only legal on chat / sessions / in-app browser.
    var allowsSessionDrawer: Bool { !closesSessionDrawer }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let appVersion = "0.1.0"

    @Published var profiles: [Profile] = ProfileStore.load()
    @Published var activeId: String? = ProfileStore.activeId
    @Published var status: [String: Dot] = [:]
    @Published var routes: [String: Route] = [:]
    @Published var sessions: [SessionSummary] = []
    @Published var workspaces: [WorkspaceView] = []
    @Published var archivedIds: Set<String> = []
    @Published var pinnedIds: Set<String> = []
    @Published var unreadIds: Set<String> = []
    @Published var jobs: [JobRow]?
    @Published var jobsFailed = false
    @Published var jobsPanelError: String?
    @Published var jobDetail: JobDetailState?
    @Published var chat: ChatState?
    @Published var approvals: [Approval] = []
    @Published var userQuestions: [UserQuestion] = []
    @Published var questionDrafts: [String: [String: QuestionDraft]] = [:]
    @Published var questionPageIndex: [String: Int] = [:]
    private let questionStore = UserQuestionStore()
    @Published var ops: Set<String> = []
    @Published var catalog: ModelCatalog?
    @Published var modelChoice: ModelChoice?
    @Published var errorMessage: String?
    @Published var toast: String?
    @Published var language: AppLanguage = AppPrefs.language
    @Published var appearance: Appearance = AppPrefs.appearance
    @Published var busySend: BusySend = AppPrefs.busySend
    @Published var fontSize: Int = AppPrefs.fontSize
    @Published var codeFontSize: Int = AppPrefs.codeFontSize
    @Published var terminalFontSize: Int = AppPrefs.terminalFontSize
    @Published var textFontFamily: String = AppPrefs.textFontFamily
    @Published var codeFontFamily: String = AppPrefs.codeFontFamily
    @Published var terminalFontFamily: String = AppPrefs.terminalFontFamily
    @Published var codeWordWrap: Bool = AppPrefs.codeWordWrap
    @Published var collapseTiming: CollapseTiming = .completion
    @Published var pluginCatalogRevision: Int64 = 0
    @Published var scheduleCatalogRevision: Int64 = 0
    @Published var modelSettingsRevision: Int64 = 0
    @Published var permissionCatalog: PermissionCatalog?
    @Published var permissionCatalogError: String?
    @Published var permissionCatalogLoading = false
    @Published var sessionPermission: String?
    /// Landing hero selection applied to the session that gets created.
    /// Memory-only: desktop hero is already a Host session, so it does not persist a local draft.
    @Published var draftPermission: String?
    @Published var draftModel: ModelChoice?
    /// Bumped when a landing draft is written so an in-flight `permissions.get` cannot overwrite it.
    private var permissionHydrationGeneration = 0
    @Published var permissionChanging = false
    @Published var modelPending: ModelChoice?
    @Published var catalogLoading = false
    @Published var catalogError: String?
    @Published var goalActivation: String?
    @Published var pendingAttaches: [PendingAttach] = []
    @Published var commandEntries: [JSONValue] = []
    @Published var skillEntries: [SkillEntry] = []
    private var skillEntriesByScope: [String: [SkillEntry]] = [:]
    @Published var draftWorkspaceId: String?
    @Published var pendingBrowserURL: URL?
    var fileTreeStates: [String: FileTreeState] = [:]
    var fileTreeOffsets: [String: CGFloat] = [:]
    @Published var hiddenQuestionId: String?
    @Published var nearby: [DiscoveredHost] = []
    @Published var composerText = ""
    @Published var mentionQuery: String?
    @Published var fileMentions: [FileReference] = []
    @Published var sessionMentions: [SessionReference] = []
    @Published var routeStack: [AppRoute] = []
    @Published var showDrawer = false
    @Published var feedback: [String: MessageFeedback] = [:]
    @Published var firstPrompt: FirstPrompt? = nil
    private var firstPromptSessionId: String?
    @Published var sessionGroupBy: SessionGroupBy = AppPrefs.sessionGroupBy
    @Published var sessionOrderBy: SessionOrderBy = AppPrefs.sessionOrderBy
    @Published var archivedFilter: ArchivedFilter = AppPrefs.archivedFilter
    @Published var collapsedWorkspaces: Set<String> = []
    @Published var terminalRevision: Int64 = 0
    @Published var terminalMeta: TerminalMeta?
    @Published var terminalPlatform: String?
    @Published var terminalOpening = false
    @Published var terminalFailure: String?
    @Published var terminalMissing = false
    @Published var terminalExited = false
    var terminalAttachFrozen = false
    @Published var filePreview: FilePreviewRef?
    @Published var exportShare: ExportShare?
    @Published var filesRevision: Int64 = 0
    @Published var presetRoster: [JSONValue] = []
    @Published var draftPreset = ""
    @Published var pendingCreatorPreset: String?
    @Published var searchHits: [SessionSummary] = []
    @Published var searchHostHasMore = false
    @Published var searching = false
    @Published var lastArchivedId: String?
    @Published var toastUndoArchiveId: String?
    @Published var archiveConfirm: ArchiveConfirmRequest?
    var uiTestFixture = false
    var uiTestFilePreviewText: String?

    let terminal = AnsiTerminal()
    let hostSettings = HostSettings()
    let lan = LanDiscovery()

    private var client: PocketClient?
    private var connectTask: Task<Void, Never>?
    private var reducer = TranscriptReducer()
    private var inspectorLog = SessionInspectorLog()
    private lazy var transcriptPublisher = TranscriptPublisher { [weak self] in
        Task { @MainActor in self?.publishChat() }
    }
    private var subId: String?
    private var followEpoch: Int64 = 0
    private var backoffMs: Int64 = ReconnectBackoffPolicy.reset()
    private var reconnectWake = false
    private var terminalSubId: String?
    private var terminalOpenEpoch: Int64 = 0
    private var terminalHostId: String?
    private var terminalWantCols = 80
    private var terminalWantRows = 24
    private var terminalReady = TerminalReady()
    private var terminalStray: [String: [JSONValue]] = [:]
    private var terminalRosterRevision: [String: Int64] = [:]
    private var terminalAttachTask: Task<Void, Never>?
    private let completionReminders = CompletionReminders()
    private var completionReadySession: String?
    private var desiredViewedSession: String?
    private var completionViewClient: PocketClient?
    private var completionViewSession: String?
    private var completionViewBusy = false
    private var completionViewPending = false
    private var jobsWatchers = 0
    private var jobsLoop: Task<Void, Never>?
    private var jobsWatchHostId: String?
    private var jobsWatchSessionId: String?
    private var jobsLoopGeneration: Int64 = 0
    private var jobFollows: [String: String] = [:]
    private var jobFollowEnded: Set<String> = []
    private var jobFollowInFlight: Set<String> = []
    private var jobStray: [String: [JSONValue]] = [:]
    private var jobsReconcileBusy = false
    private var jobsReconcilePending = false
    private var jobsPanelKillError = false
    private var selectedJobId: String? = nil
    private var permissionProjectionSeq: Int64 = -1
    private var goalProjectionSeq: Int64 = -1
    private var modelProjectionSeq: Int64 = -1
    private var presetProjectionSeq: Int64 = -1
    private var goalActivationEpoch: Int64 = 0
    private var attachmentCache: [String: Data] = [:]
    private var restoreGeneration: Int64 = 0
    private var probeTask: Task<Void, Never>?
    private var searchGeneration: Int64 = 0
    private var resumeTask: Task<Void, Never>?
    private var liveRefreshBusy = false
    private var liveRefreshPending = false

    var activeProfile: Profile? { profiles.first { $0.id == activeId } }
    var currentDot: Dot? { activeId.flatMap { status[$0] } }
    var isOnline: Bool { currentDot == .online }

    private init() {
        TrajL.en = AppPrefs.language == .en
        if UITestLaunch.isEnabled {
            installUITestFixture()
            return
        }
        if let id = activeId { connect(profileId: id) }
        lan.onHosts = { [weak self] hosts in
            Task { @MainActor in self?.applyDiscovery(hosts) }
        }
        lan.start()
        ConnectionKeeper.shared.start()
        if let id = activeId { collapsedWorkspaces = AppPrefs.collapsedWorkspaces(hostId: id) }
    }

    var currentRoute: AppRoute {
        if let last = routeStack.last { return last }
        if chat != nil { return .chat }
        return .sessions
    }

    func push(_ route: AppRoute) {
        routeStack.append(route)
        // Phone (Android MainActivity): Connections / Settings / panels replace
        // the chat screen and close the session drawer — never a half-sheet
        // over an open drawer. Drop the IME so Settings / 远程主机 are not
        // covered by a leftover composer keyboard.
        if route.closesSessionDrawer {
            showDrawer = false
            Keyboard.dismiss()
        }
    }
    func pop() { if !routeStack.isEmpty { routeStack.removeLast() } }

    func connect(profileId: String) {
        if uiTestFixture { return }
        resumeTask?.cancel()
        resumeTask = nil
        connectTask?.cancel()
        client?.close()
        client = nil
        transcriptPublisher.cancel()
        inspectorLog = SessionInspectorLog()
        hostSettings.clear()
        followEpoch += 1
        detachFollow()
        resetTerminalAttachment(keepScreen: false)
        resetCompletion()
        resetJobs(unfollow: false)
        activeId = profileId
        ProfileStore.activeId = profileId
        collapsedWorkspaces = AppPrefs.collapsedWorkspaces(hostId: profileId)
        filePreview = nil
        sessions = []
        chat = nil
        firstPrompt = nil
        firstPromptSessionId = nil
        approvals = []
        resetQuestionStore(clearDrafts: true)
        sessionPermission = nil
        goalActivation = nil
        pendingAttaches = []
        commandEntries = []
        skillEntries = []
        skillEntriesByScope = [:]
        ops = []
        presetRoster = []
        searchHits = []
        searchHostHasMore = false
        catalog = nil
        catalogError = nil
        modelChoice = nil
        draftModel = nil
        modelPending = nil
        routes[profileId] = nil
        connectTask = Task { await runConnection(profileId) }
    }

    func pair(name: String, host: String, port: Int, code: String) async throws {
        let deviceName = try clipProfileName(name.isEmpty ? host : name)
        guard let url = websocketURL(host: host, port: port) else {
            throw PocketError(code: "transport", message: "invalid host:port")
        }
        let client = PocketClient(appVersion: Self.appVersion)
        let hello = try await client.connect(url: url, host: host, auth: .pair(code: code, deviceName: deviceName))
        if let issue = hello.handshakeVersions().flatMap({
            VersionCompatibility.evaluate(appVersion: Self.appVersion, handshake: $0)
        }) {
            client.close()
            throw compatibilityError(issue)
        }
        guard let token = hello.issuedToken, let deviceId = hello.deviceId else {
            client.close()
            throw PocketError(code: "pair", message: L.pairFailed())
        }
        let profile = Profile(
            id: UUID().uuidString,
            name: deviceName,
            deviceId: deviceId,
            host: host,
            port: port,
            instanceId: hello.instanceId ?? "",
            lastUsedAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        try TokenStore.put(profileId: profile.id, token: token)
        profiles = [profile] + profiles.filter { $0.id != profile.id }
        ProfileStore.save(profiles)
        client.close()
        connect(profileId: profile.id)
    }

    func pair(link: PairingLink, name: String) async throws {
        try await pair(name: name, host: link.host, port: link.port, code: link.code)
    }

    /// Rename a local desktop profile label on the phone.
    /// Does not call Host `PATCH /pocket/devices`.
    func renameProfile(_ id: String, name: String) throws {
        let trimmed = try clipProfileName(name)
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw PocketError(code: "not-found", message: "profile not found: \(id)")
        }
        profiles[index].name = trimmed
        ProfileStore.save(profiles)
    }

    func removeProfile(_ id: String) {
        if activeId == id {
            resumeTask?.cancel()
            resumeTask = nil
            connectTask?.cancel()
            client?.close()
            client = nil
            activeId = nil
            ProfileStore.activeId = nil
        }
        TokenStore.remove(profileId: id)
        profiles.removeAll { $0.id == id }
        ProfileStore.save(profiles)
        status[id] = nil
        routes[id] = nil
    }

    func openSession(_ sessionId: String) {
        if isArchived(sessionId) { return }
        clearFirstPrompt()
        beginSession(sessionId)
    }

    private func beginSession(_ sessionId: String, seed: FirstPrompt? = nil) {
        initializeChat(sessionId, seed: seed)
        showDrawer = false
        loadSessionPermission(sessionId)
        Task {
            guard let client else { return }
            do {
                try await refollow(client, sessionId: sessionId, afterSeq: nil)
            } catch is CancellationError {
            } catch {
                if chat?.sessionId != sessionId { return }
                if SessionNotFoundPolicy.matches(error) {
                    absorbMissingSession(sessionId)
                    return
                }
                emit(error.localizedDescription)
                chat?.loaded = true
            }
        }
    }

    func createAndOpenSession(workspaceId: String? = nil, preset: String? = nil, then: (() -> Void)? = nil) {
        Task {
            guard let client else { return }
            let chosenWorkspace = workspaceId ?? draftWorkspaceId ?? workspaces.first?.workspaceId
            if landingComposerNeedsWorkspace(selectedWorkspaceId: chosenWorkspace, workspaceCount: workspaces.count) {
                presentToast(landingWorkspaceRequired(english: L.en))
                return
            }
            do {
                let chosen = preset ?? pendingCreatorPreset ?? draftPreset.nilIfBlank
                let id = try await client.createSession(
                    agentPreset: chosen,
                    workspaceId: chosenWorkspace
                )
                pendingCreatorPreset = nil
                openSession(id)
                await applyDraftPermission(sessionId: id)
                await applyDraftModel(sessionId: id)
                then?()
            } catch {
                emit(error.localizedDescription)
            }
        }
    }

    var isParentOffline: Bool {
        let current = sessions.first { $0.sessionId == chat?.sessionId }
        let parentId = current?.parentSessionId
        let parent = parentId.flatMap { id in sessions.first { $0.sessionId == id } }
        return composerParentOffline(
            origin: current?.origin,
            parentSessionId: parentId,
            parentListed: parent != nil,
            parentOffline: parent == nil
        )
    }

    var canSteerQueue: Bool {
        chat?.running == true
            && !(chat?.queuedPrompts.isEmpty ?? true)
            && ops.contains("queue.update")
    }

    var landingWorkspaceLabel: String? {
        if let id = draftWorkspaceId, let workspace = workspaces.first(where: { $0.workspaceId == id }) {
            return workspaceDisplayTitle(title: workspace.title, path: workspace.path, localizedDefault: L.defaultWorkspace())
        }
        if let first = workspaces.first {
            return workspaceDisplayTitle(title: first.title, path: first.path, localizedDefault: L.defaultWorkspace())
        }
        return nil
    }

    func skillEntries(for scope: String) -> [SkillEntry]? {
        skillEntriesByScope[scope]
    }

    func submitComposer(gesture: ComposerSubmitGesture) {
        if gesture == .chord, canSteerQueue, composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, pendingAttaches.isEmpty {
            steerQueuedPrompts()
            return
        }
        sendCurrent(gesture: gesture)
    }

    func steerQueuedPrompts() {
        guard let prompts = chat?.queuedPrompts, !prompts.isEmpty else { return }
        for prompt in prompts where !prompt.sending {
            updateQueuedPrompt(itemId: prompt.id, action: .steer) { _ in }
        }
    }

    func openChatLink(_ url: URL) {
        guard isChatWebLink(url) else { return }
        switch chatLinkDestination(hostSettings.value(.linkOpening)?.str()) {
        case .newTab:
            UIApplication.shared.open(url)
        case .sidebar:
            pendingBrowserURL = url
            if case .panel(.browser) = currentRoute {
                return
            }
            push(.panel(.browser))
        }
    }

    func sendCurrent() {
        sendCurrent(gesture: .enter)
    }

    func sendCurrent(gesture: ComposerSubmitGesture) {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = pendingAttaches.compactMap { attach -> PromptImage? in
            guard attach.isImage, attach.status == .ready || attach.status == .pending else { return nil }
            return PromptImage(mediaType: attach.mediaType, data: attach.data.base64EncodedString(), name: attach.name)
        }
        let files = pendingAttaches.compactMap { attach -> PromptFile? in
            guard !attach.isImage, attach.status == .ready, let receipt = attach.receiptId else { return nil }
            return PromptFile(receiptId: receipt)
        }
        let draftFiles = pendingAttaches.filter { attach in
            !attach.isImage && attach.receiptId == nil
        }
        guard (!text.isEmpty || !images.isEmpty || !files.isEmpty || !draftFiles.isEmpty), let client else { return }
        if firstPrompt != nil { return }
        if chat == nil, landingComposerNeedsWorkspace(
            selectedWorkspaceId: draftWorkspaceId ?? workspaces.first?.workspaceId,
            workspaceCount: workspaces.count
        ) {
            presentToast(landingWorkspaceRequired(english: L.en))
            return
        }
        if !pendingAttaches.isEmpty, let name = slashCommandName(text) {
            let row = commandEntries.first { $0["name"].str() == name }
            if commandRefusesAttachments(name: name, catalogRow: row) {
                presentToast(commandAttachmentsUnsupportedNotice(command: name, english: L.en))
                return
            }
        }
        let queueAttachments: [QueuedAttachment] = pendingAttaches.compactMap { attach in
            if attach.isImage {
                return QueuedAttachment(
                    id: attach.id.uuidString,
                    kind: .image,
                    name: attach.name,
                    bytes: attach.data.count,
                    mediaType: attach.mediaType,
                    previewData: attach.data
                )
            }
            guard attach.status == .ready else { return nil }
            return QueuedAttachment(
                id: attach.id.uuidString,
                kind: .file,
                name: attach.name,
                bytes: attach.data.count
            )
        }
        composerText = ""
        pendingAttaches = []
        if let chat {
            Task {
                do {
                    try await sendPrompt(client, chat: chat, text: text, images: images, files: files, attachments: queueAttachments, gesture: gesture)
                } catch {
                    emit(error.localizedDescription)
                }
            }
            return
        }
        let first = FirstPrompt(
            requestId: UUID().uuidString,
            text: text,
            images: images.count,
            files: files.count + draftFiles.count
        )
        firstPrompt = first
        Task {
            await createSessionAndSend(
                client,
                first: first,
                text: text,
                images: images,
                files: files,
                attachments: queueAttachments,
                draftFiles: draftFiles,
                gesture: gesture
            )
        }
    }

    private func createSessionAndSend(
        _ client: PocketClient,
        first: FirstPrompt,
        text: String,
        images: [PromptImage],
        files: [PromptFile],
        attachments: [QueuedAttachment],
        draftFiles: [PendingAttach] = [],
        gesture: ComposerSubmitGesture
    ) async {
        func current() -> Bool { firstPrompt?.requestId == first.requestId }
        do {
            let chosen = pendingCreatorPreset ?? draftPreset.nilIfBlank
            let workspaceId = draftWorkspaceId ?? workspaces.first?.workspaceId
            let id = try await client.createSession(agentPreset: chosen, workspaceId: workspaceId)
            guard current() else { return }
            pendingCreatorPreset = nil
            firstPromptSessionId = id
            beginSession(id, seed: first)
            guard let chat, chat.sessionId == id else {
                throw PocketError(code: "session", message: L.t("未能打开新会话", "Could not open the new session"))
            }
            await applyDraftPermission(sessionId: id)
            await applyDraftModel(sessionId: id)
            guard current() else { return }
            var uploaded = files
            if landingAllowsDraftFileAttachments, !draftFiles.isEmpty {
                pendingAttaches.append(contentsOf: draftFiles)
                for attach in draftFiles {
                    await uploadAttach(attach.id)
                }
                let failed = pendingAttaches.contains { attach in
                    draftFiles.contains { $0.id == attach.id } && attach.status == .failed
                }
                uploaded = pendingAttaches.compactMap { attach in
                    guard !attach.isImage, attach.status == .ready, let receipt = attach.receiptId else { return nil }
                    return PromptFile(receiptId: receipt)
                }
                if failed {
                    pendingAttaches.removeAll { attach in
                        draftFiles.contains { $0.id == attach.id } && attach.status != .failed
                    }
                    if current() {
                        failFirstPrompt(nil)
                    }
                    return
                }
                pendingAttaches.removeAll { attach in draftFiles.contains { $0.id == attach.id } }
            }
            guard current(), let live = self.chat, live.sessionId == id else { return }
            try await sendPrompt(
                client,
                chat: live,
                text: text,
                images: images,
                files: uploaded,
                attachments: attachments,
                gesture: gesture,
                requestId: first.requestId
            )
            if current() {
                firstPrompt = nil
                firstPromptSessionId = nil
            }
        } catch {
            if current() {
                failFirstPrompt(error.localizedDescription)
            }
        }
    }

    private func clearFirstPrompt() {
        if let first = firstPrompt {
            reducer.discardEcho(first.requestId)
            if chat != nil { publishChat() }
        }
        firstPrompt = nil
        firstPromptSessionId = nil
    }

    private func failFirstPrompt(_ message: String?) {
        guard let first = firstPrompt else { return }
        composerText = first.text
        reducer.discardEcho(first.requestId)
        if chat != nil { publishChat() }
        firstPrompt = nil
        firstPromptSessionId = nil
        if let message { emit(message) }
    }

    func stopRun() {
        Task {
            guard let client, let id = chat?.sessionId else { return }
            do { _ = try await client.cancel(sessionId: id) }
            catch { emit(error.localizedDescription) }
        }
    }

    func answer(_ approval: Approval, outcome: String, onResult: @escaping (Bool) -> Void = { _ in }) {
        Task {
            guard let client else {
                onResult(false)
                return
            }
            do {
                let result = try await client.answerApproval(approvalId: approval.approvalId, outcome: outcome)
                guard result["accepted"].bool() == true else {
                    throw PocketError(code: "rejected", message: L.t("审批未被远程主机接受", "The approval was not accepted by the remote host"))
                }
                approvals.removeAll { $0.approvalId == approval.approvalId }
                onResult(true)
            } catch {
                emit(error.localizedDescription)
                onResult(false)
            }
        }
    }

    func loadOlderHistory() {
        Task {
            guard var state = chat, let client else { return }
            if !HistoryPagingPolicy.canLoadOlder(hasMore: state.hasMore, loadingOlder: state.loadingOlder, firstSeq: state.firstSeq) {
                return
            }
            let epoch = followEpoch
            let target = reducer
            state.loadingOlder = true
            chat = state
            do {
                let req = HistoryPagingPolicy.pageRequest(cursor: reducer.cursor, firstSeq: state.firstSeq)
                let page = try await client.historyPage(
                    sessionId: state.sessionId,
                    throughSeq: req.throughSeq,
                    beforeSeq: req.beforeSeq,
                    maxMessages: req.maxMessages
                )
                guard followEpoch == epoch, reducer === target else { return }
                _ = reducer.prepend(records: page["records"], pageHasMore: page["hasMore"].bool() ?? false)
                inspectorLog.prepend(page["records"])
                publishChat()
                chat?.loadingOlder = false
            } catch {
                if followEpoch != epoch { return }
                if SessionNotFoundPolicy.matches(error) {
                    absorbMissingSession(state.sessionId)
                    return
                }
                emit(error.localizedDescription)
                chat?.loadingOlder = false
            }
        }
    }

    func pin(_ session: SessionSummary) {
        Task {
            guard let client else { return }
            do {
                if pinnedIds.contains(session.sessionId) {
                    try await client.unpinSession(session.sessionId)
                } else {
                    try await client.pinSession(session.sessionId)
                }
            } catch { emit(error.localizedDescription) }
        }
    }

    func archive(_ session: SessionSummary, stopActivity: Bool = false) {
        Task {
            guard let client else { return }
            do {
                try await client.archiveSession(session.sessionId, stopActivity: stopActivity)
                lastArchivedId = session.sessionId
                archiveConfirm = nil
                if let state = try? await client.call("workspace.state") { applyWorkspaceState(state) }
                presentToast(L.archivedToast(stopped: stopActivity), undoArchive: session.sessionId)
            } catch {
                if !stopActivity,
                   let pocket = error as? PocketError,
                   pocket.code == "workspace/session-active",
                   archiveSessionActiveOpensConfirm {
                    archiveConfirm = ArchiveConfirmRequest(session: session, details: pocket.details)
                } else {
                    emit(error.localizedDescription)
                }
            }
        }
    }

    func undoLastArchive() {
        guard let id = toastUndoArchiveId else { return }
        toastUndoArchiveId = nil
        toast = nil
        unarchive(id)
    }

    func unarchive(_ sessionId: String, thenOpen: Bool = false, onResult: ((Bool) -> Void)? = nil) {
        Task {
            guard let client else {
                onResult?(false)
                return
            }
            guard ops.contains("workspace.unarchiveSession") else {
                emit(L.t("远程主机未提供取消归档", "This remote host cannot unarchive sessions"))
                onResult?(false)
                return
            }
            do {
                _ = try await client.unarchiveSession(sessionId)
                if let state = try? await client.call("workspace.state") { applyWorkspaceState(state) }
                if thenOpen { openSession(sessionId) }
                onResult?(true)
            } catch {
                emit(error.localizedDescription)
                onResult?(false)
            }
        }
    }

    func isArchived(_ sessionId: String) -> Bool {
        archivedIds.contains(sessionId) || sessions.first { $0.sessionId == sessionId }?.archived == true
    }

    func rename(_ sessionId: String, title: String) {
        Task {
            guard let client, !title.isEmpty else { return }
            do { try await client.renameSession(sessionId: sessionId, title: title) }
            catch { emit(error.localizedDescription) }
        }
    }

    func fork(_ session: SessionSummary) {
        forkSession(sessionId: session.sessionId, atSeq: nil)
    }

    func forkCurrent(atSeq: Int64?) {
        guard let sessionId = chat?.sessionId else { return }
        forkSession(sessionId: sessionId, atSeq: atSeq)
    }

    func forkSession(sessionId: String, atSeq: Int64?) {
        Task {
            guard let client else { return }
            do {
                let sourceTitle = sessions.first { $0.sessionId == sessionId }?.title
                let result = try await client.forkSession(sessionId: sessionId, atSeq: atSeq)
                guard let id = result["sessionId"].str() else { return }
                if let childTitle = forkChildTitle(sourcePersistedTitle: sourceTitle) {
                    try await client.renameSession(sessionId: id, title: childTitle)
                }
                openSession(id)
            } catch { emit(error.localizedDescription) }
        }
    }

    func setMessageFeedback(
        messageId: String,
        rating: String?,
        category: String? = nil,
        note: String? = nil,
        onResult: ((Bool) -> Void)? = nil
    ) {
        Task {
            guard let client, let sessionId = chat?.sessionId else {
                onResult?(false)
                return
            }
            let previous = feedback[messageId]
            do {
                let result = try await client.setFeedback(
                    sessionId: sessionId,
                    messageId: messageId,
                    rating: rating,
                    category: rating == nil ? nil : category,
                    note: rating == nil ? nil : note,
                    ifVersion: previous?.version
                )
                if rating == nil {
                    feedback.removeValue(forKey: messageId)
                    onResult?(true)
                } else if let next = MessageFeedback.parse(result) {
                    feedback[messageId] = next
                    presentToast(L.thanksFeedback())
                    onResult?(true)
                } else {
                    emit(PocketError(code: "bad-reply", message: "远程主机未返回已保存的反馈").localizedDescription)
                    onResult?(false)
                }
            } catch {
                emit(error.localizedDescription)
                onResult?(false)
            }
        }
    }

    func selectModel(_ info: ModelInfo, effort: String?, onComplete: ((Bool) -> Void)? = nil) {
        selectModel(
            ModelChoice(provider: info.provider, model: info.id, name: info.name, effort: effort),
            onComplete: onComplete
        )
    }

    func selectModel(_ choice: ModelChoice, onComplete: ((Bool) -> Void)? = nil) {
        if uiTestFixture {
            guard modelPending == nil else {
                onComplete?(false)
                return
            }
            modelChoice = choice
            draftModel = choice
            onComplete?(true)
            return
        }
        Task {
            guard modelPending == nil else {
                onComplete?(false)
                return
            }
            guard let sessionId = chat?.sessionId else {
                guard client != nil else {
                    onComplete?(false)
                    return
                }
                modelChoice = choice
                draftModel = choice
                onComplete?(true)
                return
            }
            guard let client else {
                onComplete?(false)
                return
            }
            modelPending = choice
            do {
                let response = try await client.selectModel(
                    sessionId: sessionId,
                    provider: choice.provider,
                    model: choice.model,
                    effort: choice.effort
                )
                if let selected = modelChoice(from: response["selected"]) {
                    modelChoice = selected
                } else {
                    modelChoice = choice
                }
                onComplete?(true)
            } catch {
                emit(error.localizedDescription)
                onComplete?(false)
            }
            if modelPending == choice { modelPending = nil }
        }
    }

    private func applyDraftPermission(sessionId: String) async {
        guard let pending = draftPermission, chat?.sessionId == sessionId else { return }
        draftPermission = nil
        permissionHydrationGeneration += 1
        guard let client, ops.contains("permissions.set") else { return }
        guard permissionCatalog?.options.contains(where: { $0.value == pending }) == true else { return }
        if let selected = try? await client.setPermission(sessionId: sessionId, name: pending) {
            sessionPermission = selected
        }
    }

    private func applyDraftModel(sessionId: String) async {
        guard let pending = draftModel, chat?.sessionId == sessionId else { return }
        draftModel = nil
        guard let client else { return }
        do {
            let response = try await client.selectModel(
                sessionId: sessionId,
                provider: pending.provider,
                model: pending.model,
                effort: pending.effort
            )
            if let selected = modelChoice(from: response["selected"]) {
                modelChoice = selected
            } else {
                modelChoice = pending
            }
        } catch {
            emit(error.localizedDescription)
        }
    }

    func setPermission(_ name: String, onComplete: ((Bool) -> Void)? = nil) {
        Task {
            guard chat?.sessionId != nil else {
                draftPermission = name
                onComplete?(true)
                return
            }
            guard let client, let sessionId = chat?.sessionId, !permissionChanging, !permissionCatalogLoading else {
                onComplete?(false)
                return
            }
            guard ops.contains("permissions.set") else {
                emit(L.t("远程主机不支持切换权限", "This remote host cannot change permissions"))
                onComplete?(false)
                return
            }
            guard permissionCatalog?.options.contains(where: { $0.value == name }) == true else {
                emit(L.t("权限目录已变化，请重新选择访问模式", "The permission catalog changed. Choose an access mode again."))
                onComplete?(false)
                return
            }
            permissionChanging = true
            do {
                let selected = try await client.setPermission(sessionId: sessionId, name: name)
                sessionPermission = selected
                if selected != name {
                    emit(L.t("远程主机未应用所选权限，当前模式为 \(selected)", "The remote host did not apply the selected permission. Current mode is \(selected)"))
                }
                onComplete?(selected == name)
            } catch {
                emit(error.localizedDescription)
                onComplete?(false)
            }
            permissionChanging = false
        }
    }

    func updateQueuedPrompt(itemId: String, action: QueueAction, onComplete: @escaping (Bool) -> Void) {
        Task {
            guard let client, let sessionId = chat?.sessionId else {
                onComplete(false)
                return
            }
            do {
                guard isOnline else { throw PocketError(code: "transport", message: L.t("未连接到远程主机", "Not connected to the remote host")) }
                guard ops.contains("queue.update") else {
                    throw PocketError(code: "unsupported", message: L.t("远程主机不支持修改排队消息", "This remote host cannot edit queued messages"))
                }
                guard let row = reducer.queueMessages().first(where: { $0.id == itemId }) else {
                    throw PocketError(code: "session/queue-item-not-found", message: L.t("排队消息已变化", "Queued message changed"))
                }
                if row.sending { throw PocketError(code: "busy", message: L.t("消息仍在发送中", "The message is still sending")) }
                switch action {
                case .edit(let text):
                    if !row.editable {
                        throw PocketError(code: "invalid", message: L.t("含附件的排队消息不能编辑", "Queued messages with attachments cannot be edited"))
                    }
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw PocketError(code: "invalid", message: L.t("消息不能为空", "Message cannot be empty"))
                    }
                case .steer:
                    if chat?.running != true {
                        throw PocketError(code: "invalid", message: L.t("当前没有运行中的轮次", "There is no running turn"))
                    }
                case .remove:
                    break
                }
                _ = try await client.updateQueuedPrompt(sessionId: sessionId, itemId: itemId, action: action)
                onComplete(true)
            } catch {
                let converged: Bool
                if case .steer = action, let pocket = error as? PocketError,
                   pocket.code == "session/steer-unavailable" || pocket.code == "session/queue-item-not-found" {
                    converged = true
                } else {
                    converged = false
                }
                if !converged { emit(error.localizedDescription) }
                onComplete(converged)
            }
        }
    }

    func executeCommand(_ line: String, onResult: ((Bool) -> Void)? = nil) {
        Task {
            guard let client else {
                onResult?(false)
                return
            }
            var sessionId = chat?.sessionId
            if sessionId == nil {
                do {
                    let created = try await client.createSession(
                        agentPreset: pendingCreatorPreset ?? draftPreset.nilIfBlank,
                        workspaceId: draftWorkspaceId ?? workspaces.first?.workspaceId
                    )
                    pendingCreatorPreset = nil
                    openSession(created)
                    sessionId = created
                    await applyDraftPermission(sessionId: created)
                    await applyDraftModel(sessionId: created)
                } catch {
                    emit(error.localizedDescription)
                    onResult?(false)
                    return
                }
            }
            guard let sessionId else {
                onResult?(false)
                return
            }
            do {
                let result = try await client.executeCommand(sessionId: sessionId, line: line)
                if result["result"]["kind"].str() == "error" {
                    emit(result["result"]["text"].str() ?? L.t("指令失败", "Command failed"))
                    onResult?(false)
                } else {
                    if let text = result["result"]["text"].str(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        presentToast(text)
                    }
                    onResult?(true)
                }
            } catch {
                emit(error.localizedDescription)
                onResult?(false)
            }
        }
    }

    func commandCatalog(sessionId: String?) async throws -> [JSONValue] {
        if uiTestFixture { return commandEntries }
        guard let client else { throw PocketError(code: "transport", message: L.t("未连接", "Not connected")) }
        let entries = try await client.listCommands(sessionId: sessionId)
        if sessionId == nil || chat?.sessionId == sessionId { commandEntries = entries }
        return entries
    }

    func skillCatalog(sessionId: String?) async throws -> [SkillEntry] {
        guard ops.contains("skills.list") else { return [] }
        guard let client else { throw PocketError(code: "transport", message: L.t("未连接", "Not connected")) }
        let raw = try await client.listSkills(sessionId: sessionId)
        let entries = raw.compactMap(SkillEntry.parse)
        let scope = skillCatalogScopeKey(
            sessionId: sessionId,
            subagent: sessions.first { $0.sessionId == sessionId }?.origin == "subagent"
        )
        #if DEBUG
        print("[dsh.skills] scope=\(scope) raw=\(raw.count) parsed=\(entries.count)")
        #endif
        skillEntriesByScope[scope] = entries
        if chat?.sessionId == sessionId {
            skillEntries = entries
        } else if sessionId == nil, chat == nil {
            skillEntries = entries
        }
        return entries
    }

    func attachImage(name: String, mediaType: String, data: Data) {
        pendingAttaches.append(PendingAttach(
            name: name,
            isImage: true,
            mediaType: mediaType,
            data: data,
            receiptId: nil,
            status: .ready
        ))
    }

    func attachFile(name: String, mediaType: String, data: Data) {
        let attach = PendingAttach(
            name: name,
            isImage: false,
            mediaType: mediaType,
            data: data,
            receiptId: nil,
            status: chat?.sessionId == nil ? .ready : .uploading
        )
        pendingAttaches.append(attach)
        if chat?.sessionId != nil {
            Task { await uploadAttach(attach.id) }
        }
    }

    func retryAttach(_ id: UUID) {
        Task { await uploadAttach(id) }
    }

    func removeAttach(_ id: UUID) {
        pendingAttaches.removeAll { $0.id == id }
    }

    func answerUserQuestion(callId: String, answers: [JSONValue], onResult: @escaping (Bool) -> Void) {
        Task {
            guard let client, let sessionId = chat?.sessionId else {
                onResult(false)
                return
            }
            do {
                let result = try await client.answerUserQuestion(sessionId: sessionId, callId: callId, answers: answers)
                guard result["accepted"].bool() == true else {
                    throw PocketError(code: "rejected", message: L.t("提问已变化或答案未被接受", "The question changed or the answers were not accepted"))
                }
                if self.client === client {
                    questionStore.submitted(sessionId: sessionId, callId: callId)
                    if hiddenQuestionId == callId { hiddenQuestionId = nil }
                    publishUserQuestions()
                }
                onResult(true)
            } catch {
                emit(error.localizedDescription)
                onResult(false)
            }
        }
    }

    func refreshGoal() {
        Task {
            guard let client, let sessionId = chat?.sessionId, ops.contains("goals.get") else { return }
            let epoch = goalActivationEpoch
            do {
                let result = try await client.getGoal(sessionId: sessionId)
                if chat?.sessionId == sessionId && goalActivationEpoch == epoch {
                    goalActivation = result["goal"]["activation"].str()
                    chat?.goal = result["goal"].isNull ? nil : result["goal"]
                }
            } catch {
                if SessionNotFoundPolicy.matches(error) {
                    if chat?.sessionId == sessionId { absorbMissingSession(sessionId) }
                    return
                }
                if chat?.sessionId == sessionId && goalActivationEpoch == epoch {
                    emit(error.localizedDescription)
                }
            }
        }
    }

    func mutateGoal(action: String, objective: String?, onComplete: @escaping (Bool) -> Void) {
        Task {
            guard let client, let sessionId = chat?.sessionId, let goal = chat?.goal else {
                onComplete(false)
                return
            }
            guard ops.contains("goals.\(action)") else {
                emit(L.t("远程主机不支持目标操作", "This remote host cannot change goals"))
                onComplete(false)
                return
            }
            let epoch = goalActivationEpoch
            let ref = jsonObject(["id": goal["id"], "revision": goal["revision"]])
            do {
                let response = try await client.mutateGoal(sessionId: sessionId, action: action, ref: ref, objective: objective)
                if chat?.sessionId == sessionId && goalActivationEpoch == epoch {
                    goalActivation = response["goal"]["activation"].str()
                    chat?.goal = response["goal"].isNull ? nil : response["goal"]
                }
                onComplete(true)
            } catch {
                emit(error.localizedDescription)
                onComplete(false)
            }
        }
    }

    func insertComposer(_ token: String) {
        let next = replaceComposerToken(composerText, cursor: composerText.count, token: token)
        composerText = next.text
        mentionQuery = nil
    }

    func consumeComposerSlash() {
        let next = replaceComposerToken(composerText, cursor: composerText.count, token: "")
        composerText = next.text
    }

    func reloadModelCatalog() {
        Task {
            guard let client else { return }
            catalogLoading = true
            do {
                applyCatalog(try await client.modelCatalog())
                catalogError = nil
            } catch {
                catalogError = error.localizedDescription
            }
            catalogLoading = false
        }
    }

    func fetchMentions(query: String) {
        Task {
            guard let client, let sessionId = chat?.sessionId else { return }
            let canFiles = ops.contains("references.files")
            let canSessions = ops.contains("references.sessions")
            if !canFiles { fileMentions = [] }
            if !canSessions { sessionMentions = [] }
            if canFiles {
                do {
                    let fileResult = try await client.referenceFiles(sessionId: sessionId, query: query)
                    fileMentions = (fileResult["items"].arr() ?? []).compactMap(FileReference.parse)
                } catch {
                    fileMentions = []
                }
            }
            if canSessions {
                do {
                    let sessionResult = try await client.referenceSessions(sessionId: sessionId, query: query)
                    sessionMentions = (sessionResult["items"].arr() ?? []).compactMap(SessionReference.parse)
                } catch {
                    sessionMentions = []
                }
            }
        }
    }

    func recordSessionFeedback(category: String?, note: String, onResult: @escaping (Bool) -> Void) {
        Task {
            guard let client, let sessionId = chat?.sessionId else {
                onResult(false)
                return
            }
            do {
                let receipt = try await client.recordSessionFeedback(sessionId: sessionId, category: category, note: note)
                try SessionFeedbackRequest.recorded(receipt)
                presentToast(L.thanksFeedback())
                onResult(true)
            } catch {
                emit(error.localizedDescription)
                onResult(false)
            }
        }
    }

    func searchSessions(_ query: String) {
        searchGeneration += 1
        let generation = searchGeneration
        if !SessionSearch.shouldSearchHost(query: query, ops: ops) {
            searchHits = []
            searchHostHasMore = false
            searching = false
            return
        }
        searching = true
        Task {
            try? await Task.sleep(nanoseconds: UInt64(SessionSearch.debounceMs) * 1_000_000)
            guard searchGeneration == generation else { return }
            do {
                guard let client else { throw PocketError(code: "transport", message: L.t("未连接到远程主机", "Not connected to the remote host")) }
                let parsed = SessionSearch.parse(try await client.searchSessions(query: query))
                guard searchGeneration == generation else { return }
                searchHits = parsed.items
                searchHostHasMore = parsed.hasMore
            } catch {
                guard searchGeneration == generation else { return }
                // Desktop: failed content search leaves local metadata matches
                // visible, without an extra warning.
                searchHits = []
                searchHostHasMore = false
            }
            if searchGeneration == generation { searching = false }
        }
    }

    func clearSessionSearch() {
        searchGeneration += 1
        searchHits = []
        searchHostHasMore = false
        searching = false
    }

    func loadAttachmentBytes(sessionId: String, attachmentId: String) async -> Data? {
        if let cached = attachmentCache[attachmentId] { return cached }
        guard let client, ops.contains("session.attachment") else { return nil }
        do {
            let result = try await client.sessionAttachment(sessionId: sessionId, attachmentId: attachmentId)
            guard let data = SessionAttachment.decodeBytes(result) else { return nil }
            attachmentCache[attachmentId] = data
            return data
        } catch {
            return nil
        }
    }

    func moveWorkspace(id: String, beforeId: String?) {
        Task {
            guard let client, ops.contains("workspace.insertBefore") else { return }
            do {
                _ = try await client.insertWorkspaceBefore(workspaceId: id, beforeWorkspaceId: beforeId)
                if let state = try? await client.call("workspace.state") { applyWorkspaceState(state) }
            } catch { emit(error.localizedDescription) }
        }
    }

    func moveWorkspaceSession(workspaceId: String, sessionId: String, beforeSessionId: String?) {
        Task {
            guard let client, ops.contains("workspace.insertSessionBefore") else { return }
            do {
                _ = try await client.insertSessionBefore(
                    workspaceId: workspaceId,
                    sessionId: sessionId,
                    beforeSessionId: beforeSessionId
                )
                if let state = try? await client.call("workspace.state") { applyWorkspaceState(state) }
            } catch { emit(error.localizedDescription) }
        }
    }

    func persistManualOrder(_ order: [String]) {
        guard let id = activeId else { return }
        AppPrefs.setManualSessionOrder(hostId: id, value: order)
    }

    func manualOrder() -> [String] {
        guard let id = activeId else { return [] }
        return AppPrefs.manualSessionOrder(hostId: id)
    }

    func readPresetRoster() async throws -> JSONValue {
        guard let client else { throw PocketError(code: "transport", message: L.unavailable()) }
        if ops.contains("presets.settings") { return try await client.presetsSettings() }
        guard ops.contains("presets.list") else { throw PocketError(code: "unsupported", message: L.unavailable()) }
        let roster = try await client.presetsList()
        return .object([
            "presets": roster["presets"],
            "writable": .bool(false),
        ])
    }

    func readPresetContent(id: String) async throws -> String {
        guard let client else { throw PocketError(code: "transport", message: L.unavailable()) }
        guard let content = try await client.readPreset(id: id)["content"].str() else {
            throw PocketError(code: "bad-reply", message: L.hostDidNotReturnPreset())
        }
        return content
    }

    func onNetworkRestored() {
        wakeReconnect()
    }

    func onBecameActive() {
        if uiTestFixture { return }
        refreshPairedStatus()
        resumeTask?.cancel()
        resumeTask = Task { await resumeForegroundSession() }
        Task { await refreshSessionRoster() }
    }

    func refreshSessionsWhenVisible() {
        if uiTestFixture { return }
        Task { await refreshSessionRoster() }
    }

    func onEnteredBackground() {
        resumeTask?.cancel()
        resumeTask = nil
    }

    func wakeReconnect() {
        guard let id = activeId else { return }
        let socketOpen = client?.state == .open
        let work = BackgroundKeepAlivePolicy.resumeWork(
            dot: status[id].map(ConnectionDot.init(dot:)),
            socketOpen: socketOpen
        )
        guard work == .reconnect else { return }
        restoreGeneration += 1
        let generation = restoreGeneration
        backoffMs = ReconnectBackoffPolicy.reset()
        reconnectWake = true
        if status[id] == .connecting || !socketOpen, restoreGeneration == generation {
            client?.close()
        }
    }

    func noteKeepAliveFailed() {
        client?.close()
        wakeReconnect()
    }

    func pingLiveSocket() async -> BackgroundKeepAlivePolicy.PingResult {
        guard let client, client.state == .open else { return .skipped }
        do {
            try await client.ping()
            return .ok
        } catch {
            return .failed
        }
    }

    func performBackgroundRefresh() async -> Bool {
        guard let id = activeId else { return true }
        let work = BackgroundKeepAlivePolicy.resumeWork(
            dot: status[id].map(ConnectionDot.init(dot:)),
            socketOpen: client?.state == .open
        )
        switch work {
        case .none:
            return true
        case .reconnect:
            wakeReconnect()
            return await waitUntilSocketOpen()
        case .refreshLive:
            switch await pingLiveSocket() {
            case .ok:
                await refreshLiveSessionState()
                return true
            case .skipped, .failed:
                noteKeepAliveFailed()
                return await waitUntilSocketOpen()
            }
        }
    }

    func refreshPairedStatus() {
        probeTask?.cancel()
        probeTask = Task { await probePairedDevices() }
    }

    func identity(of profile: Profile) -> PairedDeviceIdentity {
        PairedDeviceIdentity(
            id: profile.id,
            host: profile.host,
            port: profile.port,
            instanceId: profile.instanceId,
            deviceId: profile.deviceId,
            needsRepair: profile.needsRepair
        )
    }

    func exportSession() {
        Task {
            guard let client, let sessionId = chat?.sessionId else {
                emit(L.t("无会话", "No session"))
                return
            }
            guard ops.contains("session.export") else {
                emit(L.t("远程主机未提供导出", "This remote host cannot export sessions"))
                return
            }
            do {
                let result = try await client.exportSession(sessionId: sessionId)
                let name = result["filename"].str() ?? "dsh-session.zip"
                guard let encoded = result["data"].str(), let data = Data(base64Encoded: encoded) else {
                    throw PocketError(code: "invalid-response", message: "empty export")
                }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                exportShare = ExportShare(url: url)
            } catch {
                emit(error.localizedDescription)
            }
        }
    }

    func call(_ op: String, args: JSONValue = .object([:])) async throws -> JSONValue {
        guard let client else { throw PocketError(code: "transport", message: "not connected") }
        return try await client.call(op, args: args)
    }

    func clientOrNull() -> PocketClient? { client }

    var transcriptView: TranscriptView {
        transcriptViewFromHost(hostSettings.value(.transcript)?.str())
    }

    var performanceUsage: PerformanceUsage {
        hostSettings.value(.performance)?.str() == "detailed" ? .detailed : .compact
    }

    var showCodeWorkView: Bool {
        hostSettings.value(.codeWork)?.bool() ?? true
    }

    var defaultPermission: String {
        hostSettings.value(.permission)?.str() ?? "workspace-write"
    }

    func copyDiagnostics() async -> String? {
        guard let profile = activeProfile, !profile.needsRepair else { return nil }
        guard let url = URL(string: "http://\(profile.host):\(profile.port)/diagnostics") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw PocketError(code: "diagnostics", message: L.diagnosticsUnavailable())
            }
            let text = String(data: data, encoding: .utf8) ?? ""
            UIPasteboard.general.string = text
            presentToast(L.diagnosticsCopied())
            return text
        } catch {
            emit(error.localizedDescription)
            return nil
        }
    }

    func handleIncomingURL(_ url: URL) {
        if let link = PairingUriPolicy.parse(url.absoluteString) {
            push(.pair)
            pendingPair = link
        }
    }

    @Published var pendingPair: PairingLink?

    func setLanguage(_ value: AppLanguage) {
        language = value
        AppPrefs.language = value
        TrajL.en = value == .en
        hostSettings.write(.language, value: .string(value == .en ? "en" : "zh"))
    }

    func applyHostMirroredPrefs() {
        if let hosted = hostSettings.value(.busySend)?.str(), let parsed = BusySend(rawValue: hosted) {
            busySend = parsed
        }
        collapseTiming = collapseTimingFromHost(hostSettings.value(.collapse)?.str())
        if let zh = controllerLanguageIsZh(
            hostedPreference: hostSettings.value(.language)?.str(),
            hostReady: hostSettings.ready,
            systemIsZh: Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true
        ) {
            language = zh ? .zh : .en
        }
        AppPrefs.language = language
        TrajL.en = language == .en
    }

    func setSessionGroupBy(_ value: SessionGroupBy) {
        sessionGroupBy = value
        AppPrefs.sessionGroupBy = value
    }

    func setSessionOrderBy(_ value: SessionOrderBy) {
        sessionOrderBy = value
        AppPrefs.sessionOrderBy = value
    }

    func setArchivedFilter(_ value: ArchivedFilter) {
        archivedFilter = value
        AppPrefs.archivedFilter = value
    }

    func toggleWorkspaceCollapsed(_ key: String) {
        if collapsedWorkspaces.contains(key) { collapsedWorkspaces.remove(key) }
        else { collapsedWorkspaces.insert(key) }
        if let id = activeId { AppPrefs.setCollapsedWorkspaces(hostId: id, value: collapsedWorkspaces) }
    }

    func openFilePreview(path: String) {
        guard let sessionId = chat?.sessionId else { return }
        filePreview = FilePreviewRef(sessionId: sessionId, path: path)
        if case .panel(.files) = currentRoute { return }
        push(.panel(.files))
    }

    func createWorkspace(path: String) async throws -> WorkspaceView {
        guard let client else { throw PocketError(code: "transport", message: "未连接") }
        let result = try await client.createWorkspace(path: path)
        guard let workspace = WorkspaceView.parse(result["workspace"]) else {
            throw PocketError(code: "bad-reply", message: "missing workspace")
        }
        if let state = try? await client.call("workspace.state") {
            applyWorkspaceState(state)
        }
        return workspace
    }

    func renameWorkspace(id: String, title: String) {
        Task {
            guard let client else { return }
            do {
                _ = try await client.renameWorkspace(workspaceId: id, title: title)
                if let state = try? await client.call("workspace.state") { applyWorkspaceState(state) }
            } catch { emit(error.localizedDescription) }
        }
    }

    func deleteWorkspace(id: String) {
        Task {
            guard let client else { return }
            do {
                _ = try await client.deleteWorkspace(workspaceId: id)
                if let state = try? await client.call("workspace.state") { applyWorkspaceState(state) }
            } catch { emit(error.localizedDescription) }
        }
    }

    func listWorkspaceDirectories(path: String?) async throws -> WorkspaceDirectoryLevel {
        guard let client else { throw PocketError(code: "transport", message: "未连接") }
        return try WorkspaceDirectoryLevel.parse(try await client.directoryList(path: path))
    }

    func createWorkspaceDirectory(path: String, name: String) async throws -> String {
        guard let client else { throw PocketError(code: "transport", message: "未连接") }
        let result = try await client.directoryCreate(path: path, name: name)
        guard let created = result.str() else {
            throw PocketError(code: "bad-reply", message: "missing directory path")
        }
        return created
    }

    func listFiles(sessionId: String, path: String) async throws -> JSONValue {
        guard let client else { throw PocketError(code: "transport", message: "未连接") }
        return try await client.listFiles(sessionId: sessionId, path: path)
    }

    func readFile(sessionId: String, path: String, offset: Int? = nil, limit: Int? = nil) async throws -> JSONValue {
        guard let client else { throw PocketError(code: "transport", message: "未连接") }
        return try await client.readFile(sessionId: sessionId, path: path, offset: offset, limit: limit)
    }

    func readFileBytes(sessionId: String, path: String, offset: Int? = nil, length: Int? = nil) async throws -> JSONValue {
        guard let client else { throw PocketError(code: "transport", message: "未连接") }
        return try await client.readFileBytes(sessionId: sessionId, path: path, offset: offset, length: length)
    }

    func readAllText(sessionId: String, path: String) async throws -> String {
        var out = ""
        var offset = 1
        var version: String?
        while true {
            let result = try await readFile(sessionId: sessionId, path: path, offset: offset, limit: 200)
            let pageVersion = result["version"].str()
            if offset == 1 { version = pageVersion }
            else if pageVersion != version {
                throw PocketError(code: "preview", message: L.fileChangedWhileReading())
            }
            let chunk = result["text"].str() ?? ""
            let lines = result["lines"].int() ?? 0
            if chunk.contains("\0") {
                throw PocketError(code: "preview", message: L.binaryNoTextPreview())
            }
            if out.utf8.count + chunk.utf8.count > 4_000_000 {
                throw PocketError(code: "preview", message: L.fileTooLarge())
            }
            if lines > 0 {
                if offset > 1 { out.append("\n") }
                out.append(chunk)
            }
            if result["eof"].bool() != false { break }
            if lines <= 0 { throw PocketError(code: "bad-reply", message: "File response did not advance") }
            offset += lines
        }
        return out
    }

    func fetchChangesSummary(sessionId: String, seq: Int64) async throws -> WorkspaceChangesSummary? {
        let hasOp = ops.contains("workspaceChanges.summary")
        guard hasOp else {
            logChanges("skip fetch op missing session=\(sessionId) seq=\(seq)")
            return nil
        }
        guard let client else { throw PocketError(code: "transport", message: "not connected") }
        let result = try await client.workspaceChangesSummary(sessionId: sessionId, seq: seq)
        let parsed = WorkspaceChangesSummary.parsePocketResult(result)
        logChanges(
            "summary session=\(sessionId) seq=\(seq) parsed=\(parsed != nil) files=\(parsed.map { String($0.files.count) } ?? "nil") raw=\(result)"
        )
        return parsed
    }

    func fetchChangesDiff(sessionId: String, seq: Int64, index: Int) async throws -> WorkspaceFileDiff? {
        guard ops.contains("workspaceChanges.diff") else { return nil }
        guard let client else { throw PocketError(code: "transport", message: "not connected") }
        return WorkspaceFileDiff.parse(try await client.workspaceChangesDiff(sessionId: sessionId, seq: seq, index: index)["diff"])
    }

    var canShowTerminal: Bool {
        ops.contains("terminal.create") && ops.contains("terminal.follow")
    }

    var canShowFiles: Bool { ops.contains("files.list") }

    var canShowJobs: Bool { isOnline && ops.contains("jobs.list") }

    /// Chip and panel each retain the same poll loop. Leaving the last retainer unfollows but keeps the roster.
    func retainJobsWatch(hostId: String?, sessionId: String, available: Bool) async {
        guard available, let hostId else { return }
        let token = attachJobsWatch(hostId: hostId, sessionId: sessionId)
        defer { detachJobsWatch(token) }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_600_000_000_000)
        }
    }

    func refreshJobs() {
        jobsPanelKillError = false
        Task { await refreshJobsOnce(clearKillError: true) }
    }

    func selectJob(_ job: JobRow) {
        selectedJobId = job.id
        jobFollowEnded.remove(job.id)
        jobDetail = JobDetailState(jobId: job.id, status: job.status, output: [], error: nil)
        Task {
            guard let client else { return }
            if let sub = jobFollows.removeValue(forKey: job.id) {
                try? await client.unfollow(sub)
            }
            await runJobReconcile()
        }
    }

    func clearJobSelection() {
        selectedJobId = nil
        jobDetail = nil
        Task { await runJobReconcile() }
    }

    func retryJobFollow() {
        guard let jobId = selectedJobId else { return }
        let status = jobDetail?.status ?? jobs?.first { $0.id == jobId }?.status ?? ""
        jobDetail = JobDetailState(jobId: jobId, status: status, output: [], error: nil)
        jobFollowEnded.remove(jobId)
        Task {
            guard let client else { return }
            if let sub = jobFollows.removeValue(forKey: jobId) {
                try? await client.unfollow(sub)
            }
            await runJobReconcile()
        }
    }

    func killJob(jobId: String, onResult: @escaping (Bool) -> Void) {
        Task {
            guard let client, let sessionId = jobsWatchSessionId ?? chat?.sessionId else {
                onResult(false)
                return
            }
            do {
                _ = try await client.killJob(sessionId: sessionId, jobId: jobId)
                let next = parseJobRoster(try await client.listJobs(sessionId: sessionId))
                jobs = next
                jobsFailed = false
                jobsPanelKillError = false
                jobsPanelError = nil
                if let updated = next.first(where: { $0.id == jobId }), selectedJobId == jobId {
                    jobDetail?.status = updated.status
                }
                await runJobReconcile()
                onResult(true)
            } catch is CancellationError {
                onResult(false)
            } catch {
                jobsPanelKillError = true
                jobsPanelError = jobKillFailedLabel(english: L.en)
                onResult(false)
            }
        }
    }

    /// Foreground ChatView only. Background, drawer, or any other route must pass null.
    func setViewedSession(_ sessionId: String?) {
        desiredViewedSession = sessionId
        if let client {
            Task { await syncCompletionView(client) }
        }
    }

    func openTerminal(sessionId: String, forceNew: Bool = false, terminalId: String? = nil) {
        terminalAttachTask?.cancel()
        terminalAttachTask = Task { await attachTerminal(sessionId: sessionId, forceNew: forceNew, terminalId: terminalId) }
    }

    func writeTerminal(_ data: String) {
        Task {
            guard let client, let meta = terminalMeta else { return }
            do {
                _ = try await client.writeTerminal(sessionId: meta.sessionId, id: meta.id, attachmentId: meta.attachmentId, data: data)
            } catch { emit(error.localizedDescription) }
        }
    }

    func resizeTerminal(cols: Int, rows: Int) {
        terminalWantCols = max(cols, 2)
        terminalWantRows = max(rows, 1)
        if terminal.cols != terminalWantCols || terminal.rows != terminalWantRows {
            terminal.resize(newCols: terminalWantCols, newRows: terminalWantRows)
            terminalRevision = terminal.revision
        }
        Task {
            guard let client, let meta = terminalMeta else { return }
            do {
                _ = try await client.resizeTerminal(
                    sessionId: meta.sessionId, id: meta.id, attachmentId: meta.attachmentId,
                    cols: terminalWantCols, rows: terminalWantRows
                )
            } catch { emit(error.localizedDescription) }
        }
    }

    func closeTerminalFollow() {
        let client = self.client
        let old = terminalSubId
        terminalSubId = nil
        resetTerminalAttachment(keepScreen: true)
        Task {
            if let client, let old { try? await client.unfollow(old) }
        }
    }

    func terminateTerminal(sessionId: String, terminalId: String?) {
        Task {
            guard let client, let hostId = activeId else { return }
            let meta = terminalMeta.flatMap { $0.sessionId == sessionId ? $0 : nil }
            guard let id = terminalId ?? meta?.id else {
                emit(PocketError(code: "terminal/not-attached", message: "没有已连接的终端").localizedDescription)
                return
            }
            let epoch = terminalOpenEpoch
            do {
                _ = try await client.closeTerminal(sessionId: sessionId, id: id)
                bumpRoster(hostId: hostId, sessionId: sessionId)
                TerminalStore.forget(hostId: hostId, sessionId: sessionId, terminalId: id)
                if terminalOpenEpoch == epoch,
                   terminalMeta?.sessionId == sessionId,
                   terminalMeta?.id == id,
                   terminalMeta?.attachmentId == meta?.attachmentId {
                    closeTerminalFollow()
                }
            } catch { emit(error.localizedDescription) }
        }
    }

    func terminalSessions(sessionId: String) async throws -> TerminalSessionCatalog {
        guard let client, let hostId = activeId else { throw PocketError(code: "transport", message: "未连接") }
        let owners = uniqueStrings([sessionId] + TerminalStore.ownerIds(hostId))
        var entries: [TerminalSessionEntry] = []
        for owner in owners {
            entries.append(contentsOf: try await listTerminalOwner(client, hostId: hostId, sessionId: owner))
        }
        return TerminalSessionCatalog(entries: entries, platform: terminalPlatform)
    }

    func setAppearance(_ value: Appearance) {
        appearance = value
        AppPrefs.appearance = value
        ThemeStateHolder.shared.applyAppearance(value)
    }

    func setFontSize(_ value: Int) {
        fontSize = clampFontSize(value, range: themeFontSizeSpec(.text).range)
        AppPrefs.fontSize = fontSize
    }

    func setCodeFontSize(_ value: Int) {
        codeFontSize = clampFontSize(value, range: themeFontSizeSpec(.code).range)
        AppPrefs.codeFontSize = codeFontSize
    }

    func setTerminalFontSize(_ value: Int) {
        terminalFontSize = clampFontSize(value, range: themeFontSizeSpec(.terminal).range)
        AppPrefs.terminalFontSize = terminalFontSize
    }

    func setTextFontFamily(_ value: String) {
        textFontFamily = normalizeFontFamily(value)
        AppPrefs.textFontFamily = textFontFamily
    }

    func setCodeFontFamily(_ value: String) {
        codeFontFamily = normalizeFontFamily(value)
        AppPrefs.codeFontFamily = codeFontFamily
    }

    func setTerminalFontFamily(_ value: String) {
        terminalFontFamily = normalizeFontFamily(value)
        AppPrefs.terminalFontFamily = terminalFontFamily
    }

    func followFiles(sessionId: String, path: String) -> AsyncThrowingStream<JSONValue, Error>? {
        client?.followFiles(sessionId: sessionId, path: path)
    }

    func withOfficePreview<T>(
        sessionId: String,
        path: String,
        _ block: (OfficePreviewReader) async throws -> T
    ) async throws -> T {
        guard let client else { throw PocketError(code: "transport", message: L.t("未连接", "Not connected")) }
        return try await client.withOfficePreview(sessionId: sessionId, path: path, block)
    }

    func setBusySend(_ value: BusySend) {
        busySend = value
        AppPrefs.busySend = value
        if hostSettings.writable(.busySend) {
            hostSettings.write(.busySend, value: .string(value.rawValue))
        }
    }

    func setCodeWordWrap(_ value: Bool) {
        codeWordWrap = value
        AppPrefs.codeWordWrap = value
    }

    func reloadPermissionCatalog() {
        if uiTestFixture { return }
        guard ops.contains("permissions.catalog") else {
            permissionCatalog = nil
            permissionCatalogLoading = false
            permissionCatalogError = nil
            return
        }
        permissionCatalogLoading = true
        permissionCatalogError = nil
        Task {
            do {
                guard let client else { throw PocketError(code: "transport", message: L.t("未连接到远程主机", "Not connected to the remote host")) }
                permissionCatalog = try await client.permissionsCatalog()
                permissionCatalogError = nil
            } catch {
                permissionCatalogError = error.localizedDescription
            }
            permissionCatalogLoading = false
        }
    }

    private func runConnection(_ profileId: String) async {
        backoffMs = ReconnectBackoffPolicy.reset()
        while !Task.isCancelled {
            guard let profile = profiles.first(where: { $0.id == profileId }) else { return }
            if profile.needsRepair {
                status[profile.id] = .unauthorized
                return
            }
            guard let token = TokenStore.get(profileId: profile.id) else {
                status[profile.id] = .unauthorized
                return
            }
            status[profile.id] = .connecting
            let client = PocketClient(appVersion: Self.appVersion)
            client.setEventHandler { [weak self] event in
                Task { @MainActor in self?.onPush(event) }
            }
            do {
                guard let url = websocketURL(host: profile.host, port: profile.port) else {
                    status[profile.id] = .offline
                    emit(L.t("地址无效，请重新配对（需要远程主机地址）", "Invalid address; pair again (host:port required)"))
                    return
                }
                let hello = try await client.connect(url: url, host: profile.host, auth: .token(token))
                if let issue = hello.handshakeVersions().flatMap({
                    VersionCompatibility.evaluate(appVersion: Self.appVersion, handshake: $0)
                }) {
                    emit(compatibilityError(issue).message)
                }
                self.client = client
                resetQuestionStore(clearDrafts: false)
                ops = hello.ops
                routes[profile.id] = client.route ?? hello.route
                status[profile.id] = .online
                backoffMs = ReconnectBackoffPolicy.reset()
                if let instance = hello.instanceId, !instance.isEmpty, instance != profile.instanceId {
                    profiles = profiles.map { row in
                        row.id == profile.id ? Profile(
                            id: row.id, name: row.name, deviceId: row.deviceId,
                            host: row.host, port: row.port, instanceId: instance, lastUsedAt: row.lastUsedAt
                        ) : row
                    }
                    ProfileStore.save(profiles)
                }
                if ops.contains("plugins.settingsDescribe") {
                    hostSettings.onChange = { [weak self] in self?.applyHostMirroredPrefs() }
                    hostSettings.bind(
                        describe: { try await client.call("plugins.settingsDescribe") },
                        mutate: ops.contains("plugins.settingsMutate")
                            ? { ns, ops, rev in
                                try await client.call("plugins.settingsMutate", args: jsonObject([
                                    "ns": .string(ns),
                                    "ops": ops,
                                    "expectedRevision": .number(Double(rev)),
                                ]))
                            }
                            : nil
                    )
                }
                if ops.contains("permissions.catalog") {
                    reloadPermissionCatalog()
                }
                ConnectionKeeper.shared.requestNotifications()
                try await refreshAll(client)
                while !Task.isCancelled && client.state == .open {
                    try await Task.sleep(nanoseconds: 250_000_000)
                }
                if client.state != .open {
                    throw PocketError(code: "transport", message: client.closeReason ?? "closed")
                }
            } catch is CancellationError {
                client.close()
                return
            } catch {
                client.close()
            }
            self.client = nil
            hostSettings.onChange = nil
            hostSettings.clear()
            permissionCatalog = nil
            permissionCatalogLoading = false
            permissionChanging = false
            modelPending = nil
            commandEntries = []
            skillEntries = []
            skillEntriesByScope = [:]
            pendingAttaches = []
            followEpoch += 1
            detachFollow()
            resetTerminalAttachment(keepScreen: true, keepMeta: true)
            resetCompletion()
            resetJobs(unfollow: false)
            ops = []
            let reason = client.closeReason ?? ""
            if reason.contains("4401") || reason.contains("4403") || reason.contains("auth/") {
                status[profile.id] = .unauthorized
                return
            }
            status[profile.id] = .offline
            routes[profileId] = nil
            let wait = backoffMs
            backoffMs = ReconnectBackoffPolicy.next(backoffMs)
            let ns = UInt64(wait) * 1_000_000
            var slept: UInt64 = 0
            while slept < ns && !Task.isCancelled && !reconnectWake {
                let step: UInt64 = 200_000_000
                try? await Task.sleep(nanoseconds: step)
                slept += step
            }
            reconnectWake = false
        }
    }

    private func resumeForegroundSession() async {
        guard !Task.isCancelled, let id = activeId else { return }
        let work = BackgroundKeepAlivePolicy.resumeWork(
            dot: status[id].map(ConnectionDot.init(dot:)),
            socketOpen: client?.state == .open
        )
        switch work {
        case .none:
            return
        case .reconnect:
            wakeReconnect()
        case .refreshLive:
            switch await pingLiveSocket() {
            case .ok:
                await refreshLiveSessionState()
            case .skipped, .failed:
                noteKeepAliveFailed()
            }
        }
    }

    private func waitUntilSocketOpen() async -> Bool {
        while !Task.isCancelled {
            if client?.state == .open { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return client?.state == .open
    }

    private func refreshLiveSessionState() async {
        if liveRefreshBusy {
            liveRefreshPending = true
            return
        }
        liveRefreshBusy = true
        defer {
            liveRefreshBusy = false
            if liveRefreshPending {
                liveRefreshPending = false
                if !Task.isCancelled {
                    Task { await refreshLiveSessionState() }
                }
            }
        }
        guard let client, client.state == .open else { return }
        do {
            try await refreshAll(client)
        } catch is CancellationError {
            return
        } catch {
            if client.state != .open {
                noteKeepAliveFailed()
            }
        }
        if jobsWatchers > 0 {
            await refreshJobsOnce(clearKillError: false)
        }
    }

    private func refreshAll(_ client: PocketClient) async throws {
        if ops.contains("completion.state") {
            if let snapshot = try? await client.call("completion.state") {
                applyCompletion(snapshot)
            }
            await syncCompletionView(client)
        }
        if let list = try? await client.listSessions() {
            sessions = list.sorted { $0.updatedAt > $1.updatedAt }
        }
        if ops.contains("approval.pending") {
            if let pending = try? await client.call("approval.pending") {
                approvals = (pending["approvals"].arr() ?? []).map(Approval.parse)
            }
        }
        if let catalog = try? await client.modelCatalog() {
            applyCatalog(catalog)
        }
        if ops.contains("workspace.state"), let state = try? await client.call("workspace.state") {
            applyWorkspaceState(state)
        }
        if ops.contains("presets.list") || ops.contains("presets.settings") {
            if let roster = try? await readPresetRoster() {
                presetRoster = PresetPolicy.parseRoster(roster)
            }
            modelSettingsRevision += 1
        }
        if let sessionId = chat?.sessionId {
            do {
                try await refollow(client, sessionId: sessionId, afterSeq: reducer.cursor >= 0 ? reducer.cursor : nil)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if SessionNotFoundPolicy.matches(error) {
                    absorbMissingSession(sessionId, refreshRoster: false)
                } else {
                    throw error
                }
            }
        }
    }

    private func initializeChat(_ sessionId: String, seed: FirstPrompt? = nil) {
        followEpoch += 1
        detachFollow()
        transcriptPublisher.cancel()
        reducer = TranscriptReducer()
        inspectorLog = SessionInspectorLog()
        reducer.setRunning(sessions.first { $0.sessionId == sessionId }?.running ?? false)
        if let seed {
            reducer.echo(
                text: seed.text,
                requestId: seed.requestId,
                images: seed.images,
                files: seed.files
            )
        }
        chat = ChatState(
            sessionId: sessionId,
            items: reducer.items(),
            title: sessions.first { $0.sessionId == sessionId }?.title,
            running: reducer.running
        )
        feedback = [:]
        completionReadySession = nil
        pendingAttaches = []
        commandEntries = []
        skillEntries = []
        hiddenQuestionId = nil
        goalActivation = nil
        goalActivationEpoch += 1
        goalProjectionSeq = -1
        permissionProjectionSeq = -1
        modelProjectionSeq = -1
        presetProjectionSeq = -1
        sessionPermission = nil
        mentionQuery = nil
        fileMentions = []
        sessionMentions = []
    }

    private func detachFollow() {
        subId = nil
        completionReadySession = nil
        if let client {
            Task { await syncCompletionView(client) }
        }
    }

    private func refollow(_ client: PocketClient, sessionId: String, afterSeq: Int64?) async throws {
        followEpoch += 1
        let epoch = followEpoch
        let old = subId
        detachFollow()
        if let old {
            try? await client.unfollow(old)
        }
        guard self.client === client, chat?.sessionId == sessionId, followEpoch == epoch else { return }
        let sid = try await client.follow(sessionId: sessionId, afterSeq: afterSeq)
        guard self.client === client, chat?.sessionId == sessionId, followEpoch == epoch else {
            try? await client.unfollow(sid)
            return
        }
        subId = sid
        chat?.loaded = true
        await loadFeedback(client, sessionId: sessionId)
        await loadSkills(sessionId)
    }

    private func loadSkills(_ sessionId: String) async {
        guard ops.contains("skills.list") else { return }
        do {
            _ = try await skillCatalog(sessionId: sessionId)
        } catch is CancellationError {
        } catch {
            #if DEBUG
            print("[dsh.skills] prefetch failed session=\(sessionId) error=\(error)")
            #endif
        }
    }

    private func loadFeedback(_ client: PocketClient, sessionId: String) async {
        guard ops.contains("feedback.get") else { return }
        do {
            let result = try await client.getFeedback(sessionId: sessionId)
            let items = (result["items"].arr() ?? []).compactMap(MessageFeedback.parse)
            if chat?.sessionId == sessionId {
                feedback = Dictionary(uniqueKeysWithValues: items.map { ($0.messageId, $0) })
            }
        } catch {
            // Feedback is decorative; never drop the follow socket.
        }
    }

    /// View confirmation is not connectivity. Failures must not close the WebSocket.
    /// `sessionId` is explicit JSON null when this conversation is not ready — jsonObject would drop it.
    private func syncCompletionView(_ client: PocketClient) async {
        if completionViewBusy {
            completionViewPending = true
            return
        }
        completionViewBusy = true
        defer {
            completionViewBusy = false
            if completionViewPending {
                completionViewPending = false
                if let next = self.client {
                    Task { await syncCompletionView(next) }
                }
            }
        }
        guard ops.contains("completion.view") else { return }
        let viewed = CompletionViewed.sessionId(
            desired: desiredViewedSession,
            chat: chat?.sessionId,
            ready: completionReadySession
        )
        if CompletionViewed.shouldSkip(
            sameClient: completionViewClient === client,
            lastSession: completionViewSession,
            nextSession: viewed
        ) {
            return
        }
        let args = CompletionViewRequest.args(sessionId: viewed)
        do {
            let snapshot: JSONValue
            do {
                snapshot = try await client.call("completion.view", args: args)
            } catch is CancellationError {
                return
            } catch {
                if self.client !== client { return }
                if SessionNotFoundPolicy.matches(error) { return }
                emit(error.localizedDescription)
                snapshot = try await client.call("completion.view", args: args)
            }
            if self.client === client {
                completionViewClient = client
                completionViewSession = viewed
                applyCompletion(snapshot)
            }
        } catch is CancellationError {
            return
        } catch {
            if self.client === client {
                if !SessionNotFoundPolicy.matches(error) {
                    emit(error.localizedDescription)
                }
                completionViewClient = nil
                completionViewSession = nil
            }
        }
    }

    private func sendPrompt(
        _ client: PocketClient,
        chat: ChatState,
        text: String,
        images: [PromptImage] = [],
        files: [PromptFile] = [],
        attachments: [QueuedAttachment] = [],
        gesture: ComposerSubmitGesture = .enter,
        requestId: String? = nil
    ) async throws {
        let target = reducer
        let requestId = requestId ?? UUID().uuidString
        let mode = resolveSubmitMode(
            preferred: busySend.mode,
            running: chat.running,
            gesture: gesture,
            steeringAvailable: ops.contains("queue.update")
        )
        target.echo(
            text: text,
            requestId: requestId,
            mode: mode,
            images: images.count,
            files: files.count,
            attachments: attachments
        )
        publishChat()
        do {
            _ = try await client.prompt(
                sessionId: chat.sessionId,
                text: text,
                mode: mode,
                images: images,
                files: files,
                requestId: requestId
            )
        } catch {
            target.discardEcho(requestId)
            publishChat()
            throw error
        }
    }

    private func uploadAttach(_ id: UUID) async {
        guard let client, let sessionId = chat?.sessionId, ops.contains("attachments.upload") else { return }
        guard let index = pendingAttaches.firstIndex(where: { $0.id == id }) else { return }
        pendingAttaches[index].status = .uploading
        let payload = pendingAttaches[index].data
        let filename = pendingAttaches[index].name
        do {
            guard let receipt = UploadReceipt.parse(try await client.uploadAttachment(
                sessionId: sessionId,
                data: payload.base64EncodedString(),
                name: filename
            )) else {
                throw PocketError(code: "bad-reply", message: L.t("未返回附件回执", "Attachment receipt missing"))
            }
            if let next = pendingAttaches.firstIndex(where: { $0.id == id }) {
                pendingAttaches[next].receiptId = receipt.receiptId
                pendingAttaches[next].status = .ready
            }
        } catch {
            if let next = pendingAttaches.firstIndex(where: { $0.id == id }) {
                pendingAttaches[next].status = .failed
            }
            emit(error.localizedDescription)
        }
    }

    private func applyCatalog(_ catalog: ModelCatalog) {
        self.catalog = catalog
        if let current = modelChoice {
            let resolved = composerResolvedModel(
                provider: current.provider,
                model: current.model,
                name: current.name,
                effort: current.effort,
                catalog: catalog
            )
            if let resolved, catalog.find(provider: resolved.provider, model: resolved.model)?.hasReasoning == true {
                modelChoice = ModelChoice(
                    provider: resolved.provider,
                    model: resolved.model,
                    name: resolved.name,
                    effort: resolved.effort
                )
            }
            return
        }
        guard let resolved = composerResolvedModel(
            provider: nil,
            model: nil,
            name: nil,
            effort: nil,
            catalog: catalog
        ) else { return }
        modelChoice = ModelChoice(
            provider: resolved.provider,
            model: resolved.model,
            name: resolved.name,
            effort: resolved.effort
        )
    }

    private func modelChoice(from value: JSONValue) -> ModelChoice? {
        guard let provider = value["provider"].str(), let model = value["model"].str() else { return nil }
        return ModelChoice(
            provider: provider,
            model: model,
            name: catalog?.find(provider: provider, model: model)?.name ?? value["name"].str() ?? model,
            effort: value["effort"].str()
        )
    }

    private func resetQuestionStore(clearDrafts: Bool) {
        questionStore.clear()
        userQuestions = []
        if clearDrafts {
            questionDrafts = [:]
            questionPageIndex = [:]
            hiddenQuestionId = nil
        }
    }

    private func publishUserQuestions() {
        userQuestions = questionStore.questions()
        let live = questionStore.retainedQuestionIds()
        questionDrafts = questionDrafts.filter { live.contains($0.key) }
        questionPageIndex = questionPageIndex.filter { live.contains($0.key) }
    }

    private func applyUserQuestionFollow(_ frame: JSONValue) {
        let type = frame["type"].str()
        let key = frame["key"].str()
        guard type == "snapshot" || type == "resume"
            || (type == "projection" && (key == "userQuestions" || key == "inbox"))
        else { return }
        guard let sessionId = chat?.sessionId else { return }
        questionStore.apply(sessionId: sessionId, frame: frame)
        publishUserQuestions()
    }

    private func applyFollowProjections(_ frame: JSONValue) {
        let type = frame["type"].str()
        let projection = (type == "snapshot" || type == "resume") ? frame["projections"] : nil
        let values = projection?["values"]
        let seq = projection?["asOfSeq"].long() ?? frame["seq"].long() ?? frame["cursor"].long() ?? -1
        if values?.obj()?.keys.contains("modelSelection") == true || type == "snapshot" {
            applyModelProjection(seq, values?["modelSelection"] ?? .null)
        }
        if type == "projection" && frame["key"].str() == "modelSelection" {
            applyModelProjection(frame["seq"].long() ?? -1, frame["value"])
        }
        if let values, values.obj()?.keys.contains("permissions") == true, seq >= permissionProjectionSeq {
            permissionProjectionSeq = seq
            sessionPermission = values["permissions"]["currentValue"].str()
        } else if type == "projection", frame["key"].str() == "permissions" {
            let next = frame["seq"].long() ?? -1
            if next >= permissionProjectionSeq {
                permissionProjectionSeq = next
                sessionPermission = frame["value"]["currentValue"].str()
            }
        }
        if type == "snapshot" || values?.obj()?.keys.contains("goal") == true || frame["key"].str() == "goal" {
            if seq >= goalProjectionSeq {
                goalProjectionSeq = seq
                let raw = (values.flatMap { $0.obj()?["goal"] } ?? frame["value"])["goal"]
                chat?.goal = raw.isNull ? nil : raw
            }
        }
        if type == "snapshot" || values?.obj()?.keys.contains("agentPreset") == true || frame["key"].str() == "agentPreset" {
            if seq >= presetProjectionSeq {
                presetProjectionSeq = seq
                let raw = values.flatMap { $0.obj()?["agentPreset"] } ?? frame["value"]
                chat?.agentPreset = raw.str()
            }
        }
    }

    private func applyModelProjection(_ seq: Int64, _ value: JSONValue) {
        guard seq >= modelProjectionSeq else { return }
        modelProjectionSeq = seq
        if let next = modelChoice(from: value) {
            modelChoice = next
        }
    }

    private func loadSessionPermission(_ sessionId: String) {
        let generation = permissionHydrationGeneration
        Task {
            guard let client, ops.contains("permissions.get") else { return }
            do {
                let current = try await client.permission(sessionId: sessionId)
                if chat?.sessionId == sessionId, generation == permissionHydrationGeneration {
                    sessionPermission = current
                }
            } catch {
                // Permission is decorative until the user opens the picker.
            }
        }
    }

    private func onPush(_ m: JSONValue) {
        switch m["ev"].str() {
        case "ops.changed":
            ops = Set((m["ops"].arr() ?? []).compactMap { $0.str() })
        case "follow":
            if m["subId"].str() == subId {
                let frame = m["frame"]
                let changed = reducer.apply(frame)
                inspectorLog.apply(frame)
                let frameType = frame["type"].str()
                if frameType == "assistant-stream" && frame["frame"]["type"].str() == "chunk" {
                    if changed { transcriptPublisher.schedule() }
                    break
                }
                applyFollowProjections(frame)
                applyUserQuestionFollow(frame)
                transcriptPublisher.flush()
                if frameType == "snapshot" || frameType == "resume",
                   let sessionId = chat?.sessionId {
                    completionReadySession = sessionId
                    if let client {
                        Task { await syncCompletionView(client) }
                    }
                }
            }
        case "follow.end":
            if m["subId"].str() == subId, let client, let sessionId = chat?.sessionId {
                Task {
                    do {
                        try await refollow(client, sessionId: sessionId, afterSeq: reducer.cursor >= 0 ? reducer.cursor : nil)
                    } catch is CancellationError {
                    } catch {
                        if chat?.sessionId != sessionId { return }
                        if SessionNotFoundPolicy.matches(error) {
                            absorbMissingSession(sessionId)
                        }
                    }
                }
            }
        case "follow.error":
            if m["subId"].str() == subId {
                subId = nil
                let code = m["error"]["code"].str()
                let message = m["error"]["message"].str()
                if SessionNotFoundPolicy.matches(code: code, message: message), let sessionId = chat?.sessionId {
                    absorbMissingSession(sessionId)
                } else {
                    emit(message ?? code ?? "follow error")
                    chat?.loaded = true
                }
            }
        case "session":
            switch m["kind"].str() {
            case "added":
                if let s = SessionSummary.parse(m["summary"]) {
                    sessions = [s] + sessions.filter { $0.sessionId != s.sessionId }
                } else {
                    logSession("added parse failed raw=\(m)")
                    Task { await refreshSessionRoster() }
                }
            case "removed":
                let removedId = m["sessionId"].str()
                sessions.removeAll { $0.sessionId == removedId }
                if let removedId, chat?.sessionId == removedId {
                    absorbMissingSession(removedId)
                }
            case "status":
                let id = m["sessionId"].str()
                let running = m["running"].bool() ?? false
                sessions = sessions.map { $0.sessionId == id ? mutated($0, running: running) : $0 }
                if chat?.sessionId == id {
                    reducer.setRunning(running)
                    transcriptPublisher.flush()
                }
                Task {
                    await refreshSessionTitles()
                    if !running {
                        try? await Task.sleep(nanoseconds: sessionTitleRefreshDelayNanoseconds)
                        await refreshSessionTitles()
                    }
                }
            case "activity":
                let id = m["sessionId"].str()
                let t = m["updatedAt"].long() ?? 0
                sessions = sessions.map { row in
                    var next = row
                    if next.sessionId == id { next.updatedAt = t }
                    return next
                }.sorted { $0.updatedAt > $1.updatedAt }
            case "error":
                if SessionNotFoundPolicy.matches(code: m["code"].str(), message: m["message"].str()) {
                    if let id = m["sessionId"].str() ?? chat?.sessionId {
                        absorbMissingSession(id)
                    }
                } else if let message = m["message"].str() {
                    emit(message)
                }
            default:
                break
            }
        case "approval":
            let a = Approval.parse(m)
            approvals = approvals.filter { $0.approvalId != a.approvalId } + [a]
            ConnectionKeeper.shared.notifyApproval(a)
        case "approval.closed":
            approvals.removeAll { $0.approvalId == m["approvalId"].str() }
        case "task":
            if let event = TaskEvent.parse(m) {
                let title = sessions.first { $0.sessionId == event.sessionId }?.title
                ConnectionKeeper.shared.notifyTask(event, sessionTitle: title)
            }
        case "user-question":
            questionStore.offer(m)
            publishUserQuestions()
        case "user-question.closed":
            if let id = m["questionId"].str() {
                questionStore.close(questionId: id, sessionId: m["sessionId"].str())
                publishUserQuestions()
                let stillOpen = userQuestions.contains { $0.questionId == id || $0.callId == id }
                if !stillOpen, userQuestionIsCollapsed(
                    questionId: id,
                    callId: m["callId"].str(),
                    hiddenId: hiddenQuestionId
                ) {
                    hiddenQuestionId = nil
                }
            }
        case "goal.activation":
            if m["sessionId"].str() == chat?.sessionId {
                goalActivationEpoch += 1
                goalActivation = m["goal"]["activation"].str()
            }
        case "permission-presets/catalog-changed":
            reloadPermissionCatalog()
        case "workspace.changed":
            applyWorkspaceFrame(m["frame"])
            filesRevision += 1
        case "plugins.changed":
            pluginCatalogRevision += 1
            modelSettingsRevision += 1
        case "models.changed", "credentials.changed", "presets.changed":
            modelSettingsRevision += 1
            if ops.contains("presets.list") || ops.contains("presets.settings") {
                Task {
                    if let roster = try? await readPresetRoster() {
                        presetRoster = PresetPolicy.parseRoster(roster)
                    }
                }
            }
        case "schedule.changed":
            scheduleCatalogRevision += 1
        case "settings.changed":
            hostSettings.refresh()
            applyHostMirroredPrefs()
        case "completion":
            let previous = unreadIds
            applyCompletion(m)
            for id in unreadIds.subtracting(previous) {
                ConnectionKeeper.shared.notifyCompletion(sessionId: id)
            }
        case "job", "job.end", "job.error":
            handleJobEvent(m)
        case "terminal", "terminal.end", "terminal.error":
            handleTerminalEvent(m)
        default:
            break
        }
    }

    private func handleTerminalEvent(_ m: JSONValue) {
        guard let id = m["subId"].str() else { return }
        if id == terminalSubId {
            if m["ev"].str() == "terminal" {
                applyTerminalFrame(m["frame"])
            } else {
                let message = m["error"]["message"].str() ?? "终端连接已结束"
                terminalReady.fail(PocketError(code: "terminal/unavailable", message: message))
                if m["ev"].str() == "terminal.error" {
                    terminalFailure = message
                    emit(message)
                }
                terminalSubId = nil
                terminalMeta = nil
            }
        } else if terminalOpening {
            terminalStray[id, default: []].append(m)
        }
    }

    private func applyTerminalFrame(_ frame: JSONValue) {
        switch frame["type"].str() {
        case "snapshot":
            terminal.applySnapshot(frame["screen"].str() ?? "")
            terminalRevision = terminal.revision
            if let info = frame["info"].obj() {
                terminalMeta = terminalMeta.map {
                    TerminalMeta(
                        sessionId: $0.sessionId,
                        id: $0.id,
                        attachmentId: $0.attachmentId,
                        title: info["title"]?.str() ?? $0.title,
                        state: info["state"]?.str() ?? $0.state,
                        cwd: info["cwd"]?.str() ?? $0.cwd
                    )
                }
            }
            if let meta = terminalMeta, let hostId = terminalHostId, activeId == hostId {
                bumpRoster(hostId: hostId, sessionId: meta.sessionId)
                TerminalStore.remember(hostId: hostId, sessionId: meta.sessionId, terminalId: meta.id)
                terminalReady.succeed()
            }
        case "output":
            terminal.write(frame["data"].str() ?? "")
            terminalRevision = terminal.revision
        case "state":
            if let info = frame["info"].obj() {
                terminalMeta = terminalMeta.map {
                    TerminalMeta(
                        sessionId: $0.sessionId,
                        id: $0.id,
                        attachmentId: $0.attachmentId,
                        title: info["title"]?.str() ?? $0.title,
                        state: info["state"]?.str() ?? $0.state,
                        cwd: info["cwd"]?.str() ?? $0.cwd
                    )
                }
            }
        default:
            break
        }
    }

    private func attachTerminal(sessionId: String, forceNew: Bool, terminalId: String?) async {
        if terminalAttachFrozen { return }
        terminalOpenEpoch += 1
        let epoch = terminalOpenEpoch
        let client = self.client
        let hostId = activeId
        let oldSubId = terminalSubId
        terminalSubId = nil
        terminalReady.fail(CancellationError())
        let ready = TerminalReady()
        terminalReady = ready
        terminalOpening = true
        terminalFailure = nil
        terminalMissing = false
        terminalExited = false
        terminalStray = [:]
        terminalMeta = nil
        terminalHostId = hostId
        terminal.clear()
        terminal.resize(newCols: terminalWantCols, newRows: terminalWantRows)
        terminalRevision = terminal.revision
        var followed: String?
        var attached = false
        func current() -> Bool {
            self.client === client && activeId == hostId && terminalOpenEpoch == epoch
        }
        do {
            guard let client, let hostId else { throw PocketError(code: "transport", message: "未连接") }
            guard ops.contains("terminal.list"), ops.contains("terminal.follow") else {
                throw PocketError(code: "unsupported", message: "桌面端未提供终端")
            }
            if let oldSubId { try? await client.unfollow(oldSubId) }
            if !current() { return }
            let saved = TerminalStore.selectedId(hostId: hostId, sessionId: sessionId)
            let existing: TerminalSessionEntry?
            if forceNew {
                existing = nil
            } else {
                do {
                    existing = try selectTerminal(
                        entries: try await listTerminalOwner(client, hostId: hostId, sessionId: sessionId),
                        savedId: saved,
                        explicitId: terminalId
                    )
                } catch let error as PocketError where error.code == terminalMissingIdentityCode {
                    if current() {
                        terminalMissing = true
                        terminalFailure = nil
                    }
                    throw error
                }
            }
            if !current() { return }
            let info: TerminalSessionEntry
            if let existing {
                info = existing
            } else {
                guard ops.contains("terminal.create") else {
                    throw PocketError(code: "unsupported", message: "桌面端未提供新建终端")
                }
                let requestedId = UUID().uuidString
                bumpRoster(hostId: hostId, sessionId: sessionId)
                TerminalStore.discover(hostId: hostId, sessionId: sessionId, terminalId: requestedId)
                let result = try await client.createTerminal(sessionId: sessionId, cols: terminalWantCols, rows: terminalWantRows, id: requestedId)
                info = try TerminalSessionEntry.parse(sessionId: sessionId, value: result["terminal"])
                bumpRoster(hostId: hostId, sessionId: sessionId)
                TerminalStore.discover(hostId: hostId, sessionId: sessionId, terminalId: info.id)
                if current() { terminalPlatform = result["platform"].str() }
            }
            if !current() { return }
            let follow = try await client.followTerminal(sessionId: sessionId, id: info.id)
            followed = follow["subId"].str()
            guard let followed, let attachmentId = follow["attachmentId"].str() else {
                throw PocketError(code: "bad-reply", message: "no terminal subscription")
            }
            if !current() {
                try? await client.unfollow(followed)
                return
            }
            terminalSubId = followed
            terminalMeta = TerminalMeta(sessionId: sessionId, id: info.id, attachmentId: attachmentId, title: info.title, state: info.state, cwd: info.cwd)
            terminalOpening = false
            let buffered = terminalStray.removeValue(forKey: followed) ?? []
            terminalStray = [:]
            for event in buffered { handleTerminalEvent(event) }
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in try await ready.wait() }
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    throw PocketError(code: "timeout", message: "timed out after 60000ms")
                }
                do {
                    try await group.next()
                    group.cancelAll()
                } catch {
                    ready.fail(error)
                    group.cancelAll()
                    throw error
                }
            }
            if !current() { return }
            attached = true
            terminal.resize(newCols: terminalWantCols, newRows: terminalWantRows)
            terminalRevision = terminal.revision
            if terminalMeta?.state == "running" {
                _ = try await client.resizeTerminal(sessionId: sessionId, id: info.id, attachmentId: attachmentId, cols: terminalWantCols, rows: terminalWantRows)
            }
        } catch is CancellationError {
            ready.fail(CancellationError())
            return
        } catch {
            ready.fail(error)
            if current() {
                if terminalMissing {
                    terminalFailure = nil
                } else if let pocket = error as? PocketError {
                    terminalFailure = pocket.message
                    emit(error.localizedDescription)
                } else {
                    terminalFailure = error.localizedDescription
                    emit(error.localizedDescription)
                }
            }
        }
        if current() {
            terminalOpening = false
            terminalStray = [:]
            if !attached {
                terminalSubId = nil
                terminalMeta = nil
                terminalHostId = nil
            }
        }
        if !attached, let followed, let client {
            try? await client.unfollow(followed)
        }
    }

    private func listTerminalOwner(_ client: PocketClient, hostId: String, sessionId: String) async throws -> [TerminalSessionEntry] {
        let key = rosterKey(hostId, sessionId)
        let revision = terminalRosterRevision[key] ?? 0
        let result = try await client.listTerminals(sessionId: sessionId)
        if self.client !== client || activeId != hostId {
            throw CancellationError()
        }
        guard let rows = result["terminals"].arr() else {
            throw PocketError(code: "bad-reply", message: "未返回终端列表")
        }
        let entries = try rows.map { try TerminalSessionEntry.parse(sessionId: sessionId, value: $0) }
        terminalPlatform = result["platform"].str()
        if terminalRosterRevision[key] == revision || terminalRosterRevision[key] == nil && revision == 0 {
            TerminalStore.reconcile(hostId: hostId, sessionId: sessionId, ids: entries.map(\.id))
        }
        return entries
    }

    private func resetTerminalAttachment(keepScreen: Bool, keepMeta: Bool = false) {
        terminalOpenEpoch += 1
        terminalOpening = false
        terminalStray = [:]
        terminalReady.fail(CancellationError())
        terminalHostId = nil
        if !keepMeta {
            terminalMeta = nil
        }
        if !keepScreen {
            terminal.clear()
            terminalRevision = terminal.revision
        }
    }

    private func bumpRoster(hostId: String, sessionId: String) {
        let key = rosterKey(hostId, sessionId)
        terminalRosterRevision[key] = (terminalRosterRevision[key] ?? 0) + 1
    }

    private func rosterKey(_ hostId: String, _ sessionId: String) -> String { "\(hostId)\t\(sessionId)" }

    private func mutated(_ session: SessionSummary, running: Bool) -> SessionSummary {
        var next = session
        next.running = running
        return next
    }

    private func applyWorkspaceState(_ state: JSONValue) {
        workspaces = (state["items"].arr() ?? state["workspaces"].arr() ?? []).compactMap(WorkspaceView.parse)
        archivedIds = Set((state["archivedSessionIds"].arr() ?? []).compactMap { $0.str() })
        pinnedIds = Set((state["pinnedSessionIds"].arr() ?? []).compactMap { $0.str() })
    }

    private func applyWorkspaceFrame(_ frame: JSONValue) {
        switch frame["type"].str() {
        case "baseline":
            applyWorkspaceState(frame["value"])
        case "upsert":
            if let row = WorkspaceView.parse(frame["workspace"]) {
                if workspaces.contains(where: { $0.workspaceId == row.workspaceId }) {
                    workspaces = workspaces.map { $0.workspaceId == row.workspaceId ? row : $0 }
                } else {
                    workspaces.append(row)
                }
            }
        case "remove":
            workspaces.removeAll { $0.workspaceId == frame["workspaceId"].str() }
        case "order":
            let rows = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.workspaceId, $0) })
            workspaces = (frame["workspaceIds"].arr() ?? []).compactMap { id in
                id.str().flatMap { rows[$0] }
            }
        case "archived":
            archivedIds = Set((frame["archivedSessionIds"].arr() ?? []).compactMap { $0.str() })
        case "pinned":
            pinnedIds = Set((frame["pinnedSessionIds"].arr() ?? []).compactMap { $0.str() })
        default:
            break
        }
    }

    private func applyCompletion(_ snapshot: JSONValue) {
        completionReminders.accept(snapshot)
        unreadIds = completionReminders.unreadIds
    }

    private func resetCompletion() {
        completionReminders.reset()
        unreadIds = []
        completionReadySession = nil
        desiredViewedSession = nil
        completionViewClient = nil
        completionViewSession = nil
        completionViewBusy = false
        completionViewPending = false
    }

    private func resetJobs(unfollow: Bool) {
        jobsWatchers = 0
        resetJobsWatchState(unfollow: unfollow, clearSnapshot: true)
    }

    private struct JobsWatchToken {
        let hostId: String
        let sessionId: String
    }

    private func attachJobsWatch(hostId: String, sessionId: String) -> JobsWatchToken {
        if jobsWatchHostId != hostId || jobsWatchSessionId != sessionId {
            resetJobsWatchState(unfollow: true, clearSnapshot: true)
            jobsWatchHostId = hostId
            jobsWatchSessionId = sessionId
        }
        jobsWatchers += 1
        ensureJobsLoop()
        return JobsWatchToken(hostId: hostId, sessionId: sessionId)
    }

    private func detachJobsWatch(_ token: JobsWatchToken) {
        guard jobsWatchHostId == token.hostId, jobsWatchSessionId == token.sessionId else { return }
        if jobsWatchers == 0 {
            preconditionFailure("jobs watch retain count underflow")
        }
        jobsWatchers -= 1
        if jobsWatchers == 0 {
            resetJobsWatchState(unfollow: true, clearSnapshot: false)
        }
    }

    private func resetJobsWatchState(unfollow: Bool, clearSnapshot: Bool) {
        jobsLoopGeneration += 1
        jobsLoop?.cancel()
        jobsLoop = nil
        let leftover = jobFollows
        jobFollows = [:]
        jobFollowEnded = []
        jobFollowInFlight = []
        jobStray = [:]
        jobsReconcileBusy = false
        jobsReconcilePending = false
        if clearSnapshot {
            jobs = nil
            jobsFailed = false
            jobsPanelError = nil
            jobsPanelKillError = false
            selectedJobId = nil
            jobDetail = nil
            jobsWatchHostId = nil
            jobsWatchSessionId = nil
            jobsWatchers = 0
        }
        if unfollow, !leftover.isEmpty, let client {
            Task {
                for sub in leftover.values { try? await client.unfollow(sub) }
            }
        }
    }

    private func ensureJobsLoop() {
        guard jobsLoop == nil, let hostId = jobsWatchHostId, let sessionId = jobsWatchSessionId else { return }
        let generation = jobsLoopGeneration
        jobsLoop = Task { await pollJobs(generation: generation, hostId: hostId, sessionId: sessionId) }
    }

    private func pollJobs(generation: Int64, hostId: String, sessionId: String) async {
        while !Task.isCancelled {
            guard jobsLoopGeneration == generation, activeId == hostId, jobsWatchers > 0 else { return }
            await refreshJobsOnce(clearKillError: false)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    private func refreshJobsOnce(clearKillError: Bool) async {
        let generation = jobsLoopGeneration
        guard let client, let sessionId = jobsWatchSessionId ?? chat?.sessionId else { return }
        do {
            let next = parseJobRoster(try await client.listJobs(sessionId: sessionId))
            guard jobsLoopGeneration == generation else { return }
            if jobs != next { jobs = next }
            jobsFailed = false
            if clearKillError || !jobsPanelKillError {
                jobsPanelKillError = false
                jobsPanelError = nil
            }
            await runJobReconcile()
        } catch is CancellationError {
            return
        } catch {
            guard jobsLoopGeneration == generation else { return }
            if jobs != nil { jobs = nil }
            jobsFailed = true
            jobsPanelKillError = false
            jobsPanelError = L.jobLoadFailed()
            await detachJobFollows(client: client)
        }
    }

    private func runJobReconcile() async {
        if jobsReconcileBusy {
            jobsReconcilePending = true
            return
        }
        jobsReconcileBusy = true
        defer {
            jobsReconcileBusy = false
            if jobsReconcilePending {
                jobsReconcilePending = false
                Task { await runJobReconcile() }
            }
        }
        guard jobsWatchers > 0, let client, let sessionId = jobsWatchSessionId ?? chat?.sessionId else { return }
        await reconcileJobFollows(client: client, sessionId: sessionId)
    }

    private func reconcileJobFollows(client: PocketClient, sessionId: String) async {
        let generation = jobsLoopGeneration
        var wanted = Set((jobs ?? []).filter(\.isLive).map(\.id))
        if let selectedJobId { wanted.insert(selectedJobId) }
        for id in Set(jobFollows.keys).subtracting(wanted) {
            if let sub = jobFollows.removeValue(forKey: id) {
                try? await client.unfollow(sub)
            }
        }
        for id in wanted.subtracting(Set(jobFollows.keys)) {
            if jobFollowEnded.contains(id) { continue }
            guard JobFollowClaim.begin(inFlight: &jobFollowInFlight, assigned: jobFollows, jobId: id) else { continue }
            guard jobsLoopGeneration == generation, self.client === client else {
                JobFollowClaim.end(inFlight: &jobFollowInFlight, jobId: id)
                return
            }
            do {
                let sub = try await client.followJob(sessionId: sessionId, jobId: id)
                JobFollowClaim.end(inFlight: &jobFollowInFlight, jobId: id)
                if jobsLoopGeneration != generation || self.client !== client {
                    try? await client.unfollow(sub)
                    return
                }
                if let extra = JobFollowClaim.assign(current: &jobFollows, jobId: id, subId: sub) {
                    try? await client.unfollow(extra)
                } else {
                    let buffered = jobStray.removeValue(forKey: sub) ?? []
                    for event in buffered { handleJobEvent(event) }
                }
            } catch is CancellationError {
                JobFollowClaim.end(inFlight: &jobFollowInFlight, jobId: id)
                return
            } catch {
                JobFollowClaim.end(inFlight: &jobFollowInFlight, jobId: id)
                if selectedJobId == id {
                    jobDetail?.error = error.localizedDescription
                }
            }
        }
    }

    private func detachJobFollows(client: PocketClient) async {
        let leftover = jobFollows
        jobFollows = [:]
        jobFollowInFlight = []
        jobStray = [:]
        for sub in leftover.values { try? await client.unfollow(sub) }
    }

    private func handleJobEvent(_ m: JSONValue) {
        guard let subId = m["subId"].str() else { return }
        if let jobId = jobFollows.first(where: { $0.value == subId })?.key {
            applyFollowedJobEvent(jobId: jobId, m)
            return
        }
        if !jobFollowInFlight.isEmpty {
            jobStray[subId, default: []].append(m)
        }
    }

    private func applyFollowedJobEvent(jobId: String, _ m: JSONValue) {
        switch m["ev"].str() {
        case "job":
            applyJobFrame(jobId: jobId, frame: m["frame"])
        case "job.end":
            jobFollows[jobId] = nil
            jobFollowEnded.insert(jobId)
        case "job.error":
            jobFollows[jobId] = nil
            jobFollowEnded.insert(jobId)
            let message = m["error"]["message"].str() ?? L.jobOutputFailed()
            if selectedJobId == jobId {
                jobDetail?.error = message
            }
        default:
            break
        }
    }

    private func applyJobFrame(jobId: String, frame: JSONValue) {
        switch JobFollowFrame.parse(frame, fallbackId: jobId) {
        case .opened(let job), .status(let job):
            applyJobFollowProjection(&jobs, jobId: jobId, incoming: job)
            if selectedJobId == jobId {
                jobDetail?.status = job.status
            }
        case .output(let lossy, let chunks):
            guard selectedJobId == jobId else { return }
            var lines = jobDetail?.output ?? []
            applyJobOutputFrames(
                to: &lines,
                lossy: lossy,
                chunks: chunks,
                expiredNotice: L.jobOutputExpired(),
                missingNotice: L.jobOutputMissing()
            )
            jobDetail?.output = lines
        case .other:
            break
        }
    }

    private func publishChat() {
        guard var state = chat else { return }
        state.items = reducer.items()
        state.queuedPrompts = reducer.queueMessages()
        state.running = reducer.running
        state.title = reducer.title ?? state.title
        state.hasMore = reducer.hasMore
        state.firstSeq = reducer.firstSeq
        state.todos = reducer.todosSnapshot()
        state.planMode = reducer.planMode
        state.steps = reducer.stepRecords()
        state.turns = reducer.turnRecords()
        state.lastAnswerKeys = ChatActionKeys.lastCommittedAnswerKeys(state.items)
        state.composerMetrics = reducer.composerMetrics
        state.turnTokenUsage = reducer.turnTokenUsage()
        state.inspectorRecords = inspectorLog.snapshot()
        state.loaded = true
        chat = state
        if let title = state.title {
            sessions = sessions.map { row in
                var next = row
                if next.sessionId == state.sessionId { next.title = title }
                return next
            }
        }
    }

    private func applyDiscovery(_ hosts: [DiscoveredHost]) {
        let merged = LanDiscoveryPolicy.mergeByInstance(hosts)
        nearby = LanDiscoveryPolicy.unpairedNearby(
            found: merged,
            paired: profiles.map { ($0.instanceId, $0.host, $0.port, $0.needsRepair) }
        )
        var activeChanged = false
        for host in merged {
            if let index = profiles.firstIndex(where: { !$0.instanceId.isEmpty && $0.instanceId == host.instanceId }) {
                if let updated = LanDiscoveryPolicy.applyAddressUpdate(
                    instanceId: profiles[index].instanceId,
                    host: profiles[index].host,
                    port: profiles[index].port,
                    discovered: host
                ) {
                    profiles[index].host = updated.host
                    profiles[index].port = updated.port
                    ProfileStore.save(profiles)
                    if profiles[index].id == activeId { activeChanged = true }
                }
            }
        }
        if activeChanged, let id = activeId { connect(profileId: id) }
    }

    private func probePairedDevices() async {
        let targets = profiles.filter { $0.id != activeId && !$0.needsRepair }
        await withTaskGroup(of: Void.self) { group in
            var inflight = 0
            for profile in targets {
                if inflight >= 2 {
                    await group.next()
                    inflight -= 1
                }
                inflight += 1
                group.addTask { await self.probeOne(profile) }
            }
        }
    }

    private func probeOne(_ profile: Profile) async {
        let requested = identity(of: profile)
        if status[profile.id] != .online && status[profile.id] != .unauthorized {
            status[profile.id] = Dot(PairedDeviceStatusPolicy.beginCheck(current: status[profile.id].map(ConnectionDot.init(dot:))))
        }
        let reachable = await tcpReachable(host: profile.host, port: profile.port, timeoutMs: 2_500)
        let revoked = TokenStore.get(profileId: profile.id) == nil
        guard let current = profiles.first(where: { $0.id == profile.id }) else { return }
        let next = PairedDeviceStatusPolicy.applyProbe(
            currentDot: status[profile.id].map(ConnectionDot.init(dot:)),
            current: identity(of: current),
            requested: requested,
            reachable: reachable,
            revoked: revoked
        )
        if profile.id != activeId || status[profile.id] != .online {
            status[profile.id] = Dot(next)
        }
    }

    private func tcpReachable(host: String, port: Int, timeoutMs: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            let params = NWParameters.tcp
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: UInt16(port)) ?? 7690, using: params)
            let gate = ProbeGate()
            @Sendable func finish(_ value: Bool) {
                if gate.take() {
                    connection.cancel()
                    continuation.resume(returning: value)
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
                finish(false)
            }
        }
    }

    /// Stale drawer row: Host follow/goals no longer bind this id. Drop it, refresh
    /// the roster, and leave the no-session home — never toast `session/not-found`.
    private func absorbMissingSession(_ sessionId: String, refreshRoster: Bool = true) {
        let dropped = SessionNotFoundPolicy.drop(
            missingId: sessionId,
            from: sessions,
            currentId: chat?.sessionId
        )
        sessions = dropped.sessions
        searchHits.removeAll { $0.sessionId == sessionId }
        workspaces = SessionNotFoundPolicy.drop(sessionId: sessionId, from: workspaces)
        if dropped.droppedCurrent {
            followEpoch += 1
            detachFollow()
            transcriptPublisher.cancel()
            chat = nil
            showDrawer = true
        }
        if refreshRoster {
            Task { await refreshSessionRoster() }
        }
    }

    private func refreshSessionRoster() async {
        guard let client else { return }
        if let list = try? await client.listSessions() {
            sessions = list.sorted { $0.updatedAt > $1.updatedAt }
            applySessionTitleToChat()
            if let id = chat?.sessionId, !list.contains(where: { $0.sessionId == id }) {
                absorbMissingSession(id, refreshRoster: false)
            }
        }
        if ops.contains("workspace.state"), let state = try? await client.call("workspace.state") {
            applyWorkspaceState(state)
        }
    }

    /// dsh titles a session asynchronously after the first turn; the list is the source of truth.
    private func refreshSessionTitles() async {
        await refreshSessionRoster()
    }

    private func applySessionTitleToChat() {
        guard let id = chat?.sessionId,
              let title = sessions.first(where: { $0.sessionId == id })?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty
        else { return }
        chat?.title = title
    }

    func showToast(_ message: String) {
        presentToast(message)
    }

    private func presentToast(_ message: String, undoArchive: String? = nil) {
        toastUndoArchiveId = undoArchive
        toast = message
    }

    private func emit(_ message: String) {
        toastUndoArchiveId = nil
        errorMessage = message
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func compatibilityError(_ issue: CompatibilityIssue) -> PocketError {
        switch issue.kind {
        case .appTooOld: return PocketError(code: "compat", message: L.appTooOld(issue.requiredVersion))
        case .pluginTooOld: return PocketError(code: "compat", message: L.pluginTooOld(issue.requiredVersion))
        case .protocolUnsupported: return PocketError(code: "compat", message: L.protocolUnsupported())
        }
    }
}

extension ConnectionDot {
    init(dot: Dot) {
        switch dot {
        case .online: self = .online
        case .connecting: self = .connecting
        case .offline: self = .offline
        case .unauthorized: self = .unauthorized
        }
    }
}

private func logChanges(_ message: String) {
    #if DEBUG
    print("[dsh.changes] \(message)")
    #endif
}

private func logSession(_ message: String) {
    #if DEBUG
    print("[dsh.session] \(message)")
    #endif
}

extension Dot {
    init(_ dot: ConnectionDot) {
        switch dot {
        case .online: self = .online
        case .connecting: self = .connecting
        case .offline: self = .offline
        case .unauthorized: self = .unauthorized
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

private final class ProbeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if finished { return false }
        finished = true
        return true
    }
}

/// Snapshot may complete before the waiter is armed, matching Android `CompletableDeferred`.
@MainActor
private final class TerminalReady {
    private var continuation: CheckedContinuation<Void, Error>?
    private var stored: Result<Void, Error>?

    func wait() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            if let stored {
                switch stored {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            } else {
                continuation = cont
            }
        }
    }

    func succeed() { finish(.success(())) }

    func fail(_ error: Error) { finish(.failure(error)) }

    private func finish(_ result: Result<Void, Error>) {
        if stored != nil { return }
        stored = result
        switch result {
        case .success: continuation?.resume()
        case .failure(let error): continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}
