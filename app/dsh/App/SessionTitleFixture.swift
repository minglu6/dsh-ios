import Combine
import Foundation
import CoreFoundation
import DSHProtocol

extension UITestLaunch {
    static var sessionTitleReduceMotion: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains("-UITestTitleReduceMotion")
    }
}

private enum SessionTitleFixture {
    static let chinese = "会话标题完整阅读：核对多端交互、代码修改、历史记录复用与无障碍表现，确保最后一段内容仍然可以清楚阅读【中文末尾】"
    static let english = "Review conversation title overflow, history row reuse, accessibility and desktop parity without losing the final words [English tail]"
    static var titleChanges: AnyCancellable?
    #if DEBUG
    static var metadataDriver: SessionTitleSelectionDriver?
    #endif
}

extension AppModel {
    func installUITestSessionTitlesIfRequested() {
        SessionTitleFixture.titleChanges = nil
#if DEBUG
        SessionTitleFixture.metadataDriver = nil
#endif
        guard uiTestFixture, UITestLaunch.screen == "sessionTitles" || UITestLaunch.screen == "sessionTitlesChanging" else { return }
        guard let id = chat?.sessionId else { return }
        chat?.title = SessionTitleFixture.chinese
        chat?.loaded = true
        chat?.agentPreset = nil
        sessions = [
            SessionSummary(sessionId: id, title: SessionTitleFixture.chinese, updatedAt: 1_792_584_000_000),
            SessionSummary(sessionId: "title-short", title: "短标题", updatedAt: 1_792_583_000_000),
            SessionSummary(sessionId: "title-english", title: SessionTitleFixture.english, updatedAt: 1_792_582_000_000),
            SessionSummary(sessionId: "title-short-english", title: "Hello", updatedAt: 1_792_581_000_000),
            SessionSummary(sessionId: "title-mixed", title: "地面洞察报告生成逻辑梳理与 Agent Skill 准备"),
        ]
        sessionGroupBy = .flat
        sessionOrderBy = .updated
        workspaces = []
#if DEBUG
        SessionTitleFixture.metadataDriver = SessionTitleSelectionDriver(
            notification: "dev.dsh.uitest.sessionTitle.toggleRunning"
        ) { [weak self] in
            Task { @MainActor in
                guard let self, self.uiTestFixture, var state = self.chat else { return }
                state.running.toggle()
                self.chat = state
                if let index = self.sessions.firstIndex(where: { $0.sessionId == state.sessionId }) {
                    self.sessions[index].updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
                }
            }
        }
#endif
        if UITestLaunch.screen == "sessionTitlesChanging" {
            // Drive real title replacement via the existing composer, without
            // adding test-only buttons to either the header or the history row.
            SessionTitleFixture.titleChanges = $composerText.removeDuplicates().sink { [weak self] text in
                let title: String
                switch text.trimmingCharacters(in: .whitespacesAndNewlines) {
                case "short": title = "短标题"
                case "english", "short english": title = SessionTitleFixture.english
                default: return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.chat?.sessionId == id else { return }
                    self.chat?.title = title
                    if let index = self.sessions.firstIndex(where: { $0.sessionId == id }) {
                        self.sessions[index].title = title
                    }
                }
            }
        }
    }
}

#if DEBUG
private final class SessionTitleSelectionDriver: @unchecked Sendable {
    private let toggle: @Sendable () -> Void

    init(notification: String = "dev.dsh.uitest.sessionTitle.toggleSelection", toggle: @escaping @Sendable () -> Void) {
        self.toggle = toggle
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<SessionTitleSelectionDriver>.fromOpaque(observer).takeUnretainedValue().toggle()
            },
            notification as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
#endif
