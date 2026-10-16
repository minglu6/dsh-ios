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

/// Desktop `ui-conversation` `tool.title.*` / `todo.rowTitle` / `ask.rowTitle`.
/// `ui-tool` SearchRow / WebRow / DetailsRow refine grep, glob, web_*, lsp operations.
public func toolRowTitle(name: String, arguments: String? = nil, english: Bool) -> String {
    if name == "lsp", let operation = parseToolJson(arguments)?["operation"].str() {
        switch operation {
        case "goToDefinition": return english ? "Find definition" : "查找定义"
        case "findReferences": return english ? "Find references" : "查找引用"
        case "goToImplementation": return english ? "Find implementation" : "查找实现"
        case "hover": return english ? "Inspect symbol" : "查看符号信息"
        default: break
        }
    }
    let pair: (zh: String, en: String)? = {
        switch name {
        case "bash": return ("运行命令", "Bash")
        case "pwsh": return ("运行命令", "Pwsh")
        case "read": return ("读取", "Read")
        case "read_image": return ("读取图片", "Read image")
        case "web_fetch": return ("网页获取", "Fetch")
        case "web_search": return ("网页搜索", "Search")
        case "grep": return ("搜索文件内容", "Grep")
        case "glob": return ("查找文件", "Glob")
        case "write": return ("写入", "Write")
        case "edit": return ("编辑", "Edit")
        case "run_code": return ("代码", "Code")
        case "cordis_package_inspect", "cordis_runtime_inspect":
            return ("查询 Cordis 环境", "Query Cordis environment")
        case "cordis_run": return ("运行 Cordis 插件", "Run Cordis Plugin")
        case "cordis_stop": return ("停止 Cordis 插件", "Stop Cordis Plugin")
        case "cordis_undefine": return ("移除 Cordis 插件", "Remove Cordis Plugin")
        case "todo_write": return ("更新任务清单", "Update to-do list")
        case "ask_user_question", "request_user_input": return ("提问", "Ask question")
        case "create_goal": return ("创建目标", "Create goal")
        case "get_goal": return ("查看目标", "View goal")
        case "update_goal": return ("更新目标", "Update goal")
        case "schedule_create": return ("创建定时任务", "Create reminder")
        case "schedule_list": return ("查看定时任务", "List reminders")
        case "schedule_delete": return ("删除定时任务", "Delete reminder")
        case "schedule_update": return ("修改定时任务", "Update reminder")
        case "cordis_inspect_list": return ("检查提供方", "Inspect providers")
        case "cordis_inspect_query": return ("查询运行时", "Query runtime")
        case "cordis_inspect_self": return ("检查动态插件", "Inspect plugins")
        case "workflow": return ("运行工作流", "Run workflow")
        case "ralph": return ("运行循环工作流", "Run ralph loop")
        case "session_event_read": return ("读取事件", "Read event")
        case "session_event_search": return ("搜索事件", "Search events")
        case "session_event_trace": return ("追踪事件", "Trace event")
        case "session_search": return ("搜索会话", "Search sessions")
        case "session_trace": return ("追踪会话", "Trace session")
        case "list_subagent_models": return ("查看可用模型", "List models")
        case "subagent": return ("创建子智能体", "Create subagent")
        case "list_agents": return ("查看子智能体", "List subagents")
        case "send_message": return ("发送消息", "Send message")
        case "interrupt_agent": return ("中断智能体", "Interrupt agent")
        case "job_list": return ("查看后台任务", "List background jobs")
        case "job_output": return ("读取任务输出", "Read job output")
        case "job_kill": return ("取消后台任务", "Cancel background job")
        case "terminal_open": return ("创建终端", "Open terminal")
        case "terminal_read": return ("读取终端", "Read terminal")
        case "terminal_list": return ("查看终端", "List terminals")
        case "terminal_signal": return ("发送终端信号", "Signal terminal")
        case "terminal_close": return ("关闭终端", "Close terminal")
        case "lsp": return ("查询代码符号", "Query code symbols")
        case "spawn_teammate": return ("创建队友", "Create teammate")
        case "team_task_create": return ("创建团队任务", "Create team task")
        case "team_task_get": return ("读取团队任务", "Read team task")
        case "team_task_update": return ("更新团队任务", "Update team task")
        case "team_task_list": return ("查看团队任务", "List team tasks")
        case "wait_agent": return ("等待子智能体", "Wait for subagent")
        default: return nil
        }
    }()
    if let pair { return english ? pair.en : pair.zh }
    return english ? "Tool call" : "工具调用"
}

/// Desktop `ToolRow` `stateStatus`: visually hidden; title stays `tool.title.*`.
public func toolRowStateStatus(_ status: ToolStatus, english: Bool) -> String? {
    switch status {
    case .preparing: return english ? "Preparing tool call" : "正在准备调用"
    case .running: return english ? "Running" : "运行中"
    case .error: return english ? "Failed" : "失败"
    case .awaitingApproval, .ok: return nil
    }
}

private func toolRowHasOfficialTitle(_ name: String) -> Bool {
    name == "ask_user_question" || name == "request_user_input" || toolRowTitle(name: name, english: false) != "工具调用"
}
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
    let title = toolRowTitle(name: tool.name, arguments: tool.arguments, english: en)
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
    let summary = toolRowHasOfficialTitle(tool.name)
        ? argumentSummary
        : tool.name + (argumentSummary.isEmpty ? "" : " · \(argumentSummary)")
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
