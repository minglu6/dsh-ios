import Foundation

/// Official agent-preset registry fold. Port of Android `isBuiltInPreset` / `presetName`.
public enum PresetPolicy {
    public static let builtInIds: Set<String> = ["standard", "ptc", "minimal", "cordis"]
    public static let codingPresetIds: Set<String> = ["ptc", "minimal"]
    public static let registryNamespace = "agent-preset-registry"

    /// The desktop registry's display fold, not a guess based on the id alone.
    public static func isBuiltIn(_ row: JSONValue) -> Bool {
        row["name"].str() == nil && builtInIds.contains(row["id"].str() ?? "")
    }

    public static func requiresCodingTools(_ row: JSONValue) -> Bool {
        isBuiltIn(row) && codingPresetIds.contains(row["id"].str() ?? "")
    }

    public static func guideAvailable(_ id: String) -> Bool {
        builtInIds.contains(id)
    }

    public static func name(_ row: JSONValue, english: Bool) -> String {
        if let explicit = row["name"].str() { return explicit }
        switch row["id"].str() {
        case "standard": return english ? "Standard mode" : "标准模式"
        case "ptc": return english ? "PTC mode" : "PTC 模式"
        case "minimal": return english ? "Minimal mode" : "极简模式"
        case "cordis": return english ? "Creator mode" : "创造模式"
        default: return row["id"].str() ?? ""
        }
    }

    public static func description(_ row: JSONValue, english: Bool) -> String? {
        if row["name"].str() != nil { return row["description"].str() }
        switch row["id"].str() {
        case "standard":
            return english
                ? "Work with code, files, and information. Suitable for most tasks, with search, editing, terminal commands, and other tools available as needed."
                : "处理代码、文件和资料，适合大多数任务。Agent 会按需使用检索、编辑和终端等工具。"
        case "ptc":
            return english
                ? "Includes all Standard mode capabilities. Better suited to tasks that call tools in batches and then filter, organize, deduplicate, count, or summarize the results."
                : "包含标准模式的所有能力，更适合批量调用工具，并对结果进行筛选、整理、去重、统计或汇总的任务。"
        case "minimal":
            return english
                ? "The agent works using only a terminal tool. Useful for testing and comparing its basic performance."
                : "Agent 仅使用终端工具完成任务，适合测试和对比其基础表现。"
        case "cordis":
            return english
                ? "Customize DSH through conversation. Let the agent write plugins that add features or UI, or combine tools and prompts to create your own mode."
                : "用对话定制 DSH：让 Agent 编写插件，添加新功能或界面；也能组合工具和提示词，创建自己的模式。"
        default:
            return row["description"].str()
        }
    }

    public static func defaultMutation(id: String) -> JSONValue {
        .array([
            jsonObject([
                "op": .string("set"),
                "path": .array([.string("selectedDefault")]),
                "value": .string(id),
            ]),
        ])
    }

    public static func visibleRows(_ rows: [JSONValue], codingTools: Bool) -> [JSONValue] {
        rows.filter { codingTools || !requiresCodingTools($0) }
    }

    public static func canLoad(online: Bool, ops: Set<String>) -> Bool {
        online && (ops.contains("presets.settings") || ops.contains("presets.list"))
    }

    public static func hostWritable(data: JSONValue, ops: Set<String>) -> Bool {
        data["writable"].bool() == true
            && data["namespace"]["revision"].long() != nil
            && ops.contains("models.settingsMutate")
    }

    public static func canCreateWithCreator(_ rows: [JSONValue], ops: Set<String>, online: Bool) -> Bool {
        online
            && ops.contains("sessions.create")
            && rows.contains { $0["id"].str() == "cordis" && $0["broken"].str() == nil }
    }

    public static func parseRoster(_ result: JSONValue) -> [JSONValue] {
        result["presets"].arr() ?? []
    }

    /// Desktop/Android: the current default card is not rewritten on tap.
    public static func canSelectAsDefault(_ row: JSONValue) -> Bool {
        row["broken"].str() == nil && row["isDefault"].bool() != true
    }

    public static func presetName(id: String?, roster: [JSONValue], english: Bool) -> String? {
        guard let id = nonblank(id) else { return nil }
        let row = roster.first { $0["id"].str() == id } ?? jsonObject(["id": .string(id)])
        return PresetPolicy.name(row, english: english)
    }

    public static func draftPresetId(pending: String?, draft: String, roster: [JSONValue]) -> String? {
        nonblank(pending) ?? nonblank(draft)
            ?? roster.first { $0["isDefault"].bool() == true }.flatMap { nonblank($0["id"].str()) }
    }

    private static func nonblank(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

public enum WorkspaceOrder {
    public static func insertBeforeArgs(workspaceId: String, beforeWorkspaceId: String?) -> JSONValue {
        jsonObject([
            "workspaceId": .string(workspaceId),
            "beforeWorkspaceId": beforeWorkspaceId.map { .string($0) },
        ])
    }

    public static func insertSessionBeforeArgs(
        workspaceId: String,
        sessionId: String,
        beforeSessionId: String?
    ) -> JSONValue {
        jsonObject([
            "workspaceId": .string(workspaceId),
            "sessionId": .string(sessionId),
            "beforeSessionId": beforeSessionId.map { .string($0) },
        ])
    }
}
