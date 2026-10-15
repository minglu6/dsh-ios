import Foundation

public struct PocketError: Error, LocalizedError, Equatable {
    public let code: String
    public let message: String
    public let details: JSONValue?

    public init(code: String, message: String, details: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }

    public var errorDescription: String? {
        message.isEmpty ? code : "\(code): \(message)"
    }
}

public enum Auth: Sendable {
    case token(String)
    case pair(code: String, deviceName: String)
}

public struct HelloResult: Sendable {
    public let raw: JSONValue
    public let route: Route?

    public init(raw: JSONValue, route: Route? = nil) {
        self.raw = raw
        self.route = route
    }

    public var ops: Set<String> {
        Set((raw["ops"].arr() ?? []).compactMap { $0.str() })
    }

    public var deviceId: String? {
        raw["deviceId"].str() ?? raw["device"]["id"].str()
    }

    public var issuedToken: String? {
        raw["token"].str()
    }

    public var proto: Int? { raw["proto"].int() }
    public var pluginVersion: String? { raw["version"].str() }
    public var minimumAppVersion: String? { raw["minimumAppVersion"].str() }
    public var instanceId: String? { raw["instanceId"].str() }
    public var hostName: String? { raw["host"].str() }

    public func handshakeVersions() -> HandshakeVersions? {
        guard let proto else { return nil }
        return HandshakeVersions(
            proto: proto,
            pluginVersion: pluginVersion ?? "0.0.0",
            minimumAppVersion: minimumAppVersion ?? VersionCompatibility.minimumAppVersion
        )
    }
}

public struct SessionSummary: Sendable, Equatable, Identifiable {
    public var sessionId: String
    public var title: String?
    public var cwd: String?
    public var running: Bool
    public var blank: Bool
    public var updatedAt: Int64
    public var parentSessionId: String?
    public var archived: Bool?
    public var pinned: Bool?
    public var origin: String?
    public var searchSnippet: String?

    public var id: String { sessionId }

    public init(
        sessionId: String,
        title: String? = nil,
        cwd: String? = nil,
        running: Bool = false,
        blank: Bool = false,
        updatedAt: Int64 = 0,
        parentSessionId: String? = nil,
        archived: Bool? = nil,
        pinned: Bool? = nil,
        origin: String? = nil,
        searchSnippet: String? = nil
    ) {
        self.sessionId = sessionId
        self.title = title
        self.cwd = cwd
        self.running = running
        self.blank = blank
        self.updatedAt = updatedAt
        self.parentSessionId = parentSessionId
        self.archived = archived
        self.pinned = pinned
        self.origin = origin
        self.searchSnippet = searchSnippet
    }

    public static func parse(_ element: JSONValue) -> SessionSummary? {
        guard let id = element["sessionId"].str() else { return nil }
        return SessionSummary(
            sessionId: id,
            title: element["projections"]["values"]["title"].str() ?? element["title"].str(),
            cwd: element["cwd"].str(),
            running: element["running"].bool() ?? false,
            blank: element["blank"].bool() ?? false,
            updatedAt: element["updatedAt"].long() ?? 0,
            parentSessionId: element["parentSessionId"].str(),
            archived: element["archived"].bool(),
            pinned: element["pinned"].bool(),
            origin: element["origin"].str(),
            searchSnippet: element["snippet"].str()
        )
    }
}

public struct WorkspaceView: Sendable, Equatable, Identifiable {
    public var workspaceId: String
    public var path: String
    public var title: String
    public var sessionIds: [String]
    public var createdAt: String?
    public var updatedAt: String?

    public var id: String { workspaceId }

    public init(
        workspaceId: String,
        path: String,
        title: String,
        sessionIds: [String],
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.workspaceId = workspaceId
        self.path = path
        self.title = title
        self.sessionIds = sessionIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func parse(_ element: JSONValue) -> WorkspaceView? {
        guard let id = element["workspaceId"].str(), let path = element["path"].str() else { return nil }
        return WorkspaceView(
            workspaceId: id,
            path: path,
            title: element["title"].str() ?? "",
            sessionIds: (element["sessionIds"].arr() ?? []).compactMap { $0.str() },
            createdAt: element["createdAt"].str(),
            updatedAt: element["updatedAt"].str()
        )
    }
}

public struct ReasoningLevel: Sendable, Equatable {
    public var id: String
    public var name: String
    public var description: String?
}

public struct ModelInfo: Sendable, Equatable, Identifiable {
    public var provider: String
    public var id: String
    public var name: String
    public var description: String?
    public var efforts: [ReasoningLevel]
    public var defaultEffort: String?
    public var hasReasoning: Bool
}

public struct ModelGroup: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var models: [ModelInfo]
}

public struct ModelCatalogFailure: Sendable, Equatable {
    public var id: String
    public var name: String
    public var message: String
}

public struct ModelCatalog: Sendable, Equatable {
    public var groups: [ModelGroup]
    public var defaultProvider: String?
    public var defaultModel: String?
    public var failures: [ModelCatalogFailure]
    public var defaultEffort: String?

    public func find(provider: String?, model: String?) -> ModelInfo? {
        groups.flatMap(\.models).first { $0.provider == provider && $0.id == model }
    }

    public static func parse(_ element: JSONValue) -> ModelCatalog {
        let groups = (element["groups"].arr() ?? []).map { group -> ModelGroup in
            let gid = group["id"].str() ?? ""
            let models = (group["models"].arr() ?? []).map { model -> ModelInfo in
                let reasoning = model["reasoning"]
                let efforts = (reasoning["efforts"].arr() ?? []).map { row in
                    ReasoningLevel(
                        id: row["id"].str() ?? "",
                        name: row["name"].str() ?? row["id"].str() ?? "",
                        description: row["description"].str()
                    )
                }
                return ModelInfo(
                    provider: gid,
                    id: model["id"].str() ?? "",
                    name: model["name"].str() ?? model["id"].str() ?? "",
                    description: model["description"].str(),
                    efforts: efforts,
                    defaultEffort: reasoning["defaultEffort"].str(),
                    hasReasoning: reasoning.obj() != nil
                )
            }
            return ModelGroup(id: gid, name: group["name"].str() ?? gid, models: models)
        }
        return ModelCatalog(
            groups: groups,
            defaultProvider: element["default"]["provider"].str(),
            defaultModel: element["default"]["model"].str(),
            failures: (element["failures"].arr() ?? []).map { failure in
                let id = failure["id"].str() ?? ""
                return ModelCatalogFailure(
                    id: id,
                    name: failure["name"].str() ?? id,
                    message: failure["message"].str() ?? ""
                )
            },
            defaultEffort: element["default"]["reasoningEffort"].str()
        )
    }
}

public struct Approval: Sendable, Equatable, Identifiable {
    public var approvalId: String
    public var sessionId: String?
    public var toolName: String
    public var callId: String?
    public var reason: String?

    public var id: String { approvalId }

    public static func parse(_ element: JSONValue) -> Approval {
        Approval(
            approvalId: element["approvalId"].str() ?? "",
            sessionId: element["sessionId"].str(),
            toolName: element["toolName"].str() ?? "",
            callId: element["callId"].str(),
            reason: element["displayReason"]["zh"].str()
                ?? element["reason"].str()
                ?? element["displayReason"]["en"].str()
        )
    }
}

public struct PromptImage: Sendable {
    public var mediaType: String
    public var data: String
    public var name: String?
    public init(mediaType: String, data: String, name: String? = nil) {
        self.mediaType = mediaType
        self.data = data
        self.name = name
    }
}

public struct PromptFile: Sendable {
    public var receiptId: String
    public init(receiptId: String) { self.receiptId = receiptId }
}

/// One message-feedback rating from `feedback.get`.
public struct MessageFeedback: Sendable, Equatable {
    public var messageId: String
    public var rating: String?
    public var version: String?
    public var category: String?
    public var note: String?

    public init(messageId: String, rating: String? = nil, version: String? = nil, category: String? = nil, note: String? = nil) {
        self.messageId = messageId
        self.rating = rating
        self.version = version
        self.category = category
        self.note = note
    }

    public static func parse(_ element: JSONValue) -> MessageFeedback? {
        guard let id = element["messageId"].str() else { return nil }
        return MessageFeedback(
            messageId: id,
            rating: element["rating"].str(),
            version: element["version"].str(),
            category: element["category"].str(),
            note: element["note"].str()
        )
    }
}

public struct UserQuestionOption: Sendable, Equatable {
    public var label: String
    public var description: String?
}

public struct UserQuestionItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var question: String
    public var detail: String?
    public var header: String?
    public var options: [UserQuestionOption]
    public var multiSelect: Bool
    public var intentKind: String?
    public var approveLabel: String?

    public static func parse(_ element: JSONValue) -> UserQuestionItem? {
        guard let id = element["id"].str(), let question = element["question"].str() else { return nil }
        let intent = element["intent"]
        return UserQuestionItem(
            id: id,
            question: question,
            detail: element["detail"].str(),
            header: element["header"].str(),
            options: (element["options"].arr() ?? []).compactMap { option in
                guard let label = option["label"].str() else { return nil }
                return UserQuestionOption(label: label, description: option["description"].str())
            },
            multiSelect: element["multiSelect"].bool() == true,
            intentKind: intent["kind"].str(),
            approveLabel: intent["approve"].str()
        )
    }
}

public struct UserQuestion: Sendable, Equatable, Identifiable {
    public var questionId: String
    public var sessionId: String?
    public var callId: String?
    public var questions: [UserQuestionItem]
    public var state: String?

    public var id: String { questionId }

    public static func parse(_ element: JSONValue) -> UserQuestion? {
        let questionId = element["questionId"].str() ?? element["callId"].str()
        let questions = (element["questions"].arr() ?? []).compactMap(UserQuestionItem.parse)
        guard let questionId, !questions.isEmpty else { return nil }
        return UserQuestion(
            questionId: questionId,
            sessionId: element["sessionId"].str(),
            callId: element["callId"].str() ?? questionId,
            questions: questions,
            state: element["wait"].isNull ? element["state"].str() : "open"
        )
    }
}

public struct FileReference: Sendable, Equatable, Identifiable {
    public var path: String
    public var kind: String?
    public var id: String { path }

    public static func parse(_ element: JSONValue) -> FileReference? {
        guard let path = element["path"].str() ?? element["mention"].str() else { return nil }
        return FileReference(path: path, kind: element["kind"].str())
    }
}

public struct SessionReference: Sendable, Equatable, Identifiable {
    public var mention: String
    public var title: String?
    public var kind: String?
    public var sessionId: String?
    public var updatedAt: Int64?
    public var createdAt: Int64?
    public var cwd: String?
    public var sameWorkspace: Bool?

    public var id: String { mention }

    public static func parse(_ element: JSONValue) -> SessionReference? {
        guard let mention = element["mention"].str() else { return nil }
        return SessionReference(
            mention: mention,
            title: element["displayTitle"].str() ?? element["title"].str() ?? element["label"].str(),
            kind: element["kind"].str(),
            sessionId: element["sessionId"].str(),
            updatedAt: element["updatedAt"].long(),
            createdAt: element["createdAt"].long(),
            cwd: element["cwd"].str(),
            sameWorkspace: element["sameWorkspace"].bool()
        )
    }
}

public struct PairingLink: Sendable, Equatable {
    public var host: String
    public var port: Int
    public var code: String

    public init(host: String, port: Int, code: String) {
        self.host = host
        self.port = port
        self.code = code
    }
}

public struct DiscoveredHost: Sendable, Equatable, Identifiable {
    public var instanceId: String
    public var host: String
    public var port: Int
    public var deviceName: String

    public var id: String { instanceId.isEmpty ? "\(host):\(port)" : instanceId }

    public init(instanceId: String, host: String, port: Int, deviceName: String) {
        self.instanceId = instanceId
        self.host = host
        self.port = port
        self.deviceName = deviceName
    }
}

public func parseHostPort(_ raw: String) -> (String, Int)? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.hasPrefix("ws://") { text.removeFirst(5) }
    if text.hasPrefix("wss://") { text.removeFirst(6) }
    guard let match = text.range(of: #"^\[?([^\[\]]+?)\]?:(\d{1,5})$"#, options: .regularExpression) else {
        return nil
    }
    let matched = String(text[match])
    guard let colon = matched.lastIndex(of: ":") else { return nil }
    var host = String(matched[..<colon])
    if host.hasPrefix("[") && host.hasSuffix("]") {
        host.removeFirst()
        host.removeLast()
    }
    guard let port = Int(matched[matched.index(after: colon)...]), (1...65535).contains(port), !host.isEmpty else {
        return nil
    }
    return (host, port)
}
