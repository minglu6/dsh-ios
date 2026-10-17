import Foundation

/// Desktop `ui-user-questions` `QuestionDraftAnswer`.
public struct QuestionDraft: Equatable, Sendable {
    public var selected: Set<String>
    public var custom: String
    public var skipped: Bool

    public init(selected: Set<String> = [], custom: String = "", skipped: Bool = false) {
        self.selected = selected
        self.custom = custom
        self.skipped = skipped
    }

    public var answered: Bool {
        !selected.isEmpty || !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var completed: Bool { skipped || answered }
}

/// Desktop `parseRecommendedLabel`: strip the conventional suffix without changing
/// the answer value submitted on the wire.
public struct RecommendedLabel: Equatable, Sendable {
    public var label: String
    public var recommended: Bool
}

private let recommendationSuffix = try! NSRegularExpression(
    pattern: #"\s*(?:\((?:recommended|推荐)\)|（(?:recommended|推荐)）)\s*$"#,
    options: [.caseInsensitive]
)

public func parseRecommendedLabel(_ label: String) -> RecommendedLabel {
    let range = NSRange(label.startIndex..<label.endIndex, in: label)
    guard let match = recommendationSuffix.firstMatch(in: label, range: range),
          let suffix = Range(match.range, in: label)
    else {
        return RecommendedLabel(label: label, recommended: false)
    }
    return RecommendedLabel(label: String(label[..<suffix.lowerBound]), recommended: true)
}

/// Desktop `recommendedFirstOption`: only a marked first choice is an implicit draft.
public func recommendedFirstOption(_ item: UserQuestionItem) -> String? {
    guard let label = item.options.first?.label else { return nil }
    return parseRecommendedLabel(label).recommended ? label : nil
}

public func initialQuestionDraft(_ item: UserQuestionItem) -> QuestionDraft {
    if let recommended = recommendedFirstOption(item) {
        return QuestionDraft(selected: [recommended])
    }
    return QuestionDraft()
}

public func questionDraft(for item: UserQuestionItem, in drafts: [String: QuestionDraft]) -> QuestionDraft {
    drafts[item.id] ?? initialQuestionDraft(item)
}

/// Desktop `submitDrafts` / Android `questionAnswers`.
public func questionAnswers(_ question: UserQuestion, drafts: [String: QuestionDraft]) -> [JSONValue] {
    question.questions.map { item in
        let draft = questionDraft(for: item, in: drafts)
        if draft.skipped {
            return .object([
                "id": .string(item.id),
                "selected": .array([]),
            ])
        }
        let custom = draft.custom.trimmingCharacters(in: .whitespacesAndNewlines)
        var object: [String: JSONValue] = [
            "id": .string(item.id),
            "selected": .array(
                (custom.isEmpty || item.multiSelect) ? draft.selected.sorted().map(JSONValue.string) : []
            ),
        ]
        if !custom.isEmpty { object["custom"] = .string(custom) }
        return .object(object)
    }
}

public func firstIncompleteQuestionIndex(
    _ question: UserQuestion,
    drafts: [String: QuestionDraft]
) -> Int? {
    question.questions.firstIndex { !questionDraft(for: $0, in: drafts).completed }
}

public func coerceQuestionIndex(_ index: Int, count: Int) -> Int {
    guard count > 0 else { return 0 }
    return min(max(index, 0), count - 1)
}

// MARK: - Desktop `question` namespace (ui-user-questions locales)

public func questionRecommendedBadge(english: Bool) -> String {
    english ? "Recommended" : "推荐"
}

public func questionUnansweredError(english: Bool) -> String {
    english ? "Please select an option or enter a custom answer." : "请选择一个选项或填写自定义答案。"
}

public func questionIncompleteError(english: Bool) -> String {
    english ? "Please complete this question first." : "请先完成这道问题。"
}

/// Desktop `wait.continued` on the composer card (not the tool-row `ask.pending`).
public func questionWaitContinued(english: Bool) -> String {
    english ? "Work continued — you can still answer" : "已继续工作，仍可回答"
}

public func questionResubmitHint(english: Bool) -> String {
    english
        ? "The answer did not arrive before work continued; submit it again."
        : "回答未送达，工作已继续，请再提交一次。"
}

public func questionSubmitFailed(english: Bool) -> String {
    english ? "Submit failed; answers kept. Try again." : "提交失败，答案已保留，请重试"
}

public func questionSubmitting(english: Bool) -> String {
    english ? "Submitting…" : "正在提交…"
}

public func questionPreviousLabel(english: Bool) -> String {
    english ? "Previous question" : "上一题"
}

public func questionSubmitAnswersLabel(english: Bool) -> String {
    english ? "Submit answers" : "提交答案"
}

public func questionCollapseLabel(english: Bool) -> String {
    english ? "Collapse" : "收起"
}

public func questionPlanHeader(english: Bool) -> String {
    english ? "Plan review" : "计划待审"
}

public func questionPlanApprove(english: Bool) -> String {
    english ? "Approve" : "同意执行"
}

/// Desktop `plan.discuss` — dismisses the plan-review takeover (hide, not a skip answer).
public func questionPlanDiscuss(english: Bool) -> String {
    english ? "Request changes" : "要求修改"
}

/// Desktop `planReviewOf`: one plan-review question with a plan body and an approve option.
public func planReviewOf(_ questions: [UserQuestionItem]) -> UserQuestionItem? {
    guard questions.count == 1 else { return nil }
    let item = questions[0]
    guard item.intentKind == "plan-review", item.detail != nil else { return nil }
    guard !item.multiSelect, item.options.count <= 2 else { return nil }
    guard let approve = item.approveLabel, item.options.contains(where: { $0.label == approve }) else {
        return nil
    }
    return item
}
