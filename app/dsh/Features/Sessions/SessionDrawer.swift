import SwiftUI
import UIKit
import DSHProtocol
import UniformTypeIdentifiers

struct SessionDrawer: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var now = Int64(Date().timeIntervalSince1970 * 1000)
    @State private var viewOptions = false
    @State private var addWorkspace = false
    @State private var overflow: [String: Int] = [:]
    @State private var restoreId: String?
    @State private var renameSession: SessionSummary?
    @State private var renameTitle = ""
    @State private var renameBusy = false
    @State private var draggingSession: String?
    @State private var lastOps: Set<String> = []

    private var visibleOps: Set<String> { model.isOnline ? model.ops : lastOps }

    private func rememberOps() {
        if model.isOnline && !model.ops.isEmpty { lastOps = model.ops }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ViewThatFits(in: .horizontal) {
                    BrandWordmark(height: 22)
                    BrandWordmark(height: 18)
                    BrandWordmark(height: 16)
                }
                Spacer(minLength: 8)
                Button { model.createAndOpenSession() } label: {
                    Image(systemName: D.newChat).foregroundStyle(T.ink)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack {
                Image(systemName: D.search).foregroundStyle(T.text3)
                    .accessibilityLabel(L.searchSessionsAria())
                TextField(L.searchSessions(), text: $query)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("sessionSearch")
                if !query.isEmpty {
                    Button(L.clearSearch()) {
                        query = ""
                        model.clearSessionSearch()
                    }
                    .font(.caption)
                    .foregroundStyle(T.text3)
                    .accessibilityLabel(L.clearSearch())
                }
            }
            .padding(10)
            .background(T.fill, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if visibleOps.contains("plugins.list") || visibleOps.contains("schedule.catalog") {
                drawerPanels.padding(.bottom, 4)
            }

            HStack {
                Text(model.sessionGroupBy == .flat ? L.sectionSessions() : L.sectionWorkspaces())
                    .font(.system(size: 13))
                    .foregroundStyle(T.text3)
                Spacer()
                Button { viewOptions = true } label: {
                    Image(systemName: D.sliders).foregroundStyle(T.text2)
                }
                .accessibilityLabel(L.viewOptions())
                if visibleOps.contains("workspace.create") {
                    Button { addWorkspace = true } label: {
                        Image(systemName: D.projectAdd).foregroundStyle(T.text2)
                    }
                    .accessibilityLabel(L.addWorkspace())
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if searching {
                        if model.searching { Text(L.searchingSessions()).foregroundStyle(T.text3).padding(16) }
                        if presented.rows.isEmpty && !model.searching {
                            Text(L.noMatchingSessions()).foregroundStyle(T.text3).padding(16)
                        }
                        sessionRows(presented.rows, groupKey: nil, cap: false)
                        if presented.hasMore {
                            Text(L.searchHasMore(SessionSearch.resultLimit))
                                .font(.caption)
                                .foregroundStyle(T.text3)
                                .padding(16)
                        }
                    } else if pinnedRows.isEmpty && rest.isEmpty {
                        if drawerShowsEmptySessions(
                            hasVisibleSessions: false,
                            groupByWorkspace: model.sessionGroupBy != .flat,
                            hasWorkspaces: !orderedWorkspaces.isEmpty,
                            archivedOnly: model.archivedFilter == .only
                        ) {
                            emptyState
                        } else {
                            workspaceGroups(sessions: rest)
                        }
                    } else {
                        if !pinnedRows.isEmpty {
                            Text(L.pinned())
                                .font(.system(size: 12))
                                .foregroundStyle(T.text3)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 4)
                            sessionRows(pinnedRows, groupKey: nil)
                        }
                        if model.sessionGroupBy == .flat {
                            sessionRows(rest, groupKey: "flat")
                        } else {
                            workspaceGroups(sessions: rest)
                        }
                    }
                }
            }
            footer
        }
        .background(T.drawer.ignoresSafeArea())
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            now = Int64(Date().timeIntervalSince1970 * 1000)
        }
        .onChange(of: query) { value in
            model.searchSessions(value)
        }
        .onChange(of: orderedIds) { value in
            if model.sessionOrderBy == .manual { model.persistManualOrder(value) }
        }
        .onAppear {
            rememberOps()
            model.refreshSessionsWhenVisible()
        }
        .onChange(of: model.isOnline) { _ in rememberOps() }
        .onChange(of: model.ops) { _ in rememberOps() }
        .confirmationDialog(L.viewOptions(), isPresented: $viewOptions, titleVisibility: .visible) {
            Button(L.groupByWorkspace()) { model.setSessionGroupBy(.workspace) }
            Button(L.groupByWorkspaceTree()) { model.setSessionGroupBy(.workspaceTree) }
            Button(L.groupByFlat()) { model.setSessionGroupBy(.flat) }
            Button(L.orderByManual()) { model.setSessionOrderBy(.manual) }
            Button(L.orderByUpdated()) { model.setSessionOrderBy(.updated) }
            Button(L.hideArchived()) { model.setArchivedFilter(.hide) }
            Button(L.showArchived()) { model.setArchivedFilter(.show) }
            Button(L.onlyArchived()) { model.setArchivedFilter(.only) }
            Button(L.cancel(), role: .cancel) {}
        }
        .sheet(isPresented: $addWorkspace) {
            WorkspaceDirectorySheet(model: model, onDismiss: { addWorkspace = false })
        }
        .alert(L.rename(), isPresented: Binding(get: { renameSession != nil }, set: { if !$0 && !renameBusy { renameSession = nil } })) {
            TextField(L.rename(), text: $renameTitle)
            Button(renameBusy ? L.savingEllipsis() : L.save()) {
                guard let session = renameSession else { return }
                renameBusy = true
                model.rename(session.sessionId, title: renameTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                renameBusy = false
                renameSession = nil
            }
            .disabled(!(model.isOnline && model.ops.contains("sessions.rename") && !renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !renameBusy))
            Button(L.cancel(), role: .cancel) { renameSession = nil }
        }
        .alert(L.archived(), isPresented: Binding(get: { restoreId != nil }, set: { if !$0 { restoreId = nil } })) {
            Button(L.unarchiveSession()) {
                if let id = restoreId {
                    model.unarchive(id, thenOpen: true)
                    restoreId = nil
                }
            }
            .disabled(!(model.isOnline && model.ops.contains("workspace.unarchiveSession")))
            Button(L.cancel(), role: .cancel) { restoreId = nil }
        } message: {
            Text(L.restoreArchivedBody())
        }
        .alert(
            archiveConfirmTitle(english: L.en),
            isPresented: Binding(
                get: { model.archiveConfirm != nil },
                set: { if !$0 { model.archiveConfirm = nil } }
            )
        ) {
            Button(archiveConfirmAction(english: L.en), role: .destructive) {
                guard let request = model.archiveConfirm else { return }
                model.archive(request.session, stopActivity: true)
            }
            .disabled(!(model.isOnline && model.ops.contains("workspace.archiveSession")))
            Button(L.cancel(), role: .cancel) { model.archiveConfirm = nil }
        } message: {
            if let request = model.archiveConfirm {
                Text(archiveConfirmMessage(request))
            }
        }
    }

    private var searching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var filter: WorkspaceArchivedFilter {
        switch model.archivedFilter {
        case .hide: return .hide
        case .show: return .show
        case .only: return .only
        }
    }

    private var visibleSessions: [SessionSummary] {
        ordered.filter {
            visibleDrawerSession($0, current: model.chat?.sessionId, archived: model.archivedIds, filter: filter)
        }
    }

    private var ordered: [SessionSummary] {
        let members = Dictionary(uniqueKeysWithValues: model.sessions.map { ($0.sessionId, $0) })
        if model.sessionOrderBy == .manual {
            let ids = reconcileSessionOrder(sessions: model.sessions, saved: model.manualOrder())
            return ids.compactMap { members[$0] }
        }
        return model.sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var orderedIds: [String] { ordered.map(\.sessionId) }

    private var orderedWorkspaces: [WorkspaceView] { model.workspaces }

    private var presented: SessionSearch.Presented {
        let needle = query
        let local = SessionSearch.localMatches(sessions: model.sessions, workspaces: model.workspaces, query: needle).filter {
            visibleDrawerSession($0, current: model.chat?.sessionId, archived: model.archivedIds, filter: filter)
        }
        let host = model.searchHits.filter {
            visibleDrawerSession($0, current: model.chat?.sessionId, archived: model.archivedIds, filter: filter)
        }
        return SessionSearch.present(hits: host, local: local, hostHasMore: model.searchHostHasMore)
    }

    private var pinnedRows: [SessionSummary] {
        visibleSessions.filter { model.pinnedIds.contains($0.sessionId) && !model.archivedIds.contains($0.sessionId) }
    }

    private var rest: [SessionSummary] {
        visibleSessions.filter { !model.pinnedIds.contains($0.sessionId) || model.archivedIds.contains($0.sessionId) }
    }

    @ViewBuilder
    private var emptyState: some View {
        let kind = drawerEmptyKind(
            online: model.currentDot == .online,
            archivedOnly: model.archivedFilter == .only,
            hasVisibleSessions: false
        )
        VStack(spacing: 12) {
            Text(emptyCopy(kind))
                .foregroundStyle(T.text3)
            if kind == .emptyArchived {
                Button(emptyArchivedViewOthers(english: L.en)) {
                    if emptyArchivedViewOthersResetsToHide {
                        model.setArchivedFilter(.hide)
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(T.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private func emptyCopy(_ kind: DrawerEmptyKind?) -> String {
        switch kind {
        case .empty, nil: return emptySessionsNone(english: L.en)
        case .emptyArchived: return L.emptyArchivedSessions()
        }
    }

    @ViewBuilder
    private func workspaceGroups(sessions: [SessionSummary]) -> some View {
        WorkspaceNavigationGroups(
            model: model,
            workspaces: orderedWorkspaces,
            sessions: sessions,
            tree: model.sessionGroupBy == .workspaceTree,
            onMoveWorkspace: canDragWorkspaces ? { from, before in
                model.moveWorkspace(id: from, beforeId: before)
            } : nil
        ) { key, rows in
            sessionRows(rows, groupKey: key)
        }
    }

    private var canDragWorkspaces: Bool {
        model.isOnline && model.ops.contains("workspace.insertBefore")
    }

    private var canDragSessions: Bool {
        model.isOnline && model.ops.contains("workspace.insertSessionBefore")
    }

    @ViewBuilder
    private func sessionRows(_ rows: [SessionSummary], groupKey: String?, cap: Bool = true) -> some View {
        let slice = cap ? projectSessions(rows, groupKey: groupKey) : (rows, 0, 0, Int.max)
        ForEach(slice.0) { session in
            sessionRow(session, groupKey: groupKey)
        }
        if cap, let groupKey, slice.1 > 5 {
            Button {
                overflow[groupKey] = slice.2 == 0 ? 5 : (slice.2 <= 5 ? Int.max : slice.3 + 5)
            } label: {
                Text(slice.2 == 0 ? L.showLess() : L.showMoreSessions(slice.2))
                    .font(.system(size: 13))
                    .foregroundStyle(T.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 48)
                    .padding(.vertical, 8)
            }
        }
    }

    private func projectSessions(_ rows: [SessionSummary], groupKey: String?) -> ([SessionSummary], Int, Int, Int) {
        let limit = groupKey == nil ? Int.max : (overflow[groupKey!] ?? 5)
        var idle = 0
        let projected = rows.filter { session in
            if session.blank || session.running { return true }
            idle += 1
            return idle <= limit
        }
        return (projected, idle, rows.count - projected.count, limit)
    }

    private func sessionRow(_ session: SessionSummary, groupKey: String?) -> some View {
        let selected = model.chat?.sessionId == session.sessionId
        let archived = model.isArchived(session.sessionId)
        return Button {
            if archived { restoreId = session.sessionId }
            else {
                if searching {
                    query = ""
                    model.clearSessionSearch()
                }
                model.openSession(session.sessionId)
            }
        } label: {
            HStack(spacing: 10) {
                leading(session)
                VStack(alignment: .leading, spacing: 2) {
                    Text(drawerSessionTitle(
                        session,
                        current: model.chat?.sessionId,
                        newSession: L.newSession(),
                        untitled: L.untitledSession()
                    ))
                        .foregroundStyle(archived ? T.text3 : T.ink)
                        .lineLimit(1)
                    if searching, searchResultShowsWorkspaceContext {
                        Text(workspaceContext(for: session.sessionId))
                            .font(.caption)
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                    }
                    if let snippet = session.searchSnippet, searching {
                        Text(snippet).font(.caption).foregroundStyle(T.accent).lineLimit(2)
                    } else if !searching, let trailing = sessionRowTrailingLabel(
                        blank: session.blank,
                        pending: sessionPendingInteraction(
                            awaitingApproval: model.approvals.contains { $0.sessionId == session.sessionId },
                            planReview: model.userQuestions.contains { question in
                                question.sessionId == session.sessionId
                                    && question.questions.contains { $0.intentKind == "plan-review" }
                            },
                            awaitingAnswer: model.userQuestions.contains { $0.sessionId == session.sessionId }
                        ),
                        updatedAt: session.updatedAt,
                        now: now,
                        english: L.en
                    ) {
                        Text(trailing)
                            .font(.caption)
                            .foregroundStyle(T.text3)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? T.sidebarActiveAccent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 8)
        .onDrag {
            draggingSession = session.sessionId
            return NSItemProvider(object: session.sessionId as NSString)
        }
        .onDrop(of: [.text], delegate: SessionDropDelegate(
            target: session,
            groupKey: groupKey,
            model: model,
            canDrag: canDragSessions,
            dragging: $draggingSession
        ))
        .contextMenu {
            if !archived, visibleOps.contains("workspace.pinSession") {
                Button(model.pinnedIds.contains(session.sessionId) ? L.unpinSession() : L.pinSession()) {
                    model.pin(session)
                }
                .disabled(!model.isOnline)
            }
            if visibleOps.contains("sessions.rename") {
                Button(L.rename()) {
                    renameTitle = session.title ?? ""
                    renameSession = session
                }
                .disabled(!model.isOnline)
            }
            if visibleOps.contains("sessions.fork") {
                Button(L.fork()) { model.fork(session) }
                    .disabled(!model.isOnline)
            }
            Button(L.copySessionId()) {
                UIPasteboard.general.string = session.sessionId
                model.showToast(L.sessionIdCopied())
            }
            if visibleOps.contains("workspace.archiveSession") {
                if archived {
                    Button(L.unarchiveSession()) { model.unarchive(session.sessionId) }
                        .disabled(!model.isOnline)
                } else {
                    Button(L.archiveSession()) { model.archive(session) }
                        .disabled(!model.isOnline)
                }
            }
        }
    }

    private func workspaceContext(for sessionId: String) -> String {
        if let workspace = model.workspaces.first(where: { $0.sessionIds.contains(sessionId) }) {
            return workspaceDisplayTitle(
                title: workspace.title,
                path: workspace.path,
                localizedDefault: L.defaultWorkspace()
            )
        }
        return L.ungrouped()
    }

    private func archiveConfirmMessage(_ request: ArchiveConfirmRequest) -> String {
        let title = drawerSessionTitle(
            request.session,
            current: model.chat?.sessionId,
            newSession: L.newSession(),
            untitled: L.untitledSession()
        )
        var lines = [
            archiveConfirmDescription(title: title, english: L.en),
            "",
            archiveConfirmActivityLabel(english: L.en),
        ]
        let activity = archiveActivityDescription(request.details, english: L.en)
        if !activity.isEmpty { lines.append(activity) }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private func leading(_ session: SessionSummary) -> some View {
        let archived = model.archivedIds.contains(session.sessionId)
        SidebarSessionLeadingView(
            kind: sidebarSessionLeading(
                running: session.running,
                archived: archived,
                unread: model.unreadIds.contains(session.sessionId),
                awaitingApproval: model.approvals.contains { $0.sessionId == session.sessionId },
                awaitingAnswer: model.userQuestions.contains { $0.sessionId == session.sessionId }
            ),
            english: L.en
        )
    }

    private var drawerPanels: some View {
        VStack(spacing: 0) {
            Divider().padding(.vertical, 8)
            if visibleOps.contains("plugins.list") {
                panel(L.pluginsNav(), .plugins) {
                    PluginPinwheelIcon(size: 16, color: T.ink)
                }
            }
            if visibleOps.contains("schedule.catalog") {
                panel(L.scheduleNav(), .schedule) {
                    Image(systemName: D.clock)
                }
            }
        }
    }

    private func panel<Icon: View>(_ title: String, _ panel: DrawerPanel, @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            model.push(.panel(panel))
            model.showDrawer = false
        } label: {
            Label {
                Text(title)
            } icon: {
                icon()
            }
            .foregroundStyle(T.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .opacity(model.isOnline ? 1 : 0.5)
        }
        .disabled(!model.isOnline)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if sidebarFooterActionAboveSettings {
                footerPeerDevice
                footerSettings
            } else {
                footerSettings
                footerPeerDevice
            }
        }
        .background(T.surface)
    }

    private var footerPeerDevice: some View {
        Button { model.push(.connections) } label: {
            HStack {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.activeProfile?.name ?? L.notConnected()).foregroundStyle(T.ink)
                    Text(footerSubtitle).font(.caption).foregroundStyle(T.text3)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(T.text3)
            }
            .padding(12)
        }
        .accessibilityIdentifier("drawerPeerDeviceRow")
    }

    private var footerSettings: some View {
        Button {
            model.push(.settings)
            model.showDrawer = false
        } label: {
            Label(L.settings(), systemImage: D.gear)
                .foregroundStyle(T.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .accessibilityIdentifier("drawerSettingsRow")
    }

    private var dotColor: Color {
        switch model.currentDot {
        case .online: return T.ok
        case .connecting: return T.accent
        case .unauthorized: return T.warnText
        default: return T.text3
        }
    }

    private var footerSubtitle: String {
        switch model.currentDot {
        case .online: return model.activeProfile?.kind ?? L.online()
        case .connecting: return L.connecting()
        case .unauthorized: return L.repairNeeded()
        default: return L.offline()
        }
    }
}

private struct SessionDropDelegate: DropDelegate {
    let target: SessionSummary
    let groupKey: String?
    let model: AppModel
    let canDrag: Bool
    @Binding var dragging: String?

    func performDrop(info: DropInfo) -> Bool {
        guard canDrag, let source = dragging, source != target.sessionId else { return false }
        let workspaceId = model.workspaces.first { $0.sessionIds.contains(target.sessionId) }?.workspaceId
            ?? groupKey.flatMap { key in
                key.hasPrefix("workspace:") ? String(key.dropFirst("workspace:".count)) : nil
            }
        guard let workspaceId else { return false }
        model.moveWorkspaceSession(workspaceId: workspaceId, sessionId: source, beforeSessionId: target.sessionId)
        dragging = nil
        return true
    }
}
