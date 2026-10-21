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
    @State private var visibleIdleLimits: [String: Int] = [:]
    @State private var restoreId: String?
    @State private var renameSession: SessionSummary?
    @State private var renameTitle = ""
    @State private var renameBusy = false
    @State private var draggingSession: String?
    @State private var lastOps: Set<String> = []
    @FocusState private var searchFocused: Bool

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
                    OfficialGlyph(
                        kind: .newChat,
                        size: CGFloat(sidebarNewChatIconSizePoints),
                        color: T.ink
                    )
                }
                .accessibilityLabel(L.newSession())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack {
                OfficialGlyph(
                    kind: .searchOutline,
                    size: CGFloat(sidebarSearchIconSizePoints),
                    color: T.text3
                )
                .accessibilityLabel(L.searchSessionsAria())
                TextField(L.searchSessions(), text: $query)
                    .textInputAutocapitalization(.never)
                    .focused($searchFocused)
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
                    .font(Font.system(size: 13))
                    .foregroundStyle(T.text3)
                Spacer()
                Button { viewOptions.toggle() } label: {
                    OfficialGlyph(kind: .slidersTwo, size: 16, color: T.text2)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel(L.viewOptions())
                .accessibilityIdentifier("viewOptionsButton")
                .popover(isPresented: $viewOptions, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    ViewOptionsMenu(model: model)
                        .frame(minWidth: CGFloat(viewOptionsMenuMinWidthPoints))
                        .modifier(PopoverCompactAdaptation())
                }
                if visibleOps.contains("workspace.create") {
                    Button { addWorkspace = true } label: {
                        OfficialGlyph(
                            kind: .projectAdd,
                            size: CGFloat(sidebarProjectAddIconSizePoints),
                            color: T.text2
                        )
                        .frame(
                            width: CGFloat(sidebarProjectAddButtonPoints),
                            height: CGFloat(sidebarProjectAddButtonPoints)
                        )
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
                                .font(Font.caption)
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
                                .font(Font.system(size: 12))
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
            .accessibilityIdentifier("sessionList")
            .background {
                GeometryReader { viewport in
                    Color.clear.preference(
                        key: DrawerPagingGeometryKey.self,
                        value: DrawerPagingGeometry(viewport: viewport.frame(in: .global))
                    )
                }
            }
            .onPreferenceChange(DrawerPagingGeometryKey.self, perform: revealVisiblePages)
            .dshDismissesKeyboardOnScrollAndTap()
            // A new projection has different row geometry and cannot inherit
            // the previous lazy stack's scroll offset. Pagination within the
            // same projection keeps its identity; workspace collapse lives in
            // the model and is deliberately not reset here.
            .id(DrawerListContext(
                groupBy: model.sessionGroupBy,
                archived: model.archivedFilter,
                searching: searching
            ))
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
            searchFocused = false
            rememberOps()
            model.refreshSessionsWhenVisible()
        }
        .onChange(of: model.isOnline) { _ in rememberOps() }
        .onChange(of: model.ops) { _ in rememberOps() }
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
                .font(Font.system(size: 14, weight: .medium))
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
        let limit = cap ? groupKey.map { visibleIdleLimits[$0] ?? 5 } ?? Int.max : Int.max
        let slice = projectSessions(rows, limit: limit)
        ForEach(slice.rows) { session in
            sessionRow(session, groupKey: groupKey)
                .background {
                    if let groupKey, slice.hasMore, session.sessionId == slice.lastIdleId {
                        GeometryReader { row in
                            Color.clear.preference(
                                key: DrawerPagingGeometryKey.self,
                                value: DrawerPagingGeometry(boundaries: [
                                    groupKey: DrawerPagingBoundary(
                                        limit: limit,
                                        frame: row.frame(in: .global)
                                    ),
                                ])
                            )
                        }
                    }
                }
        }
    }

    private func projectSessions(
        _ rows: [SessionSummary], limit: Int
    ) -> (rows: [SessionSummary], hasMore: Bool, lastIdleId: String?) {
        var idle = 0
        var lastIdleId: String?
        let projected = rows.filter { session in
            if session.blank || session.running { return true }
            idle += 1
            guard idle <= limit else { return false }
            lastIdleId = session.sessionId
            return true
        }
        return (projected, idle > limit, lastIdleId)
    }

    private func revealVisiblePages(_ geometry: DrawerPagingGeometry) {
        guard !searching, let viewport = geometry.viewport, viewport.height > 0 else { return }
        for (key, boundary) in geometry.boundaries {
            // Workspace children are not lazy. Appearance alone would eagerly
            // exhaust every group; require the actual last idle row in view.
            // The limit also rejects stale geometry during the next layout.
            guard (visibleIdleLimits[key] ?? 5) == boundary.limit,
                  boundary.frame.maxY > viewport.minY,
                  boundary.frame.minY < viewport.maxY,
                  boundary.frame.maxX > viewport.minX,
                  boundary.frame.minX < viewport.maxX else { continue }
            // Insert after this idle boundary, keeping existing row identities
            // and everything above the boundary at its current scroll offset.
            visibleIdleLimits[key] = boundary.limit + 5
        }
    }

    private func sessionRow(_ session: SessionSummary, groupKey: String?) -> some View {
        let selected = model.chat?.sessionId == session.sessionId
        let archived = model.isArchived(session.sessionId)
        let trailing = searching ? nil : sessionRowTrailingLabel(
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
        )
        return HStack(spacing: 0) {
            Button {
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
                        HStack(spacing: 8) {
                            Text(drawerSessionTitle(
                                session,
                                current: model.chat?.sessionId,
                                newSession: L.newSession(),
                                untitled: L.untitledSession()
                            ))
                                .foregroundStyle(archived ? T.text3 : T.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if SessionRowChromePolicy.timeSharesTitleLine, let trailing {
                                Text(trailing)
                                    .font(Font.system(size: 12))
                                    .foregroundStyle(T.text3)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                    .accessibilityIdentifier("sessionRowTime")
                            }
                        }
                        if searching, searchResultShowsWorkspaceContext {
                            Text(workspaceContext(for: session.sessionId))
                                .font(Font.caption)
                                .foregroundStyle(T.text3)
                                .lineLimit(1)
                        }
                        if let snippet = session.searchSnippet, searching {
                            Text(snippet).font(Font.caption).foregroundStyle(T.text2).lineLimit(2)
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sessionRow.\(session.sessionId)")
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
            if SessionRowChromePolicy.trailingActionsAlwaysVisibleOnTouch {
                sessionRowActions(session, archived: archived)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.trailing, 8)
            }
        }
        .background(selected ? T.sidebarActiveAccent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
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
        .accessibilityElement(children: .contain)
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
                    OfficialGlyph(kind: .clockOutline, size: 16, color: T.ink)
                }
            }
        }
    }

    private func panel<Icon: View>(_ title: String, _ panel: DrawerPanel, @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            Keyboard.dismiss()
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

    @ViewBuilder
    private func sessionRowActions(_ session: SessionSummary, archived: Bool) -> some View {
        let force = model.uiTestFixture
        HStack(spacing: 0) {
            if !archived, force || visibleOps.contains("workspace.pinSession") {
                Button {
                    model.pin(session)
                } label: {
                    OfficialGlyph(
                        kind: model.pinnedIds.contains(session.sessionId) ? .pinFill : .pinOutline,
                        size: 14,
                        color: T.text2
                    )
                    .frame(width: 28, height: 28)
                }
                .disabled(!model.isOnline)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(model.pinnedIds.contains(session.sessionId) ? L.unpinSession() : L.pinSession())
                .accessibilityIdentifier("sessionRowPin")
            }
            if force || visibleOps.contains("workspace.archiveSession") {
                Button {
                    if archived { model.unarchive(session.sessionId) }
                    else { model.archive(session) }
                } label: {
                    OfficialGlyph(kind: .archiveOutline, size: 14, color: T.text2)
                        .frame(width: 28, height: 28)
                }
                .disabled(!model.isOnline)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(archived ? L.unarchiveSession() : L.archiveSession())
                .accessibilityIdentifier("sessionRowArchive")
            }
            Menu {
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
            } label: {
                OfficialGlyph(kind: .ellipsis, size: 14, color: T.text2)
                    .frame(width: 28, height: 28)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(L.moreActions())
            .accessibilityIdentifier("sessionRowMore")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sessionRowActions")
    }

    private var footer: some View {
        HStack(spacing: 0) {
            footerSettings
                .layoutPriority(1)
            Spacer(minLength: CGFloat(sidebarFooterHitGapMinPoints))
                .allowsHitTesting(false)
            footerPeerDevice
                .layoutPriority(0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(T.surface)
    }

    private var footerPeerDevice: some View {
        Button {
            Keyboard.dismiss()
            model.push(.connections)
            model.showDrawer = false
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(footerHostName)
                    .font(Font.system(size: CGFloat(sidebarFooterHostNameFontSizePoints)))
                    .foregroundStyle(T.text2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0)
                    .accessibilityIdentifier("drawerPeerDeviceName")
            }
            .padding(.horizontal, 8)
            .frame(minHeight: CGFloat(sidebarFooterHitMinHeightPoints))
            .frame(minWidth: 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(DrawerFooterHitStyle())
        .accessibilityLabel(footerDeviceAria)
        .accessibilityIdentifier("drawerPeerDeviceRow")
    }

    private var footerSettings: some View {
        Button {
            Keyboard.dismiss()
            model.push(.settings)
            model.showDrawer = false
        } label: {
            HStack(spacing: CGFloat(sidebarSettingsTriggerGapPoints)) {
                OfficialGlyph(
                    kind: .settingsOutline,
                    size: CGFloat(sidebarSettingsTriggerIconSizePoints),
                    color: T.ink
                )
                Text(L.settings())
                    .font(Font.system(size: CGFloat(sidebarSettingsTriggerFontSizePoints)))
                    .lineLimit(1)
            }
            .foregroundStyle(T.ink)
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .frame(minHeight: CGFloat(sidebarFooterHitMinHeightPoints))
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(DrawerFooterHitStyle())
        .accessibilityIdentifier("drawerSettingsRow")
    }

    private var footerHostName: String {
        model.activeProfile?.name ?? L.notConnected()
    }

    private var footerDeviceAria: String {
        let name = model.activeProfile?.name ?? L.notConnected()
        return "\(name) · \(footerSubtitle)"
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

private struct DrawerListContext: Hashable {
    let groupBy: SessionGroupBy
    let archived: ArchivedFilter
    let searching: Bool
}

private struct DrawerPagingBoundary: Equatable {
    let limit: Int
    let frame: CGRect
}

private struct DrawerPagingGeometry: Equatable {
    var viewport: CGRect?
    var boundaries: [String: DrawerPagingBoundary] = [:]
}

private struct DrawerPagingGeometryKey: PreferenceKey {
    static var defaultValue: DrawerPagingGeometry { DrawerPagingGeometry() }

    static func reduce(value: inout DrawerPagingGeometry, nextValue: () -> DrawerPagingGeometry) {
        let next = nextValue()
        if let viewport = next.viewport { value.viewport = viewport }
        value.boundaries.merge(next.boundaries, uniquingKeysWith: { _, latest in latest })
    }
}

/// Independent pressed highlight for the two footer hits. Uses desktop
/// `--dsw-alias-interactive-bg-hover` so Settings and Host never share
/// a full-row active state.
private struct DrawerFooterHitStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? T.hoverBg : Color.clear)
            )
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

/// Desktop `ui-workspace` `ViewOptionsMenu`: grouped popover, not a system ActionSheet.
struct ViewOptionsMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section(.groupBy)
            Divider()
            section(.orderBy)
            Divider()
            section(.filter)
        }
        .padding(.vertical, 6)
        .background(T.surface)
        .accessibilityIdentifier("viewOptionsMenu")
    }

    private func section(_ section: ViewOptionsSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ViewOptionsMenuPolicy.title(section, english: L.en))
                .font(Font.system(size: 12))
                .foregroundStyle(T.text3)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ForEach(ViewOptionsMenuPolicy.rows(in: section), id: \.self) { row in
                Button {
                    apply(row)
                } label: {
                    HStack(spacing: 8) {
                        leadingIcon(row)
                            .frame(width: 16, height: 16)
                        Text(ViewOptionsMenuPolicy.label(row, english: L.en))
                            .font(Font.system(size: 14))
                            .foregroundStyle(T.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if selected(row) {
                            Text("✓")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(T.ink)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: CGFloat(viewOptionsMenuRowMinHeightPoints))
                    .background(selected(row) ? T.fill : Color.clear)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected(row) ? [.isSelected] : [])
            }
        }
    }

    @ViewBuilder
    private func leadingIcon(_ row: ViewOptionsRow) -> some View {
        OfficialGlyph(kind: officialGlyph(for: row), size: 14, color: T.ink)
    }

    private func officialGlyph(for row: ViewOptionsRow) -> OfficialGlyph.Kind {
        switch row {
        case .groupWorkspace: return .folderClose
        case .groupWorkspaceTree: return .workspaceTree
        case .groupFlat: return .flatList
        case .orderManual: return .chevronsUpDown
        case .orderUpdated: return .clockOutline
        case .filterHide: return .archiveOff
        case .filterShow: return .queue
        case .filterOnly: return .archiveCheck
        }
    }

    private func selected(_ row: ViewOptionsRow) -> Bool {
        switch row {
        case .groupWorkspace: return model.sessionGroupBy == .workspace
        case .groupWorkspaceTree: return model.sessionGroupBy == .workspaceTree
        case .groupFlat: return model.sessionGroupBy == .flat
        case .orderManual: return model.sessionOrderBy == .manual
        case .orderUpdated: return model.sessionOrderBy == .updated
        case .filterHide: return model.archivedFilter == .hide
        case .filterShow: return model.archivedFilter == .show
        case .filterOnly: return model.archivedFilter == .only
        }
    }

    private func apply(_ row: ViewOptionsRow) {
        switch row {
        case .groupWorkspace: model.setSessionGroupBy(.workspace)
        case .groupWorkspaceTree: model.setSessionGroupBy(.workspaceTree)
        case .groupFlat: model.setSessionGroupBy(.flat)
        case .orderManual: model.setSessionOrderBy(.manual)
        case .orderUpdated: model.setSessionOrderBy(.updated)
        case .filterHide: model.setArchivedFilter(.hide)
        case .filterShow: model.setArchivedFilter(.show)
        case .filterOnly: model.setArchivedFilter(.only)
        }
    }
}
