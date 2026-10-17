import Foundation

/// Merge live `user-question` offers with the durable `userQuestions` / `inbox`
/// projections, including reconnects. Desktop `useProjection("userQuestions")`
/// `view.active` is the authority for whether a card stays answerable; Android
/// `UserQuestionStore` is the phone-side merge of that projection with pocket
/// waterfall offers.
public final class UserQuestionStore {
    private struct Submitted {
        var state: String?
    }

    private struct SessionQuestions {
        var questionSeq: Int64 = -1
        var inboxSeq: Int64 = -1
        var active: [UserQuestion] = []
        var queued: Set<String> = []
        var submitted: [String: Submitted] = [:]
    }

    private struct OfferKey: Hashable {
        var sessionId: String?
        var questionId: String
    }

    private var sessions: [String: SessionQuestions] = [:]
    private var offers: [OfferKey: UserQuestion] = [:]
    private var offerOrder: [OfferKey] = []

    public init() {}

    public func clear() {
        sessions.removeAll()
        offers.removeAll()
        offerOrder.removeAll()
    }

    public func offer(_ value: JSONValue) {
        guard let question = UserQuestion.parse(value) else { return }
        let key = OfferKey(sessionId: question.sessionId, questionId: question.questionId)
        if offers[key] == nil { offerOrder.append(key) }
        offers[key] = question
    }

    public func close(questionId: String, sessionId: String? = nil) {
        let dropping = offerOrder.filter { key in
            key.questionId == questionId && (sessionId == nil || key.sessionId == sessionId)
        }
        for key in dropping { offers[key] = nil }
        offerOrder.removeAll { dropping.contains($0) }
        // A closed foreground request may already have become a continued question.
        for id in Array(sessions.keys) {
            guard sessionId == nil || id == sessionId, var session = sessions[id] else { continue }
            session.active.removeAll { question in
                question.questionId == questionId && question.state != "continued"
            }
            sessions[id] = session
        }
    }

    public func submitted(sessionId: String, callId: String) {
        var session = sessions[sessionId] ?? SessionQuestions()
        let question = session.active.first { $0.callId == callId }
            ?? offers[OfferKey(sessionId: sessionId, questionId: callId)]
        session.submitted[callId] = Submitted(state: question?.state)
        sessions[sessionId] = session
    }

    public func apply(sessionId: String, frame: JSONValue) {
        if let frameSession = frame["sessionId"].str(), frameSession != sessionId { return }
        switch frame["type"].str() {
        case "snapshot", "resume":
            let projections = frame["projections"]
            let values = projections["values"]
            guard values.obj() != nil else { return }
            let seq = projections["asOfSeq"].long() ?? frame["cursor"].long()
            guard let seq else { return }
            // Old Host plugins omit these keys; do not treat absence as empty active.
            if !values["userQuestions"].isNull {
                applyQuestions(sessionId: sessionId, seq: seq, value: values["userQuestions"])
            }
            if !values["inbox"].isNull {
                applyInbox(sessionId: sessionId, seq: seq, value: values["inbox"])
            }
        case "projection":
            guard let seq = frame["seq"].long() else { return }
            switch frame["key"].str() {
            case "userQuestions":
                applyQuestions(sessionId: sessionId, seq: seq, value: frame["value"])
            case "inbox":
                applyInbox(sessionId: sessionId, seq: seq, value: frame["value"])
            default:
                break
            }
        default:
            break
        }
    }

    public func questions() -> [UserQuestion] {
        var result: [OfferKey: UserQuestion] = [:]
        var order: [OfferKey] = []
        for key in offerOrder {
            guard let question = offers[key] else { continue }
            result[key] = question
            order.append(key)
        }
        let sessionIds = sessions.keys.sorted()
        for id in sessionIds {
            guard let session = sessions[id] else { continue }
            for question in session.active {
                let key = OfferKey(sessionId: question.sessionId, questionId: question.questionId)
                if result[key] == nil { order.append(key) }
                result[key] = question
            }
        }
        return order.compactMap { key in
            guard let question = result[key] else { return nil }
            let session = question.sessionId.flatMap { sessions[$0] }
            let callId = question.callId ?? question.questionId
            if session?.queued.contains(callId) == true { return nil }
            if let submitted = session?.submitted, submitted[callId] != nil { return nil }
            return question
        }
    }

    /// Request ids still held as a live offer or projected active card, including
    /// those hidden by a queued reply / in-flight submit. Drafts stay until the
    /// Host drops the question.
    public func retainedQuestionIds() -> Set<String> {
        var ids = Set(offers.values.map(\.questionId))
        for session in sessions.values {
            ids.formUnion(session.active.map(\.questionId))
        }
        return ids
    }

    private func applyQuestions(sessionId: String, seq: Int64, value: JSONValue) {
        var session = sessions[sessionId] ?? SessionQuestions()
        if seq < session.questionSeq { return }
        session.questionSeq = seq
        session.active = (value["active"].arr() ?? []).compactMap { entry in
            guard var fields = entry.obj() else { return nil }
            fields["sessionId"] = .string(sessionId)
            return UserQuestion.parse(.object(fields))
        }
        let activeIds = Set(session.active.map(\.questionId))
        let staleOffers = offerOrder.filter { key in
            guard let question = offers[key] else { return false }
            return question.sessionId == sessionId && question.state != nil && !activeIds.contains(question.questionId)
        }
        for key in staleOffers { offers[key] = nil }
        offerOrder.removeAll { staleOffers.contains($0) }
        session.submitted = session.submitted.filter { id, entry in
            guard let current = session.active.first(where: { $0.callId == id }) else { return false }
            return current.state == entry.state
        }
        sessions[sessionId] = session
    }

    private func applyInbox(sessionId: String, seq: Int64, value: JSONValue) {
        var session = sessions[sessionId] ?? SessionQuestions()
        if seq < session.inboxSeq { return }
        session.inboxSeq = seq
        var queued = Set<String>()
        for target in ["next-turn", "next-step"] {
            for message in value[target].arr() ?? [] {
                let source = message["source"]
                if source["kind"].str() == "user-question-reply", let callId = source["callId"].str() {
                    queued.insert(callId)
                }
            }
        }
        // Discarding a queued reply makes its still-active question answerable again.
        for callId in session.queued.subtracting(queued) {
            session.submitted.removeValue(forKey: callId)
        }
        session.queued = queued
        sessions[sessionId] = session
    }
}
