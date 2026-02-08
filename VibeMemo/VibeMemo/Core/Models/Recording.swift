import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var fileName: String
    var duration: TimeInterval
    var fileSize: Int64
    var createdAt: Date
    var transcript: String?
    var isTranscribed: Bool
    var language: String
    var filePath: String
    
    init(
        fileName: String,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        language: String = "zh"
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.duration = duration
        self.fileSize = fileSize
        self.createdAt = Date()
        self.isTranscribed = false
        self.language = language
        self.filePath = ""
    }
}
