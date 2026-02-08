import Foundation
import SwiftData

/// Echo — 原始语音资产
/// 完整的、带时间戳的转录文本，是"资产库"，不可篡改
@Model
final class EchoRecord {
    var id: UUID
    /// 音频分段文件路径（每 5 分钟一段）
    var audioSegments: [String]
    /// 最宝贵的非结构化资产——完整转录文本
    var fullTranscript: String
    /// AI 一句话摘要
    var summary: String?
    /// 总录音时长（秒）
    var duration: TimeInterval
    /// 创建时间
    var createdAt: Date
    /// 是否正在处理（转写/提取中）
    var isProcessing: Bool
    /// 处理进度描述
    var processingStatus: String?
    /// 已转写的分段数
    var transcribedSegments: Int
    /// 总分段数
    var totalSegments: Int

    init(
        audioSegments: [String] = [],
        fullTranscript: String = "",
        duration: TimeInterval = 0
    ) {
        self.id = UUID()
        self.audioSegments = audioSegments
        self.fullTranscript = fullTranscript
        self.duration = duration
        self.createdAt = Date()
        self.isProcessing = false
        self.transcribedSegments = 0
        self.totalSegments = 0
    }
}
