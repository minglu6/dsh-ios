import Foundation

public enum ToolProcessIcon: String, Sendable, Equatable {
    case browse, search, command, write, edit, code, generic, users, checklist, clock, goal, plugin, agent, branch
}

public struct ToolProcessSummary: Equatable, Sendable {
    public var title: String
    public var summary: String?
    public var icon: ToolProcessIcon

    public init(title: String, summary: String?, icon: ToolProcessIcon) {
        self.title = title
        self.summary = summary
        self.icon = icon
    }
}

/// Official ui-tool title registry; unknown tools keep their wire name in the generic summary.
private let toolTitles: [String: (zh: String, en: String)] = [
    "bash": ("运行命令", "Bash"), "pwsh": ("运行命令", "PowerShell"),
    "read": ("读取", "Read"), "read_image": ("读取图片", "Read image"),
    "web_fetch": ("读取", "Read"), "web_search": ("搜索", "Search"),
    "grep": ("搜索", "Search"), "glob": ("搜索", "Search"),
    "write": ("写入", "Write"), "edit": ("编辑", "Edit"), "run_code": ("代码", "Code"),
    "cordis_package_inspect": ("查询 Cordis 环境", "Query Cordis environment"),
    "cordis_runtime_inspect": ("查询 Cordis 环境", "Query Cordis environment"),
    "cordis_run": ("运行 Cordis 插件", "Run Cordis Plugin"),
    "cordis_stop": ("停止 Cordis 插件", "Stop Cordis Plugin"),
    "cordis_undefine": ("移除 Cordis 插件", "Remove Cordis Plugin"),
    "todo_write": ("更新任务清单", "Update todo list"),
    "ask_user_question": ("提问", "Ask question"),
    "request_user_input": ("提问", "Ask question"),
    "create_goal": ("创建目标", "Create goal"), "get_goal": ("查看目标", "Get goal"),
    "update_goal": ("更新目标", "Update goal"),
    "schedule_create": ("创建定时任务", "Create schedule"), "schedule_list": ("查看定时任务", "List schedules"),
    "schedule_delete": ("删除定时任务", "Delete schedule"), "schedule_update": ("修改定时任务", "Update schedule"),
    "cordis_inspect_list": ("检查提供方", "Inspect providers"), "cordis_inspect_query": ("查询运行时", "Query runtime"),
    "cordis_inspect_self": ("检查动态插件", "Inspect dynamic plugins"),
    "workflow": ("运行工作流", "Run workflow"), "ralph": ("运行循环工作流", "Run loop workflow"),
    "session_event_read": ("读取事件", "Read event"), "session_event_search": ("搜索事件", "Search events"),
    "session_event_trace": ("追踪事件", "Trace event"), "session_search": ("搜索会话", "Search sessions"),
    "session_trace": ("追踪会话", "Trace session"), "list_subagent_models": ("查看可用模型", "List available models"),
    "subagent": ("创建子智能体", "Create subagent"), "list_agents": ("查看子智能体", "List subagents"),
    "send_message": ("发送消息", "Send message"), "interrupt_agent": ("中断智能体", "Interrupt agent"),
    "job_list": ("查看后台任务", "List background jobs"), "job_output": ("读取任务输出", "Read job output"),
    "job_kill": ("取消后台任务", "Cancel background job"), "terminal_open": ("创建终端", "Open terminal"),
    "terminal_read": ("读取终端", "Read terminal"), "terminal_list": ("查看终端", "List terminals"),
    "terminal_signal": ("发送终端信号", "Signal terminal"), "terminal_close": ("关闭终端", "Close terminal"),
    "lsp": ("查询代码符号", "Query code symbols"), "spawn_teammate": ("创建队友", "Spawn teammate"),
    "team_task_create": ("创建团队任务", "Create team task"), "team_task_get": ("读取团队任务", "Read team task"),
    "team_task_update": ("更新团队任务", "Update team task"), "team_task_list": ("查看团队任务", "List team tasks"),
    "wait_agent": ("等待子智能体", "Wait for subagent"),
]
private let agentLine = try! NSRegularExpression(pattern: #"^(\S+) \[([^\]]+)\](?: parent=(\S+) depth=(\d+))?(?: — (.*))?$"#)
private let jobLine = try! NSRegularExpression(pattern: #"^(\S+) \[([^\]]+)\] (\S+) — (.*)$"#)
private let jobStatusSuffix = try! NSRegularExpression(pattern: #"\n\[status: ([^,\n\]]+)(?:, [^\]\n]+)?\]$"#)
private let terminalLine = try! NSRegularExpression(pattern: #"^(\S+)(?: \((.*?)\))? \[([^\]]+)\] (running|exited code=(\S+) signal=(\S+))(?: pid=(\d+))?$"#)
private let teammateTools: Set<String> = ["spawn_teammate", "list_agents", "send_message", "interrupt_agent", "wait_agent"]
private let searchTools: Set<String> = ["grep", "glob", "web_search"]
private let browseTools: Set<String> = ["read", "read_image", "web_fetch", "cordis_package_inspect", "cordis_runtime_inspect"]
private let inspectTools: Set<String> = ["cordis_inspect_list", "cordis_inspect_query", "cordis_inspect_self"]
private let commandKeys = ["description", "command"]
private let pathKeys = ["path", "file_path", "url"]
private let searchKeys = ["query", "pattern", "url"]
private let codeKeys = ["description"]
private let targetKeys = ["target", "agent_id", "sessionId", "job_id"]

private func parseToolJson(_ raw: String?) -> JSONValue? {
    guard let raw else { return nil }
    return try? JSONValue.parse(raw)
}

private func firstToolLine(_ text: String) -> String {
    String(text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? Substring(text))
}

private func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
    regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
}

public func toolProcessSummary(_ tool: Item.Tool, en: Bool = false) -> ToolProcessSummary {
    func tr(_ zh: String, _ english: String) -> String { en ? english : zh }
    let args = parseToolJson(tool.arguments)?.obj().map { JSONValue.object($0) }
    let title = toolTitles[tool.name].map { en ? $0.en : $0.zh } ?? tr("工具调用", "Tool call")
    let icon: ToolProcessIcon = {
        if teammateTools.contains(tool.name) { return .users }
        if tool.name.hasPrefix("schedule_") { return .clock }
        if tool.name.hasSuffix("_goal") { return .goal }
        if tool.name.hasPrefix("job_") || tool.name.hasPrefix("team_task_") || tool.name == "todo_write" { return .checklist }
        if tool.name.hasPrefix("terminal_") { return .code }
        if tool.name.hasPrefix("session_") || tool.name == "lsp" { return .search }
        if tool.name == "workflow" || tool.name == "ralph" { return .branch }
        if inspectTools.contains(tool.name) { return .plugin }
        if tool.name == "subagent" || tool.name == "list_subagent_models" { return .agent }
        if browseTools.contains(tool.name) { return .browse }
        if searchTools.contains(tool.name) { return .search }
        if tool.name == "bash" || tool.name == "pwsh" { return .command }
        if tool.name == "write" { return .write }
        if tool.name == "edit" { return .edit }
        if tool.name == "run_code" { return .code }
        return .generic
    }()
    if tool.status == .preparing {
        return ToolProcessSummary(title: preparingToolTitle(tool.name, en: en), summary: nil, icon: icon)
    }
    if tool.status == .error {
        return ToolProcessSummary(
            title: title,
            summary: firstToolLine(tool.error ?? tool.result ?? tr("调用失败", "Tool failed")),
            icon: icon
        )
    }
    let result = tool.result
    if tool.status == .ok, let result, let argsObject = args {
        if let recorded = controlSummary(name: tool.name, args: argsObject, text: result, json: parseToolJson(result), en: en) {
            return ToolProcessSummary(title: title, summary: recorded.isEmpty ? nil : recorded, icon: icon)
        }
    }
    let keys: [String]
    switch tool.name {
    case "bash", "pwsh": keys = commandKeys
    case "read", "read_image", "web_fetch", "write", "edit", "cordis_package_inspect", "cordis_runtime_inspect": keys = pathKeys
    case "grep", "glob", "web_search": keys = searchKeys
    case "run_code": keys = codeKeys
    default: keys = []
    }
    let queries: [String]?
    if searchTools.contains(tool.name) {
        queries = args?["queries"].arr()?.compactMap { $0.str()?.isEmpty == false ? firstToolLine($0.str()!) : nil }
    } else {
        queries = nil
    }
    let argumentSummary: String
    if args == nil {
        argumentSummary = firstToolLine(tool.arguments)
    } else if let queries, !queries.isEmpty {
        argumentSummary = queries.joined(separator: ", ")
    } else {
        let picked = keys.compactMap { args?[$0].str()?.isEmpty == false ? args?[$0].str() : nil }.first
            ?? args?.obj()?.values.compactMap { $0.str()?.isEmpty == false ? $0.str() : nil }.first
        argumentSummary = picked.map(firstToolLine) ?? ""
    }
    let summary = toolTitles[tool.name] == nil
        ? tool.name + (argumentSummary.isEmpty ? "" : " · \(argumentSummary)")
        : argumentSummary
    return ToolProcessSummary(title: title, summary: summary.isEmpty ? nil : summary, icon: icon)
}

/// Derive counts/receipts only from recognized successful recorded outputs, as ui-tool does.
private func controlSummary(name: String, args: JSONValue, text: String, json: JSONValue?, en: Bool) -> String? {
    func tr(_ zh: String, _ english: String) -> String { en ? english : zh }
    func count(_ n: Int, _ zh: String, _ english: String) -> String {
        en ? "\(n) \(english)" : "\(n) 个\(zh)"
    }
    func parsedLines(_ pattern: NSRegularExpression) -> Int? {
        if text.isEmpty { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.allSatisfy({ matches(pattern, $0) }) else { return nil }
        return lines.count
    }
    let target = targetKeys.compactMap { args[$0].str()?.isEmpty == false ? args[$0].str() : nil }.first ?? ""
    switch name {
    case "list_agents":
        if let array = json?.arr() { return count(array.count, "智能体", "agents") }
        if text == "(no subagents)" { return count(0, "智能体", "agents") }
        return parsedLines(agentLine).map { count($0, "智能体", "agents") }
    case "job_list":
        if text == "(no background jobs)" { return count(0, "后台任务", "background jobs") }
        return parsedLines(jobLine).map { count($0, "后台任务", "background jobs") }
    case "terminal_list":
        if text == "(no terminal sessions)" { return count(0, "终端", "terminals") }
        return parsedLines(terminalLine).map { count($0, "终端", "terminals") }
    case "wait_agent":
        if json?.obj() != nil, json?["timedOut"].bool() != nil {
            if json?["noProgress"].obj() != nil, json?["noProgress"]["message"].str() != nil {
                return tr("没有正在运行的子智能体", "No active subagents")
            }
            let suffix = json?["timedOut"].bool() == true ? tr("等待超时", "Wait timed out") : tr("检测到变化", "Change detected")
            return tr("子智能体状态", "Subagent activity") + " · " + suffix
        }
        return nil
    case "team_task_list":
        return json?["tasks"].arr().map { count($0.count, "团队任务", "team tasks") }
    case "team_task_create", "team_task_get", "team_task_update":
        return json?["subject"].str()
    case "spawn_teammate":
        return json?["member"].obj() != nil ? args["name"].str() : nil
    case "send_message":
        if json?["status"].str() == "queued" { return "\(target) · \(tr("已入队", "Queued"))" }
        if json?["status"].str() == "accepted" || text == "message delivered to agent \(target)" {
            return "\(target) · \(tr("已送达", "Delivered"))"
        }
        return nil
    case "interrupt_agent":
        if json?["previousStatus"].str() != nil || text == "interrupt requested for agent \(target)" {
            return "\(target) · \(tr("已请求中断", "Interrupt requested"))"
        }
        return nil
    case "job_output":
        let ns = text as NSString
        guard let match = jobStatusSuffix.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return "\(target) · \(ns.substring(with: match.range(at: 1)))"
    case "job_kill":
        if text == "requested cancellation of job \(target)" {
            return "\(target) · \(tr("已请求取消", "Cancellation requested"))"
        }
        if text.hasPrefix("job \(target) had already finished ") {
            return "\(target) · \(tr("已结束", "Already finished"))"
        }
        return nil
    case "get_goal", "create_goal", "update_goal":
        guard json?.obj() != nil, json?["goal"].isNull == false || json?.obj()?.keys.contains("goal") == true else { return nil }
        if json?["goal"].isNull == true { return tr("当前没有目标", "No current goal") }
        return json?["goal"]["objective"].str()
    case "subagent":
        if text.hasPrefix("started background subagent job ") || text.hasPrefix("started subagent ") {
            return args["prompt"].str().map { "\($0) · \(tr("已启动", "Started"))" }
        }
        return tr("智能体回复", "Agent response")
    case "list_subagent_models":
        return args["model"].str() ?? args["provider"].str() ?? tr("可用模型", "Available models")
    default:
        return nil
    }
}
