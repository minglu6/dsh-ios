import SwiftUI
import UIKit
import DSHProtocol

struct ChatView: View {
    @ObservedObject var model: AppModel
    @State private var showModels = false
    @State private var showMore = false

    var body: some View {
        VStack(spacing: 0) {
            header
            approvals
            transcript
            composer
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: $showModels) { ModelPickerSheet(model: model) }
        .confirmationDialog(L.more(), isPresented: $showMore, titleVisibility: .visible) {
            Button(L.trajectory()) { model.push(.panel(.trajectory)) }
            Button(L.files()) { model.push(.panel(.files)) }
            Button(L.terminal()) { model.push(.panel(.terminal)) }
            Button(L.jobs()) { model.push(.panel(.jobs)) }
            Button(L.cancel(), role: .cancel) {}
        }
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
            Button { showModels = true } label: {
                Text(model.modelChoice?.name ?? L.modelsNav())
                    .font(.caption)
                    .foregroundStyle(T.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(T.tint, in: Capsule())
            }
            Button { showMore = true } label: {
                Image(systemName: "ellipsis").foregroundStyle(T.ink)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(T.surface)
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
                        MessageRow(item: item)
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

struct MessageRow: View {
    let item: Item

    var body: some View {
        switch item {
        case .user(let user):
            HStack {
                Spacer(minLength: 48)
                Text(user.text)
                    .foregroundStyle(T.ink)
                    .padding(12)
                    .background(T.bubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        case .text(let text):
            VStack(alignment: .leading, spacing: 6) {
                Text(text.text).foregroundStyle(T.ink)
                if !text.live {
                    Button(L.copy()) {
                        UIPasteboard.general.string = text.text
                    }
                    .font(.caption)
                    .foregroundStyle(T.text3)
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
                    Text(tool.name).font(.subheadline.weight(.medium))
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
            VStack(alignment: .leading) {
                ForEach(deliverable.files, id: \.path) { file in
                    Text(file.path).font(.footnote.monospaced()).foregroundStyle(T.link)
                }
            }
        case .context:
            EmptyView()
        }
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

struct ComposerView: View {
    @ObservedObject var model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let mentions = mentionPanel {
                mentions
            }
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
