import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulse = false

    var body: some View {
        ZStack {
            DS.Colors.bg.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(DS.Colors.border, lineWidth: 1)
                            .frame(width: CGFloat(64 + i * 36), height: CGFloat(64 + i * 36))
                            .scaleEffect(pulse ? 1.08 : 0.92)
                            .animation(
                                .easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(Double(i) * 0.15),
                                value: pulse
                            )
                    }

                    Image(systemName: "waveform")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(DS.Colors.text)
                }

                VStack(spacing: 8) {
                    Text("EchoPick")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.text)

                    Text("语音笔记，放口袋里就行")
                        .font(DS.Font.body())
                        .foregroundColor(DS.Colors.textSecondary)
                }

                Spacer()

                Button {
                    appState.authenticate()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18))
                        Text("解锁")
                            .font(DS.Font.bodyBold(15))
                    }
                    .foregroundColor(DS.Colors.bgCard)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(DS.Colors.text))
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            pulse = true
            appState.authenticate()
        }
    }
}

#Preview {
    LockScreenView().environmentObject(AppState())
}
