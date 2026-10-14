import SwiftUI
import DSHProtocol

struct SessionDrawer: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var now = Int64(Date().timeIntervalSince1970 * 1000)

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

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                        Text(group.title)
                            .font(.caption)
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        ForEach(group.sessions) { session in
                            sessionRow(session)
                        }
                    }
                    if grouped.allSatisfy(\.sessions.isEmpty) {
                        Text(L.emptySessions()).foregroundStyle(T.text3).padding(24)
                    }
                    if model.ops.contains("plugins.list") || model.ops.contains("schedule.catalog") {
                        drawerPanels
                    }
                }
            }
            footer
        }
        .background(T.drawer.ignoresSafeArea())
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            now = Int64(Date().timeIntervalSince1970 * 1000)
        }
    }

    private var visibleSessions: [SessionSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return model.sessions.filter { session in
            if model.archivedIds.contains(session.sessionId) { return false }
            if q.isEmpty { return true }
            return (session.title ?? "").lowercased().contains(q)
        }
    }

    private var grouped: [(title: String, sessions: [SessionSummary])] {
        if model.workspaces.isEmpty {
            return [(L.sectionSessions(), visibleSessions)]
        }
        var used = Set<String>()
        var groups: [(String, [SessionSummary])] = []
        for workspace in model.workspaces {
            let rows = visibleSessions.filter { workspace.sessionIds.contains($0.sessionId) }
            rows.forEach { used.insert($0.sessionId) }
            groups.append((workspace.title.isEmpty ? workspace.path : workspace.title, rows))
        }
        let rest = visibleSessions.filter { !used.contains($0.sessionId) }
        if !rest.isEmpty { groups.append((L.ungrouped(), rest)) }
        return groups
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
