import Foundation

public func userMessageReplayUnavailable(_ user: Item.User, english: Bool) -> String? {
    if user.pending {
        return english ? "The message is still sending." : "消息仍在发送中。"
    }
    if !user.textOnly || user.images > 0 || !user.imageRefs.isEmpty {
        return english
            ? "This message contains attachments or other content that cannot be replayed safely. Reattach the original files in the composer before sending."
            : "此消息含附件或其他无法安全重放的内容。请在输入框中重新添加原附件后发送。"
    }
    if !user.referenceLabels.isEmpty {
        let references = composerReferences(user.text)
        if user.referenceLabels.contains(where: { label in
            !references.contains { $0.kind == .session && $0.label == label }
        }) {
            return english
                ? "This message has session references without reusable reference tokens. Add those references again in the composer before sending."
                : "此消息的部分会话引用没有可重用的引用标记。请在输入框中重新添加这些引用后发送。"
        }
    }
    if user.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return english ? "This message has no text to resend." : "此消息没有可重新发送的文字。"
    }
    return nil
}
