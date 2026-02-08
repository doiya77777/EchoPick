import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    // 豆包 LLM (Doubao Seed for PickExtractor)
    @Published var doubaoLLMKeyInput = ""
    @Published var hasDoubaoLLMKey = false
    @Published var maskedDoubaoLLMKey = ""

    // ASR Streaming (App Key + Access Key)
    @Published var asrAppKeyInput = ""
    @Published var asrAccessKeyInput = ""
    @Published var hasASRAppKey = false
    @Published var hasASRAccessKey = false
    @Published var maskedASRAppKey = ""
    @Published var maskedASRAccessKey = ""

    @Published var savedConfirmation = false
    @Published var savedKeyType = ""
    @Published var defaultLanguage: String

    init() {
        defaultLanguage = UserDefaults.standard.string(forKey: "echopick.language") ?? "zh"
        checkKeys()
    }

    func checkKeys() {
        hasDoubaoLLMKey = APIKeyStore.doubaoLLMExists
        maskedDoubaoLLMKey = APIKeyStore.doubaoLLMMasked
        hasASRAppKey = APIKeyStore.asrAppKeyExists
        maskedASRAppKey = APIKeyStore.asrAppKeyMasked
        hasASRAccessKey = APIKeyStore.asrAccessKeyExists
        maskedASRAccessKey = APIKeyStore.asrAccessKeyMasked
    }

    // MARK: - 豆包 LLM Key

    func saveDoubaoLLMKey() {
        let key = doubaoLLMKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        try? APIKeyStore.saveDoubaoLLM(key)
        doubaoLLMKeyInput = ""
        checkKeys()
        savedKeyType = "豆包 LLM"
        savedConfirmation = true
    }

    func deleteDoubaoLLMKey() {
        APIKeyStore.deleteDoubaoLLM()
        checkKeys()
    }

    // MARK: - ASR Streaming Keys

    func saveASRKeys() {
        let appKey = asrAppKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessKey = asrAccessKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if !appKey.isEmpty { try? APIKeyStore.saveASRAppKey(appKey) }
        if !accessKey.isEmpty { try? APIKeyStore.saveASRAccessKey(accessKey) }

        asrAppKeyInput = ""
        asrAccessKeyInput = ""
        checkKeys()
        savedKeyType = "豆包语音识别"
        savedConfirmation = true
    }

    func deleteASRKeys() {
        APIKeyStore.deleteASRAppKey()
        APIKeyStore.deleteASRAccessKey()
        checkKeys()
    }

    func saveLanguage() {
        UserDefaults.standard.set(defaultLanguage, forKey: "echopick.language")
    }

    // Stats
    var recordCount: Int { StorageService.shared.fetchRecords().count }
    var pickCount: Int {
        StorageService.shared.fetchRecords().reduce(0) { total, record in
            total + StorageService.shared.fetchPicks(for: record.id).count
        }
    }
}
