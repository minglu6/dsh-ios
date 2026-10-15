import BackgroundTasks
import Foundation
import Network
import SwiftUI
import UIKit
import UserNotifications
import DSHProtocol

/// iOS stand-in for Android `ConnectionService`.
/// Holds the WS through `beginBackgroundTask` with pings, then a `BGAppRefreshTask`
/// for a later lightweight reconnect/status refresh. Not a ForegroundService.
@MainActor
final class ConnectionKeeper {
    static let shared = ConnectionKeeper()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.dsh.pocket.ios.path")
    private var background: UIBackgroundTaskIdentifier = .invalid
    private var lastSatisfied = true
    private var started = false
    private var registered = false
    private var keepAliveTask: Task<Void, Never>?

    func registerBackgroundTasks() {
        guard !registered else { return }
        registered = true
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundKeepAlivePolicy.taskIdentifier,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handlePocketRefreshTask(refresh)
        }
    }

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let restored = satisfied && !self.lastSatisfied
                self.lastSatisfied = satisfied
                if restored {
                    AppModel.shared.onNetworkRestored()
                }
            }
        }
        monitor.start(queue: queue)
        requestNotifications()
    }

    func sceneChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            endBackground()
            AppModel.shared.onBecameActive()
        case .inactive:
            break
        case .background:
            AppModel.shared.onEnteredBackground()
            beginBackground()
            scheduleAppRefresh()
        @unknown default:
            break
        }
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    break
                case .denied:
                    AppPrefs.notificationsDeclined = true
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        Task { @MainActor in AppPrefs.notificationsDeclined = !granted }
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    func notifyTask(_ event: TaskEvent, sessionTitle: String?) {
        guard shouldNotify(sessionId: event.sessionId) else { return }
        post(
            id: TaskNotifyTexts.tag(event),
            title: TaskNotifyTexts.title(event.kind, english: L.en),
            body: TaskNotifyTexts.body(event.kind, sessionTitle: sessionTitle, english: L.en),
            sessionId: event.sessionId
        )
    }

    func notifyApproval(_ approval: Approval) {
        guard shouldNotify(sessionId: approval.sessionId) else { return }
        post(
            id: "dsh-approval-\(approval.approvalId)",
            title: L.approvalNotify(approval.toolName.isEmpty ? approval.approvalId : approval.toolName),
            body: approval.sessionId.flatMap { id in AppModel.shared.sessions.first { $0.sessionId == id }?.title } ?? L.approval(),
            sessionId: approval.sessionId
        )
    }

    func notifyCompletion(sessionId: String) {
        guard shouldNotify(sessionId: sessionId) else { return }
        let title = AppModel.shared.sessions.first { $0.sessionId == sessionId }?.title
        notifyTask(TaskEvent(kind: .done, sessionId: sessionId), sessionTitle: title)
    }

    func scheduleAppRefresh() {
        guard AppModel.shared.activeId != nil else { return }
        let request = BGAppRefreshTaskRequest(identifier: BackgroundKeepAlivePolicy.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: BackgroundKeepAlivePolicy.refreshEarliestBeginSeconds)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func shouldNotify(sessionId: String?) -> Bool {
        if AppPrefs.notificationsDeclined { return false }
        if UIApplication.shared.applicationState == .active,
           AppModel.shared.chat?.sessionId == sessionId,
           !AppModel.shared.showDrawer {
            return false
        }
        return true
    }

    private func post(id: String, title: String, body: String, sessionId: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let sessionId { content.userInfo = ["sessionId": sessionId] }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func beginBackground() {
        endBackground()
        background = UIApplication.shared.beginBackgroundTask(withName: "dsh-pocket-ws") { [weak self] in
            Task { @MainActor in self?.endBackground() }
        }
        keepAliveTask = Task { await self.runKeepAlivePing() }
    }

    private func runKeepAlivePing() async {
        let ns = UInt64(BackgroundKeepAlivePolicy.pingIntervalMs) * 1_000_000
        while !Task.isCancelled {
            switch await AppModel.shared.pingLiveSocket() {
            case .ok, .skipped:
                try? await Task.sleep(nanoseconds: ns)
            case .failed:
                if Task.isCancelled { return }
                AppModel.shared.noteKeepAliveFailed()
                return
            }
        }
    }

    private func endBackground() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        if background != .invalid {
            UIApplication.shared.endBackgroundTask(background)
            background = .invalid
        }
    }
}

private func handlePocketRefreshTask(_ task: BGAppRefreshTask) {
    let gate = CompletionGate()
    let work = Task { @MainActor in
        ConnectionKeeper.shared.scheduleAppRefresh()
        let ok = await AppModel.shared.performBackgroundRefresh()
        if gate.take() {
            task.setTaskCompleted(success: ok)
        }
    }
    task.expirationHandler = {
        work.cancel()
        if gate.take() {
            task.setTaskCompleted(success: false)
        }
    }
}

/// `BGAppRefreshTask.setTaskCompleted` must run once; expiration and the work task race.
private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if finished { return false }
        finished = true
        return true
    }
}
