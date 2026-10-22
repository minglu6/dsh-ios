import DSHProtocol

/// Read-only UI data in Host wire shapes; no client or mutation response is installed.
enum PluginManagerFixture {
    static let bundles: [JSONValue] = [
        .object([
            "name": .string("@deepseek-ai/dsh-experimental-agent-team-profile"),
            "official": .bool(true), "availability": .string("profile"),
            "installed": .bool(true), "optional": .bool(true),
            "removable": .bool(false), "enabled": .bool(true),
            "meta": metadata(title: "智能体团队", description: "让多个智能体协作完成任务。"),
            "rows": .array([
                .object([
                    "rowId": .string("agent-team"),
                    "moduleName": .string("@deepseek-ai/dsh-experimental-agent-team-profile"),
                    "entryId": .string("include:agent-team"),
                    "meta": metadata(title: "团队协作", description: "协调团队任务。"),
                ]),
            ]),
            "overrides": .array([]),
        ]),
        .object([
            "name": .string("@deepseek-ai/dsh-experimental-cot-translation-bundle"),
            "official": .bool(true), "availability": .string("profile"),
            "installed": .bool(true), "optional": .bool(true),
            "removable": .bool(false), "enabled": .bool(false),
            "meta": metadata(title: "思考翻译", description: "翻译模型的思考内容。"),
            "rows": .array([]), "overrides": .array([]),
        ]),
        .object([
            "name": .string("dsh-plugin-example"),
            "official": .bool(false), "availability": .string("profile"),
            "installed": .bool(true), "optional": .bool(false),
            "removable": .bool(true), "enabled": .bool(true),
            "version": .string("1.2.3"),
            "source": .string("dsh-plugin-example@^1.2.0"),
            "meta": metadata(title: "示例插件", description: "用于插件管理界面的隔离测试。"),
            "rows": .array([
                .object([
                    "rowId": .string("example-main"),
                    "moduleName": .string("dsh-plugin-example"),
                    "entryId": .string("include:example-main"),
                    "meta": metadata(title: "示例组件", description: "已加载的可寻址组件。"),
                ]),
                .object([
                    "rowId": .string("example-theme"),
                    "moduleName": .string("dsh-plugin-example/theme"),
                    "meta": metadata(title: "示例主题", description: "未提供 Loader 入口的组件。"),
                ]),
            ]),
            "overrides": .array([]),
        ]),
    ]

    static let plugins: [JSONValue] = [
        .object([
            "entryId": .string("include:agent-team"),
            "moduleName": .string("@deepseek-ai/dsh-experimental-agent-team-profile"),
            "enabled": .bool(true), "fiberPhase": .string("active"),
            "patchId": .string("agent-team"),
        ]),
        .object([
            "entryId": .string("include:example-main"),
            "moduleName": .string("dsh-plugin-example"),
            "enabled": .bool(true), "fiberPhase": .string("active"),
            "patchId": .string("example-main"),
        ]),
    ]

    static let namespaces: [JSONValue] = [
        namespace("subagent", value: [
            "maxDepth": .number(2), "maxActiveSubagents": .number(4),
        ], fields: [("maxDepth", "number"), ("maxActiveSubagents", "number")]),
        namespace("subagent-model-selection-settings", value: [
            "enabled": .bool(false), "allowedModels": .array([]),
        ], schema: .object([
            "uid": .number(1),
            "refs": .object([
                "1": .object(["type": .string("object"), "dict": .object([
                    "enabled": .number(2), "allowedModels": .number(3),
                ])]),
                "2": .object(["type": .string("boolean")]),
                "3": .object(["type": .string("array"), "inner": .number(4)]),
                "4": .object(["type": .string("object"), "dict": .object([
                    "provider": .number(5), "model": .number(5),
                ])]),
                "5": .object(["type": .string("string"), "meta": .object([
                    "min": .number(1), "required": .bool(true),
                ])]),
            ]),
        ])),
        namespace("web-search-deepseek", value: [
            "apiKeyEnv": .string("DEEPSEEK_API_KEY"),
            "baseURL": .string("https://api.deepseek.com"), "maxUses": .number(5),
        ], fields: [("apiKeyEnv", "string"), ("baseURL", "string"), ("maxUses", "number")]),
        namespace("agent-loop", value: [
            "maxParallelToolCalls": .number(10),
        ], fields: [("maxParallelToolCalls", "number")]),
        namespace("bash-sandbox", value: [
            "timeoutMs": .number(120_000), "maxOutputBytes": .number(65_536),
        ], fields: [("timeoutMs", "number"), ("maxOutputBytes", "number")]),
        namespace("example-main", value: [
            "enabled": .bool(true),
        ], fields: [("enabled", "boolean")]),
    ]

    private static func metadata(title: String, description: String) -> JSONValue {
        .object(["title": .string(title), "description": .string(description)])
    }

    private static func namespace(
        _ name: String,
        value: [String: JSONValue],
        fields: [(String, String)] = [],
        schema: JSONValue? = nil
    ) -> JSONValue {
        var properties: [String: JSONValue] = [:]
        var refs: [String: JSONValue] = [:]
        for (index, field) in fields.enumerated() {
            let id = index + 2
            properties[field.0] = .number(Double(id))
            refs[String(id)] = .object(["type": .string(field.1)])
        }
        refs["1"] = .object(["type": .string("object"), "dict": .object(properties)])
        return .object([
            "ns": .string(name), "revision": .number(1),
            "value": .object(value), "user": .object([:]), "base": .object(value),
            "schema": schema ?? .object(["uid": .number(1), "refs": .object(refs)]),
            "secrets": .array([]), "applies": .string("live"), "autoGenerate": .bool(true),
        ])
    }
}
