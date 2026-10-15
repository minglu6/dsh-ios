import Foundation

public struct QoderConnectionFields: Equatable, Sendable {
    public var vpcInstance: String
    public var baseURL: String
    public var openApiUrl: String

    public init(vpcInstance: String, baseURL: String, openApiUrl: String) {
        self.vpcInstance = vpcInstance
        self.baseURL = baseURL
        self.openApiUrl = openApiUrl
    }
}

public struct QoderConnectionDraft: Equatable, Sendable {
    public var fields: QoderConnectionFields
    public var original: QoderConnectionFields
    public var ref: String
    public var path: [String]
    public var revision: Int64
    public var pat: String

    public init(
        fields: QoderConnectionFields,
        original: QoderConnectionFields,
        ref: String,
        path: [String],
        revision: Int64,
        pat: String = ""
    ) {
        self.fields = fields
        self.original = original
        self.ref = ref
        self.path = path
        self.revision = revision
        self.pat = pat
    }
}

public enum QoderConnectionError: Equatable, Sendable {
    case readOnly, credentialReadOnly, loadFailed, credentialFailed, settingsFailed, conflict
}

public struct QoderConnectionSave: Equatable, Sendable {
    public var draft: QoderConnectionDraft
    public var error: QoderConnectionError?
    public var settingsSaved: Bool

    public init(draft: QoderConnectionDraft, error: QoderConnectionError? = nil, settingsSaved: Bool = false) {
        self.draft = draft
        self.error = error
        self.settingsSaved = settingsSaved
    }
}

/// Same profile-over-root resolution as the installed Qoder Models footer. Never reads a PAT.
public func qoderConnectionDraft(_ config: JSONValue?, revision: Int64) -> QoderConnectionDraft {
    let profile = config?["providers"]["qoder-cn"]
    let profileObject = profile?.obj()
    func value(_ field: String) -> String {
        profile?[field].str() ?? config?[field].str() ?? ""
    }
    let fields = QoderConnectionFields(
        vpcInstance: value("vpcInstance"),
        baseURL: value("baseURL"),
        openApiUrl: value("openApiUrl")
    )
    return QoderConnectionDraft(
        fields: fields,
        original: fields,
        ref: profile?["apiKeyEnv"].str() ?? config?["apiKeyEnv"].str() ?? "QODERCN_PERSONAL_ACCESS_TOKEN",
        path: profileObject == nil ? [] : ["providers", "qoder-cn"],
        revision: revision
    )
}

public func qoderConnectionOperations(_ draft: QoderConnectionDraft) -> JSONValue {
    let fields = [
        ("vpcInstance", draft.fields.vpcInstance, draft.original.vpcInstance),
        ("baseURL", draft.fields.baseURL, draft.original.baseURL),
        ("openApiUrl", draft.fields.openApiUrl, draft.original.openApiUrl),
    ]
    let ops: [JSONValue] = fields.compactMap { field, value, original in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != original else { return nil }
        return jsonObject([
            "op": .string("set"),
            "path": .array((draft.path + [field]).map { .string($0) }),
            "value": .string(trimmed),
        ])
    }
    return .array(ops)
}

/// Fence even PAT-only writes; a partial save adopts the committed revision before retry.
public func saveQoderConnection(
    _ draft: QoderConnectionDraft,
    writable: Bool,
    describe: (String) async throws -> JSONValue,
    mutate: (JSONValue, Int64) async throws -> JSONValue,
    store: (String, String) async throws -> JSONValue
) async throws -> QoderConnectionSave {
    var retained = draft
    var settingsSaved = false
    func failure(_ error: QoderConnectionError) -> QoderConnectionSave {
        QoderConnectionSave(draft: retained, error: error, settingsSaved: settingsSaved)
    }
    if !writable { return failure(.readOnly) }
    let pat = draft.pat.trimmingCharacters(in: .whitespacesAndNewlines)
    if !pat.isEmpty {
        do {
            let info = try await describe(draft.ref)
            if info["writable"].bool() == nil { return failure(.loadFailed) }
            if info["writable"].bool() != true { return failure(.credentialReadOnly) }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return failure(.loadFailed)
        }
    }
    do {
        let ops = qoderConnectionOperations(draft)
        let written = try await mutate(ops, draft.revision)
        if written["ok"].bool() == false {
            return failure(written["error"]["code"].str() == "settings/conflict" ? .conflict : .settingsFailed)
        }
        guard let revision = written["revision"].long() else { return failure(.settingsFailed) }
        guard written["value"].obj() != nil else { return failure(.settingsFailed) }
        if case .array(let items) = ops, !items.isEmpty { settingsSaved = true }
        retained = qoderConnectionDraft(written["value"], revision: revision)
        retained.pat = draft.pat
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        let conflict = (error as? PocketError)?.code == "settings/conflict"
        return failure(conflict ? .conflict : .settingsFailed)
    }
    if !pat.isEmpty {
        do {
            let info = try await store(retained.ref, pat)
            if info["configured"].bool() != true || info["ref"].str() != retained.ref {
                return failure(.credentialFailed)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return failure(.credentialFailed)
        }
    }
    retained.pat = ""
    return QoderConnectionSave(draft: retained, settingsSaved: settingsSaved)
}
