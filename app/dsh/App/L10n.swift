import Foundation

enum L {
    static var en: Bool { AppPrefs.language == .en }

    static func sendMessage() -> String { en ? "Send message" : "发送消息" }
    static func queueSend() -> String { en ? "Queue message" : "排队发送" }
    static func steerSend() -> String { en ? "Steer message" : "插话发送" }
    static func busySendLabel(running: Bool, busy: BusySend) -> String {
        if !running { return sendMessage() }
        return busy == .steer ? steerSend() : queueSend()
    }

    static func copy() -> String { en ? "Copy" : "复制" }
    static func copied() -> String { en ? "Copied" : "复制成功" }
    static func like() -> String { en ? "Good response" : "好的回答" }
    static func dislike() -> String { en ? "Bad response" : "有问题的回答" }
    static func undoRating() -> String { en ? "Remove rating" : "取消标记" }
    static func submitFeedback() -> String { en ? "Submit feedback" : "提交反馈" }
    static func feedbackCategory() -> String { en ? "Feedback category" : "反馈分类" }
    static func feedbackDetail() -> String { en ? "Feedback details" : "反馈详情" }
    static func feedbackHint() -> String { en ? "Add details to help us improve…" : "填写详情以帮助我们改进…" }
    static func thanksFeedback() -> String { en ? "Thanks for your feedback" : "感谢你的反馈" }
    /// Android sheet only; desktop has no bilingual key for this retry line.
    static func feedbackSubmitFailed() -> String { "提交失败，内容已保留，请重试" }
    static func feedbackCategories() -> [(id: String, label: String)] {
        [
            ("task-result", en ? "Task result" : "任务结果"),
            ("instruction-following", en ? "Instruction understanding and following" : "指令理解与遵循"),
            ("product-interaction", en ? "Product features and interaction" : "产品功能与交互"),
            ("service-stability", en ? "Stability and speed" : "稳定性和速度"),
            ("resource-cost", en ? "Resource usage and cost" : "资源使用与费用"),
            ("security-privacy-permission", en ? "Security, privacy, and permissions" : "安全隐私与权限"),
            ("other", en ? "Other" : "其他"),
        ]
    }
    static func branch() -> String { en ? "Branch into a new conversation" : "在新对话中分支" }
    static func branchUnavailable() -> String {
        en ? "Available only on the last message of a completed turn" : "仅可从已完成轮次的最后一条消息分支"
    }
    static func chatTab() -> String { en ? "Chat" : "对话" }
    static func stop() -> String { en ? "Stop" : "停止" }
    static func newSession() -> String { en ? "New session" : "新会话" }
    static func search() -> String { en ? "Search" : "搜索" }
    static func searchSessions() -> String { en ? "Search session names" : "搜索会话名称" }
    static func emptySessions() -> String { en ? "No sessions yet" : "暂无会话" }
    static func sectionSessions() -> String { en ? "Sessions" : "会话" }
    static func sectionWorkspaces() -> String { en ? "Workspaces" : "工作区" }
    static func ungrouped() -> String { en ? "Ungrouped" : "未分组" }
    static func pinSession() -> String { en ? "Pin session" : "置顶会话" }
    static func unpinSession() -> String { en ? "Unpin session" : "取消置顶" }
    static func archiveSession() -> String { en ? "Archive session" : "归档会话" }
    static func unarchiveSession() -> String { en ? "Unarchive session" : "取消归档" }
    static func rename() -> String { en ? "Rename" : "重命名" }
    static func fork() -> String { en ? "Fork" : "Fork" }
    static func cancel() -> String { en ? "Cancel" : "取消" }
    static func save() -> String { en ? "Save" : "保存" }
    static func delete() -> String { en ? "Delete" : "删除" }
    static func retry() -> String { en ? "Retry" : "重试" }
    static func loading() -> String { en ? "Loading…" : "加载中…" }
    static func allowOnce() -> String { en ? "Allow once" : "允许一次" }
    static func reject() -> String { en ? "Reject" : "拒绝" }
    static func approval() -> String { en ? "Approval needed" : "需要审批" }

    static func settings() -> String { en ? "Settings" : "设置" }
    static func generalNav() -> String { en ? "General" : "通用设置" }
    static func modelsNav() -> String { en ? "Models" : "模型" }
    static func pluginsNav() -> String { en ? "Plugins" : "插件" }
    static func builtinPluginsNav() -> String { en ? "Built-in plugins" : "内置插件" }
    static func scheduleNav() -> String { en ? "Scheduled tasks" : "自动化任务" }
    static func phoneConnection() -> String { en ? "Phone connection" : "手机连接" }
    static func language() -> String { en ? "Language" : "语言" }
    static func appearance() -> String { en ? "Appearance" : "外观" }
    static func light() -> String { en ? "Light" : "浅色" }
    static func dark() -> String { en ? "Dark" : "深色" }
    static func followSystem() -> String { en ? "System" : "跟随系统" }
    static func currentVersion() -> String { en ? "Current version" : "当前版本" }

    static func diagnostics() -> String { en ? "Connection diagnostics" : "连接诊断" }
    static func diagnosticsCopy() -> String { en ? "Copy diagnostic report" : "复制诊断报告" }
    static func diagnosticsCopied() -> String { en ? "Copied" : "已复制" }
    static func diagnosticsChecking() -> String { en ? "Checking…" : "正在检查…" }
    static func diagnosticsUnavailable() -> String { en ? "Diagnostics unavailable" : "诊断服务暂不可用" }
    static func nearbyDevices() -> String { en ? "Nearby devices" : "附近设备" }
    static func connections() -> String { en ? "Connections" : "连接" }
    static func scanQr() -> String { en ? "Scan" : "扫码" }
    static func enterAddress() -> String { en ? "Enter address" : "输入地址" }
    static func pairedDevices() -> String { en ? "Paired devices" : "已配对设备" }
    static func pairSheetTitle() -> String { en ? "Pair" : "配对" }
    static func addressField() -> String { en ? "Address" : "地址" }
    static func nameField() -> String { en ? "Name" : "名称" }
    static func nameHint() -> String { en ? "Defaults to remote host IP" : "默认远程主机 IP" }
    static func pairAction() -> String { en ? "Start pairing" : "开始配对" }
    static func pairingBusy() -> String { en ? "Pairing…" : "配对中…" }
    static func pairTimeout() -> String {
        en
            ? "Pairing timed out. Confirm the desktop pairing window is open and this host:port is reachable."
            : "配对超时。请确认电脑已打开配对，且手机可达该 host:port。"
    }
    static func pairFailed() -> String { en ? "Pairing failed" : "配对失败" }
    static func connecting() -> String { en ? "Connecting" : "连接中" }
    static func online() -> String { en ? "Online" : "在线" }
    static func offline() -> String { en ? "Offline" : "离线" }
    static func repairNeeded() -> String { en ? "Pair again" : "请重新配对" }
    static func currentDevice() -> String { en ? "Current" : "当前" }
    static func switchDevice() -> String { en ? "Switch" : "切换" }
    static func pairingUriHint() -> String { "dshpocket://pair?h=<host:port>&c=<code>" }

    static func files() -> String { en ? "Files" : "文件" }
    static func terminal() -> String { en ? "Terminal" : "终端" }
    static func trajectory() -> String { en ? "Trajectory" : "轨迹" }
    static func jobs() -> String { en ? "Jobs" : "任务" }
    static func reasoning() -> String { en ? "Reasoning" : "思考" }
    static func tool() -> String { en ? "Tool" : "工具" }
    static func composerPlaceholder() -> String { en ? "Message" : "消息" }
    static func notConnected() -> String { en ? "Not connected" : "未连接" }
    static func disconnected() -> String { en ? "Disconnected" : "已断开" }

    static func pluginTooOld(_ required: String?) -> String {
        let need = required.map { en ? " (need ≥ \($0))" : "（需要 ≥ \($0)）" } ?? ""
        return en
            ? "Desktop plugin is too old\(need). Update dsh-plugin-pocket on the computer."
            : "桌面端插件版本过旧\(need)，请在电脑上升级 dsh-plugin-pocket。"
    }

    static func appTooOld(_ required: String?) -> String {
        let need = required.map { en ? " (need ≥ \($0))" : "（需要 ≥ \($0)）" } ?? ""
        return en
            ? "This app is too old\(need). Install the latest dsh-ios release."
            : "当前 App 版本过旧\(need)，请安装最新的 dsh-ios。"
    }

    static func protocolUnsupported() -> String {
        en
            ? "Incompatible plugin protocol. Update the desktop plugin and this app together."
            : "插件协议不兼容，请同时升级桌面端插件与本 App。"
    }
}

func formatSessionTime(at: Int64, now: Int64, language: AppLanguage) -> String {
    let diff = max(0, now - at)
    let en = language == .en
    switch diff {
    case ..<60_000: return en ? "now" : "刚刚"
    case ..<(3_600_000): return "\(diff / 60_000)" + (en ? "min" : "分钟")
    case ..<(86_400_000): return "\(diff / 3_600_000)" + (en ? "h" : "小时")
    case ..<(30 * 86_400_000): return "\(diff / 86_400_000)" + (en ? "d" : "天")
    case ..<(365 * 86_400_000): return "\(diff / (30 * 86_400_000))" + (en ? "mo" : "个月")
    default: return "\(diff / (365 * 86_400_000))" + (en ? "y" : "年")
    }
}
