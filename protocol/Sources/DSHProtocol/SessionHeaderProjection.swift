import Foundation

public enum AgentTeamMemberPhase: String, Equatable, Sendable {
    case provisioning, active, failed
}

public enum AgentTeamMemberRole: String, Equatable, Sendable {
    case lead, teammate
}

/// Durable roster identity. Activity is supplied separately by Session status, not inferred from phase.
public struct AgentTeamMember: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let role: AgentTeamMemberRole
    public let phase: AgentTeamMemberPhase
    public let error: String?

    fileprivate init?(_ value: JSONValue) {
        guard let id = value["id"].str(), let name = value["name"].str(),
              let role = value["role"].str().flatMap(AgentTeamMemberRole.init(rawValue:)),
              let phase = value["phase"].str().flatMap(AgentTeamMemberPhase.init(rawValue:)),
              headerOptionalStringIsValid(value, "error") else { return nil }
        self.id = id
        self.name = name
        self.role = role
        self.phase = phase
        error = value["error"].str()
    }
}

public enum AgentTeamTaskStatus: String, Equatable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed, deleted
}

/// Official TeamTaskView, including Host-computed readiness and write-scope diagnostics.
public struct AgentTeamTask: Equatable, Sendable, Identifiable {
    public let id: String
    public let revision: Int64
    public let subject: String
    public let description: String
    public let status: AgentTeamTaskStatus
    public let ownerName: String?
    public let blockedBy: [String]
    public let ready: Bool
    public let writeScopes: [String]
    public let writeScopeWarnings: [String]

    fileprivate init?(_ value: JSONValue) {
        guard let id = value["id"].str(),
              let revision = headerInteger(value["revision"]), revision > 0,
              let subject = value["subject"].str(), let description = value["description"].str(),
              let status = value["status"].str().flatMap(AgentTeamTaskStatus.init(rawValue:)),
              headerOptionalStringIsValid(value, "ownerName"),
              let blockedBy = headerArray(value["blockedBy"], parse: { $0.str() }),
              let writeScopes = headerArray(value["writeScopes"], parse: { $0.str() }),
              let ready = value["ready"].bool(),
              let warnings = headerArray(value["writeScopeWarnings"], parse: { $0.str() }) else { return nil }
        self.id = id
        self.revision = revision
        self.subject = subject
        self.description = description
        self.status = status
        ownerName = value["ownerName"].str()
        self.blockedBy = blockedBy
        self.ready = ready
        self.writeScopes = writeScopes
        writeScopeWarnings = warnings
    }
}

/// The Lead Session's agentTeam projection; failure accompanies its last valid members and tasks.
public struct AgentTeamSnapshot: Equatable, Sendable {
    public let members: [AgentTeamMember]
    public let tasks: [AgentTeamTask]
    public let failure: String?

    fileprivate init?(_ value: JSONValue) {
        guard let members = headerArray(value["members"], parse: AgentTeamMember.init),
              let tasks = headerArray(value["tasks"], parse: AgentTeamTask.init),
              headerOptionalStringIsValid(value, "failure") else { return nil }
        self.members = members
        self.tasks = tasks
        failure = value["failure"].str()
    }
}

/// Direct-child catalog membership is not a Team roster and carries no execution status.
public struct SubagentCatalogEntry: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String?
    public let mode: String
    public let createdAt: Int64?

    fileprivate init?(_ value: JSONValue) {
        guard let id = value["id"].str(), let mode = value["mode"].str(),
              ["one-shot", "continuable", "external", "unknown"].contains(mode),
              let createdAt = headerInteger(value["createdAt"]), createdAt >= 0,
              headerOptionalStringIsValid(value, "label"),
              mode != "continuable" || value["label"].str() != nil else { return nil }
        self.id = id
        self.mode = mode
        label = value["label"].str()
        self.createdAt = createdAt
    }
}

/// Per-Session whole-value projection store. Never merge catalog entries into the Team roster.
///
/// Accepts follow snapshot/resume/projection frames and the sessions.projections result block.
/// Sequenced writes use strictly higher-seq-wins independently per key. Cached blocks cannot
/// replace sequenced data; a baseline discards cached rows and clears omitted capabilities.
/// Explicit null means unavailable, not an empty Team/catalog. Malformed values retain the last
/// valid display and expose a diagnostic; their watermark still prevents older data from landing.
/// Create a fresh store when changing Host connection generation, as sequence domains may differ.
public struct SessionHeaderProjection: Equatable, Sendable {
    public private(set) var team: AgentTeamSnapshot?
    public private(set) var subagents: [SubagentCatalogEntry]?
    public private(set) var errors: [String: String] = [:]
    private var sequences: [String: Int64] = [:]
    private var cached: Set<String> = []
    private static let keys = ["agentTeam", "subagentCatalog"]

    public init() {}

    public mutating func apply(frame: JSONValue) {
        if frame.isNull {
            // A null sessions.projections result means unavailable, not a missing follow block.
            for key in Self.keys {
                clear(key)
                errors[key] = "Session projections are unavailable"
            }
            cached.removeAll()
            return
        }
        switch frame["type"].str() {
        case "projection":
            guard let key = frame["key"].str(), Self.keys.contains(key),
                  let seq = headerInteger(frame["seq"]),
                  let value = frame.obj()?["value"] else { return }
            apply(key: key, value: value, seq: seq)
        case "snapshot", "resume":
            baseline(frame["projections"], fallbackSeq: headerInteger(frame["cursor"]))
        default:
            // sessions.projections returns the official projection block without a follow wrapper.
            guard frame["type"].isNull else { return }
            baseline(frame, fallbackSeq: nil)
        }
    }

    private mutating func baseline(_ block: JSONValue, fallbackSeq: Int64?) {
        if block["kind"].str() == "migration-required" {
            // This checkpoint has no comparable sequence; never replace live data with it.
            for key in Self.keys {
                errors[key] = "Session projections require Host migration"
            }
            return
        }
        guard let values = block["values"].obj() else { return }
        if block["kind"].str() == "cached" {
            for key in Self.keys where sequences[key] == nil {
                guard let value = values[key] else { continue }
                cached.insert(key)
                read(key: key, value: value)
            }
            return
        }
        guard let seq = headerInteger(block["asOfSeq"]) ?? fallbackSeq else { return }
        for key in cached {
            clear(key)
        }
        cached.removeAll()
        for key in Self.keys {
            if let value = values[key] {
                apply(key: key, value: value, seq: seq)
            } else if sequences[key].map({ $0 <= seq }) ?? true {
                // Keep an absence watermark so late frames cannot resurrect this capability.
                sequences[key] = seq
                clear(key)
            }
        }
    }

    private mutating func apply(key: String, value: JSONValue, seq: Int64) {
        if let previous = sequences[key], seq <= previous { return }
        sequences[key] = seq
        cached.remove(key)
        read(key: key, value: value)
    }

    private mutating func read(key: String, value: JSONValue) {
        if value.isNull {
            clear(key)
            return
        }
        switch key {
        case "agentTeam":
            guard let next = AgentTeamSnapshot(value) else {
                errors[key] = "Invalid agentTeam projection"
                return
            }
            team = next
        case "subagentCatalog":
            guard let next = headerArray(value, parse: SubagentCatalogEntry.init) else {
                errors[key] = "Invalid subagentCatalog projection"
                return
            }
            subagents = next
        default: return
        }
        errors.removeValue(forKey: key)
    }

    private mutating func clear(_ key: String) {
        switch key {
        case "agentTeam": team = nil
        case "subagentCatalog": subagents = nil
        default: return
        }
        errors.removeValue(forKey: key)
    }
}

private func headerOptionalStringIsValid(_ value: JSONValue, _ key: String) -> Bool {
    guard let field = value.obj()?[key] else { return true }
    return field.str() != nil
}

/// Wire integers are JSON numbers within JavaScript's safe integer range, never numeric strings.
private func headerInteger(_ value: JSONValue) -> Int64? {
    guard let number = value.double(), number.isFinite, number.rounded() == number,
          abs(number) <= 9_007_199_254_740_991 else { return nil }
    return Int64(number)
}

private func headerArray<Element>(_ value: JSONValue, parse: (JSONValue) -> Element?) -> [Element]? {
    guard let array = value.arr() else { return nil }
    var result: [Element] = []
    result.reserveCapacity(array.count)
    for item in array {
        guard let parsed = parse(item) else { return nil }
        result.append(parsed)
    }
    return result
}
