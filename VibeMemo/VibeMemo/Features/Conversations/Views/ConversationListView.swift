import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationViewModel()
    @State private var showingNewConversation = false
    @State private var newTitle = ""
    @State private var newParticipants = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .navigationTitle("对话记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewConversation = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .alert("新对话", isPresented: $showingNewConversation) {
                TextField("对话标题", text: $newTitle)
                TextField("参与者（逗号分隔）", text: $newParticipants)
                
                Button("取消", role: .cancel) {
                    newTitle = ""
                    newParticipants = ""
                }
                
                Button("创建") {
                    let participants = newParticipants
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    
                    _ = viewModel.createConversation(
                        title: newTitle.isEmpty ? "新对话" : newTitle,
                        participants: participants
                    )
                    newTitle = ""
                    newParticipants = ""
                }
            }
            .onAppear {
                viewModel.loadConversations()
            }
        }
    }
    
    // MARK: - Conversations List
    
    private var conversationsList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink {
                    ConversationDetailView(conversation: conversation)
                } label: {
                    ConversationRowView(conversation: conversation)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteConversation(conversation)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("还没有对话记录")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("记录你和朋友的重要对话\nAI 会帮你自动生成摘要")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingNewConversation = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("开始记录")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
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

// MARK: - Conversation Row

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conversation.title.isEmpty ? "无标题对话" : conversation.title)
                    .font(.headline)
                Spacer()
                Text("\(conversation.messages.count) 条消息")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !conversation.participants.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                    Text(conversation.participants.joined(separator: "、"))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            if let summary = conversation.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(2)
            }
            
            Text(conversation.updatedAt.smartDisplay)
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationListView()
}
