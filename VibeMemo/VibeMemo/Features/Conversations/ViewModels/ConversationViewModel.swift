import SwiftUI

@MainActor
class ConversationViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storage = StorageService.shared
    private let aiService = AIService()
    
    func loadConversations() {
        conversations = storage.fetchConversations()
    }
    
    func createConversation(title: String, participants: [String]) -> Conversation {
        let conversation = Conversation(title: title, participants: participants)
        storage.saveConversation(conversation)
        loadConversations()
        return conversation
    }
    
    func deleteConversation(_ conversation: Conversation) {
        storage.deleteConversation(conversation)
        loadConversations()
    }
    
    func addMessage(to conversation: Conversation, speaker: String, content: String, timestamp: TimeInterval = 0) {
        let message = ConversationMessage(speaker: speaker, content: content, timestamp: timestamp)
        conversation.messages.append(message)
        conversation.updatedAt = Date()
        try? storage.modelContext.save()
    }
    
    func generateSummary(for conversation: Conversation) async {
        guard !conversation.messages.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let messagesText = conversation.messages.map { "\($0.speaker): \($0.content)" }.joined(separator: "\n")
        
        do {
            let summary = try await aiService.summarize(text: messagesText)
            await MainActor.run {
                conversation.summary = summary
                conversation.updatedAt = Date()
                try? storage.modelContext.save()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
