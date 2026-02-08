import XCTest
import AVFoundation
@testable import EchoPick

/// 🧪 EchoPick 单元测试 + 集成测试
/// - 单元测试: 不依赖硬件/网络，在模拟器上可以跑
/// - 集成测试: 需要 API key 和网络
final class EchoPickIntegrationTests: XCTestCase {

    private var asrAppKey: String?
    private var asrAccessKey: String?
    private var doubaoLLMKey: String?

    override func setUp() {
        super.setUp()
        asrAppKey = readKeyFile("/Users/doiya/.echopick_test_asr_appkey")
        asrAccessKey = readKeyFile("/Users/doiya/.echopick_test_asr_accesskey")
        doubaoLLMKey = readKeyFile("/Users/doiya/.echopick_test_doubao_llm_key")
    }

    private func readKeyFile(_ path: String) -> String? {
        (try? String(contentsOfFile: path, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func skipIfNoASRKeys() throws {
        guard asrAppKey != nil, asrAccessKey != nil else {
            throw XCTSkip("ASR keys not found. Create ~/.echopick_test_asr_appkey and ~/.echopick_test_asr_accesskey")
        }
    }

    private func skipIfNoLLMKey() throws {
        guard doubaoLLMKey != nil else {
            throw XCTSkip("LLM key not found. Create ~/.echopick_test_doubao_llm_key")
        }
    }

    // ============================================================
    // MARK: - 🧪 单元测试（不需要硬件/网络，模拟器可跑）
    // ============================================================

    // MARK: - PCM 累积逻辑

    func testPCMAccumulation_exactChunk() {
        // 恰好一个 chunk 大小
        var acc = Data()
        var chunks: [Data] = []
        let data = Data(repeating: 0xAB, count: 6400)

        AudioEngine.accumulatePCM(accumulator: &acc, newData: data, chunkSize: 6400) { chunk in
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.count, 1, "应该产生 1 个 chunk")
        XCTAssertEqual(chunks[0].count, 6400)
        XCTAssertEqual(acc.count, 0, "累积器应该为空")
    }

    func testPCMAccumulation_partialChunk() {
        // 不足一个 chunk
        var acc = Data()
        var chunks: [Data] = []
        let data = Data(repeating: 0xAB, count: 3000)

        AudioEngine.accumulatePCM(accumulator: &acc, newData: data, chunkSize: 6400) { chunk in
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.count, 0, "不足一个 chunk 不应输出")
        XCTAssertEqual(acc.count, 3000, "应保留在累积器中")
    }

    func testPCMAccumulation_multipleChunks() {
        // 多个 chunk + 余数
        var acc = Data()
        var chunks: [Data] = []
        let data = Data(repeating: 0xCD, count: 15000)  // 2 * 6400 + 2200

        AudioEngine.accumulatePCM(accumulator: &acc, newData: data, chunkSize: 6400) { chunk in
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.count, 2, "应该产生 2 个 chunk")
        XCTAssertEqual(acc.count, 2200, "余下 2200 bytes")
    }

    func testPCMAccumulation_incrementalFeed() {
        // 分多次喂入，模拟实时场景
        var acc = Data()
        var chunks: [Data] = []

        // 第 1 次: 3200 bytes (半个 chunk)
        AudioEngine.accumulatePCM(accumulator: &acc, newData: Data(count: 3200), chunkSize: 6400) { chunks.append($0) }
        XCTAssertEqual(chunks.count, 0)
        XCTAssertEqual(acc.count, 3200)

        // 第 2 次: 再 3200 bytes → 凑够一个 chunk
        AudioEngine.accumulatePCM(accumulator: &acc, newData: Data(count: 3200), chunkSize: 6400) { chunks.append($0) }
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(acc.count, 0)

        // 第 3 次: 10000 bytes → 1 chunk + 余 3600
        AudioEngine.accumulatePCM(accumulator: &acc, newData: Data(count: 10000), chunkSize: 6400) { chunks.append($0) }
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(acc.count, 3600)
    }

    func testPCMAccumulation_empty() {
        var acc = Data()
        var chunks: [Data] = []

        AudioEngine.accumulatePCM(accumulator: &acc, newData: Data(), chunkSize: 6400) { chunks.append($0) }
        XCTAssertEqual(chunks.count, 0)
        XCTAssertEqual(acc.count, 0)
    }

    // MARK: - 音频电平计算

    func testAudioLevelCalculation_silence() {
        // 静音 → 电平 = 0
        var samples = [Int16](repeating: 0, count: 1600)
        let level = samples.withUnsafeBufferPointer { ptr in
            AudioEngine.calcLevel(ptr.baseAddress!, 1600)
        }
        XCTAssertEqual(level, 0.0, accuracy: 0.001)
    }

    func testAudioLevelCalculation_maxVolume() {
        // 最大音量 → 电平 = 1.0 (capped)
        var samples = [Int16](repeating: Int16.max, count: 1600)
        let level = samples.withUnsafeBufferPointer { ptr in
            AudioEngine.calcLevel(ptr.baseAddress!, 1600)
        }
        XCTAssertEqual(level, 1.0, accuracy: 0.1)
    }

    func testAudioLevelCalculation_mediumVolume() {
        // 中等音量
        var samples = [Int16](repeating: 8000, count: 1600)
        let level = samples.withUnsafeBufferPointer { ptr in
            AudioEngine.calcLevel(ptr.baseAddress!, 1600)
        }
        XCTAssertTrue(level > 0.0 && level < 1.0, "中等音量应在 0-1 之间: \(level)")
    }

    // MARK: - 文件管理

    func testRecordingsBaseDirectory() {
        let engine = AudioEngine()
        let dir = engine.getRecordingsBaseDirectory()
        XCTAssertTrue(dir.path.contains("EchoRecordings"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }

    func testDeleteSession() {
        let engine = AudioEngine()
        let baseDir = engine.getRecordingsBaseDirectory()
        let testId = "test-session-\(UUID().uuidString)"
        let sessionDir = baseDir.appendingPathComponent(testId)

        // 创建测试目录和文件
        try! FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let testFile = sessionDir.appendingPathComponent("test.wav")
        try! "test".write(to: testFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path))

        // 删除
        engine.deleteSession(sessionId: testId)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionDir.path))
    }

    func testSessionSize() {
        let engine = AudioEngine()
        let baseDir = engine.getRecordingsBaseDirectory()
        let testId = "test-size-\(UUID().uuidString)"
        let sessionDir = baseDir.appendingPathComponent(testId)

        try! FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let data = Data(repeating: 0xFF, count: 1024)
        try! data.write(to: sessionDir.appendingPathComponent("audio.wav"))

        let size = engine.sessionSize(sessionId: testId)
        XCTAssertEqual(size, 1024, "应该返回 1024 bytes")

        // 清理
        engine.deleteSession(sessionId: testId)
    }

    // MARK: - API Key 存储

    func testAPIKeyRoundTrip() throws {
        // 保存 → 读取 → 删除
        let testKey = "test-key-\(UUID().uuidString)"
        try APIKeyStore.saveASRAppKey(testKey)
        let loaded = APIKeyStore.loadASRAppKey()
        XCTAssertEqual(loaded, testKey)

        try APIKeyStore.deleteASRAppKey()
        XCTAssertNil(APIKeyStore.loadASRAppKey())
    }

    func testASRAccessKeyRoundTrip() throws {
        let testKey = "test-access-\(UUID().uuidString)"
        try APIKeyStore.saveASRAccessKey(testKey)
        let loaded = APIKeyStore.loadASRAccessKey()
        XCTAssertEqual(loaded, testKey)

        try APIKeyStore.deleteASRAccessKey()
        XCTAssertNil(APIKeyStore.loadASRAccessKey())
    }

    // MARK: - AudioEngine 模拟器行为

    func testSimulatorDetection() {
        #if targetEnvironment(simulator)
        XCTAssertTrue(AudioEngine.isSimulator)
        #else
        XCTAssertFalse(AudioEngine.isSimulator)
        #endif
    }

    func testAudioEngineInitialState() async {
        let engine = AudioEngine()
        let isRecording = await MainActor.run { engine.isRecording }
        let level = await MainActor.run { engine.audioLevel }

        XCTAssertFalse(isRecording)
        XCTAssertEqual(level, 0.0)
        XCTAssertTrue(engine.completedSegments.isEmpty)
    }

    @MainActor
    func testFormattedTime() async {
        let engine = AudioEngine()

        engine.elapsedTime = 0
        XCTAssertEqual(engine.formattedElapsedTime, "00:00")

        engine.elapsedTime = 65
        XCTAssertEqual(engine.formattedElapsedTime, "01:05")

        engine.elapsedTime = 3661
        XCTAssertEqual(engine.formattedElapsedTime, "1:01:01")
    }

    // MARK: - StreamingASR 协议测试

    @MainActor
    func testStreamingASRInitialState() {
        let asr = StreamingASRService()
        XCTAssertEqual(asr.connectionState, .disconnected)
        XCTAssertTrue(asr.liveTranscript.isEmpty)
        XCTAssertTrue(asr.confirmedUtterances.isEmpty)
        XCTAssertNil(asr.error)
    }

    func testStreamingASRNoCredentials() async {
        // 没有配置 key 应该抛出 noCredentials
        try? APIKeyStore.deleteASRAppKey()
        try? APIKeyStore.deleteASRAccessKey()

        let asr = await MainActor.run { StreamingASRService() }
        do {
            try await asr.startStreaming()
            XCTFail("应该抛出 noCredentials 错误")
        } catch {
            // 预期的错误
            print("✅ 无凭证时正确抛出错误: \(error)")
        }
    }

    // ============================================================
    // MARK: - 🌐 集成测试（需要网络 + API Key）
    // ============================================================

    @MainActor
    func testStreamingASRConnection() async throws {
        try skipIfNoASRKeys()
        try APIKeyStore.saveASRAppKey(asrAppKey!)
        try APIKeyStore.saveASRAccessKey(asrAccessKey!)

        let streamingASR = StreamingASRService()

        print("🔌 测试 WebSocket 连接到 Seed ASR 2.0...")
        try await streamingASR.startStreaming()

        XCTAssertTrue(
            streamingASR.connectionState == .connected || streamingASR.connectionState == .streaming,
            "应该处于已连接状态，当前: \(streamingASR.connectionState.rawValue)"
        )
        print("   ✅ 连接成功！状态: \(streamingASR.connectionState.rawValue)")

        // 发 1 秒静音
        let silenceData = Data(count: 32000)
        try await streamingASR.sendAudio(silenceData)
        try await Task.sleep(nanoseconds: 1_000_000_000)

        try await streamingASR.sendLastPacket()
        try await Task.sleep(nanoseconds: 2_000_000_000)

        if let error = streamingASR.error {
            XCTFail("ASR 错误: \(error.localizedDescription)")
        }

        streamingASR.disconnect()
        print("✅ 流式 ASR 连接测试通过！")
    }

    @MainActor
    func testStreamingASRWithAudio() async throws {
        try skipIfNoASRKeys()
        try APIKeyStore.saveASRAppKey(asrAppKey!)
        try APIKeyStore.saveASRAccessKey(asrAccessKey!)

        let testAudioURL = try getTestAudioURL()
        let pcmData = try convertToPCM(url: testAudioURL)
        print("📎 PCM: \(pcmData.count) bytes (\(Double(pcmData.count) / 32000.0)s)")

        let streamingASR = StreamingASRService()
        try await streamingASR.startStreaming()

        // 分包发送
        let chunkSize = 6400
        var offset = 0
        while offset < pcmData.count {
            let end = min(offset + chunkSize, pcmData.count)
            try await streamingASR.sendAudio(Data(pcmData[offset..<end]))
            offset = end
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        try await streamingASR.sendLastPacket()
        try await Task.sleep(nanoseconds: 3_000_000_000)

        let finalText = streamingASR.finalTranscript
        print("✅ 转录: \(finalText)")
        print("   分句数: \(streamingASR.confirmedUtterances.count)")

        if let error = streamingASR.error {
            XCTFail("ASR 错误: \(error.localizedDescription)")
        }
        XCTAssertFalse(finalText.isEmpty, "转录不应为空")

        streamingASR.disconnect()
    }

    @MainActor
    func testFullPipeline() async throws {
        try skipIfNoASRKeys()
        try skipIfNoLLMKey()
        try APIKeyStore.saveASRAppKey(asrAppKey!)
        try APIKeyStore.saveASRAccessKey(asrAccessKey!)
        try APIKeyStore.saveDoubaoLLM(doubaoLLMKey!)

        let testAudioURL = try getTestAudioURL()
        let pcmData = try convertToPCM(url: testAudioURL)

        // ASR
        let asr = StreamingASRService()
        try await asr.startStreaming()

        var offset = 0
        while offset < pcmData.count {
            let end = min(offset + 6400, pcmData.count)
            try await asr.sendAudio(Data(pcmData[offset..<end]))
            offset = end
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await asr.sendLastPacket()
        try await Task.sleep(nanoseconds: 3_000_000_000)

        let transcript = asr.finalTranscript
        XCTAssertFalse(transcript.isEmpty)
        asr.disconnect()

        // LLM Pick
        let extractor = PickExtractor()
        let result = try await extractor.extract(from: transcript)

        print("📝 摘要: \(result.summary)")
        print("🏷️ 主题: \(result.topics.map { $0.name })")
        print("📊 数据: \(result.discreteData.map { "\($0.key)=\($0.value)" })")
        print("✅ 待办: \(result.actionItems.map { $0.task })")

        XCTAssertFalse(result.summary.isEmpty, "摘要不应为空")
    }

    // MARK: - Helpers

    private func getTestAudioURL() throws -> URL {
        // 查找测试音频文件
        let paths = [
            "/Users/doiya/vibe_project/EchoPick/Tests/Resources/test_audio.m4a",
            "/Users/doiya/vibe_project/EchoPick/Tests/Resources/test_audio.wav",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        throw XCTSkip("测试音频文件不存在")
    }

    private func convertToPCM(url: URL) throws -> Data {
        let audioFile = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        let converter = AVAudioConverter(from: audioFile.processingFormat, to: format)!

        let frameCount = AVAudioFrameCount(audioFile.length)
        let srcBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount)!
        try audioFile.read(into: srcBuffer)

        let ratio = 16000.0 / audioFile.processingFormat.sampleRate
        let outFrames = AVAudioFrameCount(Double(frameCount) * ratio)
        let outBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outFrames)!

        var error: NSError?
        converter.convert(to: outBuffer, error: &error) { _, status in
            status.pointee = .haveData
            return srcBuffer
        }

        guard error == nil, let ch = outBuffer.int16ChannelData else {
            throw NSError(domain: "PCM", code: -1, userInfo: [NSLocalizedDescriptionKey: "PCM 转换失败"])
        }
        return Data(bytes: ch[0], count: Int(outBuffer.frameLength) * 2)
    }
}
