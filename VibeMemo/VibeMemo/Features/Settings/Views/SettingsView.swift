import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationStack {
            List {
                // AI Settings
                Section {
                    HStack {
                        Label {
                            Text("OpenAI API Key")
                        } icon: {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        if viewModel.hasAPIKey {
                            Text(viewModel.maskedAPIKey)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("未设置")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    SecureField("输入 API Key...", text: $viewModel.apiKey)
                        .textContentType(.password)
                    
                    HStack {
                        Button("保存 Key") {
                            viewModel.saveAPIKey()
                        }
                        .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                        
                        Spacer()
                        
                        if viewModel.hasAPIKey {
                            Button("删除", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                        }
                    }
                } header: {
                    Text("AI 功能")
                } footer: {
                    Text("API Key 安全存储在设备 Keychain 中，不会上传到任何服务器。获取 Key: platform.openai.com")
                }
                
                // AI Preferences
                Section("AI 偏好") {
                    Toggle(isOn: $viewModel.autoTranscribe) {
                        Label {
                            Text("录音后自动转写")
                        } icon: {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: viewModel.autoTranscribe) { _, _ in
                        viewModel.saveSettings()
                    }
                    
                    Picker(selection: $viewModel.defaultLanguage) {
                        Text("中文").tag("zh")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                        Text("自动检测").tag("auto")
                    } label: {
                        Label {
                            Text("语音识别语言")
                        } icon: {
                            Image(systemName: "globe")
                                .foregroundColor(.green)
                        }
                    }
                    .onChange(of: viewModel.defaultLanguage) { _, _ in
                        viewModel.saveSettings()
                    }
                }
                
                // Privacy & Security
                Section("隐私与安全") {
                    Toggle(isOn: $viewModel.isBiometricEnabled) {
                        Label {
                            VStack(alignment: .leading) {
                                Text(viewModel.biometricType)
                                Text("启动应用时需要验证身份")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: viewModel.biometricIcon)
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: viewModel.isBiometricEnabled) { _, _ in
                        viewModel.saveSettings()
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label {
                            Text("隐私政策")
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                // About
                Section("关于") {
                    HStack {
                        Label {
                            Text("版本")
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/doiya")!) {
                        Label {
                            Text("开发者")
                        } icon: {
                            Image(systemName: "person.circle")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Data Management
                Section {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label {
                            Text("数据管理")
                        } icon: {
                            Image(systemName: "externaldrive")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                viewModel.loadSettings()
            }
            .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    viewModel.deleteAPIKey()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要删除已保存的 API Key 吗？删除后 AI 功能将无法使用。")
            }
            .alert("保存成功", isPresented: $viewModel.showingSaveConfirmation) {
                Button("好的") {}
            } message: {
                Text("API Key 已安全保存到 Keychain")
            }
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("隐私政策")
                        .font(.title.bold())
                    
                    Text("最后更新：2026年2月8日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    sectionView(
                        title: "数据存储",
                        content: "VibeMemo 的所有数据（笔记、录音、对话记录）均存储在您的设备本地，使用 AES-256-GCM 加密保护。未经您明确授权，数据不会上传到任何服务器。"
                    )
                    
                    sectionView(
                        title: "AI 功能",
                        content: "当您使用语音转文字或 AI 摘要功能时，相关数据会通过加密通道（TLS 1.3）发送到 OpenAI API 进行处理。根据 OpenAI 的 API 数据使用政策，通过 API 发送的数据不会用于训练模型。"
                    )
                    
                    sectionView(
                        title: "生物识别",
                        content: "Face ID / Touch ID 数据由 Apple 的安全区域（Secure Enclave）处理，VibeMemo 无法访问您的生物识别数据。"
                    )
                    
                    sectionView(
                        title: "API Key",
                        content: "您的 OpenAI API Key 存储在设备的 Keychain 中，这是 Apple 提供的最安全的存储方式，即使设备被越狱也难以提取。"
                    )
                    
                    sectionView(
                        title: "数据删除",
                        content: "您可以随时在设置中删除所有数据。删除操作不可逆，数据将被永久移除。"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @State private var showingDeleteAll = false
    @State private var noteCount = 0
    @State private var recordingCount = 0
    @State private var conversationCount = 0
    
    var body: some View {
        List {
            Section("数据统计") {
                HStack {
                    Label("笔记", systemImage: "note.text")
                    Spacer()
                    Text("\(noteCount) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("录音", systemImage: "waveform")
                    Spacer()
                    Text("\(recordingCount) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("对话", systemImage: "bubble.left.and.bubble.right")
                    Spacer()
                    Text("\(conversationCount) 条")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteAll = true
                } label: {
                    Label("删除所有数据", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } footer: {
                Text("⚠️ 此操作不可撤销，所有笔记、录音和对话记录将被永久删除。")
            }
        }
        .navigationTitle("数据管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCounts()
        }
        .alert("确认删除所有数据", isPresented: $showingDeleteAll) {
            Button("删除全部", role: .destructive) {
                deleteAllData()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这将永久删除所有笔记（\(noteCount) 条）、录音（\(recordingCount) 条）和对话记录（\(conversationCount) 条）。")
        }
    }
    
    private func loadCounts() {
        let storage = StorageService.shared
        noteCount = storage.fetchNotes().count
        recordingCount = storage.fetchRecordings().count
        conversationCount = storage.fetchConversations().count
    }
    
    private func deleteAllData() {
        let storage = StorageService.shared
        for note in storage.fetchNotes() { storage.deleteNote(note) }
        for recording in storage.fetchRecordings() { storage.deleteRecording(recording) }
        for conversation in storage.fetchConversations() { storage.deleteConversation(conversation) }
        loadCounts()
    }
}

#Preview {
    SettingsView()
}
