//
//  SharedStorage.swift
//  PluginReporter
//
//  Provides shared storage location for plugins.json
//  Easy migration path to iCloud later
//

import Foundation

public enum SharedStorage {

    /// Returns the shared plugins.json URL
    /// Currently uses a local directory, but can easily switch to iCloud Container
    public static var pluginsURL: URL? {
        #if os(macOS)
        // macOS: Save to Application Support
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = appSupport.appendingPathComponent("PluginReporter", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        return appDir.appendingPathComponent("plugins.json")

        #else
        // iOS/iPadOS
        #if targetEnvironment(simulator)
        // Simulator: Read directly from Mac's REAL Application Support (not simulator's sandbox!)
        // The Mac app saves to: ~/Library/Application Support/PluginReporter/plugins.json
        // Extract username from simulator's home directory
        // Format: /Users/username/Library/Developer/CoreSimulator/.../
        let homeDir = NSHomeDirectory()
        let components = homeDir.split(separator: "/")

        // Get username (should be at index 1: /Users/username/...)
        guard components.count >= 2, components[0] == "Users" else {
            return nil
        }

        let username = String(components[1])
        let realAppSupport = "/Users/\(username)/Library/Application Support/PluginReporter"
        let appSupportURL = URL(fileURLWithPath: realAppSupport)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)

        return appSupportURL.appendingPathComponent("plugins.json")
        #else
        // Real device: Use Documents (later will be iCloud)
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent("plugins.json")
        #endif
        #endif
    }

    /// Load plugins from shared storage
    public static func loadPlugins() throws -> [PluginItem] {
        AppLogger.info("SharedStorage.loadPlugins() called")

        guard let url = pluginsURL else {
            AppLogger.error("Could not get plugins URL")
            return []
        }

        AppLogger.info("Plugins URL: \(url.path)")

        let exists = FileManager.default.fileExists(atPath: url.path)
        AppLogger.info("File exists: \(exists)")

        guard exists else {
            AppLogger.info("No plugins file at \(url.path)")
            return [] // No plugins yet
        }

        AppLogger.info("Loading plugins from: \(url.path)")
        let data = try Data(contentsOf: url)
        AppLogger.info("Read \(data.count) bytes")

        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            AppLogger.error("Invalid JSON format")
            throw StorageError.invalidFormat
        }

        AppLogger.info("Found \(jsonArray.count) items in JSON")

        let plugins = jsonArray.compactMap { dict -> PluginItem? in
            guard let name = dict["Name"] as? String,
                  let type = dict["Type"] as? String else {
                return nil
            }

            let dateInterval = dict["Date"] as? Double ?? 0
            let date = dateInterval > 0 ? Date(timeIntervalSince1970: dateInterval) : nil

            return PluginItem(
                name: name,
                publisher: dict["Publisher"] as? String ?? "",
                version: dict["Version"] as? String ?? "",
                type: type,
                style: dict["Style"] as? String ?? "",
                architectures: dict["Architectures"] as? String ?? "",
                date: date,
                sizeBytes: Int64(dict["SizeBytes"] as? Int ?? 0),
                path: dict["Path"] as? String ?? "",
                runtimeRequirement: dict["Requirement"] as? String ?? "",
                obsolete: dict["Obsolete"] as? Bool ?? false
            )
        }

        AppLogger.info("Successfully parsed \(plugins.count) plugins")
        return plugins
    }

    /// Save plugins to shared storage
    public static func savePlugins(_ plugins: [PluginItem]) throws {
        guard let url = pluginsURL else {
            throw StorageError.notFound
        }
        JSONExporter.export(rows: plugins, to: url)
    }

    public enum StorageError: Error {
        case invalidFormat
        case notFound
    }
}

// MARK: - iCloud Migration Notes
/*
 To migrate to iCloud later:

 1. Enable iCloud capability in Xcode (requires Apple Developer account)
 2. Add iCloud Container (e.g., "iCloud.com.pluginreporter")
 3. Update pluginsURL to use:
    FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents/plugins.json")
 4. Add NSUbiquitousContainers to Info.plist
 5. Monitor for iCloud changes with NSMetadataQuery

 No other code changes needed! All access goes through SharedStorage.
 */
