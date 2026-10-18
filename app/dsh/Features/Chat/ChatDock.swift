import SwiftUI
import UIKit
import DSHProtocol

func approvalCommand(_ approval: Approval, items: [Item]) -> String? {
    items.compactMap { item -> Item.Tool? in
        if case .tool(let tool) = item { return tool }
        return nil
    }.last { $0.callId == approval.callId }?.arguments
}

struct UserQuestionCard: View {
    let question: UserQuestion
    @Binding var drafts: [String: QuestionDraft]
    @Binding var index: Int
    var enabled: Bool = true
    var onDismiss: () -> Void
    var onAnswer: (String, [JSONValue], @escaping (Bool) -> Void) -> Void

    @State private var busy = false
    @State private var err: String?

    var body: some View {
        if question.questions.isEmpty { EmptyView() } else { card }
    }

    private var currentIndex: Int {
        coerceQuestionIndex(index, count: question.questions.count)
    }

    private var item: UserQuestionItem {
        question.questions[currentIndex]
    }

    private var draft: QuestionDraft { questionDraft(for: item, in: drafts) }

    private var writable: Bool { enabled && !busy }

    private var isPlan: Bool { planReviewOf(question.questions) != nil }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isPlan ? L.planReview() : "\(item.header ?? askRowTitle(english: L.en)) · \(currentIndex + 1)/\(question.questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(T.text2)
                Spacer()
                Button(questionCollapseLabel(english: L.en), action: onDismiss).disabled(busy)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.question).font(.title3).foregroundStyle(T.ink)
                    if let detail = item.detail, !detail.isEmpty {
                        MarkdownView(source: detail, wrapCode: AppModel.shared.codeWordWrap)
                    }
                    if !isPlan {
                        ForEach(Array(item.options.enumerated()), id: \.offset) { _, opt in
                            optionRow(opt)
                        }
                        TextField(L.typeYourAnswer(), text: Binding(
                            get: { draft.custom },
                            set: { value in
                                drafts[item.id] = QuestionDraft(
                                    selected: item.multiSelect ? draft.selected : [],
                                    custom: value,
                                    skipped: false
                                )
                                err = nil
                            }
                        ), axis: .vertical)
                        .lineLimit(1...4)
                        .disabled(!writable)
                        .padding(10)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }
            VStack(alignment: .leading, spacing: 8) {
                if let err { Text(err).font(.caption).foregroundStyle(T.err) }
                if busy { Text(questionSubmitting(english: L.en)).foregroundStyle(T.text3) }
                else if question.state == "continued" {
                    Text(questionWaitContinued(english: L.en))
                        .font(.caption)
                        .foregroundStyle(T.text3)
                }
                if isPlan {
                    Button(L.approvePlan()) {
                        drafts[item.id] = QuestionDraft(selected: [item.approveLabel ?? ""])
                        submit()
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(T.onPrimary)
                    .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(!writable)
                    Button(questionPlanDiscuss(english: L.en), action: onDismiss)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                        .disabled(busy)
                } else {
                    HStack {
                        if currentIndex > 0 {
                            Button(questionPreviousLabel(english: L.en)) {
                                index = currentIndex - 1
                                err = nil
                            }
                            .disabled(busy)
                        }
                        Button(L.skip()) { skipCurrent() }
                            .disabled(!writable)
                        Spacer()
                        Button(currentIndex < question.questions.count - 1
                               ? L.nextQuestion()
                               : questionSubmitAnswersLabel(english: L.en)) {
                            continueOrSubmit()
                        }
                        .disabled(!writable || !draft.completed)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 420)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.border, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .onChange(of: question.questionId) { _ in
            busy = false
            err = nil
        }
        .onChange(of: question.state) { state in
            if busy, state == "continued" {
                busy = false
                err = questionResubmitHint(english: L.en)
            }
        }
    }

    private func optionRow(_ opt: UserQuestionOption) -> some View {
        let selected = draft.selected.contains(opt.label)
        let display = parseRecommendedLabel(opt.label)
        return Button {
            choose(opt.label)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.label).foregroundStyle(T.ink)
                    if display.recommended {
                        Text(questionRecommendedBadge(english: L.en))
                            .font(.caption)
                            .foregroundStyle(T.accent)
                    }
                    if let description = opt.description, !description.isEmpty {
                        Text(description).font(.caption).foregroundStyle(T.text3)
                    }
                }
                Spacer()
                if selected { OfficialGlyph(kind: .checkOutline, size: 14, color: T.accent) }
            }
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? T.accent : T.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!writable)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func choose(_ label: String) {
        if item.multiSelect {
            var next = draft
            if next.selected.contains(label) { next.selected.remove(label) } else { next.selected.insert(label) }
            next.skipped = false
            drafts[item.id] = next
        } else {
            drafts[item.id] = QuestionDraft(selected: [label])
            if currentIndex < question.questions.count - 1 {
                index = currentIndex + 1
            }
        }
        err = nil
    }

    private func skipCurrent() {
        drafts[item.id] = QuestionDraft(skipped: true)
        err = nil
        if currentIndex < question.questions.count - 1 {
            index = currentIndex + 1
        } else {
            submit()
        }
    }

    private func continueOrSubmit() {
        if currentIndex == question.questions.count - 1 {
            submit()
            return
        }
        if !draft.completed {
            err = questionUnansweredError(english: L.en)
            return
        }
        index = currentIndex + 1
        err = nil
    }

    private func submit() {
        if !writable { return }
        if let missing = firstIncompleteQuestionIndex(question, drafts: drafts) {
            index = missing
            err = questionIncompleteError(english: L.en)
            return
        }
        busy = true
        err = nil
        onAnswer(question.callId ?? question.questionId, questionAnswers(question, drafts: drafts)) { success in
            if !success {
                busy = false
                err = questionSubmitFailed(english: L.en)
            }
        }
    }
}

/// Desktop `QuestionReplyView`: right-aligned late answer to a continued question.
struct QuestionReplyRow: View {
    let item: Item.QuestionReply
    @State private var open = false
    @State private var copied = false

    private var summary: String {
        questionReplySummary(questions: item.questions, answers: item.answers, english: L.en)
    }

    private var copyText: String {
        replyClipboardText(
            text: item.text,
            questions: item.questions,
            answers: item.answers,
            english: L.en
        )
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    open.toggle()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 3) {
                            OfficialGlyph(kind: .chevronDown, size: 12, color: T.text3)
                                .rotationEffect(.degrees(open ? 0 : -90))
                            Text(questionReplyLabel(english: L.en))
                                .font(.system(size: 13))
                                .foregroundStyle(T.text3)
                        }
                        if !open {
                            Text(summary)
                                .font(LocalFonts.text())
                                .foregroundStyle(T.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(questionReplyLabel(english: L.en)) · \(open ? questionReplyClose(english: L.en) : questionReplyOpen(english: L.en))")

                if open {
                    if item.questions.isEmpty {
                        Text(item.text)
                            .font(LocalFonts.text())
                            .foregroundStyle(T.ink)
                            .padding(.top, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(item.questions) { question in
                                replyQuestion(question)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(T.bubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack(spacing: 8) {
                if let at = item.at {
                    Text(formatMessageClock(at, english: L.en))
                        .font(.system(size: 13))
                        .foregroundStyle(T.text3)
                }
                Button {
                    guard !copied else { return }
                    UIPasteboard.general.string = copyText
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
                } label: {
                    Group {
                        if copied {
                            OfficialGlyph(kind: .checkOutline, size: 14, color: T.text3)
                        } else {
                            OfficialGlyph(kind: .copyOutline, size: 14, color: T.text3)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? L.t("已复制", "Copied") : L.copy())
            }
        }
        .padding(.leading, 48)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(questionReplyLabel(english: L.en))
    }

    private func replyQuestion(_ question: QuestionReplyQuestion) -> some View {
        let values = replyAnswerValues(answers: item.answers, id: question.id)
        return VStack(alignment: .leading, spacing: 4) {
            if let header = question.header, !header.isEmpty, header != question.question {
                Text(header).font(.system(size: 11)).foregroundStyle(T.text3)
            }
            Text(question.question).font(LocalFonts.text()).foregroundStyle(T.ink)
            if let detail = question.detail, !detail.isEmpty {
                Text(detail).font(.system(size: 11)).foregroundStyle(T.text3)
            }
            if !question.options.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { _, option in
                        Text(option.description.map { "\(option.label) — \($0)" } ?? option.label)
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(questionReplyAnswerLabel(english: L.en))
                    .font(.system(size: 12))
                    .foregroundStyle(T.text3)
                Text(values.isEmpty ? questionReplySkipped(english: L.en) : values.joined(separator: ", "))
                    .font(LocalFonts.text())
                    .foregroundStyle(T.ink)
            }
        }
    }
}

struct ApprovalCard: View {
    let approval: Approval
    let items: [Item]
    var enabled: Bool = true
    var onAnswer: (Approval, String, @escaping (Bool) -> Void) -> Void

    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(T.warnBorder).frame(width: 7, height: 7)
                Text(L.t("等待审批", "Waiting for approval")).foregroundStyle(T.warnText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(T.warnTint)
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("工具 \(approval.toolName) 请求越权执行", "Tool \(approval.toolName) requested elevated execution"))
                    .font(.title3)
                    .foregroundStyle(T.ink)
                if let command = approvalCommand(approval, items: items) ?? approval.reason {
                    Text(command)
                        .font(LocalFonts.code())
                        .foregroundStyle(T.text3)
                        .textSelection(.enabled)
                }
                if let reason = approval.reason, reason != approvalCommand(approval, items: items) {
                    Text(reason).font(.footnote).foregroundStyle(T.warnText)
                }
                HStack(spacing: 10) {
                    Button(L.reject()) { answer("rejected") }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                        .disabled(!enabled || busy)
                    Button(busy ? L.t("提交中…", "Submitting…") : L.allowOnce()) { answer("allowed-once") }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(T.onPrimary)
                        .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                        .disabled(!enabled || busy)
                }
            }
            .padding(18)
        }
        .frame(maxHeight: 420)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.warnBorder, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .onChange(of: approval.approvalId) { _ in busy = false }
    }

    private func answer(_ outcome: String) {
        if busy || !enabled { return }
        busy = true
        onAnswer(approval, outcome) { success in
            if !success { busy = false }
        }
    }
}

struct TodoPanel: View {
    let sessionKey: String
    let todos: [TodoItem]
    @State private var expanded = false

    var body: some View {
        if todos.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checklist").foregroundStyle(T.text3)
                        Text(L.t("任务", "To-dos")).font(.subheadline.weight(.medium)).foregroundStyle(T.ink)
                        Text(todoProgressLabel(todos, en: L.en))
                            .font(.subheadline)
                            .foregroundStyle(T.text3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(T.text3)
                            .rotationEffect(.degrees(expanded ? 0 : 180))
                    }
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(todos) { item in
                            HStack(spacing: 10) {
                                todoDot(item.status)
                                Text(item.content).font(.subheadline).foregroundStyle(T.text2).lineLimit(1)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.settingsCardStroke, lineWidth: 0.5))
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
            .onChange(of: sessionKey) { _ in expanded = false }
        }
    }

    @ViewBuilder
    private func todoDot(_ status: String) -> some View {
        if status == "in_progress" {
            ProgressView().controlSize(.mini).frame(width: 16, height: 16)
        } else {
            Circle()
                .fill(status == "completed" ? T.ok : T.text3)
                .frame(width: 6, height: 6)
                .frame(width: 16, height: 16)
        }
    }
}

struct GoalBar: View {
    let goal: JSONValue
    let activation: String?
    var onEdit: () -> Void

    var body: some View {
        if goal["phase"].str() == "complete" {
            EmptyView()
        } else {
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: D.goal).foregroundStyle(T.text3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goalPhaseLabel(phase: goal["phase"].str(), activation: activation, english: L.en))
                            .font(.caption)
                            .foregroundStyle(T.text3)
                        Text(goal["objective"].str() ?? "")
                            .font(.subheadline)
                            .foregroundStyle(T.text2)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(T.text3)
                }
                .frame(minHeight: 48)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
    }
}

struct GoalSheet: View {
    @ObservedObject var model: AppModel
    var onDismiss: () -> Void
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?

    private var goal: JSONValue? { model.chat?.goal }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let goal {
                        Text(goalPhaseLabel(phase: goal["phase"].str(), activation: model.goalActivation, english: L.en))
                            .font(.caption)
                            .foregroundStyle(T.text3)
                        if let reason = goal["blockedReason"]["message"].str() {
                            Text(reason).foregroundStyle(T.warnText)
                        }
                    }
                    TextField(L.t("长期任务目标", "Long-running task goal"), text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .disabled(busy)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                    if let error { Text(error).foregroundStyle(T.err) }
                    if let goal {
                        let phase = goal["phase"].str()
                        if phase == "active" && model.goalActivation == "armed" {
                            Button(L.t("暂停目标", "Pause goal")) { mutate("pause") }.disabled(!model.isOnline || busy)
                        }
                        if phase == "paused" || (phase == "active" && model.goalActivation == "disarmed") {
                            Button(L.t("恢复目标", "Resume goal")) { mutate("resume") }.disabled(!model.isOnline || busy)
                        }
                        Button(L.t("清除目标", "Clear goal")) { mutate("clear") }
                            .foregroundStyle(T.err)
                            .disabled(!model.isOnline || busy)
                    }
                    Button(busy ? L.t("提交中…", "Submitting…") : (goal == nil ? L.t("设置目标", "Set goal") : L.t("保存目标", "Save goal"))) {
                        if goal != nil { mutate("edit") } else { create() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(T.onPrimary)
                    .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(!model.isOnline || busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.chat == nil)
                }
                .padding(22)
            }
            .navigationTitle(L.t("目标", "Goal"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.cancel()) { if !busy { onDismiss() } } } }
        }
        .onAppear { text = goal?["objective"].str() ?? "" }
    }

    private func mutate(_ action: String) {
        if busy || !model.isOnline { return }
        busy = true
        error = nil
        model.mutateGoal(action: action, objective: action == "edit" ? text.trimmingCharacters(in: .whitespacesAndNewlines) : nil) { success in
            busy = false
            if success { onDismiss() } else { error = L.t("目标修改失败", "Could not update the goal") }
        }
    }

    private func create() {
        guard let sessionId = model.chat?.sessionId else { return }
        busy = true
        error = nil
        Task {
            do {
                let commands = try await model.commandCatalog(sessionId: sessionId)
                guard let command = commands.first(where: { builtinCommandName($0["definitionId"].str()) == "goal" }),
                      let name = command["name"].str() else {
                    throw PocketError(code: "unsupported", message: L.t("远程主机没有提供目标指令", "The remote host did not provide a goal command"))
                }
                model.executeCommand("/\(name) \(text.trimmingCharacters(in: .whitespacesAndNewlines))") { success in
                    busy = false
                    if success { onDismiss() } else { error = L.t("目标创建失败，内容已保留", "Could not create the goal; the text was kept") }
                }
            } catch {
                busy = false
                self.error = error.localizedDescription
            }
        }
    }
}

struct PromptQueue: View {
    let sessionId: String
    let prompts: [QueuedPrompt]
    let running: Bool
    let enabled: Bool
    var onAction: (String, QueueAction, @escaping (Bool) -> Void) -> Void

    @State private var collapsed = true
    @State private var editingId: String?
    @State private var draft = ""
    @State private var busyId: String?

    var body: some View {
        if prompts.isEmpty {
            EmptyView()
        } else {
            let interacting = editingId != nil || busyId != nil
            let expanded = !collapsed || interacting
            let single = prompts.count == 1
            VStack(spacing: 0) {
                if !single {
                    Button { collapsed.toggle() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "text.line.first.and.arrowtriangle.forward").foregroundStyle(T.text3)
                            Text(L.en ? "\(prompts.count) queued messages" : "\(prompts.count) 条排队消息")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(T.text2)
                            Spacer()
                            if !expanded && prompts.contains(where: \.sending) {
                                Text(L.t("发送中…", "Sending…")).foregroundStyle(T.text3)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .rotationEffect(.degrees(expanded ? 0 : 180))
                                .foregroundStyle(T.text3)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(interacting)
                }
                if single || expanded {
                    ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                        if index > 0 { Divider() }
                        queueRow(prompt, single: single)
                    }
                }
            }
            .padding(.vertical, 2)
            .background(T.fill2)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                    .stroke(T.border, lineWidth: 0.5)
            }
            .padding(.horizontal, 30)
            .onChange(of: prompts) { next in
                if next.isEmpty { collapsed = true }
                if let editingId, !next.contains(where: { $0.id == editingId && $0.editable && !$0.sending }) {
                    self.editingId = nil
                    draft = ""
                }
            }
        }
    }

    private func queueRow(_ prompt: QueuedPrompt, single: Bool) -> some View {
        let editing = editingId == prompt.id
        let actionable = enabled && !prompt.sending && busyId == nil
        let preview = queuePreview(prompt)
        return HStack(spacing: 8) {
            if single {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").foregroundStyle(T.text3)
            }
            if editing {
                TextField(L.t("编辑排队消息", "Edit queued message"), text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .disabled(!enabled || busyId != nil)
            } else {
                HStack(spacing: 8) {
                    if !prompt.attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(prompt.attachments) { attachment in
                                    queueAttachment(attachment)
                                }
                            }
                        }
                        .frame(maxWidth: 180)
                    }
                    if !preview.isEmpty {
                        Text(preview).font(.subheadline).foregroundStyle(T.text2).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 4)
            if prompt.sending {
                Text(L.t("发送中…", "Sending…")).font(.subheadline).foregroundStyle(T.text3)
            }
            if editing {
                icon("checkmark", enabled: actionable && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, label: L.t("保存排队消息", "Save queued message")) {
                    apply(prompt.id, .edit(draft))
                }
                icon("xmark", enabled: busyId == nil, label: L.t("取消编辑", "Cancel edit")) { editingId = nil; draft = "" }
            } else {
                icon("pencil", enabled: actionable && prompt.editable, label: L.t("编辑排队消息", "Edit queued message")) {
                    editingId = prompt.id
                    draft = prompt.text
                }
                icon("trash", enabled: actionable, label: L.t("删除排队消息", "Remove queued message")) {
                    apply(prompt.id, .remove)
                }
                icon(
                    "paperplane",
                    enabled: actionable && running,
                    label: running
                        ? L.t("插话发送", "Steer queued message")
                        : L.t("仅运行中可插话发送", "Steering is available only while the agent is running")
                ) { apply(prompt.id, .steer) }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 5)
        .frame(minHeight: 36)
    }

    private func apply(_ id: String, _ action: QueueAction) {
        busyId = id
        onAction(id, action) { success in
            if busyId == id { busyId = nil }
            if success, case .edit = action, editingId == id {
                editingId = nil
                draft = ""
            }
        }
    }

    private func icon(_ system: String, enabled: Bool, label: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13))
                .foregroundStyle(T.text3.opacity(enabled ? 1 : 0.45))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }

    @ViewBuilder
    private func queueAttachment(_ attachment: QueuedAttachment) -> some View {
        switch attachment.kind {
        case .image:
            QueueThumb(sessionId: sessionId, attachment: attachment)
        case .file:
            HStack(spacing: 4) {
                FileTypeIcon(path: attachment.name ?? "", type: "file", openable: true)
                Text(attachment.name ?? "")
                    .font(.caption)
                    .foregroundStyle(T.text2)
                    .lineLimit(1)
                if let bytes = attachment.bytes {
                    Text(fileSizeText(bytes))
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(T.bg, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(T.border, lineWidth: 0.5))
            .accessibilityLabel(queueFileLabel(name: attachment.name ?? "", english: L.en))
        }
    }

    private func queuePreview(_ prompt: QueuedPrompt) -> String {
        prompt.text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct QueueThumb: View {
    let sessionId: String
    let attachment: QueuedAttachment
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                T.fill
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(T.border, lineWidth: 0.5))
        .accessibilityLabel(queueImageLabel(english: L.en))
        .task(id: attachment.id) {
            if let data = attachment.previewData, let loaded = UIImage(data: data) {
                image = loaded
                return
            }
            guard let attachmentId = attachment.attachmentId else { return }
            guard let data = await AppModel.shared.loadAttachmentBytes(sessionId: sessionId, attachmentId: attachmentId) else {
                return
            }
            image = UIImage(data: data)
        }
    }
}

final class CommandMenuHost: ObservableObject {
    @Published var enterRequest = 0
    @Published var moveRequest = 0
    @Published var moveDirection = 0

    func requestEnter() { enterRequest += 1 }
    func requestMove(_ direction: Int) {
        moveDirection = direction
        moveRequest += 1
    }
}

struct CommandMenuOverlay: View {
    @ObservedObject var model: AppModel
    @ObservedObject var host: CommandMenuHost
    var query: String = ""
    var leading: Bool = true
    var consumeSlash: Bool = true
    var availableHeight: CGFloat = 0
    var onDismiss: () -> Void
    var onFile: () -> Void
    var onGoal: () -> Void
    var onPlan: () -> Void
    var onFeedback: () -> Void
    var onCompact: () -> Void
    var onPerm: () -> Void
    var onModel: () -> Void
    var onExport: () -> Void
    /// Desktop `/permission` is a `popupSelect`: options replace the slash list in place.
    var onSelectPermission: ((String) -> Void)? = nil

    @State private var pickingPermission = false
    @State private var commands: [JSONValue] = []
    @State private var skills: [SkillEntry] = []
    @State private var loading = true
    @State private var error: String?
    @State private var attempt = 0
    @State private var highlight: Int?
    @State private var loadedScope: String?

    private var sessionReady: Bool { model.chat?.loaded == true }
    private var landing: Bool { model.chat == nil }
    private var catalogReady: Bool { landing || sessionReady }
    private var subagent: Bool {
        model.sessions.first { $0.sessionId == model.chat?.sessionId }?.origin == "subagent"
    }
    private var skillScope: String {
        skillCatalogScopeKey(sessionId: model.chat?.sessionId, subagent: subagent)
    }

    private var candidates: [JSONValue] {
        commandMenuMerge(
            host: commands,
            injected: commandMenuClientRows(
                ops: model.ops,
                sessionReady: sessionReady,
                subagent: subagent,
                landing: landing
            )
        )
    }

    private var permissionOptions: [PermissionOption] { model.permissionCatalog?.options ?? [] }

    private var currentPermission: String {
        model.sessionPermission ?? model.draftPermission ?? model.defaultPermission
    }

    private func choosePermission(_ value: String) {
        if consumeSlash { model.consumeComposerSlash() }
        pickingPermission = false
        if value != currentPermission { onSelectPermission?(value) }
        onDismiss()
    }

    private var collision: String? { commandContributionCollision(candidates) }

    private var rows: [CommandMenuRow] {
        if collision != nil { return [] }
        return commandMenuDisplayRows(
            commands: candidates,
            skills: skills,
            query: query,
            leading: leading,
            english: L.en
        )
    }

    private var catalogTaskId: String {
        "\(model.activeId ?? "")-\(skillScope)-\(catalogReady)-\(attempt)-\(model.isOnline)-\(model.ops.sorted().joined())-\(subagent)"
    }

    var body: some View {
        menuCard
            .frame(
                minHeight: availableHeight > 0 ? availableHeight : nil,
                maxHeight: availableHeight > 0 ? availableHeight : nil,
                alignment: .bottom
            )
            .task(id: catalogTaskId) { await load() }
            .onAppear {
                if skills.isEmpty, let scoped = model.skillEntries(for: skillScope), !scoped.isEmpty {
                    skills = scoped
                }
                highlight = commandMenuDefaultHighlight(rows)
            }
            .onChange(of: query) { _ in
                pickingPermission = false
                highlight = commandMenuDefaultHighlight(rows)
            }
            .onChange(of: rows.count) { _ in syncHighlight() }
            .onChange(of: host.enterRequest) { _ in
                if host.enterRequest > 0 {
                    if pickingPermission {
                        if let h = highlight, permissionOptions.indices.contains(h) { choosePermission(permissionOptions[h].value) }
                    } else {
                        activateHighlight()
                    }
                }
            }
            .onChange(of: host.moveRequest) { _ in
                if host.moveRequest > 0 && pickingPermission {
                    let count = permissionOptions.count
                    if count > 0 { highlight = ((highlight ?? -1) + host.moveDirection + count) % count }
                } else if host.moveRequest > 0 {
                    highlight = commandMenuMoveHighlight(rows: rows, current: highlight, direction: host.moveDirection)
                }
            }
    }

    private var menuCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pickingPermission {
                permissionList
            } else {
                statusBanner
                menuList
            }
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(T.settingsCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("slashMenu")
    }

    @ViewBuilder
    private var statusBanner: some View {
        if loading { loadingRow }
        if let error { errorRow(error) }
        if let collision {
            Text(commandContributionCollisionMessage(collision, english: L.en))
                .font(.caption)
                .foregroundStyle(T.err)
                .padding(12)
        }
        if !loading && error == nil && rows.isEmpty {
            Text(L.noOptions()).font(.caption).foregroundStyle(T.text3).padding(12)
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView().controlSize(.mini)
            Text(commandMenuStatusLoading(english: L.en)).font(.caption).foregroundStyle(T.text3)
        }
        .padding(12)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message).font(.caption).foregroundStyle(T.err)
            Button(L.retry()) { attempt += 1 }.disabled(!model.isOnline)
        }
        .padding(12)
    }

    private var permissionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if model.permissionCatalogLoading && permissionOptions.isEmpty { loadingRow }
                ForEach(Array(permissionOptions.enumerated()), id: \.offset) { index, option in
                    HStack(spacing: 10) {
                        if permissionHasGlyph(option.value) {
                            OfficialGlyph(kind: .permission(option.value), size: 14, color: T.text2)
                        }
                        Text(permissionLabel(value: option.value, option: option, english: L.en)).foregroundStyle(T.ink)
                        Spacer()
                        if option.value == currentPermission {
                            OfficialGlyph(kind: .checkOutline, size: 14, color: T.ink)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(highlight == index ? T.hoverBg : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { choosePermission(option.value) }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var menuList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                        menuItem(item, index: index)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: highlight) { value in
                if let value { proxy.scrollTo(value, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func menuItem(_ item: CommandMenuRow, index: Int) -> some View {
        switch item {
        case .section(let title):
            Text(title)
                .font(.caption)
                .foregroundStyle(T.text3)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)
        case .command(let command):
            commandRow(command, name: command["name"].str() ?? "", kind: commandMenuKind(command), index: index)
        case .skill(let skill):
            skillRow(skill, index: index)
        }
    }

    private func syncHighlight() {
        if highlight.flatMap({ rows.indices.contains($0) && rows[$0].isSelectable }) != true {
            highlight = commandMenuDefaultHighlight(rows)
        }
    }

    @ViewBuilder
    private func commandRow(_ command: JSONValue, name: String, kind: String?, index: Int) -> some View {
        let label = commandMenuLabel(command, english: L.en)
        let enabled = model.isOnline && catalogReady && (landing || commandMenuAvailable(kind: kind, ops: model.ops))
        let active = highlight == index
        menuRow(
            index: index,
            enabled: enabled,
            active: active,
            icon: commandMenuIconSymbol(kind),
            title: label ?? name,
            alias: label.flatMap { $0.caseInsensitiveCompare(name) == .orderedSame ? nil : name },
            detail: commandMenuDescription(command, english: L.en)
        ) {
            activate(command, name: name, kind: kind)
        }
    }

    @ViewBuilder
    private func skillRow(_ skill: SkillEntry, index: Int) -> some View {
        let enabled = model.isOnline && catalogReady
        menuRow(
            index: index,
            enabled: enabled,
            active: highlight == index,
            icon: "sparkle",
            title: skill.name,
            alias: nil,
            detail: {
                let text = skill.menuDescription(english: L.en)
                return text.isEmpty ? nil : text
            }()
        ) {
            guard enabled else { return }
            model.insertComposer("/\(skill.name) ")
            onDismiss()
        }
    }

    private func menuRow(
        index: Int,
        enabled: Bool,
        active: Bool,
        icon: String,
        title: String,
        alias: String?,
        detail: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon).foregroundStyle(enabled ? T.text2 : T.text3)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).foregroundStyle(enabled ? T.ink : T.text3)
                    if let alias {
                        Text(alias).font(.caption).foregroundStyle(T.text3)
                    }
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(T.text3)
                        .lineLimit(commandMenuDescriptionLineLimit)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? T.hoverBg : Color.clear)
        .contentShape(Rectangle())
        .id(index)
        .onTapGesture {
            highlight = index
            if enabled { action() }
        }
        .onHover { hovering in
            if hovering { highlight = index }
        }
    }

    private func activateHighlight() {
        guard let row = commandMenuHighlightedRow(rows, highlight: highlight) else { return }
        switch row {
        case .command(let command):
            activate(command, name: command["name"].str() ?? "", kind: commandMenuKind(command))
        case .skill(let skill):
            guard model.isOnline && catalogReady else { return }
            model.insertComposer("/\(skill.name) ")
            onDismiss()
        case .section:
            return
        }
    }

    private func activate(_ command: JSONValue, name: String, kind: String?) {
        let enabled = model.isOnline && catalogReady && (landing || commandMenuAvailable(kind: kind, ops: model.ops))
        guard enabled else { return }
        if kind != "file", !model.pendingAttaches.isEmpty, commandRefusesAttachments(name: name, catalogRow: command) {
            model.showToast(commandAttachmentsUnsupportedNotice(command: name, english: L.en))
            return
        }
        @MainActor func consume() { if consumeSlash { model.consumeComposerSlash() } }
        switch kind {
        case "file": consume(); onDismiss(); onFile()
        case "model": consume(); onModel(); onDismiss()
        case "goal": consume(); onGoal(); onDismiss()
        case "plan":
            consume()
            if name == "plan" { onPlan() } else { model.executeCommand("/\(name)") }
            onDismiss()
        case "feedback": consume(); onFeedback(); onDismiss()
        case "compact":
            consume()
            if name == "compact" { onCompact() } else { model.executeCommand("/\(name)") }
            onDismiss()
        case "permission":
            if onSelectPermission != nil {
                model.reloadPermissionCatalog()
                highlight = permissionOptions.firstIndex { $0.value == currentPermission } ?? 0
                pickingPermission = true
            } else {
                consume(); onPerm(); onDismiss()
            }
        case "export": consume(); onExport(); onDismiss()
        default:
            if command["input"].obj() != nil {
                model.insertComposer("/\(name)")
            } else {
                consume()
                model.executeCommand("/\(name)")
            }
            onDismiss()
        }
    }

    private func load() async {
        if !model.isOnline {
            loading = false
            return
        }
        if model.chat != nil && !sessionReady {
            loading = true
            return
        }
        if loadedScope != skillScope {
            commands = []
            skills = []
            loadedScope = skillScope
        }
        loading = true
        error = nil
        let id = model.chat?.sessionId
        do {
            if subagent || !model.ops.contains("commands.list") {
                commands = []
            } else {
                commands = try await model.commandCatalog(sessionId: id)
            }
        } catch is CancellationError {
            return
        } catch {
            commands = []
            if !landing {
                self.error = error.localizedDescription.isEmpty ? (L.en ? "Could not load commands" : "无法加载指令") : error.localizedDescription
            }
        }
        if !subagent, model.ops.contains("skills.list") {
            do {
                skills = try await model.skillCatalog(sessionId: id)
            } catch is CancellationError {
                return
            } catch {
                #if DEBUG
                print("[dsh.skills] list failed scope=\(skillScope) error=\(error)")
                #endif
                skills = []
            }
        } else {
            skills = []
        }
        loading = false
    }
}
