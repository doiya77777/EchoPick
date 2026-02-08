import Foundation

/// Whisper API 语音转文字服务
/// 将音频分段发送到 OpenAI Whisper，返回转录文本
actor WhisperService {
    private let session: URLSession
    private let endpoint = "https://api.openai.com/v1/audio/transcriptions"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    enum WhisperError: Error, LocalizedError {
        case noAPIKey
        case fileTooLarge
        case fileNotFound
        case apiError(String)
        case invalidResponse
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "请在设置中配置 OpenAI API Key"
            case .fileTooLarge: return "音频文件超过 25MB 限制"
            case .fileNotFound: return "音频文件未找到"
            case .apiError(let m): return "Whisper API 错误：\(m)"
            case .invalidResponse: return "无效的 API 响应"
            case .rateLimited: return "请求过于频繁，请稍后再试"
            }
        }
    }

    /// 转写单个音频文件
    func transcribe(fileURL: URL, language: String = "zh") async throws -> WhisperResult {
        guard let apiKey = APIKeyStore.load() else { throw WhisperError.noAPIKey }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw WhisperError.fileNotFound }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        guard fileSize <= 25 * 1024 * 1024 else { throw WhisperError.fileTooLarge }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let audioData = try Data(contentsOf: fileURL)

        body.appendField(name: "model", value: "whisper-1", boundary: boundary)
        body.appendField(name: "language", value: language, boundary: boundary)
        body.appendField(name: "response_format", value: "verbose_json", boundary: boundary)
        body.appendField(name: "timestamp_granularities[]", value: "segment", boundary: boundary)
        body.appendFile(name: "file", fileName: fileURL.lastPathComponent, mimeType: "audio/m4a", data: audioData, boundary: boundary)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw WhisperError.invalidResponse }
        if http.statusCode == 429 { throw WhisperError.rateLimited }
        guard http.statusCode == 200 else {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw WhisperError.apiError("[\(http.statusCode)] \(errBody)")
        }

        let decoded = try JSONDecoder().decode(WhisperAPIResponse.self, from: data)
        return WhisperResult(
            text: decoded.text,
            language: decoded.language ?? language,
            duration: decoded.duration ?? 0,
            segments: decoded.segments?.map {
                WhisperSegment(text: $0.text, start: $0.start, end: $0.end)
            } ?? []
        )
    }

    /// 批量转写多个音频分段，返回合并的转录文本
    func transcribeSegments(_ urls: [URL], language: String = "zh", onProgress: @Sendable @escaping (Int, Int) -> Void) async throws -> String {
        var allText = ""
        for (index, url) in urls.enumerated() {
            onProgress(index + 1, urls.count)
            let result = try await transcribe(fileURL: url, language: language)
            allText += result.text
            if index < urls.count - 1 {
                allText += "\n"
            }
        }
        return allText
    }
}

// MARK: - API Response Models

struct WhisperAPIResponse: Codable {
    let text: String
    let language: String?
    let duration: Double?
    let segments: [WhisperAPISegment]?
}

struct WhisperAPISegment: Codable {
    let text: String
    let start: Double
    let end: Double
}

struct WhisperResult {
    let text: String
    let language: String
    let duration: Double
    let segments: [WhisperSegment]
}

struct WhisperSegment {
    let text: String
    let start: Double
    let end: Double
}

// MARK: - Multipart Data Helpers

extension Data {
    mutating func appendField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFile(name: String, fileName: String, mimeType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
