import XCTest
@testable import DSHProtocol

final class NavigationPolicyTests: XCTestCase {
    private func session(
        _ id: String,
        parent: String? = nil,
        origin: String? = nil,
        blank: Bool = false,
        time: Int64 = 1
    ) -> SessionSummary {
        SessionSummary(
            sessionId: id,
            title: id,
            cwd: "/work/project",
            running: false,
            blank: blank,
            updatedAt: time,
            parentSessionId: parent,
            origin: origin
        )
    }

    func testWorkspaceLabelsLocalizeOnlyAutomaticNamesAndPreserveCustomTitles() {
        let path = #"C:\Users\luming2\Documents\deepseek-harness\default-workspace"#
        XCTAssertEqual(workspaceDisplayTitle(title: "default-workspace", path: path, localizedDefault: "默认工作区"), "默认工作区")
        XCTAssertEqual(workspaceDisplayTitle(title: "default-workspace", path: path, localizedDefault: "Default workspace"), "Default workspace")
        XCTAssertEqual(workspaceDisplayTitle(title: "我的工程", path: path, localizedDefault: "默认工作区"), "我的工程")
        XCTAssertEqual(workspaceDisplayTitle(title: "Default-workspace", path: path, localizedDefault: "默认工作区"), "Default-workspace")
    }

    func testUntitledWorkspaceLabelsHandleHostSeparatorsWithoutChangingPaths() {
        XCTAssertEqual(workspaceDisplayTitle(title: nil, path: #"C:\work\project\"#, localizedDefault: "默认工作区"), "project")
        XCTAssertEqual(workspaceDisplayTitle(title: "", path: "/work/project/", localizedDefault: "默认工作区"), "project")
        XCTAssertEqual(workspaceDisplayTitle(title: " ", path: #"\\server\share\project"#, localizedDefault: "默认工作区"), "project")
        XCTAssertEqual(workspaceDisplayTitle(title: nil, path: #"C:\work/mixed\project"#, localizedDefault: "默认工作区"), "project")
        XCTAssertEqual(workspaceDisplayTitle(title: nil, path: "/", localizedDefault: "默认工作区"), "/")
        XCTAssertEqual(workspaceDisplayTitle(title: nil, path: #"C:\"#, localizedDefault: "默认工作区"), "C:")
        XCTAssertEqual(workspaceDisplayTitle(title: nil, path: #"C:\work\default-workspace"#, localizedDefault: "默认工作区"), "默认工作区")
    }

    func testForksRemainVisibleButSubagentsAndInactiveBlanksDoNot() {
        XCTAssertTrue(visibleDrawerSession(session("fork", parent: "parent"), current: nil, archived: [], filter: .hide))
        XCTAssertFalse(visibleDrawerSession(session("child", parent: "parent", origin: "subagent"), current: "child", archived: [], filter: .show))
        XCTAssertTrue(visibleDrawerSession(session("blank", blank: true), current: "blank", archived: [], filter: .hide))
        XCTAssertFalse(visibleDrawerSession(session("blank", blank: true), current: "other", archived: [], filter: .hide))
    }

    func testArchiveFiltersRemainConsistentForAllViews() {
        let s = session("archived")
        XCTAssertFalse(visibleDrawerSession(s, current: nil, archived: [s.sessionId], filter: .hide))
        XCTAssertTrue(visibleDrawerSession(s, current: nil, archived: [s.sessionId], filter: .show))
        XCTAssertTrue(visibleDrawerSession(s, current: nil, archived: [s.sessionId], filter: .only))
        XCTAssertFalse(visibleDrawerSession(s, current: nil, archived: [], filter: .only))
    }

    func testTreeUsesFullPathsAndNearestRegisteredAncestor() {
        let tree = workspaceBranches(["/a/project", "/b/project", "/a/project/nested", "/a/project-other", "/a/project/nested/deep"])
        XCTAssertEqual(tree.map(\.path), ["/a/project", "/b/project", "/a/project-other"])
        XCTAssertEqual(tree.first?.children.map(\.path), ["/a/project/nested"])
        XCTAssertEqual(tree.first?.children.first?.children.map(\.path), ["/a/project/nested/deep"])
        XCTAssertTrue(tree[1].children.isEmpty)
        XCTAssertEqual(workspacePathKey(nil), "")
        XCTAssertEqual(workspacePathKey(""), "")
        XCTAssertEqual(workspacePathKey("/"), "/")
    }

    func testNewForksPrecedeSourceAndHiddenArchivesRetainSlots() {
        let all = [session("source"), session("archived"), session("fork", parent: "source", time: 3), session("other")]
        let order = reconcileSessionOrder(sessions: all, saved: ["archived", "source", "other"])
        XCTAssertEqual(order, ["archived", "fork", "source", "other"])
        XCTAssertEqual(order, reconcileSessionOrder(sessions: all, saved: order))
    }

    func testCyclicLineageDoesNotRecurseForever() {
        let order = reconcileSessionOrder(sessions: [session("a", parent: "b"), session("b", parent: "a")], saved: [])
        XCTAssertEqual(Set(order), ["a", "b"])
        XCTAssertEqual(order.count, 2)
    }

    func testArchiveActivityDescribesHostKinds() throws {
        let details = try JSONValue.parse("""
        {"activity":[
            {"kind":"turn","items":[{"label":"修 bug"}]},
            {"kind":"job","items":[{"id":"j1"}]}
        ]}
        """)
        XCTAssertEqual(
            archiveActivityDescription(details, english: false),
            "进行中的回合: 修 bug\n后台任务: j1"
        )
        XCTAssertEqual(
            archiveActivityDescription(details, english: true),
            "Turn in progress: 修 bug\nBackground jobs: j1"
        )
    }
}

final class ReconnectBackoffTests: XCTestCase {
    func testResetsToInitialAndDoublesUntilCap() {
        XCTAssertEqual(ReconnectBackoffPolicy.reset(), 1_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(1_000), 2_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(2_000), 4_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(8_000), 16_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(16_000), 30_000)
        XCTAssertEqual(ReconnectBackoffPolicy.next(30_000), 30_000)
    }
}

final class ConnectionRestoreTests: XCTestCase {
    func testReconnectsOnlyWhenOfflineOrConnecting() {
        XCTAssertTrue(ConnectionRestorePolicy.shouldReconnect(.offline))
        XCTAssertTrue(ConnectionRestorePolicy.shouldReconnect(.connecting))
        XCTAssertFalse(ConnectionRestorePolicy.shouldReconnect(.online))
        XCTAssertFalse(ConnectionRestorePolicy.shouldReconnect(.unauthorized))
        XCTAssertFalse(ConnectionRestorePolicy.shouldReconnect(nil))
    }
}

final class SessionSearchTests: XCTestCase {
    func testPreservesForkIdentityAndSearchSnippetSeparately() throws {
        let fork = try XCTUnwrap(SessionSummary.parse(try JSONValue.parse(
            #"{"sessionId":"fork","parentSessionId":"root","snippet":"matched text"}"#
        )))
        XCTAssertNil(fork.origin)
        XCTAssertEqual(fork.parentSessionId, "root")
        XCTAssertNil(fork.title)
        XCTAssertEqual(fork.searchSnippet, "matched text")
        let subagent = try XCTUnwrap(SessionSummary.parse(try JSONValue.parse(
            #"{"sessionId":"child","origin":"subagent"}"#
        )))
        XCTAssertEqual(subagent.origin, "subagent")
    }

    func testWorkspaceRetainsHostIdentityAndManualSessionOrder() throws {
        let workspace = try XCTUnwrap(WorkspaceView.parse(try JSONValue.parse(
            #"{"workspaceId":"w1","path":"/project","title":"Project","sessionIds":["b","a"],"createdAt":"2026-10-13T00:00:00Z"}"#
        )))
        XCTAssertEqual(workspace.workspaceId, "w1")
        XCTAssertEqual(workspace.sessionIds, ["b", "a"])
        XCTAssertNil(WorkspaceView.parse(try JSONValue.parse(#"{"path":"/project","title":"No identity"}"#)))
    }

    func testBlankQueryIsRejectedAndHostSearchIsOpsGated() {
        XCTAssertThrowsError(try SessionSearch.args(query: "   ")) { error in
            XCTAssertEqual((error as? PocketError)?.code, "bad-request")
            XCTAssertEqual((error as? PocketError)?.message, "query required")
        }
        XCTAssertEqual(try SessionSearch.args(query: " needle "), jsonObject(["query": .string("needle")]))
        XCTAssertFalse(SessionSearch.shouldSearchHost(query: "x", ops: []))
        XCTAssertFalse(SessionSearch.shouldSearchHost(query: "  ", ops: ["sessions.search"]))
        XCTAssertTrue(SessionSearch.shouldSearchHost(query: "x", ops: ["sessions.search"]))
        XCTAssertEqual(SessionSearch.debounceMs, 250)
    }

    func testMergePrefersHostHitsThenLocalWithoutDuplicates() {
        let host = SessionSummary(sessionId: "s1", title: "Host", searchSnippet: "hi")
        let local = [
            SessionSummary(sessionId: "s1", title: "Local"),
            SessionSummary(sessionId: "s2", title: "Other"),
        ]
        let merged = SessionSearch.merge(hits: [host], local: local)
        XCTAssertEqual(merged.map(\.sessionId), ["s1", "s2"])
        XCTAssertEqual(merged[0].searchSnippet, "hi")
    }

    func testLocalMatchesTitleCwdAndWorkspace() {
        let sessions = [
            SessionSummary(sessionId: "a", title: "修 bug", cwd: "/work"),
            SessionSummary(sessionId: "b", title: "notes", cwd: "/tmp"),
        ]
        let workspaces = [
            WorkspaceView(workspaceId: "w", path: "/repo", title: "工程", sessionIds: ["b"]),
        ]
        XCTAssertEqual(SessionSearch.localMatches(sessions: sessions, workspaces: workspaces, query: "bug").map(\.sessionId), ["a"])
        XCTAssertEqual(SessionSearch.localMatches(sessions: sessions, workspaces: workspaces, query: "工程").map(\.sessionId), ["b"])
    }
}

final class SessionFeedbackTests: XCTestCase {
    func testOmitsBlankTextAndOptionalCategory() throws {
        let blank = SessionFeedbackRequest.args(sessionId: "s1", category: nil, note: "   ")
        XCTAssertEqual(blank.obj()?.keys.sorted(), ["sessionId"])
        XCTAssertNil(blank["text"].str())
        let full = SessionFeedbackRequest.args(sessionId: "s1", category: "task-result", note: "太慢")
        XCTAssertEqual(full["category"].str(), "task-result")
        XCTAssertEqual(full["text"].str(), "太慢")
        try SessionFeedbackRequest.recorded(.object(["recorded": .bool(true)]))
        XCTAssertThrowsError(try SessionFeedbackRequest.recorded(.object(["recorded": .bool(false)])))
    }

    func testMoreSheetGatesFeedbackAndDisablesWithoutSession() {
        XCTAssertFalse(MoreSheetPolicy.showsFeedback(ops: ["session.export", "commands.execute"]))
        XCTAssertTrue(MoreSheetPolicy.showsFeedback(ops: ["session.export", "sessionFeedback.record"]))
        XCTAssertFalse(MoreSheetPolicy.exportEnabled(online: true, ops: ["session.export"], inChat: false))
        XCTAssertTrue(MoreSheetPolicy.exportEnabled(online: true, ops: ["session.export"], inChat: true))
        XCTAssertFalse(MoreSheetPolicy.feedbackEnabled(inChat: false))
        XCTAssertTrue(MoreSheetPolicy.feedbackEnabled(inChat: true))
    }
}

final class SessionAttachmentTests: XCTestCase {
    func testParsesUserImageRefs() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#))
        _ = reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":1,"time":1001,"data":{"role":"user","source":{"kind":"user"},"content":[
            {"type":"text","text":"see this"},
            {"type":"image","attachment":{"attachmentId":"att-1","mediaType":"image/png"}},
            {"type":"image","attachment":{"attachmentId":"att-2","mediaType":"image/jpeg"}}
        ]}}}
        """))
        let users = reducer.items().compactMap { item -> Item.User? in
            if case .user(let user) = item { return user }
            return nil
        }
        XCTAssertEqual(users.count, 1)
        let user = try XCTUnwrap(users.first)
        XCTAssertEqual(user.text, "see this")
        XCTAssertEqual(user.images, 2)
        XCTAssertEqual(user.imageRefs, [
            ImageRef(attachmentId: "att-1", mediaType: "image/png"),
            ImageRef(attachmentId: "att-2", mediaType: "image/jpeg"),
        ])
    }

    func testIgnoresNonImageAttachmentBlocks() throws {
        let reducer = TranscriptReducer()
        _ = reducer.apply(try JSONValue.parse(#"{"type":"snapshot","cursor":0,"records":[],"projections":{}}"#))
        _ = reducer.apply(try JSONValue.parse("""
        {"type":"event","event":{"type":"user/message","seq":1,"time":1001,"data":{"role":"user","source":{"kind":"user"},"content":[
            {"type":"text","text":"file"},
            {"type":"file","attachment":{"attachmentId":"doc-1","mediaType":"application/pdf"}}
        ]}}}
        """))
        let users = reducer.items().compactMap { item -> Item.User? in
            if case .user(let user) = item { return user }
            return nil
        }
        let user = try XCTUnwrap(users.first)
        XCTAssertEqual(user.images, 0)
        XCTAssertTrue(user.imageRefs.isEmpty)
    }

    func testDecodesBase64AndSamplesPreview() {
        let data = Data("A".utf8)
        let result = jsonObject(["data": .string(data.base64EncodedString())])
        XCTAssertEqual(SessionAttachment.decodeBytes(result), data)
        XCTAssertNil(SessionAttachment.decodeBytes(.object([:])))
        XCTAssertEqual(SessionAttachment.sampleSize(width: 200, height: 200), 1)
        // Android Chat.kt: while (max(w,h) / sample > 660) sample *= 2  — integer division.
        XCTAssertEqual(SessionAttachment.sampleSize(width: 1321, height: 10), 2)
        XCTAssertEqual(SessionAttachment.sampleSize(width: 1322, height: 10), 4)
        XCTAssertEqual(
            SessionAttachment.args(sessionId: "s", attachmentId: "a"),
            jsonObject(["sessionId": .string("s"), "attachmentId": .string("a")])
        )
    }
}

final class WorkspaceOrderTests: XCTestCase {
    func testInsertArgsOmitNullBeforeIds() {
        XCTAssertEqual(
            WorkspaceOrder.insertBeforeArgs(workspaceId: "w1", beforeWorkspaceId: nil).obj()?.keys.sorted(),
            ["workspaceId"]
        )
        XCTAssertEqual(
            WorkspaceOrder.insertSessionBeforeArgs(workspaceId: "w1", sessionId: "s1", beforeSessionId: "s2")["beforeSessionId"].str(),
            "s2"
        )
    }
}

final class TaskNotifyTests: XCTestCase {
    func testBuildsDoneAndQuestionCopyWithSessionTitle() {
        XCTAssertEqual(TaskNotifyTexts.title(.done), "任务已完成")
        XCTAssertEqual(TaskNotifyTexts.title(.question), "需要你确认")
        XCTAssertEqual(TaskNotifyTexts.body(.done, sessionTitle: nil), "你的 DSH 任务已完成")
        XCTAssertEqual(TaskNotifyTexts.body(.done, sessionTitle: "修 bug"), "你的 DSH 任务已完成：修 bug")
        XCTAssertEqual(TaskNotifyTexts.body(.question, sessionTitle: nil), "等待你的回答")
        XCTAssertEqual(TaskNotifyTexts.body(.question, sessionTitle: "计划"), "计划 — 等待你的回答")
    }

    func testTagsKeepSessionsAndQuestionsDistinct() {
        let done = TaskEvent(kind: .done, sessionId: "s1", turn: 3)
        let question = TaskEvent(kind: .question, sessionId: "s1", questionId: "q9")
        XCTAssertEqual(TaskNotifyTexts.tag(done), "dsh-task-done-s1-3")
        XCTAssertEqual(TaskNotifyTexts.tag(question), "dsh-task-question-q9")
        XCTAssertNotEqual(TaskNotifyTexts.tag(done), TaskNotifyTexts.tag(question))
    }

    func testParsesMinimalTaskWireEvents() throws {
        let done = try XCTUnwrap(TaskEvent.parse(try JSONValue.parse(
            #"{"ev":"task","kind":"done","sessionId":"s1","turn":4}"#
        )))
        XCTAssertEqual(done.kind, .done)
        XCTAssertEqual(done.sessionId, "s1")
        XCTAssertEqual(done.turn, 4)
        let question = try XCTUnwrap(TaskEvent.parse(try JSONValue.parse(
            #"{"ev":"task","kind":"question","sessionId":"s1","questionId":"q1"}"#
        )))
        XCTAssertEqual(question.kind, .question)
        XCTAssertEqual(question.questionId, "q1")
        XCTAssertNil(TaskEvent.parse(try JSONValue.parse(#"{"ev":"task","kind":"other","sessionId":"s1"}"#)))
        XCTAssertNil(TaskEvent.parse(try JSONValue.parse(#"{"ev":"task","kind":"done"}"#)))
    }
}

final class LanDiscoveryPolicyTests: XCTestCase {
    func testAcceptsOnlyMetadataAnnouncementFromItsAdvertisedAddress() {
        let instanceId = String(repeating: "a", count: 64)
        let result = LanDiscoveryPolicy.parseAnnouncement(
            #"{"deviceName":"Studio PC","host":"192.168.1.20","port":7690,"protocol":1,"instanceId":"\#(instanceId)"}"#,
            remoteAddress: "192.168.1.20"
        )
        XCTAssertEqual(result, DiscoveredHost(instanceId: instanceId, host: "192.168.1.20", port: 7690, deviceName: "Studio PC"))
    }

    func testRejectsSecretBearingOrAddressMismatchedAnnouncements() {
        let instanceId = String(repeating: "a", count: 64)
        let valid = #"{"deviceName":"Studio PC","host":"192.168.1.20","port":7690,"protocol":1,"instanceId":"\#(instanceId)"}"#
        let withSecret = String(valid.dropLast()) + #","deviceToken":"secret"}"#
        XCTAssertNil(LanDiscoveryPolicy.parseAnnouncement(withSecret, remoteAddress: "192.168.1.20"))
        XCTAssertNil(LanDiscoveryPolicy.parseAnnouncement(valid, remoteAddress: "192.168.1.21"))
    }

    func testApplyAddressUpdateOnlyWhenInstanceMatchesAndHostChanges() {
        let id = String(repeating: "b", count: 64)
        XCTAssertNil(LanDiscoveryPolicy.applyAddressUpdate(
            instanceId: id, host: "192.168.1.10", port: 7690,
            discovered: DiscoveredHost(instanceId: id, host: "192.168.1.10", port: 7690, deviceName: "Mac")
        ))
        XCTAssertEqual(
            LanDiscoveryPolicy.applyAddressUpdate(
                instanceId: id, host: "192.168.1.10", port: 7690,
                discovered: DiscoveredHost(instanceId: id, host: "192.168.1.55", port: 7690, deviceName: "Mac")
            )?.host,
            "192.168.1.55"
        )
        XCTAssertNil(LanDiscoveryPolicy.applyAddressUpdate(
            instanceId: id, host: "192.168.1.10", port: 7690,
            discovered: DiscoveredHost(instanceId: String(repeating: "c", count: 64), host: "192.168.1.55", port: 7690, deviceName: "Other")
        ))
    }

    func testUnpairedNearbyDropsPairedInstanceAndHostPort() {
        let pairedId = String(repeating: "d", count: 64)
        let otherId = String(repeating: "e", count: 64)
        let found = [
            DiscoveredHost(instanceId: pairedId, host: "192.168.1.10", port: 7690, deviceName: "Mac"),
            DiscoveredHost(instanceId: otherId, host: "192.168.1.10", port: 7690, deviceName: "NAS"),
            DiscoveredHost(instanceId: otherId, host: "192.168.1.42", port: 7690, deviceName: "Studio"),
        ]
        XCTAssertEqual(
            LanDiscoveryPolicy.unpairedNearby(
                found: found,
                paired: [(pairedId, "192.168.1.10", 7690, false)]
            ),
            [DiscoveredHost(instanceId: otherId, host: "192.168.1.42", port: 7690, deviceName: "Studio")]
        )
    }
}

final class PairedDeviceStatusTests: XCTestCase {
    func testProbeAppliesOnlyToRequestedAuthorization() {
        let current = PairedDeviceIdentity(id: "p1", host: "10.0.0.2", port: 7690, instanceId: "aa")
        let requested = current
        XCTAssertEqual(PairedDeviceStatusPolicy.beginCheck(current: nil), .connecting)
        XCTAssertEqual(PairedDeviceStatusPolicy.beginCheck(current: .unauthorized), .unauthorized)
        XCTAssertEqual(
            PairedDeviceStatusPolicy.applyProbe(
                currentDot: .offline, current: current, requested: requested, reachable: true, revoked: false
            ),
            .online
        )
        XCTAssertEqual(
            PairedDeviceStatusPolicy.applyProbe(
                currentDot: .offline, current: current, requested: requested, reachable: false, revoked: true
            ),
            .unauthorized
        )
        var other = current
        other.host = "10.0.0.3"
        XCTAssertEqual(
            PairedDeviceStatusPolicy.applyProbe(
                currentDot: .connecting, current: current, requested: other, reachable: true, revoked: false
            ),
            .connecting
        )
    }
}

final class PresetPolicyTests: XCTestCase {
    func testBuiltInFoldIgnoresRenamedIds() throws {
        let standard = try JSONValue.parse(#"{"id":"standard"}"#)
        let renamed = try JSONValue.parse(#"{"id":"standard","name":"My standard"}"#)
        let ptc = try JSONValue.parse(#"{"id":"ptc"}"#)
        XCTAssertTrue(PresetPolicy.isBuiltIn(standard))
        XCTAssertFalse(PresetPolicy.isBuiltIn(renamed))
        XCTAssertFalse(PresetPolicy.requiresCodingTools(renamed))
        XCTAssertTrue(PresetPolicy.requiresCodingTools(ptc))
        XCTAssertFalse(PresetPolicy.isBuiltIn(try JSONValue.parse(#"{"id":"unknown"}"#)))
        XCTAssertEqual(PresetPolicy.name(standard, english: false), "标准模式")
        XCTAssertEqual(PresetPolicy.name(renamed, english: false), "My standard")
        XCTAssertTrue(PresetPolicy.guideAvailable("cordis"))
        XCTAssertTrue(PresetPolicy.canLoad(online: true, ops: ["presets.list"]))
        XCTAssertFalse(PresetPolicy.canLoad(online: false, ops: ["presets.list"]))
        let mutation = PresetPolicy.defaultMutation(id: "ptc")
        XCTAssertEqual(mutation.arr()?.first?["op"].str(), "set")
        XCTAssertEqual(mutation.arr()?.first?["path"].arr()?.compactMap { $0.str() }, ["selectedDefault"])
        XCTAssertEqual(mutation.arr()?.first?["value"].str(), "ptc")
        XCTAssertEqual(PresetPolicy.registryNamespace, "agent-preset-registry")
    }

    func testWritableRequiresSettingsRevisionAndMutate() throws {
        let data = try JSONValue.parse(#"{"writable":true,"namespace":{"revision":7},"presets":[{"id":"cordis"}]}"#)
        XCTAssertTrue(PresetPolicy.hostWritable(data: data, ops: ["models.settingsMutate"]))
        XCTAssertFalse(PresetPolicy.hostWritable(data: data, ops: []))
        XCTAssertTrue(PresetPolicy.canCreateWithCreator(PresetPolicy.parseRoster(data), ops: ["sessions.create"], online: true))
        XCTAssertEqual(PresetPolicy.visibleRows([try JSONValue.parse(#"{"id":"ptc"}"#)], codingTools: false).count, 0)
        XCTAssertEqual(PresetPolicy.visibleRows([try JSONValue.parse(#"{"id":"ptc"}"#)], codingTools: true).count, 1)
    }
}

