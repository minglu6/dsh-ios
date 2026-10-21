import Foundation
import DSHProtocol

/// Exact fields owned by the official Host settings namespaces.
/// Appearance and fonts stay on the phone (`isPhoneLocalThemeField`); they are
/// not Host `ui-theme` mirrors. Language is Host `locale.preference`.
enum SharedSetting: String, CaseIterable {
    case language, busySend, codeWork, transcript, collapse, performance, permission, sessionLog, linkOpening

    var namespace: String {
        switch self {
        case .language: return "locale"
        case .busySend: return "ui-conversation"
        case .codeWork: return "ui-settings"
        case .transcript, .collapse, .performance, .linkOpening: return "ui-chat"
        case .permission: return "permission"
        case .sessionLog: return "session-log-deepseek"
        }
    }

    var field: String {
        switch self {
        case .language: return "preference"
        case .busySend: return "busyEnter"
        case .codeWork: return "enabled"
        case .transcript: return "transcriptView"
        case .collapse: return "collapseTiming"
        case .performance: return "performanceUsage"
        case .permission: return "defaultPreset"
        case .sessionLog: return "enabled"
        case .linkOpening: return "linkOpening"
        }
    }

    /// Compile-time fence: every Host-mirrored field must stay off the phone-local theme set.
    var isPhoneLocalTheme: Bool { isPhoneLocalThemeField(namespace: namespace, field: field) }
}

/// Live Host settings mirror. Never a persisted mobile copy.
@MainActor
final class HostSettings: ObservableObject {
    @Published private(set) var snapshot: JSONValue?
    @Published private(set) var online = false
    @Published private(set) var loading = false
    @Published private(set) var saving = false
    @Published var error: String?

    private var describe: (() async throws -> JSONValue)?
    private var mutate: ((String, JSONValue, Int) async throws -> JSONValue)?
    private var generation = 0
    var onChange: (() -> Void)?

    var ready: Bool { online && snapshot != nil }

    func bind(
        describe: @escaping () async throws -> JSONValue,
        mutate: ((String, JSONValue, Int) async throws -> JSONValue)? = nil
    ) {
        precondition(SharedSetting.allCases.allSatisfy { !$0.isPhoneLocalTheme })
        clear()
        self.describe = describe
        self.mutate = mutate
        online = true
        refresh()
    }

    func clear() {
        describe = nil
        mutate = nil
        generation += 1
        snapshot = nil
        online = false
        loading = false
        saving = false
        error = nil
    }

    func dismissError() { error = nil }

    func namespace(_ setting: SharedSetting) -> JSONValue? {
        namespace(setting.namespace)
    }

    func namespace(_ ns: String) -> JSONValue? {
        snapshot?["namespaces"].arr()?.first { $0["ns"].str() == ns }
    }

    func value(_ setting: SharedSetting) -> JSONValue? {
        namespace(setting)?["value"][setting.field]
    }

    func hasField(_ setting: SharedSetting) -> Bool {
        guard let object = namespace(setting)?["value"].obj() else { return false }
        return object.keys.contains(setting.field)
    }

    func writable(_ setting: SharedSetting) -> Bool {
        ready && !saving && mutate != nil && snapshot?["writable"].bool() == true
            && namespace(setting)?["writable"].bool() != false
            && (namespace(setting)?["revision"].int() ?? -1) >= 0
    }

    func refresh() {
        guard let describe else { return }
        let gen = generation
        loading = true
        Task {
            do {
                let next = try await describe()
                guard gen == generation else { return }
                adopt(next)
                loading = false
                error = nil
            } catch {
                guard gen == generation else { return }
                loading = false
                self.error = error.localizedDescription
            }
        }
    }

    /// Replace one namespace when the event revision is not older than the local copy.
    func adopt(_ next: JSONValue) {
        let previous = Dictionary(uniqueKeysWithValues: (snapshot?["namespaces"].arr() ?? []).compactMap { row -> (String, JSONValue)? in
            guard let ns = row["ns"].str() else { return nil }
            return (ns, row)
        })
        let namespaces = (next["namespaces"].arr() ?? []).map { row -> JSONValue in
            guard let ns = row["ns"].str(), let old = previous[ns] else { return row }
            let oldRev = old["revision"].long() ?? -1
            let newRev = row["revision"].long() ?? -1
            return oldRev > newRev ? old : row
        }
        var object = next.obj() ?? [:]
        object["namespaces"] = .array(namespaces)
        snapshot = .object(object)
        onChange?()
    }

    func write(_ setting: SharedSetting, value: JSONValue, onSaved: @escaping () -> Void = {}) {
        if setting.isPhoneLocalTheme {
            fatalError("phone-local theme \(setting.rawValue) must not mutate Host")
        }
        guard let mutate else {
            error = L.t("远程主机设置尚未连接、不可用或只读，未保存", "Remote host settings are disconnected, unavailable, or read-only; nothing was saved")
            return
        }
        guard writable(setting), let revision = namespace(setting)?["revision"].int() else {
            error = saving
                ? L.t("正在保存，请稍后再试", "Saving; try again shortly")
                : L.t("远程主机设置尚未连接、不可用或只读，未保存", "Remote host settings are disconnected, unavailable, or read-only; nothing was saved")
            return
        }
        saving = true
        error = nil
        Task {
            do {
                let result = try await mutate(setting.namespace, .array([
                    jsonObject([
                        "op": .string("set"),
                        "path": .array([.string(setting.field)]),
                        "value": value,
                    ]),
                ]), revision)
                try requireSettingsSuccess(result)
                refresh()
                onSaved()
            } catch {
                self.error = error.localizedDescription
                refresh()
            }
            saving = false
        }
    }

    /// Screenshot / XCUITest writable Host snapshot. No transport.
    func installUITestFixture(performanceUsage: PerformanceUsage = .compact) {
        online = true
        loading = false
        saving = false
        error = nil
        var fixture = JSONValue.object([
            "writable": .bool(true),
            "namespaces": .array([
                .object([
                    "ns": .string("permission"),
                    "writable": .bool(true),
                    "revision": .number(1),
                    "value": .object(["defaultPreset": .string("workspace-write")]),
                ]),
                .object([
                    "ns": .string("locale"),
                    "writable": .bool(true),
                    "revision": .number(1),
                    "value": .object(["preference": .string("zh")]),
                ]),
                .object([
                    "ns": .string("ui-chat"),
                    "writable": .bool(true),
                    "revision": .number(1),
                    "value": .object([
                        "transcriptView": .string("detailed"),
                        "collapseTiming": .string("completion"),
                        "performanceUsage": .string(performanceUsage.rawValue),
                        "linkOpening": .string("sidebar"),
                    ]),
                ]),
                .object([
                    "ns": .string("ui-settings"),
                    "writable": .bool(true),
                    "revision": .number(1),
                    "value": .object(["enabled": .bool(true)]),
                ]),
                .object([
                    "ns": .string("ui-conversation"),
                    "writable": .bool(true),
                    "revision": .number(1),
                    "value": .object(["busyEnter": .string("queue")]),
                ]),
            ]),
        ])
        snapshot = fixture
        describe = { fixture }
        mutate = { namespace, operations, revision in
            guard var namespaces = fixture["namespaces"].arr(),
                  let index = namespaces.firstIndex(where: { $0["ns"].str() == namespace }),
                  var row = namespaces[index].obj(),
                  row["revision"]?.int() == revision,
                  var value = row["value"]?.obj(),
                  let patches = operations.arr() else {
                throw PocketError(code: "fixture_settings", message: "Unknown settings namespace or revision")
            }
            for patch in patches {
                guard patch["op"].str() == "set", let path = patch["path"].arr(),
                      path.count == 1, let field = path[0].str() else {
                    throw PocketError(code: "fixture_settings", message: "Unsupported settings patch")
                }
                value[field] = patch["value"]
            }
            row["value"] = .object(value)
            row["revision"] = .number(Double(revision + 1))
            namespaces[index] = .object(row)
            fixture = .object(["writable": .bool(true), "namespaces": .array(namespaces)])
            return .object(["ok": .bool(true)])
        }
    }
}
