import SwiftUI
import Combine
import CoreLocation
import UIKit

// MARK: - App Delegate

/// Initializes the location stack synchronously on every launch — including
/// headless background relaunches for geofence events, where SwiftUI may never
/// build the scene (so the @StateObject below would never run). CoreLocation
/// drops the pending region event unless a CLLocationManager with a delegate
/// exists by the end of didFinishLaunching.
///
/// Deliberately does NOT reload geofences here: startMonitoring() stops and
/// re-registers every region, which could cancel delivery of the very event
/// that triggered this launch. handleGeofenceEvent loads from CoreData on
/// demand when the event arrives.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = LocationService.shared

        if launchOptions?[.location] != nil {
            GeofenceLogger.shared.logAppState("Relaunched in background for location event")
            // If this wake came from the significant-change service rather
            // than a region crossing, check for (and recover) missed events
            LocationService.shared.scheduleBackgroundWakeReconcile()
        }
        return true
    }
}

@main
struct KnuckleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var locationService = LocationService.shared
    @StateObject private var timerManager = TimerManager()
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }

    @State private var showLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content (always in hierarchy, fades in)
                Group {
                    if authViewModel.isAuthenticated {
                        MainTabView()
                            .environmentObject(authViewModel)
                            .environmentObject(locationService)
                            .environmentObject(timerManager)
                    } else {
                        LoginView()
                            .environmentObject(authViewModel)
                    }
                }
                .opacity(showLaunchScreen ? 0 : 1)

                // Launch screen overlay (fades out)
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.4), value: showLaunchScreen)
            .onChange(of: authViewModel.isCheckingAuth) { _, isChecking in
                if !isChecking {
                    // Auth check complete, fade out launch screen
                    withAnimation(.easeOut(duration: 0.4)) {
                        showLaunchScreen = false
                    }
                }
            }
            .preferredColorScheme(selectedTheme.colorScheme)
            .onAppear {
                // Log app launch
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
                GeofenceLogger.shared.logAppState("App launched v\(version) (\(build))")

                locationService.requestNotificationPermission()
                // Note: Don't cleanup Live Activities here - TimerManager.refresh() will sync
                // with actual timer state and either update or end the activity appropriately
            }
            .onChange(of: scenePhase) { _, newPhase in
                locationService.isAppActive = (newPhase == .active)

                switch newPhase {
                case .active:
                    GeofenceLogger.shared.logAppState("Became active")
                    Task {
                        // Re-sync geofence monitoring in case the app was
                        // relaunched and in-memory state is stale
                        await GeofenceRepository.shared.loadGeofences()
                        // Process any pending offline operations
                        await OfflineQueue.shared.processQueue()
                        await timerManager.refresh()
                    }
                case .inactive:
                    GeofenceLogger.shared.logAppState("Became inactive")
                case .background:
                    GeofenceLogger.shared.logAppState("Entered background")
                @unknown default:
                    break
                }
            }
        }
    }
}

// MARK: - Timer Manager (shared across all tabs)

@MainActor
class TimerManager: ObservableObject {
    @Published var runningTimer: RunningTimer?
    @Published var stats: TimeStats?
    @Published var isLoading = false

    private var pollTimer: Timer?
    private let harvestService = HarvestService.shared

    init() {
        // Listen for timer state changes (from geofence events, etc.)
        NotificationCenter.default.addObserver(
            forName: .timerStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }

        // Listen for geofence state changes to update Live Activity
        NotificationCenter.default.addObserver(
            forName: .geofenceStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncAllDisplays()
            }
        }
    }

    /// Full refresh - fetches timer state AND stats, syncs Live Activity
    func refresh() async {
        do {
            let newTimer = try await harvestService.getRunningTimer()
            let timerStateChanged = (newTimer != nil) != (runningTimer != nil)
            runningTimer = newTimer

            // Only fetch stats if timer state changed or stats are nil
            if timerStateChanged || stats == nil {
                stats = try? await harvestService.getStats()
            }

            // Sync Live Activity and Widget with current state
            syncAllDisplays()

            // Notify observers if timer state changed
            if timerStateChanged {
                NotificationCenter.default.post(name: .timerStateChanged, object: nil)
            }
        } catch {
            // Keep last known state — a transient network error must not end
            // a legitimately running Live Activity. Dead sessions log the
            // user out via .harvestSessionExpired instead.
        }
    }

    /// Lightweight poll - checks timer state and keeps displays in sync
    private func pollTimerState() async {
        do {
            let newTimer = try await harvestService.getRunningTimer()
            let wasRunning = runningTimer != nil
            let isNowRunning = newTimer != nil

            runningTimer = newTimer

            if wasRunning != isNowRunning {
                // Timer state changed - full refresh + notify
                stats = try? await harvestService.getStats()
                syncAllDisplays()
                NotificationCenter.default.post(name: .timerStateChanged, object: nil)
            } else if isNowRunning {
                // Timer still running - refresh stats and sync displays
                // so the widget/Live Activity hour totals stay accurate
                stats = try? await harvestService.getStats()
                syncAllDisplays()
            }
        } catch {
            // Silently fail during polling - don't clear state on network blips
        }
    }

    func stopTimer() async {
        guard let timer = runningTimer else { return }
        isLoading = true
        do {
            _ = try await harvestService.stopTimer(entryId: timer.id, notes: nil)
            runningTimer = nil
            // Refresh stats after stopping
            stats = try? await harvestService.getStats()
            // Sync displays
            syncAllDisplays()
            NotificationCenter.default.post(name: .timerStateChanged, object: nil)
        } catch {
            // Silently fail - user can manually stop from dashboard
        }
        isLoading = false
    }

    func startPolling() {
        stopPolling()
        // Poll every 60 seconds - just checks timer state, not stats
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollTimerState()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Display Sync (Live Activity)

    /// Sync Live Activity with current timer state
    private func syncAllDisplays() {
        // Get geofence info from LocationService
        let currentGeofence = LocationService.shared.currentGeofence
        let geofenceName = currentGeofence?.name
        let hasActiveGeofences = !LocationService.shared.monitoredGeofences.isEmpty
        let authStatus = LocationService.shared.authorizationStatus
        let needsLocationPermission = hasActiveGeofences && authStatus != .authorizedAlways

        // Calculate base hours for Live Activity
        let currentTimerHours = runningTimer?.hours ?? 0
        let todayBase = max(0, (stats?.hoursToday ?? 0) - currentTimerHours)
        let weekBase = max(0, (stats?.hoursThisWeek ?? 0) - currentTimerHours)

        // Sync Live Activity
        LiveActivityManager.shared.syncWithTimer(
            runningTimer,
            todayHoursBase: todayBase,
            weekHoursBase: weekBase,
            geofenceName: geofenceName,
            needsLocationPermission: needsLocationPermission
        )
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var timerManager: TimerManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }

            EntriesListView()
                .tabItem {
                    Label("Entries", systemImage: "list.clipboard")
                }

            GeofencesView()
                .tabItem {
                    Label("Geofences", systemImage: "location.circle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            await timerManager.refresh()
            timerManager.startPolling()
        }
    }
}
