import SwiftUI
import UIKit
import DSHProtocol

struct ChatView: View {
    @ObservedObject var model: AppModel
    @State private var showModels = false
    @State private var tab = 0
    @State private var feedbackDraft: FeedbackDraft?
    @State private var showStart = false

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            approvals
            if tab == 0 {
                transcript
                composer
            } else {
                TrajectoryView(model: model)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: $showModels) { ModelPickerSheet(model: model) }
        .sheet(isPresented: $showStart) { StartPanel(model: model) { showStart = false } }
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
        .onChange(of: model.chat?.sessionId) { _ in tab = 0 }
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

    @ViewBuilder
    private var approvals: some View {
        let pending = model.approvals.filter { $0.sessionId == nil || $0.sessionId == model.chat?.sessionId }
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(pending) { approval in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.approval()).font(.caption).foregroundStyle(T.warnText)
                        Text(approval.reason ?? approval.toolName).foregroundStyle(T.ink)
                        HStack {
                            Button(L.reject()) { model.answer(approval, outcome: "rejected") }
                                .foregroundStyle(T.err)
                            Spacer()
                            Button(L.allowOnce()) { model.answer(approval, outcome: "allowed-once") }
                                .foregroundStyle(T.onPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(T.primaryButton, in: Capsule())
                        }
                    }
                    .padding(12)
                    .background(T.warnTint, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.warnBorder, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
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
                    ForEach(model.chat?.items ?? []) { item in
                        MessageRow(item: item, model: model, onOpenFeedback: openFeedback)
                            .id(item.key)
                    }
                    if model.chat?.loaded == false {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: model.chat?.items.last?.key) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        ComposerView(model: model)
    }
}

private struct FeedbackDraft: Identifiable {
    let messageId: String
    let rating: String
    var id: String { "\(messageId):\(rating)" }
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
                Text(text.text).foregroundStyle(T.ink)
                if showAssistantActions(text) {
                    assistantActions(text)
                }
            }
        case .reasoning(let reasoning):
            DisclosureGroup {
                Text(reasoning.text).font(.footnote).foregroundStyle(T.text2)
            } label: {
                HStack(spacing: 6) {
                    if reasoning.live { ProgressView().controlSize(.mini) }
                    Text(L.reasoning()).font(.subheadline).foregroundStyle(T.bluish)
                }
            }
        case .tool(let tool):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver").font(.caption)
                    Text(tool.name).font(.subheadline.weight(.medium)).foregroundStyle(T.ink)
                    Spacer()
                    Text(statusLabel(tool.status)).font(.caption).foregroundStyle(statusColor(tool.status))
                }
                if !tool.arguments.isEmpty {
                    Text(tool.arguments).font(.system(.footnote, design: .monospaced)).foregroundStyle(T.text3).lineLimit(4)
                }
                if let result = tool.result, !result.isEmpty {
                    Text(result).font(.footnote).foregroundStyle(T.text2).lineLimit(8)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.codeBlock, in: RoundedRectangle(cornerRadius: 12))
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
            } : nil
        )
    }

    private func statusLabel(_ status: ToolStatus) -> String {
        switch status {
        case .preparing, .running: return L.loading()
        case .awaitingApproval: return L.approval()
        case .ok: return L.en ? "Completed" : "已完成"
        case .error: return L.en ? "Failed" : "失败"
        }
    }

    private func statusColor(_ status: ToolStatus) -> Color {
        switch status {
        case .ok: return T.ok
        case .error: return T.err
        case .awaitingApproval: return T.warnText
        default: return T.text3
        }
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
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            mentionPanel
            HStack(alignment: .bottom, spacing: 8) {
                TextField(L.composerPlaceholder(), text: $model.composerText, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .padding(10)
                    .background(T.inputMajor, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.border, lineWidth: 0.5))
                    .onChange(of: model.composerText) { value in
                        if let at = value.lastIndex(of: "@") {
                            let q = String(value[value.index(after: at)...])
                            if !q.contains(" ") {
                                model.mentionQuery = q
                                model.fetchMentions(query: q)
                                return
                            }
                        }
                        model.mentionQuery = nil
                    }
                if model.chat?.running == true {
                    Button(action: model.stopRun) {
                        Image(systemName: "stop.fill").foregroundStyle(T.onPrimary).padding(10)
                    }
                    .background(T.err, in: Circle())
                }
                Button(action: model.sendCurrent) {
                    Text(L.busySendLabel(running: model.chat?.running == true, busy: model.busySend))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(T.onPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(T.primaryButton, in: Capsule())
                .disabled(model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.isOnline)
            }
            .padding(10)
        }
        .background(T.surface)
    }

    @ViewBuilder
    private var mentionPanel: some View {
        if model.mentionQuery != nil, !(model.fileMentions.isEmpty && model.sessionMentions.isEmpty) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.fileMentions.prefix(8)) { file in
                    Button {
                        insert(file.path)
                    } label: {
                        Label(file.path, systemImage: "doc").foregroundStyle(T.ink).padding(8)
                    }
                }
                ForEach(model.sessionMentions.prefix(8)) { session in
                    Button {
                        insert(session.mention)
                    } label: {
                        Label(session.title ?? session.mention, systemImage: "bubble.left").foregroundStyle(T.ink).padding(8)
                    }
                }
            }
            .background(T.settingsCard)
            .overlay(Rectangle().stroke(T.border, lineWidth: 0.5))
        }
    }

    private func insert(_ mention: String) {
        if let at = model.composerText.lastIndex(of: "@") {
            model.composerText = String(model.composerText[..<at]) + mention + " "
        }
        model.mentionQuery = nil
    }
}

struct ModelPickerSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.catalog?.groups ?? []) { group in
                    Section(group.name) {
                        ForEach(group.models) { info in
                            Button {
                                model.selectModel(info, effort: info.defaultEffort)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(info.name).foregroundStyle(T.ink)
                                        if let description = info.description {
                                            Text(description).font(.caption).foregroundStyle(T.text3)
                                        }
                                    }
                                    Spacer()
                                    if model.modelChoice?.provider == info.provider && model.modelChoice?.model == info.id {
                                        Image(systemName: "checkmark").foregroundStyle(T.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.modelsNav())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.cancel()) { dismiss() } } }
        }
    }
}
