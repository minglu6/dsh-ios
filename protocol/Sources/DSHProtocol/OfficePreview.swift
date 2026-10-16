import Foundation

public let officePreviewMaxBytes = 100 * 1024 * 1024
public let officePreviewMaxChunkBytes = 128 * 1024

public final class OfficePreviewDownload: @unchecked Sendable {
    public let fileURL: URL
    public let missingFonts: [String]
    public let version: String
    public let generation: String
    private let lock = NSLock()
    private var closed = false

    public init(fileURL: URL, missingFonts: [String], version: String, generation: String) {
        self.fileURL = fileURL
        self.missingFonts = missingFonts
        self.version = version
        self.generation = generation
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        if closed { return }
        closed = true
        try? FileManager.default.removeItem(at: fileURL)
    }

    deinit { close() }
}

public struct OfficePreviewReader {
    public let sessionId: String
    public let handle: String
    public let attempt: Int64
    public let metadata: JSONValue
    public let read: (Int64, Int) async throws -> JSONValue

    public init(
        sessionId: String,
        handle: String,
        attempt: Int64,
        metadata: JSONValue,
        read: @escaping (Int64, Int) async throws -> JSONValue
    ) {
        self.sessionId = sessionId
        self.handle = handle
        self.attempt = attempt
        self.metadata = metadata
        self.read = read
    }
}

private func invalidOfficeResponse() -> PocketError {
    PocketError(code: "document-render/failed", message: "Invalid Office preview response")
}

/// Write each bounded page once; ownership transfers only after the final page has been checked.
public func downloadOfficePreview(
    metadata: JSONValue,
    cacheDirectory: URL,
    read: (Int64, Int) async throws -> JSONValue
) async throws -> OfficePreviewDownload {
    var temporary: URL?
    do {
        guard let total = metadata["bytes"].long(), (1...Int64(officePreviewMaxBytes)).contains(total) else {
            throw invalidOfficeResponse()
        }
        guard let version = metadata["version"].str(), let generation = metadata["generation"].str(),
              let absolutePath = metadata["absolutePath"].str() else {
            throw invalidOfficeResponse()
        }
        guard let chunk = metadata["chunkBytes"].int(), (1...officePreviewMaxChunkBytes).contains(chunk) else {
            throw invalidOfficeResponse()
        }
        guard let fontValues = metadata["missingFonts"].arr() else { throw invalidOfficeResponse() }
        let fonts = try fontValues.map { value -> String in
            guard let font = value.str() else { throw invalidOfficeResponse() }
            return font
        }
        let fileURL = cacheDirectory.appendingPathComponent("office-preview-\(UUID().uuidString).pdf")
        temporary = fileURL
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        var offset: Int64 = 0
        while offset < total {
            try Task.checkCancellation()
            let length = Int(min(Int64(chunk), total - offset))
            let page = try await read(offset, length)
            if page["offset"].long() != offset || page["bytes"].long() != total
                || page["version"].str() != version || page["generation"].str() != generation
                || page["absolutePath"].str() != absolutePath || page["encoding"].str() != "base64" {
                throw invalidOfficeResponse()
            }
            guard let encoded = page["data"].str() else { throw invalidOfficeResponse() }
            if encoded.count > ((length + 2) / 3) * 4 { throw invalidOfficeResponse() }
            guard let data = Data(base64Encoded: encoded) else { throw invalidOfficeResponse() }
            if data.isEmpty || data.count > length { throw invalidOfficeResponse() }
            let next = offset + Int64(data.count)
            if page["eof"].bool() != (next == total) { throw invalidOfficeResponse() }
            try handle.write(contentsOf: data)
            offset = next
        }
        try Task.checkCancellation()
        return OfficePreviewDownload(fileURL: fileURL, missingFonts: fonts, version: version, generation: generation)
    } catch {
        if let temporary { try? FileManager.default.removeItem(at: temporary) }
        throw error
    }
}

/// Exact official conversionErrorKey mapping; engine diagnostic messages never reach the preview.
public func officePreviewErrorMessage(_ failure: Error, english: Bool) -> String {
    let error = failure as? PocketError
    let reason: String?
    if error?.code == "unknown-op" {
        reason = "unavailable"
    } else if error?.code == "timeout" {
        reason = "timeout"
    } else {
        reason = error?.details?["reason"].str()
    }
    switch reason {
    case "input-too-large", "output-too-large":
        return english
            ? "The Office file or converted PDF exceeds the preview size limit. Reduce the file size or adjust the preview configuration."
            : "Office 文件或转换后的 PDF 超过预览大小上限，请缩小文件或调整预览配置。"
    case "invalid-document", "unsupported-format":
        return english
            ? "This Office file cannot be previewed. It may be damaged, password protected, or have the wrong extension."
            : "无法预览此 Office 文件。文件可能已损坏、受密码保护，或与扩展名不符。"
    case "timeout":
        return english ? "Office conversion timed out. Try again." : "Office 转换超时，请重试。"
    case "unavailable":
        return english
            ? "Office previews are unavailable. Enable the document preview service on the computer running DeepSeek Harness."
            : "Office 预览不可用。请在运行 DeepSeek Harness 的远程主机上启用文档预览服务。"
    case "busy":
        return english ? "Office preview is busy. Try again shortly." : "Office 预览任务较多，请稍后重试。"
    case "source-changed":
        return english ? "The file changed while being read. Reopen the preview." : "文件在读取时已更改，请重新打开预览。"
    default:
        return english
            ? "Office conversion did not produce a usable PDF. Check the file and try again."
            : "Office 转换失败，未生成可用的 PDF。请检查该文件后重试。"
    }
}
