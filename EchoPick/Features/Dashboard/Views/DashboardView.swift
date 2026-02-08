import SwiftUI
import SwiftData

/// 今日看板
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        statsGrid
                            .padding(.horizontal, DS.Spacing.md)

                        if !viewModel.todayTopics.isEmpty {
                            pickSection(title: "话题", icon: "bubble.left.fill",
                                        color: DS.Colors.topicColor, picks: viewModel.todayTopics)
                        }
                        if !viewModel.todayActions.isEmpty {
                            pickSection(title: "待办", icon: "checkmark.circle.fill",
                                        color: DS.Colors.actionColor, picks: viewModel.todayActions)
                        }
                        if !viewModel.todayFacts.isEmpty {
                            pickSection(title: "关键信息", icon: "lightbulb.fill",
                                        color: DS.Colors.factColor, picks: viewModel.todayFacts)
                        }

                        if viewModel.todayPicks.isEmpty {
                            emptyState.padding(.top, DS.Spacing.xxl)
                        }
                    }
                    .padding(.vertical, DS.Spacing.md)
                }
            }
            .navigationTitle("今日看板")
            .onAppear { viewModel.load() }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 4), spacing: DS.Spacing.sm) {
            stat("\(viewModel.todayRecords.count)", "录音", "waveform", DS.Colors.text)
            stat(viewModel.todayDuration.durationDisplay, "时长", "timer", DS.Colors.text)
            stat("\(viewModel.topicCount)", "话题", "bubble.left.fill", DS.Colors.topicColor)
            stat("\(viewModel.actionCount)", "待办", "checkmark.circle.fill", DS.Colors.actionColor)
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String, _ iconColor: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DS.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle(radius: DS.Radius.md)
    }

    private func pickSection(title: String, icon: String, color: Color, picks: [Pick]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DS.Colors.text)

                Text("\(picks.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DS.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(picks) { pick in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(pick.content)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DS.Colors.text)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(pick.createdAt.timeDisplay)
                                .font(.system(size: 10))
                                .foregroundColor(DS.Colors.textMuted)
                        }
                        .frame(width: 160, alignment: .topLeading)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(color.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(DS.Colors.textMuted)

            Text("今天还没有内容")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DS.Colors.text)

            Text("录音后 AI 会自动提取关键信息")
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(StorageService.shared.container)
}
