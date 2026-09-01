import SwiftUI
import MapKit

struct GeofenceDetailView: View {
    let geofence: LocalGeofence
    @ObservedObject var viewModel: GeofencesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isTogglingActive = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            latitudinalMeters: Double(geofence.radiusMeters) * 3,
            longitudinalMeters: Double(geofence.radiusMeters) * 3
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Map view
                Map(position: .constant(.region(mapRegion))) {
                    MapCircle(
                        center: CLLocationCoordinate2D(
                            latitude: geofence.latitude,
                            longitude: geofence.longitude
                        ),
                        radius: CLLocationDistance(geofence.radiusMeters)
                    )
                    .foregroundStyle(Color.accent.opacity(0.2))
                    .stroke(Color.accent, lineWidth: 2)

                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: geofence.latitude,
                        longitude: geofence.longitude
                    )) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.accent)
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)

                // Details
                GroupBox {
                    VStack(spacing: 0) {
                        DetailRow(label: "Name", value: geofence.name)
                        Divider().background(Color.separator)
                        DetailRow(label: "Project", value: geofence.harvestProjectName)
                        Divider().background(Color.separator)
                        DetailRow(label: "Task", value: geofence.harvestTaskName)
                        Divider().background(Color.separator)
                        DetailRow(label: "Latitude", value: String(format: "%.6f", geofence.latitude))
                        Divider().background(Color.separator)
                        DetailRow(label: "Longitude", value: String(format: "%.6f", geofence.longitude))
                        Divider().background(Color.separator)
                        DetailRow(label: "Radius", value: "\(geofence.radiusMeters)m")
                    }
                }
                .backgroundStyle(Color.bgSecondary)

                // Active toggle
                GroupBox {
                    Toggle(isOn: Binding(
                        get: { geofence.isActive },
                        set: { _ in toggleActive() }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active")
                                .foregroundColor(.textPrimary)
                            Text("When active, entering or leaving this area will start/stop your timer")
                                .font(.caption)
                                .foregroundColor(.textTertiary)
                        }
                    }
                    .disabled(isTogglingActive)
                }
                .backgroundStyle(Color.bgSecondary)

                // Delete button
                GroupBox {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Geofence")
                            Spacer()
                        }
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }
                .backgroundStyle(Color.bgSecondary)
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .navigationTitle("Geofence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            GeofenceFormView(geofence: geofence)
                .onDisappear {
                    Task {
                        await viewModel.fetchGeofences()
                    }
                }
        }
        .alert("Delete Geofence?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteGeofence(geofence.id) {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. The geofence will stop tracking time automatically.")
        }
    }

    private func toggleActive() {
        guard !isTogglingActive else { return }
        isTogglingActive = true

        Task {
            await viewModel.toggleGeofence(geofence)
            isTogglingActive = false
        }
    }
}

#Preview {
    NavigationStack {
        GeofenceDetailView(
            geofence: LocalGeofence(
                id: UUID(),
                name: "Main Office",
                latitude: 40.758896,
                longitude: -73.985130,
                radiusMeters: 100,
                isActive: true,
                harvestProjectId: 1,
                harvestProjectName: "Acme Project",
                harvestTaskId: 1,
                harvestTaskName: "Development"
            ),
            viewModel: GeofencesViewModel()
        )
    }
}
