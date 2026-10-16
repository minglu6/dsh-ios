import Foundation
import DSHProtocol

enum L {
    static var en: Bool { AppPrefs.language == .en }
    static func t(_ zh: String, _ en: String) -> String { Self.en ? en : zh }

    static func sendMessage() -> String { en ? "Send message" : "发送消息" }
    static func queueSend() -> String { en ? "Queue message" : "排队发送" }
    static func steerSend() -> String { en ? "Steer message" : "插话发送" }
    static func busySendLabel(running: Bool, busy: BusySend) -> String {
        if !running { return sendMessage() }
        return busy == .steer ? steerSend() : queueSend()
    }

    static func copy() -> String { en ? "Copy" : "复制" }
    static func paste() -> String { en ? "Paste" : "粘贴" }
    static func copied() -> String { en ? "Copied" : "复制成功" }
    static func like() -> String { en ? "Good response" : "好的回答" }
    static func dislike() -> String { en ? "Bad response" : "有问题的回答" }
    static func undoRating() -> String { en ? "Remove rating" : "取消标记" }
    static func submitFeedback() -> String { en ? "Submit feedback" : "提交反馈" }
    static func feedbackCategory() -> String { en ? "Feedback category" : "反馈分类" }
    static func feedbackDetail() -> String { en ? "Feedback details" : "反馈详情" }
    static func feedbackHint() -> String { messageFeedbackHint(english: en) }
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
    static func searchSessionsAria() -> String { en ? "Search sessions" : "搜索会话" }
    static func searchingSessions() -> String { en ? "Searching session history…" : "正在搜索会话历史…" }
    static func noMatchingSessions() -> String { en ? "No matching sessions" : "无匹配会话" }
    static func clearSearch() -> String { en ? "Clear search" : "清除搜索" }
    static func untitledSession() -> String { en ? "Untitled" : "未命名" }
    static func searchHasMore(_ n: Int) -> String { sessionSearchHasMoreLabel(n, english: en) }
    static func copySessionId() -> String { en ? "Copy Session ID" : "复制 Session ID" }
    static func sessionIdCopied() -> String { en ? "Session ID copied" : "Session ID 已复制" }
    static func sessionIdCopyFailed() -> String { en ? "Copy failed. Try again." : "复制失败，请重试" }
    static func emptyArchivedSessions() -> String { en ? "No archived sessions yet" : "暂无已归档会话" }
    static func archived() -> String { en ? "Archived" : "已归档" }
    static func restoreArchivedBody() -> String { archivedNotOpenable(english: en) }
    static func archivedToast(stopped: Bool = false) -> String { archiveSuccessToast(stopped: stopped, english: en) }
    static func orderByLabel() -> String { en ? "Order by" : "排序方式" }
    static func orderByManual() -> String { en ? "Manual" : "手动排序" }
    static func orderByUpdated() -> String { en ? "Last updated" : "最近更新" }
    static func filterByLabel() -> String { en ? "Filter sessions" : "筛选会话" }
    static func hideArchived() -> String { en ? "Hide archived" : "隐藏已归档" }
    static func showArchived() -> String { en ? "All conversations (show archived)" : "全部对话（显示已归档）" }
    static func onlyArchived() -> String { en ? "Archived only" : "仅显示已归档" }
    static func downloadSessionLog() -> String { downloadSessionLogLabel(english: en) }
    static func share() -> String { en ? "Share" : "分享" }
    static func pairingCode() -> String { pairingCodeFieldLabel(english: en) }
    static func sessionInspector() -> String { en ? "Session diagnostics" : "会话数据诊断" }
    static func sessionFeedback() -> String { en ? "Feedback" : "反馈" }
    static func sessionFeedbackHint() -> String { messageFeedbackHint(english: en) }
    static func imageLoading() -> String { en ? "Loading image…" : "图片加载中…" }
    static func imageLoadFailed() -> String { en ? "Failed to load image; click to retry" : "图片加载失败，点击重试" }
    static func agentPresets() -> String { en ? "Agent presets" : "Agent 预设" }
    static func presetOnboarding() -> String {
        en
            ? "Choose the agent’s tools and how it works. Use Standard mode for everyday tasks, or Creator mode to add capabilities to DSH."
            : "选择 Agent 的工具和工作方式。日常任务用「标准模式」，扩展 DSH 的能力用「创造模式」。"
    }
    static func presetReadOnly() -> String {
        en ? "This remote host allows viewing presets only; the default is read-only" : "当前远程主机仅支持查看预设，默认设置为只读"
    }
    static func presetLocked() -> String { en ? "Preset is fixed when the session is created" : "预设在创建会话时确定" }
    static func letAgentCreatePreset() -> String { en ? "Let the agent help me create a preset" : "让 Agent 帮我创建预设模式" }
    static func builtIn() -> String { en ? "Built-in" : "内置" }
    static func custom() -> String { en ? "Custom" : "自定义" }
    static func newTaskDefault() -> String { en ? "New task default" : "新任务默认" }
    static func setAsNewTaskDefault() -> String { en ? "Set as new task default: " : "设为新任务默认：" }
    static func newTaskDefaultPrefix() -> String { en ? "New task default: " : "新任务默认：" }
    static func loadFailed() -> String { en ? "Failed to load" : "加载失败" }
    static func noDescription() -> String { en ? "No description." : "暂无描述。" }
    static func modeExplanation() -> String { en ? "Mode explanation" : "模式说明" }
    static func howToUse() -> String { en ? "How to use" : "如何使用" }
    static func viewConfiguration() -> String { en ? "View configuration" : "查看配置" }
    static func hostDidNotReturnPreset() -> String {
        en ? "The remote host did not return the preset composition" : "远程主机未返回预设组成"
    }
    static func defaultUnchanged() -> String {
        en
            ? "Saved, but the remote host default is unchanged; a higher-priority override may be active"
            : "已保存，但远程主机当前默认值未改变，可能存在更高优先级覆盖"
    }
    static func renameSession() -> String { en ? "Rename session" : "重命名会话" }
    static func forkFromPrefix() -> String { en ? "Create a branch from the current session prefix" : "从当前会话前缀创建分支" }
    static func connectToViewSessions() -> String { en ? "Connect to view sessions" : "连接后显示会话" }
    static func closeSearch() -> String { en ? "Close search" : "关闭搜索" }
    static func approvalNotify(_ tool: String) -> String { ApprovalNotifyTexts.title(toolName: tool, english: en) }
    static func allowOnceAction() -> String { en ? "Allow once" : "允许一次" }
    static func rejectAction() -> String { en ? "Reject" : "拒绝" }
    static func connectedNamed(_ name: String) -> String { en ? "Connected to \(name)" : "已连接 \(name)" }
    static func offlineReconnecting() -> String { en ? "Offline, reconnecting" : "离线，重连中" }
    static func emptySessions() -> String { en ? "No sessions yet" : "暂无会话" }
    static func sectionSessions() -> String { en ? "Sessions" : "会话" }
    static func sectionWorkspaces() -> String { en ? "Workspaces" : "工作区" }
    static func ungrouped() -> String { en ? "Ungrouped" : "未分组" }
    static func pinSession() -> String { en ? "Pin session" : "置顶会话" }
    static func unpinSession() -> String { en ? "Unpin session" : "取消置顶" }
    static func archiveSession() -> String { en ? "Archive session" : "归档会话" }
    static func unarchiveSession() -> String { en ? "Unarchive session" : "取消归档" }
    static func rename() -> String { en ? "Rename" : "重命名" }
    static func fork() -> String { en ? "Fork session" : "分叉会话" }
    static func savingEllipsis() -> String { en ? "Saving…" : "保存中…" }
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
    static func modelsIntro() -> String {
        en
            ? "Enter your API keys to use models from the following providers."
            : "填入各提供商的 API 密钥即可使用其模型。"
    }
    static func pluginsNav() -> String { en ? "Plugins" : "插件" }
    static func builtinPluginsNav() -> String { en ? "Built-in plugins" : "内置插件" }
    static func scheduleNav() -> String { en ? "Scheduled tasks" : "自动化任务" }
    static func phoneConnection() -> String { en ? "Phone connection" : "手机连接" }
    static func mobileSection() -> String { en ? "Mobile" : "移动端" }
    static func hostSettingsReadOnly() -> String {
        en ? "Host settings are read-only" : "远程主机配置为只读"
    }
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
            : "配对超时。请确认电脑已打开配对，且手机可达该远程主机地址。"
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
    static func workspaceFiles() -> String { en ? "Workspace files" : "工作区文件" }
    static func workspaceFilesHint() -> String {
        en ? "Browse files in this session's workspace" : "浏览会话工作区的文件"
    }
    static func startPanel() -> String { en ? "Start" : "开始" }
    static func editedCount(_ count: Int) -> String { en ? "Edited \(count) files" : "已编辑 \(count) 个文件" }
    static func editedName(_ name: String) -> String { en ? "Edited \(name)" : "已编辑 \(name)" }
    static func collapseRightPanel() -> String { en ? "Collapse right sidebar" : "收起右侧边栏" }
    static func parentDirectory() -> String { en ? "Parent directory" : "上级目录" }
    static func noWorkspace() -> String { en ? "No workspace" : "无工作区" }
    static func noWorkspaceHint() -> String {
        en ? "This session has no workspace directory." : "这个会话没有工作区目录。"
    }
    static func copyPath() -> String { en ? "Copy path" : "复制路径" }
    static func copyName() -> String { en ? "Copy name" : "复制名称" }
    static func readingFiles() -> String { en ? "Reading…" : "正在读取…" }
    static func emptyDirectory() -> String { en ? "Empty directory" : "空目录" }
    static func filesTruncated() -> String {
        en ? "Too many entries, showing only some of them." : "条目太多，只显示了一部分。"
    }
    static func reload() -> String { en ? "Reload" : "重新读取" }
    static func autoRefresh() -> String { autoRefreshLabel(english: en) }
    static func autoRefreshEnable() -> String { autoRefreshEnableLabel(english: en) }
    static func autoRefreshDisable() -> String { autoRefreshDisableLabel(english: en) }
    static func refresh() -> String { en ? "Refresh" : "刷新" }
    static func notFileOrDirectory() -> String {
        en ? "Not a file or a directory, so it cannot be opened." : "这不是文件或目录，没法打开。"
    }
    static func preview() -> String { en ? "Preview" : "预览" }
    static func source() -> String { en ? "Source" : "源码" }
    static func code() -> String { en ? "Code" : "代码" }
    static func plainText() -> String { en ? "Plain text" : "纯文本" }
    static func openWith() -> String { en ? "Open with" : "打开方式" }
    static func refreshFile() -> String { en ? "Refresh file" : "刷新文件" }
    static func wrapLines() -> String { en ? "Wrap lines" : "自动换行" }
    static func unwrapLines() -> String { en ? "Do not wrap lines" : "取消自动换行" }
    static func viewOriginal() -> String { en ? "View original" : "查看原图" }
    static func image() -> String { en ? "Image" : "图片" }
    static func imagePreviewFailed() -> String { en ? "This image could not be displayed." : "无法显示这张图片" }
    static func docUnsupported() -> String {
        en ? "Preview is not available for this file type yet." : "该格式文件暂时无法预览"
    }
    static func docRetry() -> String { en ? "Retry" : "重试" }
    static func fileUnchanged() -> String { en ? "File unchanged" : "文件未变更" }
    static func fileUpdated() -> String { en ? "Loaded updated file" : "已加载文件的新版本" }
    static func fileChangedWhileReading() -> String {
        en ? "The file changed while reading; refresh to reload." : "文件在读取过程中发生变更，请刷新。"
    }
    static func binaryNoTextPreview() -> String {
        en ? "Binary files cannot be previewed as text" : "二进制文件不支持文本预览"
    }
    static func fileTooLarge() -> String {
        en ? "File too large to safely preview in full" : "文件过大，无法安全预览全文"
    }
    static func incompleteFile() -> String {
        en ? "Incomplete file response; cannot preview" : "文件未读取完整，无法预览"
    }
    static func pdfRendering() -> String { en ? "Rendering page…" : "正在绘制页面…" }
    static func pdfFailed(_ message: String) -> String {
        en ? "Cannot display PDF: \(message)" : "无法显示 PDF：\(message)"
    }
    static func pdfPage(_ page: Int) -> String { en ? "PDF page \(page)" : "PDF 第 \(page) 页" }
    static func docErrorUnavailable(_ message: String) -> String {
        en ? "Read failed: \(message)" : "读取失败：\(message)"
    }
    static func reset() -> String { en ? "Reset" : "重置" }
    static func close() -> String { en ? "Close" : "关闭" }
    static func zoomIn() -> String { en ? "Zoom in" : "放大图片" }
    static func zoomOut() -> String { en ? "Zoom out" : "缩小图片" }

    static func terminal() -> String { en ? "Terminal" : "终端" }
    static func terminalHint() -> String {
        en ? "Run commands in the session workspace" : "在会话工作区运行命令"
    }
    static func terminalSessions() -> String { en ? "Terminal sessions" : "终端会话" }
    static func terminalOffline() -> String { en ? "Offline" : "离线" }
    static func terminalConnecting() -> String { en ? "Connecting" : "连接中" }
    static func terminalExiting() -> String { en ? "Closing" : "关闭中" }
    static func terminalRunning() -> String { en ? "Running" : "运行中" }
    static func terminalStopped() -> String { en ? "Stopped" : "已停止" }
    static func connectToSwitchSessions() -> String { en ? "Connect to switch sessions" : "连接后可切换会话" }
    static func noRetainedSessions() -> String { en ? "No retained sessions" : "暂无保留的会话" }
    static func newTerminal() -> String { en ? "New terminal" : "新建终端" }
    static func exitTerminal() -> String { en ? "Close" : "关闭" }
    static func exitTerminalTitle() -> String { en ? "Close terminal?" : "关闭终端？" }
    static func exitTerminalBody() -> String {
        en
            ? "This ends the current shell and its running commands. Collapsing the panel keeps the session."
            : "这将结束当前 Shell 和其中正在运行的命令。仅收起面板不会结束会话。"
    }
    static func disconnectedReattach() -> String {
        en ? "Disconnected; reattaching when the connection returns." : "连接已断开；连接恢复后会重新附加。"
    }
    static func terminalConnectingEllipsis() -> String { en ? "Connecting…" : "正在连接…" }
    static func terminalExitingEllipsis() -> String { en ? "Closing…" : "正在关闭…" }
    static func terminalExitedHint() -> String {
        en
            ? "Terminal exited. Switch sessions or create a terminal from the menu."
            : "终端已退出。可从菜单切换会话或新建终端。"
    }
    static func terminalUnavailable() -> String { en ? "Terminal unavailable" : "终端不可用" }
    static func terminalEnded() -> String { en ? "Terminal ended." : "终端已结束。" }
    static func reconnect() -> String { en ? "Reconnect" : "重新连接" }
    static func pasteMultilineTitle() -> String { en ? "Paste multiple lines?" : "粘贴多行内容？" }
    static func pasteMultilineBody() -> String {
        en
            ? "Line breaks may execute commands immediately. Review before sending."
            : "换行可能立即执行命令，请确认内容后再发送。"
    }
    static func confirmPaste() -> String { en ? "Paste" : "确认粘贴" }
    static func terminalKeyboardInput() -> String { en ? "Terminal keyboard input" : "终端键盘输入" }
    static func terminalOutputHint() -> String {
        en ? "Terminal output; long press to select text" : "终端输出，长按选择文本"
    }
    static func showKeyboard() -> String { en ? "Show keyboard" : "显示键盘" }
    static func hideKeyboard() -> String { en ? "Hide keyboard" : "隐藏键盘" }
    static func terminalDone() -> String { en ? "Done" : "完成" }
    static func cannotLoadTerminalSessions() -> String {
        en ? "Unable to load terminal sessions" : "无法读取终端会话"
    }

    static func addWorkspace() -> String { en ? "Add workspace" : "添加工作区" }
    static func selectWorkspaceDirectory() -> String { en ? "Select Workspace Directory" : "选择工作区目录" }
    static func editPath() -> String { en ? "Edit path" : "编辑路径" }
    static func newFolder() -> String { en ? "New folder" : "新建文件夹" }
    static func folderName() -> String { en ? "Folder name" : "文件夹名称" }
    static func untitledFolder() -> String { en ? "Untitled folder" : "未命名文件夹" }
    static func newFolderIn(_ name: String) -> String {
        en ? "New folder in “\(name)”" : "在“\(name)”中新建文件夹"
    }
    static func open() -> String { en ? "Open" : "打开" }
    static func create() -> String { en ? "Create" : "创建" }
    static func homeDirectory() -> String { en ? "Home" : "主目录" }
    static func showHiddenFiles() -> String { en ? "Show hidden files" : "显示隐藏文件" }
    static func foldersTruncated() -> String {
        en ? "Too many folders to list; only the beginning is shown." : "文件夹过多，仅显示开头部分。"
    }
    static func deleteWorkspace() -> String { en ? "Delete workspace" : "删除工作区" }
    static func deleteWorkspaceBody(_ title: String) -> String {
        en
            ? "This removes “\(title)” from the workspace list. The folder and session logs will be kept. Its sessions will appear under Ungrouped."
            : "将把“\(title)”从工作区列表中移除。文件夹与会话记录会保留，其会话将显示在“未分组”下。"
    }
    static func defaultWorkspace() -> String { en ? "Default workspace" : "默认工作区" }
    static func viewOptions() -> String { en ? "View options" : "视图选项" }
    static func groupByLabel() -> String { en ? "Group by" : "分组方式" }
    static func groupByWorkspace() -> String { en ? "Workspace" : "按工作区" }
    static func groupByWorkspaceTree() -> String { en ? "Workspace Tree" : "按工作区树" }
    static func groupByFlat() -> String { en ? "In one list" : "单列表" }
    static func pinned() -> String { en ? "Pinned" : "已置顶" }
    static func expand() -> String { en ? "Expand" : "展开" }
    static func collapse() -> String { en ? "Collapse" : "收起" }
    static func moreActions() -> String { en ? "More" : "更多" }
    static func showMoreSessions(_ n: Int) -> String {
        en ? "Show \(n) more sessions" : "展开其余 \(n) 个会话"
    }
    static func showLess() -> String { en ? "Show less" : "收起" }

    static func presentFiles() -> String { en ? "Present files" : "交付文件" }
    static func trajectory() -> String { en ? "Trajectory" : "轨迹" }
    static func jobs() -> String { en ? "Jobs" : "任务" }
    static func backgroundJobs() -> String { en ? "Background jobs" : "后台任务" }
    static func jobsUnavailable() -> String { en ? "Job status unavailable" : "任务状态不可用" }
    static func jobsZero() -> String { en ? "0 background jobs" : "0 个后台任务" }
    static func backToJobs() -> String { en ? "Back to background jobs" : "返回后台任务" }
    static func waitingJobOutput() -> String { en ? "Waiting for job output…" : "等待任务输出…" }
    static func jobOutputExpired() -> String { jobOutputGap(english: en) }
    static func jobOutputMissing() -> String { jobOutputGap(english: en) }
    static func jobOutputFailed() -> String { en ? "Unable to read output" : "输出读取失败" }
    static func jobLoadFailed() -> String { en ? "Unable to load jobs" : "任务加载失败" }
    static func completedUnread() -> String { en ? "Completed, unread" : "已完成，未查看" }
    static func reasoning() -> String { en ? "Think" : "思考" }
    static func unavailable() -> String { en ? "Unavailable" : "暂不可用" }
    static func saving() -> String { en ? "Saving…" : "保存中…" }
    static func workDetails() -> String { en ? "Work details" : "工作步骤展示" }
    static func collapseTiming() -> String { en ? "When to Collapse Work Details" : "工作步骤收起时机" }
    static func performanceUsage() -> String { en ? "Performance & usage" : "性能与用量" }
    static func compact() -> String { en ? "Compact" : "简洁" }
    static func detailed() -> String { en ? "Detailed" : "详细" }
    static func fontSize() -> String { en ? "Font size" : "字号大小" }
    static func linkOpening() -> String { linkOpeningTitle(english: en) }
    static func addPlugin() -> String { en ? "Add plugin" : "添加插件" }
    static func pluginsHint() -> String { en ? "Install, enable, and configure plugins" : "安装、启用和配置插件" }
    static func officialPlugins(_ count: Int) -> String { en ? "Official \(count)" : "官方 \(count)" }
    static func installedPlugins() -> String { en ? "Installed plugins" : "已安装插件" }
    static func experimentalBadge() -> String { en ? "Experimental" : "实验性" }
    static func configureComponent() -> String { en ? "Configure component" : "配置组件" }
    static func pluginInterfaces() -> String { en ? "Open plugin interfaces" : "打开插件自定义界面" }
    static func newAutomation() -> String { en ? "New automation task" : "新建自动化任务" }
    static func automation() -> String { en ? "Scheduled tasks" : "自动化任务" }
    static func tool() -> String { en ? "Tool" : "工具" }
    static func composerPlaceholder() -> String { composerPlaceholderText(planMode: false, english: en) }
    static func landingHeadline() -> String { DSHProtocol.landingHeadline(english: en) }
    static func landingPreview() -> String { landingPreviewBadge(english: en) }
    static func landingPlaceholder() -> String { composerPlaceholderText(planMode: false, english: en, hero: true) }
    static func planReview() -> String { en ? "Plan review" : "计划待审" }
    static func approvePlan() -> String { en ? "Approve" : "同意执行" }
    static func typeYourAnswer() -> String { en ? "Type your answer" : "输入你的答案" }
    static func skip() -> String { en ? "Skip" : "跳过" }
    static func nextQuestion() -> String { en ? "Next" : "下一题" }
    static func completeQuestionFirst() -> String { en ? "Please complete this question first." : "请先完成这道问题。" }
    static func sectionAdd() -> String { en ? "Add" : "添加" }
    static func sectionCommands() -> String { en ? "Commands" : "指令" }
    static func sectionSkills() -> String { en ? "Skills" : "技能" }
    static func noOptions() -> String { commandMenuStatusEmpty(english: en) }
    static func file() -> String { en ? "File" : "文件" }
    static func pendingFiles() -> String { pendingAttachmentsLabel(english: en) }
    static func uploading() -> String { en ? "Uploading…" : "上传中…" }
    static func uploadFailed() -> String { en ? "Upload failed; click to retry" : "上传失败，点击重试" }
    static func removeFile(_ name: String) -> String { en ? "Remove file \(name)" : "移除文件 \(name)" }
    static func filesAndFolders() -> String { en ? "Files & folders" : "文件与文件夹" }
    static func planChip() -> String { planChipLabel(english: en) }
    static func planModeOn() -> String { planChipAria(english: en) }
    static func reopenQuestion() -> String { askReopenLabel(english: en) }
    static func notConnected() -> String { en ? "Not connected" : "未连接" }
    static func disconnected() -> String { en ? "Disconnected" : "已断开" }

    static func pluginTooOld(_ required: String?) -> String {
        let need = required.map { en ? " (need ≥ \($0))" : "（需要 ≥ \($0)）" } ?? ""
        return en
            ? "Desktop plugin is too old\(need). Update dsh-plugin-pocket on the computer."
            : "远程主机插件版本过旧\(need)，请在电脑上升级 dsh-plugin-pocket。"
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

