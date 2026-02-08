import Foundation

/// 豆包 Seed ASR 语音转文字服务（火山引擎）
/// 异步模式：提交任务 → 轮询查询结果
/// 文档：https://www.volcengine.com/docs/6561/1354868
actor SeedASRService {
    private let session: URLSession
    private let submitEndpoint = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit"
    private let queryEndpoint = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query"
    private let resourceId = "volc.seedasr.auc"  // 豆包录音文件识别模型 2.0

    /// 查询轮询间隔
    private let pollInterval: TimeInterval = 2.0
    /// 最大轮询次数（2s × 150 = 5 分钟超时）
    private let maxPollAttempts = 150

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600  // 10 分钟
        // 绕过本地代理（解决模拟器 Clash 代理导致 TLS 失败）
        config.connectionProxyDictionary = [kCFNetworkProxiesHTTPEnable as String: false]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Error Types

    enum SeedASRError: Error, LocalizedError {
        case noAPIKey
        case fileNotFound
        case fileTooLarge
        case fileUploadRequired
        case submitFailed(String)
        case queryFailed(String)
        case timeout
        case silentAudio
        case invalidResponse
        case processingError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "请在设置中配置豆包语音 API Key"
            case .fileNotFound: return "音频文件未找到"
            case .fileTooLarge: return "音频文件过大"
            case .fileUploadRequired: return "需要音频 URL，本地文件需先上传"
            case .submitFailed(let m): return "提交任务失败：\(m)"
            case .queryFailed(let m): return "查询结果失败：\(m)"
            case .timeout: return "转录超时，请稍后重试"
            case .silentAudio: return "检测到静音音频"
            case .invalidResponse: return "无效的 API 响应"
            case .processingError(let m): return "处理错误：\(m)"
            }
        }
    }

    // MARK: - Public API

    /// 转写本地音频文件
    /// 将本地文件转为 base64 data URL 或通过临时服务器上传
    /// 当前实现：先将音频转为 base64 data URL
    func transcribe(fileURL: URL) async throws -> SeedASRResult {
        guard let apiKey = APIKeyStore.loadSeedASR() else {
            throw SeedASRError.noAPIKey
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SeedASRError.fileNotFound
        }

        // 读取音频文件并构造 data URL
        let audioData = try Data(contentsOf: fileURL)
        let fileSize = audioData.count
        guard fileSize <= 500 * 1024 * 1024 else {  // 500MB 限制
            throw SeedASRError.fileTooLarge
        }

        // 将音频文件编码为 base64 data URL
        let base64Audio = audioData.base64EncodedString()
        let ext = fileURL.pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "m4a": mimeType = "audio/mp4"
        case "mp3": mimeType = "audio/mpeg"
        case "wav": mimeType = "audio/wav"
        case "ogg": mimeType = "audio/ogg"
        default: mimeType = "audio/mp4"
        }
        let dataURL = "data:\(mimeType);base64,\(base64Audio)"

        // 确定音频格式
        let format: String
        switch ext {
        case "m4a": format = "mp3"  // m4a 使用 mp3 容器解码
        case "mp3": format = "mp3"
        case "wav": format = "wav"
        case "ogg": format = "ogg"
        default: format = "raw"
        }

        let requestId = UUID().uuidString

        // Step 1: 提交任务
        try await submitTask(
            audioURL: dataURL,
            format: format,
            apiKey: apiKey,
            requestId: requestId
        )

        // Step 2: 轮询查询结果
        let result = try await pollResult(
            apiKey: apiKey,
            requestId: requestId
        )

        return result
    }

    /// 转写远程音频 URL（直接使用）
    func transcribeURL(_ audioURL: String, format: String = "mp3") async throws -> SeedASRResult {
        guard let apiKey = APIKeyStore.loadSeedASR() else {
            throw SeedASRError.noAPIKey
        }

        let requestId = UUID().uuidString

        try await submitTask(
            audioURL: audioURL,
            format: format,
            apiKey: apiKey,
            requestId: requestId
        )

        return try await pollResult(apiKey: apiKey, requestId: requestId)
    }

    // MARK: - Submit Task

    private func submitTask(
        audioURL: String,
        format: String,
        apiKey: String,
        requestId: String
    ) async throws {
        var request = URLRequest(url: URL(string: submitEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(requestId, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("-1", forHTTPHeaderField: "X-Api-Sequence")

        let body: [String: Any] = [
            "user": [
                "uid": "echopick-ios"
            ],
            "audio": [
                "url": audioURL,
                "format": format,
                "codec": "raw",
                "rate": 16000,
                "bits": 16,
                "channel": 1
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,      // 启用标点，提升可读性
                "enable_ddc": false,
                "enable_speaker_info": false,
                "show_utterances": true,   // 获取时间戳分句
                "vad_segment": false,
                "sensitive_words_filter": ""
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SeedASRError.invalidResponse
        }

        // 检查 response header 中的状态码
        let statusCode = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        let message = http.value(forHTTPHeaderField: "X-Api-Message") ?? ""

        guard statusCode == "20000000" else {
            throw SeedASRError.submitFailed("[\(statusCode)] \(message)")
        }
    }

    // MARK: - Poll Query Result

    private func pollResult(apiKey: String, requestId: String) async throws -> SeedASRResult {
        for attempt in 0..<maxPollAttempts {
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))

            let (statusCode, data) = try await queryTask(apiKey: apiKey, requestId: requestId)

            switch statusCode {
            case "20000000":
                // 成功！解析结果
                return try parseResult(data)

            case "20000001", "20000002":
                // 仍在处理中，继续轮询
                continue

            case "20000003":
                // 静音音频
                throw SeedASRError.silentAudio

            default:
                let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown"
                throw SeedASRError.queryFailed("[\(statusCode)] \(message)")
            }
        }

        throw SeedASRError.timeout
    }

    private func queryTask(apiKey: String, requestId: String) async throws -> (String, Data?) {
        var request = URLRequest(url: URL(string: queryEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(requestId, forHTTPHeaderField: "X-Api-Request-Id")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SeedASRError.invalidResponse
        }

        let statusCode = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        return (statusCode, data)
    }

    // MARK: - Parse Result

    private func parseResult(_ data: Data?) throws -> SeedASRResult {
        guard let data = data else { throw SeedASRError.invalidResponse }

        let decoded = try JSONDecoder().decode(SeedASRResponse.self, from: data)

        let text = decoded.result?.text ?? ""
        let duration = Double(decoded.audioInfo?.duration ?? 0) / 1000.0  // ms → s

        let segments: [SeedASRSegment] = decoded.result?.utterances?.map { utt in
            SeedASRSegment(
                text: utt.text,
                startTime: Double(utt.startTime) / 1000.0,
                endTime: Double(utt.endTime) / 1000.0
            )
        } ?? []

        return SeedASRResult(
            text: text,
            duration: duration,
            segments: segments
        )
    }
}

// MARK: - Response Models

private struct SeedASRResponse: Codable {
    let result: SeedASRResponseResult?
    let audioInfo: SeedASRAudioInfo?

    enum CodingKeys: String, CodingKey {
        case result
        case audioInfo = "audio_info"
    }
}

private struct SeedASRResponseResult: Codable {
    let text: String?
    let utterances: [SeedASRUtterance]?
}

private struct SeedASRUtterance: Codable {
    let text: String
    let startTime: Int
    let endTime: Int
    let definite: Bool?

    enum CodingKeys: String, CodingKey {
        case text
        case startTime = "start_time"
        case endTime = "end_time"
        case definite
    }
}

private struct SeedASRAudioInfo: Codable {
    let duration: Int?
}

// MARK: - Public Result Types

struct SeedASRResult {
    let text: String
    let duration: Double        // 秒
    let segments: [SeedASRSegment]
}

struct SeedASRSegment {
    let text: String
    let startTime: Double       // 秒
    let endTime: Double         // 秒
}
