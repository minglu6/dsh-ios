import SwiftUI
import DSHProtocol

struct PluginPackageDetail: View {
    let bundle: JSONValue
    let plugins: [JSONValue]
    let namespaces: [JSONValue]
    let locked: Bool
    let canToggle: Bool
    let canUninstall: Bool
    let canToggleRows: Bool
    let onBack: () -> Void
    let onToggle: (Bool) -> Void
    let onUninstall: () -> Void
    let onToggleRow: (String, Bool) -> Void
    let onConfigure: (JSONValue) -> Void
    var backTitle: String = L.pluginsNav()

    @State private var filter = ""

    private var name: String { bundle["name"].str() ?? "" }
    private var title: String { pluginTitle(bundle, english: L.en) }
    private var rows: [JSONValue] { bundle["rows"].arr() ?? [] }
    private var missing: Bool { bundle["availability"].str() == "missing" }
    private var bundleEnabled: Bool { !missing && bundle["enabled"].bool() == true }
    private var mayToggle: Bool {
        !locked && canToggle && bundle["readOnlyReason"].isNull
            && (!missing || pluginNeedsInstallToEnable(bundle))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            top
            VStack(alignment: .leading, spacing: 8) {
                PluginDetailFlow(spacing: 8) {
                    Text(title).font(.system(size: 20, weight: .medium)).foregroundStyle(T.ink)
                    if let version = bundle["version"].str() {
                        tag("v\(version)", version: true)
                    }
                    if name.hasPrefix("@deepseek-ai/dsh-experimental-") {
                        tag(L.t("实验性", "Experimental"), color: T.businessPrimary)
                    }
                    if !bundle["error"].isNull {
                        tag(L.t("异常", "Problem"), color: T.err)
                    }
                    if missing {
                        tag(bundle["installed"].bool() == true
                            ? L.t("包不可用", "Package unavailable") : L.t("未安装", "Not installed"), outline: true)
                    }
                }
                Text(name).font(.system(size: 12, design: .monospaced)).foregroundStyle(T.text3)
                    .textSelection(.enabled)
                let description = pluginDescription(bundle, english: L.en)
                if !description.isEmpty {
                    Text(description).font(.system(size: 14)).foregroundStyle(T.text2).lineSpacing(4)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 20)
            metadataError(bundle)
            if !bundle["error"].isNull {
                reason(L.t("原因", "Reason") + ": " + pluginDetailManagementText(bundle["error"]))
            }
            if !bundle["readOnlyReason"].isNull {
                reason(pluginDetailManagementText(bundle["readOnlyReason"]))
            }
            VStack(alignment: .leading, spacing: 32) {
                if !missing { components }
                source
            }
            .padding(.top, 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pluginPackageDetail")
        .onChange(of: name) { _ in filter = "" }
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 32) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    OfficialGlyph(kind: .chevronLeft, size: 14, color: T.text3)
                    Text(backTitle).font(.system(size: 12.5)).foregroundStyle(T.text3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.t("返回 \(backTitle)", "Back to \(backTitle)"))
            .accessibilityIdentifier("pluginDetailBack")
            HStack(spacing: 12) {
                artwork(bundle, row: false)
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    if bundle["installed"].bool() == true || bundle["removable"].bool() == true {
                        Button {
                            guard canUninstall && !locked else { return }
                            onUninstall()
                        } label: {
                            HStack(spacing: 6) {
                                OfficialGlyph(kind: .trashOutline, size: 13, color: T.err)
                                Text(L.t("卸载", "Uninstall")).font(.system(size: 12))
                            }
                            .foregroundStyle(T.err)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.borderL3, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canUninstall || locked)
                        .opacity(canUninstall && !locked ? 1 : 0.5)
                        .accessibilityLabel(L.t("卸载 \(title)", "Uninstall \(title)"))
                        .accessibilityIdentifier("pluginDetailUninstall")
                    }
                    PluginEnableSwitch(isOn: bundleEnabled, enabled: mayToggle,
                                       label: L.t("启用 \(title)", "Enable \(title)"), onChange: onToggle)
                        .accessibilityIdentifier("pluginDetailToggle")
                }
            }
        }
    }

    private var components: some View {
        let counts = pluginParts(rows: rows, plugins: plugins)
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = rows.filter { row in
            query.isEmpty || [rowTitle(row), pluginDescription(row, english: L.en),
                              row["rowId"].str() ?? "", row["moduleName"].str() ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            PluginDetailFlow(spacing: 10) {
                sectionTitle(L.t("包含的组件", "Components"))
                if !rows.isEmpty {
                    Text(summary(counts)).font(.system(size: 12)).foregroundStyle(T.text2)
                }
            }
            if rows.count > 10 {
                TextField(L.t("筛选组件", "Filter components"), text: $filter)
                    .font(.system(size: 13)).foregroundStyle(T.ink)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(.horizontal, 10).frame(width: 200, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.borderL3, lineWidth: 0.5))
                    .accessibilityIdentifier("pluginComponentFilter")
            }
            if rows.isEmpty {
                status(L.t("这个插件包不包含任何组件。", "This plugin pack contains no components."))
            } else if shown.isEmpty {
                status(L.t("没有匹配的组件。", "No component matches."))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { index, row in
                        component(row)
                        if index < shown.count - 1 { Rectangle().fill(T.border).frame(height: 0.5) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pluginComponents")
    }

    private func component(_ row: JSONValue) -> some View {
        let live = pluginLiveRow(row, plugins: plugins)
        let rowId = row["rowId"].str() ?? ""
        let enabled = live?["enabled"].bool() == true
        let phase = live?["fiberPhase"].str()
        let namespace = row["rowId"].str().flatMap { id in namespaces.first { $0["ns"].str() == id } }
        return VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    artwork(row, row: true)
                    rowMain(row, namespace: namespace, enabled: enabled)
                    rowActions(row, live: live, enabled: enabled, phase: phase)
                }
                HStack(alignment: .top, spacing: 16) {
                    artwork(row, row: true)
                    VStack(alignment: .leading, spacing: 8) {
                        rowMain(row, namespace: namespace, enabled: enabled)
                        rowActions(row, live: live, enabled: enabled, phase: phase)
                    }
                }
            }
            metadataError(row)
            if !row["readOnlyReason"].isNull {
                reason(pluginDetailManagementText(row["readOnlyReason"]))
            } else if let live, !live["readOnlyReason"].isNull {
                reason(pluginDetailManagementText(live["readOnlyReason"]))
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pluginComponent.\(rowId)")
    }

    private func rowMain(_ row: JSONValue, namespace: JSONValue?, enabled: Bool) -> some View {
        let title = rowTitle(row)
        let rowId = row["rowId"].str() ?? ""
        return VStack(alignment: .leading, spacing: 2) {
            if let namespace {
                Button { onConfigure(namespace) } label: {
                    HStack(spacing: 2) {
                        Text(title).font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(enabled ? T.ink : T.text2)
                        OfficialGlyph(kind: .chevronRight, size: 14, color: T.text3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t("配置 \(title)", "Configure \(title)"))
                .accessibilityIdentifier("pluginConfigure.\(rowId)")
            } else {
                Text(title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(enabled ? T.ink : T.text2)
            }
            let description = pluginDescription(row, english: L.en)
            if !description.isEmpty { rowCaption(description) }
            if title != rowId && !rowId.isEmpty { rowCaption(rowId) }
            if let module = row["moduleName"].str(), title != module { rowCaption(module) }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowActions(_ row: JSONValue, live: JSONValue?, enabled: Bool, phase: String?) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                PluginComponentStateDot(enabled: enabled, phase: phase)
                Text(stateText(enabled: enabled, phase: phase))
                    .font(.system(size: 12.5)).foregroundStyle(phase == "failed" ? T.err : T.text2)
            }
            .fixedSize()
            if bundleEnabled {
                let entryId = row["entryId"].str()
                let mayWrite = !locked && canToggleRows && entryId != nil && live != nil
                    && row["readOnlyReason"].isNull && (live?["readOnlyReason"].isNull ?? true)
                PluginEnableSwitch(isOn: enabled, enabled: mayWrite,
                                   label: L.t("启用组件 \(rowTitle(row))", "Enable component \(rowTitle(row))")) { value in
                    guard mayWrite, let entryId else { return }
                    onToggleRow(entryId, value)
                }
                .accessibilityIdentifier("pluginRowToggle.\(entryId ?? row["rowId"].str() ?? "")")
            }
        }
    }

    @ViewBuilder
    private var source: some View {
        if bundle["source"].str() != nil || bundle["installed"].bool() == true
            || bundle["availability"].str() != "installation" || bundle["optional"].bool() == true {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L.t("来源信息", "Source"))
                VStack(spacing: 0) {
                    let source = bundle["source"].str()
                    sourceFact(L.t("代码来源", "Code source"), value: source ?? (missing
                        ? (bundle["installed"].bool() == true ? L.t("包不可用", "Package unavailable") : L.t("未安装", "Not installed"))
                        : L.t("内置", "Built in")), code: source != nil)
                    if let version = bundle["version"].str() {
                        sourceFact(L.t("当前版本", "Current version"), value: version)
                    }
                    if let spec = bundle["installTarget"]["spec"].str() {
                        sourceFact(L.t("当前 DSH 对应来源", "Source for this DSH"), value: spec, code: true)
                    }
                    if let version = bundle["installTarget"]["version"].str() {
                        sourceFact(L.t("当前 DSH 对应版本", "Version for this DSH"), value: version)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pluginSource")
        }
    }

    private func sourceFact(_ label: String, value: String, code: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label).font(.system(size: 13)).foregroundStyle(T.text2).fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
            Text(value).font(.system(size: code ? 12 : 13, design: code ? .monospaced : .default))
                .foregroundStyle(T.ink).multilineTextAlignment(.trailing).textSelection(.enabled)
                .padding(.horizontal, code ? 6 : 0).padding(.vertical, code ? 2 : 0)
                .background(code ? T.fill2 : .clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 2).padding(.vertical, 8).frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(T.border).frame(height: 0.5) }
    }

    private func artwork(_ value: JSONValue, row: Bool) -> some View {
        Group {
            if row && pluginMetadataSVG(value["meta"]["icon"].str()) == nil {
                PluginArtwork(kind: "subagent", size: 30)
            } else {
                PluginMetadataArtwork(icon: value["meta"]["icon"].str(), size: row ? 30 : 36)
            }
        }
        .frame(width: row ? 40 : 48, height: row ? 40 : 48)
        .overlay(RoundedRectangle(cornerRadius: row ? 8 : 12).stroke(T.borderL3, lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    private func tag(_ text: String, color: Color? = nil, version: Bool = false, outline: Bool = false) -> some View {
        Text(text).font(.system(size: version ? 11 : 10, weight: .medium)).monospacedDigit()
            .foregroundStyle(color ?? (outline ? T.text3 : T.text2))
            .padding(.horizontal, version ? 8 : 7).frame(height: version ? 19 : 18)
            .background(outline ? .clear : (color?.opacity(0.1) ?? T.fill2), in: Capsule())
            .overlay(Capsule().stroke(outline ? T.borderStrong : .clear, lineWidth: 0.5))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink)
    }

    private func status(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(T.text2)
    }

    private func rowCaption(_ text: String) -> some View {
        Text(text).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(T.text3)
    }

    private func reason(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(T.err).lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
    }

    @ViewBuilder
    private func metadataError(_ value: JSONValue) -> some View {
        if let error = value["meta"]["error"].str() {
            reason(L.t("包元信息错误：\(error)", "Package metadata error: \(error)"))
        }
    }

    private func rowTitle(_ row: JSONValue) -> String {
        pluginLocalized(row["meta"]["title"], english: L.en) ?? row["moduleName"].str() ?? row["rowId"].str() ?? ""
    }

    private func summary(_ counts: PluginParts) -> String {
        var parts = [L.t("共 \(counts.total) 个", "\(counts.total) total")]
        if counts.running > 0 { parts.append(L.t("\(counts.running) 运行中", "\(counts.running) running")) }
        if counts.off > 0 { parts.append(L.t("\(counts.off) 已停用", "\(counts.off) off")) }
        if counts.failed > 0 { parts.append(L.t("\(counts.failed) 异常", "\(counts.failed) failed")) }
        return parts.joined(separator: " · ")
    }

    private func stateText(enabled: Bool, phase: String?) -> String {
        guard enabled else { return L.t("已关闭", "Off") }
        switch phase {
        case "pending": return L.t("等待依赖", "Waiting for dependencies")
        case "loading": return L.t("加载中", "Loading")
        case "active": return L.t("运行中", "Running")
        case "failed": return L.t("异常", "Problem")
        case "unloading": return L.t("卸载中", "Unloading")
        case nil: return L.t("未运行", "Not running")
        default: return phase ?? ""
        }
    }
}

struct PluginEnableSwitch: View {
    let isOn: Bool
    let enabled: Bool
    let label: String
    let onChange: (Bool) -> Void

    @ViewBuilder
    var body: some View {
        if #available(iOS 17.0, *) {
            control.accessibilityAddTraits(.isToggle)
        } else {
            control.accessibilityRepresentation {
                Toggle(label, isOn: Binding(get: { isOn }, set: change)).disabled(!enabled)
            }
        }
    }

    private var control: some View {
        Button { change(!isOn) } label: {
            Capsule().fill(isOn ? T.primaryButton : T.borderL3)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(isOn ? T.onPrimary : (ThemeStateHolder.shared.dark ? Color(hex: 0xFFADB2B8) : .white))
                        .frame(width: 16, height: 16).padding(2)
                }
                .frame(width: 36, height: 20)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.12), value: isOn)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? L.t("开", "On") : L.t("关", "Off"))
    }

    private func change(_ value: Bool) {
        guard enabled else { return }
        onChange(value)
    }
}

private struct PluginComponentStateDot: View {
    let enabled: Bool
    let phase: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false

    var body: some View {
        Group {
            if enabled && (phase == "loading" || phase == "unloading") {
                ZStack {
                    Circle().stroke(T.text3.opacity(0.25), lineWidth: 1)
                    Circle().trim(from: 0, to: 0.25).stroke(T.text3, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(rotating && !reduceMotion ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 1.5).repeatForever(autoreverses: false), value: rotating)
                .onAppear { rotating = true }
            } else {
                Circle().fill(!enabled ? T.text3 : phase == "active" ? T.ok : phase == "failed" ? T.err : T.text3)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 10, height: 10).accessibilityHidden(true)
    }
}

private struct PluginDetailFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(subviews, width: bounds.width)
        for (index, point) in layout.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                                 anchor: .topLeading, proposal: ProposedViewSize(width: min(bounds.width, subviews[index].sizeThatFits(.unspecified).width), height: nil))
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(width, ideal.width), height: nil))
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: usedWidth, height: y + lineHeight), origins)
    }
}

private func pluginDetailManagementText(_ error: JSONValue) -> String {
    let code = error.str() ?? error["code"].str() ?? ""
    switch code {
    case "management-required": return L.t("插件管理所需，不能停用或卸载", "Plugin management needs it; it cannot be switched off or uninstalled.")
    case "unaddressable": return L.t("当前 profile 的 patch 无法唯一定位这一项", "The profile patch cannot address this one uniquely.")
    case "unknown-plugin": return L.t("找不到该插件", "No such plugin.")
    case "invalid-spec": return L.t("请输入有效的包名或地址", "Enter a valid package name or address.")
    case "already-installed": return L.t("这个包已经安装；要安装其他版本，请先卸载它", "This package is already installed; uninstall it before installing another version.")
    case "ambiguous-install": return L.t("无法从依赖变更中确定安装了哪一个包", "Which package was installed cannot be told from the dependency change.")
    case "not-bundle": return L.t("这个包没有声明组合包，不能作为插件管理", "This package declares no bundle, so it cannot be managed as a plugin.")
    case "not-removable": return L.t("这个包不属于当前 profile，或者是插件管理所需的组件", "This package is not owned by the profile, or plugin management needs it.")
    case "stop-profile": return L.t("这个 profile 没有启用 HMR，正在使用的包要停止后用 dsh plugin 卸载", "This profile runs without HMR; stop it and uninstall the package with dsh plugin.")
    case "bundle-in-use": return L.t("其他配置仍在使用这个组合包的组件，请先停用它们", "Other configuration still uses this bundle's components; switch them off first.")
    case "stale-approval": return L.t("待允许的安装脚本列表已变化，请重新安装以刷新", "The pending script approvals changed; install again to refresh them.")
    case "incompatible-version":
        let named = error["incompatible"].arr() ?? []
        var sentences = named.map { plugin in
            let name = (plugin["name"].str() ?? "") + "@" + (plugin["version"].str() ?? "")
            let runtime = plugin["runtimeVersion"].str() ?? ""
            let requirements = (plugin["requirements"].obj() ?? [:]).sorted { $0.key < $1.key }
                .map { "\($0.key) \($0.value.str() ?? "")" }.joined(separator: ", ")
            return L.t("\(name) 与 DSH \(runtime) 不兼容（要求 \(requirements)），运行它可能导致崩溃或数据丢失。",
                       "\(name) is incompatible with DSH \(runtime) (requires \(requirements)); running it may cause crashes or data loss.")
        }
        if sentences.isEmpty {
            sentences.append(L.t("这个插件与当前 DSH 版本不兼容，运行它可能导致崩溃或数据丢失。", "This plugin is incompatible with the running DSH version; running it may cause crashes or data loss."))
        }
        sentences.append(L.t("请卸载后重新安装与当前 DSH 兼容的版本。", "Uninstall it and install a version compatible with this DSH."))
        return sentences.joined(separator: L.en ? " " : "")
    default:
        if let diagnostic = error["diagnostic"].str(), !diagnostic.isEmpty { return diagnostic }
        if let message = error["message"].str(), !message.isEmpty { return message }
        return code.isEmpty || code == "operation-error" ? L.t("Host 报告了一个错误", "The Host reported an error.") : code
    }
}
