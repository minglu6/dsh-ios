#if DEBUG
import Foundation
import CoreFoundation
import DSHProtocol

extension AppModel {
    func installUITestJobsLifecycle(hostPanel: Bool = false) {
        guard uiTestFixture else { return }
        showDrawer = false
        routeStack = []
        // No jobs.list transport exists in the fixture. The real kill API's
        // no-client failure remains exercised; no fake successful RPC is used.
        ops.insert("jobs.kill")
        jobsFailed = false
        jobsPanelError = nil
        jobs = parseJobRoster(JobsLifecycleFrames.roster)
        if hostPanel { push(.panel(.jobs)) }
        JobsLifecycleFixture.driver = UITestJobsLifecycleDriver { [weak self] action in
            Task { @MainActor in
                guard let self, self.uiTestFixture else { return }
                switch action {
                case "output":
                    guard let jobId = self.jobDetail?.jobId else { return }
                    self.receiveUITestJobFrame(jobId: jobId, frame: JobsLifecycleFrames.output)
                case "settle", "stopping":
                    self.receiveUITestJobFrame(jobId: "jobs-live", frame: JobsLifecycleFrames.status(stopping: action == "stopping"))
                case "new":
                    let added = parseJobRoster(JobsLifecycleFrames.newRoster)
                    self.jobs = (self.jobs ?? []).filter { $0.id != "jobs-new" } + added
                case "session":
                    self.clearJobSelection()
                    self.chat = ChatState(sessionId: "jobs-other-session", loaded: true, agentPreset: "standard")
                    self.jobs = parseJobRoster(JobsLifecycleFrames.roster)
                case "host":
                    self.clearJobSelection()
                    self.activeId = "jobs-other-host"
                    self.status["jobs-other-host"] = .online
                    self.jobs = parseJobRoster(JobsLifecycleFrames.roster)
                default:
                    preconditionFailure("Unknown jobs lifecycle fixture action: \(action)")
                }
            }
        }
    }
}

@MainActor
private enum JobsLifecycleFixture {
    static var driver: UITestJobsLifecycleDriver?
}

private final class UITestJobsLifecycleDriver: @unchecked Sendable {
    private static let prefix = "dev.dsh.uitest.jobsLifecycle."
    private let receive: @Sendable (String) -> Void

    init(receive: @escaping @Sendable (String) -> Void) {
        self.receive = receive
        for action in ["output", "settle", "stopping", "new", "session", "host"] {
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                { _, observer, name, _, _ in
                    guard let observer, let name else { return }
                    let driver = Unmanaged<UITestJobsLifecycleDriver>.fromOpaque(observer).takeUnretainedValue()
                    driver.receive(String((name.rawValue as String).dropFirst(UITestJobsLifecycleDriver.prefix.count)))
                },
                (Self.prefix + action) as CFString,
                nil,
                .deliverImmediately
            )
        }
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
    }
}

private enum JobsLifecycleFrames {
    static let roster = try! JSONValue.parse("""
    {"jobs":[
      {"id":"jobs-live","kind":"bash","label":"sleep 600","status":"running","startedAt":1700000000000,"output":{"total":0,"earliest":0}},
      {"id":"jobs-output","kind":"bash","label":"printf retained","status":"completed","detail":"exit code: 0","startedAt":1700000000000,"finishedAt":1700000183037,"output":{"total":32,"earliest":0}},
      {"id":"jobs-static","kind":"bash","label":"echo static","status":"completed","detail":"exit code: 0","startedAt":1700000000000,"finishedAt":1700000001000,"output":{"total":0,"earliest":0}}
    ]}
    """)

    static let newRoster = try! JSONValue.parse("""
    {"jobs":[{"id":"jobs-new","kind":"bash","label":"echo newly finished","status":"completed","detail":"exit code: 0","startedAt":1700000200000,"finishedAt":1700000201000,"output":{"total":0,"earliest":0}}]}
    """)

    static let output = try! JSONValue.parse("""
    {"type":"output","lossy":false,"chunks":[{"text":"job-frame-first\\njob-frame-second","gapBefore":false}]}
    """)

    static func status(stopping: Bool) -> JSONValue {
        .object([
            "type": .string("status"),
            "job": .object([
                "id": .string("jobs-live"), "kind": .string("bash"),
                "label": .string("sleep 600"), "status": .string(stopping ? "stopping" : "completed"),
                "detail": stopping ? .null : .string("exit code: 0"),
                "startedAt": .number(1_700_000_000_000),
                "finishedAt": stopping ? .null : .number(1_700_000_183_037),
                "output": .object(["total": .number(0), "earliest": .number(0)]),
            ]),
        ])
    }
}
#endif
