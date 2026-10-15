import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import DSHProtocol

struct ChatView: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showModels = false
    @State private var tab = 0
    @State private var feedbackDraft: FeedbackDraft?
    @State private var showStart = false
    @State private var showJobs = false
    @State private var openTurns: [String: Bool] = [:]
    @State private var openProcesses: [String: Bool] = [:]
    @State private var inspectTool: Item.Tool?
    @State private var showPermission = false
    @State private var riskPermission: String?
    @State private var showCommands = false
    @State private var showGoal = false
    @State private var showPlus = false
    @State private var questionDrafts: [String: QuestionDraft] = [:]
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false

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
                transcript
                dock
                if !questionVisible && sessionApproval == nil {
                    composer
                }
                if let metrics = model.chat?.composerMetrics {
                    ComposerStats(metrics: metrics)
                }
            } else {
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
        .sheet(isPresented: $showStart) { StartPanel(model: model) { showStart = false } }
        .sheet(isPresented: $showJobs) {
            JobsPanel(model: model) { showJobs = false }
        }
        .sheet(item: $feedbackDraft) { draft in
            FeedbackCategorySheet(
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
        .sheet(isPresented: $showCommands) {
            CommandSheet(
                model: model,
                initialQuery: slashQuery,
                onDismiss: { showCommands = false },
                onFile: { showPlus = true },
                onGoal: { showGoal = true },
                onPlan: { model.executeCommand("/plan") },
                onFeedback: {},
                onCompact: { model.executeCommand("/compact") },
                onPerm: { showPermission = true },
                onModel: { showModels = true }
            )
        }
        .sheet(isPresented: $showGoal) {
            GoalSheet(model: model) { showGoal = false }
        }
        .confirmationDialog(L.sectionAdd(), isPresented: $showPlus, titleVisibility: .visible) {
            Button(L.image()) { showPhotoPicker = true }
            if model.ops.contains("attachments.upload") {
                Button(L.file()) { showFileImporter = true }
            }
            Button(L.t("访问模式", "Access mode")) { showPermission = true }
            Button(L.t("模型", "Model")) { showModels = true }
            Button(L.t("目标", "Goal")) { showGoal = true }
            Button(L.cancel(), role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: 8, matching: .images)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        model.attachFile(name: url.lastPathComponent, mediaType: "application/octet-stream", data: data)
                    }
                }
            }
        }
        .onChange(of: photoItems.count) { _ in
            let items = photoItems
            guard !items.isEmpty else { return }
            photoItems = []
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        model.attachImage(name: L.image(), mediaType: "image/jpeg", data: data)
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

    private func openFeedback(messageId: String, rating: String) {
        feedbackDraft = FeedbackDraft(messageId: messageId, rating: rating)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { model.showDrawer = true } label: {
                Image(systemName: "line.3.horizontal").foregroundStyle(T.ink)
            }
            if model.chat?.running == true {
                ProgressView().controlSize(.mini)
            }
            Text(model.chat?.title?.isEmpty == false ? model.chat!.title! : L.newSession())
                .font(.headline)
                .foregroundStyle(T.ink)
                .lineLimit(1)
            Spacer()
            if model.canShowFiles || model.canShowTerminal {
                Button { showStart = true } label: {
                    Image(systemName: "safari").foregroundStyle(T.ink)
                }
                .accessibilityLabel(L.startPanel())
            }
            Button { showModels = true } label: {
                Text(model.modelChoice?.name ?? L.modelsNav())
                    .font(.caption)
                    .foregroundStyle(T.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(T.tint, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(T.surface)
    }

    private var tabs: some View {
        HStack(spacing: 16) {
            tabChip(0, L.chatTab())
            tabChip(1, TrajL.viewTrajectory)
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

    private var slashQuery: String {
        composerTrigger(model.composerText, cursor: model.composerText.count)?.kind == Character("/")
            ? (composerTrigger(model.composerText, cursor: model.composerText.count)?.query ?? "")
            : ""
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
                onAnswer: { approval, outcome in model.answer(approval, outcome: outcome) }
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

    private var chatRows: [ChatRow] {
        let policy = presentationPolicyFor(model.transcriptView, collapseTiming: model.collapseTiming)
        let folded = foldChatItems(
            model.chat?.items ?? [],
            policy: policy,
            sessionRunning: model.chat?.running == true,
            turnRecords: model.chat?.turns ?? [],
            en: L.en
        )
        return visibleChatRows(folded, openTurns: openTurns)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.chat?.hasMore == true {
                        Button(L.loading()) { model.loadOlderHistory() }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    ForEach(Array(chatRows.enumerated()), id: \.element.key) { _, row in
                        ChatRowView(
                            row: row,
                            model: model,
                            openTurns: $openTurns,
                            openProcesses: $openProcesses,
                            onOpenFeedback: openFeedback,
                            onTool: { inspectTool = $0 }
                        )
                        .id(row.key)
                    }
                    if model.chat?.loaded == false {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: chatRows.last?.key) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
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
            onPlus: { showPlus = true },
            onPerm: { if model.isOnline { showPermission = true } },
            onModel: { if model.isOnline { showModels = true } },
            onSlash: { showCommands = true }
        )
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
    var onOpenFeedback: (String, String) -> Void
    var onTool: (Item.Tool) -> Void

    var body: some View {
        switch row {
        case .user(let user):
            MessageRow(item: .user(user), model: model, onOpenFeedback: onOpenFeedback)
        case .answer(let text):
            MessageRow(item: .text(text), model: model, onOpenFeedback: onOpenFeedback)
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
        case .changes:
            EmptyView()
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
        case .goal: return "flag"
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
    var onOpenFeedback: (String, String) -> Void = { _, _ in }

    var body: some View {
        switch item {
        case .user(let user):
            VStack(alignment: .trailing, spacing: 0) {
                HStack {
                    Spacer(minLength: 48)
                    Text(user.text)
                        .foregroundStyle(T.ink.opacity(user.pending ? 0.6 : 1))
                        .padding(12)
                        .background(T.bubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                MessageActions(
                    text: user.text,
                    timeMs: user.at,
                    clock: .start,
                    branchEnabled: false,
                    branchUnavailable: false,
                    onBranch: nil
                )
            }
        case .text(let text):
            VStack(alignment: .leading, spacing: 6) {
                MarkdownView(source: text.text, streaming: text.live, wrapCode: model.codeWordWrap, onFile: { path in
                    model.openFilePreview(path: path)
                })
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
        let turnRecord = (model.chat?.turns ?? []).first { $0.turn == turn }
        let canFork = model.chat != nil && model.firstPrompt == nil && model.ops.contains("sessions.fork")
        let branchSeq = turnRecord?.endSeq
        let branchHere = canFork && branchSeq != nil
        let mid = text.messageId
        let rating = mid.flatMap { model.feedback[$0]?.rating }
        let canFeedback = mid != nil && model.ops.contains("feedback.set")
        let usage = (model.performanceUsage == .detailed ? turn.flatMap { model.chat?.turnTokenUsage[$0] } : nil)
        return MessageActions(
            text: text.text,
            timeMs: text.at,
            clock: .end,
            branchEnabled: branchHere,
            branchUnavailable: canFork && !branchHere,
            onBranch: canFork ? { if let branchSeq { model.forkCurrent(atSeq: branchSeq) } } : nil,
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

/// Desktop MessageIconActions: copy → like/dislike → branch. Clock at start (user) or end (assistant).
private struct MessageActions: View {
    let text: String
    let timeMs: Int64?
    let clock: MessageClock
    let branchEnabled: Bool
    let branchUnavailable: Bool
    let onBranch: (() -> Void)?
    var messageId: String? = nil
    var rating: String? = nil
    var onLike: (() -> Void)? = nil
    var onDislike: (() -> Void)? = nil
    var usageAction: (() -> TurnUsageAction)? = nil
    @State private var copied = false

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
            if let onBranch {
                iconButton(
                    system: "arrow.triangle.branch",
                    label: branchUnavailable ? L.branchUnavailable() : L.branch(),
                    enabled: branchEnabled,
                    dimmed: branchUnavailable,
                    action: onBranch
                )
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
    }

    private func iconButton(
        system: String,
        label: String,
        enabled: Bool = true,
        dimmed: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15))
                .foregroundStyle(T.text3.opacity(dimmed ? 0.4 : 1))
                .frame(width: 36, height: 48)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct ComposerView: View {
    @ObservedObject var model: AppModel
    var onPlus: () -> Void = {}
    var onPerm: () -> Void = {}
    var onModel: () -> Void = {}
    var onSlash: () -> Void = {}
    @FocusState private var focused: Bool

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
                            Image(systemName: "checklist").foregroundStyle(T.accent)
                            Text(L.planChip()).foregroundStyle(T.accent)
                            Text(L.t("退出", "Exit")).font(.caption).foregroundStyle(T.text3)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 48)
                }
                TextField(L.composerPlaceholder(), text: $model.composerText, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .onChange(of: model.composerText) { value in
                        if let trigger = composerTrigger(value, cursor: value.count) {
                            if trigger.kind == Character("@") {
                                model.mentionQuery = trigger.query
                                model.fetchMentions(query: trigger.query)
                            } else if trigger.kind == Character("/") {
                                onSlash()
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
                    if let perm = model.sessionPermission, !perm.isEmpty {
                        Button(action: onPerm) {
                            Image(systemName: permissionIcon(perm))
                                .foregroundStyle(perm == "danger-full-access" ? T.warnText : T.text2)
                                .frame(width: 48, height: 48)
                        }
                        .accessibilityLabel(permissionLabel(value: perm, option: model.permissionCatalog?.find(perm)))
                    }
                    Button(action: onModel) {
                        HStack(spacing: 4) {
                            Text(model.modelChoice?.name ?? L.t("选择模型", "Select model"))
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
                    }
                    .disabled(!model.isOnline)
                    if runningIdle {
                        Button(action: model.stopRun) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 10, height: 10)
                                .frame(width: 48, height: 48)
                        }
                        .background(T.accent, in: Circle())
                        .accessibilityLabel(L.stop())
                    } else {
                        Button(action: model.sendCurrent) {
                            Image(systemName: "arrow.up").foregroundStyle(Color.white).frame(width: 48, height: 48)
                        }
                        .background(T.accent.opacity(canSend ? 1 : 0.4), in: Circle())
                        .disabled(!canSend)
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
