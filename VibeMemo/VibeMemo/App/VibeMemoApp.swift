import SwiftUI
import LocalAuthentication

@main
struct VibeMemoApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isUnlocked {
                    ContentView()
                        .environmentObject(appState)
                } else {
                    LockScreenView()
                        .environmentObject(appState)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    appState.lockApp()
                case .active:
                    if !appState.isUnlocked {
                        appState.authenticate()
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isUnlocked = false
    @Published var selectedTab: AppTab = .notes
    
    private let biometricService = BiometricService()
    
    enum AppTab: Int, CaseIterable {
        case notes = 0
        case record
        case conversations
        case settings
    }
    
    func authenticate() {
        Task {
            let success = await biometricService.authenticate()
            await MainActor.run {
                self.isUnlocked = success
            }
        }
    }
    
    func lockApp() {
        isUnlocked = false
    }
}
