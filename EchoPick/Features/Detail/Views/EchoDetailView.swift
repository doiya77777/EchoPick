import SwiftUI
import SwiftData

/// 详情页 — 音频 + 文本为主，AI 分析为辅
struct EchoDetailView: View {
    @StateObject private var viewModel: EchoDetailViewModel
    @State private var showAISection = false

    init(record: EchoRecord) {
        _viewModel = StateObject(wrappedValue: EchoDetailViewModel(record: record))
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.sm)

                    // Audio Player
                    if viewModel.hasAudio {
                        audioPlayerSection
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.top, DS.Spacing.md)
                    }

                    divider

                    // Transcript — 最重要的部分
                    transcriptSection
                        .padding(.horizontal, DS.Spacing.md)

                    // AI 分析（折叠）
                    if !viewModel.picks.isEmpty || viewModel.record.summary != nil {
                        divider

                        aiSection(scrollProxy: scrollProxy)
                            .padding(.horizontal, DS.Spacing.md)
                    }

                    Color.clear.frame(height: DS.Spacing.xxl)
                }
            }
            .background(DS.Colors.bg.ignoresSafeArea())
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.copyTranscript()
                    } label: {
                        Label("复制全文", systemImage: "doc.on.doc")
                    }
                    if viewModel.record.summary != nil {
                        Button {
                            viewModel.copySummary()
                        } label: {
                            Label("复制摘要", systemImage: "doc.plaintext")
                        }
                    }
                    Divider()
                    Button {
                        Task { await viewModel.reprocess() }
                    } label: {
                        Label("重新分析", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            // Copy toast
            if viewModel.copyToast {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("已复制")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .cardStyle(radius: DS.Radius.pill)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: viewModel.copyToast)
            }

            // Reprocessing overlay
            if viewModel.isReprocessing {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("分析中…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DS.Colors.text)
                    }
                    .padding(24)
                    .cardStyle()
                }
            }
        }
        .onDisappear { viewModel.stopPlayback() }
    }

    private var divider: some View {
        Divider()
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = viewModel.record.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DS.Colors.text)
            }

            HStack(spacing: 14) {
                Label(viewModel.record.createdAt.dateDisplay, systemImage: "calendar")
                Label(viewModel.record.duration.durationDisplay, systemImage: "timer")
                if viewModel.hasAudio {
                    Label("有音频", systemImage: "waveform")
                }
            }
            .font(.system(size: 12))
            .foregroundColor(DS.Colors.textMuted)
        }
    }

    // MARK: - Audio Player

    private var audioPlayerSection: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DS.Colors.text)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.accentSoft)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DS.Colors.accentSoft)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DS.Colors.text)
                            .frame(width: geo.size.width * viewModel.playbackProgress, height: 4)
                    }
                }
                .frame(height: 4)

                Text(viewModel.isPlaying ? "播放中" : "点击播放")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textMuted)
            }
        }
        .padding(DS.Spacing.md)
        .cardStyle(radius: DS.Radius.md)
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                sectionHeader("完整文本", icon: "doc.text")
                Spacer()
                Button {
                    viewModel.copyTranscript()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                        Text("复制")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(DS.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))
                }
            }

            if viewModel.record.fullTranscript.isEmpty {
                Text("暂无转录文本")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.textMuted)
                    .padding(.vertical, DS.Spacing.lg)
            } else {
                Text(viewModel.record.fullTranscript)
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.text)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(radius: DS.Radius.md)
            }
        }
    }

    // MARK: - AI Analysis (collapsible)

    private func aiSection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAISection.toggle()
                }
            } label: {
                HStack {
                    sectionHeader("AI 分析", icon: "sparkles")

                    if !viewModel.picks.isEmpty {
                        Text("\(viewModel.picks.count) 条")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.Colors.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))
                    }

                    Spacer()

                    Image(systemName: showAISection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textMuted)
                }
            }
            .buttonStyle(.plain)

            if showAISection {
                // Summary
                if let summary = viewModel.record.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("摘要")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DS.Colors.textSecondary)
                            Spacer()
                            Button { viewModel.copySummary() } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(DS.Colors.textMuted)
                            }
                        }
                        Text(summary)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DS.Colors.text)
                            .lineSpacing(4)
                    }
                    .padding(DS.Spacing.md)
                    .cardStyle(radius: DS.Radius.md)
                }

                // Picks by type
                if !viewModel.topicPicks.isEmpty {
                    pickGroup("话题", "bubble.left.fill", DS.Colors.topicColor,
                              viewModel.topicPicks, scrollProxy: scrollProxy)
                }
                if !viewModel.factPicks.isEmpty {
                    pickGroup("关键信息", "lightbulb.fill", DS.Colors.factColor,
                              viewModel.factPicks, scrollProxy: scrollProxy)
                }
                if !viewModel.actionPicks.isEmpty {
                    pickGroup("待办", "checkmark.circle.fill", DS.Colors.actionColor,
                              viewModel.actionPicks, scrollProxy: scrollProxy)
                }

                // Reprocess button
                Button {
                    Task { await viewModel.reprocess() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                        Text("重新分析")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(DS.Colors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.textSecondary)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(DS.Colors.text)
        }
    }

    private func pickGroup(_ title: String, _ icon: String, _ color: Color,
                           _ picks: [Pick], scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }

            ForEach(picks) { pick in
                PickCardView(
                    pick: pick,
                    isHighlighted: viewModel.highlightedAnchor == pick.contextAnchor
                ) {
                    viewModel.traceToSource(pick)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var record = {
        let r = EchoRecord(fullTranscript: "今天讨论了项目进度，预算大概50万。周五前完成设计稿。", duration: 325)
        r.summary = "项目进度讨论"
        return r
    }()

    NavigationStack {
        EchoDetailView(record: record)
    }
    .modelContainer(StorageService.shared.container)
}
