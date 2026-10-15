import Foundation

public let maxBrowserURLTitleLength = 512

public struct BrowserTabCheckpoint: Equatable, Sendable {
    public var id: String
    public var url: String
    public var title: String

    public init(id: String, url: String, title: String) {
        self.id = id
        self.url = String(url.prefix(maxBrowserURLLength))
        self.title = String(title.prefix(maxBrowserURLTitleLength))
    }
}

public struct BrowserTabsCheckpoint: Equatable, Sendable {
    public var selected: String
    public var pages: [BrowserTabCheckpoint]

    public init(selected: String, pages: [BrowserTabCheckpoint]) {
        self.selected = selected
        self.pages = pages
    }
}

/// Checkpoints contain addresses only: recreation never restores a WebView or starts network traffic.
public func browserTabsCheckpoint(
    stored: String?,
    legacyURL: String?,
    legacyTitle: String?
) -> BrowserTabsCheckpoint {
    if let stored, let parsed = try? JSONValue.parse(stored), let entries = parsed["pages"].arr() {
        var pages: [BrowserTabCheckpoint] = []
        var seen = Set<String>()
        for entry in entries {
            guard let id = entry["id"].str(), !id.isEmpty, !seen.contains(id) else { continue }
            seen.insert(id)
            pages.append(BrowserTabCheckpoint(
                id: id,
                url: entry["url"].str() ?? "",
                title: entry["title"].str() ?? ""
            ))
        }
        if pages.isEmpty {
            pages = [BrowserTabCheckpoint(id: UUID().uuidString, url: "", title: "")]
        }
        let selected = parsed["selected"].str()
        let chosen = pages.first { $0.id == selected } ?? pages[0]
        return BrowserTabsCheckpoint(selected: chosen.id, pages: pages)
    }
    let migrated = BrowserTabCheckpoint(
        id: UUID().uuidString,
        url: legacyURL ?? "",
        title: legacyTitle ?? ""
    )
    return BrowserTabsCheckpoint(selected: migrated.id, pages: [migrated])
}

public func encodeBrowserTabsCheckpoint(_ checkpoint: BrowserTabsCheckpoint) -> String {
    let pages = checkpoint.pages.map { page in
        jsonObjectKeeping([
            "id": .string(page.id),
            "url": .string(page.url),
            "title": .string(String(page.title.prefix(maxBrowserURLTitleLength))),
        ])
    }
    return (try? jsonObjectKeeping([
        "selected": .string(checkpoint.selected),
        "pages": .array(pages),
    ]).encodeString()) ?? "{}"
}
