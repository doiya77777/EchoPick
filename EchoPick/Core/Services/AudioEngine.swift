import AVFoundation
import Foundation
import Combine

/// 音频录音引擎 — 支持后台录制 + 自动分段 + 实时 PCM 流式输出
/// 使用 AVAudioEngine 统一管道：实时 PCM 流 + AVAudioFile 写入
///
/// 标记为 @unchecked Sendable：内部通过 audioQueue 串行队列保证线程安全。
final class AudioEngine: ObservableObject, @unchecked Sendable {

    // MARK: - Published (UI 绑定)
    @MainActor @Published var isRecording = false
    @MainActor @Published var elapsedTime: TimeInterval = 0
    @MainActor @Published var audioLevel: Float = 0
    @MainActor @Published var currentSegmentIndex: Int = 0
    @MainActor @Published var errorMessage: String?
    @MainActor @Published var completedSegmentURL: URL?

    // MARK: - 实时 PCM 流式回调

    /// 产生 16kHz 16bit mono PCM 数据时调用
    var onPCMBuffer: (@Sendable (Data) -> Void)?

    // MARK: - Private (protected by audioQueue)

    private let audioQueue = DispatchQueue(label: "com.echopick.audioengine")

    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var writeFormat: AVAudioFormat?
    private var pcmAccumulator = Data()
    let pcmChunkSize = 6400  // 200ms @ 16kHz 16bit mono = 6400 bytes

    private var timer: Timer?
    private var segmentTimer: Timer?
    private var recordingStartTime: Date?
    private var segmentStartTime: Date?
    private var currentSessionId: UUID?
    private var sessionDirectory: URL?
    private var _completedSegments: [URL] = []
    private var _segmentIndex: Int = 0

    var completedSegments: [URL] {
        audioQueue.sync { _completedSegments }
    }

    /// 分段间隔（秒）— 默认 5 分钟
    let segmentInterval: TimeInterval = 5 * 60

    enum EngineError: Error, LocalizedError, Sendable {
        case permissionDenied
        case recordingFailed(String)
        case sessionConfigFailed(String)
        case simulatorNotSupported

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "麦克风权限被拒绝，请在设置中开启"
            case .recordingFailed(let m): return "录音失败：\(m)"
            case .sessionConfigFailed(let m): return "音频会话配置失败：\(m)"
            case .simulatorNotSupported: return "iOS 模拟器不支持实时录音，请使用真机测试"
            }
        }
    }

    // MARK: - Simulator Detection

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Start Recording Session

    @MainActor
    func startSession() async throws {
        let granted = await requestPermission()
        guard granted else { throw EngineError.permissionDenied }

        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw EngineError.sessionConfigFailed(error.localizedDescription)
        }

        // Create session directory
        let sessionId = UUID()
        let dir = getRecordingsBaseDirectory().appendingPathComponent(sessionId.uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        audioQueue.sync {
            self.currentSessionId = sessionId
            self.sessionDirectory = dir
            self._completedSegments = []
            self._segmentIndex = 0
            self.pcmAccumulator = Data()
        }

        // Start audio pipeline (off MainActor)
        try await Task.detached { [self] in
            try self.startAudioPipeline(directory: dir)
        }.value

        isRecording = true
        elapsedTime = 0
        currentSegmentIndex = 0

        audioQueue.sync { self.recordingStartTime = Date() }

        // Timers
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = self.audioQueue.sync { () -> TimeInterval? in
                guard let start = self.recordingStartTime else { return nil }
                return Date().timeIntervalSince(start)
            }
            if let elapsed {
                Task { @MainActor in self.elapsedTime = elapsed }
            }
        }

        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentInterval, repeats: true) { [weak self] _ in
            self?.rotateSegment()
        }
    }

    // MARK: - Stop Recording Session

    @MainActor
    func stopSession() -> (sessionId: UUID, segments: [URL], duration: TimeInterval)? {
        audioQueue.sync {
            self.engine?.inputNode.removeTap(onBus: 0)
            self.engine?.stop()
            self.engine = nil

            if !self.pcmAccumulator.isEmpty {
                let remaining = self.pcmAccumulator
                self.pcmAccumulator = Data()
                self.onPCMBuffer?(remaining)
            }
        }

        finalizeCurrentSegment()

        timer?.invalidate()
        timer = nil
        segmentTimer?.invalidate()
        segmentTimer = nil

        let result: (UUID, [URL], TimeInterval)? = audioQueue.sync {
            guard let sessionId = self.currentSessionId else { return nil }
            let segments = self._completedSegments
            let duration: TimeInterval = self.recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
            self.currentSessionId = nil
            self.recordingStartTime = nil
            return (sessionId, segments, duration)
        }

        isRecording = false
        elapsedTime = 0
        audioLevel = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return result
    }

    // MARK: - Audio Pipeline

    private func startAudioPipeline(directory dir: URL) throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode

        // 获取输入格式 — 不调用 prepare()，直接读取 inputNode 默认格式
        let hwFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 输入格式: sampleRate=\(hwFormat.sampleRate) ch=\(hwFormat.channelCount)")

        // 目标 PCM: 16kHz 16bit mono
        let pcmFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!

        // 文件格式 — 用实际可用的格式
        let tapFormat: AVAudioFormat?
        if hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 {
            tapFormat = hwFormat  // 真机：用硬件格式
        } else {
            tapFormat = nil  // 模拟器：让系统自己选
        }

        // 创建录音文件（用 tapFormat 或 PCM 格式）
        let fileFormat = tapFormat ?? pcmFormat
        let fileName = String(format: "segment_%03d.wav", 0)
        let fileURL = dir.appendingPathComponent(fileName)
        let file = try AVAudioFile(forWriting: fileURL, settings: fileFormat.settings)

        audioQueue.sync {
            self.outputFile = file
            self.writeFormat = fileFormat
            self.segmentStartTime = Date()
        }

        let queue = self.audioQueue
        let chunkSize = self.pcmChunkSize
        weak var weakSelf = self

        // 懒创建转换器
        var converter: AVAudioConverter?
        var converterReady = false
        let lock = NSLock()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
            guard let s = weakSelf else { return }
            let fmt = buffer.format

            // 懒初始化转换器
            lock.lock()
            if !converterReady {
                converterReady = true
                if fmt.sampleRate > 0 && fmt.channelCount > 0 {
                    converter = AVAudioConverter(from: fmt, to: pcmFormat)
                    print("🔄 转换器: \(fmt.sampleRate)Hz ch\(fmt.channelCount) → 16kHz mono")
                }
            }
            let conv = converter
            lock.unlock()

            // 写入文件
            queue.async {
                if let f = s.outputFile { try? f.write(from: buffer) }
            }

            // PCM 转换
            guard let conv, fmt.sampleRate > 0 else { return }
            let cap = AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / fmt.sampleRate))
            guard cap > 0, let out = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: cap) else { return }

            var err: NSError?
            let st = conv.convert(to: out, error: &err) { _, os in os.pointee = .haveData; return buffer }
            guard st != .error, err == nil, let ch = out.int16ChannelData else { return }

            let pcm = Data(bytes: ch[0], count: Int(out.frameLength) * 2)
            let level = AudioEngine.calcLevel(ch[0], Int(out.frameLength))
            Task { @MainActor in s.audioLevel = level }

            queue.async {
                s.pcmAccumulator.append(pcm)
                while s.pcmAccumulator.count >= chunkSize {
                    let chunk = Data(s.pcmAccumulator.prefix(chunkSize))
                    s.pcmAccumulator = Data(s.pcmAccumulator.dropFirst(chunkSize))
                    s.onPCMBuffer?(chunk)
                }
            }
        }

        // 启动
        do {
            try audioEngine.start()
            print("✅ AVAudioEngine 启动成功")
        } catch {
            // 模拟器可能不支持
            inputNode.removeTap(onBus: 0)
            if Self.isSimulator {
                throw EngineError.simulatorNotSupported
            }
            throw EngineError.recordingFailed("引擎启动失败: \(error.localizedDescription)")
        }

        audioQueue.sync { self.engine = audioEngine }
    }

    static func calcLevel(_ samples: UnsafePointer<Int16>, _ count: Int) -> Float {
        var sum: Float = 0
        let n = min(count, 1600)
        for i in 0..<n { sum += abs(Float(samples[i])) }
        return min(1.0, sum / Float(max(n, 1)) / 16000.0)
    }

    // MARK: - PCM Accumulation (testable)

    /// 累积 PCM 数据并输出完整的 chunk。可独立测试。
    static func accumulatePCM(
        accumulator: inout Data,
        newData: Data,
        chunkSize: Int,
        onChunk: (Data) -> Void
    ) {
        accumulator.append(newData)
        while accumulator.count >= chunkSize {
            let chunk = Data(accumulator.prefix(chunkSize))
            accumulator = Data(accumulator.dropFirst(chunkSize))
            onChunk(chunk)
        }
    }

    // MARK: - Segment

    private func rotateSegment() {
        finalizeCurrentSegment()
        audioQueue.sync {
            self._segmentIndex += 1
            guard let dir = self.sessionDirectory, let fmt = self.writeFormat else { return }
            let url = dir.appendingPathComponent(String(format: "segment_%03d.wav", self._segmentIndex))
            self.outputFile = try? AVAudioFile(forWriting: url, settings: fmt.settings)
            self.segmentStartTime = Date()
        }
        let idx = audioQueue.sync { _segmentIndex }
        Task { @MainActor in self.currentSegmentIndex = idx }
    }

    private func finalizeCurrentSegment() {
        audioQueue.sync {
            guard let file = self.outputFile else { return }
            let url = file.url
            self.outputFile = nil
            let sz = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            if sz > 1024 {
                self._completedSegments.append(url)
                Task { @MainActor in self.completedSegmentURL = url }
            }
        }
    }

    // MARK: - File Management

    func getRecordingsBaseDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("EchoRecordings")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func deleteSession(sessionId: String) {
        let dir = getRecordingsBaseDirectory().appendingPathComponent(sessionId)
        try? FileManager.default.removeItem(at: dir)
    }

    func sessionSize(sessionId: String) -> Int64 {
        let dir = getRecordingsBaseDirectory().appendingPathComponent(sessionId)
        guard let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in en {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    @MainActor
    var formattedElapsedTime: String {
        let h = Int(elapsedTime) / 3600
        let m = (Int(elapsedTime) % 3600) / 60
        let s = Int(elapsedTime) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
