import Foundation
import Combine
import UIKit
import Compression

/// 豆包 Seed ASR 2.0 流式实时语音识别
/// WebSocket 二进制协议 — 支持双向流式 + 性别检测 + 分句
///
/// 文档: https://www.volcengine.com/docs/6561/1354869
@MainActor
final class StreamingASRService: NSObject, ObservableObject {

    // MARK: - 实时输出

    /// 当前完整转录文本（不断更新）
    @Published var liveTranscript = ""
    /// 当前正在识别的临时文本（未 definite 的句子）
    @Published var pendingText = ""
    /// 所有已确认的分句（带说话人标签）
    @Published var confirmedUtterances: [Utterance] = []
    /// 连接状态
    @Published var connectionState: ConnectionState = .disconnected
    /// 错误
    @Published var error: ASRError?

    // MARK: - Types

    struct Utterance: Identifiable {
        let id = UUID()
        let text: String
        let startTime: Int      // ms
        let endTime: Int        // ms
        let speakerGender: String? // "male" / "female"
        let emotion: String?
    }

    enum ConnectionState: String {
        case disconnected = "未连接"
        case connecting = "连接中..."
        case connected = "已连接"
        case streaming = "识别中..."
        case error = "连接错误"
    }

    enum ASRError: Error, LocalizedError {
        case noCredentials
        case connectionFailed(String)
        case protocolError(String)
        case serverError(Int, String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .noCredentials: return "未配置豆包语音 App Key / Access Key"
            case .connectionFailed(let m): return "连接失败: \(m)"
            case .protocolError(let m): return "协议错误: \(m)"
            case .serverError(let code, let msg): return "服务端错误 [\(code)]: \(msg)"
            case .timeout: return "连接超时"
            }
        }
    }

    // MARK: - Private

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var sequenceNumber: Int32 = 0
    private let connectId = UUID().uuidString

    // 累计已确认文本
    private var confirmedText = ""

    // MARK: - Binary Protocol Constants

    private let protocolVersion: UInt8 = 0b0001
    private let headerSize: UInt8 = 0b0001  // 4 bytes

    // Message types
    private let msgTypeFullClientRequest: UInt8  = 0b0001
    private let msgTypeAudioOnly: UInt8          = 0b0010
    private let msgTypeFullServerResponse: UInt8 = 0b1001
    private let msgTypeServerError: UInt8        = 0b1111

    // Flags
    private let flagNoSequence: UInt8   = 0b0000
    private let flagLastPacket: UInt8   = 0b0010

    // Serialization
    private let serializationJSON: UInt8 = 0b0001
    private let serializationNone: UInt8 = 0b0000

    // Compression
    private let compressionGzip: UInt8 = 0b0001
    private let compressionNone: UInt8 = 0b0000

    // MARK: - Init

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        // 绕过本地 Clash TUN 代理
        config.connectionProxyDictionary = [kCFNetworkProxiesHTTPEnable as String: false]
        session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }

    // MARK: - Public API

    /// 开始流式识别（建连 + 发送配置）
    func startStreaming() async throws {
        guard let appKey = APIKeyStore.loadASRAppKey(),
              let accessKey = APIKeyStore.loadASRAccessKey() else {
            throw ASRError.noCredentials
        }

        await MainActor.run {
            connectionState = .connecting
            liveTranscript = ""
            pendingText = ""
            confirmedUtterances = []
            confirmedText = ""
            sequenceNumber = 0
            error = nil
        }

        // 构建 WebSocket URL + 鉴权 header
        let url = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async")!
        var request = URLRequest(url: url)
        request.setValue(appKey, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(accessKey, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue("volc.seedasr.sauc.duration", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(connectId, forHTTPHeaderField: "X-Api-Connect-Id")

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // 发送 full client request (配置参数)
        try await sendFullClientRequest()

        await MainActor.run {
            connectionState = .connected
        }

        // 启动接收循环
        Task {
            await receiveLoop()
        }
    }

    /// 发送音频 PCM 数据
    /// - Parameter pcmData: 16kHz 16bit mono PCM 数据
    func sendAudio(_ pcmData: Data) async throws {
        guard let ws = webSocketTask else { return }

        let header = buildHeader(
            messageType: msgTypeAudioOnly,
            flags: flagNoSequence,
            serialization: serializationNone,
            compression: compressionGzip
        )

        // Gzip 压缩音频
        let compressed = try gzipCompress(pcmData)

        var packet = Data()
        packet.append(contentsOf: header)
        packet.append(contentsOf: bigEndianUInt32(UInt32(compressed.count)))
        packet.append(compressed)

        try await ws.send(.data(packet))

        await MainActor.run {
            if connectionState == .connected {
                connectionState = .streaming
            }
        }
    }

    /// 发送最后一包（负包），通知服务端音频结束
    func sendLastPacket() async throws {
        guard let ws = webSocketTask else { return }

        let header = buildHeader(
            messageType: msgTypeAudioOnly,
            flags: flagLastPacket,
            serialization: serializationNone,
            compression: compressionGzip
        )

        // 发送空音频的负包
        let emptyCompressed = try gzipCompress(Data())

        var packet = Data()
        packet.append(contentsOf: header)
        packet.append(contentsOf: bigEndianUInt32(UInt32(emptyCompressed.count)))
        packet.append(emptyCompressed)

        try await ws.send(.data(packet))
    }

    /// 断开连接
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        Task { @MainActor in
            connectionState = .disconnected
        }
    }

    /// 获取最终完整转录文本
    var finalTranscript: String {
        let pending = pendingText.isEmpty ? "" : "\n\(pendingText)"
        return confirmedText + pending
    }

    // MARK: - Full Client Request

    private func sendFullClientRequest() async throws {
        let config: [String: Any] = [
            "user": [
                "uid": UIDevice.current.identifierForVendor?.uuidString ?? "echopick-user"
            ],
            "audio": [
                "format": "pcm",
                "codec": "raw",
                "rate": 16000,
                "bits": 16,
                "channel": 1
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
                "enable_ddc": false,
                "show_utterances": true,
                "enable_gender_detection": true,
                "enable_emotion_detection": true,
                "result_type": "full",
                "end_window_size": 800
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: config)

        let header = buildHeader(
            messageType: msgTypeFullClientRequest,
            flags: flagNoSequence,
            serialization: serializationJSON,
            compression: compressionGzip
        )

        let compressed = try gzipCompress(jsonData)

        var packet = Data()
        packet.append(contentsOf: header)
        packet.append(contentsOf: bigEndianUInt32(UInt32(compressed.count)))
        packet.append(compressed)

        guard let ws = webSocketTask else { throw ASRError.connectionFailed("WebSocket not connected") }
        try await ws.send(.data(packet))
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        guard let ws = webSocketTask else { return }

        while true {
            do {
                let message = try await ws.receive()
                switch message {
                case .data(let data):
                    parseServerMessage(data)
                case .string(let text):
                    // 不应该收到文本消息
                    print("⚠️ Unexpected text message: \(text.prefix(100))")
                @unknown default:
                    break
                }
            } catch {
                // 连接关闭或错误
                if (error as NSError).code != 57 { // Socket is not connected (normal close)
                    await MainActor.run {
                        self.connectionState = .error
                        self.error = .connectionFailed(error.localizedDescription)
                    }
                }
                break
            }
        }
    }

    // MARK: - Parse Server Response

    private func parseServerMessage(_ data: Data) {
        guard data.count >= 4 else { return }

        let byte0 = data[0]
        let byte1 = data[1]
        let byte2 = data[2]
        // byte3 is reserved

        let _ = (byte0 >> 4) & 0x0F // protocol version
        let headerSizeVal = Int(byte0 & 0x0F) * 4
        let messageType = (byte1 >> 4) & 0x0F
        let flags = byte1 & 0x0F
        let _ = (byte2 >> 4) & 0x0F // serialization
        let compression = byte2 & 0x0F

        if messageType == msgTypeServerError {
            // Error message: header + error_code(4) + error_msg_size(4) + error_msg
            guard data.count >= headerSizeVal + 8 else { return }
            let errorCode = readBigEndianInt32(data, offset: headerSizeVal)
            let msgSize = readBigEndianUInt32(data, offset: headerSizeVal + 4)
            var errMsg = ""
            if msgSize > 0 && data.count >= headerSizeVal + 8 + Int(msgSize) {
                let msgData = data[(headerSizeVal + 8)..<(headerSizeVal + 8 + Int(msgSize))]
                errMsg = String(data: msgData, encoding: .utf8) ?? ""
            }
            Task { @MainActor in
                self.error = .serverError(Int(errorCode), errMsg)
                self.connectionState = .error
            }
            return
        }

        guard messageType == msgTypeFullServerResponse else { return }

        // Full server response: header + sequence(4) + payload_size(4) + payload
        guard data.count >= headerSizeVal + 8 else { return }

        let _ = readBigEndianInt32(data, offset: headerSizeVal)  // sequence
        let payloadSize = readBigEndianUInt32(data, offset: headerSizeVal + 4)

        guard payloadSize > 0,
              data.count >= headerSizeVal + 8 + Int(payloadSize) else { return }

        var payloadData = Data(data[(headerSizeVal + 8)..<(headerSizeVal + 8 + Int(payloadSize))])

        // Decompress if Gzip
        if compression == compressionGzip {
            guard let decompressed = try? gzipDecompress(payloadData) else { return }
            payloadData = decompressed
        }

        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let result = json["result"] as? [String: Any] else { return }

        let text = result["text"] as? String ?? ""
        let utterances = result["utterances"] as? [[String: Any]] ?? []

        // 是否最后一个响应
        let isLast = (flags & 0x02) != 0

        // 解析分句
        var newConfirmedUtterances: [Utterance] = []
        var newPendingText = ""

        for utt in utterances {
            let uttText = utt["text"] as? String ?? ""
            let startTime = utt["start_time"] as? Int ?? 0
            let endTime = utt["end_time"] as? Int ?? 0
            let definite = utt["definite"] as? Bool ?? false

            // 解析 additions 中的性别和情绪
            var gender: String? = nil
            var emotion: String? = nil
            if let additions = utt["additions"] as? [String: Any] {
                gender = additions["gender"] as? String
                emotion = additions["emotion"] as? String
            }

            if definite {
                let u = Utterance(
                    text: uttText,
                    startTime: startTime,
                    endTime: endTime,
                    speakerGender: gender,
                    emotion: emotion
                )
                newConfirmedUtterances.append(u)
            } else {
                newPendingText = uttText
            }
        }

        Task { @MainActor in
            // Seed ASR 2.0 的每次响应包含所有已确认分句（累积式），直接替换而非追加
            if !newConfirmedUtterances.isEmpty {
                self.confirmedUtterances = newConfirmedUtterances
            }

            // 重建已确认文本
            self.confirmedText = self.confirmedUtterances.map(\.text).joined(separator: "")

            // 更新临时文本
            self.pendingText = newPendingText

            // 更新总文本
            self.liveTranscript = text

            if isLast {
                self.connectionState = .disconnected
            }
        }
    }

    // MARK: - Binary Protocol Helpers

    private func buildHeader(messageType: UInt8, flags: UInt8, serialization: UInt8, compression: UInt8) -> [UInt8] {
        let byte0 = (protocolVersion << 4) | headerSize
        let byte1 = (messageType << 4) | flags
        let byte2 = (serialization << 4) | compression
        let byte3: UInt8 = 0x00
        return [byte0, byte1, byte2, byte3]
    }

    private func bigEndianUInt32(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    private func readBigEndianUInt32(_ data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) << 24
             | UInt32(data[offset + 1]) << 16
             | UInt32(data[offset + 2]) << 8
             | UInt32(data[offset + 3])
    }

    private func readBigEndianInt32(_ data: Data, offset: Int) -> Int32 {
        Int32(bitPattern: readBigEndianUInt32(data, offset: offset))
    }

    // MARK: - Gzip Compression (using Compression framework)

    private func gzipCompress(_ data: Data) throws -> Data {
        guard !data.isEmpty else {
            // 标准 Gzip 空帧
            return Data([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
                         0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }

        // 使用 Compression 框架的 ZLIB 压缩
        let compressed = try data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data in
            let dstSize = data.count + 1024  // 足够大的输出缓冲区
            var dst = Data(count: dstSize)
            let compressedSize = try dst.withUnsafeMutableBytes { (dstPtr: UnsafeMutableRawBufferPointer) -> Int in
                let result = compression_encode_buffer(
                    dstPtr.bindMemory(to: UInt8.self).baseAddress!, dstSize,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB
                )
                guard result > 0 else { throw ASRError.protocolError("Compression failed") }
                return result
            }
            return dst.prefix(compressedSize)
        }

        // 构建 Gzip 包装: header + compressed deflate data + footer
        var gzipData = Data()
        // Gzip header (10 bytes)
        gzipData.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03])
        // Compressed data (raw deflate)
        gzipData.append(compressed)
        // Gzip footer: CRC32 (4 bytes) + original size (4 bytes)
        let crc = crc32(data)
        gzipData.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
        let size = UInt32(truncatingIfNeeded: data.count)
        gzipData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })

        return gzipData
    }

    private func gzipDecompress(_ data: Data) throws -> Data {
        guard data.count > 10 else { throw ASRError.protocolError("Data too short for gzip") }

        // 跳过 Gzip header (找到压缩数据的起始位置)
        var offset = 10
        let flags = data[3]
        if flags & 0x04 != 0 { // FEXTRA
            guard offset + 2 <= data.count else { throw ASRError.protocolError("Invalid gzip") }
            let extraLen = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2 + extraLen
        }
        if flags & 0x08 != 0 { // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 { offset += 2 } // FHCRC

        // 去掉末尾 8 字节 (CRC32 + size)
        let compressedData = data[offset..<(data.count - 8)]

        // 解压
        let dstSize = data.count * 10  // 预估解压后大小
        var dst = Data(count: dstSize)
        let decompressedSize = try compressedData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
            try dst.withUnsafeMutableBytes { (dstPtr: UnsafeMutableRawBufferPointer) -> Int in
                let result = compression_decode_buffer(
                    dstPtr.bindMemory(to: UInt8.self).baseAddress!, dstSize,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!, compressedData.count,
                    nil, COMPRESSION_ZLIB
                )
                guard result > 0 else { throw ASRError.protocolError("Decompression failed") }
                return result
            }
        }

        return dst.prefix(decompressedSize)
    }

    /// CRC32 计算
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let poly: UInt32 = 0xEDB88320
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ poly
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
