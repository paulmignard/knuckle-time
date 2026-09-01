import Foundation

enum DateFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601WithoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // For dates without timezone (e.g., "2026-01-31T10:29:45.012935")
    static let iso8601NoTimezone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let iso8601NoTimezoneNoFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    static let dayHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static func formatTime(_ date: Date) -> String {
        timeOnly.string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        dateOnly.string(from: date)
    }

    static func formatDuration(_ hours: Double) -> String {
        let totalMinutes = Int(round(hours * 60))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h):\(String(format: "%02d", m))"
    }

    static func formatTimer(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func isYesterday(_ date: Date) -> Bool {
        Calendar.current.isDateInYesterday(date)
    }

    static func sectionHeader(for date: Date) -> String {
        if isToday(date) {
            return "Today"
        } else if isYesterday(date) {
            return "Yesterday"
        } else {
            return dayHeader.string(from: date)
        }
    }
}

extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with timezone and fractional seconds
            if let date = DateFormatters.iso8601.date(from: dateString) {
                return date
            }
            // Try ISO8601 with timezone, no fractional seconds
            if let date = DateFormatters.iso8601WithoutFractional.date(from: dateString) {
                return date
            }
            // Try without timezone (server default format)
            if let date = DateFormatters.iso8601NoTimezone.date(from: dateString) {
                return date
            }
            // Try without timezone and without fractional seconds
            if let date = DateFormatters.iso8601NoTimezoneNoFractional.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let apiEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
