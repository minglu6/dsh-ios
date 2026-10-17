import SwiftUI
import DSHProtocol

struct RetryRow: View {
    let item: Item.Retry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(item.attempts.enumerated()), id: \.element.seq) { index, attempt in
                RetryAttemptRow(
                    attempt: attempt,
                    active: retryAttemptIsActive(state: attempt.state, isLast: index == item.attempts.count - 1)
                )
            }
        }
    }
}

private struct RetryAttemptRow: View {
    let attempt: RetryAttempt
    let active: Bool
    @State private var expanded = false
    @State private var remaining: Int64 = 1
    @State private var renderedAt = Date()

    var body: some View {
        let label = retryAttemptLabel(state: attempt.state, active: active, english: L.en)
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
                        .font(LocalFonts.text(size: CGFloat(AppPrefs.fontSize - 1)))
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
                    detail(L.en ? "Retry delay: " : "重试延迟：", retryDelayMilliseconds(delayMs: attempt.delayMs, english: L.en))
                    detail(L.en ? "Failure reason: " : "失败原因：", chatFailureMessage(attempt.message, code: attempt.code, en: L.en))
                }
                .padding(.leading, 14)
                .padding(.top, 3)
            }
        }
        .onAppear {
            remaining = retrySeconds(attempt.delayMs)
            renderedAt = Date()
        }
        .task(id: "\(attempt.seq)-\(attempt.delayMs)-\(active)") {
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

    private func detail(_ label: String, _ value: String) -> some View {
        (Text(label).foregroundColor(T.text2) + Text(value).foregroundColor(T.text3))
            .font(LocalFonts.text(size: CGFloat(AppPrefs.fontSize - 1)))
    }
}

struct TurnFailureRow: View {
    let item: Item.TurnFailure

    var body: some View {
        let title = turnFailureTitle(code: item.code, english: L.en)
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(T.err).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                (Text(title).foregroundColor(T.err).fontWeight(.semibold) + Text("  ") + Text(chatFailureMessage(item.message, code: item.code, en: L.en)))
                    .font(LocalFonts.text(size: CGFloat(AppPrefs.fontSize - 1)))
                    .foregroundStyle(T.text2)
                if turnFailureShowsCode(item.code), let code = item.code {
                    Text(code)
                        .font(LocalFonts.code(size: CGFloat(AppPrefs.fontSize - 1)))
                        .foregroundStyle(T.text3)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Desktop `ui-chat` `TurnMaxTokensItem`: warning StateDot + title + hint.
struct TurnMaxTokensRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(T.warnBorder).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(maxTokensTitle(english: L.en))
                    .font(LocalFonts.text(size: CGFloat(AppPrefs.fontSize - 1)))
                    .fontWeight(.semibold)
                    .foregroundStyle(T.warnText)
                Text(maxTokensHint(english: L.en))
                    .font(LocalFonts.text(size: CGFloat(AppPrefs.fontSize - 1)))
                    .foregroundStyle(T.text2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(maxTokensTitle(english: L.en)) \(maxTokensHint(english: L.en))")
    }
}
