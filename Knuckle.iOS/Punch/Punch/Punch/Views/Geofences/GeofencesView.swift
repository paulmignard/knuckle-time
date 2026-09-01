import SwiftUI
import CoreLocation

struct GeofencesView: View {
    @StateObject private var viewModel = GeofencesViewModel()
    @State private var showAddGeofence = false

    var body: some View {
        NavigationStack {
            List {
                // Location section
                Section {
                    HStack {
                        Image(systemName: locationIcon)
                            .foregroundColor(locationColor)
                        Text("Location Access")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(locationStatusText)
                            .foregroundColor(.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.locationStatus == .denied || viewModel.locationStatus == .restricted {
                            viewModel.openSettings()
                        } else if viewModel.locationStatus == .notDetermined {
                            LocationService.shared.requestPermission()
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Knuckle requires \"Always\" location access to automatically track time when you enter or leave work locations.")
                }
                .listRowBackground(Color.bgSecondary)

                // Geofences section
                Section {
                    ForEach(viewModel.geofences) { geofence in
                        NavigationLink(destination: GeofenceDetailView(geofence: geofence, viewModel: viewModel)) {
                            GeofenceRow(geofence: geofence)
                        }
                    }
                } header: {
                    Text("Geofences")
                } footer: {
                    Text("\(viewModel.activeGeofenceCount) of \(LocationService.maxGeofences) geofences active.")
                }
                .listRowBackground(Color.bgSecondary)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle("Geofences")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddGeofence = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.geofences.count >= LocationService.maxGeofences)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showAddGeofence) {
                GeofenceFormView()
                    .onDisappear {
                        Task {
                            await viewModel.fetchGeofences()
                        }
                    }
            }
        }
    }

    // MARK: - Location Helpers

    private var locationIcon: String {
        switch viewModel.locationStatus {
        case .authorizedAlways:
            return "location.fill"
        case .authorizedWhenInUse:
            return "location"
        case .denied, .restricted:
            return "location.slash"
        case .notDetermined:
            return "location"
        @unknown default:
            return "location"
        }
    }

    private var locationColor: Color {
        switch viewModel.locationStatus {
        case .authorizedAlways:
            return .success
        case .authorizedWhenInUse:
            return .warning
        case .denied, .restricted:
            return .danger
        case .notDetermined:
            return .textMuted
        @unknown default:
            return .textMuted
        }
    }

    private var locationStatusText: String {
        switch viewModel.locationStatus {
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Geofence Row

struct GeofenceRow: View {
    let geofence: LocalGeofence

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.circle.fill")
                .font(.title2)
                .foregroundColor(geofence.isActive ? .success : .textMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(geofence.name)
                    .font(.body)
                    .foregroundColor(.textPrimary)

                Text("\(geofence.harvestProjectName) - \(geofence.harvestTaskName)")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            Text(geofence.isActive ? "Active" : "Inactive")
                .font(.caption)
                .foregroundColor(geofence.isActive ? .success : .textMuted)
        }
    }
}

#Preview {
    GeofencesView()
}
