import SwiftUI

struct TranscriptView: View {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recording Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(recording.fileName)
                                    .font(.headline)
                                Text(recording.createdAt.dateDisplay)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            Label("\(Int(recording.duration))秒", systemImage: "clock")
                            Label(recording.language == "zh" ? "中文" : recording.language, systemImage: "globe")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Transcript
                    if let transcript = recording.transcript {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("转写文本", systemImage: "doc.text")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button {
                                    UIPasteboard.general.string = transcript
                                    withAnimation {
                                        isCopied = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            isCopied = false
                                        }
                                    }
                                } label: {
                                    Label(
                                        isCopied ? "已复制" : "复制",
                                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                                    )
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isCopied ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text(transcript)
                                .font(.body)
                                .lineSpacing(6)
                                .textSelection(.enabled)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("暂无转写文本")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("请在录音列表中点击「转写」按钮")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("录音详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let recording = Recording(fileName: "test_recording.m4a", duration: 125)
    recording.transcript = "这是一段测试转写文本，包含了语音识别的结果。AI 会自动将你的语音转换为文字，支持中英文混合识别。"
    recording.isTranscribed = true
    
    return TranscriptView(recording: recording)
}
