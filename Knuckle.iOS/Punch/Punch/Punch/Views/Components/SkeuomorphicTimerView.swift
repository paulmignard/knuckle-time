import SwiftUI

/// A retro LCD-style timer display with inner gradient and glowing digits
struct SkeuomorphicTimerView: View {
    let timeString: String
    let isRunning: Bool

    var body: some View {
        ZStack {
            // Background with inner gradient (creates depth)
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "1a1a1a"),
                            Color(hex: "0d0d0d"),
                            Color(hex: "000000")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Inner shadow/bevel effect
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .blur(radius: 1)

            // Subtle vignette
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )

            // Timer digits with glow
            Text(timeString)
                .font(.system(size: 48, weight: .regular, design: .monospaced))
                .foregroundColor(.success)
                .shadow(color: isRunning ? Color.successGlow : Color.successGlow.opacity(0.3), radius: isRunning ? 20 : 8)
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            // Outer subtle glow when running
            RoundedRectangle(cornerRadius: 16)
                .stroke(isRunning ? Color.successBorder : Color.clear, lineWidth: 1)
        )
        .shadow(color: isRunning ? Color.successGlow.opacity(0.3) : .clear, radius: 20)
        .animation(.easeInOut(duration: 0.3), value: isRunning)
    }
}

#Preview("Timer States") {
    VStack(spacing: 20) {
        SkeuomorphicTimerView(timeString: "02:34:17", isRunning: true)
            .padding(.horizontal)

        SkeuomorphicTimerView(timeString: "00:00:00", isRunning: false)
            .padding(.horizontal)
    }
    .padding(.vertical, 40)
    .background(Color(hex: "0d0d0d"))
}
