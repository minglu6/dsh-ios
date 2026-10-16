import SwiftUI
import UIKit
import UniformTypeIdentifiers
import DSHProtocol

struct ChatView: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showModels = false
    @State private var tab = 0
    @State private var feedbackDraft: FeedbackDraft?
    @State private var showStart = false
    @State private var showInspector = false
    @State private var highlightedRow: String?
    @ObservedObject private var inspectorNav = InspectorNavigation.shared
    @State private var showJobs = false
    @State private var openTurns: [String: Bool] = [:]
    @State private var openProcesses: [String: Bool] = [:]
    @State private var inspectTool: Item.Tool?
    @State private var showPermission = false
    @State private var riskPermission: String?
    @State private var slashMenu = SlashMenuState()
    @StateObject private var commandHost = CommandMenuHost()
    @State private var composerFocus = 0
    @State private var showGoal = false
    @State private var questionDrafts: [String: QuestionDraft] = [:]
    @State private var showFileImporter = false
    @State private var showSessionFeedback = false
    @State private var showPreset = false

    /// Android: Screen.Chat + drawer closed + focused + RESUMED. Otherwise completion.view gets null.
    private var desiredViewedSession: String? {
        guard scenePhase == .active, !model.showDrawer, let id = model.chat?.sessionId else { return nil }
        return id
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            if tab == 0 {
                chatTab
            } else if model.showCodeWorkView {
                TrajectoryView(model: model)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: $showModels) {
            ModelPicker(
                catalog: model.catalog,
                current: model.modelChoice,
                loading: model.catalogLoading,
                error: model.catalogError,
                pending: model.modelPending,
                enabled: model.isOnline,
                onReload: { model.reloadModelCatalog() },
                onDismiss: { showModels = false },
                onPick: { choice, done in model.selectModel(choice, onComplete: done) }
            )
            .padding()
        }
        .sheet(isPresented: $showStart) {
            StartPanel(
                model: model,
                onFiles: {
                    model.push(.panel(.files))
                    showStart = false
                },
                onTerminal: {
                    model.push(.panel(.terminal))
                    showStart = false
                },
                onDismiss: { showStart = false }
            )
        }
        .sheet(isPresented: $showInspector) {
            if let sessionId = model.chat?.sessionId {
                SessionInspectorPanel(model: model, sessionId: sessionId) { showInspector = false }
            }
        }
        .onChange(of: inspectorNav.picking) { picking in
            if !picking, inspectorNav.sessionId == model.chat?.sessionId {
                showInspector = true
            }
        }
        .onChange(of: model.showDrawer) { show in
            if show && inspectorNav.picking { inspectorNav.cancel() }
        }
        .onChange(of: model.showCodeWorkView) { show in
            if !show { tab = 0 }
        }
        .sheet(isPresented: $showJobs) {
            JobsPanel(model: model) { showJobs = false }
        }
        .sheet(item: $feedbackDraft) { draft in
            FeedbackCategorySheet(
                hint: L.feedbackHint(),
                onDismiss: { feedbackDraft = nil },
                onSubmit: { category, note, complete in
                    model.setMessageFeedback(
                        messageId: draft.messageId,
                        rating: draft.rating,
                        category: category,
                        note: note,
                        onResult: complete
                    )
                }
            )
        }
        .sheet(isPresented: $showPermission) {
            PermissionPickerSheet(
                current: model.sessionPermission ?? "",
                catalog: model.permissionCatalog,
                loading: model.permissionCatalogLoading,
                error: model.permissionCatalogError,
                enabled: model.isOnline,
                busy: model.permissionChanging,
                onRefresh: { model.reloadPermissionCatalog() },
                onDismiss: { showPermission = false },
                onPick: { value in
                    if value == "danger-full-access" || value == "auto" {
                        riskPermission = value
                        showPermission = false
                    } else {
                        model.setPermission(value) { _ in showPermission = false }
                    }
                }
            )
            .onAppear { model.reloadPermissionCatalog() }
        }
        .sheet(isPresented: Binding(get: { riskPermission != nil }, set: { if !$0 { riskPermission = nil } })) {
            if let value = riskPermission {
                PermissionRiskSheet(
                    preset: value,
                    enabled: model.isOnline && !model.permissionChanging && model.permissionCatalog?.find(value) != nil,
                    onDismiss: { riskPermission = nil },
                    onConfirm: {
                        model.setPermission(value) { _ in riskPermission = nil }
                    }
                )
            }
        }
        .onChange(of: model.composerText) { _ in
            slashMenu.track(trigger: slashTrigger)
        }
        .sheet(isPresented: $showGoal) {
            GoalSheet(model: model) { showGoal = false }
        }
        .sheet(item: $model.exportShare) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $showSessionFeedback) {
            FeedbackCategorySheet(
                hint: L.sessionFeedbackHint(),
                onDismiss: { showSessionFeedback = false },
                onSubmit: { category, note, complete in
                    model.recordSessionFeedback(category: category, note: note, onResult: complete)
                }
            )
        }
        .sheet(isPresented: $showPreset) {
            PresetSheet(
                model: model,
                current: model.chat?.agentPreset ?? model.draftPreset,
                editable: model.chat == nil,
                onDismiss: { showPreset = false },
                onPick: { model.draftPreset = $0 }
            )
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    guard let data = try? Data(contentsOf: url) else { continue }
                    let type = UTType(filenameExtension: url.pathExtension)
                    if type?.conforms(to: .image) == true {
                        model.attachImage(name: url.lastPathComponent, mediaType: type?.preferredMIMEType ?? "image/jpeg", data: data)
                    } else {
                        model.attachFile(name: url.lastPathComponent, mediaType: type?.preferredMIMEType ?? "application/octet-stream", data: data)
                    }
                }
            }
        }
        .onAppear { model.setViewedSession(desiredViewedSession) }
        .onDisappear { model.setViewedSession(nil) }
        .onChange(of: scenePhase) { _ in model.setViewedSession(desiredViewedSession) }
        .onChange(of: model.showDrawer) { _ in model.setViewedSession(desiredViewedSession) }
        .onChange(of: model.chat?.sessionId) { _ in
            tab = 0
            openTurns = [:]
            openProcesses = [:]
            model.setViewedSession(desiredViewedSession)
        }
    }

    private var headerTitle: String {
        guard let chat = model.chat else { return L.newSession() }
        let row = model.sessions.first { $0.sessionId == chat.sessionId }
        return conversationHeaderTitle(
            sessionId: chat.sessionId,
            title: chat.title ?? row?.title,
            blank: row?.blank ?? false,
            newSession: L.newSession(),
            untitled: L.untitledSession()
        )
    }

    private var presetLabel: String? {
        let id = model.chat?.agentPreset ?? model.draftPreset.nilIfBlank
        guard let id else { return nil }
        if let row = model.presetRoster.first(where: { $0["id"].str() == id }) {
            return PresetPolicy.name(row, english: L.en)
        }
        return id
    }

    private func openFeedback(messageId: String, rating: String) {
        feedbackDraft = FeedbackDraft(messageId: messageId, rating: rating)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { model.showDrawer = true } label: {
                Image(systemName: D.panelLeft).foregroundStyle(T.ink)
            }
            if model.chat?.running == true {
                ProgressView().controlSize(.mini)
            }
            Text(headerTitle)
                .font(.headline)
                .foregroundStyle(T.ink)
                .lineLimit(1)
            Spacer()
            if let label = presetLabel {
                Button { showPreset = true } label: {
                    Label(label, systemImage: D.agentPreset)
                        .font(.caption)
                        .foregroundStyle(T.accent)
                        .labelStyle(.titleAndIcon)
                }
            }
            Button { showStart = true } label: {
                Image(systemName: D.panelRight).foregroundStyle(T.ink)
            }
            .accessibilityLabel(L.startPanel())
            Button { if model.isOnline { showModels = true } } label: {
                Text(composerModelDisplayName(choiceName: model.modelChoice?.name, catalog: model.catalog) ?? L.modelsNav())
                    .font(.caption)
                    .foregroundStyle(T.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(T.tint, in: Capsule())
            }
            .disabled(!model.isOnline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(T.surface)
    }

    private var tabs: some View {
        HStack(spacing: 16) {
            tabChip(0, L.chatTab())
            if model.showCodeWorkView {
                tabChip(1, TrajL.viewTrajectory)
            }
            Spacer()
            if let sessionId = model.chat?.sessionId {
                JobsAction(model: model, sessionId: sessionId) { showJobs = true }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .background(T.surface)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func tabChip(_ index: Int, _ title: String) -> some View {
        Button { tab = index } label: {
            Text(title)
                .font(.subheadline.weight(tab == index ? .semibold : .regular))
                .foregroundStyle(tab == index ? T.ink : T.text3)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    if tab == index { T.accent.frame(height: 2) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == index ? [.isSelected] : [])
    }

    private var sessionQuestion: UserQuestion? {
        model.userQuestions.first { model.chat != nil && ($0.sessionId == nil || $0.sessionId == model.chat?.sessionId) }
    }

    private var sessionApproval: Approval? {
        model.approvals.first { model.chat != nil && ($0.sessionId == nil || $0.sessionId == model.chat?.sessionId) }
    }

    private var questionVisible: Bool {
        guard let question = sessionQuestion else { return false }
        return !question.questions.isEmpty && model.hiddenQuestionId != question.questionId
    }

    private var slashTrigger: ComposerTrigger? { slashMenuTrigger(model.composerText) }

    private var commandMenuVisible: Bool { slashMenu.isVisible(trigger: slashTrigger) }

    private var chatTab: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        transcript
                        dock
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    if commandMenuVisible {
                        commandMenuLayer(maxHeight: max(0, geo.size.height - 8))
                    }
                }
            }
            if !questionVisible && sessionApproval == nil {
                composer
            }
            if let metrics = model.chat?.composerMetrics {
                ComposerStats(metrics: metrics)
            }
        }
    }

    private func commandMenuLayer(maxHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismissCommandMenu() }
            commandMenu(maxHeight: maxHeight)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
                .frame(height: maxHeight, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commandMenu(maxHeight: CGFloat) -> some View {
        CommandMenuOverlay(
            model: model,
            host: commandHost,
            query: slashMenuQuery(model.composerText),
            leading: slashMenuIsLeading(model.composerText),
            consumeSlash: slashTrigger != nil,
            availableHeight: maxHeight,
            onDismiss: { dismissCommandMenu() },
            onFile: { showFileImporter = true },
            onGoal: { showGoal = true },
            onPlan: { model.executeCommand("/plan") },
            onFeedback: { showSessionFeedback = true },
            onCompact: { model.executeCommand("/compact") },
            onPerm: { if model.isOnline { showPermission = true } },
            onModel: { if model.isOnline { showModels = true } },
            onExport: { model.exportSession() }
        )
    }

    private func dismissCommandMenu() {
        slashMenu.dismiss(trigger: slashTrigger)
    }

    private func submitCommandMenuOrSend() {
        if commandMenuVisible {
            commandHost.requestEnter()
            return
        }
        model.sendCurrent()
    }

    @ViewBuilder
    private var dock: some View {
        if questionVisible, let question = sessionQuestion {
            UserQuestionCard(
                question: question,
                drafts: Binding(
                    get: { questionDrafts },
                    set: { questionDrafts = $0 }
                ),
                enabled: model.isOnline,
                onDismiss: { model.hiddenQuestionId = question.questionId },
                onAnswer: { callId, answers, done in model.answerUserQuestion(callId: callId, answers: answers, onResult: done) }
            )
        } else if let approval = sessionApproval {
            ApprovalCard(
                approval: approval,
                items: model.chat?.items ?? [],
                enabled: model.isOnline,
                onAnswer: { approval, outcome, done in model.answer(approval, outcome: outcome, onResult: done) }
            )
        }
        if sessionQuestion != nil && !questionVisible {
            Button(L.reopenQuestion()) { model.hiddenQuestionId = nil }
                .frame(maxWidth: .infinity)
        }
        if let chat = model.chat {
            TodoPanel(sessionKey: "\(model.activeId ?? ""):\(chat.sessionId)", todos: chat.todos)
            if let goal = chat.goal {
                GoalBar(goal: goal, activation: model.goalActivation) { showGoal = true }
                    .task(id: "\(chat.sessionId)-\(goal["revision"].description)-\(chat.running)-\(model.isOnline)") {
                        if model.isOnline { model.refreshGoal() }
                    }
            }
            PromptQueue(
                sessionId: chat.sessionId,
                prompts: chat.queuedPrompts,
                running: chat.running,
                enabled: model.isOnline && chat.loaded && model.ops.contains("queue.update"),
                onAction: { id, action, done in model.updateQueuedPrompt(itemId: id, action: action, onComplete: done) }
            )
        }
    }

    private var foldedRows: [ChatRow] {
        let policy = presentationPolicyFor(model.transcriptView, collapseTiming: model.collapseTiming)
        return foldChatItems(
            model.chat?.items ?? [],
            policy: policy,
            sessionRunning: model.chat?.running == true,
            turnRecords: model.chat?.turns ?? [],
            en: L.en
        )
    }

    private var runningTurnStartedAt: Int64? {
        model.chat?.turns.last(where: { $0.endedAt == nil })?.startedAt
    }

    private var lastAnswerKeys: [Int: String] {
        lastCommittedAnswerKeys(in: foldedRows)
    }

    private var changesByTurn: [Int: Item.Changes] {
        var keys: [Int: Item.Changes] = [:]
        for row in foldedRows {
            if case .changes(let item) = row {
                keys[item.turn] = item
            }
        }
        return keys
    }

    private var chatRows: [ChatRow] {
        chatTranscriptRows(foldedRows, openTurns: openTurns)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.chat?.hasMore == true {
                        Button(loadOlderLabel(loading: model.chat?.loadingOlder == true, english: L.en)) {
                            model.loadOlderHistory()
                        }
                        .disabled(model.chat?.loadingOlder == true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    ForEach(Array(chatRows.enumerated()), id: \.element.key) { _, row in
                        let pickKey = inspectorPickKey(row)
                        let attached: Item.Changes? = {
                            if case .answer(let text) = row {
                                return changesAttachedToAnswer(
                                    text,
                                    lastCommittedAnswerKeys: lastAnswerKeys,
                                    changesByTurn: changesByTurn
                                )
                            }
                            return nil
                        }()
                        InspectorChatTarget(
                            itemKey: pickKey,
                            highlighted: highlightedRow == row.key,
                            reveal: inspectorNav.revealItemKey == row.key
                        ) {
                            ChatRowView(
                                row: row,
                                model: model,
                                openTurns: $openTurns,
                                openProcesses: $openProcesses,
                                changes: attached,
                                highlightedChanges: attached.map { inspectorNav.revealItemKey == $0.key } ?? false,
                                onOpenFeedback: openFeedback,
                                onTool: { inspectTool = $0 }
                            )
                        }
                        .id(row.key)
                    }
                    if model.chat?.loaded == false {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                    if model.chat?.running == true {
                        RunningStatusRow(startedAtMs: runningTurnStartedAt)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: chatRows.last?.key) { _ in
                if inspectorNav.picking { return }
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: inspectorNav.revealItemKey) { key in
                guard let key, inspectorNav.sessionId == model.chat?.sessionId else { return }
                let attachedTurn = changesByTurn.first { $0.value.key == key }?.key
                let target = attachedTurn.flatMap { lastAnswerKeys[$0] } ?? key
                for row in foldedRows {
                    if case .process(let proc) = row, proc.turnSummary {
                        let hit = row.key == target || proc.members.contains { $0.key == target } || proc.controlledKeys.contains(target)
                        if hit { openTurns[proc.key] = true }
                    }
                }
                let index = inspectorRowIndex(chatRows, itemKey: target)
                if index >= 0 {
                    let scrollKey = chatRows[index].key
                    proxy.scrollTo(scrollKey, anchor: .center)
                    highlightedRow = scrollKey
                    Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        if highlightedRow == scrollKey { highlightedRow = nil }
                        if inspectorNav.sessionId == model.chat?.sessionId && inspectorNav.revealItemKey == key {
                            inspectorNav.revealItemKey = nil
                        }
                    }
                } else if inspectorRowIndex(foldedRows, itemKey: target) >= 0 {
                    return
                } else if model.chat?.loaded == true, model.chat?.hasMore == true, model.chat?.loadingOlder != true {
                    model.loadOlderHistory()
                } else if model.chat?.loaded == true, model.chat?.hasMore != true {
                    inspectorNav.revealItemKey = nil
                }
            }
        }
        .sheet(item: Binding(
            get: { inspectTool.map { ToolInspect($0) } },
            set: { inspectTool = $0?.tool }
        )) { inspect in
            ToolInspectSheet(tool: inspect.tool) { inspectTool = nil }
        }
    }

    private var composer: some View {
        ComposerView(
            model: model,
            interceptKeys: commandMenuVisible,
            focusToken: composerFocus,
            onPlus: {
                slashMenu.togglePlus(trigger: slashTrigger)
                if slashMenu.isVisible(trigger: slashTrigger) {
                    composerFocus += 1
                }
            },
            onPerm: { if model.isOnline { showPermission = true } },
            onModel: { if model.isOnline { showModels = true } },
            onSend: { submitCommandMenuOrSend() },
            onCommandReturn: { commandHost.requestEnter() },
            onCommandMove: { commandHost.requestMove($0) },
            onCommandEscape: { dismissCommandMenu() }
        )
    }
}

private struct RunningStatusRow: View {
    let startedAtMs: Int64?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            let label = deepDivingLabel(startedAtMs: startedAtMs, nowMs: nowMs, english: L.en)
            HStack(alignment: .center, spacing: 8) {
                RunningWhaleTail()
                TextShimmer(text: label, active: true)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.t("深度求索中", "Deep diving"))
        }
    }
}

private struct FeedbackDraft: Identifiable {
    let messageId: String
    let rating: String
    var id: String { "\(messageId):\(rating)" }
}

private struct ToolInspect: Identifiable {
    let tool: Item.Tool
    var id: String { tool.key }
    init(_ tool: Item.Tool) { self.tool = tool }
}

private struct ToolInspectSheet: View {
    let tool: Item.Tool
    var onDismiss: () -> Void
    private var summary: ToolProcessSummary { toolProcessSummary(tool, en: L.en) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(summary.title).font(.headline).foregroundStyle(T.ink)
                    if let summary = summary.summary { Text(summary).foregroundStyle(T.text2) }
                    if !tool.arguments.isEmpty {
                        Text(tool.arguments).font(LocalFonts.code()).foregroundStyle(T.text3).textSelection(.enabled)
                    }
                    if let result = tool.result, !result.isEmpty {
                        Text(result).font(LocalFonts.code()).foregroundStyle(T.text2).textSelection(.enabled)
                    }
                    if let error = tool.error { Text(error).foregroundStyle(T.err) }
                }
                .padding(16)
            }
            .navigationTitle(L.tool())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.close(), action: onDismiss) } }
        }
    }
}

struct ChatRowView: View {
    let row: ChatRow
    @ObservedObject var model: AppModel
    @Binding var openTurns: [String: Bool]
    @Binding var openProcesses: [String: Bool]
    var changes: Item.Changes? = nil
    var highlightedChanges = false
    var onOpenFeedback: (String, String) -> Void
    var onTool: (Item.Tool) -> Void

    var body: some View {
        switch row {
        case .user(let user):
            MessageRow(item: .user(user), model: model, onOpenFeedback: onOpenFeedback)
        case .answer(let text):
            MessageRow(
                item: .text(text),
                model: model,
                changes: changes,
                highlightedChanges: highlightedChanges,
                onOpenFeedback: onOpenFeedback
            )
        case .notice(let notice):
            MessageRow(item: .notice(notice), model: model, onOpenFeedback: onOpenFeedback)
        case .deliverable(let deliverable):
            MessageRow(item: .deliverable(deliverable), model: model, onOpenFeedback: onOpenFeedback)
        case .retry(let retry):
            RetryRow(item: retry)
        case .turnFailure(let failure):
            TurnFailureRow(item: failure)
        case .tool(let tool):
            ToolCard(tool: tool, onTap: { onTool(tool) })
        case .reasoning(let reasoning):
            ReasoningRow(reasoning: reasoning)
        case .process(let proc):
            ProcessGroupView(proc: proc, openTurns: $openTurns, openProcesses: $openProcesses, onTool: onTool)
        case .changes(let item):
            if changesCardMountsFetch(
                seq: item.seq,
                turnClosed: model.chat?.turns.contains(where: { $0.turn == item.turn && $0.closed }) == true,
                codeWork: model.showCodeWorkView,
                hasSummaryOp: model.ops.contains("workspaceChanges.summary")
            ), let sessionId = model.chat?.sessionId {
                ChangesCard(model: model, sessionId: sessionId, item: item)
            }
        }
    }
}

private struct ProcessGroupView: View {
    let proc: ChatRow.Process
    @Binding var openTurns: [String: Bool]
    @Binding var openProcesses: [String: Bool]
    var onTool: (Item.Tool) -> Void

    var body: some View {
        let binding = proc.turnSummary ? $openTurns : $openProcesses
        let open = binding.wrappedValue[proc.key] ?? proc.defaultOpen
        VStack(alignment: .leading, spacing: 6) {
            Button {
                binding.wrappedValue[proc.key] = !open
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: processSymbol(proc.activityKind)).foregroundStyle(T.text3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proc.title).font(LocalFonts.text()).foregroundStyle(T.text2)
                        if let detail = proc.detail, !open {
                            Text(detail).font(.caption).foregroundStyle(T.text3).lineLimit(1)
                        }
                    }
                    Spacer()
                    if !proc.closed { ProgressView().controlSize(.mini) }
                    Image(systemName: open ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(T.text3)
                }
            }
            .buttonStyle(.plain)
            .disabled(!proc.canCollapse && proc.turnSummary)
            if open && !proc.members.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(proc.members.enumerated()), id: \.element.key) { _, member in
                        switch member {
                        case .reasoning(let reasoning): ReasoningRow(reasoning: reasoning)
                        case .tool(let tool): ToolCard(tool: tool, onTap: { onTool(tool) })
                        default: EmptyView()
                        }
                    }
                }
                .padding(.leading, 22)
            }
        }
    }

    private func processSymbol(_ kind: String) -> String {
        switch kind {
        case "thinking": return "brain"
        case "read", "readImage", "webFetch": return "doc.text.magnifyingglass"
        case "search", "webSearch": return "magnifyingglass"
        case "edit", "write": return "pencil"
        case "commands": return "terminal"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "subagents": return "person.2"
        case "plan": return "checklist"
        case "questions": return "questionmark.circle"
        default: return "sparkle"
        }
    }
}

private struct ReasoningRow: View {
    let reasoning: Item.Reasoning
    @State private var open = false

    var body: some View {
        let preview = reasoningPreview(reasoning.text, running: reasoning.live)
        let policy = presentationPolicyFor(AppModel.shared.transcriptView)
        let showPreview = !open && !preview.isEmpty && (reasoning.live || policy.settledReasoningPreview)
        VStack(alignment: .leading, spacing: 4) {
            Button { open.toggle() } label: {
                HStack(spacing: 6) {
                    if reasoning.live { ProgressView().controlSize(.mini) }
                    Image(systemName: open ? "chevron.down" : "brain").foregroundStyle(T.text3)
                    Text(L.reasoning()).font(.system(size: CGFloat(AppPrefs.fontSize - 1))).foregroundStyle(T.text3)
                    if showPreview {
                        Circle().fill(T.caption).frame(width: 2, height: 2)
                        Text(preview).font(.system(size: CGFloat(AppPrefs.fontSize - 1))).foregroundStyle(T.text3).lineLimit(1)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            if open {
                MarkdownView(source: reasoning.text, streaming: reasoning.live, wrapCode: AppModel.shared.codeWordWrap, bodyColor: T.text2)
                    .padding(.leading, 22)
            }
        }
    }
}

private struct ToolCard: View {
    let tool: Item.Tool
    var onTap: () -> Void

    var body: some View {
        let summary = toolProcessSummary(tool, en: L.en)
        let tint: Color = {
            switch tool.status {
            case .error: return T.err
            case .awaitingApproval: return T.warnText
            default: return T.text3
            }
        }()
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: toolSymbol(summary.icon)).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title).font(LocalFonts.text()).foregroundStyle(T.ink)
                    if let line = summary.summary {
                        Text(line).font(.caption).foregroundStyle(T.text3).lineLimit(2)
                    }
                }
                Spacer()
                if tool.status == .running || tool.status == .preparing { ProgressView().controlSize(.mini) }
            }
            .padding(tool.status == .awaitingApproval ? 8 : 0)
            .background(tool.status == .awaitingApproval ? T.warnTint : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(tool.status == .preparing)
    }

    private func toolSymbol(_ icon: ToolProcessIcon) -> String {
        switch icon {
        case .browse: return "doc.text.magnifyingglass"
        case .search: return "magnifyingglass"
        case .command: return "terminal"
        case .write, .edit: return "pencil"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .users: return "person.2"
        case .checklist: return "checklist"
        case .clock: return "clock"
        case .goal: return D.goal
        case .plugin: return "puzzlepiece.extension"
        case .agent: return "person.crop.circle"
        case .branch: return "arrow.triangle.branch"
        case .generic: return "sparkle"
        }
    }
}

struct MessageRow: View {
    let item: Item
    @ObservedObject var model: AppModel
    var changes: Item.Changes? = nil
    var highlightedChanges = false
    var onOpenFeedback: (String, String) -> Void = { _, _ in }

    var body: some View {
        switch item {
        case .user(let user):
            VStack(alignment: .trailing, spacing: 0) {
                if let sessionId = model.chat?.sessionId, !user.imageRefs.isEmpty {
                    ForEach(Array(user.imageRefs.enumerated()), id: \.offset) { _, ref in
                        ImageBubble(sessionId: sessionId, ref: ref)
                    }
                }
                if !user.text.isEmpty {
                    HStack {
                        Spacer(minLength: 48)
                        Text(user.text)
                            .foregroundStyle(T.ink.opacity(user.pending ? 0.6 : 1))
                            .padding(12)
                            .background(T.bubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                MessageActions(
                    text: user.text,
                    timeMs: user.at,
                    clock: .start
                )
            }
        case .text(let text):
            VStack(alignment: .leading, spacing: 6) {
                MarkdownView(source: text.text, streaming: text.live, wrapCode: model.codeWordWrap, onFile: { path in
                    model.openFilePreview(path: path)
                }, onLink: { url in
                    model.openChatLink(url)
                })
                if showAssistantActions(text),
                   let changes,
                   let sessionId = model.chat?.sessionId,
                   changesCardMountsFetch(
                       seq: changes.seq,
                       turnClosed: true,
                       codeWork: model.showCodeWorkView,
                       hasSummaryOp: model.ops.contains("workspaceChanges.summary")
                   ) {
                    InspectorChatTarget(itemKey: changes.key, reveal: highlightedChanges) {
                        ChangesCard(model: model, sessionId: sessionId, item: changes)
                    }
                    .padding(.top, 6)
                }
                if showAssistantActions(text) {
                    assistantActions(text)
                }
            }
        case .reasoning(let reasoning):
            ReasoningRow(reasoning: reasoning)
        case .tool(let tool):
            ToolCard(tool: tool, onTap: {})
        case .notice(let notice):
            Text(notice.text).font(.footnote).foregroundStyle(T.warnText)
        case .deliverable(let deliverable):
            VStack(alignment: .leading, spacing: 6) {
                Text(L.presentFiles()).font(.caption).foregroundStyle(T.text3)
                ForEach(deliverable.files, id: \.path) { file in
                    Button {
                        model.openFilePreview(path: file.path)
                    } label: {
                        Text(file.path).font(.footnote.monospaced()).foregroundStyle(T.link)
                    }
                    .disabled(!model.canShowFiles)
                }
            }
        case .context, .system, .compacted, .retry, .turnFailure, .changes:
            EmptyView()
        }
    }

    /// Desktop: actions on the last committed assistant text of a closed turn.
    private func showAssistantActions(_ text: Item.Text) -> Bool {
        if text.live { return false }
        let turns = model.chat?.turns ?? []
        if let turn = text.turn {
            let record = turns.first { $0.turn == turn }
            return record?.closed == true && model.chat?.lastAnswerKeys[turn] == text.key
        }
        return model.chat?.running != true
    }

    private func assistantActions(_ text: Item.Text) -> some View {
        let turn = text.turn
        let mid = text.messageId
        let rating = mid.flatMap { model.feedback[$0]?.rating }
        let canFeedback = mid != nil && model.ops.contains("feedback.set")
        let usage = (model.performanceUsage == .detailed ? turn.flatMap { model.chat?.turnTokenUsage[$0] } : nil)
        return MessageActions(
            text: text.text,
            timeMs: text.at,
            clock: .end,
            shareEnabled: MessageActionPolicy.assistantRow.contains(.share),
            messageId: mid,
            rating: rating,
            onLike: canFeedback ? {
                if rating == "positive" { model.setMessageFeedback(messageId: mid!, rating: nil) }
                else { onOpenFeedback(mid!, "positive") }
            } : nil,
            onDislike: canFeedback ? {
                if rating == "negative" { model.setMessageFeedback(messageId: mid!, rating: nil) }
                else { onOpenFeedback(mid!, "negative") }
            } : nil,
            usageAction: {
                if let usage, let turn { return { TurnUsageAction(turn: turn, usage: usage) } }
                return nil
            }()
        )
    }
}

private enum MessageClock { case start, end }

/// Desktop MessageIconActions: copy → like/dislike → share. Branch stays on the session row menu.
private struct MessageActions: View {
    let text: String
    let timeMs: Int64?
    let clock: MessageClock
    var shareEnabled = false
    var messageId: String? = nil
    var rating: String? = nil
    var onLike: (() -> Void)? = nil
    var onDislike: (() -> Void)? = nil
    var usageAction: (() -> TurnUsageAction)? = nil
    @State private var copied = false
    @State private var sharing = false

    var body: some View {
        HStack(spacing: 0) {
            if clock == .start, let timeMs {
                Text(formatMessageClock(timeMs))
                    .font(.system(size: 13))
                    .foregroundStyle(T.text3)
                    .padding(.trailing, 8)
            }
            iconButton(
                system: copied ? "checkmark" : "square.on.square",
                label: copied ? L.copied() : L.copy(),
                enabled: !copied
            ) {
                UIPasteboard.general.string = text
                copied = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    copied = false
                }
            }
            if let onLike, let onDislike {
                iconButton(
                    system: rating == "positive" ? "hand.thumbsup.fill" : "hand.thumbsup",
                    label: rating == "positive" ? L.undoRating() : L.like(),
                    action: onLike
                )
                iconButton(
                    system: rating == "negative" ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                    label: rating == "negative" ? L.undoRating() : L.dislike(),
                    action: onDislike
                )
            }
            if shareEnabled {
                iconButton(system: D.share, label: L.share(), enabled: !text.isEmpty) {
                    sharing = true
                }
            }
            if let usageAction {
                usageAction()
            }
            Spacer(minLength: 0)
            if clock == .end, let timeMs {
                Text(formatMessageClock(timeMs))
                    .font(.system(size: 12))
                    .foregroundStyle(T.text3)
                    .padding(.leading, 8)
            }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: clock == .start ? .trailing : .leading)
        .padding(.top, 4)
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [text])
        }
    }

    private func iconButton(
        system: String,
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15))
                .foregroundStyle(T.text3)
                .frame(width: 36, height: 48)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct ComposerView: View {
    @ObservedObject var model: AppModel
    var interceptKeys = false
    var focusToken = 0
    var heroPlaceholder = false
    var onPlus: () -> Void = {}
    var onPerm: () -> Void = {}
    var onModel: () -> Void = {}
    var onSend: () -> Void = {}
    var onCommandReturn: () -> Void = {}
    var onCommandMove: (Int) -> Void = { _ in }
    var onCommandEscape: () -> Void = {}

    private var trigger: ComposerTrigger? {
        composerTrigger(model.composerText, cursor: model.composerText.count)
    }

    private var references: [ComposerReference] { composerReferences(model.composerText) }
    private var filesReady: Bool {
        model.pendingAttaches.allSatisfy { $0.status != .uploading && $0.status != .failed && $0.status != .pending }
    }
    private var hasPending: Bool { !model.pendingAttaches.isEmpty }
    private var canSend: Bool {
        model.isOnline && filesReady && (!model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasPending)
    }
    private var runningIdle: Bool {
        model.chat?.running == true && model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasPending
    }

    var body: some View {
        VStack(spacing: 0) {
            mentionPanel
            VStack(alignment: .leading, spacing: 8) {
                if hasPending { attachList }
                if !references.isEmpty { mentionChips }
                if model.chat?.planMode == true {
                    Button {
                        model.executeCommand("/plan off")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: D.plan).foregroundStyle(T.accent)
                            Text(L.planChip()).foregroundStyle(T.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 48)
                    .accessibilityLabel(L.planModeOn())
                }
                if let hint = claimedComposerHint(
                    text: model.composerText,
                    catalog: model.commandEntries,
                    hasGoal: model.chat?.goal != nil,
                    english: L.en
                ) {
                    Text(hint)
                        .font(.system(size: 13))
                        .foregroundStyle(T.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ComposerTextView(
                    text: $model.composerText,
                    placeholder: composerPlaceholderText(
                        kind: composerPlaceholderKind(
                            parentOffline: model.isParentOffline,
                            unavailable: model.chat != nil && !model.isOnline,
                            canSteerQueue: model.canSteerQueue,
                            planMode: model.chat?.planMode == true,
                            hero: heroPlaceholder
                        ),
                        english: L.en
                    ),
                    interceptKeys: interceptKeys,
                    focusToken: focusToken,
                    onReturn: onCommandReturn,
                    onMove: onCommandMove,
                    onEscape: onCommandEscape,
                    onChord: { model.submitComposer(gesture: .chord) }
                )
                    .frame(minHeight: 22, maxHeight: 132, alignment: .topLeading)
                    .onChange(of: model.composerText) { value in
                        if let trigger = composerTrigger(value, cursor: value.count) {
                            if trigger.kind == Character("@") {
                                model.mentionQuery = trigger.query
                                model.fetchMentions(query: trigger.query)
                            }
                        } else {
                            model.mentionQuery = nil
                        }
                    }
                HStack(spacing: 8) {
                    Button(action: onPlus) {
                        Image(systemName: "plus").foregroundStyle(T.ink).frame(width: 48, height: 48)
                    }
                    .background(T.fill, in: Circle())
                    if let perm = model.sessionPermission ?? (heroPlaceholder ? model.defaultPermission : nil), !perm.isEmpty {
                        Button(action: onPerm) {
                            HStack(spacing: 4) {
                                Image(systemName: permissionIcon(perm))
                                Text(permissionLabel(value: perm, option: model.permissionCatalog?.find(perm)))
                                    .lineLimit(1)
                                Text("⌄")
                                    .font(.subheadline.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            .font(.subheadline)
                            .foregroundStyle(perm == "danger-full-access" ? T.warnText : T.text2)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                            .background(T.fill, in: Capsule())
                        }
                        .disabled(!model.isOnline)
                        .accessibilityLabel(permissionLabel(value: perm, option: model.permissionCatalog?.find(perm)))
                    }
                    Button(action: onModel) {
                        HStack(spacing: 4) {
                            Text(
                                composerModelDisplayName(choiceName: model.modelChoice?.name, catalog: model.catalog)
                                    ?? composerModelFallback(english: L.en)
                            )
                            .font(.subheadline)
                            .foregroundStyle(T.text2)
                            .lineLimit(1)
                            if let effort = modelEffortLabel(catalog: model.catalog, provider: model.modelChoice?.provider, model: model.modelChoice?.model, effort: model.modelChoice?.effort) {
                                Text(effort).font(.caption).foregroundStyle(T.caption).lineLimit(1)
                            }
                            if model.modelPending != nil { ProgressView().controlSize(.mini) }
                            else { Image(systemName: "chevron.down").font(.caption).foregroundStyle(T.text2) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .trailing)
                        .opacity(model.isOnline ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isOnline)
                    if runningIdle {
                        Button(action: model.stopRun) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 10, height: 10)
                                .frame(width: 48, height: 48)
                        }
                        .background(T.accent, in: Circle())
                        .accessibilityLabel(L.stop())
                    } else {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up").foregroundStyle(Color.white).frame(width: 48, height: 48)
                        }
                        .background(T.accent.opacity(canSend || interceptKeys ? 1 : 0.4), in: Circle())
                        .disabled(!canSend && !interceptKeys)
                        .accessibilityLabel(L.busySendLabel(running: model.chat?.running == true, busy: model.busySend))
                    }
                }
            }
            .padding(14)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(T.border, lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
        .background(T.surface)
    }

    @ViewBuilder
    private var attachList: some View {
        Text(L.pendingFiles()).font(.caption).foregroundStyle(T.text3)
        ForEach(model.pendingAttaches) { attach in
            HStack {
                Text(attach.name).font(.subheadline).foregroundStyle(T.ink).lineLimit(1)
                Spacer()
                switch attach.status {
                case .uploading, .pending:
                    Text(L.uploading()).font(.caption).foregroundStyle(T.caption)
                case .failed:
                    Button(L.uploadFailed()) { model.retryAttach(attach.id) }.font(.caption).foregroundStyle(T.err)
                case .ready:
                    Button(L.removeFile(attach.name)) { model.removeAttach(attach.id) }.font(.caption).foregroundStyle(T.text3)
                }
            }
        }
    }

    @ViewBuilder
    private var mentionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(references.enumerated()), id: \.offset) { _, ref in
                    HStack(spacing: 4) {
                        Image(systemName: ref.kind == .session ? "bubble.left" : (ref.kind == .directory ? "folder" : "doc"))
                            .font(.caption2)
                        Text(ref.label).font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(T.ink)
                    .background(T.fill2, in: Capsule())
                    .overlay(Capsule().stroke(T.border, lineWidth: 0.5))
                }
            }
        }
    }

    @ViewBuilder
    private var mentionPanel: some View {
        if trigger?.kind == Character("@"), !(model.fileMentions.isEmpty && model.sessionMentions.isEmpty) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L.filesAndFolders()).font(.caption).foregroundStyle(T.text3).padding(.horizontal, 8).padding(.top, 6)
                ForEach(model.fileMentions.prefix(8)) { file in
                    let directory = file.kind == "directory" || file.kind == "folder"
                    if let token = fileReferenceToken(file.path, directory: directory, preserveQuote: trigger?.quoted == true) {
                        Button {
                            insert(token)
                        } label: {
                            HStack {
                                Image(systemName: directory ? "folder" : "doc").foregroundStyle(T.text3)
                                Text(mentionFileRowLabel(file.path, directory: directory)).foregroundStyle(T.ink)
                                Spacer()
                                Text(file.path).font(.caption).foregroundStyle(T.text3).lineLimit(1)
                            }
                            .padding(8)
                        }
                    }
                }
                if trigger?.quoted != true && !model.sessionMentions.isEmpty {
                    Text(L.t("对话", "Sessions")).font(.caption).foregroundStyle(T.text3).padding(.horizontal, 8).padding(.top, 6)
                    ForEach(model.sessionMentions.prefix(8)) { session in
                        Button {
                            insert(session.mention)
                        } label: {
                            HStack {
                                Image(systemName: "bubble.left").foregroundStyle(T.text3)
                                Text(session.title ?? session.mention).foregroundStyle(T.ink)
                                Spacer()
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .background(T.settingsCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 0.5))
            .padding(.horizontal, 14)
        }
    }

    private func insert(_ token: String) {
        let next = replaceComposerToken(model.composerText, cursor: model.composerText.count, token: token)
        model.composerText = next.text
        model.mentionQuery = nil
    }
}

/// Composer field that keeps first responder while the slash menu is open so
/// the keyboard stays up; Return / arrows / Escape are routed to the menu.
private struct ComposerTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var interceptKeys: Bool
    var focusToken: Int
    var onReturn: () -> Void
    var onMove: (Int) -> Void
    var onEscape: () -> Void
    var onChord: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ComposerUITextView {
        let view = ComposerUITextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.adjustsFontForContentSizeCategory = true
        view.text = text
        let placeholder = UILabel()
        placeholder.font = view.font
        placeholder.textColor = UIColor.placeholderText
        placeholder.numberOfLines = 0
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: view.textContainer.lineFragmentPadding),
            placeholder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: view.topAnchor),
        ])
        context.coordinator.placeholder = placeholder
        context.coordinator.applyPlaceholder(view)
        return view
    }

    func updateUIView(_ view: ComposerUITextView, context: Context) {
        context.coordinator.parent = self
        view.onMove = onMove
        view.onEscape = onEscape
        view.onChord = onChord
        view.lockFirstResponder = interceptKeys
        view.interceptArrows = interceptKeys
        if view.text != text && view.markedTextRange == nil {
            view.text = text
        }
        context.coordinator.applyPlaceholder(view)
        if focusToken != context.coordinator.focusToken {
            context.coordinator.focusToken = focusToken
            if focusToken > 0 {
                view.becomeFirstResponder()
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ComposerUITextView, context: Context) -> CGSize {
        let width = proposal.width ?? uiView.bounds.width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: min(132, max(22, fitted.height)))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposerTextView
        var placeholder: UILabel?
        var focusToken = 0

        init(_ parent: ComposerTextView) {
            self.parent = parent
        }

        func applyPlaceholder(_ view: UITextView) {
            placeholder?.text = parent.placeholder
            placeholder?.isHidden = !view.text.isEmpty
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            applyPlaceholder(textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if textView.markedTextRange != nil { return true }
            if parent.interceptKeys && text == "\n" {
                parent.onReturn()
                return false
            }
            return true
        }
    }
}

private final class ComposerUITextView: UITextView {
    var onMove: ((Int) -> Void)?
    var onEscape: (() -> Void)?
    var onChord: (() -> Void)?
    var lockFirstResponder = false
    var interceptArrows = false

    override var keyCommands: [UIKeyCommand]? {
        let title = L.t("Cmd/Ctrl+Enter 插话发送全部排队消息", "Cmd/Ctrl+Enter steers all queued messages")
        return [
            UIKeyCommand(title: title, action: #selector(chordEnter), input: "\r", modifierFlags: .command),
            UIKeyCommand(title: title, action: #selector(chordEnter), input: "\r", modifierFlags: .control),
        ]
    }

    override func resignFirstResponder() -> Bool {
        if lockFirstResponder { return false }
        return super.resignFirstResponder()
    }

    @objc private func chordEnter() {
        onChord?()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let key = presses.first?.key {
            let chord = key.modifierFlags.contains(.command) || key.modifierFlags.contains(.control)
            if chord && (key.keyCode == .keyboardReturn || key.keyCode == .keyboardReturnOrEnter) {
                onChord?()
                return
            }
            if interceptArrows {
                switch key.keyCode {
                case .keyboardUpArrow:
                    onMove?(-1)
                    return
                case .keyboardDownArrow:
                    onMove?(1)
                    return
                case .keyboardEscape:
                    onEscape?()
                    return
                default:
                    break
                }
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

private struct ImageBubble: View {
    let sessionId: String
    let ref: ImageRef
    @State private var image: UIImage?
    @State private var failed = false
    @State private var loading = true
    @State private var attempt = 0
    @State private var preview = false
    @State private var bytes: Data?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Group {
                if loading {
                    Text(L.imageLoading()).font(.caption).foregroundStyle(T.text3)
                } else if failed {
                    Button(L.imageLoadFailed()) { attempt += 1 }.font(.caption).foregroundStyle(T.err)
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { preview = true }
                    Button(L.viewOriginal()) { preview = true }.font(.caption).foregroundStyle(T.accent)
                }
            }
        }
        .padding(.leading, 56)
        .task(id: "\(ref.attachmentId)-\(attempt)") {
            loading = true
            failed = false
            image = nil
            let data = await AppModel.shared.loadAttachmentBytes(sessionId: sessionId, attachmentId: ref.attachmentId)
            bytes = data
            guard let data else { failed = true; loading = false; return }
            image = UIImage(data: data)
            failed = image == nil
            loading = false
        }
        .fullScreenCover(isPresented: $preview) {
            if let bytes, let full = UIImage(data: bytes) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: full).resizable().scaledToFit()
                }
                .onTapGesture { preview = false }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController,
           let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
