import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    var onSave: () -> Void
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedMood: Note.Mood?
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    @State private var showingMoodPicker = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, content, tag
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    TextField("标题", text: $title)
                        .font(.title2.bold())
                        .focused($focusedField, equals: .title)
                        .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Mood selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Note.Mood.allCases, id: \.self) { mood in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedMood = selectedMood == mood ? nil : mood
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.rawValue)
                                            .font(.title2)
                                        Text(mood.label)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedMood == mood ? Color.accentColor.opacity(0.15) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedMood == mood ? Color.accentColor : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Content editor
                    TextEditor(text: $content)
                        .font(.body)
                        .focused($focusedField, equals: .content)
                        .frame(minHeight: 200)
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden)
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("标签")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Existing tags
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text(tag)
                                                .font(.subheadline)
                                            Button {
                                                withAnimation {
                                                    tags.removeAll { $0 == tag }
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Add tag
                        HStack {
                            TextField("添加标签...", text: $tagInput)
                                .focused($focusedField, equals: .tag)
                                .onSubmit {
                                    addTag()
                                }
                            
                            Button("添加") {
                                addTag()
                            }
                            .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal)
                        
                        // Preset tags
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Tag.presets) { preset in
                                    Button {
                                        if !tags.contains(preset.name) {
                                            withAnimation {
                                                tags.append(preset.name)
                                            }
                                        }
                                    } label: {
                                        Text(preset.name)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                tags.contains(preset.name)
                                                    ? Color.accentColor.opacity(0.2)
                                                    : Color.secondary.opacity(0.1)
                                            )
                                            .clipShape(Capsule())
                                    }
                                    .disabled(tags.contains(preset.name))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(note.title.isEmpty ? "新笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveNote()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                title = note.title
                content = note.content
                selectedMood = note.mood
                tags = note.tags
                focusedField = note.title.isEmpty ? .title : .content
            }
        }
    }
    
    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        withAnimation {
            tags.append(tag)
        }
        tagInput = ""
    }
    
    private func saveNote() {
        note.title = title.trimmingCharacters(in: .whitespaces)
        note.content = content
        note.mood = selectedMood
        note.tags = tags
        note.updatedAt = Date()
        
        // Auto-generate title from content if empty
        if note.title.isEmpty && !note.content.isEmpty {
            note.title = note.content.firstLine.prefix(30)
        }
        
        try? StorageService.shared.modelContext.save()
        onSave()
        dismiss()
    }
}

#Preview {
    NoteEditorView(note: Note()) {
        print("Saved")
    }
}
