import SwiftUI
import DSHProtocol

/// Compact session actions; the preset remains a passive current-session indicator.
struct ConversationHeaderActions: View {
    @ObservedObject var model: AppModel

    @State private var teamOpen = false

    var body: some View {
        if let chat = model.chat {
            let parent = model.currentSubagentAddress?.parentSessionId ?? chat.sessionId
            let projection = model.headerProjections[parent]
            let blank = model.sessions.first { $0.sessionId == chat.sessionId }?.blank == true
            let preset = SessionContextPolicy.presetName(
                id: chat.agentPreset, roster: model.presetRoster, english: L.en
            )
            HStack(spacing: 8) {
                if projection?.team != nil || projection?.errors["agentTeam"] != nil {
                    Button { teamOpen = true } label: {
                        OfficialGlyph(kind: .usersOutline, size: 14, color: T.text2)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(L.t("智能体团队", "Agent Team"))
                    .accessibilityIdentifier("conversationTeam")
                    .fixedSize(horizontal: true, vertical: false)
                    .popover(isPresented: $teamOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        AgentTeamPopover(model: model, sessionId: chat.sessionId, leadSessionId: parent)
                            .modifier(PopoverCompactAdaptation())
                    }
                }
                ConversationHeaderPreset(name: preset, loaded: chat.loaded, blank: blank)
                ConversationSubagentAction(model: model)
            }
            .buttonStyle(.plain)
            .font(Font.system(size: 12))
            .foregroundStyle(T.text2)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 28)
            .accessibilityElement(children: .contain)
            .onChange(of: chat.sessionId) { _ in
                teamOpen = false
            }
        }
    }
}

private struct ConversationSubagentAction: View {
    @ObservedObject var model: AppModel
    @State private var catalogOpen = false

    var body: some View {
        if let chat = model.chat {
            let parent = model.currentSubagentAddress?.parentSessionId ?? chat.sessionId
            let children = sessionHeaderSubagents(
                parentSessionId: parent,
                catalog: model.headerProjections[parent]?.subagents,
                sessions: model.sessions
            )
            if !children.isEmpty {
                Button { catalogOpen.toggle() } label: {
                    HStack(spacing: 4) {
                        if children.contains(where: { $0.running == true }) {
                            Circle().fill(T.accent).frame(width: 6, height: 6)
                        }
                        Text(sessionHeaderSubagentCount(children.count, english: L.en))
                            .frame(height: 18)
                        OfficialGlyph(kind: .chevronDown, size: 14, color: T.text3)
                            .rotationEffect(.degrees(catalogOpen ? 180 : 0))
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(Font.system(size: 12))
                .foregroundStyle(T.text3)
                .lineLimit(1)
                .accessibilityLabel(sessionHeaderSubagentCount(children.count, english: L.en))
                .accessibilityIdentifier("conversationSubagents")
                .popover(isPresented: $catalogOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    SubagentCatalogMenu(model: model, parentSessionId: parent, currentSessionId: chat.sessionId) {
                        catalogOpen = false
                    }
                    .modifier(PopoverCompactAdaptation())
                }
                .onChange(of: chat.sessionId) { _ in catalogOpen = false }
            }
        }
    }
}

private struct SubagentCatalogMenu: View {
    @ObservedObject var model: AppModel
    let parentSessionId: String
    let currentSessionId: String
    let onDismiss: () -> Void

    var body: some View {
        MenuViewViewport(maxHeight: 420) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    model.openHeaderSession(parentSessionId)
                    onDismiss()
                } label: {
                    HStack(spacing: 8) {
                        OfficialGlyph(kind: .usersOutline, size: 14, color: T.text2)
                        Text(L.t("主智能体", "Main agent"))
                        Spacer()
                        if parentSessionId == currentSessionId {
                            OfficialGlyph(kind: .checkOutline, size: 14, color: T.ink)
                        }
                    }
                    .padding(10)
                }
                .disabled(!model.isOnline || currentSessionId == parentSessionId)
                .accessibilityIdentifier("subagentMainSession")
                Divider()
                SubagentCatalogRows(
                    model: model, parentSessionId: parentSessionId, currentSessionId: currentSessionId,
                    ancestors: [parentSessionId], onDismiss: onDismiss
                )
            }
            .padding(6)
        }
        .frame(width: min(360, UIScreen.main.bounds.width - 32))
        .font(Font.system(size: 14))
        .foregroundStyle(T.ink)
        .buttonStyle(.plain)
        .task(id: parentSessionId) { await model.loadHeaderProjection(sessionId: parentSessionId) }
    }
}

private struct SubagentCatalogRows: View {
    @ObservedObject var model: AppModel
    let parentSessionId: String
    let currentSessionId: String
    let ancestors: Set<String>
    let onDismiss: () -> Void
    @State private var expanded: Set<String> = []

    private var children: [HeaderSubagentRow] {
        sessionHeaderSubagents(
            parentSessionId: parentSessionId,
            catalog: model.headerProjections[parentSessionId]?.subagents,
            sessions: model.sessions
        ).filter { !ancestors.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.headerProjectionLoading.contains(parentSessionId) { ProgressView().padding(8) }
            if let error = model.headerProjectionErrors[parentSessionId] {
                Text(error).foregroundStyle(T.err).font(Font.system(size: 14)).padding(8)
                Button(L.docRetry()) {
                    Task { await model.loadHeaderProjection(sessionId: parentSessionId) }
                }
                .disabled(!model.isOnline || model.headerProjectionLoading.contains(parentSessionId))
                .padding(8)
            }
            if children.isEmpty && !model.headerProjectionLoading.contains(parentSessionId) {
                Text(L.t("尚无子智能体", "No subagents yet")).foregroundStyle(T.text3).padding(8)
            }
            ForEach(children) { child in
                HStack(spacing: 4) {
                    Button {
                        model.openHeaderSession(child.id, parentSessionId: parentSessionId, mode: child.mode)
                        onDismiss()
                    } label: {
                        HStack(spacing: 8) {
                            if child.running == true {
                                Circle().fill(T.accent).frame(width: 6, height: 6)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(child.title).lineLimit(2)
                                if child.mode == "external" {
                                    Text(L.t("外部子智能体", "External subagent")).foregroundStyle(T.text3)
                                }
                            }
                            Spacer(minLength: 4)
                            if child.id == currentSessionId {
                                OfficialGlyph(kind: .checkOutline, size: 14, color: T.ink)
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .disabled(!model.isOnline || child.id == currentSessionId || child.mode == "external")
                    .accessibilityIdentifier("subagentSession.\(child.id)")
                    if child.mode != "external" && model.ops.contains("sessions.projections") {
                        Button {
                            if expanded.contains(child.id) { expanded.remove(child.id) }
                            else { expanded.insert(child.id) }
                        } label: {
                            OfficialGlyph(kind: .chevronRight, size: 12, color: T.text2)
                                .rotationEffect(.degrees(expanded.contains(child.id) ? 90 : 0))
                                .frame(width: 30, height: 36)
                        }
                        .accessibilityLabel(L.t("展开 \(child.title) 的下级子智能体", "Expand children of \(child.title)"))
                    }
                }
                .padding(.horizontal, 8)
                if expanded.contains(child.id) {
                    SubagentCatalogRows(
                        model: model, parentSessionId: child.id, currentSessionId: currentSessionId,
                        ancestors: ancestors.union([child.id]), onDismiss: onDismiss
                    )
                    .padding(.leading, 14)
                    .task { await model.loadHeaderProjection(sessionId: child.id) }
                }
            }
        }
    }
}
