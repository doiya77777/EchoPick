import SwiftUI
import SwiftData

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText = ""
    @Published var sortOption: StorageService.SortOption = .updatedAt
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedNote: Note?
    @Published var showingEditor = false
    
    private let storage = StorageService.shared
    private let aiService = AIService()
    
    func loadNotes() {
        notes = storage.fetchNotes(searchText: searchText, sortBy: sortOption)
    }
    
    func createNote() -> Note {
        let note = Note(title: "", content: "")
        storage.saveNote(note)
        loadNotes()
        return note
    }
    
    func deleteNote(_ note: Note) {
        storage.deleteNote(note)
        loadNotes()
    }
    
    func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            storage.deleteNote(notes[index])
        }
        loadNotes()
    }
    
    func togglePin(_ note: Note) {
        note.isPinned.toggle()
        note.updatedAt = Date()
        try? storage.modelContext.save()
        loadNotes()
    }
    
    func generateSummary(for note: Note) async {
        guard !note.content.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let summary = try await aiService.summarize(text: note.content)
            await MainActor.run {
                note.summary = summary
                note.updatedAt = Date()
                try? storage.modelContext.save()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    var pinnedNotes: [Note] {
        notes.filter { $0.isPinned }
    }
    
    var unpinnedNotes: [Note] {
        notes.filter { !$0.isPinned }
    }
}
