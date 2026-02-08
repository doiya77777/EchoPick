import SwiftUI

struct NotesListView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var showingNewNote = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.notes.isEmpty && viewModel.searchText.isEmpty {
                    emptyStateView
                } else {
                    notesList
                }
            }
            .navigationTitle("笔记")
            .searchable(text: $viewModel.searchText, prompt: "搜索笔记...")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.loadNotes()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(StorageService.SortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.sortOption = option
                                viewModel.loadNotes()
                            } label: {
                                if viewModel.sortOption == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let note = viewModel.createNote()
                        viewModel.selectedNote = note
                        showingNewNote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingNewNote) {
                if let note = viewModel.selectedNote {
                    NoteEditorView(note: note) {
                        viewModel.loadNotes()
                    }
                }
            }
            .onAppear {
                viewModel.loadNotes()
            }
        }
    }
    
    // MARK: - Notes List
    
    private var notesList: some View {
        List {
            if !viewModel.pinnedNotes.isEmpty {
                Section("已固定") {
                    ForEach(viewModel.pinnedNotes) { note in
                        NoteRowView(note: note)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteNote(note)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    viewModel.togglePin(note)
                                } label: {
                                    Label("取消固定", systemImage: "pin.slash")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
            
            Section(viewModel.pinnedNotes.isEmpty ? "" : "全部笔记") {
                ForEach(viewModel.unpinnedNotes) { note in
                    NoteRowView(note: note)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteNote(note)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            
                            Button {
                                viewModel.togglePin(note)
                            } label: {
                                Label("固定", systemImage: "pin.fill")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("还没有笔记")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("点击右上角 + 开始记录你的第一个想法")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                let note = viewModel.createNote()
                viewModel.selectedNote = note
                showingNewNote = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("创建笔记")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Note Row View

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        NavigationLink {
            NoteDetailView(note: note)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let mood = note.mood {
                        Text(mood.rawValue)
                    }
                    
                    Text(note.title.isEmpty ? "无标题" : note.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if note.audioFilePath != nil {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(note.updatedAt.smartDisplay)
                        .font(.caption)
                        .foregroundColor(.tertiary)
                    
                    Spacer()
                    
                    if !note.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(note.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    NotesListView()
}
