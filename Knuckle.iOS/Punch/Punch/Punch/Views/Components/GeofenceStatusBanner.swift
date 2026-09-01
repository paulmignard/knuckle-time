import SwiftUI
import CoreLocation

/// Compact geofence status pill for the header
struct GeofenceStatusPill: View {
    let geofence: Geofence?
    var locationStatus: CLAuthorizationStatus = .authorizedAlways
    var hasActiveGeofences: Bool = false

    private var isInside: Bool {
        geofence != nil
    }

    /// Check if we need to warn about permissions
    private var needsPermissionWarning: Bool {
        // Only warn if there are active geofences AND permission isn't "Always"
        hasActiveGeofences && locationStatus != .authorizedAlways
    }

    private var dotColor: Color {
        if needsPermissionWarning {
            return .danger
        } else if isInside {
            return .success
        } else {
            return .textMuted
        }
    }

    private var textColor: Color {
        if needsPermissionWarning {
            return .danger
        } else if isInside {
            return .success
        } else {
            return .textMuted
        }
    }

    private var backgroundColor: Color {
        if needsPermissionWarning {
            return Color.danger.opacity(0.15)
        } else if isInside {
            return Color.successSubtle
        } else {
            return Color.bgElevated
        }
    }

    private var borderColor: Color {
        if needsPermissionWarning {
            return Color.danger.opacity(0.3)
        } else if isInside {
            return Color.successBorder
        } else {
            return Color.clear
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier(isAnimating: isInside || needsPermissionWarning))

            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var statusText: String {
        if needsPermissionWarning {
            return "Needs Permission"
        } else if let fence = geofence {
            return fence.name
        } else {
            return "Away"
        }
    }
}

/// Pulse animation modifier for the geofence indicator dot
private struct PulseModifier: ViewModifier {
    let isAnimating: Bool
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                if isAnimating {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        scale = 1.3
                        opacity = 0.6
                    }
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        scale = 1.3
                        opacity = 0.6
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Away state
        HStack {
            Text("Away:")
                .font(.caption)
                .foregroundColor(.textSecondary)
            Spacer()
            GeofenceStatusPill(geofence: nil)
        }

        // Inside geofence
        HStack {
            Text("Inside:")
                .font(.caption)
                .foregroundColor(.textSecondary)
            Spacer()
            GeofenceStatusPill(geofence: Geofence(
                id: UUID(),
                clientId: UUID(),
                clientName: "Acme Corp",
                name: "Main Office",
                latitude: 40.7128,
                longitude: -74.0060,
                radiusMeters: 100,
                isActive: true,
                createdAt: Date()
            ))
        }

        // Needs permission warning
        HStack {
            Text("Needs Permission:")
                .font(.caption)
                .foregroundColor(.textSecondary)
            Spacer()
            GeofenceStatusPill(
                geofence: nil,
                locationStatus: .authorizedWhenInUse,
                hasActiveGeofences: true
            )
        }
    }
    .padding()
    .background(Color.bgPrimary)
}
