import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var isEncrypted: Bool
    var mood: Mood?
    var summary: String?
    var audioFilePath: String?
    var transcript: String?
    var isPinned: Bool
    
    enum Mood: String, Codable, CaseIterable {
        case happy = "😊"
        case neutral = "😐"
        case sad = "😢"
        case excited = "🤩"
        case thoughtful = "🤔"
        case anxious = "😰"
        
        var label: String {
            switch self {
            case .happy: return "开心"
            case .neutral: return "平静"
            case .sad: return "难过"
            case .excited: return "兴奋"
            case .thoughtful: return "沉思"
            case .anxious: return "焦虑"
            }
        }
    }
    
    init(
        title: String = "",
        content: String = "",
        tags: [String] = [],
        isEncrypted: Bool = false,
        mood: Mood? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
        self.isEncrypted = isEncrypted
        self.mood = mood
        self.isPinned = false
    }
}
