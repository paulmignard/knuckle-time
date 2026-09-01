import SwiftUI
import Combine

// MARK: - Shimmer Effect Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    var duration: Double = 2.5
    var color: Color = .success

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            color.opacity(0.03),
                            color.opacity(0.08),
                            color.opacity(0.03),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width)
                    .offset(x: phase * geometry.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pulse Glow Modifier

struct PulseGlowModifier: ViewModifier {
    @State private var glowOpacity: Double = 0.5

    var color: Color = .success
    var radius: CGFloat = 30

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(glowOpacity * 0.3), radius: radius)
            .shadow(color: color.opacity(glowOpacity * 0.15), radius: radius * 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 1
                }
            }
    }
}

// MARK: - Pulsing Dot Modifier

struct PulsingDotModifier: ViewModifier {
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 0.85
                    opacity = 0.6
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func shimmer(duration: Double = 2.5, color: Color = .success) -> some View {
        modifier(ShimmerModifier(duration: duration, color: color))
    }

    func pulseGlow(color: Color = .success, radius: CGFloat = 30) -> some View {
        modifier(PulseGlowModifier(color: color, radius: radius))
    }

    func pulsingDot() -> some View {
        modifier(PulsingDotModifier())
    }

    @ViewBuilder
    func shimmerIf(_ condition: Bool, duration: Double = 2.5, color: Color = .success) -> some View {
        if condition {
            self.shimmer(duration: duration, color: color)
        } else {
            self
        }
    }

    @ViewBuilder
    func pulseGlowIf(_ condition: Bool, color: Color = .success, radius: CGFloat = 30) -> some View {
        if condition {
            self.pulseGlow(color: color, radius: radius)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.bgSecondary)
            .frame(height: 100)
            .shimmer()

        RoundedRectangle(cornerRadius: 16)
            .fill(Color.bgSecondary)
            .frame(height: 100)
            .pulseGlow()

        Circle()
            .fill(Color.success)
            .frame(width: 12, height: 12)
            .pulsingDot()
    }
    .padding()
    .background(Color.bgPrimary)
}
