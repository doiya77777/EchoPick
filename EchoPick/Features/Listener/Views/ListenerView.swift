import SwiftUI

/// 录音页
struct ListenerView: View {
    @StateObject private var viewModel = ListenerViewModel()
    @EnvironmentObject var appState: AppState
    @State private var buttonScale: CGFloat = 1.0
    @State private var showTranscript = false

    var body: some View {
        ZStack {
            DS.Colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)

                if viewModel.isRecording && showTranscript {
                    transcriptPanel
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, DS.Spacing.md)
                } else {
                    Spacer()
                }

                // 状态
                Text(viewModel.statusText)
                    .font(DS.Font.tag(13))
                    .foregroundColor(DS.Colors.textSecondary)
                    .padding(.bottom, DS.Spacing.md)

                // 波形
                WaveformView(level: viewModel.audioLevel, isActive: viewModel.isRecording)
                    .frame(height: 56)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.lg)

                // 按钮
                mainButton
                    .padding(.bottom, DS.Spacing.md)

                // 时间
                Text(viewModel.formattedTime)
                    .font(DS.Font.timer())
                    .foregroundColor(DS.Colors.text)
                    .monospacedDigit()

                if !viewModel.isRecording && !viewModel.isProcessing {
                    Text("点击开始，放口袋里就行")
                        .font(DS.Font.caption())
                        .foregroundColor(DS.Colors.textMuted)
                        .padding(.top, DS.Spacing.xs)
                }

                if viewModel.isRecording {
                    infoRow.padding(.top, DS.Spacing.md)
                }

                if viewModel.isRecording && !showTranscript {
                    subtitlePreview
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.md)
                }

                Spacer()

                if viewModel.isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(viewModel.processingStatus)
                            .font(DS.Font.tag(13))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .cardStyle(radius: DS.Radius.md)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showTranscript)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
        .alert("出错了", isPresented: $viewModel.showError) {
            Button("好") {}
        } message: { Text(viewModel.errorMessage ?? "") }
        .onChange(of: viewModel.isRecording) { _, rec in
            appState.isRecordingActive = rec
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(DS.Font.tag())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))
            }

            Spacer()

            if viewModel.isRecording {
                Button {
                    showTranscript.toggle()
                } label: {
                    Image(systemName: showTranscript ? "text.bubble.fill" : "text.bubble")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.text)
                        .frame(width: 44, height: 44)
                }
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected, .streaming: DS.Colors.green
        case .connecting: DS.Colors.yellow
        case .disconnected: DS.Colors.textMuted
        case .error: DS.Colors.red
        }
    }

    private var statusLabel: String {
        switch viewModel.connectionState {
        case .connected: "已连接"
        case .streaming: "识别中"
        case .connecting: "连接中…"
        case .disconnected: "未连接"
        case .error: "错误"
        }
    }

    // MARK: - Main Button

    private var mainButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { await viewModel.toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? DS.Colors.red : DS.Colors.text)
                    .frame(width: 88, height: 88)

                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(DS.Colors.bgCard) // use card color so it's visible in both modes
                }
            }
            .scaleEffect(buttonScale)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessing)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.15)) { buttonScale = 0.93 } }
                .onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { buttonScale = 1.0 } }
        )
    }

    // MARK: - Info Row

    private var infoRow: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: 4) {
                Image(systemName: "waveform").font(.system(size: 10))
                Text("\(viewModel.segmentCount) 段")
                    .font(DS.Font.tag())
            }
            .foregroundColor(DS.Colors.textSecondary)

            if !viewModel.speakerSummary.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2").font(.system(size: 10))
                    Text(viewModel.speakerSummary)
                        .font(DS.Font.tag())
                }
                .foregroundColor(DS.Colors.textSecondary)
            }
        }
    }

    // MARK: - Transcript

    private var transcriptPanel: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(viewModel.confirmedUtterances.enumerated()), id: \.offset) { idx, utt in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: utt.speakerGender == "male" ? "person.fill" : utt.speakerGender == "female" ? "person.fill" : "person.wave.2.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Colors.textMuted)
                                .frame(width: 16)
                            Text(utt.text)
                                .font(DS.Font.body())
                                .foregroundColor(DS.Colors.text)
                        }
                        .id("u\(idx)")
                    }
                    if !viewModel.pendingText.isEmpty {
                        Text(viewModel.pendingText)
                            .font(DS.Font.body())
                            .foregroundColor(DS.Colors.textMuted)
                            .italic()
                            .id("pending")
                    }
                }
                .padding(DS.Spacing.md)
            }
            .frame(maxHeight: 180)
            .cardStyle()
            .padding(.horizontal, DS.Spacing.md)
            .onChange(of: viewModel.confirmedUtterances.count) { _, c in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(!viewModel.pendingText.isEmpty ? "pending" : "u\(c-1)", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Subtitle Preview

    private var subtitlePreview: some View {
        Button { showTranscript = true } label: {
            HStack {
                if let last = viewModel.confirmedUtterances.last {
                    Text(last.text)
                        .font(DS.Font.body(13))
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                } else if !viewModel.pendingText.isEmpty {
                    Text(viewModel.pendingText)
                        .font(DS.Font.body(13))
                        .foregroundColor(DS.Colors.textMuted)
                        .lineLimit(1)
                        .italic()
                } else {
                    Text("等待语音…")
                        .font(DS.Font.body(13))
                        .foregroundColor(DS.Colors.textMuted)
                }

                Spacer()

                if viewModel.confirmedUtterances.count > 0 {
                    Text("\(viewModel.confirmedUtterances.count)")
                        .font(DS.Font.number(11))
                        .foregroundColor(DS.Colors.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .cardStyle(radius: DS.Radius.sm)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ListenerView()
        .environmentObject(AppState())
}
