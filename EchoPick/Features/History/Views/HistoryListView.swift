import SwiftUI
import SwiftData

/// 记录列表
struct HistoryListView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.bg.ignoresSafeArea()

                if viewModel.records.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
            .navigationTitle("记录")
            .searchable(text: $viewModel.searchText, prompt: "搜索内容...")
            .onChange(of: viewModel.searchText) { _, _ in viewModel.load() }
            .onAppear { viewModel.load() }
        }
    }

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(viewModel.filteredRecords) { record in
                    NavigationLink {
                        EchoDetailView(record: record)
                    } label: {
                        EchoRowView(record: record)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.delete(record)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(DS.Colors.textMuted)

            Text("还没有录音")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DS.Colors.text)

            Text("去录音页开始记录")
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

// MARK: - Row

struct EchoRowView: View {
    let record: EchoRecord

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                if record.isProcessing {
                    HStack(spacing: 5) {
                        ProgressView().scaleEffect(0.6)
                        Text(record.processingStatus ?? "分析中…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }

                Text(record.duration.durationDisplay)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))

                Spacer()

                Text(record.createdAt.smartDisplay)
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textMuted)
            }

            // Content
            if let summary = record.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.text)
                    .lineLimit(2)
            } else if !record.fullTranscript.isEmpty {
                Text(record.fullTranscript)
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.textSecondary)
                    .lineLimit(2)
            } else {
                Text("暂无转录")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.textMuted)
            }

            // Pick badges — with color
            if !record.isProcessing {
                let picks = StorageService.shared.fetchPicks(for: record.id)
                if !picks.isEmpty {
                    pickBadges(picks)
                }
            }
        }
        .padding(DS.Spacing.md)
        .cardStyle()
    }

    private func pickBadges(_ picks: [Pick]) -> some View {
        HStack(spacing: 6) {
            let grouped = Dictionary(grouping: picks) { $0.pickType }
            ForEach(Array(grouped.keys.sorted()), id: \.self) { type in
                let pt = PickType(rawValue: type) ?? .keyFact
                let color = pickTypeColor(pt)
                HStack(spacing: 3) {
                    Image(systemName: pt.icon)
                        .font(.system(size: 9))
                    Text("\(grouped[type]?.count ?? 0)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private func pickTypeColor(_ pt: PickType) -> Color {
        switch pt {
        case .topic: DS.Colors.topicColor
        case .actionItem: DS.Colors.actionColor
        case .keyFact: DS.Colors.factColor
        case .sentiment: Color(hex: "#EC4899")
        case .keyMetric: Color(hex: "#10B981")
        }
    }
}

#Preview {
    HistoryListView()
        .modelContainer(for: [EchoRecord.self, Pick.self])
}
