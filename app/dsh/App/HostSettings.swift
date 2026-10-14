import Foundation
import DSHProtocol

enum SharedSetting: String {
    case appearance, fontSize, language, busySend, codeWork

    var namespace: String {
        switch self {
        case .appearance, .fontSize: return "ui-theme"
        case .language: return "locale"
        case .busySend: return "ui-conversation"
        case .codeWork: return "ui-settings"
        }
    }

    var field: String {
        switch self {
        case .appearance: return "preference"
        case .fontSize: return "fontSize"
        case .language: return "preference"
        case .busySend: return "busyEnter"
        case .codeWork: return "enabled"
        }
    }
}

/// Live Host settings mirror. Never a persisted mobile copy.
@MainActor
final class HostSettings: ObservableObject {
    @Published private(set) var snapshot: JSONValue?
    @Published private(set) var online = false
    @Published private(set) var loading = false
    @Published var error: String?

    private var describe: (() async throws -> JSONValue)?
    private var mutate: ((String, JSONValue, Int) async throws -> JSONValue)?
    private var generation = 0

    var ready: Bool { online && snapshot != nil }

    func bind(describe: @escaping () async throws -> JSONValue, mutate: @escaping (String, JSONValue, Int) async throws -> JSONValue) {
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
        error = nil
    }

    func namespace(_ setting: SharedSetting) -> JSONValue? {
        snapshot?["namespaces"].arr()?.first { $0["ns"].str() == setting.namespace }
    }

    func value(_ setting: SharedSetting) -> JSONValue? {
        namespace(setting)?["value"][setting.field]
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
    }

    func write(_ setting: SharedSetting, value: JSONValue) {
        guard let mutate, let row = namespace(setting), let revision = row["revision"].int() else { return }
        Task {
            do {
                _ = try await mutate(setting.namespace, .array([
                    jsonObject([
                        "op": .string("set"),
                        "path": .array([.string(setting.field)]),
                        "value": value,
                    ]),
                ]), revision)
                refresh()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
