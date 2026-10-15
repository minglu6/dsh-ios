import SwiftUI
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
    @State private var draggingSession: String?

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
                Button { model.push(.settings); model.showDrawer = false } label: {
                    Image(systemName: D.gear).foregroundStyle(T.ink)
                }
                .accessibilityLabel(L.settings())
                .accessibilityIdentifier("drawerSettingsGear")
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
                    Button(L.clearSearch()) { query = ""; model.searchHits = [] }
                        .font(.caption)
                        .foregroundStyle(T.text3)
                }
            }
            .padding(10)
            .background(T.fill, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if model.ops.contains("plugins.list") || model.ops.contains("schedule.catalog") {
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
                if model.ops.contains("workspace.create") {
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
                        if let error = model.searchError { Text(error).foregroundStyle(T.err).padding(16) }
                        if hits.isEmpty && !model.searching && model.searchError == nil {
                            Text(L.noMatchingSessions()).foregroundStyle(T.text3).padding(16)
                        }
                        sessionRows(hits, groupKey: nil, cap: false)
                    } else {
                        if pinnedRows.isEmpty && rest.isEmpty && model.workspaces.isEmpty {
                            Text(emptyCopy).foregroundStyle(T.text3).padding(24)
                        }
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
                            WorkspaceNavigationGroups(
                                model: model,
                                workspaces: orderedWorkspaces,
                                sessions: rest,
                                tree: model.sessionGroupBy == .workspaceTree,
                                onMoveWorkspace: canDragWorkspaces ? { from, before in
                                    model.moveWorkspace(id: from, beforeId: before)
                                } : nil
                            ) { key, rows in
                                sessionRows(rows, groupKey: key)
                            }
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

    private var hits: [SessionSummary] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let local = SessionSearch.localMatches(sessions: model.sessions, workspaces: model.workspaces, query: needle)
        return SessionSearch.merge(hits: model.searchHits, local: local).filter {
            visibleDrawerSession($0, current: model.chat?.sessionId, archived: model.archivedIds, filter: filter)
        }
    }

    private var pinnedRows: [SessionSummary] {
        visibleSessions.filter { model.pinnedIds.contains($0.sessionId) && !model.archivedIds.contains($0.sessionId) }
    }

    private var rest: [SessionSummary] {
        visibleSessions.filter { !model.pinnedIds.contains($0.sessionId) || model.archivedIds.contains($0.sessionId) }
    }

    private var emptyCopy: String {
        if model.currentDot != .online { return L.connectToViewSessions() }
        if model.archivedFilter == .only { return L.emptyArchivedSessions() }
        return L.emptySessions()
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
            else { model.openSession(session.sessionId) }
        } label: {
            HStack(spacing: 10) {
                leading(session)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title?.isEmpty == false ? session.title! : L.newSession())
                        .foregroundStyle(archived ? T.text3 : T.ink)
                        .lineLimit(1)
                    if let snippet = session.searchSnippet, searching {
                        Text(snippet).font(.caption).foregroundStyle(T.accent).lineLimit(2)
                    } else {
                        Text(formatSessionTime(at: session.updatedAt, now: now, language: model.language))
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
            if !archived {
                Button(model.pinnedIds.contains(session.sessionId) ? L.unpinSession() : L.pinSession()) {
                    model.pin(session)
                }
                Button(L.fork()) { model.fork(session) }
                Button(L.archiveSession()) { model.archive(session) }
            } else {
                Button(L.unarchiveSession()) { model.unarchive(session.sessionId) }
            }
        }
    }

    @ViewBuilder
    private func leading(_ session: SessionSummary) -> some View {
        let archived = model.archivedIds.contains(session.sessionId)
        if session.running {
            ProgressView().controlSize(.mini)
        } else if archived {
            Image(systemName: D.archive).foregroundStyle(T.text3).font(.caption)
        } else if model.unreadIds.contains(session.sessionId) {
            Circle()
                .fill(T.ok)
                .frame(width: 8, height: 8)
                .accessibilityLabel(L.completedUnread())
        } else if model.approvals.contains(where: { $0.sessionId == session.sessionId }) {
            Image(systemName: "hand.raised.fill").foregroundStyle(T.warnText).font(.caption)
        } else {
            Image(systemName: "bubble.left").foregroundStyle(T.text3).font(.caption)
        }
    }

    private var drawerPanels: some View {
        VStack(spacing: 0) {
            Divider().padding(.vertical, 8)
            if model.ops.contains("plugins.list") {
                panel(L.pluginsNav(), D.plugin, .plugins)
            }
            if model.ops.contains("schedule.catalog") {
                panel(L.scheduleNav(), D.clock, .schedule)
            }
        }
    }

    private func panel(_ title: String, _ system: String, _ panel: DrawerPanel) -> some View {
        Button {
            model.push(.panel(panel))
            model.showDrawer = false
        } label: {
            Label(title, systemImage: system)
                .foregroundStyle(T.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
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
        }
        .background(T.surface)
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
