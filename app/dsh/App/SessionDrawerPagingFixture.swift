import Foundation
import DSHProtocol

extension AppModel {
    func installSessionDrawerPagingFixture(workspace: Bool) {
        guard uiTestFixture else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        func rows(_ group: String, count: Int, offset: Int) -> [SessionSummary] {
            (1...count).map { index in
                SessionSummary(
                    sessionId: "paging-\(group)-\(index)",
                    title: "\(group.uppercased()) 会话 \(index)",
                    running: false,
                    blank: false,
                    updatedAt: now - Int64(offset + index) * 60_000
                )
            }
        }
        let first = rows("a", count: 30, offset: 0)
        let second = rows("b", count: 30, offset: 100)
        let collapsed = rows("c", count: 12, offset: 200)
        let archived = rows("archived", count: 12, offset: 300)
        let pinned = SessionSummary(
            sessionId: "paging-pinned", title: "置顶会话", running: false,
            blank: false, updatedAt: now
        )
        let running = SessionSummary(
            sessionId: "paging-running", title: "运行中的会话", running: true,
            blank: false, updatedAt: now - 500 * 60_000
        )
        sessions = [pinned] + first + second + collapsed + archived + [running]
        workspaces = [
            WorkspaceView(
                workspaceId: "paging-a", path: "/paging/a", title: "分页工作区 A",
                sessionIds: first.map(\.sessionId) + archived.map(\.sessionId) + [running.sessionId]
            ),
            WorkspaceView(
                workspaceId: "paging-b", path: "/paging/b", title: "分页工作区 B",
                sessionIds: second.map(\.sessionId)
            ),
            WorkspaceView(
                workspaceId: "paging-c", path: "/paging/c", title: "保持折叠的工作区",
                sessionIds: collapsed.map(\.sessionId)
            ),
        ]
        sessionGroupBy = workspace ? .workspace : .flat
        sessionOrderBy = .updated
        archivedFilter = .hide
        archivedIds = Set(archived.map(\.sessionId))
        pinnedIds = [pinned.sessionId]
        collapsedWorkspaces = ["workspace:paging-c"]
        chat = nil
        firstPrompt = nil
        clearSessionSearch()
        showDrawer = true
    }
}
