import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var maskedAPIKey: String = ""
    @Published var hasAPIKey: Bool = false
    @Published var isBiometricEnabled: Bool = true
    @Published var autoTranscribe: Bool = false
    @Published var defaultLanguage: String = "zh"
    @Published var showingSaveConfirmation = false
    
    private let biometricService = BiometricService()
    
    var biometricType: String {
        biometricService.displayName
    }
    
    var biometricIcon: String {
        biometricService.iconName
    }
    
    func loadSettings() {
        if let savedKey = CryptoService.loadAPIKey() {
            hasAPIKey = true
            maskedAPIKey = savedKey.masked
        }
        
        isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        autoTranscribe = UserDefaults.standard.bool(forKey: "autoTranscribe")
        defaultLanguage = UserDefaults.standard.string(forKey: "defaultLanguage") ?? "zh"
    }
    
    func saveAPIKey() {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        do {
            try CryptoService.saveAPIKey(apiKey.trimmingCharacters(in: .whitespaces))
            hasAPIKey = true
            maskedAPIKey = apiKey.masked
            apiKey = ""
            showingSaveConfirmation = true
        } catch {
            // Handle error
        }
    }
    
    func deleteAPIKey() {
        CryptoService.deleteAPIKey()
        hasAPIKey = false
        maskedAPIKey = ""
        apiKey = ""
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isBiometricEnabled, forKey: "biometricEnabled")
        UserDefaults.standard.set(autoTranscribe, forKey: "autoTranscribe")
        UserDefaults.standard.set(defaultLanguage, forKey: "defaultLanguage")
    }
}
