import Foundation
import Security

/// API Key 安全存储 — 使用 Keychain
/// 所有敏感数据只存在设备本地 Keychain 中
struct APIKeyStore {
    private static let service = "com.echopick.apikeys"
    private static let doubaoLLMKey = "doubao-llm-api-key"
    private static let seedASRKey = "seed-asr-api-key"
    private static let asrAppKeyAccount = "asr-app-key"
    private static let asrAccessKeyAccount = "asr-access-key"

    // MARK: - 豆包 LLM (Doubao Seed for PickExtractor)

    static func saveDoubaoLLM(_ key: String) throws {
        try saveKey(key, account: doubaoLLMKey)
    }

    static func loadDoubaoLLM() -> String? {
        loadKey(account: doubaoLLMKey)
    }

    static func deleteDoubaoLLM() {
        deleteKey(account: doubaoLLMKey)
    }

    static var doubaoLLMExists: Bool { loadDoubaoLLM() != nil }

    static var doubaoLLMMasked: String { maskedKey(loadDoubaoLLM()) }

    // MARK: - Legacy compat (maps to DoubaoLLM)

    static func save(_ key: String) throws { try saveDoubaoLLM(key) }
    static func load() -> String? { loadDoubaoLLM() }
    static func delete() { deleteDoubaoLLM() }
    static var exists: Bool { doubaoLLMExists }
    static var masked: String { doubaoLLMMasked }

    // MARK: - SeedASR (豆包语音识别)

    static func saveSeedASR(_ key: String) throws {
        try saveKey(key, account: seedASRKey)
    }

    static func loadSeedASR() -> String? {
        loadKey(account: seedASRKey)
    }

    static func deleteSeedASR() {
        deleteKey(account: seedASRKey)
    }

    static var seedASRExists: Bool { loadSeedASR() != nil }

    static var seedASRMasked: String { maskedKey(loadSeedASR()) }

    // MARK: - ASR Streaming (App Key + Access Key)

    static func saveASRAppKey(_ key: String) throws { try saveKey(key, account: asrAppKeyAccount) }
    static func loadASRAppKey() -> String? { loadKey(account: asrAppKeyAccount) }
    static func deleteASRAppKey() { deleteKey(account: asrAppKeyAccount) }
    static var asrAppKeyExists: Bool { loadASRAppKey() != nil }
    static var asrAppKeyMasked: String { maskedKey(loadASRAppKey()) }

    static func saveASRAccessKey(_ key: String) throws { try saveKey(key, account: asrAccessKeyAccount) }
    static func loadASRAccessKey() -> String? { loadKey(account: asrAccessKeyAccount) }
    static func deleteASRAccessKey() { deleteKey(account: asrAccessKeyAccount) }
    static var asrAccessKeyExists: Bool { loadASRAccessKey() != nil }
    static var asrAccessKeyMasked: String { maskedKey(loadASRAccessKey()) }

    // MARK: - Generic Keychain Helpers

    private static func saveKey(_ key: String, account: String) throws {
        guard let data = key.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func loadKey(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKey(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func maskedKey(_ key: String?) -> String {
        guard let key = key else { return "未设置" }
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        var errorDescription: String? {
            switch self {
            case .saveFailed(let s): return "Keychain 保存失败：\(s)"
            }
        }
    }
}

