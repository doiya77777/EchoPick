import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    init() {
        // Fix tab bar appearance — 不闪烁
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ListenerView()
                .tabItem { Label("录音", systemImage: "mic.fill") }
                .tag(AppState.Tab.listener)

            HistoryListView()
                .tabItem { Label("记录", systemImage: "list.bullet") }
                .tag(AppState.Tab.history)

            DashboardView()
                .tabItem { Label("看板", systemImage: "square.grid.2x2") }
                .tag(AppState.Tab.dashboard)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(AppState.Tab.settings)
        }
        .tint(DS.Colors.text)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(StorageService.shared.container)
}
