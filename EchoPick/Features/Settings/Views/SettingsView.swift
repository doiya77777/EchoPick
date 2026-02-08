import SwiftUI

/// 设置
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showDeleteASR = false
    @State private var showDeleteLLM = false
    @State private var showDeleteAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        asrSection
                        llmSection

                        section(title: "隐私", icon: "lock.fill") {
                            NavigationLink { privacyView } label: {
                                infoRow("隐私政策", value: "→")
                            }
                            infoRow("数据存储", value: "本地 + iCloud")
                        }

                        section(title: "统计", icon: "chart.bar.fill") {
                            infoRow("录音数", value: "\(viewModel.recordCount)")
                            infoRow("提取数", value: "\(viewModel.pickCount)")
                        }

                        Button { showDeleteAll = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash").font(.system(size: 13))
                                Text("清除所有数据")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(DS.Colors.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .stroke(DS.Colors.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, DS.Spacing.md)

                        section(title: "关于", icon: "info.circle") {
                            infoRow("版本", value: "1.0.0")
                            infoRow("转录", value: "Seed ASR 2.0")
                            infoRow("智能", value: "Seed LLM")
                        }

                        Color.clear.frame(height: DS.Spacing.xxl)
                    }
                    .padding(.top, DS.Spacing.sm)
                }
            }
            .navigationTitle("设置")
            .scrollDismissesKeyboard(.interactively)
            .alert("删除语音识别凭证？", isPresented: $showDeleteASR) {
                Button("删除", role: .destructive) { viewModel.deleteASRKeys() }
                Button("取消", role: .cancel) {}
            }
            .alert("删除智能提取 Key？", isPresented: $showDeleteLLM) {
                Button("删除", role: .destructive) { viewModel.deleteDoubaoLLMKey() }
                Button("取消", role: .cancel) {}
            }
            .alert("清除所有数据？", isPresented: $showDeleteAll) {
                Button("清除", role: .destructive) { deleteAll() }
                Button("取消", role: .cancel) {}
            }
            .alert("已保存", isPresented: $viewModel.savedConfirmation) {
                Button("好") {}
            } message: { Text("\(viewModel.savedKeyType) 已保存到 Keychain") }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { dismissKB() }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    // MARK: - ASR

    private var asrSection: some View {
        section(title: "语音识别", icon: "mic.fill", subtitle: "Seed ASR 2.0") {
            keyRow(label: "App Key", icon: "key.fill", placeholder: "App ID",
                   text: $viewModel.asrAppKeyInput,
                   existing: viewModel.hasASRAppKey ? viewModel.maskedASRAppKey : nil, secure: false)
            keyRow(label: "Access Key", icon: "key.horizontal.fill", placeholder: "Access Token",
                   text: $viewModel.asrAccessKeyInput,
                   existing: viewModel.hasASRAccessKey ? viewModel.maskedASRAccessKey : nil, secure: true)
            HStack(spacing: DS.Spacing.sm) {
                actionButton("保存", enabled: canSaveASR) { viewModel.saveASRKeys(); dismissKB() }
                if viewModel.hasASRAppKey || viewModel.hasASRAccessKey {
                    Button("删除") { showDeleteASR = true }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.red)
                }
            }
        }
    }

    // MARK: - LLM

    private var llmSection: some View {
        section(title: "智能提取", icon: "brain", subtitle: "Seed LLM") {
            keyRow(label: "API Key", icon: "brain", placeholder: "LLM API Key",
                   text: $viewModel.doubaoLLMKeyInput,
                   existing: viewModel.hasDoubaoLLMKey ? viewModel.maskedDoubaoLLMKey : nil, secure: true)
            HStack(spacing: DS.Spacing.sm) {
                actionButton("保存",
                    enabled: !viewModel.doubaoLLMKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
                ) { viewModel.saveDoubaoLLMKey(); dismissKB() }
                if viewModel.hasDoubaoLLMKey {
                    Button("删除") { showDeleteLLM = true }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.red)
                }
            }
        }
    }

    // MARK: - Components

    private func section<C: View>(title: String, icon: String, subtitle: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DS.Colors.text)
                if let s = subtitle {
                    Text("· \(s)")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Colors.textMuted)
                }
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.md) { content() }
                .padding(DS.Spacing.md)
                .cardStyle()
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    private func keyRow(label: String, icon: String, placeholder: String,
                        text: Binding<String>, existing: String?, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(DS.Colors.textSecondary)
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(DS.Colors.text)
                Spacer()
                Text(existing ?? "未设置")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(existing != nil ? DS.Colors.green : DS.Colors.textMuted)
            }
            Group {
                if secure { SecureField(placeholder, text: text) }
                else { TextField(placeholder, text: text) }
            }
            .font(.system(size: 14))
            .foregroundColor(DS.Colors.text)
            .padding(10)
            .background(DS.Colors.bg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
            .submitLabel(.done)
            .onSubmit { dismissKB() }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundColor(DS.Colors.text)
            Spacer()
            Text(value).font(.system(size: 12)).foregroundColor(DS.Colors.textMuted)
        }
    }

    private func actionButton(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? DS.Colors.bgCard : DS.Colors.textMuted)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(enabled ? DS.Colors.text : DS.Colors.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .disabled(!enabled)
    }

    // MARK: - Helpers

    private var canSaveASR: Bool {
        !viewModel.asrAppKeyInput.trimmingCharacters(in: .whitespaces).isEmpty ||
        !viewModel.asrAccessKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private func dismissKB() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func deleteAll() {
        let s = StorageService.shared
        for r in s.fetchRecords() { s.deleteRecord(r) }
    }

    // MARK: - Privacy

    private var privacyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("隐私政策")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DS.Colors.text)
                Text("更新：2026.02")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textMuted)

                policyItem("本地存储", "录音和转录存在设备本地，通过 iCloud 同步到你的其他设备。")
                policyItem("数据安全", "API Key 存在 Keychain。音频通过 TLS 加密传输，服务端不保留。")
                policyItem("语音识别", "使用火山引擎 Seed ASR 流式识别，WebSocket 加密。")
                policyItem("智能提取", "使用 Seed LLM 做文本分析，数据不用于训练。")
                policyItem("无自建后端", "所有同步通过 iCloud 完成，没有第三方服务器。")
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Colors.bg.ignoresSafeArea())
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policyItem(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.Colors.text)
            Text(content).font(.system(size: 13)).foregroundColor(DS.Colors.textSecondary).lineSpacing(2)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: DS.Radius.md)
    }
}

#Preview { SettingsView() }
