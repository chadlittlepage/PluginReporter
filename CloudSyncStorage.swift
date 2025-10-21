//
//  CloudSyncStorage.swift
//  PluginReporter
//
//  Provides automatic iCloud sync for ratings, tags, notes, and metadata
//  Falls back to UserDefaults if iCloud is not available
//

import Foundation

/// Provides transparent storage with iCloud sync when available
class CloudSyncStorage {

    static let shared = CloudSyncStorage()

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let localStore = UserDefaults.standard

    // Track whether iCloud is available
    private var isCloudAvailable: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    private init() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudUpdate),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )

        // Sync from cloud if available
        if isCloudAvailable {
            ubiquitousStore.synchronize()
            print("☁️ iCloud Key-Value Store available and syncing")
        } else {
            print("💾 Using local storage only (iCloud not available)")
        }
    }

    @objc private func handleCloudUpdate(_ notification: Notification) {
        // When iCloud data changes, notification will trigger
        // ObservableObjects will automatically update their @Published properties
        print("☁️ iCloud data updated externally")

        // Post notification for managers to reload if needed
        NotificationCenter.default.post(name: .cloudDataDidChange, object: nil)
    }

    // MARK: - Storage Methods

    /// Save data - automatically syncs to iCloud if available
    func setData(_ data: Data?, forKey key: String) {
        if isCloudAvailable {
            let cloudStart = Date()
            if let data = data {
                ubiquitousStore.set(data, forKey: key)
                // Removed synchronize() - system automatically syncs in background
                // This prevents blocking the main thread waiting for network I/O
                let cloudTime = Date().timeIntervalSince(cloudStart)
                print("☁️ Queued for iCloud sync: \(key) (\(cloudTime)s)")
            } else {
                ubiquitousStore.removeObject(forKey: key)
                // Removed synchronize() - system handles automatic sync
            }
        }

        // Always save to local as backup
        let localStart = Date()
        localStore.set(data, forKey: key)
        let localTime = Date().timeIntervalSince(localStart)
        print("💾 UserDefaults write: \(key) (\(localTime)s)")
    }

    /// Load data - prefers iCloud if available, falls back to local
    func getData(forKey key: String) -> Data? {
        if isCloudAvailable {
            if let cloudData = ubiquitousStore.data(forKey: key) {
                // Sync cloud data to local backup
                localStore.set(cloudData, forKey: key)
                return cloudData
            }
        }

        // Fall back to local data
        return localStore.data(forKey: key)
    }

    /// Remove data from both stores
    func removeData(forKey key: String) {
        if isCloudAvailable {
            ubiquitousStore.removeObject(forKey: key)
            // Removed synchronize() - system handles automatic sync
        }
        localStore.removeObject(forKey: key)
    }

    /// Force synchronization with iCloud
    /// NOTE: synchronize() is deprecated and may block. System automatically syncs in background.
    /// Only use this if absolutely necessary (e.g., before app termination).
    func forceSynchronize() {
        if isCloudAvailable {
            ubiquitousStore.synchronize()
            print("☁️ Forced iCloud sync (blocking operation)")
        }
    }

    /// Check if cloud sync is enabled
    func isCloudSyncEnabled() -> Bool {
        return isCloudAvailable
    }

    /// Get sync status for display
    func getSyncStatus() -> String {
        if isCloudAvailable {
            return "☁️ Syncing with iCloud"
        } else {
            return "💾 Local storage only"
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let cloudDataDidChange = Notification.Name("cloudDataDidChange")
}
