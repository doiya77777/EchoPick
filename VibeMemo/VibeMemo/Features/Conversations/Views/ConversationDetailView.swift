import SwiftUI

struct ConversationDetailView: View {
    @Bindable var conversation: Conversation
    @StateObject private var viewModel = ConversationViewModel()
    @State private var newMessage = ""
    @State private var selectedSpeaker = "我"
    @State private var isGeneratingSummary = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversation.messages) { message in
                            MessageBubbleView(message: message, isMe: message.speaker == "我")
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    if let lastMessage = conversation.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Summary card (if available)
            if let summary = conversation.summary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("AI 摘要", systemImage: "sparkles")
                            .font(.caption.bold())
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                        Spacer()
                    }
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            
            Divider()
            
            // Input area
            inputArea
        }
        .navigationTitle(conversation.title.isEmpty ? "对话详情" : conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task {
                            isGeneratingSummary = true
                            await viewModel.generateSummary(for: conversation)
                            isGeneratingSummary = false
                        }
                    } label: {
                        Label("生成摘要", systemImage: "sparkles")
                    }
                    
                    Menu("参与者") {
                        ForEach(conversation.participants, id: \.self) { participant in
                            Text(participant)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isGeneratingSummary {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("AI 正在生成摘要...")
                            .font(.headline)
                    }
                    .padding(32)
                    .background(.ultraThickMaterial)
                    .cornerRadius(20)
                }
            }
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 8) {
            // Speaker selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    speakerButton(name: "我")
                    
                    ForEach(conversation.participants, id: \.self) { participant in
                        speakerButton(name: participant)
                    }
                }
                .padding(.horizontal)
            }
            
            // Message input
            HStack(spacing: 12) {
                TextField("输入对话内容...", text: $newMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(newMessage.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .accentColor)
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func speakerButton(name: String) -> some View {
        Button {
            selectedSpeaker = name
        } label: {
            Text(name)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedSpeaker == name
                        ? Color.accentColor
                        : Color(.systemGray5)
                )
                .foregroundColor(selectedSpeaker == name ? .white : .primary)
                .clipShape(Capsule())
        }
    }
    
    private func sendMessage() {
        let content = newMessage.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        
        viewModel.addMessage(
            to: conversation,
            speaker: selectedSpeaker,
            content: content
        )
        newMessage = ""
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: ConversationMessage
    let isMe: Bool
    
    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 60) }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.speaker)
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isMe
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color(.systemGray5))
                    )
                    .foregroundColor(isMe ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                Text(message.createdAt.timeDisplay)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
            
            if !isMe { Spacer(minLength: 60) }
        }
    }
}

#Preview {
    let conversation = Conversation(title: "和小明聊天", participants: ["我", "小明"])
    
    return NavigationStack {
        ConversationDetailView(conversation: conversation)
    }
}
