import Foundation

/// OpenAI API 集成服务
/// 负责语音转文字、文本摘要、情感分析等 AI 功能
actor AIService {
    private let session: URLSession
    private var apiKey: String?
    
    // API Endpoints
    private let baseURL = "https://api.openai.com/v1"
    private let whisperEndpoint = "/audio/transcriptions"
    private let chatEndpoint = "/chat/completions"
    private let embeddingsEndpoint = "/embeddings"
    
    enum AIError: Error, LocalizedError {
        case noAPIKey
        case networkError(String)
        case apiError(String)
        case invalidResponse
        case fileTooLarge
        case rateLimited
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "请在设置中配置 OpenAI API Key"
            case .networkError(let msg):
                return "网络错误：\(msg)"
            case .apiError(let msg):
                return "API 错误：\(msg)"
            case .invalidResponse:
                return "无效的 API 响应"
            case .fileTooLarge:
                return "音频文件过大（最大 25MB）"
            case .rateLimited:
                return "请求过于频繁，请稍后再试"
            }
        }
    }
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - API Key Management
    
    func setAPIKey(_ key: String) {
        self.apiKey = key
        // In production, store in Keychain via CryptoService
    }
    
    func loadAPIKey() -> String? {
        // In production, load from Keychain
        return apiKey
    }
    
    // MARK: - Speech to Text (Whisper)
    
    func transcribeAudio(fileURL: URL, language: String = "zh") async throws -> TranscriptionResult {
        guard let apiKey = apiKey else { throw AIError.noAPIKey }
        
        // Check file size (max 25MB for Whisper)
        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
        guard fileSize <= 25 * 1024 * 1024 else { throw AIError.fileTooLarge }
        
        let url = URL(string: baseURL + whisperEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let audioData = try Data(contentsOf: fileURL)
        
        // Model field
        body.appendMultipartField(name: "model", value: "whisper-1", boundary: boundary)
        // Language field
        body.appendMultipartField(name: "language", value: language, boundary: boundary)
        // Response format
        body.appendMultipartField(name: "response_format", value: "verbose_json", boundary: boundary)
        // Timestamp granularity for word-level timestamps
        body.appendMultipartField(name: "timestamp_granularities[]", value: "segment", boundary: boundary)
        // Audio file
        body.appendMultipartFile(name: "file", fileName: fileURL.lastPathComponent, mimeType: "audio/m4a", data: audioData, boundary: boundary)
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 { throw AIError.rateLimited }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }
        
        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        
        return TranscriptionResult(
            text: result.text,
            language: result.language,
            duration: result.duration,
            segments: result.segments?.map { segment in
                TranscriptionSegment(
                    text: segment.text,
                    start: segment.start,
                    end: segment.end
                )
            } ?? []
        )
    }
    
    // MARK: - Text Summarization
    
    func summarize(text: String) async throws -> String {
        let prompt = """
        请用中文对以下内容进行简洁的摘要，提取关键信息和要点。如果内容中包含待办事项，请单独列出。
        摘要应该简洁明了，不超过原文长度的 30%。
        
        内容：
        \(text)
        """
        
        return try await chatCompletion(
            messages: [
                ChatMessage(role: "system", content: "你是一个专业的笔记助手，擅长提取和总结信息。"),
                ChatMessage(role: "user", content: prompt)
            ],
            model: "gpt-4o-mini"
        )
    }
    
    // MARK: - Sentiment Analysis
    
    func analyzeSentiment(text: String) async throws -> SentimentResult {
        let prompt = """
        分析以下文本的情感倾向，返回 JSON 格式：
        {
            "mood": "happy|neutral|sad|excited|thoughtful|anxious",
            "confidence": 0.0-1.0,
            "keywords": ["关键词1", "关键词2"]
        }
        
        文本：\(text)
        """
        
        let response = try await chatCompletion(
            messages: [
                ChatMessage(role: "system", content: "你是情感分析专家，请只返回 JSON，不要其他内容。"),
                ChatMessage(role: "user", content: prompt)
            ],
            model: "gpt-4o-mini"
        )
        
        // Parse JSON response
        guard let data = response.data(using: .utf8),
              let result = try? JSONDecoder().decode(SentimentResult.self, from: data) else {
            return SentimentResult(mood: "neutral", confidence: 0.5, keywords: [])
        }
        
        return result
    }
    
    // MARK: - Chat Completion (Generic)
    
    func chatCompletion(messages: [ChatMessage], model: String = "gpt-4o-mini", temperature: Double = 0.7) async throws -> String {
        guard let apiKey = apiKey else { throw AIError.noAPIKey }
        
        let url = URL(string: baseURL + chatEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 { throw AIError.rateLimited }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw AIError.invalidResponse
        }
        
        return content
    }
}

// MARK: - API Models

struct WhisperResponse: Codable {
    let text: String
    let language: String
    let duration: Double
    let segments: [WhisperSegment]?
}

struct WhisperSegment: Codable {
    let text: String
    let start: Double
    let end: Double
}

struct TranscriptionResult {
    let text: String
    let language: String
    let duration: Double
    let segments: [TranscriptionSegment]
}

struct TranscriptionSegment {
    let text: String
    let start: Double
    let end: Double
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage
}

struct SentimentResult: Codable {
    let mood: String
    let confidence: Double
    let keywords: [String]
}

// MARK: - Data Extension for Multipart

extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func appendMultipartFile(name: String, fileName: String, mimeType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
