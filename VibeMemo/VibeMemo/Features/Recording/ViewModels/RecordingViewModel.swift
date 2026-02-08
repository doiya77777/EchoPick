import SwiftUI
import AVFoundation

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordings: [Recording] = []
    @Published var currentRecordingURL: URL?
    @Published var errorMessage: String?
    @Published var isTranscribing = false
    @Published var transcriptionProgress: String = ""
    @Published var audioLevel: Float = 0
    
    private let audioService = AudioService()
    private let aiService = AIService()
    private let storage = StorageService.shared
    private var timer: Timer?
    
    func requestPermission() async -> Bool {
        await audioService.requestPermission()
    }
    
    func startRecording() async {
        let hasPermission = await requestPermission()
        guard hasPermission else {
            errorMessage = "请在设置中允许 VibeMemo 使用麦克风"
            return
        }
        
        do {
            let url = try await audioService.startRecording()
            currentRecordingURL = url
            isRecording = true
            recordingTime = 0
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stopRecording() async {
        stopTimer()
        
        guard let result = await audioService.stopRecording() else { return }
        
        isRecording = false
        
        let recording = Recording(
            fileName: result.url.lastPathComponent,
            duration: result.duration,
            fileSize: await audioService.getFileSize(at: result.url)
        )
        recording.filePath = result.url.path
        
        storage.saveRecording(recording)
        loadRecordings()
    }
    
    func loadRecordings() {
        recordings = storage.fetchRecordings()
    }
    
    func deleteRecording(_ recording: Recording) {
        if !recording.filePath.isEmpty {
            try? FileManager.default.removeItem(atPath: recording.filePath)
        }
        storage.deleteRecording(recording)
        loadRecordings()
    }
    
    func transcribeRecording(_ recording: Recording) async {
        guard !recording.filePath.isEmpty else {
            errorMessage = "音频文件不存在"
            return
        }
        
        isTranscribing = true
        transcriptionProgress = "正在转写..."
        
        do {
            let fileURL = URL(fileURLWithPath: recording.filePath)
            let result = try await aiService.transcribeAudio(fileURL: fileURL)
            
            await MainActor.run {
                recording.transcript = result.text
                recording.isTranscribed = true
                try? storage.modelContext.save()
                loadRecordings()
            }
            
            transcriptionProgress = "转写完成！"
        } catch {
            errorMessage = error.localizedDescription
            transcriptionProgress = ""
        }
        
        isTranscribing = false
    }
    
    func createNoteFromRecording(_ recording: Recording) {
        guard let transcript = recording.transcript else { return }
        
        let note = Note(
            title: "语音笔记 - \(recording.createdAt.dayDisplay)",
            content: transcript,
            tags: ["语音"]
        )
        note.audioFilePath = recording.filePath
        note.transcript = transcript
        
        storage.saveNote(note)
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Formatting
    
    var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        let tenths = Int((recordingTime * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
