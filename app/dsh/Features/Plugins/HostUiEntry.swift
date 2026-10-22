import SwiftUI

struct HostUiEntry: View {
    @ObservedObject var model: AppModel
    var section: String? = nil
    var enabled = true

    private var supported: Bool { model.ops.contains("ui.open") && model.ops.contains("ui.close") }
    private var systemSupported: Bool {
        if #available(iOS 18.4, *) { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { model.openHostUi(section: section) } label: {
                Text(L.t("打开插件自定义界面", "Open plugin Web interfaces"))
                    .font(.system(size: 14))
                    .foregroundStyle(systemSupported && model.isOnline && supported && enabled ? T.link : T.text3)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(!systemSupported || !model.isOnline || !supported || !enabled)
            .accessibilityIdentifier("hostUiEntry.\(section ?? "plugins")")
            if !systemSupported {
                notice(L.t("插件自定义界面需要 iOS 18.4 或更新版本；原生插件管理仍可使用。", "Plugin Web interfaces require iOS 18.4 or later. Native plugin management remains available."))
            } else if !model.isOnline {
                notice(L.t("连接主机后可用", "Available while connected to the Host"))
            } else if !supported {
                notice(L.t("此 Host 未提供完整的插件界面会话接口，请更新桌面端手机连接插件。", "This Host lacks the complete plugin UI session API. Update its phone-connection plugin."))
            }
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(T.text3).fixedSize(horizontal: false, vertical: true)
    }
}
