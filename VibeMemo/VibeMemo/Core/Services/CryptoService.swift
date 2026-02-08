import Foundation
import CryptoKit
import Security

/// 加密与安全存储服务
/// 使用 AES-256-GCM 加密数据，Keychain 存储敏感信息
struct CryptoService {
    
    enum CryptoError: Error, LocalizedError {
        case encryptionFailed
        case decryptionFailed
        case keyGenerationFailed
        case keychainError(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .encryptionFailed: return "加密失败"
            case .decryptionFailed: return "解密失败"
            case .keyGenerationFailed: return "密钥生成失败"
            case .keychainError(let status): return "Keychain 错误：\(status)"
            }
        }
    }
    
    // MARK: - Encryption Key Management
    
    /// Generate or retrieve the master encryption key
    static func getMasterKey() throws -> SymmetricKey {
        let keychainKey = "com.vibememo.master-key"
        
        // Try to load existing key from Keychain
        if let existingKeyData = try? loadFromKeychain(key: keychainKey) {
            return SymmetricKey(data: existingKeyData)
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try saveToKeychain(key: keychainKey, data: keyData)
        
        return newKey
    }
    
    // MARK: - AES-256-GCM Encryption
    
    static func encrypt(_ data: Data) throws -> Data {
        let key = try getMasterKey()
        
        guard let sealedBox = try? AES.GCM.seal(data, using: key) else {
            throw CryptoError.encryptionFailed
        }
        
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        return combined
    }
    
    static func decrypt(_ data: Data) throws -> Data {
        let key = try getMasterKey()
        
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decryptedData = try? AES.GCM.open(sealedBox, using: key) else {
            throw CryptoError.decryptionFailed
        }
        
        return decryptedData
    }
    
    static func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw CryptoError.encryptionFailed
        }
        return try encrypt(data)
    }
    
    static func decryptToString(_ data: Data) throws -> String {
        let decryptedData = try decrypt(data)
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        return string
    }
    
    // MARK: - Keychain Operations
    
    static func saveToKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.vibememo",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CryptoError.keychainError(status)
        }
    }
    
    static func loadFromKeychain(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.vibememo",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw CryptoError.keychainError(status)
        }
        
        return data
    }
    
    static func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.vibememo"
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - API Key Storage
    
    static func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw CryptoError.encryptionFailed
        }
        try saveToKeychain(key: "com.vibememo.openai-api-key", data: data)
    }
    
    static func loadAPIKey() -> String? {
        guard let data = try? loadFromKeychain(key: "com.vibememo.openai-api-key") else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    static func deleteAPIKey() {
        deleteFromKeychain(key: "com.vibememo.openai-api-key")
    }
}
