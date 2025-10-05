//
//  AppLogger.swift
//  PluginReporter
//
//  Simple logging utility for the app
//

import Foundation
import os.log

enum AppLogger {
    private static let logger = Logger(subsystem: "com.pluginreporter", category: "general")

    static func export(_ message: String) {
        logger.error("\(message)")
    }

    static func error(_ message: String) {
        logger.error("\(message)")
    }

    static func warning(_ message: String) {
        logger.warning("\(message)")
    }

    static func info(_ message: String) {
        logger.info("\(message)")
    }

    static func debug(_ message: String) {
        logger.debug("\(message)")
    }
}
