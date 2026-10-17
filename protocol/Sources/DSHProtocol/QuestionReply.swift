import Foundation

/// Desktop `ui-user-questions` `QuestionReplyQuestion`.
public struct QuestionReplyQuestion: Sendable, Equatable, Identifiable {
    public var id: String
    public var question: String
    public var detail: String?
    public var header: String?
    public var options: [UserQuestionOption]
    public var multiSelect: Bool

    public init(
        id: String,
        question: String,
        detail: String? = nil,
        header: String? = nil,
        options: [UserQuestionOption] = [],
        multiSelect: Bool = false
    ) {
        self.id = id
        self.question = question
        self.detail = detail
        self.header = header
        self.options = options
        self.multiSelect = multiSelect
    }
}

/// Desktop `ui-user-questions` `QuestionReplyAnswer`.
public struct QuestionReplyAnswer: Sendable, Equatable {
    public var id: String
    public var selected: [String]
    public var custom: String?

    public init(id: String, selected: [String] = [], custom: String? = nil) {
        self.id = id
        self.selected = selected
        self.custom = custom
    }
}

/// Desktop `questionReplyDefinition` / `QuestionReplyData`.
public struct QuestionReplySource: Sendable, Equatable {
    public var callId: String
    public var outcome: String

    public init(callId: String, outcome: String) {
        self.callId = callId
        self.outcome = outcome
    }
}

/// Desktop `isAppendSurfaceEvent` + `replySource`: only an append-origin
/// `user/message` with `source.kind === "user-question-reply"` and
/// `outcome === "answered"` becomes a late-reply bubble.
public func questionReplySource(event: JSONValue, message: JSONValue) -> QuestionReplySource? {
    guard event["surfaceOp"].str() == "append" else { return nil }
    let source = message["source"]
    guard source["kind"].str() == "user-question-reply",
          let callId = source["callId"].str(), !callId.isEmpty,
          source["outcome"].str() == "answered"
    else {
        return nil
    }
    return QuestionReplySource(callId: callId, outcome: "answered")
}

/// Desktop `replyPairsOf`.
public func replyPairsOf(_ text: String) -> (questions: [QuestionReplyQuestion], answers: [QuestionReplyAnswer]) {
    guard let value = try? JSONValue.parse(text), value.obj() != nil else {
        return ([], [])
    }
    var questions: [QuestionReplyQuestion] = []
    for question in value["questions"].arr() ?? [] {
        guard let id = question["id"].str(), let prompt = question["question"].str() else { continue }
        var options: [UserQuestionOption] = []
        for option in question["options"].arr() ?? [] {
            guard let label = option["label"].str() else { continue }
            options.append(UserQuestionOption(label: label, description: option["description"].str()))
        }
        questions.append(QuestionReplyQuestion(
            id: id,
            question: prompt,
            detail: question["detail"].str(),
            header: question["header"].str(),
            options: options,
            multiSelect: question["multiSelect"].bool() == true
        ))
    }
    var answers: [QuestionReplyAnswer] = []
    for answer in value["answers"].arr() ?? [] {
        guard let id = answer["id"].str() else { continue }
        let selected = (answer["selected"].arr() ?? []).compactMap { $0.str() }
        answers.append(QuestionReplyAnswer(id: id, selected: selected, custom: answer["custom"].str()))
    }
    return (questions, answers)
}

/// Desktop `replyAnswerValues`.
public func replyAnswerValues(answers: [QuestionReplyAnswer], id: String) -> [String] {
    guard let answer = answers.first(where: { $0.id == id }) else { return [] }
    let custom = answer.custom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return answer.selected + (custom.isEmpty ? [] : [custom])
}

/// Desktop `replyClipboardText`.
public func replyClipboardText(
    text: String,
    questions: [QuestionReplyQuestion],
    answers: [QuestionReplyAnswer],
    english: Bool
) -> String {
    if questions.isEmpty { return text }
    return questions.map { question in
        let values = replyAnswerValues(answers: answers, id: question.id)
        let title: String
        if let header = question.header, !header.isEmpty, header != question.question {
            title = "\(header) — \(question.question)"
        } else {
            title = question.question
        }
        let body = values.isEmpty
            ? questionReplySkipped(english: english)
            : "\(questionReplyAnswerLabel(english: english))\(values.joined(separator: ", "))"
        return "\(title)\n\(body)"
    }.joined(separator: "\n\n")
}

public func questionReplySummary(
    questions: [QuestionReplyQuestion],
    answers: [QuestionReplyAnswer],
    english: Bool
) -> String {
    let values = questions.flatMap { replyAnswerValues(answers: answers, id: $0.id) }
    return values.isEmpty ? questionReplySkipped(english: english) : values.joined(separator: ", ")
}

public func questionReplyLabel(english: Bool) -> String {
    english ? "Reply to earlier pending questions" : "回答先前等待中的问题"
}

public func questionReplyOpen(english: Bool) -> String {
    english ? "Open question details" : "展开问题详情"
}

public func questionReplyClose(english: Bool) -> String {
    english ? "Close question details" : "收起问题详情"
}

public func questionReplyAnswerLabel(english: Bool) -> String {
    english ? "Answer: " : "回答："
}

public func questionReplySkipped(english: Bool) -> String {
    english ? "Skipped" : "已跳过"
}

public func questionReplyItem(
    event: JSONValue,
    message: JSONValue,
    key: String,
    at: Int64?,
    seq: Int64?
) -> Item.QuestionReply? {
    guard let source = questionReplySource(event: event, message: message) else { return nil }
    let text = (message["content"].arr() ?? [])
        .filter { $0["type"].str() == "text" }
        .map { $0["text"].str() ?? "" }
        .joined(separator: "\n")
    let pairs = replyPairsOf(text)
    return Item.QuestionReply(
        key: key,
        callId: source.callId,
        text: text,
        questions: pairs.questions,
        answers: pairs.answers,
        at: at,
        seq: seq
    )
}
