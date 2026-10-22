#if DEBUG
import Foundation
import SwiftUI
import DSHProtocol

extension AppModel {
    func installUITestModelsSettings() {
        guard uiTestFixture else { return }
        showDrawer = false
        routeStack = []
        uiTestModelsStatus = "connecting"
        let failFirst = ProcessInfo.processInfo.arguments.contains("-UITestModelsFailFirst")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let transport = ModelsSettingsTransport(failFirst: failFirst) { [weak self] status in
                Task { @MainActor in self?.uiTestModelsStatus = status }
            }
            let client = PocketClient()
            do {
                _ = try await client.connect(transport: transport, auth: .token(ModelsSettingsTransport.token))
                self.installUITestModelsClient(client)
                self.ops.formUnion(ModelsSettingsTransport.operations)
                self.uiTestModelsStatus = transport.status
                self.push(.models)
            } catch {
                self.uiTestModelsStatus = "setup-error: \(error.localizedDescription)"
            }
        }
    }
}

struct ModelsSettingsFixtureStatus: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.uiTestFixture && !model.uiTestModelsStatus.isEmpty {
            Text(model.uiTestModelsStatus)
                .font(.system(size: 5))
                .lineLimit(1)
                .allowsHitTesting(false)
                .accessibilityIdentifier("models.fixtureStatus")
                .accessibilityValue(model.uiTestModelsStatus)
        }
    }
}

/// A strict, in-memory Host. All consumer reads and writes traverse PocketClient.
/// Credentials never appear in responses or the accessibility status.
final class ModelsSettingsTransport: FrameTransport, @unchecked Sendable {
    static let token = "synthetic-model-settings"
    static let operations: Set<String> = [
        "models.providers", "models.providerGet", "models.settingsMutate", "models.discover",
        "credentials.describe", "credentials.set", "credentials.unset",
    ]
    let route = Route.wsLocal
    var closeReason: String? { "Models settings fixture closed" }
    private let lock = NSLock()
    private var frames: [String] = []
    private var waiter: CheckedContinuation<String, Error>?
    private var closed = false
    private var authenticated = false
    private var failNextWrite: Bool
    private let report: @Sendable (String) -> Void
    private var revision: Int64 = 1
    private var requests = 0
    private var settingsWrites = 0
    private var credentialWrites = 0
    private var failures = 0
    private var contractErrors = 0
    private var readbacks = 0
    private var lastRead = "none"
    private var credentials: [String: String] = ["ALPHA_API_KEY": "synthetic-alpha", "BETA_API_KEY": "synthetic-beta"]
    private var profiles: [String: JSONValue] = [
        "alpha": ModelsSettingsTransport.profile(name: "Alpha", route: "alpha"),
        "beta": ModelsSettingsTransport.profile(name: "Beta", route: "beta"),
    ]
    private static let catalog = ["openai", "anthropic"]
    private static let protocols = ["openai-completions", "anthropic-messages"]

    init(failFirst: Bool = false, report: @escaping @Sendable (String) -> Void = { _ in }) {
        failNextWrite = failFirst
        self.report = report
    }

    var status: String { lock.withLock { statusLocked() } }

    func send(_ text: String) async throws {
        let request = try JSONValue.parse(text)
        let (reply, status) = lock.withLock { () -> (JSONValue, String) in
            let reply: JSONValue
            do {
                let result = try respond(request)
                reply = .object(["id": request["id"], "ok": .bool(true), "result": result])
            } catch {
                let failure = error as? PocketError
                failures += 1
                if failure?.code == "fixture-contract" { contractErrors += 1 }
                reply = .object([
                    "id": request["id"], "ok": .bool(false),
                    "error": .object(["code": .string(failure?.code ?? "fixture"), "message": .string(failure?.message ?? error.localizedDescription)]),
                ])
            }
            return (reply, statusLocked())
        }
        report(status)
        try enqueue(reply)
    }

    private func respond(_ request: JSONValue) throws -> JSONValue {
        try keys(request, required: ["id", "op", "args"])
        try require(request["id"].long() != nil, "Request id must be numeric")
        let op = request["op"].str() ?? ""
        let args = request["args"]
        if op == "hello" {
            try keys(args, required: ["proto", "token", "app", "appVersion"])
            try require(!authenticated && args["token"].str() == Self.token && args["proto"].int() == 1 && args["app"].str() == "dsh-ios", "Invalid hello")
            authenticated = true
            return .object(["proto": .number(1), "ops": .array(Self.operations.sorted().map(JSONValue.string))])
        }
        try require(authenticated, "Hello required")
        requests += 1
        switch op {
        case "models.providers":
            try keys(args, required: [])
            return .object([
                "rows": .array((profiles.keys.sorted() + Self.catalog.filter { profiles[$0] == nil }).map(row)),
                "namespaces": .array([namespace()]), "protocols": .array(Self.protocols.map(JSONValue.string)),
                "writable": .bool(true),
            ])
        case "models.providerGet":
            try keys(args, required: ["provider"])
            let route = args["provider"].str() ?? ""
            try require(!route.isEmpty, "Provider required")
            guard profiles[route] != nil || Self.catalog.contains(route) else {
                throw PocketError(code: "not-found", message: "unknown provider: \(route)")
            }
            lastRead = route
            if settingsWrites + credentialWrites > 0 { readbacks += 1 }
            return .object([
                "provider": row(route), "namespace": namespace(),
                "inheritedModels": .null, "writable": .bool(true),
                "protocols": .array(Self.protocols.map(JSONValue.string)),
                "catalog": .array(profiles[route] == nil ? [] : profiles[route]?["models"].arr() ?? Self.models(route)),
                "catalogError": .null,
            ])
        case "models.settingsMutate":
            try keys(args, required: ["ns", "ops", "expectedRevision"])
            try require(args["ns"].str() == "llm-pi-ai", "Wrong settings namespace")
            try require(args["expectedRevision"].long() == revision, "Stale or missing revision")
            guard let mutations = args["ops"].arr(), !mutations.isEmpty else { throw contract("Empty mutation") }
            var next = profiles
            for mutation in mutations { try apply(mutation, to: &next) }
            try maybeFail()
            profiles = next
            revision += 1
            settingsWrites += 1
            return namespace()
        case "credentials.set", "credentials.unset", "credentials.describe":
            try keys(args, required: op == "credentials.set" ? ["ref", "value"] : ["ref"])
            let ref = args["ref"].str() ?? ""
            let knownRefs = Set((Array(profiles.keys) + Self.catalog + ["alpha", "beta"]).map(providerKeyRef))
            try require(knownRefs.contains(ref), "Credential reference does not belong to a provider")
            if op == "credentials.describe" { return credential(ref) }
            if op == "credentials.set" {
                try require(args["value"].str()?.isEmpty == false, "Empty credential")
            }
            try maybeFail()
            if op == "credentials.set" { credentials[ref] = args["value"].str() }
            else { credentials.removeValue(forKey: ref) }
            credentialWrites += 1
            return credential(ref)
        case "models.discover":
            try keys(args, required: ["settingsNs", "request"])
            try require(args["settingsNs"].str() == "llm-pi-ai", "Wrong discovery namespace")
            let probe = args["request"]
            try keys(probe, required: [], optional: ["provider", "baseURL", "api", "apiKey"])
            let route = probe["provider"].str()
            if let route { try require(profiles[route] != nil || Self.catalog.contains(route), "Unknown discovery provider") }
            else { try require(probe["baseURL"].str()?.isEmpty == false && Self.protocols.contains(probe["api"].str() ?? ""), "Custom discovery requires endpoint and protocol") }
            for key in probe.obj()?.keys ?? Dictionary<String, JSONValue>().keys {
                try require(probe[key].str() != nil, "Discovery values must be strings")
            }
            return .object(["models": .array(Self.models(route ?? "custom"))])
        default:
            throw contract("Unexpected operation: \(op)")
        }
    }

    private func apply(_ mutation: JSONValue, to profiles: inout [String: JSONValue]) throws {
        let operation = mutation["op"].str() ?? ""
        try keys(mutation, required: operation == "set" ? ["op", "path", "value"] : ["op", "path"])
        try require(operation == "set" || operation == "unset", "Unsupported mutation")
        guard let rawPath = mutation["path"].arr() else { throw contract("Missing path") }
        let path = rawPath.compactMap { $0.str() }
        try require(path.count == rawPath.count && (path.count == 2 || path.count == 3) && path.first == "providers", "Invalid provider path")
        let route = path[1]
        try require(providerRouteFailure(route, taken: []) == nil, "Invalid route")
        if path.count == 2 {
            if operation == "unset" { profiles.removeValue(forKey: route); return }
            try require(profiles[route] == nil && mutation["value"].obj() != nil, "Cannot replace existing provider profile")
            try keys(mutation["value"], required: [], optional: ["displayName", "baseURL", "api", "apiKeyEnv", "models"])
            profiles[route] = mutation["value"]
        } else {
            let field = path[2]
            try require(["displayName", "baseURL", "api", "apiKeyEnv", "models"].contains(field), "Unexpected edited field")
            var value = profiles[route]?.obj() ?? [:]
            if operation == "unset" { value.removeValue(forKey: field) }
            else { value[field] = mutation["value"] }
            profiles[route] = .object(value)
        }
    }

    private func maybeFail() throws {
        if failNextWrite {
            failNextWrite = false
            throw PocketError(code: "fixture-transient", message: "Synthetic models write failure; retry the retained draft")
        }
    }

    private static func profile(name: String, route: String) -> JSONValue {
        .object([
            "displayName": .string(name), "baseURL": .string("https://\(route).example/v1"),
            "api": .string("openai-completions"), "apiKeyEnv": .string(providerKeyRef(route)),
            "models": .array(models(route)), "headers": .object(["X-Fixture-Keep": .string(route)]),
        ])
    }

    private static func models(_ route: String) -> [JSONValue] {
        [.object([
            "id": .string("\(route)-chat"), "name": .string("\(route.capitalized) Chat"),
            "contextWindow": .number(128_000), "maxTokens": .number(8_192),
            "input": .array([.string("text"), .string("image")]), "reasoning": .bool(true),
            "cost": .object(["input": .number(1), "output": .number(2)]),
        ])]
    }

    private func row(_ route: String) -> JSONValue {
        let profile = profiles[route]
        let ref = profile?["apiKeyEnv"].str() ?? providerKeyRef(route)
        return .object([
            "provider": .string(route), "displayName": profile?["displayName"] ?? .string(route.capitalized),
            "settingsNs": .string("llm-pi-ai"), "settingsPath": .array([.string("providers"), .string(route)]),
            "declared": .bool(!Self.catalog.contains(route)), "configured": .bool(profile != nil),
            "active": .bool(profile != nil), "removable": .bool(profile != nil), "editable": .bool(true),
            "profile": profile ?? .null, "apiKeyEnv": profile?["apiKeyEnv"] ?? .null,
            "credential": profile == nil ? .null : credential(ref),
            "derivedCredential": profile == nil ? credential(ref) : .null,
            "defaultBaseURL": .string(route == "anthropic" ? "https://api.anthropic.com" : "https://api.openai.com/v1"),
        ])
    }

    private func credential(_ ref: String) -> JSONValue {
        .object(["ref": .string(ref), "configured": .bool(credentials[ref] != nil), "writable": .bool(true), "source": .string("managed")])
    }

    private func namespace() -> JSONValue {
        .object([
            "ns": .string("llm-pi-ai"), "revision": .number(Double(revision)),
            "user": .object(["providers": .object(profiles)]), "value": .object(["providers": .object(profiles)]),
            "base": .object(["providers": .object([:])]), "schema": Self.schema,
            "secrets": .array([]), "applies": .string("live"), "autoGenerate": .bool(false),
        ])
    }

    private static let schema: JSONValue = .object([
        "uid": .number(1), "refs": .object([
            "1": .object(["type": .string("object"), "dict": .object(["providers": .number(2)])]),
            "2": .object(["type": .string("dict"), "inner": .number(3)]),
            "3": .object(["type": .string("object"), "dict": .object([
                "displayName": .number(4), "baseURL": .number(4), "apiKeyEnv": .number(4),
                "api": .number(5), "models": .number(8),
            ])]),
            "4": .object(["type": .string("string")]),
            "5": .object(["type": .string("union"), "list": .array([.number(6), .number(7)])]),
            "6": .object(["type": .string("literal"), "value": .string("openai-completions")]),
            "7": .object(["type": .string("literal"), "value": .string("anthropic-messages")]),
            "8": .object(["type": .string("array"), "inner": .number(9)]),
            "9": .object(["type": .string("object"), "dict": .object([
                "id": .number(4), "name": .number(4), "contextWindow": .number(10), "maxTokens": .number(10),
            ])]),
            "10": .object(["type": .string("number")]),
        ]),
    ])

    private func statusLocked() -> String {
        let preserved = ["alpha", "beta"].allSatisfy { route in
            profiles[route] == nil || profiles[route]?["headers"]["X-Fixture-Keep"].str() == route
        }
        return "requests=\(requests);settingsWrites=\(settingsWrites);credentialWrites=\(credentialWrites);failures=\(failures);contractErrors=\(contractErrors);revision=\(revision);readbacks=\(readbacks);lastRead=\(lastRead);preserved=\(preserved)"
    }

    private func keys(_ value: JSONValue, required: Set<String>, optional: Set<String> = []) throws {
        guard let object = value.obj() else { throw contract("Expected object") }
        let actual = Set(object.keys)
        try require(required.isSubset(of: actual) && actual.isSubset(of: required.union(optional)), "Unexpected or missing request fields")
    }

    private func require(_ valid: Bool, _ message: String) throws {
        if !valid { throw contract(message) }
    }

    private func contract(_ message: String) -> PocketError { PocketError(code: "fixture-contract", message: message) }

    func ping() async throws {}

    func receive() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if !frames.isEmpty {
                let frame = frames.removeFirst()
                lock.unlock()
                continuation.resume(returning: frame)
            } else if closed {
                lock.unlock()
                continuation.resume(throwing: PocketError(code: "transport", message: closeReason ?? "closed"))
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }

    func close() {
        lock.lock()
        closed = true
        let pending = waiter
        waiter = nil
        lock.unlock()
        pending?.resume(throwing: PocketError(code: "transport", message: closeReason ?? "closed"))
    }

    private func enqueue(_ frame: JSONValue) throws {
        let text = try frame.encodeString()
        lock.lock()
        if let waiter {
            self.waiter = nil
            lock.unlock()
            waiter.resume(returning: text)
        } else {
            frames.append(text)
            lock.unlock()
        }
    }
}
#endif
