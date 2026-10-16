import SwiftUI
import DSHProtocol

private func qoderCopy(_ zh: String, _ en: String) -> String { L.t(zh, en) }

struct QoderConnectionCard: View {
    let namespace: JSONValue
    let online: Bool
    let writable: Bool
    var interactionEnabled: Bool = true
    @ObservedObject var model: AppModel
    var onBusy: (Bool) -> Void
    var onChanged: () -> Void

    @State private var draft: QoderConnectionDraft?
    @State private var failure: QoderConnectionError?
    @State private var partial = false
    @State private var busy = false
    @State private var advanced = false
    @State private var refresh = 0
    @State private var credential: JSONValue?
    @State private var credentialFailed = false

    private var revision: Int64? { namespace["revision"].long() }
    private var effective: QoderConnectionDraft { qoderConnectionDraft(namespace["value"], revision: revision ?? 0) }
    private var ref: String { draft?.ref ?? effective.ref }
    private var editable: Bool {
        online && writable && namespace["writable"].bool() != false && revision != nil && model.ops.contains("models.settingsMutate")
    }
    private var fieldsEnabled: Bool { editable && interactionEnabled && !busy }
    private var tokenWritable: Bool { credential?["writable"].bool() == true && model.ops.contains("credentials.set") }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(qoderCopy("Qoder CN", "Qoder CN")).foregroundStyle(T.ink).font(.system(size: 14, weight: .medium))
                    hint(patStatus)
                }
                Spacer()
                if draft == nil {
                    Button(qoderCopy("编辑连接", "Edit connection")) {
                        guard let revision else { return }
                        draft = qoderConnectionDraft(namespace["value"], revision: revision)
                        failure = nil
                        partial = false
                        advanced = false
                    }
                    .disabled(!fieldsEnabled)
                    .font(.system(size: 13))
                }
            }
            hint(qoderCopy("使用个人访问令牌连接。VPC 实例留空时使用公网服务", "Connect with a personal access token. Leave the VPC instance empty to use the public service."))
            if !editable && online {
                hint(qoderCopy("当前会话的连接设置为只读，请在本机远程主机中编辑", "Connection settings are read-only in this session. Open the local Host to edit them."))
            }
            if credentialFailed {
                Text(qoderCopy("无法读取令牌状态，请重试后再保存新令牌", "Could not read the token status. Retry before saving a new token."))
                    .font(.system(size: 12))
                    .foregroundStyle(T.err)
                Button(L.retry()) { refresh += 1 }
                    .disabled(!online || busy)
            }
            if credential?["writable"].bool() == false {
                hint(qoderCopy("此令牌由启动环境等只读凭据来源管理，请到对应来源中修改", "This token is managed by a read-only credential source, such as the launch environment. Update it there instead."))
            }
            if let current = draft {
                editor(current)
            } else {
                Text(effective.fields.vpcInstance.isEmpty
                     ? qoderCopy("公网服务", "Public service")
                     : effective.fields.vpcInstance)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text2)
            }
        }
        .task(id: "\(ref)-\(online)-\(refresh)-\(model.modelSettingsRevision)-\(revision ?? -1)-\(model.ops.sorted().joined())") {
            await loadCredential()
        }
    }

    private var patStatus: String {
        switch credential?["configured"].bool() {
        case true: return qoderCopy("PAT 已配置", "PAT configured")
        case false: return qoderCopy("PAT 未配置", "PAT not configured")
        default: return qoderCopy("PAT 状态不可用", "PAT status unavailable")
        }
    }

    @ViewBuilder
    private func editor(_ current: QoderConnectionDraft) -> some View {
        field(qoderCopy("个人访问令牌（PAT）", "Personal access token (PAT)")) {
            SecureField(qoderCopy("个人访问令牌（PAT）", "Personal access token (PAT)"), text: Binding(
                get: { current.pat },
                set: { draft = patch(current, pat: $0) }
            ))
            .textInputAutocapitalization(.never)
            .disabled(!(fieldsEnabled && tokenWritable))
            hint(qoderCopy("留空保留现有令牌，已保存的令牌不会回显", "Leave empty to keep the existing token. Stored tokens are never displayed."))
        }
        field(qoderCopy("VPC 实例（可选）", "VPC instance (optional)")) {
            TextField(qoderCopy("VPC 实例（可选）", "VPC instance (optional)"), text: Binding(
                get: { current.fields.vpcInstance },
                set: { draft = patch(current, fields: QoderConnectionFields(vpcInstance: $0, baseURL: current.fields.baseURL, openApiUrl: current.fields.openApiUrl)) }
            ))
            .textInputAutocapitalization(.never)
            .disabled(!fieldsEnabled)
            hint(qoderCopy("填写实例 ID，而不是工作区网址；清空后使用公网服务", "Enter the instance ID, not a workspace URL. Clear it to use the public service."))
        }
        Button {
            advanced.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(advanced ? "▾" : "▸").foregroundStyle(T.text2)
                Text(qoderCopy("高级端点覆盖", "Advanced endpoint overrides")).foregroundStyle(T.text2).font(.system(size: 14))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        if advanced {
            field(qoderCopy("Gateway URL（可选）", "Gateway URL (optional)")) {
                TextField(qoderCopy("Gateway URL（可选）", "Gateway URL (optional)"), text: Binding(
                    get: { current.fields.baseURL },
                    set: { draft = patch(current, fields: QoderConnectionFields(vpcInstance: current.fields.vpcInstance, baseURL: $0, openApiUrl: current.fields.openApiUrl)) }
                ))
                .textInputAutocapitalization(.never)
                .disabled(!fieldsEnabled)
            }
            field(qoderCopy("OpenAPI URL（可选）", "OpenAPI URL (optional)")) {
                TextField(qoderCopy("OpenAPI URL（可选）", "OpenAPI URL (optional)"), text: Binding(
                    get: { current.fields.openApiUrl },
                    set: { draft = patch(current, fields: QoderConnectionFields(vpcInstance: current.fields.vpcInstance, baseURL: current.fields.baseURL, openApiUrl: $0)) }
                ))
                .textInputAutocapitalization(.never)
                .disabled(!fieldsEnabled)
            }
            hint(qoderCopy("留空时根据 VPC 实例或公网服务自动生成端点", "Leave empty to derive the endpoints from the VPC instance or public service."))
        }
        if let failure {
            Text(qoderFailure(failure)).font(.system(size: 12)).foregroundStyle(T.err)
        }
        if partial {
            hint(qoderCopy("连接设置已保存，但令牌未保存；关闭编辑器不会撤销已保存的设置", "Connection settings were saved, but the token was not. Closing will not undo the saved settings."))
        }
        HStack {
            Spacer()
            Button(partial ? qoderCopy("关闭", "Close") : L.cancel(), action: close)
                .disabled(busy)
            Button(busy ? qoderCopy("正在保存…", "Saving…") : L.save(), action: save)
                .disabled(!fieldsEnabled || failure == .conflict || (!current.pat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !tokenWritable))
        }
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(T.ink)
            content()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(T.text2).lineSpacing(4)
    }

    private func patch(_ current: QoderConnectionDraft, pat: String? = nil, fields: QoderConnectionFields? = nil) -> QoderConnectionDraft {
        QoderConnectionDraft(
            fields: fields ?? current.fields,
            original: current.original,
            ref: current.ref,
            path: current.path,
            revision: current.revision,
            pat: pat ?? current.pat
        )
    }

    private func close() {
        draft = nil
        failure = nil
        partial = false
        advanced = false
        onChanged()
    }

    private func save() {
        guard let pending = draft, editable, !busy, interactionEnabled, failure != .conflict else { return }
        guard let client = model.clientOrNull() else { return }
        busy = true
        onBusy(true)
        failure = nil
        Task {
            do {
                let result = try await saveQoderConnection(
                    pending,
                    writable: editable,
                    describe: { try await client.credentialsDescribe(ref: $0) },
                    mutate: { changes, expected in
                        try await client.modelsSettingsMutate(ns: "llm-qoder", ops: changes, expectedRevision: expected)
                    },
                    store: { credentialRef, pat in
                        try await client.credentialsSet(ref: credentialRef, value: pat)
                    }
                )
                partial = partial || (result.settingsSaved && result.error != nil)
                failure = result.error
                draft = result.error == nil ? nil : result.draft
                if result.error == nil {
                    partial = false
                    advanced = false
                }
                refresh += 1
                if result.settingsSaved || result.error == nil || result.error == .conflict {
                    onChanged()
                }
            } catch is CancellationError {
                return
            } catch {
                failure = .settingsFailed
            }
            busy = false
            onBusy(false)
        }
    }

    private func loadCredential() async {
        credential = nil
        credentialFailed = false
        guard online else { return }
        guard model.ops.contains("credentials.describe") else {
            credentialFailed = true
            return
        }
        do {
            let info = try await model.clientOrNull()?.credentialsDescribe(ref: ref)
            if info?["configured"].bool() != nil && info?["writable"].bool() != nil {
                credential = info
                credentialFailed = false
            } else {
                credentialFailed = true
            }
        } catch is CancellationError {
            return
        } catch {
            credentialFailed = true
        }
    }

    private func qoderFailure(_ error: QoderConnectionError) -> String {
        switch error {
        case .readOnly:
            return qoderCopy("当前会话的连接设置为只读，请在本机远程主机中编辑", "Connection settings are read-only in this session. Open the local Host to edit them.")
        case .credentialReadOnly:
            return qoderCopy("此令牌由启动环境等只读凭据来源管理，请到对应来源中修改", "This token is managed by a read-only credential source, such as the launch environment. Update it there instead.")
        case .loadFailed:
            return qoderCopy("无法读取令牌状态，请重试后再保存新令牌", "Could not read the token status. Retry before saving a new token.")
        case .credentialFailed:
            return qoderCopy("令牌保存失败，输入已保留；请重试或检查凭据来源", "The token could not be saved. Your input is kept; retry or check the credential source.")
        case .settingsFailed:
            return qoderCopy("连接保存失败，输入已保留；请检查填写内容后重试", "The connection could not be saved. Your input is kept; check the values and retry.")
        case .conflict:
            return qoderCopy("这些设置已在其他地方修改。请取消并重新打开编辑器以加载最新值，当前草稿尚未丢弃", "These settings changed elsewhere. Cancel and reopen this editor to load the latest values; your draft has not been discarded.")
        }
    }
}
