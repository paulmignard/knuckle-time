import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled: Bool = true
    @State private var showLogoutConfirmation = false

    private var selectedTheme: AppTheme {
        get { AppTheme(rawValue: appTheme) ?? .system }
        set { appTheme = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                // Appearance section
                Section("Appearance") {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            appTheme = theme.rawValue
                        } label: {
                            HStack {
                                Image(systemName: theme.icon)
                                    .foregroundColor(.accent)
                                    .frame(width: 24)
                                Text(theme.rawValue)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                if selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.success)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.bgSecondary)

                // Live Activity section
                Section {
                    Toggle(isOn: $liveActivityEnabled) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.accent)
                                .frame(width: 24)
                            Text("Live Activity")
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .tint(.success)
                    .onChange(of: liveActivityEnabled) { _, newValue in
                        if !newValue {
                            // End any running Live Activity when disabled
                            LiveActivityManager.shared.endActivity()
                        }
                    }
                } header: {
                    Text("Live Activity")
                } footer: {
                    Text("Show running timer in the Dynamic Island and on your Lock Screen.")
                }
                .listRowBackground(Color.bgSecondary)

                // Harvest Account section (consolidated)
                Section {
                    // Logged in as (shows name and email)
                    HStack {
                        Image(systemName: "leaf.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authViewModel.currentUserName ?? "—")
                                .foregroundColor(.textPrimary)
                            if let email = authViewModel.currentUserEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        Spacer()
                    }

                    // Last Updated
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.accent)
                            .frame(width: 24)
                        Text("Last Updated")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(lastUpdatedText)
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }

                    // Refresh Data button
                    Button {
                        Task {
                            await viewModel.refreshHarvestData()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.accent)
                                .frame(width: 24)
                            Text("Refresh Data")
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if viewModel.isRefreshingHarvest {
                                ProgressView()
                                    .tint(.accent)
                            }
                        }
                    }
                    .disabled(viewModel.isRefreshingHarvest)

                    // Open Harvest link
                    Button {
                        if let url = URL(string: "https://harvestapp.com") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.accent)
                                .frame(width: 24)
                            Text("Open Harvest")
                                .foregroundColor(.textPrimary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Harvest Account")
                }
                .listRowBackground(Color.bgSecondary)

                // Pending Events Warning (only shown if there are pending events)
                if viewModel.pendingEvents > 0 {
                    Section {
                        Button {
                            Task {
                                await viewModel.retryPendingEvents()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.warning)
                                Text("\(viewModel.pendingEvents) event\(viewModel.pendingEvents == 1 ? "" : "s") pending")
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.accent)
                                } else {
                                    Text("Retry")
                                        .foregroundColor(.accent)
                                }
                            }
                        }
                        .disabled(viewModel.isLoading)
                    } footer: {
                        Text("These events couldn't be synced. Tap to retry.")
                    }
                    .listRowBackground(Color.warning.opacity(0.15))
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(appVersionString)
                            .foregroundColor(.textSecondary)
                    }

                    #if DEBUG
                    NavigationLink {
                        GeofenceDebugView()
                    } label: {
                        HStack {
                            Image(systemName: "ant.fill")
                                .foregroundColor(.accent)
                                .frame(width: 24)
                            Text("Geofence Logs")
                                .foregroundColor(.textPrimary)
                        }
                    }
                    #endif
                }
                .listRowBackground(Color.bgSecondary)

                // Logout section
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Color.bgSecondary)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle("Settings")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.refresh()
            }
            .alert("Log Out?", isPresented: $showLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    Task {
                        await authViewModel.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var lastUpdatedText: String {
        if let date = viewModel.lastHarvestUpdateDate {
            return DateFormatters.relative.localizedString(for: date, relativeTo: Date())
        }
        return "Never"
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
