import AVFoundation
import Foundation

/// 音频录制与播放服务
actor AudioService {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingStartTime: Date?
    
    enum AudioError: Error, LocalizedError {
        case permissionDenied
        case recordingFailed(String)
        case playbackFailed(String)
        case fileNotFound
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "麦克风权限被拒绝，请在设置中开启"
            case .recordingFailed(let message):
                return "录音失败：\(message)"
            case .playbackFailed(let message):
                return "播放失败：\(message)"
            case .fileNotFound:
                return "音频文件未找到"
            }
        }
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording(fileName: String? = nil) throws -> URL {
        let name = fileName ?? "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = getRecordingsDirectory().appendingPathComponent(name)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            recordingStartTime = Date()
            
            return url
        } catch {
            throw AudioError.recordingFailed(error.localizedDescription)
        }
    }
    
    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder else { return nil }
        
        let url = recorder.url
        let duration = recorder.currentTime
        
        recorder.stop()
        audioRecorder = nil
        recordingStartTime = nil
        
        return (url, duration)
    }
    
    // MARK: - Playback
    
    func play(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioError.fileNotFound
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            throw AudioError.playbackFailed(error.localizedDescription)
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    func isPlaying() -> Bool {
        audioPlayer?.isPlaying ?? false
    }
    
    // MARK: - File Management
    
    func getRecordingsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")
        
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        
        return recordingsPath
    }
    
    func deleteRecording(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func getFileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int64 ?? 0
    }
}
