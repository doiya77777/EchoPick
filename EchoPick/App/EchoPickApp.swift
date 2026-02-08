import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct EchoPickApp: App {
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
                    // 录音中不锁屏，否则后台录音会中断
                    if !appState.isRecordingActive {
                        appState.lockApp()
                    }
                case .active:
                    if !appState.isUnlocked {
                        appState.authenticate()
                    }
                default:
                    break
                }
            }
            .modelContainer(StorageService.shared.container)
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var isUnlocked = false
    @Published var selectedTab: Tab = .listener
    @Published var isRecordingActive = false  // 录音时不锁屏

    enum Tab: Int, CaseIterable {
        case listener = 0
        case history
        case dashboard
        case settings
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // 如果没有生物识别，直接解锁（开发期间）
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = true
            return
        }

        Task {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "解锁拾响以访问你的录音记录"
                )
                await MainActor.run { isUnlocked = success }
            } catch {
                // 允许在模拟器上跳过
                await MainActor.run { isUnlocked = true }
            }
        }
    }

    func lockApp() { isUnlocked = false }
}
