//
//  DashboardView.swift
//  Punch
//
//  Main dashboard showing timer, stats, and today's entries
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var locationService: LocationService
    @Environment(\.scenePhase) var scenePhase
    @State private var showStopSheet = false
    @State private var showProjectTaskPicker = false

    private var isRunning: Bool {
        viewModel.runningTimer != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Dynamic geofence background (satellite image when inside)
                GeofenceBackgroundView(geofence: locationService.currentGeofence)

                ScrollView {
                    VStack(spacing: 24) {
                        // Header row: Logo + Geofence Pill
                        HStack {
                            // Logo
                            HStack(spacing: 8) {
                                Text("\u{1F44A}")
                                    .font(.title3)
                                Text("Knuckle")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .tracking(-0.5)
                                    .foregroundColor(.textPrimary)
                            }

                            Spacer()

                            // Geofence status pill (tappable to go to settings)
                            NavigationLink(destination: GeofencesView()) {
                                GeofenceStatusPill(
                                    geofence: locationService.currentGeofence,
                                    locationStatus: locationService.authorizationStatus,
                                    hasActiveGeofences: !locationService.monitoredGeofences.isEmpty
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)

                        // Main Timer Card
                        TimerDisplayView(
                            runningTimer: viewModel.runningTimer,
                            selectedProject: viewModel.selectedProject,
                            selectedTask: viewModel.selectedTask,
                            notes: $viewModel.notes,
                            isTogglingTimer: viewModel.isTogglingTimer,
                            onStart: { Task { await viewModel.startTimer() } },
                            onStop: { showStopSheet = true },
                            onSelectProjectTask: { showProjectTaskPicker = true }
                        )

                        // Stats Row (no card backgrounds, just text)
                        if let stats = viewModel.stats {
                            HStack {
                                StatCard(
                                    title: "Today",
                                    value: DateFormatters.formatDuration(stats.hoursToday),
                                    isHighlighted: isRunning
                                )
                                StatCard(
                                    title: "Week",
                                    value: DateFormatters.formatDuration(stats.hoursThisWeek)
                                )
                                StatCard(
                                    title: "Month",
                                    value: DateFormatters.formatDuration(stats.hoursThisMonth)
                                )
                            }
                            .padding(.horizontal, 8)
                        }

                        // Recent Entry Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TODAY")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.textMuted)
                                .tracking(0.5)

                            if viewModel.todayEntries.isEmpty {
                                // Empty state
                                VStack(spacing: 8) {
                                    Text("No time tracked today")
                                        .font(.subheadline)
                                        .foregroundColor(.textSecondary)
                                    Text("Start a timer to begin tracking")
                                        .font(.caption)
                                        .foregroundColor(.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(Color.bgSecondary.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            } else {
                                ForEach(viewModel.todayEntries) { entry in
                                    RecentEntryCard(
                                        entry: entry,
                                        isCurrentlyRunning: entry.isRunning
                                    )
                                }
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Space for tab bar
                }
                .refreshable {
                    await viewModel.refresh()
                }

                // Syncing indicator (top center, over content)
                VStack {
                    SyncingIndicator(isVisible: viewModel.isSyncing)
                        .padding(.top, 60)
                    Spacer()
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isSyncing)

                // Error toast (top, over everything)
                VStack {
                    if viewModel.showErrorToast, let message = viewModel.errorToastMessage {
                        ErrorToast(message: message, onDismiss: viewModel.dismissError)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.refresh() }
                }
            }
            .sheet(isPresented: $showStopSheet) {
                StopTimerSheet(
                    timer: viewModel.runningTimer,
                    onStop: { notes in
                        Task {
                            await viewModel.stopTimer(notes: notes)
                            showStopSheet = false
                        }
                    }
                )
            }
            .sheet(isPresented: $showProjectTaskPicker) {
                ProjectTaskPickerView(
                    projects: viewModel.projects,
                    selectedProject: $viewModel.selectedProject,
                    selectedTask: $viewModel.selectedTask,
                    tasksForProject: { projectId in
                        await viewModel.getTasks(forProjectId: projectId)
                    }
                )
            }
        }
    }
}

// MARK: - Recent Entry Card (per UI spec)

struct RecentEntryCard: View {
    let entry: TrackedTimeEntry
    let isCurrentlyRunning: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.projectName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Text(entry.notes ?? entry.taskName)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(entry.hours))
                .font(.subheadline)
                .foregroundColor(isCurrentlyRunning ? .success : .textSecondary)
                .fontWeight(isCurrentlyRunning ? .semibold : .regular)
        }
        .padding(16)
        .background(isCurrentlyRunning ? Color.successSubtle : Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: isCurrentlyRunning ? Color.clear : Color.shadowCard, radius: 6, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrentlyRunning ? Color.successBorder : (colorScheme == .light ? Color.borderSubtle : Color.clear),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isCurrentlyRunning)
    }

    private func formatDuration(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60

        if h > 0 {
            return "\(h):\(String(format: "%02d", m))"
        }
        return "\(m)m"
    }
}

#Preview {
    DashboardView()
        .environmentObject(LocationService.shared)
}
