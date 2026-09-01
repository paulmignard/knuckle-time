import SwiftUI

struct EntriesListView: View {
    @StateObject private var viewModel = EntriesViewModel()
    @State private var showNewEntry = false
    @State private var showClientFilter = false
    @State private var showDateFilter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Project filter
                        FilterPill(
                            title: selectedProjectName,
                            isActive: viewModel.selectedProjectId != nil
                        ) {
                            showClientFilter = true
                        }

                        // Date filter
                        FilterPill(
                            title: viewModel.dateFilter.rawValue,
                            isActive: true
                        ) {
                            showDateFilter = true
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color.bgSecondary)

                // Entries list
                if viewModel.groupedEntries.isEmpty && !viewModel.isLoading {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.textMuted)
                        Text("No entries found")
                            .font(.headline)
                            .foregroundColor(.textSecondary)
                        Text("Time entries will appear here once you start tracking")
                            .font(.subheadline)
                            .foregroundColor(.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button {
                            showNewEntry = true
                        } label: {
                            Text("Add Entry")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accent)
                                .cornerRadius(20)
                        }
                        .padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(viewModel.groupedEntries, id: \.date) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                                        EntryRowView(entry: entry)
                                    }
                                    .listRowBackground(Color.bgSecondary)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteEntry(entry)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(DateFormatters.sectionHeader(for: group.date))
                                    .font(.caption)
                                    .foregroundColor(.textTertiary)
                            }
                        }

                        // Footer explaining we only show uninvoiced entries
                        if !viewModel.groupedEntries.isEmpty {
                            Section {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 4) {
                                        Image(systemName: "info.circle")
                                            .font(.caption)
                                        Text("Knuckle only shows uninvoiced time entries")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.textMuted)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.bgPrimary)
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("Entries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showNewEntry) {
                EntryFormView()
                    .onDisappear {
                        Task { await viewModel.refresh() }
                    }
            }
            .sheet(isPresented: $showClientFilter) {
                ProjectFilterSheet(
                    projects: viewModel.projects,
                    selectedProjectId: $viewModel.selectedProjectId
                )
                .onDisappear {
                    Task { await viewModel.refresh() }
                }
            }
            .sheet(isPresented: $showDateFilter) {
                DateFilterSheet(selected: $viewModel.dateFilter)
                    .onDisappear {
                        Task { await viewModel.refresh() }
                    }
            }
        }
    }

    private var selectedProjectName: String {
        if let projectId = viewModel.selectedProjectId,
           let project = viewModel.projects.first(where: { $0.id == projectId }) {
            return project.name
        }
        return "All Projects"
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(isActive ? .accent : .textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.bgTertiary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Entry Row

struct EntryRowView: View {
    let entry: TrackedTimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.projectName)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(durationText)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }

            HStack {
                Text(entry.taskName)
                    .font(.caption)
                    .foregroundColor(.textTertiary)

                Spacer()

                if entry.isRunning {
                    Text("Running")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.success.opacity(0.2))
                        .foregroundColor(.success)
                        .cornerRadius(4)
                }

                Text(timeRangeText)
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }

            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var durationText: String {
        return DateFormatters.formatDuration(entry.hours)
    }

    private var timeRangeText: String {
        guard let start = entry.startedTime else {
            return DateFormatters.formatDate(entry.spentDate)
        }
        if let end = entry.endedTime {
            return "\(DateFormatters.formatTime(start)) - \(DateFormatters.formatTime(end))"
        }
        return "\(DateFormatters.formatTime(start)) - now"
    }
}

// MARK: - Project Filter Sheet

struct ProjectFilterSheet: View {
    let projects: [Project]
    @Binding var selectedProjectId: Int64?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedProjectId = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("All Projects")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        if selectedProjectId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accent)
                        }
                    }
                }

                ForEach(projects) { project in
                    Button {
                        selectedProjectId = project.id
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .foregroundColor(.textPrimary)
                                if let clientName = project.clientName {
                                    Text(clientName)
                                        .font(.caption)
                                        .foregroundColor(.textTertiary)
                                }
                            }
                            Spacer()
                            if selectedProjectId == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accent)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle("Filter by Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Date Filter Sheet

struct DateFilterSheet: View {
    @Binding var selected: EntriesViewModel.DateFilter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(EntriesViewModel.DateFilter.allCases, id: \.self) { filter in
                    Button {
                        selected = filter
                        dismiss()
                    } label: {
                        HStack {
                            Text(filter.rawValue)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if selected == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accent)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    EntriesListView()
}
