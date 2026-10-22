import SwiftUI

struct PluginInstallDialog: View {
    @Binding var spec: String
    @Binding var registry: String
    let registries: [String]
    let resolvedRegistry: String?
    let checking: Bool
    let installing: Bool
    let pending: Bool
    let cancelling: Bool
    let canInstall: Bool
    let canCancel: Bool
    let error: String?
    let result: String?
    let onInstall: () -> Void
    let onCancel: () -> Void
    let onClose: () -> Void

    @ObservedObject private var theme = ThemeStateHolder.shared
    @State private var guideOpen = false
    @State private var registryOpen = false
    @State private var customSelected = false
    @State private var customDraft = ""
    @State private var heights: [String: CGFloat] = [:]
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case spec, registry }
    private let example = "dsh-plugin-whale-pet"
    private var busy: Bool { checking || installing || pending || cancelling }
    private var customValid: Bool {
        guard let url = URLComponents(string: registry.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
    private var enabled: Bool {
        canInstall && !busy && !spec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!customSelected || customValid)
    }
    private var offered: [String] {
        var values: [String] = []
        for value in registries + ["https://registry.npmjs.org/", "https://registry.npmmirror.com/"] {
            if !value.isEmpty && !values.contains(where: { normalized($0) == normalized(value) }) {
                values.append(value)
            }
        }
        return values
    }

    var body: some View {
        GeometryReader { geometry in
            let available = max(0, min(800, geometry.size.height - 48))
            ZStack {
                T.scrim.ignoresSafeArea().onTapGesture { close() }
                card(available: available)
                    .frame(width: max(0, min(560, geometry.size.width - 48)))
                    .background(T.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(T.borderL1, lineWidth: 0.5))
                    .shadow(color: .black.opacity(theme.dark ? 0.35 : 0.16), radius: 24, y: 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityIdentifier("pluginInstallDialog")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlayPreferenceValue(PluginRegistryAnchorKey.self) { anchor in
                if registryOpen, let anchor {
                    registryOverlay(size: geometry.size, toggle: geometry[anchor])
                }
            }
        }
        .onPreferenceChange(PluginInstallHeightKey.self) { next in
            heights.merge(next) { _, new in new }
        }
        .onAppear {
            customSelected = !registry.isEmpty && !offered.contains { normalized($0) == normalized(registry) }
            if customSelected { customDraft = registry }
        }
        .onChange(of: checking) { _ in dismissRegistry() }
        .onChange(of: installing) { _ in dismissRegistry() }
        .onChange(of: pending) { _ in dismissRegistry() }
        .onChange(of: cancelling) { _ in dismissRegistry() }
        .onChange(of: error) { _ in dismissRegistry() }
        .onChange(of: result) { _ in dismissRegistry() }
        .onChange(of: canInstall) { _ in dismissRegistry() }
        .onChange(of: focusedField) { field in
            if field == .registry && !customSelected { selectCustom() }
        }
    }

    private func card(available: CGFloat) -> some View {
        let headerHeight = heights["header"] ?? 62
        let footerHeight = heights["footer"] ?? 200
        let bodyHeight = heights["body"] ?? 110
        let compact = available < headerHeight + footerHeight + 100
        return VStack(spacing: 0) {
            header.measureInstallHeight("header")
            if compact {
                ScrollView {
                    VStack(spacing: 20) {
                        content
                        footer
                    }
                    .padding(.bottom, 24)
                }
                .frame(height: max(0, available - headerHeight))
            } else {
                ScrollView {
                    content.measureInstallHeight("body")
                }
                .frame(height: min(bodyHeight, max(0, available - headerHeight - footerHeight - 44)))
                footer.measureInstallHeight("footer")
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(L.t("添加插件", "Add plugin"))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(T.ink)
            Spacer(minLength: 0)
            Button(action: close) {
                OfficialGlyph(kind: .closeOutline, size: 16, color: T.text2)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(L.t("关闭", "Close"))
            .accessibilityIdentifier("pluginInstallClose")
        }
        .padding(.leading, 24).padding(.trailing, 14)
        .padding(.top, 22).padding(.bottom, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L.t("输入插件的包名、GitHub 仓库地址或本地目录路径。", "Enter the plugin's package name, GitHub repository address, or local directory path."))
                .font(.system(size: 14)).foregroundStyle(T.ink).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                TextField(L.t("例如 dsh-plugin-whale-pet", "for example dsh-plugin-whale-pet"), text: $spec)
                    .font(.system(size: 13)).foregroundStyle(T.ink)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focusedField, equals: .spec)
                    .submitLabel(.go).onSubmit { run() }
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(T.surface3, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(focusedField == .spec ? T.businessPrimary : T.borderStrong, lineWidth: focusedField == .spec ? 1 : 0.5))
                    .disabled(busy)
                    .accessibilityLabel(L.t("包名或地址", "Package name or address"))
                    .accessibilityIdentifier("pluginInstallSpec")
                if let error { status(error, color: T.err) }
                if let result { status(result, color: T.text2) }
                if busy { status(progressText, color: T.text2) }
                if error == nil, let templateHint { status(templateHint, color: T.text2) }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { guideToggle; Spacer(minLength: 8); registryToggle }
                    VStack(alignment: .leading, spacing: 8) {
                        guideToggle
                        registryToggle.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                if guideOpen { guide }
            }
        }
        .padding(.horizontal, 24)
    }

    private var guideToggle: some View {
        Button { guideOpen.toggle() } label: {
            HStack(spacing: 4) {
                OfficialGlyph(kind: .chevronDown, size: 14, color: T.text2).rotationEffect(.degrees(guideOpen ? 180 : 0))
                Text(guideOpen ? L.t("收起引导", "Hide the guide") : L.t("插件安装引导和示例", "Install guide and examples"))
            }
            .font(.system(size: 12.5)).foregroundStyle(T.text2).fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityValue(guideOpen ? L.t("已展开", "Expanded") : L.t("已折叠", "Collapsed"))
        .accessibilityIdentifier("pluginInstallGuideToggle")
    }

    private var registryToggle: some View {
        Button { registryOpen.toggle() } label: {
            HStack(spacing: 6) {
                Text(L.t("安装源", "Registry")).foregroundStyle(T.text2)
                Text(customSelected ? L.t("自定义地址", "Custom address") : registryName(registry))
                    .fontWeight(.medium).foregroundStyle(T.ink).lineLimit(1)
                OfficialGlyph(kind: .chevronDown, size: 14, color: T.text2)
                    .rotationEffect(.degrees(registryOpen ? 180 : 0))
            }
            .font(.system(size: 12.5))
            .padding(.leading, 10).padding(.trailing, 8).frame(height: 28)
            .background(registryOpen ? T.surface3 : T.surface2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(registryOpen ? T.borderL3 : T.borderStrong, lineWidth: 0.5))
        }
        .buttonStyle(.plain).disabled(busy).opacity(busy ? 0.6 : 1)
        .accessibilityValue(registryOpen ? L.t("已展开", "Expanded") : L.t("已折叠", "Collapsed"))
        .accessibilityIdentifier("pluginInstallRegistryToggle")
        .anchorPreference(key: PluginRegistryAnchorKey.self, value: .bounds) { $0 }
    }

    private var guide: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L.t("填入插件 npm 包名", "Enter the plugin's npm package name"))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(T.ink)
                Text(L.t("插件包名即 npm 包名（如 dsh-xxx 或 @作者/插件名），社区插件的 README 安装命令中 dsh plugin add 或 pnpm add 之后的部分。", "The plugin package name is the npm package name (like dsh-xxx or @author/plugin): the part after dsh plugin add or pnpm add in a community plugin's README install command."))
                    .font(.system(size: 12)).foregroundStyle(T.text3).lineSpacing(4).padding(.top, 6)
                (Text(L.t("示例：", "Example: ")) + Text(example).font(.system(size: 12, design: .monospaced)))
                    .font(.system(size: 12)).foregroundStyle(T.text3).padding(.top, 2)
            }
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Button { spec = example } label: {
                Text(L.t("填入示例", "Use example"))
                    .font(.system(size: 12)).foregroundStyle(T.ink)
                    .padding(.horizontal, 10).frame(height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.borderL3, lineWidth: 0.5))
            }
            .buttonStyle(.plain).fixedSize().disabled(busy)
            .accessibilityLabel(L.t("填入示例 ", "Use the example ") + example)
            .accessibilityIdentifier("pluginInstallExample.0")
        }
        .padding(.horizontal, 14).padding(.vertical, 16)
        .background(T.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.borderStrong, lineWidth: 0.5))
        .accessibilityElement(children: .contain).accessibilityIdentifier("pluginInstallGuide")
    }

    private var footer: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 8) {
                OfficialGlyph(kind: .warningOutline, size: 14, color: Color(hex: 0xFFF59E0B))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("请确认插件来源可信。插件在本机以你的权限运行，来源不明的插件可能损坏 DeepSeek Harness，或读取和泄露你的数据。", "Install only plugins you trust: they run with your permissions and can damage DeepSeek Harness or leak your data."))
                    Text(L.t("按需安装的官方插件会在版本与 DSH 不同时提供“更新”。其他插件请先卸载再安装新版。", "On-demand Official plugins offer Update when their version differs from DSH. To update other plugins, uninstall and reinstall them."))
                }
                .font(.system(size: 12)).foregroundStyle(T.text2).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(T.warnTint, in: RoundedRectangle(cornerRadius: 12))
            Button(action: run) {
                HStack(spacing: 6) {
                    if busy { ProgressView().controlSize(.small).tint(T.onPrimary) }
                    Text(busy ? progressText : L.t("安装", "Install"))
                }
                .font(.system(size: 14)).foregroundStyle(T.onPrimary)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                .opacity(enabled ? 1 : 0.4)
            }
            .buttonStyle(.plain).disabled(!enabled).accessibilityIdentifier("pluginInstallRun")
            if installing || pending || cancelling {
                Button(action: onCancel) {
                    Text(cancelling ? L.t("正在停止安装…", "Stopping installation…") : L.t("停止安装", "Stop installation"))
                        .font(.system(size: 12)).foregroundStyle(T.ink)
                        .padding(.horizontal, 10).frame(height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.borderL3, lineWidth: 0.5))
                }
                .buttonStyle(.plain).disabled(!canCancel || cancelling)
                .accessibilityIdentifier("pluginInstallCancel")
            }
        }
        .padding(.horizontal, 24)
    }

    private func registryOverlay(size: CGSize, toggle: CGRect) -> some View {
        let width = max(0, min(440, size.width - 24))
        let height = min(heights["registry"] ?? 400, max(0, size.height - 24))
        let x = min(max(12, toggle.maxX - width), max(12, size.width - width - 12))
        let y = min(max(12, toggle.maxY + 6), max(12, size.height - height - 12))
        return ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle()).onTapGesture { dismissRegistry() }
            ScrollView {
                registryOptions.measureInstallHeight("registry")
            }
            .frame(width: width, height: height)
            .background(T.surface2, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.borderL1, lineWidth: 0.5))
            .shadow(color: .black.opacity(theme.dark ? 0.35 : 0.16), radius: 20, y: 6)
            .offset(x: x, y: y)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L.t("从哪个 npm 源下载插件", "The npm registry the plugin is downloaded from"))
            .accessibilityIdentifier("pluginInstallRegistryPanel")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var registryOptions: some View {
        VStack(alignment: .leading, spacing: 4) {
            registryOption("", id: "default")
            ForEach(Array(offered.enumerated()), id: \.element) { index, value in
                registryOption(value, id: String(index))
            }
            VStack(alignment: .leading, spacing: 4) {
                Button(action: selectCustom) {
                    HStack(spacing: 10) {
                        radio(customSelected)
                        Text(L.t("自定义地址", "Custom address")).font(.system(size: 13)).foregroundStyle(T.ink)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(customSelected ? .isSelected : [])
                .accessibilityIdentifier("pluginInstallRegistryOption.custom")
                TextField("https://npm.example.com/", text: Binding(get: { customDraft }, set: {
                    customDraft = $0
                    customSelected = true
                    registry = $0
                }))
                .font(.system(size: 13)).foregroundStyle(T.ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                .focused($focusedField, equals: .registry).submitLabel(.go).onSubmit { run() }
                .padding(.horizontal, 10).frame(height: 36)
                .background(T.surface3, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(customSelected && !customValid ? T.err : focusedField == .registry ? T.businessPrimary : T.borderStrong, lineWidth: 0.5))
                .accessibilityLabel(L.t("自定义地址", "Custom address"))
                .accessibilityIdentifier("pluginInstallRegistryCustom")
                if customSelected && !customValid {
                    status(L.t("请输入以 http:// 或 https:// 开头的地址", "Enter an address starting with http:// or https://"), color: T.err)
                }
                status(L.t("填写内网或私有 npm 源地址，以 http:// 或 https:// 开头。若为需要登录的源，请把凭据放在本机的 ~/.npmrc 里。", "Enter an internal or private npm registry address starting with http:// or https://. If it requires a login, store the credentials in ~/.npmrc on this machine."), color: T.text3)
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
        }
        .padding(8)
    }

    private func registryOption(_ value: String, id: String) -> some View {
        let selected = !customSelected && normalized(registry) == normalized(value)
        let host = URLComponents(string: value.isEmpty ? (resolvedRegistry ?? "https://registry.npmjs.org/") : value)?.host ?? value
        return Button {
            customSelected = false
            registry = value
            focusedField = nil
        } label: {
            HStack(alignment: .top, spacing: 10) {
                radio(selected).padding(.top, 2)
                (Text(registryName(value)).foregroundColor(T.ink)
                    + Text(registryName(value) == host ? "" : "  " + host)
                        .font(.system(size: 12)).foregroundColor(T.text3))
                    .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8).padding(.horizontal, 10).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("pluginInstallRegistryOption." + id)
    }

    private func radio(_ selected: Bool) -> some View {
        Circle().strokeBorder(selected ? T.primaryButton : T.borderL3, lineWidth: selected ? 4.5 : 1)
            .frame(width: 16, height: 16).accessibilityHidden(true)
    }

    private func registryName(_ value: String) -> String {
        guard !value.isEmpty || resolvedRegistry != nil else { return L.t("默认安装源", "Default registry") }
        let url = value.isEmpty ? (resolvedRegistry ?? "") : value
        let host = URLComponents(string: url)?.host ?? url
        switch host {
        case "registry.npmjs.org": return L.t("npm 官方源", "Official npm registry")
        case "registry.npmmirror.com": return L.t("中国大陆镜像源", "Mainland China mirror")
        default: return host
        }
    }

    private var progressText: String {
        if cancelling { return L.t("正在停止安装…", "Stopping installation…") }
        if checking { return L.t("正在检查…", "Checking…") }
        return L.t("正在安装…", "Installing…")
    }

    private var templateHint: String? {
        switch spec {
        case "https://github.com/author/dsh-plugin": return L.t("请替换为实际的 Git 仓库地址", "Replace this with the actual Git repository address.")
        case "/Users/name/my-plugin": return L.t("请替换为本机插件目录的实际路径", "Replace this with the actual path to your local plugin directory.")
        default: return nil
        }
    }

    private func status(_ value: String, color: Color) -> some View {
        Text(value).font(.system(size: 12)).foregroundStyle(color).lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func selectCustom() {
        customSelected = true
        registry = customDraft
        focusedField = .registry
    }

    private func dismissRegistry() {
        registryOpen = false
        if focusedField == .registry { focusedField = nil }
    }

    private func close() {
        if registryOpen { dismissRegistry() } else { onClose() }
    }

    private func run() {
        guard enabled else { return }
        dismissRegistry()
        focusedField = nil
        if customSelected { registry = registry.trimmingCharacters(in: .whitespacesAndNewlines) }
        onInstall()
    }
}

private struct PluginInstallHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct PluginRegistryAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private extension View {
    func measureInstallHeight(_ key: String) -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: PluginInstallHeightKey.self, value: [key: geometry.size.height])
        })
    }
}
