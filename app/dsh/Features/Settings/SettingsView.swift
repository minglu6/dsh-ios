import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header(L.settings()) { model.pop() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card {
                        nav(L.generalNav(), "slider.horizontal.3") { model.push(.general) }
                        nav(L.modelsNav(), "cpu", divider: hasPluginSettings || hasScheduleSettings) { model.push(.models) }
                        if hasPluginSettings {
                            nav(L.builtinPluginsNav(), "puzzlepiece.extension", divider: hasScheduleSettings) { model.push(.panel(.plugins)) }
                        }
                        if hasScheduleSettings {
                            nav(L.scheduleNav(), "calendar", divider: false) { model.push(.panel(.schedule)) }
                        }
                    }
                    Text(L.phoneConnection())
                        .font(.caption)
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 22)
                    card {
                        nav(L.connections(), "link", value: model.activeProfile?.name ?? L.notConnected(), divider: false) {
                            model.push(.connections)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
    }

    private var hasPluginSettings: Bool { model.ops.contains("plugins.inventory") }
    private var hasScheduleSettings: Bool { model.ops.contains("schedule.catalog") }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header(L.generalNav()) { model.pop() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card {
                        picker(L.appearance(), selection: Binding(
                            get: { model.appearance },
                            set: { model.setAppearance($0) }
                        )) {
                            Text(L.light()).tag(Appearance.light)
                            Text(L.dark()).tag(Appearance.dark)
                            Text(L.followSystem()).tag(Appearance.system)
                        }
                        picker(L.language(), selection: Binding(
                            get: { model.language },
                            set: { model.setLanguage($0) }
                        ), divider: false) {
                            Text("中文").tag(AppLanguage.zh)
                            Text("English").tag(AppLanguage.en)
                        }
                    }
                    Text("\(L.currentVersion())：\(AppModel.appVersion)")
                        .font(.caption)
                        .foregroundStyle(T.caption)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
    }
}

struct ModelsSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header(L.modelsNav()) { model.pop() }
            List {
                ForEach(model.catalog?.groups ?? []) { group in
                    Section(group.name) {
                        ForEach(group.models) { info in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(info.name).foregroundStyle(T.ink)
                                if let description = info.description {
                                    Text(description).font(.caption).foregroundStyle(T.text3)
                                }
                            }
                        }
                    }
                }
                if let failures = model.catalog?.failures, !failures.isEmpty {
                    Section {
                        ForEach(failures, id: \.id) { failure in
                            Text("\(failure.name): \(failure.message)").foregroundStyle(T.err)
                        }
                    }
                }
            }
        }
        .background(T.bg.ignoresSafeArea())
    }
}

func header(_ title: String, back: @escaping () -> Void) -> some View {
    HStack {
        Button(action: back) { Image(systemName: "chevron.left").foregroundStyle(T.ink) }
        Text(title).font(.headline).foregroundStyle(T.ink)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(T.surface)
}

func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) { content() }
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 16)
}

func nav(_ title: String, _ system: String, value: String? = nil, divider: Bool = true, action: @escaping () -> Void) -> some View {
    VStack(spacing: 0) {
        Button(action: action) {
            HStack {
                Image(systemName: system).foregroundStyle(T.text2)
                Text(title).foregroundStyle(T.ink)
                Spacer()
                if let value {
                    Text(value).font(.subheadline).foregroundStyle(T.text3)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(T.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        if divider { Divider().padding(.leading, 16) }
    }
}

func picker<Selection: Hashable, Content: View>(
    _ title: String,
    selection: Binding<Selection>,
    divider: Bool = true,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(spacing: 0) {
        HStack {
            Text(title).foregroundStyle(T.ink)
            Spacer()
            Picker("", selection: selection, content: content)
                .labelsHidden()
                .tint(T.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        if divider { Divider().padding(.leading, 16) }
    }
}
