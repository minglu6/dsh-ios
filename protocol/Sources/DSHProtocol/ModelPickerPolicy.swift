import Foundation

/// Matches the official model picker provider order and name-only fuzzy ranking.
public func modelPickerGroups(_ groups: [ModelGroup], query: String) -> [ModelGroup] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let ordered = groups.sorted { lhs, rhs in
        pickerRank(lhs.id) < pickerRank(rhs.id)
    }
    return ordered.compactMap { group in
        if normalizedQuery.isEmpty { return group.models.isEmpty ? nil : group }
        var ranked: [(model: ModelInfo, index: Int, prefix: Bool, score: Int)] = []
        for (index, model) in group.models.enumerated() {
            let name = model.name.lowercased()
            let score = modelNameAlignmentScore(name, normalizedQuery)
            if score != noModelMatch {
                ranked.append((model, index, name.hasPrefix(normalizedQuery), score))
            }
        }
        if ranked.isEmpty { return nil }
        ranked.sort {
            if $0.prefix != $1.prefix { return $0.prefix && !$1.prefix }
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.index < $1.index
        }
        return ModelGroup(id: group.id, name: group.name, models: ranked.map(\.model))
    }
}

public func modelPickerProviderLabel(_ id: String, hostName: String, english: Bool = false) -> String {
    if id == "deepseek-account" { return english ? "DeepSeek Account" : "DeepSeek 账号" }
    return hostName
}

public func modelEffortLabel(catalog: ModelCatalog?, provider: String?, model: String?, effort: String?) -> String? {
    guard let model = catalog?.find(provider: provider, model: model) else { return nil }
    if !model.hasReasoning { return nil }
    let resolved = effort ?? model.defaultEffort
    if resolved == nil { return "Default" }
    return model.efforts.first { $0.id == resolved }?.name ?? resolved
}

private func pickerRank(_ id: String) -> Int {
    switch id {
    case "deepseek-account": return 0
    case "deepseek-official": return 1
    default: return 2
    }
}

private let noModelMatch = Int.min

private func modelNameBoundaryBonus(_ name: String, _ index: Int) -> Int {
    if index == 0 { return 8 }
    let previous = name[name.index(name.startIndex, offsetBy: index - 1)]
    return previous == "-" || previous == "_" ? 8 : 0
}

/// Strongest ordered-subsequence alignment, using two reusable dynamic-programming rows.
private func modelNameAlignmentScore(_ name: String, _ query: String) -> Int {
    if query.count > name.count { return noModelMatch }
    let nameChars = Array(name)
    let queryChars = Array(query)
    var previous = Array(repeating: noModelMatch, count: nameChars.count)
    var current = Array(repeating: noModelMatch, count: nameChars.count)
    for index in nameChars.indices where nameChars[index] == queryChars[0] {
        previous[index] = 1 + modelNameBoundaryBonus(name, index) - index
    }
    if queryChars.count == 1 {
        return previous.max() ?? noModelMatch
    }
    for queryIndex in 1..<queryChars.count {
        current = Array(repeating: noModelMatch, count: nameChars.count)
        var left = noModelMatch
        var leftLeft = noModelMatch
        var bestGapped = noModelMatch
        for index in nameChars.indices {
            let prior = previous[index]
            if leftLeft != noModelMatch { bestGapped = max(bestGapped, leftLeft + index - 2) }
            if nameChars[index] == queryChars[queryIndex] {
                let bonus = 1 + modelNameBoundaryBonus(name, index)
                var score = noModelMatch
                if left != noModelMatch { score = left + bonus + 4 }
                if bestGapped != noModelMatch { score = max(score, bestGapped + bonus + 1 - index) }
                current[index] = score
            }
            leftLeft = left
            left = prior
        }
        swap(&previous, &current)
    }
    return previous.max() ?? noModelMatch
}
