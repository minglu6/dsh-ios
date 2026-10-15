import SwiftUI
import DSHProtocol

struct SessionDrawer: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var now = Int64(Date().timeIntervalSince1970 * 1000)
    @State private var viewOptions = false
    @State private var addWorkspace = false
    @State private var overflow: [String: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("dsh").font(.title3.weight(.semibold)).foregroundStyle(T.ink)
                Spacer()
                Button { model.createAndOpenSession() } label: {
                    Image(systemName: "square.and.pencil").foregroundStyle(T.ink)
                }
                Button { model.push(.settings); model.showDrawer = false } label: {
                    Image(systemName: "gearshape").foregroundStyle(T.ink)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(T.text3)
                TextField(L.searchSessions(), text: $query)
                    .textInputAutocapitalization(.never)
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
                    Image(systemName: "slider.horizontal.3").foregroundStyle(T.text2)
                }
                .accessibilityLabel(L.viewOptions())
                if model.ops.contains("workspace.create") {
                    Button { addWorkspace = true } label: {
                        Image(systemName: "plus").foregroundStyle(T.text2)
                    }
                    .accessibilityLabel(L.addWorkspace())
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if pinnedRows.isEmpty && rest.isEmpty && model.workspaces.isEmpty {
                        Text(L.emptySessions()).foregroundStyle(T.text3).padding(24)
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
                            workspaces: model.workspaces,
                            sessions: rest,
                            tree: model.sessionGroupBy == .workspaceTree
                        ) { key, rows in
                            sessionRows(rows, groupKey: key)
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
        .confirmationDialog(L.viewOptions(), isPresented: $viewOptions, titleVisibility: .visible) {
            Button(L.groupByWorkspace()) { model.setSessionGroupBy(.workspace) }
            Button(L.groupByWorkspaceTree()) { model.setSessionGroupBy(.workspaceTree) }
            Button(L.groupByFlat()) { model.setSessionGroupBy(.flat) }
            Button(L.cancel(), role: .cancel) {}
        }
        .sheet(isPresented: $addWorkspace) {
            WorkspaceDirectorySheet(model: model, onDismiss: { addWorkspace = false })
        }
    }

    private var visibleSessions: [SessionSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filter: WorkspaceArchivedFilter
        switch model.archivedFilter {
        case .hide: filter = .hide
        case .show: filter = .show
        case .only: filter = .only
        }
        return model.sessions.filter { session in
            guard visibleDrawerSession(session, current: model.chat?.sessionId, archived: model.archivedIds, filter: filter) else {
                return false
            }
            if q.isEmpty { return true }
            return (session.title ?? "").lowercased().contains(q)
        }
    }

    private var pinnedRows: [SessionSummary] {
        visibleSessions.filter { model.pinnedIds.contains($0.sessionId) && !model.archivedIds.contains($0.sessionId) }
    }

    private var rest: [SessionSummary] {
        visibleSessions.filter { !model.pinnedIds.contains($0.sessionId) || model.archivedIds.contains($0.sessionId) }
    }

    @ViewBuilder
    private func sessionRows(_ rows: [SessionSummary], groupKey: String?) -> some View {
        let slice = projectSessions(rows, groupKey: groupKey)
        ForEach(slice.rows) { session in
            sessionRow(session)
        }
        if let groupKey, slice.idle > 5 {
            Button {
                overflow[groupKey] = slice.hidden == 0 ? 5 : (slice.hidden <= 5 ? Int.max : slice.limit + 5)
            } label: {
                Text(slice.hidden == 0 ? L.showLess() : L.showMoreSessions(slice.hidden))
                    .font(.system(size: 13))
                    .foregroundStyle(T.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 48)
                    .padding(.vertical, 8)
            }
        }
    }

    private func projectSessions(_ rows: [SessionSummary], groupKey: String?) -> (rows: [SessionSummary], idle: Int, hidden: Int, limit: Int) {
        let limit = groupKey == nil ? Int.max : (overflow[groupKey!] ?? 5)
        var idle = 0
        let projected = rows.filter { session in
            if session.blank || session.running { return true }
            idle += 1
            return idle <= limit
        }
        return (projected, idle, rows.count - projected.count, limit)
    }

    private func sessionRow(_ session: SessionSummary) -> some View {
        let selected = model.chat?.sessionId == session.sessionId
        return Button {
            model.openSession(session.sessionId)
        } label: {
            HStack(spacing: 10) {
                leading(session)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title?.isEmpty == false ? session.title! : L.newSession())
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                    Text(formatSessionTime(at: session.updatedAt, now: now, language: model.language))
                        .font(.caption)
                        .foregroundStyle(T.text3)
                }
                Spacer()
                if model.unreadIds.contains(session.sessionId) {
                    Circle().fill(T.ok).frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? T.sidebarActiveAccent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 8)
        .contextMenu {
            Button(model.pinnedIds.contains(session.sessionId) ? L.unpinSession() : L.pinSession()) {
                model.pin(session)
            }
            Button(L.fork()) { model.fork(session) }
            Button(L.archiveSession()) { model.archive(session) }
        }
    }

    @ViewBuilder
    private func leading(_ session: SessionSummary) -> some View {
        if session.running {
            ProgressView().controlSize(.mini)
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
                panel(L.pluginsNav(), "puzzlepiece.extension", .plugins)
            }
            if model.ops.contains("schedule.catalog") {
                panel(L.scheduleNav(), "calendar", .schedule)
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
