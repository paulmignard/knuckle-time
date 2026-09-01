//
//  KnuckleTimerActivityLiveActivity.swift
//  KnuckleTimerActivity
//
//  Created by Paul Mignard on 1/31/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// KnuckleTimerActivityAttributes is defined in Shared/KnuckleTimerActivityAttributes.swift
// That file must have Target Membership in BOTH the main app and widget extension

// MARK: - Helper Functions

/// Format hours as "H:MM" (e.g., 1.75 → "1:45")
private func formatHours(_ hours: Double) -> String {
    let totalMinutes = Int(hours * 60)
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    return "\(h):\(String(format: "%02d", m))"
}

/// Calculate the current total hours (base + elapsed since timer start)
private func calculateCurrentHours(base baseHours: Double, timerStart: Date) -> Double {
    let elapsedHours = Date().timeIntervalSince(timerStart) / 3600
    return baseHours + elapsedHours
}

// MARK: - Live Activity Pill Colors

private enum LiveActivityPillColors {
    // Green - inside geofence
    static let greenDot = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let greenText = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let greenBg = Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.2)
    static let greenBorder = Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.3)

    // Gray - manual tracking
    static let grayDot = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let grayText = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let grayBg = Color.white.opacity(0.1)

    // Red - needs permission
    static let redDot = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let redText = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let redBg = Color(red: 1.0, green: 0.27, blue: 0.23).opacity(0.2)
    static let redBorder = Color(red: 1.0, green: 0.27, blue: 0.23).opacity(0.3)
}

// MARK: - Live Activity Widget

@available(iOS 16.2, *)
struct KnuckleTimerActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KnuckleTimerActivityAttributes.self) { context in
            // Lock screen/banner UI (expanded widget)
            let pillState = context.attributes.pillState
            let pillText = context.attributes.pillText

            // Pill colors based on state
            let dotColor: Color = {
                switch pillState {
                case .geofence: return LiveActivityPillColors.greenDot
                case .manual: return LiveActivityPillColors.grayDot
                case .needsPermission: return LiveActivityPillColors.redDot
                }
            }()
            let pillTextColor: Color = {
                switch pillState {
                case .geofence: return LiveActivityPillColors.greenText
                case .manual: return LiveActivityPillColors.grayText
                case .needsPermission: return LiveActivityPillColors.redText
                }
            }()
            let pillBgColor: Color = {
                switch pillState {
                case .geofence: return LiveActivityPillColors.greenBg
                case .manual: return LiveActivityPillColors.grayBg
                case .needsPermission: return LiveActivityPillColors.redBg
                }
            }()
            let pillBorderColor: Color = {
                switch pillState {
                case .geofence: return LiveActivityPillColors.greenBorder
                case .manual: return Color.clear
                case .needsPermission: return LiveActivityPillColors.redBorder
                }
            }()

            HStack(spacing: 0) {
                // Left side: Logo, timer, project/task
                VStack(alignment: .leading, spacing: 8) {
                    // Header with logo and geofence status pill
                    HStack(spacing: 6) {
                        Text("👊")
                            .font(.title3)

                        // Status pill - shows geofence name, "Manual", or "Needs Permission"
                        HStack(spacing: 4) {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 6, height: 6)
                            Text(pillText)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(pillTextColor)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(pillBgColor)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(pillBorderColor, lineWidth: 1)
                        )
                    }

                    // Timer display
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .monospacedDigit()

                    // Project → Task
                    if let taskName = context.attributes.taskName {
                        Text("\(context.attributes.projectName) → \(taskName)")
                            .font(.subheadline)
                            .foregroundColor(.green.opacity(0.7))
                            .lineLimit(1)
                    } else {
                        Text(context.attributes.projectName)
                            .font(.subheadline)
                            .foregroundColor(.green.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Right side: Today + Weekly totals (H:MM format, no seconds)
                VStack(alignment: .center, spacing: 6) {
                    // Today total
                    VStack(spacing: 1) {
                        Text(formatHours(calculateCurrentHours(base: context.state.todayHoursBase, timerStart: context.attributes.startedAt)))
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("today")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Weekly total
                    VStack(spacing: 1) {
                        Text(formatHours(calculateCurrentHours(base: context.state.weekHoursBase, timerStart: context.attributes.startedAt)))
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("this week")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(width: 75)
                .padding(.leading, 8)
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.08, green: 0.16, blue: 0.10))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text("👊")
                            .font(.title3)
                        Text(context.attributes.projectName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .monospacedDigit()
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Text("👊")
                    Text(context.attributes.geofenceName ?? context.attributes.projectName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .font(.caption)
                .padding(.leading, 4)
            } compactTrailing: {
                
                Text(context.attributes.startedAt, style: .timer)
                    .lineLimit(1)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                   
           
                
                
            } minimal: {
                // Minimal - fist emoji
                Text("👊")
            }
            .widgetURL(URL(string: "knuckle://timer"))
            .keylineTint(Color.green)
        }
    }
}

// MARK: - Previews

@available(iOS 16.1, *)
extension KnuckleTimerActivityAttributes {
    fileprivate static var preview: KnuckleTimerActivityAttributes {
        KnuckleTimerActivityAttributes(
            clientName: "Acme Development - Feature Development",
            startedAt: Date().addingTimeInterval(-6723), // ~1:52 ago
            geofenceName: "Office",  // Shows green pill with "Office"
            needsLocationPermission: false
        )
    }
}

@available(iOS 16.1, *)
extension KnuckleTimerActivityAttributes.ContentState {
    fileprivate static var running: KnuckleTimerActivityAttributes.ContentState {
        // Base hours = hours tracked BEFORE current timer (so timer adds to these)
        KnuckleTimerActivityAttributes.ContentState(placeholder: false, todayHoursBase: 0.25, weekHoursBase: 22.5)
    }
}

@available(iOS 16.2, *)
#Preview("Notification", as: .content, using: KnuckleTimerActivityAttributes.preview) {
    KnuckleTimerActivityLiveActivity()
} contentStates: {
    KnuckleTimerActivityAttributes.ContentState.running
}
