# Punch iOS App

A native iOS app for automatic time tracking via geofencing.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Paid Apple Developer account (required for background location)

## Setup

### 1. Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select "App" under iOS
4. Configure:
   - Product Name: **Punch**
   - Team: Your developer team
   - Organization Identifier: com.yourname
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: None
   - Uncheck "Include Tests"
5. Save to `<your-repo>/Knuckle.iOS/Punch/`

### 2. Add Source Files

1. In Xcode, delete the auto-generated ContentView.swift
2. Right-click the Punch folder → Add Files to "Punch"
3. Navigate to `<your-repo>/Knuckle.iOS/Punch/Punch/`
4. Select all folders (Models, Services, ViewModels, Views, Utilities) and PunchApp.swift
5. Make sure "Copy items if needed" is **unchecked**
6. Make sure "Create folder references" is selected
7. Click Add

### 3. Configure Info.plist

Add these keys to your app's Info.plist (or use the provided Info.plist):

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Punch uses your location to automatically start and stop your work timer when you arrive at or leave your workplace.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Punch uses your location to automatically start and stop your work timer when you arrive at or leave your workplace.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### 4. Configure Signing & Capabilities

1. Select the Punch target
2. Go to Signing & Capabilities
3. Add capability: **Background Modes**
   - Check "Location updates"
4. Ensure your team is selected for signing

### 5. Configure Build Settings

1. iOS Deployment Target: 17.0

## Project Structure

```
Punch/
├── PunchApp.swift           # App entry point
├── Models/
│   └── API/                 # API request/response models
├── Services/
│   ├── APIClient.swift      # Network layer
│   ├── KeychainService.swift # Secure token storage
│   ├── LocationService.swift # Geofencing
│   └── OfflineQueue.swift   # Offline event queue
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── DashboardViewModel.swift
│   ├── EntriesViewModel.swift
│   ├── EntryFormViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Auth/
│   ├── Dashboard/
│   ├── Entries/
│   ├── Settings/
│   └── Components/
├── Utilities/
│   ├── Colors.swift
│   ├── DateFormatters.swift
│   └── UUIDv7.swift
└── Info.plist
```

## Configuration

### Server URL

The app connects to a Punch server. Configure the server URL:

1. On the login screen, tap "Server Settings"
2. Enter your server URL (e.g., `http://192.168.1.100:5000`)
3. For local development, use your Mac's IP address (not localhost)

The server URL is stored in UserDefaults and persists between app launches.

### Default Server

The default server URL is `http://localhost:5000`. Change this in `APIClient.swift`:

```swift
private static let defaultServerURL = "http://your-server.com"
```

## Features

- **Automatic Time Tracking**: Timer starts/stops when entering/leaving geofenced areas
- **Manual Timer Controls**: Start/stop timer manually with client selection
- **Time Entries**: View, create, edit, and delete time entries
- **Geofence Management**: View and toggle geofences (edit via web app)
- **Offline Support**: Geofence events queued when offline
- **Dark Mode**: Native dark theme

## Testing

### Simulator Geofence Testing

1. Run the app in Simulator
2. Debug → Location → Custom Location
3. Enter coordinates inside/outside your geofence
4. Watch for timer start/stop

### Device Testing

1. Create a geofence with small radius (50m) near your location
2. Walk in and out of the geofence area
3. Verify timer behavior

## Troubleshooting

### "Location permission denied"
- Go to Settings → Punch → Location → Always

### "Cannot connect to server"
- Verify server URL in Settings
- Ensure server is running
- Check network connectivity
- For local testing, use Mac's IP (not localhost)

### Timer not starting on geofence entry
- Verify geofence is marked "Active"
- Check location permission is "Always"
- Ensure the geofence radius is appropriate
