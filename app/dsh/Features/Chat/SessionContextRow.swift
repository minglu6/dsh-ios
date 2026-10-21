import SwiftUI

/// Read-only session facts, separate from the new-task selectors.
struct SessionContextRow: View {
    let workspace: String
    let preset: String

    var body: some View {
        HStack(spacing: 12) {
            contextLabel(workspace, icon: .folderOpen, alignment: .leading, identifier: "conversationWorkspace")
            contextLabel(preset, icon: .agentPreset, alignment: .trailing, identifier: "conversationPreset")
        }
        .font(Font.system(size: 12))
        .foregroundStyle(T.text3)
        .accessibilityElement(children: .contain)
    }

    private func contextLabel(
        _ text: String, icon: OfficialGlyph.Kind, alignment: Alignment, identifier: String
    ) -> some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    OfficialGlyph(kind: icon, size: 14, color: T.text3)
                        .opacity(0.7)
                        .accessibilityHidden(true)
                    Text(text)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityIdentifier(identifier)
                }
                .frame(minWidth: geometry.size.width, minHeight: 22, alignment: alignment)
            }
            .accessibilityIdentifier("\(identifier).scroll")
        }
        .frame(height: 22)
        .frame(maxWidth: .infinity)
    }
}

/// Android's compact touch counterpart of the desktop's passive preset label.
struct ConversationHeaderPreset: View {
    let name: String?
    let loaded: Bool
    let blank: Bool

    var body: some View {
        if loaded, !blank, let name {
            OfficialGlyph(kind: .agentPreset, size: 14, color: T.text3)
                .opacity(0.7)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(name)
                .accessibilityIdentifier("conversationHeaderPreset")
        }
    }
}
