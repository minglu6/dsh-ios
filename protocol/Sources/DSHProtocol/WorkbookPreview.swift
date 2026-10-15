import Foundation

public let workbookMaxBytes = 16 * 1024 * 1024
public let workbookChunkBytes = 64 * 1024
public let workbookOrigin = "https://workbook-preview.invalid"
public let workbookAssetPrefix = "\(workbookOrigin)/workbook-preview/"
public let workbookURL = "\(workbookAssetPrefix)index.html"

public struct WorkbookReadFailure: Error, Equatable {
    public let reason: String
    public init(_ reason: String) { self.reason = reason }
}

public func workbookPreviewErrorMessage(_ failure: Error, english: Bool, unavailable: (String) -> String) -> String {
    switch (failure as? WorkbookReadFailure)?.reason {
    case "invalid":
        return english
            ? "This spreadsheet could not be opened. Check its format, contents, or password protection."
            : "无法打开此表格。请检查文件格式、内容或密码保护。"
    case "tooLarge":
        return english ? "This workbook exceeds the preview size limit." : "此表格超过预览大小限制。"
    case "source-changed":
        return english ? "The file changed while being read. Reopen the preview." : "文件在读取时已更改，请重新打开预览。"
    default:
        return failure.localizedDescription.isEmpty ? unavailable(String(describing: failure)) : failure.localizedDescription
    }
}

private func workbookAbsolutePath(_ value: String) -> Bool {
    value.hasPrefix("/") || value.hasPrefix("\\\\") || value.range(of: #"^[A-Za-z]:[/\\]"#, options: .regularExpression) != nil
}

/// Testable wire boundary: reject mixed revisions, truncated reads and unbounded allocations.
public func readWorkbookChunks(_ read: (Int, Int) async throws -> JSONValue) async throws -> Data {
    var identity: (String, String)?
    var result: Data?
    var offset = 0
    var confirming = false
    while true {
        try Task.checkCancellation()
        let length = confirming ? 1 : workbookChunkBytes
        let page = try await read(offset, length)
        try Task.checkCancellation()
        guard let absolute = page["absolutePath"].str(),
              let version = page["version"].str(),
              let total = page["bytes"].int(),
              let returnedOffset = page["offset"].int(),
              let eof = page["eof"].bool() else {
            throw WorkbookReadFailure("invalid")
        }
        if total > workbookMaxBytes { throw WorkbookReadFailure("tooLarge") }
        if total < 1 || version.isEmpty || !workbookAbsolutePath(absolute) { throw WorkbookReadFailure("invalid") }
        let nextIdentity = (absolute, version)
        if let identity, identity != nextIdentity || result?.count != total {
            throw WorkbookReadFailure("source-changed")
        }
        if returnedOffset != offset || page["encoding"].str() != "base64" { throw WorkbookReadFailure("invalid") }
        guard let encoded = page["data"].str() else { throw WorkbookReadFailure("invalid") }
        if encoded.count > ((length + 2) / 3) * 4 { throw WorkbookReadFailure("invalid") }
        guard let chunk = Data(base64Encoded: encoded) else { throw WorkbookReadFailure("invalid") }
        if chunk.count > length || offset + chunk.count > total || eof != (offset + chunk.count == total) {
            throw WorkbookReadFailure("invalid")
        }
        if confirming {
            if !eof || !chunk.isEmpty { throw WorkbookReadFailure("source-changed") }
            guard let result else { throw WorkbookReadFailure("invalid") }
            return result
        }
        if chunk.isEmpty { throw WorkbookReadFailure("invalid") }
        if result == nil {
            result = Data(count: total)
            identity = nextIdentity
        }
        result?[offset..<(offset + chunk.count)] = chunk
        offset += chunk.count
        confirming = eof
    }
}

/// Exact current document + generated assets; not a filesystem or URL-prefix allowlist.
public func workbookPreviewResourceFor(url: String, mainFrame: Bool, assets: Set<String>, documentUrl: String) -> String? {
    if mainFrame { return url == workbookURL ? "index.html" : nil }
    if url == documentUrl { return "@document" }
    guard url.hasPrefix(workbookAssetPrefix) else { return nil }
    let name = String(url.dropFirst(workbookAssetPrefix.count))
    return assets.contains(name) ? name : nil
}
