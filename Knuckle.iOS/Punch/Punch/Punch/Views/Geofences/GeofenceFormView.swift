//
//  GeofenceFormView.swift
//  Punch
//
//  Create/edit geofence with project/task selection
//

import SwiftUI
import MapKit

struct GeofenceFormView: View {
    @StateObject private var viewModel: GeofenceFormViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showMapPicker = false

    init(geofence: LocalGeofence? = nil) {
        _viewModel = StateObject(wrappedValue: GeofenceFormViewModel(geofence: geofence))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name section
                Section("Name") {
                    TextField("Geofence Name", text: $viewModel.name)
                }

                // Project/Task section
                Section {
                    // Project picker
                    Picker("Project", selection: $viewModel.selectedProject) {
                        Text("Select Project").tag(nil as Project?)
                        ForEach(viewModel.projects) { project in
                            VStack(alignment: .leading) {
                                Text(project.name)
                                if let clientName = project.clientName {
                                    Text(clientName)
                                        .font(.caption)
                                        .foregroundColor(.textTertiary)
                                }
                            }
                            .tag(project as Project?)
                        }
                    }
                    .onChange(of: viewModel.selectedProject) { _, newProject in
                        if let project = newProject {
                            Task {
                                await viewModel.loadTasks(for: project.id)
                            }
                        }
                    }

                    // Task picker
                    Picker("Task", selection: $viewModel.selectedTask) {
                        Text("Select Task").tag(nil as ProjectTask?)
                        ForEach(viewModel.tasks) { task in
                            Text(task.name).tag(task as ProjectTask?)
                        }
                    }
                    .disabled(viewModel.selectedProject == nil)
                } header: {
                    Text("Harvest Project & Task")
                }

                // Default Note section
                Section {
                    TextField("e.g., Geofence started with Knuckle", text: $viewModel.defaultNote)
                } header: {
                    Text("Default Note")
                } footer: {
                    Text("This note will be added to time entries when Knuckle automatically starts the timer at this location.")
                }

                // Location section
                Section {
                    // Map preview
                    Button {
                        showMapPicker = true
                    } label: {
                        VStack(spacing: 12) {
                            if viewModel.latitude != 0 || viewModel.longitude != 0 {
                                Map(position: .constant(.region(MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(
                                        latitude: viewModel.latitude,
                                        longitude: viewModel.longitude
                                    ),
                                    latitudinalMeters: Double(viewModel.radiusMeters) * 3,
                                    longitudinalMeters: Double(viewModel.radiusMeters) * 3
                                )))) {
                                    MapCircle(
                                        center: CLLocationCoordinate2D(
                                            latitude: viewModel.latitude,
                                            longitude: viewModel.longitude
                                        ),
                                        radius: CLLocationDistance(viewModel.radiusMeters)
                                    )
                                    .foregroundStyle(Color.accent.opacity(0.2))
                                    .stroke(Color.accent, lineWidth: 2)
                                }
                                .frame(height: 150)
                                .cornerRadius(8)
                                .allowsHitTesting(false)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.bgTertiary)
                                        .frame(height: 150)

                                    VStack(spacing: 8) {
                                        Image(systemName: "map")
                                            .font(.largeTitle)
                                            .foregroundColor(.textMuted)
                                        Text("Tap to set location")
                                            .font(.caption)
                                            .foregroundColor(.textMuted)
                                    }
                                }
                            }

                            HStack {
                                if viewModel.latitude != 0 || viewModel.longitude != 0 {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(format: "%.6f, %.6f", viewModel.latitude, viewModel.longitude))
                                            .font(.footnote.monospaced())
                                            .foregroundColor(.textSecondary)
                                        Text("Radius: \(viewModel.radiusMeters)m")
                                            .font(.caption)
                                            .foregroundColor(.textMuted)
                                    }
                                } else {
                                    Text("No location set")
                                        .font(.footnote)
                                        .foregroundColor(.textMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.textMuted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Location")
                } footer: {
                    Text("Tap to open the map and set the geofence location and radius.")
                }

                // Active section
                Section {
                    Toggle(isOn: $viewModel.isActive) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active")
                                .foregroundColor(.textPrimary)
                            Text("Automatically track time when entering/leaving this area")
                                .font(.caption)
                                .foregroundColor(.textTertiary)
                        }
                    }
                }

                // Delete section (edit mode only)
                if viewModel.isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Geofence")
                                Spacer()
                            }
                        }
                    }
                }

                // Error display
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle(viewModel.isEditing ? "Edit Geofence" : "New Geofence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.isValid)
                }
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showMapPicker) {
                GeofenceMapPickerView(
                    latitude: $viewModel.latitude,
                    longitude: $viewModel.longitude,
                    radiusMeters: $viewModel.radiusMeters
                )
            }
            .alert("Delete Geofence?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. The geofence will stop tracking time automatically.")
            }
        }
    }
}

#Preview("New Geofence") {
    GeofenceFormView()
}

#Preview("Edit Geofence") {
    GeofenceFormView(geofence: LocalGeofence(
        id: UUID(),
        name: "Main Office",
        latitude: 40.758896,
        longitude: -73.985130,
        radiusMeters: 100,
        isActive: true,
        harvestProjectId: 1,
        harvestProjectName: "Website Redesign",
        harvestTaskId: 1,
        harvestTaskName: "Development",
        defaultNote: "Geofence started with Knuckle"
    ))
}
