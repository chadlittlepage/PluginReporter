//
//  UninstallManager.swift
//  PluginReporter
//
//  Complete plugin uninstall system with:
//  - Move to Trash or Permanent Delete
//  - DAW process checking
//  - Admin privilege escalation
//  - Detailed deletion logging
//

import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - Uninstall Manager

@MainActor
class UninstallManager: ObservableObject {
    static let shared = UninstallManager()

    @Published var isUninstalling = false
    @Published var uninstallProgress: Double = 0.0
    @Published var currentOperation: String = ""

    // Deletion log
    private var deletionLog: [DeletionLogEntry] = []

    struct DeletionLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let pluginName: String
        let pluginPath: String
        let pluginSize: Int64
        let deletionType: DeletionType
        let success: Bool
        let errorMessage: String?
    }

    // CodableLogEntry for UserDefaults storage (no computed id)
    private struct CodableLogEntry: Codable {
        let timestamp: Date
        let pluginName: String
        let pluginPath: String
        let pluginSize: Int64
        let deletionType: DeletionType
        let success: Bool
        let errorMessage: String?
    }

    enum DeletionType: String, Codable {
        case moveToTrash = "Moved to Trash"
        case permanentDelete = "Permanently Deleted"
    }

    enum UninstallError: LocalizedError {
        case fileNotFound(String)
        case permissionDenied(String)
        case fileInUse(String)
        case dawRunning([String])
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path): 
                return "File not found: \(path)"
            case .permissionDenied(let path): 
                return "Permission denied: \(path)\n\nYou may need administrator privileges to delete this file."
            case .fileInUse(let path): 
                return "File is in use: \(path)\n\nClose any applications using this plugin and try again."
            case .dawRunning(let daws): 
                return "Active DAW detected: \(daws.joined(separator: ", "))\n\nPlease close these applications before uninstalling plugins."
            case .unknown(let message): 
                return "Error: \(message)"
            }
        }
    }

    // MARK: - DAW Process Checking

    /// Check if any DAWs are currently running
    func checkForRunningDAWs() -> [String] {
        #if os(macOS)
        let knownDAWs = [
            "Logic Pro", "Logic Pro X", "Ableton Live", "Pro Tools", "Cubase", "Nuendo", "Studio One", "FL Studio", "Reaper", "Digital Performer", "MainStage", "GarageBand", "Bitwig Studio", "Reason", "Live"
        ]

        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        var foundDAWs: [String] = []
        for app in runningApps {
            if let appName = app.localizedName {
                for daw in knownDAWs {
                    if appName.contains(daw) {
                        foundDAWs.append(appName)
                        break
                    }
                }
            }
        }

        return foundDAWs
        #else
        return []
        #endif
    }

    // MARK: - Uninstall Operations

    /// Uninstall plugins with the specified deletion type
    func uninstallPlugins(
        _ plugins: [PluginItem], deletionType: DeletionType, checkDAWs: Bool = true, onProgress: ((String, Double) -> Void)? = nil
    ) async throws -> UninstallResult {

        // Check for running DAWs first
        if checkDAWs {
            let runningDAWs = checkForRunningDAWs()
            if !runningDAWs.isEmpty {
                throw UninstallError.dawRunning(runningDAWs)
            }
        }

        isUninstalling = true
        var successCount = 0
        var failedPlugins: [(PluginItem, Error)] = []

        for (index, plugin) in plugins.enumerated() {
            let progress = Double(index) / Double(plugins.count)
            currentOperation = "Deleting \(plugin.name)..."
            uninstallProgress = progress
            onProgress?(currentOperation, progress)

            do {
                try await uninstallSinglePlugin(plugin, deletionType: deletionType)
                successCount += 1

                // Log success
                logDeletion(
                    plugin: plugin, deletionType: deletionType, success: true, error: nil
                )
            } catch {
                failedPlugins.append((plugin, error))

                // Log failure
                logDeletion(
                    plugin: plugin, deletionType: deletionType, success: false, error: error.localizedDescription
                )
            }
        }

        isUninstalling = false
        uninstallProgress = 1.0
        currentOperation = "Complete"

        // Save deletion log
        saveDeletionLog()

        return UninstallResult(
            totalPlugins: plugins.count, successCount: successCount, failedPlugins: failedPlugins
        )
    }

    /// Uninstall a single plugin
    private func uninstallSinglePlugin(
        _ plugin: PluginItem, deletionType: DeletionType
    ) async throws {

        let fileManager = FileManager.default
        let filePath = plugin.path

        // Check if file exists
        guard fileManager.fileExists(atPath: filePath) else {
            throw UninstallError.fileNotFound(filePath)
        }

        // Try to delete
        do {
            switch deletionType {
            case .moveToTrash: 
                try await moveToTrash(path: filePath)

            case .permanentDelete: 
                try await permanentlyDelete(path: filePath)
            }
        } catch let error as NSError {
            // Handle specific errors
            if error.domain == NSCocoaErrorDomain {
                if error.code == NSFileWriteNoPermissionError || error.code == NSFileReadNoPermissionError {
                    // Try with admin privileges
                    try await deleteWithAdminPrivileges(path: filePath, deletionType: deletionType)
                } else if error.code == NSFileWriteFileExistsError {
                    throw UninstallError.fileInUse(filePath)
                } else {
                    throw UninstallError.unknown(error.localizedDescription)
                }
            } else {
                throw error
            }
        }
    }

    /// Move file to trash (safe, recoverable)
    private func moveToTrash(path: String) async throws {
        #if os(macOS)
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        var resultingURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)

        print("✅ Moved to trash: \(path)")
        #endif
    }

    /// Permanently delete file (irreversible)
    private func permanentlyDelete(path: String) async throws {
        let fileManager = FileManager.default
        try fileManager.removeItem(atPath: path)

        print("🗑️ Permanently deleted: \(path)")
    }

    /// Delete file with admin privileges using AppleScript
    private func deleteWithAdminPrivileges(
        path: String, deletionType: DeletionType
    ) async throws {
        #if os(macOS)

        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")

        let script: String
        if deletionType == .moveToTrash {
            // Move to trash with admin privileges
            script = """
            do shell script "osascript -e 'tell application \\"Finder\\" to delete POSIX file \\"\(escapedPath)\\"'" with administrator privileges
            """
        } else {
            // Permanently delete with admin privileges
            script = """
            do shell script "rm -rf \\"\(escapedPath)\\"" with administrator privileges
            """
        }

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)

            if error != nil {
                throw UninstallError.permissionDenied(path)
            }

            print("✅ Deleted with admin privileges: \(path)")
        } else {
            throw UninstallError.permissionDenied(path)
        }
        #endif
    }

    // MARK: - Deletion Logging

    private func logDeletion(
        plugin: PluginItem, deletionType: DeletionType, success: Bool, error: String?
    ) {
        let entry = DeletionLogEntry(
            timestamp: Date(), pluginName: plugin.name, pluginPath: plugin.path, pluginSize: plugin.sizeBytes, deletionType: deletionType, success: success, errorMessage: error
        )

        deletionLog.append(entry)

        // Keep only last 1000 entries
        if deletionLog.count > 1000 {
            deletionLog.removeFirst(deletionLog.count - 1000)
        }
    }

    private func saveDeletionLog() {
        let codableEntries = deletionLog.map { entry in
            CodableLogEntry(
                timestamp: entry.timestamp, pluginName: entry.pluginName, pluginPath: entry.pluginPath, pluginSize: entry.pluginSize, deletionType: entry.deletionType, success: entry.success, errorMessage: entry.errorMessage
            )
        }
        guard let encoded = try? JSONEncoder().encode(codableEntries) else { return }
        UserDefaults.standard.set(encoded, forKey: "deletion_log")
        print("📝 Saved deletion log: \(deletionLog.count) entries")
    }

    func loadDeletionLog() {
        guard let data = UserDefaults.standard.data(forKey: "deletion_log"), let codableEntries = try? JSONDecoder().decode([CodableLogEntry].self, from: data) else {
            return
        }
        deletionLog = codableEntries.map { entry in
            DeletionLogEntry(
                timestamp: entry.timestamp, pluginName: entry.pluginName, pluginPath: entry.pluginPath, pluginSize: entry.pluginSize, deletionType: entry.deletionType, success: entry.success, errorMessage: entry.errorMessage
            )
        }
        print("📝 Loaded deletion log: \(deletionLog.count) entries")
    }

    func getDeletionLog() -> [DeletionLogEntry] {
        return deletionLog
    }

    func exportDeletionLog() -> String {
        var output = "Plugin Deletion Log\n"
        output += "===================\n\n"

        for entry in deletionLog.reversed() {
            output += "[\(entry.timestamp)] \(entry.success ? "✅" : "❌") \(entry.deletionType.rawValue)\n"
            output += "  Plugin: \(entry.pluginName)\n"
            output += "  Path: \(entry.pluginPath)\n"
            output += "  Size: \(ByteCountFormatter.string(fromByteCount: entry.pluginSize, countStyle: .file))\n"
            if let error = entry.errorMessage {
                output += "  Error: \(error)\n"
            }
            output += "\n"
        }

        return output
    }

    // MARK: - Batch Operations

    /// Calculate total size of plugins to be deleted
    func calculateTotalSize(_ plugins: [PluginItem]) -> String {
        let totalBytes = plugins.reduce(0) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

// MARK: - Uninstall Result

struct UninstallResult {
    let totalPlugins: Int
    let successCount: Int
    let failedPlugins: [(PluginItem, Error)]

    var failedCount: Int {
        failedPlugins.count
    }

    var allSucceeded: Bool {
        failedCount == 0
    }

    var summary: String {
        if allSucceeded {
            return "Successfully uninstalled \(successCount) plugin\(successCount == 1 ? "" : "s")"
        } else {
            return "Uninstalled \(successCount) of \(totalPlugins) plugins (\(failedCount) failed)"
        }
    }
}