import SwiftUI
import DSHProtocol

func permissionIcon(_ value: String) -> String {
    switch value {
    case "auto": return "eye"
    case "read-only": return "eyeglasses"
    case "workspace-write": return "pencil"
    case "danger-full-access": return "exclamationmark.shield"
    default: return "hand.raised"
    }
}

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
                                Image(systemName: permissionIcon(option.value))
                                    .foregroundStyle(option.value == "danger-full-access" ? T.warnText : T.text2)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(permissionLabel(value: option.value, option: option))
                                            .foregroundStyle(T.ink)
                                        if option.value == "auto" {
                                            Text("EXP")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(T.warnText)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(T.warnTint, in: Capsule())
                                        }
                                    }
                                    Text(option.value == "auto"
                                         ? L.t("无沙箱运行；每次原生工具调用和 PTC 内层调用前由同一模型进行实验性审查。", "Runs without a sandbox. Each native tool call and PTC inner call is reviewed experimentally by the same model.")
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
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Circle()
                    .fill(T.warnTint)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "exclamationmark.triangle").foregroundStyle(T.warnText))
                Text(auto
                     ? L.t("确认启用自动审查（实验）？", "Enable auto-review (experimental)?")
                     : L.t("确认启用完全权限？", "Enable full access?"))
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
                             ? L.t("我已了解这些风险，并愿意继续", "I understand these risks and want to continue")
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
                    Button(auto ? L.t("启用自动审查", "Enable auto-review") : L.t("启用完全权限", "Enable full access")) {
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
                Spacer()
            }
            .padding(22)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: enabled) { value in
            if !value { acknowledged = false }
        }
    }

    private var description: String {
        if auto {
            return L.t(
                "自动审查不使用沙箱。每次原生工具调用和 PTC 内层调用前，都会由与当前 agent 相同的模型进行审查；审查拒绝的调用由你批准或拒绝。此功能仍属实验性，可能误放行或误拒绝，并会消耗额外 token。",
                "Auto-review does not use a sandbox. Each native tool call and PTC inner call is reviewed by the same model as the current agent; rejected calls require your approval. This is experimental and may allow or deny incorrectly, and uses extra tokens."
            )
        }
        if forDefaults {
            return L.t(
                "启用完全权限后，新会话将减少确认步骤，并且可以直接执行更多操作，包括敏感操作、文件修改或外部命令。仅建议在你信任后续任务时使用。",
                "With full access, new sessions will skip more confirmations and can perform more actions, including sensitive operations, file changes, or external commands. Use only when you trust later tasks."
            )
        }
        return L.t(
            "启用完全权限后，智能体将减少确认步骤，并且可以直接执行更多操作，包括敏感操作、文件修改或外部命令。仅建议在你信任当前任务时使用。",
            "With full access, the agent will skip more confirmations and can perform more actions, including sensitive operations, file changes, or external commands. Use only when you trust the current task."
        )
    }
}
