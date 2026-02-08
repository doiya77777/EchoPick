import SwiftUI
import AVFoundation

@MainActor
final class EchoDetailViewModel: ObservableObject {
    @Published var record: EchoRecord
    @Published var picks: [Pick] = []
    @Published var highlightedAnchor: String?
    @Published var isReprocessing = false
    @Published var copyToast = false

    // Audio playback
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?

    private let storage = StorageService.shared
    private let pickExtractor = PickExtractor()

    init(record: EchoRecord) {
        self.record = record
        loadPicks()
    }

    func loadPicks() {
        picks = storage.fetchPicks(for: record.id)
    }

    // MARK: - Filtered picks

    var topicPicks: [Pick] {
        picks.filter { $0.pickType == PickType.topic.rawValue }
    }
    var factPicks: [Pick] {
        picks.filter { $0.pickType == PickType.keyFact.rawValue || $0.pickType == PickType.keyMetric.rawValue }
    }
    var actionPicks: [Pick] {
        picks.filter { $0.pickType == PickType.actionItem.rawValue }
    }
    var sentimentPicks: [Pick] {
        picks.filter { $0.pickType == PickType.sentiment.rawValue }
    }

    // MARK: - Copy

    func copyTranscript() {
        UIPasteboard.general.string = record.fullTranscript
        copyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.copyToast = false
        }
    }

    func copySummary() {
        guard let summary = record.summary else { return }
        UIPasteboard.general.string = summary
        copyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.copyToast = false
        }
    }

    // MARK: - Audio Playback

    var hasAudio: Bool {
        !record.audioSegments.isEmpty && record.audioSegments.contains { FileManager.default.fileExists(atPath: $0) }
    }

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        // Find first available segment
        guard let path = record.audioSegments.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        let url = URL(fileURLWithPath: path)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let player = self.audioPlayer else { return }
                    self.playbackProgress = player.currentTime / max(player.duration, 1)
                    if !player.isPlaying {
                        self.stopPlayback()
                    }
                }
            }
        } catch {
            print("Playback error: \(error)")
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackProgress = 0
    }

    // MARK: - Source Tracing

    func traceToSource(_ pick: Pick) {
        highlightedAnchor = pick.contextAnchor
    }

    func clearHighlight() {
        highlightedAnchor = nil
    }

    // MARK: - Reprocess

    func reprocess() async {
        isReprocessing = true
        defer { isReprocessing = false }

        guard !record.fullTranscript.isEmpty else { return }

        do {
            let extraction = try await pickExtractor.extract(from: record.fullTranscript)
            record.summary = extraction.summary

            for pick in picks { storage.context.delete(pick) }

            var newPicks: [Pick] = []
            for topic in extraction.topics {
                newPicks.append(Pick(
                    recordId: record.id, pickType: PickType.topic.rawValue,
                    content: topic.name,
                    timestampOffset: record.fullTranscript.offset(of: topic.contextAnchor ?? topic.name) ?? 0,
                    contextAnchor: topic.contextAnchor ?? topic.name
                ))
            }
            for data in extraction.discreteData {
                newPicks.append(Pick(
                    recordId: record.id, pickType: PickType.keyFact.rawValue,
                    content: "\(data.key)：\(data.value)",
                    timestampOffset: record.fullTranscript.offset(of: data.contextAnchor) ?? 0,
                    contextAnchor: data.contextAnchor
                ))
            }
            for item in extraction.actionItems {
                newPicks.append(Pick(
                    recordId: record.id, pickType: PickType.actionItem.rawValue,
                    content: item.task,
                    timestampOffset: record.fullTranscript.offset(of: item.contextAnchor ?? item.task) ?? 0,
                    contextAnchor: item.contextAnchor ?? item.task
                ))
            }

            storage.savePicks(newPicks)
            storage.save()
            loadPicks()
        } catch {
            print("Reprocess error: \(error)")
        }
    }
}
