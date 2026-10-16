import SwiftUI
import UIKit
import DSHProtocol

struct PermissionPickerSheet: View {
    let current: String
    let catalog: PermissionCatalog?
    let loading: Bool
    let error: String?
    var enabled: Bool = true
    var forDefaults: Bool = false
    var busy: Bool = false
    var onRefresh: () -> Void
    var onDismiss: () -> Void
    var onPick: (String) -> Void

    @State private var picked = false

    private var options: [PermissionOption] {
        if loading || error != nil { return [] }
        return forDefaults ? catalog?.defaultOptions ?? [] : catalog?.options ?? []
    }

    private var interactive: Bool { enabled && !busy && !loading && error == nil && !picked }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if forDefaults {
                        Text(L.t("选择新会话的默认权限模式；自动审查仅适用于当前会话。", "Choose the default permission mode for new sessions. Auto-review applies only to the current session."))
                            .font(.footnote)
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                    if loading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(L.t("加载权限模式…", "Loading permission modes…"))
                                .foregroundStyle(T.text3)
                        }
                        .padding(22)
                    } else if let error {
                        Text(error).foregroundStyle(T.err).padding(22)
                    } else if catalog == nil {
                        Text(L.t("此远程主机的权限目录不可用", "This remote host's permission catalog is unavailable"))
                            .foregroundStyle(T.text3)
                            .padding(22)
                    } else if options.isEmpty {
                        Text(L.t("没有可用的权限模式", "No permission modes available"))
                            .foregroundStyle(T.text3)
                            .padding(22)
                    }
                    ForEach(options, id: \.value) { option in
                        Button {
                            if !picked {
                                picked = true
                                if current == option.value { onDismiss() } else { onPick(option.value) }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                if permissionHasGlyph(option.value) {
                                    OfficialGlyph(
                                        kind: .permission(option.value),
                                        size: CGFloat(permissionMenuIconSizePoints),
                                        color: option.value == "danger-full-access" ? T.warnText : T.text2
                                    )
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(permissionLabel(value: option.value, option: option, english: L.en))
                                            .foregroundStyle(T.ink)
                                        if let badge = permissionExpBadge(option.value) {
                                            Text(badge)
                                                .font(.system(size: CGFloat(permissionExpBadgeFontSizePoints), weight: .medium))
                                                .tracking(CGFloat(permissionExpBadgeLetterSpacing))
                                                .foregroundStyle(T.text3)
                                        }
                                    }
                                    Text(option.value == "auto"
                                         ? permissionAutoDescription(english: L.en)
                                         : (option.description ?? ""))
                                        .font(.footnote)
                                        .foregroundStyle(T.text3)
                                }
                                Spacer()
                                if current == option.value {
                                    Image(systemName: "checkmark").foregroundStyle(T.ink)
                                }
                            }
                            .padding(14)
                            .background(current == option.value ? T.fill2 : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(!interactive)
                    }
                    if !loading && (catalog == nil || error != nil) {
                        Button(L.t("重新加载", "Reload"), action: onRefresh)
                            .disabled(!enabled || busy)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle(forDefaults ? L.t("默认权限", "Default permission") : L.t("访问模式", "Access mode"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.cancel(), action: onDismiss) } }
        }
        .onChange(of: catalog?.options.map(\.value) ?? []) { _ in picked = false }
    }
}

struct PermissionRiskSheet: View {
    let preset: String
    var enabled: Bool = true
    var forDefaults: Bool = false
    var onDismiss: () -> Void
    var onConfirm: () -> Void

    @State private var acknowledged = false
    @State private var submitted = false

    private var auto: Bool { preset == "auto" }
    private var supported: Bool { preset == "danger-full-access" || (auto && !forDefaults) }
    private var interactive: Bool { enabled && supported && !submitted }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Circle()
                .fill(T.warnTint)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "exclamationmark.triangle").foregroundStyle(T.warnText))
            Text(auto
                 ? permissionAutoConfirmTitle(english: L.en)
                 : L.t("确认启用完全权限？", "Enable Full access?"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(T.ink)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(T.text2)
                .lineSpacing(4)
            Button { if interactive { acknowledged.toggle() } } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: acknowledged ? "checkmark.square.fill" : "square")
                        .foregroundStyle(acknowledged ? T.ink : T.text3)
                    Text(auto
                         ? permissionAutoConfirmAcknowledge(english: L.en)
                         : L.t("我已了解风险，并愿意继续", "I understand the risks and want to continue"))
                        .foregroundStyle(T.ink)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
            .disabled(!interactive)
            HStack(spacing: 10) {
                Button(L.cancel(), action: onDismiss)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                Button(auto ? permissionAutoConfirmEnable(english: L.en) : L.t("启用完全权限", "Enable Full access")) {
                    if interactive && acknowledged {
                        submitted = true
                        acknowledged = false
                        onConfirm()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(T.onPrimary)
                .background(T.primaryButton.opacity(interactive && acknowledged ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 12))
                .disabled(!(interactive && acknowledged))
            }
        }
        .padding(22)
        .frame(maxWidth: 400)
        .background(T.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.border, lineWidth: 1))
        .padding(24)
        .onChange(of: enabled) { value in
            if !value { acknowledged = false }
        }
    }

    private var description: String {
        if auto {
            return permissionAutoConfirmDescription(english: L.en)
        }
        // Desktop hero / composer uses `permission.access` (current session).
        // Settings defaults use `settings.permission` (new sessions).
        return permissionFullAccessRiskDescription(
            audience: forDefaults ? .newSessionDefault : .currentSession,
            english: L.en
        )
    }
}

/// Desktop `RiskConfirmation`: centered dialog over a scrim, not a full-screen sheet.
struct PermissionRiskDialog: View {
    let preset: String
    var enabled: Bool = true
    var forDefaults: Bool = false
    var onDismiss: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            T.scrim.ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            PermissionRiskSheet(
                preset: preset,
                enabled: enabled,
                forDefaults: forDefaults,
                onDismiss: onDismiss,
                onConfirm: onConfirm
            )
        }
        .onAppear {
            guard permissionRiskDismissesKeyboard else { return }
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

/// Desktop `PermissionSelect`: ghost chip + custom MenuSurface, not a system Menu.
struct PermissionChipMenu: View {
    let current: String
    let catalog: PermissionCatalog?
    var loading: Bool = false
    var enabled: Bool = true
    var onSelect: (String) -> Void
    @State private var open = false

    private var options: [PermissionOption] { catalog?.options ?? [] }
    private var currentLabel: String {
        permissionLabel(value: current, option: catalog?.find(current), english: L.en)
    }

    var body: some View {
        Button { if enabled { open.toggle() } } label: {
            HStack(spacing: 4) {
                if permissionHasGlyph(current) {
                    OfficialGlyph(
                        kind: .permission(current),
                        size: CGFloat(permissionTriggerIconSizePoints),
                        color: current == "danger-full-access" ? T.warnText : T.text2
                    )
                }
                Text(currentLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(T.caption)
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(current == "danger-full-access" ? T.warnText : T.text2)
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .frame(minHeight: CGFloat(composerChipHeightPoints))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(currentLabel)
        .popover(isPresented: $open, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(8)
                }
                ForEach(options, id: \.value) { option in
                    Button {
                        open = false
                        if option.value != current { onSelect(option.value) }
                    } label: {
                        HStack(spacing: 6) {
                            if permissionHasGlyph(option.value) {
                                OfficialGlyph(
                                    kind: .permission(option.value),
                                    size: CGFloat(permissionMenuIconSizePoints),
                                    color: T.ink
                                )
                            }
                            Text(permissionLabel(value: option.value, option: option, english: L.en))
                                .font(.system(size: 13))
                                .foregroundStyle(T.ink)
                                .lineLimit(1)
                            if let badge = permissionExpBadge(option.value) {
                                Text(badge)
                                    .font(.system(size: CGFloat(permissionExpBadgeFontSizePoints), weight: .medium))
                                    .tracking(CGFloat(permissionExpBadgeLetterSpacing))
                                    .foregroundStyle(T.text3)
                            }
                            Spacer(minLength: 8)
                            if option.value == current {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(T.ink)
                            }
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
            .frame(minWidth: CGFloat(permissionMenuMinWidthPoints), maxWidth: CGFloat(permissionMenuMaxWidthPoints))
            .modifier(PopoverCompactAdaptation())
        }
    }
}
