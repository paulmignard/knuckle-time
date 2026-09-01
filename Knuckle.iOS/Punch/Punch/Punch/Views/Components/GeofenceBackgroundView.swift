import SwiftUI

/// Displays a black & white satellite image of the geofence location as a background
/// with a dark gradient overlay for readability
struct GeofenceBackgroundView: View {
    let geofence: Geofence?
    @State private var image: UIImage?
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Idle state gradient (when not in a geofence)
                LinearGradient(
                    colors: [.bgIdleGradientStart, .bgIdleGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Geofence satellite image (if available)
                if let image = image, geofence != nil {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .saturation(0) // Black & white
                        .opacity(isVisible ? 0.6 : 0)
                        .animation(.easeInOut(duration: 0.8), value: isVisible)

                    // Adaptive overlay for readability (white in light mode, dark in dark mode)
                    Color.bgSatelliteOverlay
                        .opacity(isVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8), value: isVisible)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: geofence?.id) { oldValue, newValue in
            if let geofenceId = newValue {
                loadImage(for: geofenceId)
            } else {
                // Fade out when leaving geofence
                withAnimation(.easeInOut(duration: 0.5)) {
                    isVisible = false
                }
                // Clear image after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    image = nil
                }
            }
        }
        .task {
            // Load image on initial appear if inside a geofence
            if let geofenceId = geofence?.id {
                loadImage(for: geofenceId)
            }
        }
    }

    private func loadImage(for geofenceId: UUID) {
        Task {
            // Try to load cached image
            if let cached = await GeofenceSnapshotService.shared.loadSnapshot(for: geofenceId) {
                await MainActor.run {
                    image = cached
                    withAnimation(.easeInOut(duration: 0.8)) {
                        isVisible = true
                    }
                }
            } else if let geofence = geofence {
                // Generate snapshot if not cached
                await GeofenceSnapshotService.shared.generateSnapshot(
                    geofenceId: geofenceId,
                    latitude: geofence.latitude,
                    longitude: geofence.longitude,
                    radiusMeters: geofence.radiusMeters
                )
                // Try loading again after generation
                if let generated = await GeofenceSnapshotService.shared.loadSnapshot(for: geofenceId) {
                    await MainActor.run {
                        image = generated
                        withAnimation(.easeInOut(duration: 0.8)) {
                            isVisible = true
                        }
                    }
                }
            }
        }
    }
}

#Preview("With Geofence") {
    GeofenceBackgroundView(geofence: Geofence(
        id: UUID(),
        clientId: UUID(),
        clientName: "Acme",
        name: "Main Office",
        latitude: 28.0836,
        longitude: -80.6081,
        radiusMeters: 100,
        isActive: true,
        createdAt: Date()
    ))
}

#Preview("No Geofence") {
    GeofenceBackgroundView(geofence: nil)
}
