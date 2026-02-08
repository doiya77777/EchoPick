import Foundation

struct Tag: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var color: String // Hex color code
    var usageCount: Int
    
    init(name: String, color: String = "#6366F1") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.usageCount = 0
    }
    
    // Predefined tags
    static let presets: [Tag] = [
        Tag(name: "灵感", color: "#F59E0B"),
        Tag(name: "待办", color: "#EF4444"),
        Tag(name: "日记", color: "#10B981"),
        Tag(name: "会议", color: "#3B82F6"),
        Tag(name: "想法", color: "#8B5CF6"),
        Tag(name: "学习", color: "#EC4899"),
    ]
}
