import Foundation
import SwiftData

/// Pick — 从 Echo 中"拾取"的离散数据索引
/// 每条 Pick 都能溯源到原始 Echo 文本中的具体位置
@Model
final class Pick {
    var id: UUID
    /// 关联的 EchoRecord ID
    var recordId: UUID
    /// 拾取类型
    var pickType: String  // "topic", "key_fact", "action_item", "sentiment", "key_metric"
    /// 离散的内容
    var content: String
    /// 在原文中的字符偏移量，用于溯源定位
    var timestampOffset: Int
    /// 原文锚点关键词/片段，用于高亮溯源
    var contextAnchor: String
    /// 扩展元数据 (JSON string)
    var metadataJSON: String?
    /// 创建时间
    var createdAt: Date

    init(
        recordId: UUID,
        pickType: String,
        content: String,
        timestampOffset: Int = 0,
        contextAnchor: String = ""
    ) {
        self.id = UUID()
        self.recordId = recordId
        self.pickType = pickType
        self.content = content
        self.timestampOffset = timestampOffset
        self.contextAnchor = contextAnchor
        self.createdAt = Date()
    }
}

// MARK: - Pick Type Definitions

enum PickType: String, CaseIterable, Identifiable {
    case topic = "topic"
    case keyFact = "key_fact"
    case actionItem = "action_item"
    case sentiment = "sentiment"
    case keyMetric = "key_metric"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topic: return "话题"
        case .keyFact: return "关键事实"
        case .actionItem: return "待办事项"
        case .sentiment: return "情感标记"
        case .keyMetric: return "关键数据"
        }
    }

    var icon: String {
        switch self {
        case .topic: return "bubble.left.and.text.bubble.right"
        case .keyFact: return "lightbulb.fill"
        case .actionItem: return "checkmark.circle"
        case .sentiment: return "heart.fill"
        case .keyMetric: return "number.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .topic: return "#6366F1"      // Indigo
        case .keyFact: return "#F59E0B"    // Amber
        case .actionItem: return "#EF4444" // Red
        case .sentiment: return "#EC4899"  // Pink
        case .keyMetric: return "#10B981"  // Emerald
        }
    }
}

// MARK: - GPT Extraction Response Models

struct ExtractionResponse: Codable {
    let summary: String
    let topics: [TopicItem]
    let discreteData: [DiscreteItem]
    let actionItems: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case topics
        case discreteData = "discrete_data"
        case actionItems = "action_items"
    }
}

struct TopicItem: Codable {
    let name: String
    let startTime: String
    let contextAnchor: String?

    enum CodingKeys: String, CodingKey {
        case name
        case startTime = "start_time"
        case contextAnchor = "context_anchor"
    }
}

struct DiscreteItem: Codable {
    let key: String
    let value: String
    let contextAnchor: String

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case contextAnchor = "context_anchor"
    }
}
