import Foundation

/// Pick 提取器 — 使用豆包 Seed LLM 从转录文本中拾取离散数据
/// API 兼容 OpenAI 格式，通过火山引擎 ARK 平台调用
/// 端点：https://ark.cn-beijing.volces.com/api/v3
actor PickExtractor {
    private let session: URLSession
    private let endpoint = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    private let model = "doubao-seed-1-8-251228"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        // 绕过本地代理（解决模拟器 Clash 代理超时问题）
        config.connectionProxyDictionary = [kCFNetworkProxiesHTTPEnable as String: false]
        self.session = URLSession(configuration: config)
    }

    /// 核心提取 Prompt — PRD 定义的「资深档案管理员」角色
    private let systemPrompt = """
    你是一个资深档案管理员。你的任务是阅读原始对话文本，首先保留其所有细节，然后从中"拾取"出离散的价值点。

    规则：
    1. summary: 用一句话概括这段对话的核心内容
    2. topics: 识别对话中的主题变化，标注主题名和开始的大致位置
    3. discrete_data: 提取所有关键数据点（金钱数字、日期、人名、地点、决策、书名、链接等）
    4. action_items: 提取所有待办事项或承诺
    5. context_anchor: 每个提取项必须包含原文中的关键片段（3-10个字），用于溯源定位

    请严格返回以下 JSON 格式，不要包含任何其他内容：
    {
      "summary": "一句话总结",
      "topics": [
        {"name": "话题名称", "start_time": "大约位置", "context_anchor": "原文关键片段"}
      ],
      "discrete_data": [
        {"key": "类别", "value": "内容", "context_anchor": "原文关键片段"}
      ],
      "action_items": [
        {"task": "待办内容", "context_anchor": "原文关键片段"}
      ]
    }

    如果某个类别没有内容，返回空数组。确保 context_anchor 是原文中真实存在的文字片段。
    """

    /// 从转录文本中提取 Picks
    func extract(from transcript: String) async throws -> ExtractionResult {
        guard let apiKey = APIKeyStore.loadDoubaoLLM() else {
            throw ExtractorError.noAPIKey
        }

        // 如果文本太长，分段处理
        if transcript.count > 8000 {
            return try await extractLongText(transcript, apiKey: apiKey)
        }

        return try await callLLM(transcript: transcript, apiKey: apiKey)
    }

    /// 处理长文本：分段提取再合并
    private func extractLongText(_ transcript: String, apiKey: String) async throws -> ExtractionResult {
        let chunkSize = 6000
        var chunks: [String] = []
        var start = transcript.startIndex
        while start < transcript.endIndex {
            let end = transcript.index(start, offsetBy: chunkSize, limitedBy: transcript.endIndex) ?? transcript.endIndex
            chunks.append(String(transcript[start..<end]))
            start = end
        }

        var allTopics: [ExtractionResult.Topic] = []
        var allDiscreteData: [ExtractionResult.Discrete] = []
        var allActionItems: [ExtractionResult.ActionItem] = []
        var summaries: [String] = []

        for chunk in chunks {
            let result = try await callLLM(transcript: chunk, apiKey: apiKey)
            summaries.append(result.summary)
            allTopics.append(contentsOf: result.topics)
            allDiscreteData.append(contentsOf: result.discreteData)
            allActionItems.append(contentsOf: result.actionItems)
        }

        let mergedSummary = summaries.count == 1 ? summaries[0] : summaries.joined(separator: "；")

        return ExtractionResult(
            summary: mergedSummary,
            topics: allTopics,
            discreteData: allDiscreteData,
            actionItems: allActionItems
        )
    }

    private func callLLM(transcript: String, apiKey: String) async throws -> ExtractionResult {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "请分析以下对话文本并提取离散数据：\n\n\(transcript)"]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ExtractorError.invalidResponse }
        guard http.statusCode == 200 else {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw ExtractorError.apiError("[\(http.statusCode)] \(errBody)")
        }

        // Parse response (OpenAI 兼容格式)
        struct LLMResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        guard let content = llmResponse.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw ExtractorError.invalidResponse
        }

        return try JSONDecoder().decode(ExtractionResult.self, from: jsonData)
    }

    enum ExtractorError: Error, LocalizedError {
        case noAPIKey
        case apiError(String)
        case invalidResponse
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "请在设置中配置豆包 LLM API Key"
            case .apiError(let m): return "提取失败：\(m)"
            case .invalidResponse: return "无效的 API 响应"
            case .parseError(let m): return "解析失败：\(m)"
            }
        }
    }
}

// MARK: - Extraction Result Model

struct ExtractionResult: Codable {
    let summary: String
    let topics: [Topic]
    let discreteData: [Discrete]
    let actionItems: [ActionItem]

    enum CodingKeys: String, CodingKey {
        case summary, topics
        case discreteData = "discrete_data"
        case actionItems = "action_items"
    }

    struct Topic: Codable {
        let name: String
        let startTime: String
        let contextAnchor: String?

        enum CodingKeys: String, CodingKey {
            case name
            case startTime = "start_time"
            case contextAnchor = "context_anchor"
        }
    }

    struct Discrete: Codable {
        let key: String
        let value: String
        let contextAnchor: String

        enum CodingKeys: String, CodingKey {
            case key, value
            case contextAnchor = "context_anchor"
        }
    }

    struct ActionItem: Codable {
        let task: String
        let contextAnchor: String?

        enum CodingKeys: String, CodingKey {
            case task
            case contextAnchor = "context_anchor"
        }
    }
}
