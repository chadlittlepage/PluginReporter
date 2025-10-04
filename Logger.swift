//
//  Logger.swift
//  Plugin Reporter
//
//  Unified logging system with categorization and privacy controls
//

import Foundation
import os.log

/// Centralized logging system for Plugin Reporter
///
/// Provides categorized, privacy-aware logging that can be filtered in Console.app
/// and disabled in production builds for performance.
///
/// Usage:
/// ```swift
/// AppLogger.app.info("Application launched")
/// AppLogger.export.error("Failed to export: \(error.localizedDescription)")
/// AppLogger.network.debug("API request: \(url)")
/// ```
enum AppLogger {

    // MARK: - Log Categories

    /// General application events
    static let app = Logger(subsystem: subsystem, category: "app")

    /// File operations and scanning
    static let scanner = Logger(subsystem: subsystem, category: "scanner")

    /// Export operations (CSV, PDF, JSON)
    static let export = Logger(subsystem: subsystem, category: "export")

    /// Network requests (OpenAI API)
    static let network = Logger(subsystem: subsystem, category: "network")

    /// CloudKit sync operations
    static let sync = Logger(subsystem: subsystem, category: "sync")

    /// UI events and interactions
    static let ui = Logger(subsystem: subsystem, category: "ui")

    // MARK: - Configuration

    private static let subsystem = "com.pluginreporter.app"

    #if DEBUG
    /// Enable all log levels in debug builds
    static let isLoggingEnabled = true
    #else
    /// Disable debug/info logs in release builds for performance
    static let isLoggingEnabled = false
    #endif
}

// MARK: - Convenience Extensions

extension Logger {
    /// Logs a debug message (disabled in production)
    func debug(_ message: String) {
        #if DEBUG
        self.debug("\(message)")
        #endif
    }

    /// Logs an info message (disabled in production)
    func info(_ message: String) {
        #if DEBUG
        self.info("\(message)")
        #endif
    }

    /// Logs a warning message (always enabled)
    func warning(_ message: String) {
        self.warning("\(message)")
    }

    /// Logs an error message (always enabled)
    func error(_ message: String) {
        self.error("\(message)")
    }

    /// Logs a fault/critical error (always enabled)
    func critical(_ message: String) {
        self.fault("\(message)")
    }
}

// MARK: - Privacy Helpers

extension Logger {
    /// Logs a message with a redacted value for privacy
    /// Use this for sensitive data like file paths or user info
    func privateInfo(_ message: String, private value: String) {
        self.info("\(message): \(value, privacy: .private)")
    }

    /// Logs a message with a public value
    /// Use this for non-sensitive data like counts or types
    func publicInfo(_ message: String, public value: String) {
        self.info("\(message): \(value, privacy: .public)")
    }
}
