import XCTest
@testable import DSHProtocol

final class HostUiTests: XCTestCase {
    func testTicketExchangeKeepsBearerOutOfUrlAndRetainsHttpOnlySameSiteCookie() async throws {
        let origin = HostUiOrigin(scheme: "http", host: "192.0.2.1", port: 7690)
        let http = MockHostUiHTTP { url, body in
            XCTAssertEqual(url.path, "/pocket-ui/open")
            XCTAssertEqual(String(data: body, encoding: .utf8), "ticket=one-use%2Bticket%26%27%3D")
            return HostUiHTTPResponse(
                status: 303,
                headers: [
                    "Location": ["/?pocket-ui=1&section=models"],
                    "Set-Cookie": ["dsh-pocket-web=short-session; Path=/; Max-Age=900; HttpOnly; SameSite=Strict"],
                ]
            )
        }
        let session = try await exchangeHostUiTicket(http: http, origin: origin, path: "/pocket-ui/open", ticket: "one-use+ticket&'=")
        XCTAssertEqual(URLComponents(url: session.startURL, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "section" }?.value, "models")
        XCTAssertTrue(session.cookie.httpOnly)
        XCTAssertTrue(session.cookie.hostOnly)
        XCTAssertTrue(session.cookieHeader.contains("SameSite=Strict"))
        XCTAssertFalse(session.startURL.absoluteString.contains("one-use"))
    }

    func testRedirectCannotMoveSessionToDifferentOriginOrRevealTicket() async {
        let origin = HostUiOrigin(scheme: "http", host: "192.0.2.1", port: 7690)
        for location in [
            "https://outside.invalid/?pocket-ui=1",
            "//outside.invalid/?pocket-ui=1",
            "/?pocket-ui=1&token=host-secret",
            "/?pocket-ui=1&ticket=grant",
            "/pocket/devices?pocket-ui=1",
            "/?pocket-ui=1#ticket",
            "/?pocket-ui=1&pocket-ui=0",
            "/?pocket-ui=1&section=models&section=plugins",
            "/?pocket-ui=1&%74oken=secret",
            "/?pocket-ui=1&Authorization=secret",
            "/?pocket-ui=1&cookie=secret",
        ] {
            let http = MockHostUiHTTP { _, _ in
                HostUiHTTPResponse(
                    status: 303,
                    headers: [
                        "Location": [location],
                        "Set-Cookie": ["dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict; Max-Age=900"],
                    ]
                )
            }
            do {
                _ = try await exchangeHostUiTicket(http: http, origin: origin, path: "/pocket-ui/open", ticket: "ticket")
                XCTFail("Accepted unsafe redirect: \(location)")
            } catch {}
        }
    }

    func testSessionRejectsReadableCookiesAndNeverAcceptsUpstreamHostCookie() async {
        let origin = HostUiOrigin(scheme: "http", host: "localhost", port: 7690)
        for header in [
            "dsh-auth-host=privileged; Path=/; HttpOnly; SameSite=Strict; Max-Age=900",
            "dsh-pocket-web=session; Path=/; SameSite=Strict; Max-Age=900",
            "dsh-pocket-web=session; Domain=localhost; Path=/; HttpOnly; SameSite=Strict; Max-Age=900",
            "dsh-pocket-web=session; Path=/api; HttpOnly; SameSite=Strict; Max-Age=900",
            "dsh-pocket-web=session; Path=/; HttpOnly; Max-Age=900",
            "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Lax; Max-Age=900",
            "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict",
            "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict; Max-Age=0",
            "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict; Max-Age=-1",
            "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict; Max-Age=invalid",
            "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict; Max-Age=900; Max-Age=1",
            "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
        ] {
            let http = MockHostUiHTTP { _, _ in
                HostUiHTTPResponse(status: 303, headers: [
                    "Location": ["/?pocket-ui=1"],
                    "Set-Cookie": [header],
                ])
            }
            do {
                _ = try await exchangeHostUiTicket(http: http, origin: origin, path: "/pocket-ui/open", ticket: "ticket")
                XCTFail("Accepted unsafe cookie: \(header)")
            } catch {}
        }
    }

    func testAuthenticationFailureIsNotAnEmptyAuthenticatedPage() async {
        let origin = HostUiOrigin(scheme: "http", host: "192.0.2.1", port: 7690)
        let http = MockHostUiHTTP { _, _ in HostUiHTTPResponse(status: 401, headers: [:], body: Data("expired".utf8)) }
        do {
            _ = try await exchangeHostUiTicket(http: http, origin: origin, path: "/pocket-ui/open", ticket: "expired-ticket")
            XCTFail("Accepted failed authentication")
        } catch {}
    }

    func testCookieLifetimeUsesMaxAgePrecedenceAndRejectsExpiryBoundary() throws {
        let origin = HostUiOrigin(scheme: "http", host: "localhost", port: 7690)
        let now = Date(timeIntervalSince1970: 1_445_412_480)
        let base = "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict"
        let expires = "; Expires=Wed, 21 Oct 2015 07:28:00 GMT"
        XCTAssertNil(parseHostUiCookie(base + expires, origin: origin, now: now))
        let absolute = try XCTUnwrap(parseHostUiCookie(base + expires, origin: origin, now: now.addingTimeInterval(-1)))
        XCTAssertEqual(absolute.expiresAt, now)
        let relative = try XCTUnwrap(parseHostUiCookie(base + expires + "; Max-Age=900", origin: origin, now: now))
        XCTAssertEqual(relative.expiresAt, now.addingTimeInterval(900))
        XCTAssertNil(parseHostUiCookie(base + "; Max-Age=900", origin: HostUiOrigin(scheme: "https", host: "localhost", port: 443), now: now))
    }

    func testDuplicateRedirectAndCookieHeadersAreRejected() async {
        let origin = HostUiOrigin(scheme: "http", host: "localhost", port: 7690)
        let cookie = "dsh-pocket-web=session; Path=/; HttpOnly; SameSite=Strict; Max-Age=900"
        for headers in [
            ["Location": ["/?pocket-ui=1", "/?pocket-ui=1"], "Set-Cookie": [cookie]],
            ["Location": ["/?pocket-ui=1"], "location": ["/?pocket-ui=1"], "Set-Cookie": [cookie]],
            ["Location": ["/?pocket-ui=1"], "Set-Cookie": [cookie, cookie]],
            ["Location": ["/?pocket-ui=1"], "Set-Cookie": [cookie, "dsh-auth-host=secret"]],
        ] {
            let http = MockHostUiHTTP { _, _ in HostUiHTTPResponse(status: 303, headers: headers) }
            do {
                _ = try await exchangeHostUiTicket(http: http, origin: origin, path: "/pocket-ui/open", ticket: "ticket")
                XCTFail("Accepted ambiguous response")
            } catch {}
        }
    }

    func testWebNavigationRejectsOtherHostsPortsSchemesCredentialsAndLocalFiles() throws {
        let policy = HostUiPolicy(origin: HostUiOrigin(scheme: "http", host: "192.0.2.1", port: 7690))
        XCTAssertTrue(policy.allows("http://192.0.2.1:7690/?pocket-ui=1&section=custom"))
        XCTAssertTrue(policy.allows("http://192.0.2.1:7690/plugins/vendor/client.js?rev=2"))
        for url in [
            "http://192.0.2.1:7691/", "https://192.0.2.1:7690/", "http://outside.invalid/",
            "http://user@192.0.2.1:7690/", "http://192.0.2.1:7690\\@outside.invalid/",
            "file:///sdcard/private", "javascript:alert(1)", "data:text/html,hello",
            "http://192.0.2.1:7690/\n",
        ] {
            XCTAssertFalse(policy.allows(url), url)
        }
    }
}

private struct MockHostUiHTTP: HostUiHTTPClient {
    let handler: @Sendable (URL, Data) -> HostUiHTTPResponse
    func post(url: URL, body: Data) async throws -> HostUiHTTPResponse { handler(url, body) }
}

final class PluginPolicyTests: XCTestCase {
    func testDeclarationDoesNotImplyEnabledRuntime() throws {
        let row = try JSONValue.parse(#"{"rowId":"tool","moduleName":"tool","entryId":"live-1"}"#)
        let live = try JSONValue.parse(#"{"entryId":"live-1","enabled":false,"fiberPhase":null}"#)
        XCTAssertEqual(pluginLiveRow(row, plugins: [live]), live)
        XCTAssertFalse(pluginLiveRow(row, plugins: [live])?["enabled"].bool() == true)
        XCTAssertNil(pluginLiveRow(row, plugins: []))
    }

    func testRuntimeJoinUsesEntryIdentityNotModuleOrRowName() throws {
        let row = try JSONValue.parse(#"{"rowId":"same","moduleName":"same","entryId":"a"}"#)
        let wrong = try JSONValue.parse(#"{"entryId":"b","id":"same","moduleName":"same","enabled":true}"#)
        XCTAssertNil(pluginLiveRow(row, plugins: [wrong]))
        XCTAssertNil(pluginLiveRow(try JSONValue.parse(#"{"rowId":"same"}"#), plugins: [wrong]))
    }

    func testPartsSummaryCountsHostRuntimeRatherThanDeclarations() throws {
        let rows = try [
            #"{"entryId":"a","enabled":false}"#,
            #"{"entryId":"b","enabled":true}"#,
            #"{"entryId":"c"}"#,
            #"{"entryId":"missing","enabled":true,"fiberPhase":"active"}"#,
        ].map { try JSONValue.parse($0) }
        let live = try [
            #"{"entryId":"a","enabled":true,"fiberPhase":"active"}"#,
            #"{"entryId":"b","enabled":false,"fiberPhase":"failed"}"#,
            #"{"entryId":"c","enabled":true,"fiberPhase":"pending"}"#,
            #"{"entryId":"unrelated","enabled":true,"fiberPhase":"active"}"#,
        ].map { try JSONValue.parse($0) }
        XCTAssertEqual(pluginParts(rows: rows, plugins: live), PluginParts(total: 4, running: 1, off: 2, failed: 1))
        XCTAssertEqual(pluginParts(rows: [], plugins: live), PluginParts(total: 0, running: 0, off: 0, failed: 0))
    }

    func testParentWritesCannotEraseRedactedSecrets() {
        let secrets = [["provider", "apiKey"]]
        XCTAssertTrue(pluginSettingsReplacesSecret(path: [], secrets: secrets))
        XCTAssertTrue(pluginSettingsReplacesSecret(path: ["provider"], secrets: secrets))
        XCTAssertFalse(pluginSettingsReplacesSecret(path: ["provider", "apiKey"], secrets: secrets))
        XCTAssertFalse(pluginSettingsReplacesSecret(path: ["provider", "model"], secrets: secrets))
        XCTAssertFalse(pluginSettingsReplacesSecret(path: [], secrets: []))
    }

    func testDereferencesSchemasteryGraphForNativeNumberFields() throws {
        let schema = try JSONValue.parse(
            #"{"uid":6358,"refs":{"6358":{"type":"object","dict":{"maxParallelToolCalls":6357}},"6357":{"type":"number","meta":{"step":1,"min":1,"default":10}}}}"#
        )
        let fields = pluginSchemaFields(schema)
        XCTAssertEqual(fields.count, 1)
        XCTAssertEqual(fields[0].path, ["maxParallelToolCalls"])
        XCTAssertEqual(fields[0].type, "number")
        XCTAssertEqual(fields[0].schema["meta"]["default"].int(), 10)
    }

    func testSupportsNestedNativeBooleanAndEnumWithoutFollowingCycles() throws {
        let schema = try JSONValue.parse(
            #"{"uid":1,"refs":{"1":{"type":"object","dict":{"options":2,"mode":4,"cycle":1}},"2":{"type":"object","dict":{"enabled":3}},"3":{"type":"boolean"},"4":{"type":"union","list":[5,6]},"5":{"type":"const","value":"safe"},"6":{"type":"const","value":"fast"}}}"#
        )
        let fields = pluginSchemaFields(schema)
        XCTAssertEqual(fields.count, 2)
        XCTAssertTrue(fields.contains { $0.path == ["options", "enabled"] && $0.type == "boolean" })
        XCTAssertTrue(fields.contains { $0.path == ["mode"] && $0.type == "enum" && $0.choices == [.string("safe"), .string("fast")] })
    }

    func testSvgAllowlistRejectsScriptAndRemoteCss() {
        XCTAssertFalse(isSupportedPluginSvg(#"<svg><script>alert(1)</script></svg>"#))
        XCTAssertFalse(isSupportedPluginSvg(#"<!DOCTYPE svg><svg></svg>"#))
        XCTAssertTrue(isSupportedPluginSvg(#"<svg><circle r="4" fill="url(#g)"/></svg>"#))
        XCTAssertNil(pluginMetadataSVG("https://evil.example/icon.svg"))
    }


    func testMarketGroupsAndExperimentalMetadataRemainIndependent() throws {
        let official = try JSONValue.parse(
            #"{"name":"@deepseek-ai/dsh-experimental-agent-team-profile","official":true,"optional":true,"enabled":false,"meta":{"title":{"zh":"智能体团队","en":"Agent team"},"description":{"zh":"启用团队协作。","en":"Enable team collaboration."}}}"#
        )
        let hidden = try JSONValue.parse(#"{"name":"@deepseek-ai/dsh-base","official":true}"#)
        let third = try JSONValue.parse(#"{"name":"dsh-plugin-whale-pet","official":false,"installed":true,"enabled":true}"#)
        let missing = try JSONValue.parse(#"{"name":"unused","official":false,"installed":false}"#)
        let bundles = [hidden, official, third, missing].filter { name in
            guard let name = name["name"].str() else { return true }
            return !hiddenProfileBundles.contains(name)
        }
        let groups = pluginMarketGroups(bundles)
        XCTAssertEqual(groups.official.map { $0["name"].str() }, ["@deepseek-ai/dsh-experimental-agent-team-profile"])
        XCTAssertEqual(groups.installed.map { $0["name"].str() }, ["dsh-plugin-whale-pet"])
        XCTAssertTrue(pluginExperimental(official))
        XCTAssertFalse(pluginExperimental(try JSONValue.parse(#"{"name":"@deepseek-ai/dsh-catalog-plugin","official":true}"#)))
        XCTAssertFalse(pluginExperimental(third))
        XCTAssertEqual(pluginTitle(official, english: false), "智能体团队")
        XCTAssertEqual(pluginDescription(official, english: false), "启用团队协作。")
        XCTAssertEqual(pluginTitle(official, english: true), "Agent team")
    }

    func testMorePluginsPinToMainOnlyWhenEnabled() {
        let heldBack = "@deepseek-ai/dsh-experimental-ralph-bundle"
        XCTAssertFalse(pluginOptionalVisible(name: heldBack, enabled: false, expanded: false))
        XCTAssertTrue(pluginOptionalVisible(name: heldBack, enabled: true, expanded: false))
        XCTAssertTrue(pluginOptionalVisible(name: heldBack, enabled: false, expanded: true))
        XCTAssertTrue(pluginOptionalVisible(name: "@deepseek-ai/dsh-experimental-agent-team-profile", enabled: false, expanded: false))
        XCTAssertTrue(pluginOptionalVisible(name: "@deepseek-ai/dsh-new-feature", enabled: false, expanded: false))
    }

    func testNeedsInstallWhenOfficialPackageIsMissing() throws {
        let missing = try JSONValue.parse(
            #"{"name":"@deepseek-ai/dsh-experimental-terminal-bundle","official":true,"optional":true,"availability":"missing","installTarget":{"spec":"@deepseek-ai/dsh-experimental-terminal-bundle"}}"#
        )
        XCTAssertTrue(pluginNeedsInstallToEnable(missing))
        XCTAssertTrue(pluginExperimental(missing))
        let installed = try JSONValue.parse(#"{"name":"x","availability":"ok","installTarget":{"spec":"x"}}"#)
        XCTAssertFalse(pluginNeedsInstallToEnable(installed))
    }
}

final class SchedulePolicyTests: XCTestCase {
    private func weekly() throws -> JSONValue {
        try JSONValue.parse("""
        {"id":"task-1","sessionId":"session-1","kind":"weekly","status":"active",
         "title":"Reminder","prompt":"Do the work","scheduledAt":"2026-10-15T01:00:00.123Z",
         "time":"09:00:00.123","timeZone":"Asia/Shanghai","weekdays":[1,3,5],
         "lastDelivery":{"scheduledAt":"2026-10-13T01:00:00.123Z","messageId":"message-1"}}
        """)
    }

    func testSnapshotKeepsCompleteRuleButNoCatalogMetadata() throws {
        let expected = try scheduleSnapshot(weekly())
        XCTAssertEqual(Set((expected.obj() ?? [:]).keys), Set(["id", "kind", "title", "prompt", "scheduledAt", "time", "timeZone", "weekdays"]))
        XCTAssertEqual(expected["weekdays"], try weekly()["weekdays"])
        XCTAssertEqual(expected["time"].str(), "09:00:00.123")
        XCTAssertEqual(expected["scheduledAt"].str(), "2026-10-15T01:00:00.123Z")
    }

    func testContentEditOmitsTimingAndRetainsOriginalCas() throws {
        let row = try weekly()
        let draft = scheduleTimingDraft(row)
        let request = try scheduleUpdateRequest(row, title: "New title", prompt: "Do the work", initial: draft, draft: draft)
        XCTAssertTrue(request["change"].isNull)
        XCTAssertTrue(request["prompt"].isNull)
        XCTAssertEqual(request["title"].str(), "New title")
        XCTAssertEqual(request["expected"], try scheduleSnapshot(row))
        var refreshed = row.obj() ?? [:]
        refreshed["scheduledAt"] = .string("2026-10-17T01:00:00.123Z")
        XCTAssertNotEqual(try scheduleSnapshot(.object(refreshed)), request["expected"])
    }

    func testChangedWeekdaysKeepMillisecondsAndStoredZoneSpelling() throws {
        var alias = try weekly().obj() ?? [:]
        alias["timeZone"] = .string("US/Eastern")
        let row = JSONValue.object(alias)
        let draft = scheduleTimingDraft(row)
        let request = try scheduleUpdateRequest(row, title: "Reminder", prompt: "Do the work", initial: draft, draft: draft.copy(weekdays: Set([2, 4])))
        XCTAssertEqual(request["change"]["weekly"]["time"].str(), "09:00:00.123")
        XCTAssertEqual(request["change"]["weekly"]["time_zone"].str(), "US/Eastern")
        XCTAssertEqual(request["change"]["weekly"]["weekdays"].arr()?.compactMap { $0.int() }, [2, 4])
    }

    func testIntervalConversionIsExactAndEnforcesHostFloorAndSafeInteger() {
        XCTAssertEqual(scheduleIntervalSeconds("1", unit: "minute"), 60)
        XCTAssertEqual(scheduleIntervalSeconds("1.5", unit: "minute"), 90)
        XCTAssertNil(scheduleIntervalSeconds("59", unit: "second"))
        XCTAssertNil(scheduleIntervalSeconds("60.1", unit: "second"))
        XCTAssertNil(scheduleIntervalSeconds("9007199254740992", unit: "second"))
        XCTAssertEqual(scheduleConvertQuantity("90", from: "second", to: "minute"), "1.5")
        XCTAssertNil(scheduleConvertQuantity("61", from: "second", to: "minute"))
        let row = jsonObject(["kind": .string("every"), "everySeconds": .number(61), "scheduledAt": .string("2026-10-15T00:00:00.000Z")])
        let draft = scheduleTimingDraft(row, deviceZone: "UTC")
        XCTAssertEqual(draft.unit, "second")
        XCTAssertEqual(draft.quantity, "61")
    }

    func testCronMatchesSupportedNumericDialect() {
        for expression in ["0 9 * * 1-5", "*/15 9-17/2 1,15 * 0,7", "0 0 * * *", "0 0 */2 * 1-7"] {
            XCTAssertTrue(scheduleCronValid(expression), expression)
        }
        for expression in ["@daily", "0 9 * *", "1-60 * * * *", ""] {
            XCTAssertFalse(scheduleCronValid(expression), expression)
        }
    }

    func testCatalogAcceptsArrayOrNamedObjectAndRejectsUnknownShape() throws {
        XCTAssertEqual(try scheduleCatalogRows(.array([jsonObject(["id": .string("a")])])).count, 1)
        XCTAssertEqual(try scheduleCatalogRows(jsonObject(["items": .array([jsonObject(["id": .string("a")])])])).count, 1)
        XCTAssertEqual(try scheduleCatalogRows(jsonObject(["tasks": .array([jsonObject(["id": .string("a")])])])).count, 1)
        XCTAssertThrowsError(try scheduleCatalogRows(jsonObject(["rows": .array([])])))
        XCTAssertEqual(try scheduleHistoryRows(jsonObject(["records": .array([jsonObject(["status": .string("ok")])])])).count, 1)
        XCTAssertThrowsError(try scheduleHistoryRows(jsonObject(["ok": .bool(true)])))
    }

    func testDstGapsAndOverlapsAreSentAsLocalSelectors() throws {
        let draft = scheduleTimingDraft(try weekly()).copy(kind: "once", date: "2027-03-14", time: "02:30:00.123", zone: "America/New_York")
        let gap = try scheduleTimingChange(draft)
        XCTAssertEqual(gap["at"]["date"].str(), "2027-03-14")
        XCTAssertEqual(gap["at"]["time"].str(), "02:30:00.123")
        let overlap = try scheduleTimingChange(draft.copy(date: "2026-11-01", time: "01:30:00.123"))
        XCTAssertEqual(overlap["at"]["time"].str(), "01:30:00.123")
        XCTAssertEqual(overlap["at"]["time_zone"].str(), "America/New_York")
    }
}

final class ToolProcessSummaryTests: XCTestCase {
    private func tool(_ name: String, result: String?, args: String = "{}", status: ToolStatus = .ok) -> Item.Tool {
        Item.Tool(key: "tool-1", callId: "call-1", name: name, arguments: args, status: status, result: result)
    }

    func testWaitReceiptDistinguishesNoProgressTimeoutAndChange() {
        let noProgress = tool("wait_agent", result: #"{"timedOut":false,"noProgress":{"message":"No running children"}}"#, args: #"{"timeout_ms":120000}"#)
        XCTAssertEqual(toolProcessSummary(noProgress).summary, "没有正在运行的子智能体")
        XCTAssertEqual(toolProcessSummary(Item.Tool(key: "tool-1", callId: "call-1", name: "wait_agent", arguments: #"{"timeout_ms":120000}"#, status: .ok, result: #"{"timedOut":true}"#)).summary, "子智能体状态 · 等待超时")
        XCTAssertEqual(toolProcessSummary(Item.Tool(key: "tool-1", callId: "call-1", name: "wait_agent", arguments: #"{"timeout_ms":120000}"#, status: .ok, result: #"{"timedOut":false}"#)).summary, "子智能体状态 · 检测到变化")
    }

    func testMalformedOrFailedReceiptsNeverClaimAnEmptySuccessfulList() {
        XCTAssertNil(toolProcessSummary(tool("job_list", result: "malformed output")).summary)
        XCTAssertNil(toolProcessSummary(tool("wait_agent", result: #"{"noProgress":{"message":"bad shape"}}"#)).summary)
        var failed = tool("job_list", result: "(no background jobs)", status: .error)
        failed.error = "permission denied"
        XCTAssertEqual(toolProcessSummary(failed).summary, "permission denied")
        XCTAssertNotEqual(toolProcessSummary(failed).summary, "0 个后台任务")
    }

    func testCountsOnlyRecognizedDurableAgentAndJobOutputs() {
        XCTAssertEqual(toolProcessSummary(tool("job_list", result: "(no background jobs)")).summary, "0 个后台任务")
        XCTAssertEqual(toolProcessSummary(tool("job_list", result: "one [bash] running — npm test\ntwo [subagent] completed — inspect UI")).summary, "2 个后台任务")
        XCTAssertEqual(toolProcessSummary(tool("list_agents", result: #"[{"id":"a1","status":"idle"}]"#)).summary, "1 个智能体")
        XCTAssertEqual(toolProcessSummary(tool("list_agents", result: "a1 [idle] parent=root depth=1 — Worker\na2 [running] — Scout")).summary, "2 个智能体")
        XCTAssertNil(toolProcessSummary(tool("job_list", result: "one [bash] running — npm test\nnot a job")).summary)
    }

    func testRunningRowsDoNotTreatResidualOutputAsCompletedReceipts() {
        let running = tool("job_list", result: "(no background jobs)", status: .running)
        XCTAssertNil(toolProcessSummary(running).summary)
        XCTAssertEqual(toolProcessSummary(tool("job_list", result: "(no background jobs)")).summary, "0 个后台任务")
    }

    func testGenericArgumentPreferenceAndUnknownNamesRemainInspectable() {
        XCTAssertEqual(toolProcessSummary(tool("bash", result: nil, args: #"{"command":"npm test","description":"Run tests"}"#, status: .running)).summary, "Run tests")
        XCTAssertEqual(toolProcessSummary(tool("web_search", result: nil, args: #"{"queries":["first\nextra","second"]}"#, status: .running)).summary, "first, second")
        let custom = toolProcessSummary(tool("vendor.job_list", result: "(no background jobs)", args: #"{"scope":"current"}"#))
        XCTAssertEqual(custom.summary, "vendor.job_list · current")
        XCTAssertEqual(custom.icon, .generic)
        XCTAssertEqual(custom.title, "工具调用")
    }

    func testPreparingKeepsOfficialTitleAndArgumentSummary() {
        let preparing = tool("grep", result: nil, args: #"{"pattern":"TODO"}"#, status: .preparing)
        let summary = toolProcessSummary(preparing)
        XCTAssertEqual(summary.title, "搜索文件内容")
        XCTAssertEqual(summary.summary, "TODO")
        XCTAssertEqual(toolProcessSummary(tool("web_fetch", result: nil, args: #"{"url":"https://ex"}"#, status: .running)).title, "网页获取")
    }
}

final class ProviderSettingsTests: XCTestCase {
    func testProviderAddOptionsAndRouteValidation() throws {
        let rows = try [
            JSONValue.parse(#"{"provider":"openai","settingsNs":"llm-pi-ai","configured":false}"#),
            JSONValue.parse(#"{"provider":"deepseek-account","settingsNs":"llm-deepseek","configured":true}"#),
        ]
        let namespaces = try [JSONValue.parse(#"{"ns":"llm-pi-ai"}"#), JSONValue.parse(#"{"ns":"llm-deepseek"}"#)]
        let options = providerAddOptions(rows: rows, namespaces: namespaces)
        XCTAssertTrue(options.offered)
        XCTAssertEqual(options.catalog.count, 1)
        XCTAssertEqual(providerRouteFailure("Acme", taken: [], en: false)?.contains("小写"), true)
        XCTAssertEqual(providerRouteFailure("acme", taken: ["acme"]), "该 Provider ID 已被占用")
        XCTAssertNil(providerRouteFailure("acme-gateway", taken: []))
        XCTAssertTrue(providerEndpointValid("https://gateway.example/v1"))
        XCTAssertFalse(providerEndpointValid("ftp://x"))
        XCTAssertEqual(providerKeyRef("acme-gateway"), "ACME_GATEWAY_API_KEY")
        XCTAssertEqual(providerKeyFailure("sk-abc"), nil)
        XCTAssertEqual(providerKeyFailure("FOO=bar"), "keyIllegalCharacters")
    }

    func testProviderFieldOpsNeverReplaceUnchangedOrNullParents() {
        let before = jsonObject(["baseURL": .string("https://a.example"), "displayName": .string("A")])
        let ops = providerFieldOps(
            path: ["providers", "acme"],
            before: before,
            after: ["baseURL": .string("https://a.example"), "displayName": .null, "api": .string("openai-completions")]
        )
        XCTAssertEqual(ops.count, 2)
        XCTAssertTrue(ops.contains { $0["op"].str() == "unset" && $0["path"].arr()?.compactMap { $0.str() } == ["providers", "acme", "displayName"] })
        XCTAssertTrue(ops.contains { $0["op"].str() == "set" && $0["path"].arr()?.compactMap { $0.str() } == ["providers", "acme", "api"] })
    }

    func testRemoveProviderDoesNotClearKeyBeforeConfigurationSucceeds() async throws {
        var progress = ProviderRemovalProgress()
        var config = 0
        var key = 0
        do {
            try await removeProviderSafely(
                progress: progress,
                onProgress: { progress = $0 },
                removeConfiguration: { config += 1; throw PocketError(code: "conflict", message: "cas") },
                confirmRemoval: {},
                clearManagedCredential: { key += 1 }
            )
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(config, 1)
            XCTAssertEqual(key, 0)
            XCTAssertFalse(progress.configurationRemoved)
        }
    }
}

final class MarkdownAndChatProcessTests: XCTestCase {
    func testParseMarkdownTablesCodeAndFileChips() {
        let blocks = parseMarkdown(sampleMarkdown)
        XCTAssertTrue(blocks.contains { if case .table = $0 { return true }; return false })
        XCTAssertTrue(blocks.contains { if case .bulletList = $0 { return true }; return false })
        XCTAssertEqual(parseFileLink("cordis.patch.yml"), "cordis.patch.yml")
        XCTAssertNil(parseFileLink("https://example.com/a.md"))
        let code = parseMarkdown("```swift\nlet x = 1\n```")
        XCTAssertTrue(code.contains { if case .code(let language, _, let incomplete) = $0 { return language == "swift" && !incomplete }; return false })
        let chatList = parseMarkdown("你好，我是 DeepSeek。[README.md](README.md)\n\n- 第一项\n- 第二项")
        XCTAssertTrue(chatList.contains { block in
            if case .bulletList(let items, _) = block { return items.count == 2 }
            return false
        })
    }

    func testFoldGroupsToolsAndReasoningIntoProcess() {
        let items: [Item] = [
            .tool(Item.Tool(key: "t1", callId: "c1", name: "bash", arguments: #"{"command":"ls"}"#, status: .ok, result: "ok", turn: 1)),
            .reasoning(Item.Reasoning(key: "r1", text: "thinking", live: false, turn: 1)),
            .text(Item.Text(key: "a1", text: "done", live: false, turn: 1)),
        ]
        let rows = foldChatItems(items, policy: presentationPolicyFor(.standard), sessionRunning: false, turnRecords: [
            TurnRecord(turn: 1, startSeq: 1, endSeq: 3, startedAt: 0, endedAt: 1000),
        ])
        XCTAssertTrue(rows.contains { if case .process = $0 { return true }; return false })
        XCTAssertTrue(rows.contains { if case .answer = $0 { return true }; return false })
    }

    func testReasoningPreviewUsesFirstLineWhenSettled() {
        XCTAssertEqual(reasoningPreview("alpha\nbeta", running: false), "alpha")
        XCTAssertEqual(processTitle(["thinking", "commands"], en: false), "已完成分析并执行了命令")
    }
}

final class PermissionCatalogTests: XCTestCase {
    func testRejectsCustomAndIneligibleDefaults() throws {
        let ok = try JSONValue.parse("""
        {"options":[{"value":"workspace-write","name":"Workspace"},{"value":"danger-full-access","name":"Full"}],
         "defaultOptions":[{"value":"workspace-write","name":"Workspace"}],
         "defaultPreset":"workspace-write"}
        """)
        let catalog = try PermissionCatalog.parse(ok)
        XCTAssertTrue(catalog.allowsDefault("workspace-write"))
        XCTAssertFalse(catalog.allowsDefault("danger-full-access"))
        XCTAssertThrowsError(try PermissionCatalog.parse(try JSONValue.parse(
            #"{"options":[{"value":"custom","name":"Custom"}],"defaultOptions":[],"defaultPreset":"x"}"#
        )))
    }
}
