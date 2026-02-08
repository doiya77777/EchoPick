import Foundation
import SwiftData

/// 数据持久化服务
/// 管理 SwiftData 容器和 CRUD 操作
@MainActor
class StorageService {
    static let shared = StorageService()
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    private init() {
        let schema = Schema([
            Note.self,
            Recording.self,
            Conversation.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer.mainContext
        } catch {
            fatalError("无法创建 SwiftData 容器：\(error)")
        }
    }
    
    // MARK: - Notes
    
    func saveNote(_ note: Note) {
        modelContext.insert(note)
        try? modelContext.save()
    }
    
    func deleteNote(_ note: Note) {
        modelContext.delete(note)
        try? modelContext.save()
    }
    
    func fetchNotes(searchText: String = "", sortBy: SortOption = .updatedAt) -> [Note] {
        var descriptor = FetchDescriptor<Note>()
        
        switch sortBy {
        case .updatedAt:
            descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        case .createdAt:
            descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        case .title:
            descriptor.sortBy = [SortDescriptor(\.title)]
        }
        
        if !searchText.isEmpty {
            descriptor.predicate = #Predicate<Note> { note in
                note.title.localizedStandardContains(searchText) ||
                note.content.localizedStandardContains(searchText)
            }
        }
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Recordings
    
    func saveRecording(_ recording: Recording) {
        modelContext.insert(recording)
        try? modelContext.save()
    }
    
    func deleteRecording(_ recording: Recording) {
        modelContext.delete(recording)
        try? modelContext.save()
    }
    
    func fetchRecordings() -> [Recording] {
        var descriptor = FetchDescriptor<Recording>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Conversations
    
    func saveConversation(_ conversation: Conversation) {
        modelContext.insert(conversation)
        try? modelContext.save()
    }
    
    func deleteConversation(_ conversation: Conversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }
    
    func fetchConversations() -> [Conversation] {
        var descriptor = FetchDescriptor<Conversation>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Sort Options
    
    enum SortOption: String, CaseIterable {
        case updatedAt = "最近更新"
        case createdAt = "创建时间"
        case title = "标题"
    }
}
