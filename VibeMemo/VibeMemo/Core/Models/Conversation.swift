import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var participants: [String]
    var createdAt: Date
    var updatedAt: Date
    var summary: String?
    var recordingId: UUID?
    var messages: [ConversationMessage]
    var tags: [String]
    
    init(
        title: String = "",
        participants: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.participants = participants
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
        self.tags = []
    }
}

struct ConversationMessage: Codable, Identifiable {
    var id: UUID
    var speaker: String
    var content: String
    var timestamp: TimeInterval
    var createdAt: Date
    
    init(
        speaker: String,
        content: String,
        timestamp: TimeInterval
    ) {
        self.id = UUID()
        self.speaker = speaker
        self.content = content
        self.timestamp = timestamp
        self.createdAt = Date()
    }
}
