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
    @State private var highlightedRow: String?
    @ObservedObject private var inspectorNav = InspectorNavigation.shared
    @State private var openTurns: [String: Bool] = [:]
    @State private var openProcesses: [String: Bool] = [:]
    @State private var inspectTool: Item.Tool?
    @State private var permissionMenuOpen = false
    @State private var riskPermission: String?
    @State private var slashMenu = SlashMenuState()
    @State private var mentionMenu = MentionMenuState()
    @StateObject private var commandHost = CommandMenuHost()
    @State private var composerFocus = 0
    @State private var showGoal = false
    @State private var showFileImporter = false
    @State private var showSessionFeedback = false

    /// Android: Screen.Chat + drawer closed + focused + RESUMED. Otherwise completion.view gets null.
    private var desiredViewedSession: String? {
        guard scenePhase == .active, !model.showDrawer, let id = model.chat?.sessionId else { return nil }
        return id
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if tab == 0 {
                chatTab
            } else if model.showCodeWorkView {
                TrajectoryView(model: model)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .onChange(of: inspectorNav.picking) { picking in
            if !picking, inspectorNav.sessionId == model.chat?.sessionId {
                if case .panel(.inspector) = model.currentRoute { return }
                model.push(.panel(.inspector))
            }
        }
        .onChange(of: model.showDrawer) { show in
            if show && inspectorNav.picking { inspectorNav.cancel() }
        }
        .onChange(of: model.showCodeWorkView) { show in
            if !show { tab = 0 }
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
        .overlay {
            if let value = riskPermission {
                PermissionRiskDialog(
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
            mentionMenu.track(trigger: mentionTrigger)
        }
        .onChange(of: model.composerCursor) { _ in
            mentionMenu.track(trigger: mentionTrigger)
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
            tab = UITestLaunch.screen == "trajectory" || UITestLaunch.screen == "trajectoryDetail" ? 1 : 0
            openTurns = [:]
            openProcesses = [:]
            model.setViewedSession(desiredViewedSession)
        }
        .onAppear {
            switch UITestLaunch.screen {
            case "models": showModels = true
            case "permission": permissionMenuOpen = true
            case "trajectory", "trajectoryDetail": tab = 1
            case "slash":
                slashMenu.track(trigger: slashMenuTrigger(model.composerText))
            case "mention", "mentionFiltered":
                mentionMenu.track(trigger: mentionMenuTrigger(model.composerText, cursor: model.composerCursor))
            default: break
            }
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

    private func openFeedback(messageId: String, rating: String) {
        feedbackDraft = FeedbackDraft(messageId: messageId, rating: rating)
    }

    private var headerCrumbs: [ConversationHeaderCrumb] {
        conversationHeaderAncestry(
            sessions: model.sessions,
            sessionId: model.chat?.sessionId,
            currentTitle: headerTitle,
            newSession: L.newSession(),
            untitled: L.untitledSession()
        )
    }

    private var header: some View {
        VStack(spacing: CGFloat(conversationHeaderTabsMarginTopPoints)) {
            ConversationTitleRow(
                onOpenDrawer: { model.showDrawer = true },
                onOpenStart: {
                    if case .panel(.start) = model.currentRoute { return }
                    model.push(.panel(.start))
                },
                startDisabled: firstPromptBlocksComposerActions(model.firstPrompt)
            ) {
                if conversationHeaderShowsCrumbs(headerCrumbs) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(headerCrumbs.enumerated()), id: \.element.sessionId) { index, crumb in
                                if index > 0 {
                                    Text("/")
                                        .font(conversationHeaderTitleFont())
                                        .foregroundStyle(T.text3)
                                }
                                if crumb.current {
                                    Text(crumb.title)
                                        .font(conversationHeaderTitleFont())
                                        .foregroundStyle(crumb.subagent ? T.text2 : T.ink)
                                        .lineLimit(1)
                                } else {
                                    Button {
                                        model.openSession(crumb.sessionId)
                                    } label: {
                                        Text(crumb.title)
                                            .font(conversationHeaderTitleFont())
                                            .foregroundStyle(T.text2)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(sessionHierarchyAria(english: L.en))
                } else {
                    Text(headerTitle)
                        .font(conversationHeaderTitleFont())
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                        .frame(
                            minHeight: CGFloat(conversationHeaderTitleLineHeightPoints),
                            maxHeight: CGFloat(conversationHeaderTitleLineHeightPoints),
                            alignment: .center
                        )
                        .accessibilityIdentifier(conversationHeaderTitleIdentifier())
                }
            }
            tabs
        }
        .modifier(ConversationHeaderBox(blank: false))
    }

    private var tabs: some View {
        HStack(alignment: .top, spacing: CGFloat(conversationHeaderTabGapPoints)) {
            tabChip(0, L.chatTab())
            if model.showCodeWorkView {
                tabChip(1, TrajL.viewTrajectory)
            }
            Spacer(minLength: 0)
            if let sessionId = model.chat?.sessionId {
                JobsAction(model: model, sessionId: sessionId)
            }
        }
    }

    private func tabChip(_ index: Int, _ title: String) -> some View {
        let selected = tab == index
        return Button { tab = index } label: {
            Text(title)
                .font(conversationHeaderTabFont())
                .foregroundStyle(selected ? T.businessPrimary : T.text3)
                .frame(height: CGFloat(conversationHeaderTabLineHeightPoints), alignment: .center)
                .padding(.bottom, CGFloat(conversationHeaderTabPaddingBottomPoints))
                .overlay(alignment: .bottom) {
                    if selected {
                        T.businessPrimary
                            .frame(height: CGFloat(conversationHeaderTabUnderlineHeightPoints))
                            .offset(y: CGFloat(conversationHeaderTabUnderlineOverflowPoints))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier(index == 0 ? "chatTab.chat" : "chatTab.trajectory")
    }

    private var sessionQuestion: UserQuestion? {
        model.userQuestions.first { model.chat != nil && ($0.sessionId == nil || $0.sessionId == model.chat?.sessionId) }
    }

    private var sessionApproval: Approval? {
        model.approvals.first { model.chat != nil && ($0.sessionId == nil || $0.sessionId == model.chat?.sessionId) }
    }

    private var questionVisible: Bool {
        guard let question = sessionQuestion else { return false }
        return !question.questions.isEmpty && !userQuestionIsCollapsed(
            questionId: question.questionId,
            callId: question.callId,
            hiddenId: model.hiddenQuestionId
        )
    }

    private var slashTrigger: ComposerTrigger? { slashMenuTrigger(model.composerText) }

    private var mentionTrigger: ComposerTrigger? {
        mentionMenuTrigger(model.composerText, cursor: model.composerCursor)
    }

    private var commandMenuVisible: Bool {
        !firstPromptBlocksComposerActions(model.firstPrompt) && slashMenu.isVisible(trigger: slashTrigger)
    }

    private var mentionMenuVisible: Bool {
        !firstPromptBlocksComposerActions(model.firstPrompt) && mentionMenu.isVisible(trigger: mentionTrigger)
    }

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
                    } else if mentionMenuVisible {
                        mentionMenuLayer(maxHeight: max(0, geo.size.height - 8))
                    }
                }
            }
            if !questionVisible && sessionApproval == nil {
                if firstPromptBlocksComposerActions(model.firstPrompt) {
                    Text(firstPromptSendingLabel(english: L.en))
                        .font(.caption)
                        .foregroundStyle(T.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .accessibilityIdentifier("firstPromptStatus")
                }
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
                .onTapGesture {
                    // Blank space outside the menu: close it and drop the IME.
                    dismissCommandMenu()
                    Keyboard.dismiss()
                }
            commandMenu(maxHeight: maxHeight)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
                .frame(height: maxHeight, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mentionMenuLayer(maxHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissMentionMenu()
                    Keyboard.dismiss()
                }
            mentionMenuPanel(maxHeight: maxHeight)
                .padding(.horizontal, 14)
                .padding(.bottom, CGFloat(mentionMenuGapAboveComposerPoints))
                .frame(height: maxHeight, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mentionMenuPanel(maxHeight: CGFloat) -> some View {
        MentionMenuOverlay(
            model: model,
            host: commandHost,
            query: mentionTrigger?.query ?? "",
            quoted: mentionTrigger?.quoted == true,
            availableHeight: maxHeight,
            onPick: { row in
                model.insertMention(row.mention)
                mentionMenu.closeAfterPick(trigger: mentionTrigger)
            },
            onDrill: { token in
                model.insertMention(token, appendSpace: false, drilled: true)
                if let trigger = mentionMenuTrigger(model.composerText, cursor: model.composerCursor) {
                    model.mentionQuery = trigger.query
                    model.fetchMentions(query: trigger.query, quoted: trigger.quoted)
                }
            },
            onDismiss: { dismissMentionMenu() }
        )
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
            onPerm: {},
            onModel: { if model.isOnline { showModels = true } },
            onExport: { model.exportSession() },
            onSelectPermission: { value in
                if value == "danger-full-access" || value == "auto" {
                    riskPermission = value
                } else {
                    model.setPermission(value) { _ in }
                }
            }
        )
    }

    private func dismissCommandMenu() {
        // Picking a row / Escape keeps the composer focused (desktop
        // CommandMenu): `/skill ` and `/goal ` are typed into right after.
        slashMenu.dismiss(trigger: slashTrigger)
    }

    private func dismissMentionMenu() {
        mentionMenu.dismiss(trigger: mentionTrigger)
    }

    private func dismissOpenComposerMenu() {
        if commandMenuVisible {
            dismissCommandMenu()
        } else if mentionMenuVisible {
            dismissMentionMenu()
        }
    }

    private func submitCommandMenuOrSend() {
        if firstPromptBlocksComposerActions(model.firstPrompt) { return }
        if commandMenuVisible || mentionMenuVisible {
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
                    get: { model.questionDrafts[question.questionId] ?? [:] },
                    set: { model.questionDrafts[question.questionId] = $0 }
                ),
                index: Binding(
                    get: { model.questionPageIndex[question.questionId] ?? 0 },
                    set: { model.questionPageIndex[question.questionId] = $0 }
                ),
                enabled: model.isOnline,
                onDismiss: {
                    model.hiddenQuestionId = userQuestionCollapseId(
                        questionId: question.questionId,
                        callId: question.callId
                    )
                },
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
            firstPromptVisibleItems(chatItems: model.chat?.items ?? [], prompt: model.firstPrompt),
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
            .accessibilityIdentifier("chatTranscript")
            .dshDismissesKeyboardOnScrollAndTap()
            .onAppear {
                if inspectorNav.picking { return }
                proxy.scrollTo("bottom", anchor: .bottom)
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
            interceptKeys: (commandMenuVisible || mentionMenuVisible) && riskPermission == nil,
            resignKeyboard: (permissionRiskDismissesKeyboard && riskPermission != nil)
                || (openingSessionDrawerResignsComposer && model.showDrawer),
            focusToken: composerFocus,
            onPlus: {
                if firstPromptBlocksComposerActions(model.firstPrompt) { return }
                slashMenu.togglePlus(trigger: slashTrigger)
                if slashMenu.isVisible(trigger: slashTrigger) {
                    composerFocus += 1
                }
            },
            onSelectPermission: { value in
                if value == "danger-full-access" || value == "auto" {
                    riskPermission = value
                } else {
                    model.setPermission(value) { _ in }
                }
            },
            modelMenuOpen: $showModels,
            permissionMenuOpen: $permissionMenuOpen,
            onSend: { submitCommandMenuOrSend() },
            onCommandReturn: { commandHost.requestEnter() },
            onCommandMove: { commandHost.requestMove($0) },
            onCommandEscape: { dismissOpenComposerMenu() },
            onCommandTab: { commandHost.requestTab() }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(chatComposerIdentifier())
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
                    .foregroundStyle(T.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
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
            switch notice.kind {
            case .maxTokens:
                TurnMaxTokensRow()
            case .stopped:
                Text(messageStopped(english: L.en))
                    .font(.footnote)
                    .foregroundStyle(T.warnText)
            case .generic:
                MessageRow(item: .notice(notice), model: model, onOpenFeedback: onOpenFeedback)
            }
        case .deliverable(let deliverable):
            MessageRow(item: .deliverable(deliverable), model: model, onOpenFeedback: onOpenFeedback)
        case .retry(let retry):
            RetryRow(item: retry)
        case .turnFailure(let failure):
            TurnFailureRow(item: failure)
        case .tool(let tool):
            ToolCard(tool: tool, reopenLabel: askRowActionLabel(for: tool), onTap: { tapTool(tool) })
        case .reasoning(let reasoning):
            ReasoningRow(reasoning: reasoning)
        case .process(let proc):
            ProcessGroupView(
                proc: proc,
                openTurns: $openTurns,
                openProcesses: $openProcesses,
                reopenLabel: { askRowActionLabel(for: $0) },
                onTool: { tapTool($0) }
            )
        case .turnTrigger(let item):
            TurnTriggerRow(item: item)
        case .compacted(let item):
            CompactionRow(item: item)
        case .command(let item):
            CommandRow(item: item)
        case .questionReply(let item):
            QuestionReplyRow(item: item)
        case .context(let item):
            ContextToolChangeRow(item: item)
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

    private func askAnswerable(for tool: Item.Tool) -> Bool {
        askToolRowIsAnswerable(
            callId: tool.callId,
            questionId: nil,
            activeCallIds: model.userQuestions.compactMap { $0.callId ?? $0.questionId }
        )
    }

    private func askRowActionLabel(for tool: Item.Tool) -> String? {
        askToolRowChrome(
            name: tool.name,
            status: tool.status,
            error: tool.error,
            result: tool.result,
            answerable: askAnswerable(for: tool),
            english: L.en
        )?.actionLabel
    }

    private func tapTool(_ tool: Item.Tool) {
        if askToolRowChrome(
            name: tool.name,
            status: tool.status,
            error: tool.error,
            result: tool.result,
            answerable: askAnswerable(for: tool),
            english: L.en
        )?.actionLabel != nil {
            model.hiddenQuestionId = nil
            return
        }
        onTool(tool)
    }
}

/// Desktop `ui-chat` `CompactionItem`. Touch has no hover, so the context/API
/// icon stays (desktop CSS swaps it for a chevron on hover).
private struct CompactionRow: View {
    let item: Item.Compacted
    @State private var expanded = false

    var body: some View {
        let expandable = compactionRowIsExpandable(item)
        let open = expandable && expanded
        let title = compactionRowTitle(sourceCommandId: item.sourceCommandId, english: L.en)
        let summary = compactionRowSummary(item: item, english: L.en)
        VStack(alignment: .leading, spacing: 0) {
            header(title: title, summary: summary, expandable: expandable)
            if open, let text = item.summary {
                MarkdownView(
                    source: text,
                    wrapCode: AppModel.shared.codeWordWrap,
                    bodyColor: T.text3,
                    variant: .compact
                )
                .padding(.leading, CGFloat(reasoningBodyLeadingPoints))
                .padding(.vertical, CGFloat(reasoningBodyVerticalPaddingPoints))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func header(title: String, summary: String, expandable: Bool) -> some View {
        let chrome = HStack(spacing: 0) {
            OfficialGlyph(
                kind: .apiOutline,
                size: CGFloat(reasoningIconSizePoints),
                color: T.text3
            )
            .frame(
                width: CGFloat(reasoningLeadingBoxPoints),
                height: CGFloat(reasoningLeadingBoxPoints)
            )
            .padding(.trailing, CGFloat(reasoningRowGapPoints))
            Text(title)
                .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                .foregroundStyle(T.text3)
                .fixedSize(horizontal: true, vertical: false)
            Circle()
                .fill(T.caption)
                .frame(
                    width: CGFloat(reasoningPreviewSeparatorSizePoints),
                    height: CGFloat(reasoningPreviewSeparatorSizePoints)
                )
                .padding(.horizontal, CGFloat(reasoningPreviewSeparatorSpacingPoints))
                .accessibilityHidden(true)
            Text(summary)
                .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                .foregroundStyle(T.text3)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
        .contentShape(Rectangle())

        if expandable {
            Button { expanded.toggle() } label: { chrome }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(title)
                .accessibilityValue(summary)
        } else {
            chrome
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(title) \(summary)")
        }
    }
}

/// Desktop `ui-chat` `GenericCommandCard` / `CompactionCommandCard` running chrome.
/// Compact success with a checkpoint is `CompactionItem`, not this row.
private struct CommandRow: View {
    let item: Item.Command
    @State private var expanded = false

    var body: some View {
        let expandable = commandRowIsExpandable(item)
        let open = expandable && expanded
        let title = commandRowTitle(item, english: L.en)
        let summary = commandRowSummary(item, english: L.en)
        let running = commandRowIsRunning(item)
        let error = commandRowIsError(item)
        let summaryColor = error ? T.err : T.text3
        VStack(alignment: .leading, spacing: 0) {
            header(title: title, summary: summary, expandable: expandable, running: running, color: summaryColor)
            if open, let text = item.outcomeText {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(error ? T.err : T.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: 260, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(T.codeBlock, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(T.border, lineWidth: 0.5)
                    )
                    .padding(.leading, 4)
                    .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(commandRowStateLabel(item, english: L.en).map { "\($0) \(title)" } ?? title)
        .accessibilityValue(summary)
    }

    @ViewBuilder
    private func header(
        title: String,
        summary: String,
        expandable: Bool,
        running: Bool,
        color: Color
    ) -> some View {
        let chrome = HStack(spacing: 0) {
            OfficialGlyph(
                kind: .apiOutline,
                size: CGFloat(reasoningIconSizePoints),
                color: T.text3
            )
            .frame(
                width: CGFloat(reasoningLeadingBoxPoints),
                height: CGFloat(reasoningLeadingBoxPoints)
            )
            .padding(.trailing, CGFloat(reasoningRowGapPoints))
            Text(title)
                .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                .fontWeight(.regular)
                .foregroundStyle(T.text3)
                .fixedSize(horizontal: true, vertical: false)
            Circle()
                .fill(T.caption)
                .frame(
                    width: CGFloat(reasoningPreviewSeparatorSizePoints),
                    height: CGFloat(reasoningPreviewSeparatorSizePoints)
                )
                .padding(.horizontal, CGFloat(reasoningPreviewSeparatorSpacingPoints))
                .accessibilityHidden(true)
            TextShimmer(active: running) {
                Text(summary)
                    .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
        .contentShape(Rectangle())

        if expandable {
            Button { expanded.toggle() } label: { chrome }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
        } else {
            chrome
                .accessibilityElement(children: .contain)
        }
    }
}

/// Desktop `ui-chat` `ContextInjectionRow` tool-addition / tool-removal chrome.
/// Touch has no hover, so the browse icon stays.
private struct ContextToolChangeRow: View {
    let item: Item.Context
    @State private var expanded = false

    var body: some View {
        let exclusive = contextToolChangeIsExclusive(item)
        let added = item.toolAdditions
        let removed = item.toolRemovals
        let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandable = exclusive
            ? contextToolChangeIsExpandable(added: added, removed: removed)
            : !text.isEmpty
        let open = expandable && expanded
        let title = contextRowTitle(item: item, english: L.en)
        let summary = exclusive ? contextToolChangeSummary(item: item, english: L.en) : nil
        VStack(alignment: .leading, spacing: 0) {
            header(title: title, summary: summary, expandable: expandable)
            if open {
                VStack(alignment: .leading, spacing: 2) {
                    if exclusive {
                        if let line = contextToolChangeAddedLine(names: added, english: L.en) {
                            Text(line)
                        }
                        if let line = contextToolChangeRemovedLine(names: removed, english: L.en) {
                            Text(line)
                        }
                    } else {
                        Text(item.text)
                    }
                }
                .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                .foregroundStyle(T.text3)
                .padding(.leading, CGFloat(reasoningBodyLeadingPoints))
                .padding(.vertical, CGFloat(reasoningBodyVerticalPaddingPoints))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func header(title: String, summary: String?, expandable: Bool) -> some View {
        let chrome = HStack(spacing: 0) {
            OfficialGlyph(
                kind: .browseOutline,
                size: CGFloat(reasoningIconSizePoints),
                color: T.text3
            )
            .frame(
                width: CGFloat(reasoningLeadingBoxPoints),
                height: CGFloat(reasoningLeadingBoxPoints)
            )
            .padding(.trailing, CGFloat(reasoningRowGapPoints))
            Text(title)
                .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                .foregroundStyle(T.text3)
                .lineLimit(1)
            if let summary {
                Circle()
                    .fill(T.caption)
                    .frame(
                        width: CGFloat(reasoningPreviewSeparatorSizePoints),
                        height: CGFloat(reasoningPreviewSeparatorSizePoints)
                    )
                    .padding(.horizontal, CGFloat(reasoningPreviewSeparatorSpacingPoints))
                    .accessibilityHidden(true)
                Text(summary)
                    .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                    .foregroundStyle(T.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
        .contentShape(Rectangle())

        if expandable {
            Button { expanded.toggle() } label: { chrome }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(title)
                .accessibilityValue(summary ?? "")
        } else {
            chrome
                .accessibilityElement(children: .contain)
                .accessibilityLabel(summary.map { "\(title) \($0)" } ?? title)
        }
    }
}

private struct TurnTriggerRow: View {
    let item: Item.Context
    @State private var open = false

    var body: some View {
        let provider = turnTriggerProvider(item.messageSourceJson)
        let icon = turnTriggerIcon(sourceKind: item.sourceKind, provider: provider)
        let title = turnTriggerTitle(sourceKind: item.sourceKind, provider: provider, english: L.en)
        VStack(alignment: .leading, spacing: 0) {
            Button { open.toggle() } label: {
                HStack(spacing: CGFloat(turnTriggerHeaderGapPoints)) {
                    OfficialGlyph(
                        kind: OfficialGlyph.turnTrigger(icon),
                        size: CGFloat(turnTriggerIconSizePoints),
                        color: T.text3
                    )
                    Text(title)
                        .font(.system(size: CGFloat(turnTriggerTitleFontSizePoints)))
                        .foregroundStyle(T.text2)
                    Spacer(minLength: 8)
                    if let at = item.at {
                        Text(formatMessageClock(at, english: L.en))
                            .font(.system(size: CGFloat(turnTriggerTimeFontSizePoints)))
                            .foregroundStyle(T.text3)
                    }
                    OfficialGlyph(
                        kind: .chevronDown,
                        size: CGFloat(turnTriggerChevronSizePoints),
                        color: T.text3
                    )
                    .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, CGFloat(turnTriggerHeaderPaddingHorizontalPoints))
                .padding(.vertical, CGFloat(turnTriggerHeaderPaddingVerticalPoints))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    Text(turnTriggerExplanation(english: L.en))
                        .font(.caption)
                        .foregroundStyle(T.text3)
                    if !item.text.isEmpty {
                        Text(item.text).font(.subheadline).foregroundStyle(T.ink)
                    }
                }
                .padding(.leading, CGFloat(turnTriggerBodyPaddingLeadingPoints))
                .padding(.trailing, CGFloat(turnTriggerHeaderPaddingHorizontalPoints))
                .padding(.bottom, CGFloat(turnTriggerBodyPaddingBottomPoints))
            }
        }
        .background(
            T.turnTriggerBg,
            in: RoundedRectangle(cornerRadius: CGFloat(turnTriggerRadiusPoints), style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(turnTriggerRadiusPoints), style: .continuous)
                .stroke(T.borderL1, lineWidth: CGFloat(turnTriggerBorderWidthPoints))
        )
        .accessibilityIdentifier("turnTrigger")
    }
}

private struct ProcessGroupView: View {
    let proc: ChatRow.Process
    @Binding var openTurns: [String: Bool]
    @Binding var openProcesses: [String: Bool]
    var reopenLabel: (Item.Tool) -> String? = { _ in nil }
    var onTool: (Item.Tool) -> Void

    var body: some View {
        let binding = proc.turnSummary ? $openTurns : $openProcesses
        let open = binding.wrappedValue[proc.key] ?? proc.defaultOpen
        VStack(alignment: .leading, spacing: 6) {
            Button {
                binding.wrappedValue[proc.key] = !open
            } label: {
                if proc.turnSummary {
                    HStack(spacing: 4) {
                        Text(proc.title)
                            .font(LocalFonts.text())
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                        if proc.canCollapse {
                            OfficialGlyph(kind: .chevronDown, size: 14, color: T.text3)
                                .rotationEffect(.degrees(open ? 180 : 0))
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 33)
                } else {
                    HStack(spacing: CGFloat(reasoningRowGapPoints)) {
                        processLeading(kind: proc.activityKind, open: open)
                        TextShimmer(active: !proc.closed) {
                            Text(processGroupHeaderTitle(label: proc.title, detail: proc.detail))
                                .font(LocalFonts.text())
                                .foregroundStyle(T.text3)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 24)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .disabled(!proc.canCollapse && proc.turnSummary)
            if open && !proc.members.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(proc.members.enumerated()), id: \.element.key) { _, member in
                        switch member {
                        case .reasoning(let reasoning): ReasoningRow(reasoning: reasoning)
                        case .tool(let tool):
                            ToolCard(
                                tool: tool,
                                reopenLabel: reopenLabel(tool),
                                onTap: { onTool(tool) }
                            )
                        default: EmptyView()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func processLeading(kind: String, open: Bool) -> some View {
        ZStack {
            if open {
                OfficialGlyph(kind: .chevronUp, size: 14, color: T.text3)
            } else if kind == "thinking" {
                OfficialGlyph(kind: .think, size: CGFloat(reasoningIconSizePoints), color: T.text3)
            } else {
                OfficialGlyph(kind: OfficialGlyph.process(kind), size: 14, color: T.text3)
            }
        }
        .frame(width: CGFloat(reasoningLeadingBoxPoints), height: CGFloat(reasoningLeadingBoxPoints))
    }
}

private struct ReasoningRow: View {
    let reasoning: Item.Reasoning
    @State private var open = reasoningDefaultExpanded

    var body: some View {
        let preview = reasoningPreview(reasoning.text, running: reasoning.live)
        let policy = presentationPolicyFor(AppModel.shared.transcriptView)
        let showPreview = !open && !preview.isEmpty && (reasoning.live || policy.settledReasoningPreview)
        VStack(alignment: .leading, spacing: 0) {
            Button { open.toggle() } label: {
                HStack(spacing: CGFloat(reasoningRowGapPoints)) {
                    ZStack {
                        if open && reasoningChevronReplacesIconWhenExpanded {
                            OfficialGlyph(kind: .chevronUp, size: 14, color: T.text3)
                        } else {
                            OfficialGlyph(kind: .think, size: CGFloat(reasoningIconSizePoints), color: T.text3)
                        }
                    }
                    .frame(width: CGFloat(reasoningLeadingBoxPoints), height: CGFloat(reasoningLeadingBoxPoints))
                    TextShimmer(active: reasoning.live) {
                        HStack(spacing: 0) {
                            Text(reasoningTitle(english: L.en))
                                .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                                .foregroundStyle(T.text3)
                            if showPreview {
                                Circle()
                                    .fill(T.caption)
                                    .frame(
                                        width: CGFloat(reasoningPreviewSeparatorSizePoints),
                                        height: CGFloat(reasoningPreviewSeparatorSizePoints)
                                    )
                                    .padding(.horizontal, CGFloat(reasoningPreviewSeparatorSpacingPoints))
                                Text(preview)
                                    .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                                    .foregroundStyle(T.text3)
                                    .lineLimit(1)
                                    .mask(
                                        LinearGradient(
                                            stops: reasoning.live
                                                ? [
                                                    .init(color: .white, location: 0),
                                                    .init(color: .white, location: 0.72),
                                                    .init(color: .clear, location: 1),
                                                ]
                                                : [.init(color: .white, location: 0), .init(color: .white, location: 1)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reasoningTitle(english: L.en))
            if open {
                MarkdownView(
                    source: reasoning.text,
                    streaming: reasoning.live,
                    wrapCode: AppModel.shared.codeWordWrap,
                    bodyColor: T.text3,
                    variant: .compact
                )
                .padding(.leading, CGFloat(reasoningBodyLeadingPoints))
                .padding(.vertical, CGFloat(reasoningBodyVerticalPaddingPoints))
            }
        }
    }
}

private struct ToolCard: View {
    let tool: Item.Tool
    var reopenLabel: String? = nil
    var onTap: () -> Void

    var body: some View {
        let base = toolProcessSummary(tool, en: L.en)
        let chrome = askToolRowChrome(
            name: tool.name,
            status: tool.status,
            error: tool.error,
            result: tool.result,
            answerable: reopenLabel != nil,
            english: L.en
        )
        let summary = ToolProcessSummary(
            title: chrome?.title ?? base.title,
            summary: chrome?.summary ?? base.summary,
            icon: base.icon
        )
        let tint: Color = {
            switch tool.status {
            case .error: return T.err
            case .awaitingApproval: return T.warnText
            default: return T.text3
            }
        }()
        Button(action: onTap) {
            HStack(spacing: CGFloat(reasoningRowGapPoints)) {
                OfficialGlyph(kind: OfficialGlyph.tool(summary.icon), size: 14, color: tint)
                    .frame(width: CGFloat(reasoningLeadingBoxPoints), height: CGFloat(reasoningLeadingBoxPoints))
                TextShimmer(active: tool.status == .running || tool.status == .preparing) {
                    HStack(spacing: CGFloat(reasoningPreviewSeparatorSpacingPoints)) {
                        Text(summary.title)
                            .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                        if let line = summary.summary {
                            Circle().fill(T.caption).frame(width: 2, height: 2)
                            Text(line)
                                .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                                .foregroundStyle(tint)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                if let reopenLabel {
                    Text(reopenLabel)
                        .font(LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))))
                        .foregroundStyle(T.accent)
                        .lineLimit(1)
                }
            }
            .padding(tool.status == .awaitingApproval ? 8 : 0)
            .background(tool.status == .awaitingApproval ? T.warnTint : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .disabled(tool.status == .preparing)
        .accessibilityValue(toolRowStateStatus(tool.status, english: L.en) ?? "")
    }
}

/// Desktop `.userStack` `max-width: min(calc(var(--dsh-chat-content-width,748px) * .702), 82%)`.
/// Reports the child's hugging width so short CJK bubbles do not stretch.
private struct UserMessageStackCap<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        UserMessageStackCapLayout {
            content
        }
    }
}

private struct UserMessageStackCapLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let maxW = capWidth(proposal.width)
        let size = child.sizeThatFits(ProposedViewSize(width: maxW, height: proposal.height))
        return CGSize(width: min(size.width, maxW), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        child.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }

    private func capWidth(_ proposed: CGFloat?) -> CGFloat {
        if let proposed, proposed > 0, proposed.isFinite {
            return CGFloat(userMessageStackMaxWidth(columnWidth: Double(proposed)))
        }
        return CGFloat(userMessageStackAbsoluteMaxWidthPoints)
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
            VStack(alignment: .trailing, spacing: CGFloat(userMessageRowGapPoints)) {
                UserMessageStackCap {
                    VStack(alignment: .trailing, spacing: CGFloat(userMessageStackGapPoints)) {
                        if let sessionId = model.chat?.sessionId, !user.imageRefs.isEmpty {
                            ForEach(Array(user.imageRefs.enumerated()), id: \.offset) { _, ref in
                                ImageBubble(sessionId: sessionId, ref: ref)
                            }
                        }
                        if !user.text.isEmpty {
                            UserMentionText(text: user.text, color: T.ink, pending: user.pending)
                                .padding(.vertical, CGFloat(userMessageBubblePaddingVerticalPoints))
                                .padding(.horizontal, CGFloat(userMessageBubblePaddingHorizontalPoints))
                                .background(
                                    T.bubble,
                                    in: RoundedRectangle(
                                        cornerRadius: CGFloat(userMessageBubbleRadiusPoints),
                                        style: .continuous
                                    )
                                )
                                // iOS 18 XCUITest drops nested identifiers when the
                                // wrapping view also has one, even with `.contain`
                                // or an extra HStack. Overlay is a sibling with the
                                // same hugging bubble frame.
                                .overlay {
                                    Color.clear
                                        .accessibilityElement()
                                        .accessibilityIdentifier(userMessageBubbleIdentifier())
                                        .allowsHitTesting(false)
                                }
                        }
                        if let summary = referenceSummaryText(labels: user.referenceLabels, english: L.en) {
                            Text(summary)
                                .font(.system(size: 13))
                                .foregroundStyle(T.text3)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                MessageActions(
                    text: user.text,
                    timeMs: user.at,
                    clock: .end,
                    trailing: true,
                    showsCopy: userMessageShowsPersistentCopy,
                    topPadding: 0
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
            Text(noticeChatTitle(notice, english: L.en)).font(.footnote).foregroundStyle(T.warnText)
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
        case .context, .system, .compacted, .retry, .turnFailure, .changes, .command, .questionReply:
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
        let canFork = model.firstPrompt == nil && model.ops.contains("sessions.fork")
        let endSeq = turn.flatMap { owned in model.chat?.turns.first { $0.turn == owned }?.endSeq }
        let branch = messageBranchChrome(canFork: canFork, turnEndSeq: endSeq)
        return MessageActions(
            text: text.text,
            timeMs: text.at,
            clock: .end,
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
            branch: branch,
            onBranch: {
                guard let seq = branch?.atSeq else { return }
                model.forkCurrent(atSeq: seq)
            },
            usageAction: {
                if let usage, let turn { return { TurnUsageAction(turn: turn, usage: usage) } }
                return nil
            }()
        )
    }
}

private enum MessageClock { case start, end }

/// Desktop MessageIconActions: copy → extraActions (like/dislike) → branch → usage → clock.
private struct MessageActions: View {
    let text: String
    let timeMs: Int64?
    let clock: MessageClock
    var messageId: String? = nil
    var rating: String? = nil
    var onLike: (() -> Void)? = nil
    var onDislike: (() -> Void)? = nil
    var branch: MessageBranchChrome? = nil
    var onBranch: (() -> Void)? = nil
    var usageAction: (() -> TurnUsageAction)? = nil
    var trailing = false
    var showsCopy = true
    var topPadding: CGFloat = 4
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            if clock == .start, let timeMs {
                Text(formatMessageClock(timeMs, english: L.en))
                    .font(.system(size: 13))
                    .foregroundStyle(T.text3)
                    .padding(.trailing, 8)
            }
            if showsCopy {
                iconButton(
                    official: copied ? .checkOutline : .copyOutline,
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
            }
            if let onLike, let onDislike {
                iconButton(
                    official: rating == "positive" ? .likeFill : .likeOutline,
                    label: rating == "positive" ? L.undoRating() : L.like(),
                    action: onLike
                )
                iconButton(
                    official: rating == "negative" ? .dislikeFill : .dislikeOutline,
                    label: rating == "negative" ? L.undoRating() : L.dislike(),
                    action: onDislike
                )
            }
            if let branch {
                iconButton(
                    official: .branchOutline,
                    label: messageBranchLabel(unavailable: branch.unavailable, english: L.en),
                    accessibilityLabel: L.branch(),
                    enabled: branch.enabled,
                    faded: branch.unavailable,
                    action: { onBranch?() }
                )
            }
            if let usageAction {
                usageAction()
            }
            Spacer(minLength: 0)
            if clock == .end, let timeMs {
                Text(formatMessageClock(timeMs, english: L.en))
                    .font(.system(size: 12))
                    .foregroundStyle(T.text3)
                    .padding(.leading, 8)
            }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: (trailing || clock == .start) ? .trailing : .leading)
        .padding(.top, topPadding)
    }

    private func iconButton(
        official: OfficialGlyph.Kind? = nil,
        system: String? = nil,
        label: String,
        accessibilityLabel: String? = nil,
        enabled: Bool = true,
        faded: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let official {
                    OfficialGlyph(kind: official, size: 16, color: T.text3)
                } else if let system {
                    Image(systemName: system)
                        .font(.system(size: 15))
                        .foregroundStyle(T.text3)
                }
            }
            .opacity(faded ? 0.4 : 1)
            .frame(width: 36, height: 48)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel ?? label)
        .accessibilityHint(faded ? label : "")
    }
}

/// XCUITest host for InputBar `.add` / `.primary`. Landing's UITextView +
/// former GeometryReader dropped the SwiftUI plus/send Buttons from the
/// snapshot; a UIKit element on the composer card stays queryable.
private struct ComposerAddA11yHost: UIViewRepresentable {
    var identifier: String
    var label: String
    var onActivate: () -> Void

    func makeUIView(context: Context) -> ComposerAddA11yView {
        let view = ComposerAddA11yView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
        view.accessibilityIdentifier = identifier
        view.accessibilityLabel = label
        view.onActivate = onActivate
        return view
    }

    func updateUIView(_ view: ComposerAddA11yView, context: Context) {
        view.accessibilityIdentifier = identifier
        view.accessibilityLabel = label
        view.onActivate = onActivate
    }
}

private final class ComposerAddA11yView: UIView {
    var onActivate: () -> Void = {}

    override func accessibilityActivate() -> Bool {
        onActivate()
        return true
    }
}

struct ComposerView: View {
    @ObservedObject var model: AppModel
    var interceptKeys = false
    var resignKeyboard = false
    var focusToken = 0
    var heroPlaceholder = false
    var onPlus: () -> Void = {}
    var onPerm: () -> Void = {}
    var onSelectPermission: (String) -> Void = { _ in }
    @Binding var modelMenuOpen: Bool
    @Binding var permissionMenuOpen: Bool
    var onSend: () -> Void = {}
    var onCommandReturn: () -> Void = {}
    var onCommandMove: (Int) -> Void = { _ in }
    var onCommandEscape: () -> Void = {}
    var onCommandTab: () -> Void = {}

    private var references: [ComposerReference] {
        mentionProjection(model.composerText, cursor: model.composerCursor).references.map(\.reference)
    }
    private var filesReady: Bool {
        model.pendingAttaches.allSatisfy { $0.status != .uploading && $0.status != .failed && $0.status != .pending }
    }
    private var hasPending: Bool { !model.pendingAttaches.isEmpty }
    private var needsWorkspace: Bool {
        landingComposerNeedsWorkspace(
            selectedWorkspaceId: model.draftWorkspaceId ?? model.workspaces.first?.workspaceId,
            workspaceCount: model.workspaces.count
        )
    }
    private var canSend: Bool {
        model.isOnline
            && !needsWorkspace
            && filesReady
            && !firstPromptBlocksComposerActions(model.firstPrompt)
            && (!model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasPending)
    }
    private var runningIdle: Bool {
        model.chat?.running == true && model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasPending
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: CGFloat(composerInnerSpacingPoints)) {
                if hasPending { attachList }
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
                    cursor: $model.composerCursor,
                    placeholder: composerPlaceholderText(
                        kind: composerPlaceholderKind(
                            parentOffline: model.isParentOffline,
                            unavailable: model.chat != nil && !model.isOnline,
                            canSteerQueue: model.canSteerQueue,
                            planMode: model.chat?.planMode == true,
                            needsWorkspace: needsWorkspace,
                            hero: heroPlaceholder
                        ),
                        english: L.en
                    ),
                    interceptKeys: interceptKeys,
                    resignKeyboard: resignKeyboard,
                    heroPlaceholder: heroPlaceholder,
                    focusToken: focusToken,
                    onReturn: onCommandReturn,
                    onMove: onCommandMove,
                    onEscape: onCommandEscape,
                    onTab: onCommandTab,
                    onChord: { model.submitComposer(gesture: .chord) }
                )
                    .fixedSize(horizontal: false, vertical: true)
                    .onAppear { syncMentions() }
                    .onChange(of: model.composerText) { _ in syncMentions() }
                    .onChange(of: model.composerCursor) { _ in syncMentions() }
                    .overlay(alignment: .topLeading) {
                        ForEach(Array(references.enumerated()), id: \.offset) { _, ref in
                            MentionChipLabel(ref: ref, composer: true)
                                .frame(width: 1, height: 1)
                                .opacity(0.01)
                                .allowsHitTesting(false)
                        }
                    }
                HStack(spacing: 8) {
                    Button(action: onPlus) {
                        OfficialGlyph(
                            kind: .plusOutline,
                            size: CGFloat(composerAddIconSizePoints),
                            color: T.ink
                        )
                        .frame(width: CGFloat(composerAddButtonPoints), height: CGFloat(composerAddButtonPoints))
                        .background(T.selector, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(firstPromptBlocksComposerActions(model.firstPrompt))
                    .accessibilityHidden(true)
                    if !permissionChipRequiresCatalog || model.permissionCatalog != nil {
                        if let perm = model.sessionPermission ?? model.draftPermission ?? (heroPlaceholder ? model.defaultPermission : nil), !perm.isEmpty {
                            PermissionChipMenu(
                                current: perm,
                                catalog: model.permissionCatalog,
                                loading: model.permissionCatalogLoading,
                                enabled: model.isOnline && !model.permissionChanging && !firstPromptBlocksComposerActions(model.firstPrompt),
                                onSelect: onSelectPermission,
                                open: $permissionMenuOpen
                            )
                        }
                    }
                    if planChipLivesInComposerModesRow, model.chat?.planMode == true {
                        Button {
                            model.executeCommand("/plan off")
                        } label: {
                            HStack(spacing: 4) {
                                OfficialGlyph(
                                    kind: .planOutline,
                                    size: CGFloat(planChipIconSizePoints),
                                    color: T.accent
                                )
                                Text(L.planChip())
                                    .font(.system(size: CGFloat(planChipFontSizePoints), weight: .medium))
                            }
                            .foregroundStyle(T.accent)
                            .padding(.horizontal, 8)
                            .frame(minHeight: CGFloat(planChipHeightPoints))
                            .background(T.tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(L.planModeOn())
                        .accessibilityHint(planChipTitle(english: L.en))
                    }
                    ModelChipMenu(
                        catalog: model.catalog,
                        current: model.modelChoice,
                        loading: model.catalogLoading,
                        error: model.catalogError,
                        pending: model.modelPending,
                        enabled: model.isOnline && !firstPromptBlocksComposerActions(model.firstPrompt),
                        open: $modelMenuOpen,
                        onReload: { model.reloadModelCatalog() },
                        onPick: { choice, done in model.selectModel(choice, onComplete: done) }
                    )
                    if runningIdle {
                        Button(action: model.stopRun) {
                            OfficialGlyph(
                                kind: .stopRect,
                                size: CGFloat(composerStopIconSizePoints),
                                color: Color.white
                            )
                            .frame(width: CGFloat(composerSendButtonPoints), height: CGFloat(composerSendButtonPoints))
                        }
                        .background(T.accent, in: Circle())
                        .accessibilityLabel(composerStopLabel(english: L.en))
                        .accessibilityIdentifier(composerStopSymbol())
                    } else {
                        Button(action: onSend) {
                            OfficialGlyph(
                                kind: .send,
                                size: CGFloat(composerSendIconSizePoints),
                                color: Color.white
                            )
                            .frame(width: CGFloat(composerSendButtonPoints), height: CGFloat(composerSendButtonPoints))
                        }
                        .background(T.accent.opacity(canSend || interceptKeys ? 1 : 0.4), in: Circle())
                        .disabled(!canSend && !interceptKeys)
                        .accessibilityHidden(true)
                    }
                }
            }
            .padding(.top, CGFloat(composerCardPaddingTopPoints))
            .padding(.horizontal, CGFloat(composerCardPaddingHorizontalPoints))
            .padding(.bottom, CGFloat(composerCardPaddingBottomPoints))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.border, lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
            .onAppear { model.reloadPermissionCatalog() }
        }
        .background(T.surface)
        .overlay(alignment: .bottomLeading) {
            ComposerAddA11yHost(
                identifier: composerAddSymbol(),
                label: composerCommandsAria(english: L.en),
                onActivate: onPlus
            )
            .frame(width: CGFloat(composerAddButtonPoints), height: CGFloat(composerAddButtonPoints))
            .padding(.leading, 14 + CGFloat(composerCardPaddingHorizontalPoints))
            .padding(.bottom, 2 + CGFloat(composerCardPaddingBottomPoints))
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            if !runningIdle {
                ComposerAddA11yHost(
                    identifier: composerSendSymbol(),
                    label: L.busySendLabel(running: model.chat?.running == true, busy: model.busySend),
                    onActivate: onSend
                )
                .frame(width: CGFloat(composerSendButtonPoints), height: CGFloat(composerSendButtonPoints))
                .padding(.trailing, 14 + CGFloat(composerCardPaddingHorizontalPoints))
                .padding(.bottom, 2 + CGFloat(composerCardPaddingBottomPoints))
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if UITestLaunch.composerIme {
                HStack(spacing: 4) {
                    Button("setMarked") {
                        NotificationCenter.default.post(name: .dshComposerImeSetMarked, object: nil)
                    }
                    .accessibilityIdentifier("composerIme.setMarked")
                    Button("unmark") {
                        NotificationCenter.default.post(name: .dshComposerImeUnmark, object: nil)
                    }
                    .accessibilityIdentifier("composerIme.unmark")
                }
                .font(.system(size: 12))
                .padding(6)
                .background(T.fill2, in: RoundedRectangle(cornerRadius: 6))
            }
        }
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

    private func syncMentions() {
        if let trigger = mentionMenuTrigger(model.composerText, cursor: model.composerCursor) {
            let same = model.mentionQuery == trigger.query
            model.mentionQuery = trigger.query
            if !same {
                model.fetchMentions(query: trigger.query, quoted: trigger.quoted)
            }
        } else if model.mentionQuery != nil {
            model.mentionQuery = nil
        }
    }
}

/// Composer field that keeps first responder while the slash / mention menu
/// is open so the keyboard stays up; Return / arrows / Escape / Tab are
/// routed to the menu. Committed `@` tokens render as desktop chips.
private struct ComposerTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursor: Int
    var placeholder: String
    var interceptKeys: Bool
    var resignKeyboard: Bool = false
    var heroPlaceholder: Bool = false
    var focusToken: Int
    var onReturn: () -> Void
    var onMove: (Int) -> Void
    var onEscape: () -> Void
    var onTab: () -> Void = {}
    var onChord: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ComposerUITextView {
        let view = ComposerUITextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.isScrollEnabled = false
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityIdentifier = "composerInput"
        context.coordinator.startObserving(view)
        let placeholder = UILabel()
        placeholder.font = view.font
        placeholder.textColor = UIColor.placeholderText
        placeholder.numberOfLines = 0
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isAccessibilityElement = true
        placeholder.accessibilityIdentifier = "composerPlaceholder"
        view.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: view.textContainer.lineFragmentPadding),
            placeholder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: view.topAnchor),
        ])
        context.coordinator.placeholder = placeholder
        context.coordinator.render(view)
        return view
    }

    func updateUIView(_ view: ComposerUITextView, context: Context) {
        context.coordinator.parent = self
        view.onMove = onMove
        view.onEscape = onEscape
        view.onTab = onTab
        view.onChord = onChord
        view.lockFirstResponder = interceptKeys && !resignKeyboard
        view.interceptArrows = interceptKeys
        view.accessibilityIdentifier = "composerInput"
        if ImeComposition.shouldRewriteText(isMarked: view.markedTextRange != nil) {
            context.coordinator.render(view)
        }
        context.coordinator.applyPlaceholder(view)
        context.coordinator.refreshImeProbe(view)
        if resignKeyboard {
            if view.isFirstResponder { view.forceResign() }
        } else if focusToken != context.coordinator.focusToken {
            context.coordinator.focusToken = focusToken
            if focusToken > 0 {
                view.becomeFirstResponder()
            }
        }
    }

    static func dismantleUIView(_ view: ComposerUITextView, coordinator: Coordinator) {
        coordinator.stopObserving()
        view.forceResign()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ComposerUITextView, context: Context) -> CGSize? {
        let width = max(proposal.width ?? uiView.bounds.width, 1)
        let wasScroll = uiView.isScrollEnabled
        uiView.isScrollEnabled = false
        let content = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        uiView.isScrollEnabled = wasScroll
        let height = composerTextFittedHeight(contentHeight: Double(content.height), hero: heroPlaceholder)
        uiView.isScrollEnabled = composerTextShouldScroll(fittedHeight: height)
        return CGSize(width: width, height: CGFloat(height))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposerTextView
        var placeholder: UILabel?
        var focusToken = 0
        var projection = mentionProjection("", cursor: 0)
        var applying = false
        weak var textView: ComposerUITextView?
        /// Tokens are registered on main; deinit only removes them from NotificationCenter.
        nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
        private var chipImages: [String: UIImage] = [:]
        private var imeProbe: UILabel?

        init(_ parent: ComposerTextView) {
            self.parent = parent
        }

        func startObserving(_ view: ComposerUITextView) {
            textView = view
            guard observers.isEmpty else { return }
            observers.append(NotificationCenter.default.addObserver(
                forName: Keyboard.dismissNotification,
                object: nil,
                queue: .main
            ) { [weak view] _ in
                view?.forceResign()
            })
            observers.append(NotificationCenter.default.addObserver(
                forName: .dshComposerImeSetMarked,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.applyTestMarkedText() }
            })
            observers.append(NotificationCenter.default.addObserver(
                forName: .dshComposerImeUnmark,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.applyTestUnmark() }
            })
            installImeProbe(on: view)
        }

        func stopObserving() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
            imeProbe?.removeFromSuperview()
            imeProbe = nil
            textView = nil
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func applyPlaceholder(_ view: UITextView) {
            placeholder?.text = parent.placeholder
            placeholder?.isHidden = !view.text.isEmpty
        }

        func render(_ view: UITextView, force: Bool = false) {
            guard ImeComposition.shouldRewriteText(isMarked: view.markedTextRange != nil) else { return }
            let next = mentionProjection(parent.text, cursor: parent.cursor, previous: projection)
            if !force,
               !applying,
               projection.original == next.original,
               projection.display == next.display {
                return
            }
            applying = true
            projection = next
            let selected = view.isFirstResponder
            view.attributedText = mentionComposerAttributed(next, font: view.font ?? .preferredFont(forTextStyle: .body), images: &chipImages)
            applySelection(view, original: parent.cursor)
            if selected && !view.isFirstResponder {
                view.becomeFirstResponder()
            }
            applying = false
            applyPlaceholder(view)
            refreshImeProbe(view)
        }

        func applySelection(_ view: UITextView, original: Int) {
            guard ImeComposition.shouldRewriteText(isMarked: view.markedTextRange != nil) else { return }
            let viewOffset = mentionViewOffset(original: original, projection: projection)
            let utf16 = mentionCharsToUtf16(view.attributedText?.string ?? "", viewOffset)
            let length = (view.attributedText?.string as NSString?)?.length ?? 0
            let clamped = min(max(utf16, 0), length)
            if view.selectedRange.location != clamped || view.selectedRange.length != 0 {
                view.selectedRange = NSRange(location: clamped, length: 0)
            }
        }

        func commit(text: String, cursor: Int, selectionStart: Int) {
            if let view = textView, !ImeComposition.shouldRewriteText(isMarked: view.markedTextRange != nil) {
                return
            }
            applying = true
            parent.text = text
            parent.cursor = cursor
            applying = false
            if let view = textView {
                render(view, force: true)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            if applying { return }
            if !ImeComposition.shouldRewriteText(isMarked: textView.markedTextRange != nil) {
                applyPlaceholder(textView)
                refreshImeProbe(textView)
                return
            }
            let reconstructed = mentionReconstructOriginal(viewText: textView.text, projection: projection)
            let caret = mentionOriginalOffset(
                view: mentionUtf16ToChars(textView.text, textView.selectedRange.location),
                projection: mentionProjection(reconstructed, cursor: reconstructed.count, previous: projection)
            )
            let normalized = mentionNormalizeEdit(
                beforeText: parent.text,
                beforeCursor: parent.cursor,
                beforeSelectionStart: parent.cursor,
                afterText: reconstructed,
                afterCursor: caret,
                afterSelectionStart: caret,
                projection: projection
            )
            commit(text: normalized.text, cursor: normalized.cursor, selectionStart: normalized.selectionStart)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if applying || !ImeComposition.shouldRewriteText(isMarked: textView.markedTextRange != nil) { return }
            let viewCaret = mentionUtf16ToChars(textView.text, textView.selectedRange.location)
            let original = mentionOriginalOffset(view: viewCaret, projection: projection)
            if parent.cursor != original {
                parent.cursor = original
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if ImeComposition.shouldLetSystemApplyReplacement(
                isMarked: textView.markedTextRange != nil,
                replacement: text,
                interceptReturn: parent.interceptKeys
            ) {
                return true
            }
            if parent.interceptKeys && text == "\n" {
                parent.onReturn()
                return false
            }
            let viewStart = mentionUtf16ToChars(textView.text, range.location)
            let viewEnd = mentionUtf16ToChars(textView.text, range.location + range.length)
            let start = mentionOriginalOffset(view: viewStart, projection: projection)
            let end = mentionOriginalOffset(view: viewEnd, projection: projection)
            if text.isEmpty && range.length > 0 {
                if let edited = mentionKeyEdit(
                    text: parent.text,
                    cursor: end,
                    selectionStart: start == end ? end : start,
                    projection: projection,
                    backspace: start == end,
                    deleteForward: false,
                    moveLeft: false,
                    moveRight: false,
                    shift: false
                ) {
                    commit(text: edited.text, cursor: edited.cursor, selectionStart: edited.selectionStart)
                    return false
                }
            }
            let after = mentionSubstring(parent.text, 0, start) + text + mentionSubstring(parent.text, end, parent.text.count)
            let afterCursor = start + text.count
            let normalized = mentionNormalizeEdit(
                beforeText: parent.text,
                beforeCursor: parent.cursor,
                beforeSelectionStart: start == end ? parent.cursor : start,
                afterText: after,
                afterCursor: afterCursor,
                afterSelectionStart: afterCursor,
                projection: projection
            )
            commit(text: normalized.text, cursor: normalized.cursor, selectionStart: normalized.selectionStart)
            return false
        }

        func refreshImeProbe(_ view: UITextView) {
            guard let probe = imeProbe else { return }
            if let range = view.markedTextRange, let marked = view.text(in: range) {
                probe.accessibilityIdentifier = "composerIme.marked"
                probe.accessibilityValue = marked
                probe.text = marked
                probe.isAccessibilityElement = true
            } else {
                probe.accessibilityIdentifier = "composerIme.idle"
                probe.accessibilityValue = parent.text
                probe.text = parent.text
                probe.isAccessibilityElement = true
            }
        }

        private func installImeProbe(on view: ComposerUITextView) {
            guard UITestLaunch.composerIme, imeProbe == nil else { return }
            let probe = UILabel()
            probe.translatesAutoresizingMaskIntoConstraints = false
            probe.font = .systemFont(ofSize: 1)
            probe.textColor = .clear
            probe.isAccessibilityElement = true
            probe.accessibilityIdentifier = "composerIme.idle"
            view.addSubview(probe)
            NSLayoutConstraint.activate([
                probe.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                probe.topAnchor.constraint(equalTo: view.topAnchor),
                probe.widthAnchor.constraint(equalToConstant: 1),
                probe.heightAnchor.constraint(equalToConstant: 1),
            ])
            imeProbe = probe
            refreshImeProbe(view)
        }

        private func applyTestMarkedText() {
            guard UITestLaunch.composerIme, let view = textView else { return }
            _ = view.becomeFirstResponder()
            view.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
            applyPlaceholder(view)
            refreshImeProbe(view)
        }

        private func applyTestUnmark() {
            guard UITestLaunch.composerIme, let view = textView else { return }
            view.unmarkText()
            if ImeComposition.shouldParseMentions(isMarked: view.markedTextRange != nil) {
                textViewDidChange(view)
            }
            applyPlaceholder(view)
            refreshImeProbe(view)
        }
    }
}

private final class ComposerUITextView: UITextView {
    var onMove: ((Int) -> Void)?
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
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
        if lockFirstResponder && !Keyboard.shouldAllowResign(window: window) {
            return false
        }
        return super.resignFirstResponder()
    }

    func forceResign() {
        lockFirstResponder = false
        Keyboard.allowsResign = true
        _ = super.resignFirstResponder()
        Keyboard.allowsResign = false
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
                case .keyboardTab:
                    onTab?()
                    return
                default:
                    break
                }
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

@MainActor
private func mentionComposerAttributed(
    _ projection: MentionProjection,
    font: UIFont,
    images: inout [String: UIImage]
) -> NSAttributedString {
    let body: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.label,
    ]
    let result = NSMutableAttributedString()
    var copied = 0
    for span in projection.references {
        if span.reference.start > copied {
            result.append(NSAttributedString(string: mentionSubstring(projection.original, copied, span.reference.start), attributes: body))
        }
        let image = mentionComposerChipImage(span.reference, cache: &images)
        let attachment = NSTextAttachment()
        attachment.image = image
        let height = image.size.height
        let offset = (font.capHeight - height) / 2
        attachment.bounds = CGRect(x: 0, y: offset, width: image.size.width, height: height)
        result.append(NSAttributedString(attachment: attachment))
        copied = span.reference.end
    }
    if copied < projection.original.count {
        result.append(NSAttributedString(string: mentionSubstring(projection.original, copied, projection.original.count), attributes: body))
    }
    return result
}

@MainActor
private func mentionComposerChipImage(_ ref: ComposerReference, cache: inout [String: UIImage]) -> UIImage {
    if let cached = cache[ref.canonical] { return cached }
    let renderer = ImageRenderer(content: MentionChipLabel(ref: ref, composer: true))
    renderer.scale = UIScreen.main.scale
    guard let image = renderer.uiImage else {
        fatalError("mention chip ImageRenderer failed for \(ref.canonical)")
    }
    cache[ref.canonical] = image
    return image
}

/// View storage is attachment (1) per committed chip + live/plain runs.
private func mentionViewOffset(original: Int, projection: MentionProjection) -> Int {
    var view = 0
    var copied = 0
    for span in projection.references {
        let ref = span.reference
        if original <= ref.start {
            return view + (original - copied)
        }
        if original < ref.end {
            return original - ref.start < ref.end - original ? view + (ref.start - copied) : view + (ref.start - copied) + 1
        }
        view += (ref.start - copied) + 1
        copied = ref.end
    }
    return view + (original - copied)
}

private func mentionOriginalOffset(view: Int, projection: MentionProjection) -> Int {
    var remaining = view
    var copied = 0
    for span in projection.references {
        let ref = span.reference
        let before = ref.start - copied
        if remaining <= before {
            return copied + remaining
        }
        remaining -= before
        if remaining == 0 { return ref.start }
        remaining -= 1
        copied = ref.end
        if remaining <= 0 { return ref.end }
    }
    return min(copied + remaining, projection.original.count)
}

private func mentionReconstructOriginal(viewText: String, projection: MentionProjection) -> String {
    var result = ""
    var chip = 0
    for character in viewText {
        if character == "\u{FFFC}", chip < projection.references.count {
            result += projection.references[chip].reference.canonical
            chip += 1
        } else {
            result.append(character)
        }
    }
    return result
}

private func mentionUtf16ToChars(_ text: String, _ utf16: Int) -> Int {
    let idx = String.Index(utf16Offset: min(max(utf16, 0), text.utf16.count), in: text)
    return text.distance(from: text.startIndex, to: idx)
}

private func mentionCharsToUtf16(_ text: String, _ chars: Int) -> Int {
    if chars <= 0 { return 0 }
    let idx = text.index(text.startIndex, offsetBy: min(chars, text.count))
    return idx.utf16Offset(in: text)
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
