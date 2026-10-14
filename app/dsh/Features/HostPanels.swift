import SwiftUI
import DSHProtocol

/// Host surfaces that share official desktop semantics. Chat-loop first;
/// trajectory / PTY / file tree remain module-bounded until the matching
/// inspector and emulator ports land.
struct HostPanelView: View {
    @ObservedObject var model: AppModel
    let panel: DrawerPanel

    var body: some View {
        VStack(spacing: 0) {
            header(title) { model.pop() }
            switch panel {
            case .plugins: PluginsPanel(model: model)
            case .schedule: SchedulePanel(model: model)
            case .files, .terminal, .trajectory, .jobs, .settings:
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(T.bg)
                    .onAppear { model.pop() }
            }
        }
        .background(T.bg.ignoresSafeArea())
    }

    private var title: String {
        switch panel {
        case .plugins: return L.pluginsNav()
        case .schedule: return L.scheduleNav()
        case .files: return L.files()
        case .terminal: return L.terminal()
        case .trajectory: return L.trajectory()
        case .jobs: return L.jobs()
        case .settings: return L.settings()
        }
    }

}

struct PluginsPanel: View {
    @ObservedObject var model: AppModel
    @State private var rows: [JSONValue] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let error {
                Text(error).foregroundStyle(T.err).padding()
            } else if !loaded {
                Text(L.loading()).foregroundStyle(T.text3).padding()
            } else if rows.isEmpty {
                Color.clear
            } else {
                List(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(row["name"].str() ?? row["id"].str() ?? row["bundle"].str() ?? "").foregroundStyle(T.ink)
                            if let id = row["id"].str() ?? row["bundle"].str() {
                                Text(id).font(.caption).foregroundStyle(T.text3)
                            }
                        }
                        Spacer()
                        Text((row["enabled"].bool() == true) ? (L.en ? "Enabled" : "已启用") : (L.en ? "Disabled" : "已停用"))
                            .font(.caption)
                            .foregroundStyle(row["enabled"].bool() == true ? T.ok : T.text3)
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard model.ops.contains("plugins.list") else {
            loaded = true
            return
        }
        do {
            let result = try await PocketCall.pluginsList()
            rows = result["plugins"].arr() ?? result["items"].arr() ?? result["entries"].arr() ?? []
            loaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SchedulePanel: View {
    @ObservedObject var model: AppModel
    @State private var rows: [JSONValue] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let error {
                Text(error).foregroundStyle(T.err).padding()
            } else if !loaded {
                Text(L.loading()).foregroundStyle(T.text3).padding()
            } else if rows.isEmpty {
                Color.clear
            } else {
                List(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading) {
                        Text(row["title"].str() ?? row["id"].str() ?? "").foregroundStyle(T.ink)
                        if let next = row["nextRun"].str() ?? row["next"].str() {
                            Text(next).font(.caption).foregroundStyle(T.text3)
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let sessionId = model.chat?.sessionId,
              model.ops.contains("schedule.list") || model.ops.contains("schedule.catalog") else {
            loaded = true
            return
        }
        do {
            let result = try await PocketCall.scheduleList(sessionId: sessionId)
            rows = result["tasks"].arr() ?? result["items"].arr() ?? []
            loaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Narrow bridge so feature panels can call the live client without exposing it.
enum PocketCall {
    static func pluginsList() async throws -> JSONValue {
        try await AppModel.shared.call("plugins.list")
    }

    static func scheduleList(sessionId: String) async throws -> JSONValue {
        try await AppModel.shared.call("schedule.list", args: jsonObject(["sessionId": .string(sessionId)]))
    }
}
