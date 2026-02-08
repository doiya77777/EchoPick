import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NotesListView()
                .tabItem {
                    Label("笔记", systemImage: "note.text")
                }
                .tag(AppState.AppTab.notes)
            
            RecordingView()
                .tabItem {
                    Label("录音", systemImage: "waveform.circle.fill")
                }
                .tag(AppState.AppTab.record)
            
            ConversationListView()
                .tabItem {
                    Label("对话", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(AppState.AppTab.conversations)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(AppState.AppTab.settings)
        }
        .tint(.accent)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
