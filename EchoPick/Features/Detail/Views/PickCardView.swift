import SwiftUI

/// Pick 卡片 — 带类型颜色区分
struct PickCardView: View {
    let pick: Pick
    let isHighlighted: Bool
    let onTap: () -> Void

    var pickType: PickType {
        PickType(rawValue: pick.pickType) ?? .keyFact
    }

    private var typeColor: Color {
        switch pickType {
        case .topic: DS.Colors.topicColor
        case .actionItem: DS.Colors.actionColor
        case .keyFact: DS.Colors.factColor
        case .sentiment: Color(hex: "#EC4899")
        case .keyMetric: Color(hex: "#10B981")
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: pickType.icon)
                    .font(.system(size: 13))
                    .foregroundColor(typeColor)
                    .frame(width: 28, height: 28)
                    .background(typeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(pickType.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(typeColor)
                        .textCase(.uppercase)

                    Text(pick.content)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.textMuted)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(isHighlighted ? typeColor.opacity(0.08) : DS.Colors.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(
                        isHighlighted ? typeColor.opacity(0.4) : DS.Colors.border,
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 8) {
        PickCardView(
            pick: Pick(recordId: UUID(), pickType: "topic", content: "讨论了项目进度", contextAnchor: "项目进度"),
            isHighlighted: false
        ) {}
        PickCardView(
            pick: Pick(recordId: UUID(), pickType: "action_item", content: "周五前完成设计稿", contextAnchor: "设计稿"),
            isHighlighted: true
        ) {}
        PickCardView(
            pick: Pick(recordId: UUID(), pickType: "key_fact", content: "预算：50万元", contextAnchor: "50万"),
            isHighlighted: false
        ) {}
    }
    .padding()
    .background(DS.Colors.bg)
}
