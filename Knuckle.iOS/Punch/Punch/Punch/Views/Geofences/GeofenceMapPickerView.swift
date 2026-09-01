import SwiftUI
import MapKit

struct GeofenceMapPickerView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var radiusMeters: Int
    @Environment(\.dismiss) var dismiss

    @State private var cameraPosition: MapCameraPosition
    @State private var markerCoordinate: CLLocationCoordinate2D

    init(latitude: Binding<Double>, longitude: Binding<Double>, radiusMeters: Binding<Int>) {
        _latitude = latitude
        _longitude = longitude
        _radiusMeters = radiusMeters

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude.wrappedValue,
            longitude: longitude.wrappedValue
        )
        _markerCoordinate = State(initialValue: coordinate)

        // Use a sensible default if coordinates are 0,0
        if latitude.wrappedValue == 0 && longitude.wrappedValue == 0 {
            if let location = LocationService.shared.currentLocation {
                _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )))
                _markerCoordinate = State(initialValue: location.coordinate)
            } else {
                // Use user location with a fallback to a default region
                let defaultRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
                _cameraPosition = State(initialValue: .userLocation(fallback: .region(defaultRegion)))
            }
        } else {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: Double(radiusMeters.wrappedValue) * 4,
                longitudinalMeters: Double(radiusMeters.wrappedValue) * 4
            )))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        // Circle overlay for radius
                        MapCircle(center: markerCoordinate, radius: CLLocationDistance(radiusMeters))
                            .foregroundStyle(Color.accent.opacity(0.2))
                            .stroke(Color.accent, lineWidth: 2)

                        // Center marker
                        Annotation("", coordinate: markerCoordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.accent)
                        }
                    }
                    .onTapGesture { position in
                        if let coordinate = proxy.convert(position, from: .local) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                markerCoordinate = coordinate
                            }
                        }
                    }
                }

                // Controls
                VStack(spacing: 16) {
                    // Use Current Location button
                    Button {
                        useCurrentLocation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Use Current Location")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    // Radius slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Radius")
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Text("\(radiusMeters)m")
                                .foregroundColor(.textPrimary)
                                .font(.headline)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(radiusMeters) },
                                set: { radiusMeters = Int($0) }
                            ),
                            in: 50...1000,
                            step: 10
                        )
                        .tint(.accent)

                        HStack {
                            Text("50m")
                                .font(.caption)
                                .foregroundColor(.textMuted)
                            Spacer()
                            Text("1000m")
                                .font(.caption)
                                .foregroundColor(.textMuted)
                        }
                    }

                    // Coordinates display
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latitude")
                                .font(.caption)
                                .foregroundColor(.textMuted)
                            Text(String(format: "%.6f", markerCoordinate.latitude))
                                .font(.footnote.monospaced())
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Longitude")
                                .font(.caption)
                                .foregroundColor(.textMuted)
                            Text(String(format: "%.6f", markerCoordinate.longitude))
                                .font(.footnote.monospaced())
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .padding()
                .background(Color.bgSecondary)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Request location update if marker is at 0,0
                if markerCoordinate.latitude == 0 && markerCoordinate.longitude == 0 {
                    LocationService.shared.requestOneTimeLocation { location in
                        if let location = location {
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    markerCoordinate = location.coordinate
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: location.coordinate,
                                        latitudinalMeters: Double(radiusMeters) * 4,
                                        longitudinalMeters: Double(radiusMeters) * 4
                                    ))
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        latitude = markerCoordinate.latitude
                        longitude = markerCoordinate.longitude
                        dismiss()
                    }
                }
            }
        }
    }

    private func useCurrentLocation() {
        if let location = LocationService.shared.currentLocation {
            withAnimation(.easeInOut(duration: 0.3)) {
                markerCoordinate = location.coordinate
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: Double(radiusMeters) * 4,
                    longitudinalMeters: Double(radiusMeters) * 4
                ))
            }
        }
    }
}

#Preview {
    GeofenceMapPickerView(
        latitude: .constant(40.758896),
        longitude: .constant(-73.985130),
        radiusMeters: .constant(100)
    )
}
