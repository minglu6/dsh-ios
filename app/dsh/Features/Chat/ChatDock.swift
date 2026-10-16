import SwiftUI
import DSHProtocol

struct QuestionDraft: Equatable {
    var selected: Set<String> = []
    var custom: String = ""
    var answered: Bool { !selected.isEmpty || !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

func questionAnswers(_ q: UserQuestion, drafts: [String: QuestionDraft]) -> [JSONValue] {
    q.questions.map { item in
        let draft = drafts[item.id] ?? QuestionDraft()
        var object: [String: JSONValue] = [
            "id": .string(item.id),
            "selected": .array(draft.selected.map { .string($0) }),
        ]
        let custom = draft.custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { object["custom"] = .string(custom) }
        return .object(object)
    }
}

func approvalCommand(_ approval: Approval, items: [Item]) -> String? {
    items.compactMap { item -> Item.Tool? in
        if case .tool(let tool) = item { return tool }
        return nil
    }.last { $0.callId == approval.callId }?.arguments
}

struct UserQuestionCard: View {
    let question: UserQuestion
    @Binding var drafts: [String: QuestionDraft]
    var enabled: Bool = true
    var onDismiss: () -> Void
    var onAnswer: (String, [JSONValue], @escaping (Bool) -> Void) -> Void

    @State private var index = 0
    @State private var busy = false
    @State private var err: String?

    var body: some View {
        if question.questions.isEmpty { EmptyView() } else { card }
    }

    private var item: UserQuestionItem {
        question.questions[min(max(index, 0), question.questions.count - 1)]
    }

    private var draft: QuestionDraft { drafts[item.id] ?? QuestionDraft() }

    private var isPlan: Bool {
        question.questions.count == 1 && item.intentKind == "plan-review"
            && !item.multiSelect && item.options.count <= 2
            && item.options.contains { $0.label == item.approveLabel }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isPlan ? L.planReview() : "\(item.header ?? L.t("问题", "Question")) · \(index + 1)/\(question.questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(T.text2)
                Spacer()
                Button(L.t("收起", "Collapse"), action: onDismiss).disabled(busy)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.question).font(.title3).foregroundStyle(T.ink)
                if let detail = item.detail, !detail.isEmpty {
                    MarkdownView(source: detail, wrapCode: AppModel.shared.codeWordWrap)
                }
                if !isPlan {
                    ForEach(item.options, id: \.label) { opt in
                        let selected = draft.selected.contains(opt.label)
                        Button {
                            var next = draft
                            if item.multiSelect {
                                if selected { next.selected.remove(opt.label) } else { next.selected.insert(opt.label) }
                            } else {
                                next.selected = [opt.label]
                            }
                            drafts[item.id] = next
                            err = nil
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(opt.label).foregroundStyle(T.ink)
                                    if let description = opt.description {
                                        Text(description).font(.caption).foregroundStyle(T.text3)
                                    }
                                }
                                Spacer()
                                if selected { Image(systemName: "checkmark").foregroundStyle(T.accent) }
                            }
                            .padding(12)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? T.accent : T.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                    }
                    TextField(L.typeYourAnswer(), text: Binding(
                        get: { draft.custom },
                        set: { drafts[item.id] = QuestionDraft(selected: draft.selected, custom: $0); err = nil }
                    ), axis: .vertical)
                    .lineLimit(1...4)
                    .disabled(busy)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                }
                if let err { Text(err).font(.caption).foregroundStyle(T.err) }
                if busy { Text(L.t("正在提交…", "Submitting…")).foregroundStyle(T.text3) }
                else if question.state == "continued" {
                    Text(L.t("智能体已继续工作，仍可补充答案", "The agent continued; you can still add an answer"))
                        .font(.caption)
                        .foregroundStyle(T.text3)
                }
                if isPlan {
                    Button(L.approvePlan()) {
                        drafts[item.id] = QuestionDraft(selected: [item.approveLabel ?? ""], custom: "")
                        submit()
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(T.onPrimary)
                    .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(!enabled || busy)
                    Button(L.t("继续讨论", "Keep discussing"), action: onDismiss)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                        .disabled(busy)
                } else {
                    HStack {
                        if index > 0 {
                            Button(L.t("上一题", "Previous")) { index -= 1; err = nil }.disabled(busy)
                        }
                        Button(L.skip()) {
                            drafts[item.id] = QuestionDraft()
                            if index < question.questions.count - 1 { index += 1 } else { submit() }
                        }
                        .disabled(busy || (index >= question.questions.count - 1 && !enabled))
                        Spacer()
                        Button(index < question.questions.count - 1 ? L.nextQuestion() : L.t("提交答案", "Submit answers")) {
                            if !draft.answered { err = L.completeQuestionFirst() }
                            else if index < question.questions.count - 1 { index += 1; err = nil }
                            else { submit() }
                        }
                        .disabled(busy || (index >= question.questions.count - 1 && !enabled))
                    }
                }
            }
            .padding(18)
        }
        .frame(maxHeight: 420)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.border, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .onChange(of: question.questionId) { _ in
            index = 0
            busy = false
            err = nil
        }
    }

    private func submit() {
        if busy || !enabled { return }
        busy = true
        err = nil
        onAnswer(question.callId ?? question.questionId, questionAnswers(question, drafts: drafts)) { success in
            if !success {
                busy = false
                err = L.t("提交失败，答案已保留，请重试", "Submit failed; answers kept. Try again.")
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
                    Image(systemName: "flag").foregroundStyle(T.text3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goalPhaseLabel(phase: goal["phase"].str(), activation: activation))
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
                        Text(goalPhaseLabel(phase: goal["phase"].str(), activation: model.goalActivation))
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
        return HStack(spacing: 8) {
            if single {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").foregroundStyle(T.text3)
            }
            if editing {
                TextField(L.t("编辑排队消息", "Edit queued message"), text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .disabled(!enabled || busyId != nil)
            } else {
                Text(queuePreview(prompt)).font(.subheadline).foregroundStyle(T.text2).lineLimit(1)
            }
            Spacer(minLength: 4)
            if prompt.sending {
                Text(L.t("发送中…", "Sending…")).font(.subheadline).foregroundStyle(T.text3)
            }
            if editing {
                icon("checkmark", enabled: actionable && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    apply(prompt.id, .edit(draft))
                }
                icon("xmark", enabled: busyId == nil) { editingId = nil; draft = "" }
            } else {
                icon("pencil", enabled: actionable && prompt.editable) { editingId = prompt.id; draft = prompt.text }
                icon("trash", enabled: actionable) { apply(prompt.id, .remove) }
                icon("paperplane", enabled: actionable && running) { apply(prompt.id, .steer) }
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

    private func icon(_ system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13))
                .foregroundStyle(T.text3.opacity(enabled ? 1 : 0.45))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func queuePreview(_ prompt: QueuedPrompt) -> String {
        var parts: [String] = []
        if prompt.images > 0 {
            parts.append(L.en ? "\(prompt.images) image\(prompt.images == 1 ? "" : "s")" : "\(prompt.images) 张图片")
        }
        if prompt.files > 0 {
            parts.append(L.en ? "\(prompt.files) file\(prompt.files == 1 ? "" : "s")" : "\(prompt.files) 个文件")
        }
        let text = prompt.text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { parts.append(text) }
        return parts.joined(separator: " · ")
    }
}

struct CommandSheet: View {
    @ObservedObject var model: AppModel
    var initialQuery: String = ""
    var leading: Bool = true
    var consumeSlash: Bool = true
    var onDismiss: () -> Void
    var onFile: () -> Void
    var onGoal: () -> Void
    var onPlan: () -> Void
    var onFeedback: () -> Void
    var onCompact: () -> Void
    var onPerm: () -> Void
    var onModel: () -> Void
    var onExport: () -> Void

    @State private var query = ""
    @State private var commands: [JSONValue] = []
    @State private var skills: [SkillEntry] = []
    @State private var loading = true
    @State private var error: String?
    @State private var attempt = 0

    private var sessionReady: Bool { model.chat?.loaded == true }
    private var subagent: Bool {
        model.sessions.first { $0.sessionId == model.chat?.sessionId }?.origin == "subagent"
    }

    private var candidates: [JSONValue] {
        commandMenuMerge(
            host: commands,
            injected: commandMenuClientRows(ops: model.ops, sessionReady: sessionReady, subagent: subagent)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(L.en ? "Search…" : "搜索…", text: $query)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let error {
                        Text(error).foregroundStyle(T.err)
                        Button(L.retry()) { attempt += 1 }.disabled(!model.isOnline)
                    }
                    let collision = commandContributionCollision(candidates)
                    if let collision {
                        Text(commandContributionCollisionMessage(collision, english: L.en))
                            .foregroundStyle(T.err)
                    }
                    let rows = collision == nil ? commandMenuRows(candidates, query: query, leading: leading, english: L.en) : []
                    let skillRows = skillMenuRows(skills, query: query)
                    if !loading && error == nil && rows.isEmpty && skillRows.isEmpty {
                        Text(L.noOptions()).foregroundStyle(T.text3)
                    }
                    if !query.isEmpty && !rows.isEmpty {
                        Text(L.sectionCommands()).font(.caption).foregroundStyle(T.text3)
                    }
                    ForEach(Array(commandSections(rows).enumerated()), id: \.offset) { _, item in
                        switch item {
                        case .section(let title):
                            Text(title).font(.caption).foregroundStyle(T.text3)
                        case .command(let command):
                            let name = command["name"].str() ?? ""
                            commandRow(command, name: name, kind: commandMenuKind(command))
                        }
                    }
                    if !query.isEmpty && !skillRows.isEmpty {
                        Text(L.sectionSkills()).font(.caption).foregroundStyle(T.text3)
                    }
                    ForEach(Array(skillSections(skillRows).enumerated()), id: \.offset) { _, item in
                        switch item {
                        case .section(let title):
                            Text(title).font(.caption).foregroundStyle(T.text3)
                        case .skill(let skill):
                            skillRow(skill)
                        }
                    }
                }
                .padding(22)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.cancel(), action: onDismiss) } }
        }
        .onAppear { query = initialQuery }
        .task(id: "\(model.activeId ?? "")-\(model.chat?.sessionId ?? "")-\(sessionReady)-\(attempt)-\(model.isOnline)-\(model.ops.sorted().joined())-\(subagent)") {
            await load()
        }
    }

    @ViewBuilder
    private func commandRow(_ command: JSONValue, name: String, kind: String?) -> some View {
        let label = commandMenuLabel(command, english: L.en)
        let available: Bool = {
            switch kind {
            case "file": return model.ops.contains("attachments.upload")
            case "model": return model.ops.contains("models.catalog")
            case "feedback": return model.ops.contains("sessionFeedback.record")
            case "export": return model.ops.contains("session.export")
            case "permission": return model.ops.contains("permissions.catalog")
            default: return model.ops.contains("commands.execute")
            }
        }()
        let enabled = model.isOnline && sessionReady && available
        Button {
            guard enabled else { return }
            @MainActor func consume() { if consumeSlash { model.consumeComposerSlash() } }
            switch kind {
            case "file": consume(); onDismiss(); onFile()
            case "model": consume(); onModel()
            case "goal": consume(); onGoal()
            case "plan":
                consume()
                if name == "plan" { onPlan() } else { model.executeCommand("/\(name)") }
                onDismiss()
            case "feedback": consume(); onFeedback()
            case "compact":
                consume()
                if name == "compact" { onCompact() } else { model.executeCommand("/\(name)") }
                onDismiss()
            case "permission": consume(); onPerm()
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
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: commandIcon(kind)).foregroundStyle(enabled ? T.text2 : T.text3)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(label ?? name).foregroundStyle(enabled ? T.ink : T.text3)
                        if let label, label.caseInsensitiveCompare(name) != .orderedSame {
                            Text(name).font(.caption).foregroundStyle(T.text3)
                        }
                    }
                    if let detail = commandMenuDescription(command, english: L.en) {
                        Text(detail).font(.caption).foregroundStyle(T.text3)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func commandIcon(_ kind: String?) -> String {
        switch kind {
        case "file": return "paperclip"
        case "model": return "cylinder.split.1x2"
        case "goal": return "flag"
        case "plan": return "checklist"
        case "feedback": return D.paperPlane
        case "compact": return "arrow.down.right.and.arrow.up.left"
        case "permission": return "hand.raised"
        case "export": return D.download
        default: return "chevron.left.forwardslash.chevron.right"
        }
    }

    @ViewBuilder
    private func skillRow(_ skill: SkillEntry) -> some View {
        let enabled = model.isOnline && sessionReady
        Button {
            guard enabled else { return }
            model.insertComposer("/\(skill.name) ")
            onDismiss()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "sparkle").foregroundStyle(enabled ? T.text2 : T.text3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name).foregroundStyle(enabled ? T.ink : T.text3)
                    let detail = skill.menuDescription(english: L.en)
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundStyle(T.text3)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private enum CommandListItem {
        case section(String)
        case command(JSONValue)
    }

    private enum SkillListItem {
        case section(String)
        case skill(SkillEntry)
    }

    private func commandSections(_ rows: [JSONValue]) -> [CommandListItem] {
        var items: [CommandListItem] = []
        var lastSection: String?
        for command in rows {
            if query.isEmpty, let name = command["name"].str() {
                let section = commandAddNames.contains(name) ? L.sectionAdd() : L.sectionCommands()
                if section != lastSection {
                    items.append(.section(section))
                    lastSection = section
                }
            }
            items.append(.command(command))
        }
        return items
    }

    private func skillSections(_ rows: [SkillEntry]) -> [SkillListItem] {
        guard !rows.isEmpty else { return [] }
        var items: [SkillListItem] = []
        if query.isEmpty {
            items.append(.section(L.sectionSkills()))
        }
        for skill in rows {
            items.append(.skill(skill))
        }
        return items
    }

    private func load() async {
        if !model.isOnline || !sessionReady {
            loading = model.isOnline && !sessionReady
            return
        }
        loading = true
        error = nil
        do {
            let id = model.chat?.sessionId
            if id == nil || subagent || !model.ops.contains("commands.list") {
                commands = []
            } else {
                commands = try await model.commandCatalog(sessionId: id!)
            }
            if id == nil || subagent || !model.ops.contains("skills.list") {
                skills = []
            } else {
                do {
                    skills = try await model.skillCatalog(sessionId: id!)
                } catch is CancellationError {
                    return
                } catch {
                    #if DEBUG
                    print("[dsh.skills] list failed session=\(id ?? "") error=\(error)")
                    #endif
                    skills = []
                }
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription.isEmpty ? (L.en ? "Could not load commands" : "无法加载指令") : error.localizedDescription
        }
        loading = false
    }
}
