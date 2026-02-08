import SwiftUI

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NotesViewModel()
    @State private var showingSummary = false
    @State private var isGeneratingSummary = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let mood = note.mood {
                            Text(mood.rawValue)
                                .font(.title)
                        }
                        
                        Text(note.title.isEmpty ? "无标题笔记" : note.title)
                            .font(.title.bold())
                    }
                    
                    HStack(spacing: 16) {
                        Label(note.createdAt.dateDisplay, systemImage: "calendar")
                        Label(note.content.estimatedReadingTime, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Content
                Text(note.content.isEmpty ? "暂无内容" : note.content)
                    .font(.body)
                    .foregroundColor(note.content.isEmpty ? .secondary : .primary)
                    .padding(.horizontal)
                
                // Transcript (if available)
                if let transcript = note.transcript, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("语音转写", systemImage: "waveform")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text(transcript)
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // AI Summary
                if let summary = note.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI 摘要", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(summary)
                            .font(.body)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.purple.opacity(0.05), .blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Tags
                if !note.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task {
                            isGeneratingSummary = true
                            await viewModel.generateSummary(for: note)
                            isGeneratingSummary = false
                        }
                    } label: {
                        Label("生成 AI 摘要", systemImage: "sparkles")
                    }
                    
                    Button {
                        viewModel.togglePin(note)
                    } label: {
                        Label(
                            note.isPinned ? "取消固定" : "固定笔记",
                            systemImage: note.isPinned ? "pin.slash" : "pin.fill"
                        )
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        viewModel.deleteNote(note)
                        dismiss()
                    } label: {
                        Label("删除笔记", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isGeneratingSummary {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("AI 正在分析...")
                            .font(.headline)
                    }
                    .padding(32)
                    .background(.ultraThickMaterial)
                    .cornerRadius(20)
                }
            }
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(note: Note(
            title: "这是一个测试笔记",
            content: "这里是笔记的详细内容，可能包含很多文字。\n\n这是第二段话。",
            tags: ["灵感", "待办", "重要"],
            mood: .thoughtful
        ))
    }
}
