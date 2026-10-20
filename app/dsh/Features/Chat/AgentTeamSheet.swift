import SwiftUI
import DSHProtocol

/// Touch presentation of the official TeamAction roster and read-only task board.
/// The caller resolves the Lead Session from the actual subagent address; catalog membership
/// alone must never be used to manufacture a Team or to select its root.
struct AgentTeamSheet: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    let leadSessionId: String
    @Environment(\.dismiss) private var dismiss

    private var projection: SessionHeaderProjection? { model.headerProjections[leadSessionId] }
    private var team: AgentTeamSnapshot? { projection?.team }
    private var loading: Bool { model.headerProjectionLoading.contains(leadSessionId) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if loading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(L.t("正在加载团队…", "Loading Team…"))
                                .foregroundStyle(T.text2)
                        }
                        .accessibilityIdentifier("agentTeamLoading")
                    }
                    if let error = model.headerProjectionErrors[leadSessionId] ?? projection?.errors["agentTeam"] {
                        diagnostic(error)
                    }
                    if let team {
                        if let failure = team.failure {
                            diagnostic(L.t("团队持久记录无效：", "Invalid persisted Team record: ") + failure)
                        }
                        members(team.members)
                        tasks(team.tasks)
                    } else if !loading {
                        Text(L.t("Team 暂不可用：Host 未提供团队数据", "Team is unavailable: the Host has not provided Team data"))
                            .foregroundStyle(T.text2)
                            .accessibilityIdentifier("agentTeamUnavailable")
                    }
                }
                .font(PhoneTypography.font(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(T.bg)
            .navigationTitle(L.t("智能体团队", "Agent Team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("关闭", "Close")) { dismiss() }
                        .font(PhoneTypography.font(size: 16))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L.t("刷新", "Refresh")) {
                        Task { await model.loadHeaderProjection(sessionId: leadSessionId) }
                    }
                    .font(PhoneTypography.font(size: 16))
                    .disabled(loading)
                }
            }
            .task(id: leadSessionId) {
                await model.loadHeaderProjection(sessionId: leadSessionId)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func diagnostic(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message).foregroundStyle(T.err)
            if team != nil {
                Text(L.t("保留最后有效的团队数据", "Showing the last valid Team data"))
                    .font(PhoneTypography.font(size: 14))
                    .foregroundStyle(T.text2)
            }
        }
        .textSelection(.enabled)
        .accessibilityIdentifier("agentTeamError")
    }

    private func members(_ rows: [AgentTeamMember]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                OfficialGlyph(kind: .usersOutline, size: 18, color: T.text2)
                Text(L.t("成员", "Members")).fontWeight(.semibold)
                Text("\(rows.count)").foregroundStyle(T.text2)
            }
            if rows.isEmpty {
                Text(L.t("团队成员为空", "The Team roster is empty"))
                    .foregroundStyle(T.text2)
                    .accessibilityIdentifier("agentTeamEmptyRoster")
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { member in
                        memberRow(member)
                        if member.id != rows.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
            }
        }
    }

    private func memberRow(_ member: AgentTeamMember) -> some View {
        let current = member.id == sessionId
        let running = model.sessions.first(where: { $0.sessionId == member.id })?.running
        let canOpen = model.isOnline && member.phase == .active && !current
        return Button {
            guard canOpen else { return }
            if member.id == leadSessionId {
                model.openHeaderSession(member.id)
            } else {
                // Official mount.ts always opens roster peers as continuable children of the Lead.
                model.openHeaderSession(member.id, parentSessionId: leadSessionId, mode: "continuable")
            }
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                memberIndicator(member.phase, running: running)
                    .frame(width: 16, height: 22)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(member.name)
                            .font(PhoneTypography.font(size: 16, weight: .medium))
                            .foregroundStyle(T.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if current {
                            Text(L.t("当前会话", "Current chat"))
                                .font(PhoneTypography.font(size: 14))
                                .foregroundStyle(T.accent)
                                .fixedSize()
                        }
                    }
                    Text(memberStatus(member.phase, running: running))
                        .font(PhoneTypography.font(size: 14))
                        .foregroundStyle(member.phase == .failed ? T.err : T.text2)
                    if let error = member.error {
                        Text(error)
                            .font(PhoneTypography.font(size: 14))
                            .foregroundStyle(T.err)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
        .accessibilityIdentifier("agentTeamMember_\(member.id)")
        .accessibilityHint(canOpen ? L.t("打开成员会话", "Open member conversation") : "")
    }

    @ViewBuilder
    private func memberIndicator(_ phase: AgentTeamMemberPhase, running: Bool?) -> some View {
        if phase == .failed {
            Circle().fill(T.err).frame(width: 8, height: 8)
        } else if phase == .provisioning || running == true {
            ProgressView().controlSize(.small)
        } else {
            OfficialGlyph(kind: .userOutline, size: 16, color: T.text2)
        }
    }

    private func memberStatus(_ phase: AgentTeamMemberPhase, running: Bool?) -> String {
        switch phase {
        case .provisioning: return L.t("准备中", "Provisioning")
        case .failed: return L.t("失败", "Failed")
        case .active:
            guard let running else { return L.t("已就绪 · 活动状态未知", "Active · activity unavailable") }
            return running ? L.t("运行中", "Running") : L.t("未运行", "Inactive")
        }
    }

    private func tasks(_ rows: [AgentTeamTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(L.t("共享任务", "Shared tasks")).fontWeight(.semibold)
                Text("\(rows.count)").foregroundStyle(T.text2)
            }
            if rows.isEmpty {
                Text(L.t("暂无共享任务，可以通过对话创建", "No shared tasks yet. Create them through the conversation."))
                    .foregroundStyle(T.text2)
                    .accessibilityIdentifier("agentTeamEmptyTasks")
            } else {
                ForEach(rows) { task in
                    AgentTeamTaskCard(task: task)
                }
            }
        }
    }
}

private struct AgentTeamTaskCard: View {
    let task: AgentTeamTask
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.subject)
                .font(PhoneTypography.font(size: 16, weight: .semibold))
                .foregroundStyle(T.ink)
            HStack(spacing: 7) {
                Circle().fill(statusColor).frame(width: 7, height: 7)
                Text(statusLabel)
                    .font(PhoneTypography.font(size: 14))
                    .foregroundStyle(T.text2)
            }
            Text(task.description)
                .font(PhoneTypography.font(size: 16))
                .foregroundStyle(T.ink)
                .lineLimit(expanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            if !task.description.isEmpty {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 4) {
                        Text(expanded ? L.t("收起", "Show less") : L.t("展开", "Show more"))
                            .font(PhoneTypography.font(size: 14))
                        OfficialGlyph(kind: .chevronDown, size: 12, color: T.text2)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(T.text2)
                .accessibilityValue(expanded ? L.t("已展开", "Expanded") : L.t("已收起", "Collapsed"))
                .accessibilityIdentifier("agentTeamTaskExpand_\(task.id)")
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(task.id)
                Text("Owner: \(task.ownerName ?? L.t("未分配", "Unowned"))")
                if task.status == .pending {
                    Text(task.ready ? L.t("可开始", "Ready") : L.t("被依赖阻塞", "Blocked by dependencies"))
                }
                if !task.blockedBy.isEmpty {
                    Text(L.t("依赖：", "Blocked by: ") + task.blockedBy.joined(separator: ", "))
                }
                if !task.writeScopes.isEmpty {
                    Text(L.t("写入范围：", "Write scopes: ") + task.writeScopes.joined(separator: ", "))
                }
                ForEach(Array(task.writeScopeWarnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning).foregroundStyle(T.warnText)
                }
            }
            .font(PhoneTypography.font(size: 14))
            .foregroundStyle(T.text2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .accessibilityIdentifier("agentTeamTask_\(task.id)")
    }

    private var statusLabel: String {
        switch task.status {
        case .pending: return L.t("待处理", "Pending")
        case .inProgress: return L.t("进行中", "In progress")
        case .completed: return L.t("已完成", "Completed")
        // Host views normally omit tombstones. Never present a deleted task as completed.
        case .deleted: return L.t("已删除", "Deleted")
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .pending: return task.ready ? T.text3 : T.warnText
        case .inProgress, .completed: return T.accent
        case .deleted: return T.text3
        }
    }
}
