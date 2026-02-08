import SwiftUI
import Combine

@MainActor
final class ListenerViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var statusText = "准备就绪"
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isProcessing = false
    @Published var processingStatus = ""

    // 实时转录
    @Published var liveTranscript = ""
    @Published var pendingText = ""
    @Published var confirmedUtterances: [StreamingASRService.Utterance] = []
    @Published var connectionState: StreamingASRService.ConnectionState = .disconnected

    let audioEngine = AudioEngine()
    private let streamingASR = StreamingASRService()
    private let pickExtractor = PickExtractor()
    private let storage = StorageService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Bind audio engine @Published → ViewModel @Published
        // 使用 receive(on: DispatchQueue.main) 确保线程安全
        audioEngine.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        audioEngine.$elapsedTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$elapsedTime)
        audioEngine.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        // Bind streaming ASR state
        streamingASR.$liveTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveTranscript)
        streamingASR.$pendingText
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingText)
        streamingASR.$confirmedUtterances
            .receive(on: DispatchQueue.main)
            .assign(to: &$confirmedUtterances)
        streamingASR.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        // 设置 PCM 流式回调 → 送入 ASR
        audioEngine.onPCMBuffer = { [weak self] pcmData in
            guard let self else { return }
            Task {
                do {
                    try await self.streamingASR.sendAudio(pcmData)
                } catch {
                    print("⚠️ ASR send error: \(error)")
                }
            }
        }
    }

    var formattedTime: String {
        audioEngine.formattedElapsedTime
    }

    var segmentCount: Int {
        audioEngine.completedSegments.count + (isRecording ? 1 : 0)
    }

    /// 说话人统计（基于性别检测）
    var speakerSummary: String {
        let males = confirmedUtterances.filter { $0.speakerGender == "male" }.count
        let females = confirmedUtterances.filter { $0.speakerGender == "female" }.count
        if males == 0 && females == 0 { return "" }
        var parts: [String] = []
        if males > 0 { parts.append("♂\(males)句") }
        if females > 0 { parts.append("♀\(females)句") }
        return parts.joined(separator: " ")
    }

    // MARK: - Toggle Recording

    func toggleRecording() async {
        if isRecording {
            await stopAndProcess()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        do {
            // 先启动音频引擎
            try await audioEngine.startSession()
            statusText = "录音中"

            // 再启动流式 ASR
            do {
                try await streamingASR.startStreaming()
                statusText = "实时识别中..."
            } catch {
                // ASR 启动失败，仍然保留录音
                statusText = "录音中...（ASR 未连接）"
                print("⚠️ ASR 启动失败: \(error)")
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopAndProcess() async {
        // 1. 发送最后一包
        do { try await streamingASR.sendLastPacket() } catch {}

        // 2. 短暂等待最终结果
        statusText = "正在保存..."
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // 3. 断开 ASR + 停止录音
        streamingASR.disconnect()
        guard let result = audioEngine.stopSession() else {
            statusText = "准备就绪"
            return
        }

        // 4. 构建转录文本
        let transcript = streamingASR.finalTranscript
        let annotatedTranscript = buildAnnotatedTranscript()
        let finalText = annotatedTranscript.isEmpty ? transcript : annotatedTranscript

        // 5. 立即保存记录 + UI 回到空闲（不阻塞用户）
        let record = EchoRecord(
            audioSegments: result.segments.map { $0.path },
            duration: result.duration
        )
        record.totalSegments = result.segments.count
        record.fullTranscript = finalText

        // 有文本才标记需要 AI 处理
        let needsAI = !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        record.isProcessing = needsAI
        if needsAI {
            record.processingStatus = "AI 分析中..."
        }
        storage.saveRecord(record)

        // 6. UI 立刻恢复空闲
        statusText = "准备就绪"
        isProcessing = false

        // 7. 后台静默 AI 提取（不阻塞 UI）
        if needsAI {
            let recordId = record.id
            let transcriptCopy = transcript
            Task {
                await Self.extractPicksInBackground(
                    recordId: recordId,
                    transcript: transcriptCopy,
                    storage: storage,
                    extractor: pickExtractor
                )
            }
        }
    }

    /// 后台静默 AI 提取
    @MainActor
    private static func extractPicksInBackground(
        recordId: UUID,
        transcript: String,
        storage: StorageService,
        extractor: PickExtractor
    ) async {
        do {
            let extraction = try await extractor.extract(from: transcript)

            // 回到 MainActor 更新 SwiftData
            guard let record = storage.fetchRecords().first(where: { $0.id == recordId }) else { return }

            record.summary = extraction.summary

            var picks: [Pick] = []
            for topic in extraction.topics {
                picks.append(Pick(
                    recordId: recordId,
                    pickType: PickType.topic.rawValue,
                    content: topic.name,
                    timestampOffset: transcript.offset(of: topic.contextAnchor ?? topic.name) ?? 0,
                    contextAnchor: topic.contextAnchor ?? topic.name
                ))
            }
            for data in extraction.discreteData {
                picks.append(Pick(
                    recordId: recordId,
                    pickType: PickType.keyFact.rawValue,
                    content: "\(data.key)：\(data.value)",
                    timestampOffset: transcript.offset(of: data.contextAnchor) ?? 0,
                    contextAnchor: data.contextAnchor
                ))
            }
            for item in extraction.actionItems {
                picks.append(Pick(
                    recordId: recordId,
                    pickType: PickType.actionItem.rawValue,
                    content: item.task,
                    timestampOffset: transcript.offset(of: item.contextAnchor ?? item.task) ?? 0,
                    contextAnchor: item.contextAnchor ?? item.task
                ))
            }

            storage.savePicks(picks)
            record.isProcessing = false
            record.processingStatus = nil
            storage.save()
        } catch {
            if let record = storage.fetchRecords().first(where: { $0.id == recordId }) {
                record.isProcessing = false
                record.processingStatus = "AI 处理失败"
                storage.save()
            }
            print("⚠️ 后台AI提取失败: \(error)")
        }
    }

    // MARK: - Annotated Transcript

    /// 构建带说话人标签的转录文本
    private func buildAnnotatedTranscript() -> String {
        guard !confirmedUtterances.isEmpty else { return "" }

        var lines: [String] = []
        var currentSpeaker: String?

        for utt in confirmedUtterances {
            let speaker = utt.speakerGender ?? "unknown"
            let label = speakerLabel(for: speaker)

            if speaker != currentSpeaker {
                currentSpeaker = speaker
                lines.append("\n[\(label)]")
            }
            lines.append(utt.text)
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func speakerLabel(for gender: String) -> String {
        switch gender {
        case "male": return "说话人 A（男）"
        case "female": return "说话人 B（女）"
        default: return "说话人"
        }
    }
}
