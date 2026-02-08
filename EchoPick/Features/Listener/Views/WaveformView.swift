import SwiftUI

/// 波形
struct WaveformView: View {
    let level: Float
    let isActive: Bool

    private let barCount = 32

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: spacing(geo.size.width)) {
                ForEach(0..<barCount, id: \.self) { i in
                    bar(i, size: geo.size)
                }
            }
        }
    }

    private func spacing(_ w: CGFloat) -> CGFloat {
        max(1.5, (w - 2 * CGFloat(barCount)) / CGFloat(barCount - 1))
    }

    private func bar(_ i: Int, size: CGSize) -> some View {
        let center = barCount / 2
        let dist = abs(i - center)
        let centerFactor = 1.0 - (CGFloat(dist) / CGFloat(center)) * 0.5
        let noise = CGFloat.random(in: 0.6...1.0)

        let activeH = max(3, CGFloat(level) * size.height * centerFactor * noise)
        let idleH: CGFloat = 2 + centerFactor * 2

        return RoundedRectangle(cornerRadius: 1)
            .fill(isActive
                ? DS.Colors.text.opacity(0.4 + Double(centerFactor) * 0.3)
                : DS.Colors.textMuted.opacity(0.4))
            .frame(width: 2, height: isActive ? activeH : idleH)
            .animation(.easeOut(duration: 0.12), value: level)
    }
}
