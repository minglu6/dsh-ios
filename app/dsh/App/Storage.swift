import Foundation
import Security
import DSHProtocol

struct Profile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var deviceId: String?
    var host: String
    var port: Int
    var instanceId: String
    var lastUsedAt: Int64

    var needsRepair: Bool { host.isEmpty || !(1...65535).contains(port) }
    var routeKind: Route? { needsRepair ? nil : classifyWsRoute(host) }

    var kind: String {
        if needsRepair { return L.repairNeeded() }
        switch routeKind {
        case .wsTailscale: return Route.wsTailscale.label
        case .wsLan: return Route.wsLan.label
        case .wsLocal: return Route.wsLocal.label
        case nil: return L.repairNeeded()
        }
    }
}

func clipProfileName(_ name: String) throws -> String {
    let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
    if trimmed.isEmpty { throw PocketError(code: "bad-request", message: "profile name required") }
    return trimmed
}

enum TokenStore {
    private static let service = "dev.dsh.pocket.ios.tokens"

    static func put(profileId: String, token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileId,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PocketError(code: "storage", message: "failed to store token (\(status))")
        }
    }

    static func get(profileId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(profileId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileId,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum ProfileStore {
    private static let key = "dsh.profiles"
    private static let activeKey = "dsh.activeProfile"

    static func load() -> [Profile] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Profile].self, from: data)) ?? []
    }

    static func save(_ profiles: [Profile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static var activeId: String? {
        get { UserDefaults.standard.string(forKey: activeKey) }
        set { UserDefaults.standard.set(newValue, forKey: activeKey) }
    }
}

enum AppPrefs {
    static var language: AppLanguage {
        get { AppLanguage(rawValue: UserDefaults.standard.string(forKey: "dsh.language") ?? "") ?? .zh }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "dsh.language") }
    }

    static var appearance: Appearance {
        get { Appearance(rawValue: UserDefaults.standard.string(forKey: "dsh.appearance") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "dsh.appearance") }
    }

    static var busySend: BusySend {
        get { BusySend(rawValue: UserDefaults.standard.string(forKey: "dsh.busySend") ?? "") ?? .queue }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "dsh.busySend") }
    }

    static var sessionGroupBy: SessionGroupBy {
        get { SessionGroupBy(rawValue: UserDefaults.standard.string(forKey: "dsh.sessionGroupBy") ?? "") ?? .workspace }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "dsh.sessionGroupBy") }
    }

    static var sessionOrderBy: SessionOrderBy {
        get { SessionOrderBy(rawValue: UserDefaults.standard.string(forKey: "dsh.sessionOrderBy") ?? "") ?? .updated }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "dsh.sessionOrderBy") }
    }

    static var archivedFilter: ArchivedFilter {
        get { ArchivedFilter(rawValue: UserDefaults.standard.string(forKey: "dsh.archivedFilter") ?? "") ?? .hide }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "dsh.archivedFilter") }
    }

    static func collapsedWorkspaces(hostId: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "dsh.collapsedWorkspaces:\(hostId)") ?? [])
    }

    static func setCollapsedWorkspaces(hostId: String, value: Set<String>) {
        UserDefaults.standard.set(Array(value), forKey: "dsh.collapsedWorkspaces:\(hostId)")
    }
}

enum TerminalStore {
    private static func key(_ hostId: String) -> String { "dsh.terminalOwners:\(hostId)" }
    private static func panelPrefix(_ hostId: String) -> String { "dsh.terminalPanelOwner:\(hostId.count):\(hostId):" }

    private static func owners(_ hostId: String) -> [SavedTerminalOwner] {
        guard let data = UserDefaults.standard.data(forKey: key(hostId)) else { return [] }
        return (try? JSONDecoder().decode([SavedTerminalOwner].self, from: data)) ?? []
    }

    private static func save(_ hostId: String, _ owners: [SavedTerminalOwner]) {
        if let data = try? JSONEncoder().encode(owners) {
            UserDefaults.standard.set(data, forKey: key(hostId))
        }
    }

    static func ownerIds(_ hostId: String) -> [String] {
        owners(hostId).map(\.sessionId)
    }

    static func selectedId(hostId: String, sessionId: String) -> String? {
        owners(hostId).first { $0.sessionId == sessionId }?.selectedId
    }

    static func discover(hostId: String, sessionId: String, terminalId: String) {
        save(hostId, TerminalIdentityStore.record(owners: owners(hostId), sessionId: sessionId, terminalId: terminalId, selected: false))
    }

    static func remember(hostId: String, sessionId: String, terminalId: String) {
        save(hostId, TerminalIdentityStore.record(owners: owners(hostId), sessionId: sessionId, terminalId: terminalId, selected: true))
    }

    static func reconcile(hostId: String, sessionId: String, ids: [String]) {
        let next = TerminalIdentityStore.reconcile(owners: owners(hostId), sessionId: sessionId, ids: ids)
        save(hostId, next)
        if ids.isEmpty {
            let prefix = panelPrefix(hostId)
            let defaults = UserDefaults.standard
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) && defaults.string(forKey: key) == sessionId {
                defaults.removeObject(forKey: key)
            }
        }
    }

    static func forget(hostId: String, sessionId: String, terminalId: String) {
        save(hostId, TerminalIdentityStore.forget(owners: owners(hostId), sessionId: sessionId, terminalId: terminalId))
    }

    static func panelOwner(hostId: String, contextSessionId: String) -> String? {
        UserDefaults.standard.string(forKey: panelPrefix(hostId) + contextSessionId)
    }

    static func setPanelOwner(hostId: String, contextSessionId: String, ownerSessionId: String?) {
        UserDefaults.standard.set(ownerSessionId, forKey: panelPrefix(hostId) + contextSessionId)
    }
}
