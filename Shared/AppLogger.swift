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

    // MARK: - Enhanced Debug Logging (Temporary Troubleshooting)

    static func logSection(_ title: String) {
        let divider = String(repeating: "=", count: 60)
        let message = "\n\(divider)\n  \(title)\n\(divider)"
        print(message)
        logger.info("\(title)")
    }

    static func logPluginLoad(source: String, count: Int, fileSize: Double? = nil) {
        let message: String
        if let size = fileSize {
            message = "📦 [LOAD] \(source): \(count) plugins (\(String(format: "%.2f", size)) MB)"
        } else {
            message = "📦 [LOAD] \(source): \(count) plugins"
        }
        print(message)
        logger.info("\(message)")
    }

    static func logPluginSave(destination: String, count: Int, fileSize: Double) {
        let message = "💾 [SAVE] \(destination): \(count) plugins (\(String(format: "%.2f", fileSize)) MB)"
        print(message)
        logger.info("\(message)")
    }

    static func logTableUpdate(source: String, totalRows: Int, displayedRows: Int, sortKey: String, ascending: Bool) {
        let direction = ascending ? "↑" : "↓"
        let message = "📊 [TABLE] \(source): \(displayedRows) of \(totalRows) rows | Sort: \(sortKey) \(direction)"
        print(message)
        logger.info("\(message)")
    }

    static func logFilterApplied(searchText: String, formats: Set<String>, publishers: Set<String>, resultCount: Int, totalCount: Int) {
        let formatStr = formats.isEmpty ? "All" : formats.joined(separator: ", ")
        let pubStr = publishers.isEmpty ? "All" : "\(publishers.count) selected"
        let message = "🔎 [FILTER] Search: '\(searchText)' | Formats: \(formatStr) | Publishers: \(pubStr) | Results: \(resultCount)/\(totalCount)"
        print(message)
        logger.info("\(message)")
    }
}
