//
//  KnuckleTimerWidget.swift
//  KnuckleTimerActivity
//
//  Home screen widget showing current tracking status.
//  State is pushed from the main app via TimerWidgetState (App Group).
//

import WidgetKit
import SwiftUI

// MARK: - Helper Functions

/// Format hours as "H:MM" (e.g., 1.75 → "1:45")
private func formatHours(_ hours: Double) -> String {
    let totalMinutes = Int(hours * 60)
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    return "\(h):\(String(format: "%02d", m))"
}

// MARK: - Pill Colors (mirrors Live Activity styling)

private enum WidgetPillColors {
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let greenBg = Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.2)

    static let grayDot = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let grayText = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let grayBg = Color.gray.opacity(0.15)

    static let red = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let redBg = Color(red: 1.0, green: 0.27, blue: 0.23).opacity(0.2)
}

// MARK: - Timeline

struct TimerWidgetEntry: TimelineEntry {
    let date: Date
    let state: TimerWidgetState
}

struct TimerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerWidgetEntry {
        TimerWidgetEntry(
            date: Date(),
            state: TimerWidgetState(
                isTracking: true,
                clientName: "Project - Task",
                geofenceName: "Office",
                startedAt: Date().addingTimeInterval(-45 * 60),
                todayHoursBase: 2.5,
                weekHoursBase: 14.25
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerWidgetEntry) -> Void) {
        completion(TimerWidgetEntry(date: Date(), state: TimerWidgetState.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerWidgetEntry>) -> Void) {
        var state = TimerWidgetState.load()
        let now = Date()
        let calendar = Calendar.current

        // Roll over stale hour totals: bases written on a previous day (or in
        // a previous week) no longer apply to "Today" / "This Week"
        if !state.isTracking, !calendar.isDateInToday(state.updatedAt) {
            state.todayHoursBase = 0
            if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(state.updatedAt) != true {
                state.weekHoursBase = 0
            }
        }

        if state.isTracking {
            // Periodic entries keep the hour totals fresh while tracking;
            // the elapsed timer itself ticks natively via Text(timerInterval:)
            let entries = stride(from: 0, through: 60, by: 15).map { minutes in
                TimerWidgetEntry(date: now.addingTimeInterval(Double(minutes) * 60), state: state)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        } else {
            // Idle: the app pushes a reload on every state change, so this
            // refresh is just a fallback. Include a midnight entry so "Today"
            // zeroes even if no reload happens overnight.
            var entries = [TimerWidgetEntry(date: now, state: state)]
            if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                var rolled = state
                rolled.todayHoursBase = 0
                entries.append(TimerWidgetEntry(date: midnight, state: rolled))
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
        }
    }
}

// MARK: - Views

private struct StatusPill: View {
    let state: TimerWidgetState

    private var dotColor: Color {
        switch state.pillState {
        case .geofence: return WidgetPillColors.green
        case .idle, .manual: return WidgetPillColors.grayDot
        case .needsPermission: return WidgetPillColors.red
        }
    }

    private var textColor: Color {
        switch state.pillState {
        case .geofence: return WidgetPillColors.green
        case .idle, .manual: return WidgetPillColors.grayText
        case .needsPermission: return WidgetPillColors.red
        }
    }

    private var bgColor: Color {
        switch state.pillState {
        case .geofence: return WidgetPillColors.greenBg
        case .idle, .manual: return WidgetPillColors.grayBg
        case .needsPermission: return WidgetPillColors.redBg
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(state.pillText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(bgColor)
        .clipShape(Capsule())
    }
}

private struct HoursStat: View {
    let label: String
    let hours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(formatHours(hours))
                .font(.headline)
                .monospacedDigit()
        }
    }
}

struct KnuckleTimerWidgetView: View {
    var entry: TimerWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var state: TimerWidgetState { entry.state }

    /// Hours including the running timer's elapsed time as of this entry
    private var currentTodayHours: Double {
        guard state.isTracking, let startedAt = state.startedAt else { return state.todayHoursBase }
        return state.todayHoursBase + entry.date.timeIntervalSince(startedAt) / 3600
    }

    private var currentWeekHours: Double {
        guard state.isTracking, let startedAt = state.startedAt else { return state.weekHoursBase }
        return state.weekHoursBase + entry.date.timeIntervalSince(startedAt) / 3600
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("👊")
                    .font(.title3)
                StatusPill(state: state)
            }

            Spacer(minLength: 0)

            if state.isTracking, let startedAt = state.startedAt {
                Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(WidgetPillColors.green)

                Text(state.clientName ?? "Tracking")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("Not Tracking")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Today: \(formatHours(currentTodayHours))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("👊")
                        .font(.title3)
                    StatusPill(state: state)
                }

                Spacer(minLength: 0)

                if state.isTracking, let startedAt = state.startedAt {
                    Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                        .font(.title)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundColor(WidgetPillColors.green)

                    Text(state.clientName ?? "Tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Not Tracking")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                HoursStat(label: "Today", hours: currentTodayHours)
                HoursStat(label: "This Week", hours: currentWeekHours)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct KnuckleTimerWidget: Widget {
    let kind: String = "KnuckleTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerWidgetProvider()) { entry in
            KnuckleTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Knuckle Timer")
        .description("See when Knuckle is tracking time and your hours for today and this week.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    KnuckleTimerWidget()
} timeline: {
    TimerWidgetEntry(
        date: .now,
        state: TimerWidgetState(
            isTracking: true,
            clientName: "Acme Co - Development",
            geofenceName: "Office",
            startedAt: .now.addingTimeInterval(-45 * 60),
            todayHoursBase: 2.5,
            weekHoursBase: 14.25
        )
    )
    TimerWidgetEntry(date: .now, state: TimerWidgetState(isTracking: false, todayHoursBase: 5.25, weekHoursBase: 17))
}
