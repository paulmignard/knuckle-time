//
//  GeofenceLogger.swift
//  Punch
//
//  Persistent logger for geofence events and API calls.
//  Logs to both console and file for post-mortem debugging.
//

import Foundation
import os.log

class GeofenceLogger {
    static let shared = GeofenceLogger()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.knuckle", category: "geofence")
    private let queue = DispatchQueue(label: "com.knuckle.logger", qos: .utility)

    private let logFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("geofence_log.txt")
    }()

    private let maxLogSize: Int = 100_000 // ~100KB, roughly 1000 entries

    private init() {}

    // MARK: - Log Levels

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    // MARK: - Logging

    /// Log a geofence event with timestamp
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        let entry = "[\(timestamp)] [\(level.rawValue)] \(message)"

        // Console log
        switch level {
        case .debug: logger.debug("\(entry)")
        case .info: logger.info("\(entry)")
        case .warning: logger.warning("\(entry)")
        case .error: logger.error("\(entry)")
        }

        // Persist to file (async to not block)
        queue.async { [weak self] in
            self?.appendToFile(entry)
        }
    }

    // MARK: - Convenience Methods

    func logEnter(_ regionId: String, geofenceName: String? = nil) {
        let name = geofenceName ?? regionId
        log("📍 ENTER region: \(name)")
    }

    func logExit(_ regionId: String, geofenceName: String? = nil) {
        let name = geofenceName ?? regionId
        log("📍 EXIT region: \(name)")
    }

    func logAPIStart(_ operation: String) {
        log("🌐 API START: \(operation)")
    }

    func logAPISuccess(_ operation: String, details: String = "") {
        let detailStr = details.isEmpty ? "" : " - \(details)"
        log("✅ API SUCCESS: \(operation)\(detailStr)")
    }

    func logAPIError(_ operation: String, error: Error) {
        // Log only the error type name to avoid leaking server response bodies or sensitive paths
        let sanitized = String(describing: type(of: error))
        log("❌ API ERROR: \(operation) - \(sanitized)", level: .error)
    }

    func logBackgroundTask(_ event: String) {
        log("⏱️ BACKGROUND: \(event)")
    }

    func logRetry(_ operation: String, attempt: Int) {
        log("🔄 RETRY: \(operation) (attempt \(attempt))", level: .warning)
    }

    func logAppState(_ state: String) {
        log("📱 APP: \(state)")
    }

    func logQueue(_ event: String) {
        log("📋 QUEUE: \(event)")
    }

    // MARK: - File Operations

    private func appendToFile(_ entry: String) {
        let line = entry + "\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            // Check size and rotate if needed
            if let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
               let size = attributes[.size] as? Int,
               size > maxLogSize {
                rotateLog()
            }

            // Append to existing file
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            // Create new file
            try? data.write(to: logFileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    private func rotateLog() {
        // Keep last half of log when rotating
        guard let content = try? String(contentsOf: logFileURL) else { return }
        let lines = content.components(separatedBy: "\n")
        let keepLines = Array(lines.suffix(lines.count / 2))
        let newContent = keepLines.joined(separator: "\n")
        try? newContent.data(using: .utf8)?.write(to: logFileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        log("🗂️ Log rotated (kept \(keepLines.count) entries)")
    }

    // MARK: - Read/Clear

    /// Get all logs as string
    func getLogs() -> String {
        (try? String(contentsOf: logFileURL)) ?? "No logs available"
    }

    /// Get logs as array of entries
    func getLogEntries() -> [String] {
        getLogs().components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    /// Get only recent logs (last N entries)
    func getRecentLogs(count: Int = 100) -> String {
        let entries = getLogEntries()
        return entries.suffix(count).joined(separator: "\n")
    }

    /// Clear all logs
    func clearLogs() {
        try? FileManager.default.removeItem(at: logFileURL)
        log("🗑️ Logs cleared")
    }

    /// Get log file URL for sharing
    func getLogFileURL() -> URL {
        logFileURL
    }

    // MARK: - Helpers

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}
