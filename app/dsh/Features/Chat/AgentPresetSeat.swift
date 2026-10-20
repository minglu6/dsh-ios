import SwiftUI
import DSHProtocol

/// One context row: editable drafts on landing, host-owned metadata in a conversation.
struct ConversationContextRow: View {
    @ObservedObject var model: AppModel
    @Binding var showDirectoryPicker: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let chat = model.chat {
                let workspace = SessionContextPolicy.workspaceLabel(
                    sessionId: chat.sessionId,
                    cwd: model.sessions.first { $0.sessionId == chat.sessionId }?.cwd,
                    workspaces: model.workspaces,
                    localizedDefault: L.defaultWorkspace()
                )
                contextLabel(
                    workspace ?? SessionContextPolicy.unknownWorkspace(english: L.en),
                    kind: .folderOpen,
                    identifier: "conversationWorkspace"
                )
                contextLabel(
                    SessionContextPolicy.presetName(
                        id: chat.agentPreset, roster: model.presetRoster, english: L.en
                    ) ?? SessionContextPolicy.unknownPreset(english: L.en),
                    kind: .agentPreset,
                    identifier: "conversationPreset"
                )
            } else {
                Group {
                    LandingWorkspaceChip(model: model, showDirectoryPicker: $showDirectoryPicker)
                    AgentPresetSeat(model: model)
                }
                .disabled(firstPromptBlocksComposerActions(model.firstPrompt))
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("conversationContext")
    }

    private func contextLabel(_ title: String, kind: OfficialGlyph.Kind, identifier: String) -> some View {
        HStack(spacing: 4) {
            OfficialGlyph(kind: kind, size: 14, color: T.caption)
            Text(title)
                .font(.system(size: CGFloat(agentPresetSeatFontSizePoints), weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(T.ink)
        .padding(.horizontal, 8)
        .frame(minHeight: CGFloat(agentPresetSeatMinHeightPoints))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

/// Desktop `EmptyHero` `WorkspaceChip`: ghost trigger + WorkspacePicker MenuSurface.
/// System `Menu` + capsule fill is not the desktop chip.
struct LandingWorkspaceChip: View {
    @ObservedObject var model: AppModel
    @Binding var showDirectoryPicker: Bool
    @State private var open = false

    private var selectedId: String? {
        model.draftWorkspaceId ?? model.workspaces.first?.workspaceId
    }

    private var canCreate: Bool { model.ops.contains("workspace.create") }

    var body: some View {
        Button {
            if workspaceChipOpensDirectoryFlowDirectly(
                workspaceCount: model.workspaces.count,
                canCreate: canCreate
            ) {
                showDirectoryPicker = true
            } else if model.isOnline {
                open.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                OfficialGlyph(
                    kind: model.landingWorkspaceLabel == nil ? .folderClose : .folderOpen,
                    size: CGFloat(workspaceChipIconSizePoints),
                    color: T.ink
                )
                Text(model.landingWorkspaceLabel ?? landingChooseWorkspace(english: L.en))
                    .font(.system(size: CGFloat(workspaceChipFontSizePoints), weight: .medium))
                    .lineLimit(1)
                OfficialGlyph(
                    kind: .chevronDown,
                    size: CGFloat(workspaceChipChevronSizePoints),
                    color: T.caption
                )
                .rotationEffect(.degrees(open ? 180 : 0))
            }
            .foregroundStyle(T.ink)
            .padding(.horizontal, 8)
            .frame(minHeight: CGFloat(workspaceChipMinHeightPoints))
            .frame(maxWidth: CGFloat(workspaceChipMaxWidthPoints), alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!model.isOnline)
        .opacity(model.isOnline ? 1 : 0.45)
        .accessibilityLabel(landingChooseWorkspace(english: L.en))
        .accessibilityValue(model.landingWorkspaceLabel ?? "")
        .accessibilityIdentifier("draftWorkspace")
        .popover(
            isPresented: $open,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: composerPickerPopoverOpensAbove ? .bottom : .top
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if model.workspaces.isEmpty {
                    Text(workspacePickerLoading(english: L.en))
                        .font(.system(size: 12))
                        .foregroundStyle(T.text2)
                        .padding(8)
                }
                ForEach(model.workspaces) { workspace in
                    let title = workspaceDisplayTitle(
                        title: workspace.title,
                        path: workspace.path,
                        localizedDefault: L.defaultWorkspace()
                    )
                    Button {
                        model.draftWorkspaceId = workspace.workspaceId
                        open = false
                    } label: {
                        HStack(spacing: 8) {
                            OfficialGlyph(
                                kind: .folderClose,
                                size: CGFloat(workspaceChipIconSizePoints),
                                color: T.ink
                            )
                            Text(title)
                                .font(.system(size: 13))
                                .foregroundStyle(T.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if selectedId == workspace.workspaceId {
                                OfficialGlyph(kind: .checkOutline, size: 12, color: T.ink)
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: CGFloat(permissionMenuRowMinHeightPoints))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if canCreate {
                    Button {
                        open = false
                        showDirectoryPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            OfficialGlyph(
                                kind: .plusOutline,
                                size: CGFloat(workspaceChipIconSizePoints),
                                color: T.ink
                            )
                            Text(addWorkspaceMenuLabel(english: L.en))
                                .font(.system(size: 13))
                                .foregroundStyle(T.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: CGFloat(permissionMenuRowMinHeightPoints))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(CGFloat(permissionMenuPaddingPoints))
            .frame(minWidth: 180, maxWidth: CGFloat(workspaceChipMaxWidthPoints))
            .modifier(PopoverCompactAdaptation())
        }
    }
}

/// New-task preset selection. Existing sessions display their projection in the context row.
struct AgentPresetSeat: View {
    @ObservedObject var model: AppModel
    @State private var open = false

    private var rows: [JSONValue] {
        PresetPolicy.visibleRows(model.presetRoster, codingTools: model.showCodeWorkView)
    }

    private var currentId: String? {
        SessionContextPolicy.draftPresetId(
            pending: model.pendingCreatorPreset, draft: model.draftPreset, roster: model.presetRoster
        )
    }

    private var currentLabel: String {
        SessionContextPolicy.presetName(id: currentId, roster: model.presetRoster, english: L.en)
            ?? (L.en ? "Choose work mode" : "选择工作模式")
    }

    var body: some View {
        Button { if model.isOnline && !rows.isEmpty { open.toggle() } } label: {
                HStack(spacing: 4) {
                    OfficialGlyph(kind: .agentPreset, size: 14, color: T.ink)
                    Text(currentLabel)
                        .font(.system(size: CGFloat(agentPresetSeatFontSizePoints), weight: .medium))
                        .lineLimit(1)
                    if !rows.isEmpty {
                        OfficialGlyph(kind: .chevronDown, size: 11, color: T.caption)
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                }
                .foregroundStyle(T.ink)
                .padding(.horizontal, 8)
                .frame(minHeight: CGFloat(agentPresetSeatMinHeightPoints))
                .frame(maxWidth: CGFloat(agentPresetSeatMaxWidthPoints), alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!model.isOnline || rows.isEmpty)
            .opacity(model.isOnline && !rows.isEmpty ? 1 : 0.45)
            .accessibilityLabel(currentLabel)
            .accessibilityHint(agentPresetSeatHint(english: L.en))
            .accessibilityIdentifier("draftPreset")
            .popover(
                isPresented: $open,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: composerPickerPopoverOpensAbove ? .bottom : .top
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        let id = row["id"].str() ?? ""
                        Button {
                            model.draftPreset = id
                            model.pendingCreatorPreset = nil
                            open = false
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(PresetPolicy.name(row, english: L.en))
                                        .font(.system(size: 13))
                                        .foregroundStyle(T.ink)
                                    Text(PresetPolicy.description(row, english: L.en).flatMap { $0.isEmpty ? nil : $0 }
                                         ?? agentPresetNoDescription(english: L.en))
                                        .font(.system(size: 12))
                                        .foregroundStyle(T.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                if currentId == id {
                                    OfficialGlyph(kind: .checkOutline, size: 12, color: T.ink)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CGFloat(permissionMenuPaddingPoints))
                .frame(minWidth: 156, maxWidth: 280)
                .modifier(PopoverCompactAdaptation())
            }
    }
}
