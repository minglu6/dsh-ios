import Foundation

/// Desktop chat `MessageIconActions` as captured on the Chinese locale main thread.
/// Branch is a session-level ⋯ action, not a message-row icon.
public enum MessageActionKind: String, Equatable, CaseIterable, Sendable {
    case copy
    case like
    case dislike
    case share
}

public enum MessageActionPolicy {
    public static var assistantRow: [MessageActionKind] { [.copy, .like, .dislike, .share] }
    public static var userRow: [MessageActionKind] { [.copy] }
    public static var includesBranch: Bool { false }
}

/// Desktop right-hand Start / Guide body: workspace files + new terminal only.
public enum StartPanelEntry: String, Equatable, Hashable, Sendable {
    case workspaceFiles
    case newTerminal
}

public enum StartPanelPolicy {
    public static func entries(files: Bool, terminal: Bool) -> [StartPanelEntry] {
        var result: [StartPanelEntry] = []
        if files { result.append(.workspaceFiles) }
        if terminal { result.append(.newTerminal) }
        return result
    }

    public static var includesBrowser: Bool { false }
    public static var includesSessionInspector: Bool { false }

    public static func shortcut(_ entry: StartPanelEntry) -> String? {
        switch entry {
        case .workspaceFiles: return "⌘P"
        case .newTerminal: return nil
        }
    }

    public static func showsChevron(_ entry: StartPanelEntry) -> Bool {
        entry == .newTerminal
    }
}

/// Composer shows a concrete model name. "选择模型" is a prompt, not a model.
public func composerModelDisplayName(choiceName: String?, catalog: ModelCatalog?) -> String? {
    if let name = choiceName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
        return name
    }
    guard let catalog else { return nil }
    if let info = catalog.find(provider: catalog.defaultProvider, model: catalog.defaultModel) {
        return info.name
    }
    if let id = catalog.defaultModel?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
        return id
    }
    return nil
}

public enum ConversationFontSize {
    public static let min = 10
    public static let max = 22
    public static var range: ClosedRange<Int> { min...max }
}

public func conversationFontSizeLabel(_ size: Int) -> String {
    "\(size) px"
}

public func pairingCodeFieldLabel(english: Bool) -> String {
    english ? "Verification code" : "验证码"
}

public func downloadSessionLogLabel(english: Bool) -> String {
    english ? "Download session log" : "下载会话日志"
}

public func sessionLogUploadLabel(english: Bool) -> String {
    english
        ? "Upload session log when using the official model API"
        : "在使用官方模型 API 时上传会话日志"
}

public func modelsSettingsIntro(english: Bool) -> String {
    english
        ? "Enter each provider's API key to use its models."
        : "填入各提供商的 API 密钥即可使用模型。"
}

public extension MoreSheetPolicy {
    /// Browser and session inspector are not on the desktop Start panel.
    /// They stay reachable from the session ⋯ overflow when a chat is open.
    static func showsBrowser(inChat: Bool) -> Bool { inChat }
    static func showsInspector(inChat: Bool) -> Bool { inChat }
}
