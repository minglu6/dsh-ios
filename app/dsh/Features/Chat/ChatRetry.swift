import SwiftUI
import DSHProtocol

func retrySeconds(_ milliseconds: Int64) -> Int64 {
    if milliseconds <= 1000 { return 1 }
    return milliseconds / 1000 + (milliseconds % 1000 == 0 ? 0 : 1)
}

func retryRemainingSeconds(delayMs: Int64, elapsedMs: Int64) -> Int64 {
    retrySeconds(max(delayMs, 0) - max(elapsedMs, 0))
}

func chatFailureMessage(_ message: String, code: String?, en: Bool) -> String {
    switch code {
    case "ACCOUNT_SIGNED_OUT":
        return en ? "Stopped because you signed out of DeepSeek." : "任务已因退出 DeepSeek 登录而停止。"
    case "ACCOUNT_SIGN_IN_REQUIRED":
        return en ? "Sign in to DeepSeek and ensure the request destination supports account authentication." : "请先登录 DeepSeek，并确认请求地址支持账号认证。"
    case "QUOTA", "ACCOUNT_QUOTA", "QUOTA_EXCEEDED":
        return en ? "Request quota exhausted." : "当前请求的额度已用尽"
    case "AUTH", "AUTH_ERROR", "INVALID_API_KEY":
        return en ? "API key is invalid" : "API 密钥无效"
    default:
        return message
    }
}

struct RetryRow: View {
    let item: Item.Retry
    @State private var expanded = false
    @State private var remaining: Int64 = 1
    @State private var renderedAt = Date()

    var body: some View {
        if let attempt = item.attempts.last {
            let active = attempt.state == .scheduled
            let label: String = {
                switch attempt.state {
                case .scheduled: return L.t("正在重试模型请求", "Retrying model request")
                case .started: return L.t("已重试模型请求", "Retried model request")
                case .cancelled: return L.t("模型请求重试已取消", "Model request retry cancelled")
                }
            }()
            let maximum = attempt.mode == "always" ? "∞" : (attempt.maxRetries.map(String.init) ?? "?")
            let seconds = active ? remaining : retrySeconds(attempt.delayMs)
            let summary = L.en
                ? "\(label) (\(attempt.retry)/\(maximum)) · \(seconds)s"
                : "\(label)（\(attempt.retry)/\(maximum)） · \(seconds)s"
            VStack(alignment: .leading, spacing: 4) {
                Button { expanded.toggle() } label: {
                    HStack {
                        if active { ProgressView().controlSize(.mini) }
                        Text(summary)
                            .font(.system(size: CGFloat(AppPrefs.fontSize - 1)))
                            .foregroundStyle(T.text3)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .rotationEffect(.degrees(expanded ? 0 : -90))
                            .foregroundStyle(T.text3)
                    }
                    .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                if expanded {
                    VStack(alignment: .leading, spacing: 2) {
                        detail(L.t("重试延迟：", "Retry delay: "), L.en ? "\(attempt.delayMs) ms" : "\(attempt.delayMs) 毫秒")
                        detail(L.t("失败原因：", "Failure reason: "), chatFailureMessage(attempt.message, code: attempt.code, en: L.en))
                    }
                    .padding(.leading, 14)
                    .padding(.top, 3)
                }
            }
            .onAppear {
                remaining = retrySeconds(attempt.delayMs)
                renderedAt = Date()
            }
            .task(id: "\(item.key)-\(attempt.seq)-\(attempt.delayMs)-\(active)") {
                guard active else { return }
                repeat {
                    let elapsed = Int64(Date().timeIntervalSince(renderedAt) * 1000)
                    remaining = retryRemainingSeconds(delayMs: attempt.delayMs, elapsedMs: elapsed)
                    if remaining > 1 {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                    }
                } while remaining > 1 && !Task.isCancelled
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        (Text(label).foregroundStyle(T.text2) + Text(value).foregroundStyle(T.text3))
            .font(.system(size: CGFloat(AppPrefs.fontSize - 1)))
    }
}

struct TurnFailureRow: View {
    let item: Item.TurnFailure

    var body: some View {
        let title = item.code == "ACCOUNT_SIGNED_OUT"
            ? L.t("任务已停止", "Task stopped")
            : L.t("本轮运行失败", "This turn failed")
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(T.err).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                (Text(title).foregroundStyle(T.err).fontWeight(.semibold) + Text("  ") + Text(chatFailureMessage(item.message, code: item.code, en: L.en)))
                    .font(.system(size: CGFloat(AppPrefs.fontSize - 1)))
                    .foregroundStyle(T.text2)
                if let code = item.code {
                    Text(code)
                        .font(.system(size: CGFloat(AppPrefs.fontSize - 1), design: .monospaced))
                        .foregroundStyle(T.text3)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
