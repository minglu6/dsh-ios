import SwiftUI
import UIKit
import DSHProtocol

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
                .overlay(
                    OfficialGlyph(
                        kind: .warningOutline,
                        size: CGFloat(permissionRiskIconSizePoints),
                        color: T.warnText
                    )
                )
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
                HStack(alignment: .top, spacing: CGFloat(permissionRiskCheckboxGapPoints)) {
                    Image(systemName: acknowledged ? "checkmark.square.fill" : "square")
                        .font(.system(size: CGFloat(permissionRiskCheckboxSizePoints)))
                        .foregroundStyle(acknowledged ? T.primaryButton : T.text3)
                        .frame(
                            width: CGFloat(permissionRiskCheckboxSizePoints),
                            height: CGFloat(permissionRiskCheckboxSizePoints)
                        )
                        .padding(.top, CGFloat(permissionRiskCheckboxMarginTopPoints))
                        .accessibilityHidden(true)
                        .accessibilityIdentifier(
                            acknowledged
                                ? permissionRiskCheckboxOnSymbol()
                                : permissionRiskCheckboxOffSymbol()
                        )
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
                    .overlay(
                        RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusMdPoints))
                            .stroke(T.borderL3, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
                    )
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
        GeometryReader { geo in
            ZStack {
                T.scrim.ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                ScrollView {
                    PermissionRiskSheet(
                        preset: preset,
                        enabled: enabled,
                        forDefaults: forDefaults,
                        onDismiss: onDismiss,
                        onConfirm: onConfirm
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .ignoresSafeArea(.keyboard, edges: permissionRiskStaysAboveKeyboard ? .all : [])
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
    @Binding var open: Bool

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
                if permissionChipTriggerShowsLabel {
                    Text(currentLabel)
                        .lineLimit(1)
                }
                OfficialGlyph(kind: .chevronDown, size: 12, color: T.caption)
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(current == "danger-full-access" ? T.warnText : T.text2)
            .padding(.leading, permissionChipTriggerShowsLabel ? 8 : 2)
            .padding(.trailing, 2)
            .frame(minHeight: CGFloat(composerChipHeightPoints))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(currentLabel)
        .accessibilityIdentifier(composerPermissionChipIdentifier())
        .popover(isPresented: $open, attachmentAnchor: .rect(.bounds), arrowEdge: composerPickerPopoverOpensAbove ? .bottom : .top) {
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
                                OfficialGlyph(kind: .checkOutline, size: 14, color: T.ink)
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(composerPermissionPickerIdentifier())
            .frame(
                minWidth: CGFloat(permissionMenuMinWidthPoints),
                maxWidth: CGFloat(permissionMenuMaxWidthPoints)
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                minHeight: options.isEmpty
                    ? nil
                    : CGFloat(permissionMenuHeightPoints(optionCount: options.count)),
                alignment: .top
            )
            .modifier(PopoverCompactAdaptation())
        }
    }
}

/// Desktop `ui-permission-presets` `PermissionRow` inline Select (36× radius-md).
/// Never a grabber sheet titled 权限 / 默认权限.
struct SettingsPermissionSelect: View {
    let current: String
    let catalog: PermissionCatalog?
    var loading: Bool = false
    var enabled: Bool = true
    var onSelect: (String) -> Void
    @Binding var open: Bool

    private var options: [PermissionOption] { catalog?.defaultOptions ?? [] }
    private var currentLabel: String {
        permissionLabel(value: current, option: catalog?.find(current), english: L.en)
    }

    var body: some View {
        Button { if enabled { open.toggle() } } label: {
            HStack(spacing: CGFloat(settingsPermissionSelectorGapPoints)) {
                Text(currentLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(T.ink)
                    .lineLimit(1)
                OfficialGlyph(kind: .chevronDown, size: 14, color: T.text2)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .padding(.horizontal, CGFloat(settingsPermissionSelectorPaddingHorizontalPoints))
            .frame(height: CGFloat(settingsPermissionSelectorHeightPoints))
            .background(
                T.fill2,
                in: RoundedRectangle(cornerRadius: CGFloat(settingsPermissionSelectorRadiusPoints))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(currentLabel)
        .accessibilityIdentifier(settingsPermissionSelectSymbol())
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
                            Spacer(minLength: 8)
                            if option.value == current {
                                OfficialGlyph(kind: .checkOutline, size: 14, color: T.ink)
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settingsPermissionMenu")
            .frame(
                minWidth: CGFloat(permissionMenuMinWidthPoints),
                maxWidth: CGFloat(permissionMenuMaxWidthPoints)
            )
            .fixedSize(horizontal: false, vertical: true)
            .modifier(PopoverCompactAdaptation())
        }
    }
}
