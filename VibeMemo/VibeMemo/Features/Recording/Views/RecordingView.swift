import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @State private var showingTranscript = false
    @State private var selectedRecording: Recording?
    @State private var pulseAnimation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Recording area
                recordingArea
                    .frame(maxHeight: .infinity)
                
                // Recordings list
                if !viewModel.recordings.isEmpty {
                    recordingsList
                        .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("录音")
            .onAppear {
                viewModel.loadRecordings()
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $selectedRecording) { recording in
                TranscriptView(recording: recording)
            }
        }
    }
    
    // MARK: - Recording Area
    
    private var recordingArea: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Waveform visualization
            ZStack {
                // Pulse rings
                if viewModel.isRecording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.red.opacity(0.2 - Double(index) * 0.05), lineWidth: 2)
                            .frame(width: CGFloat(160 + index * 40), height: CGFloat(160 + index * 40))
                            .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 1.5)
                                    .repeatForever()
                                    .delay(Double(index) * 0.3),
                                value: pulseAnimation
                            )
                    }
                }
                
                // Main record button
                Button {
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecording()
                            pulseAnimation = false
                        } else {
                            await viewModel.startRecording()
                            pulseAnimation = true
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                viewModel.isRecording
                                    ? RadialGradient(
                                        colors: [.red, .red.opacity(0.7)],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 60
                                    )
                                    : RadialGradient(
                                        colors: [
                                            Color(red: 0.4, green: 0.3, blue: 0.9),
                                            Color(red: 0.3, green: 0.2, blue: 0.8)
                                        ],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 60
                                    )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: viewModel.isRecording ? .red.opacity(0.4) : .purple.opacity(0.4), radius: 20)
                        
                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Timer display
            VStack(spacing: 8) {
                Text(viewModel.formattedTime)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(viewModel.isRecording ? .red : .primary)
                
                Text(viewModel.isRecording ? "录音中..." : "点击开始录音")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Recordings List
    
    private var recordingsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("录音记录")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.recordings.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
            
            List {
                ForEach(viewModel.recordings) { recording in
                    RecordingRowView(
                        recording: recording,
                        formattedDuration: viewModel.formatDuration(recording.duration)
                    ) {
                        selectedRecording = recording
                    } onTranscribe: {
                        Task {
                            await viewModel.transcribeRecording(recording)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteRecording(recording)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        if recording.isTranscribed {
                            Button {
                                viewModel.createNoteFromRecording(recording)
                            } label: {
                                Label("转为笔记", systemImage: "note.text")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 4)
    }
}

// MARK: - Recording Row

struct RecordingRowView: View {
    let recording: Recording
    let formattedDuration: String
    let onTap: () -> Void
    let onTranscribe: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(recording.isTranscribed ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: recording.isTranscribed ? "checkmark.circle.fill" : "waveform")
                        .foregroundColor(recording.isTranscribed ? .green : .blue)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.fileName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(formattedDuration)
                        Text("·")
                        Text(recording.createdAt.smartDisplay)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Transcribe button
                if !recording.isTranscribed {
                    Button {
                        onTranscribe()
                    } label: {
                        Label("转写", systemImage: "text.bubble")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RecordingView()
}
