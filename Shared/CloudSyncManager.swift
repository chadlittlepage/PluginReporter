// CloudSyncManager.swift - iCloud CloudKit Sync
// Add this file to BOTH macOS and iOS targets
import Foundation
import SwiftUI
import Combine
import CloudKit

@MainActor
class CloudSyncManager: ObservableObject {
    @Published var plugins: [PluginItem] = []
    @Published var lastSyncDate: Date?
    @Published var sourceDeviceName: String?
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?

    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "PluginItem"
    private let deviceRecordType = "DeviceInfo"

    init() {
        // Use iCloud container - IMPORTANT: Enable iCloud in Xcode Capabilities before uncommenting entitlements
        // Container ID must match what's configured in Apple Developer Portal
        container = CKContainer(identifier: "iCloud.com.chadlittlepage.PluginReporter")
        database = container.privateCloudDatabase

        // Auto-sync on init
        Task {
            await syncFromCloud()
        }
    }

    // MARK: - Upload Plugins (Mac Only)

    #if os(macOS)
    func uploadPlugins(_ plugins: [PluginItem]) async {
        isSyncing = true
        errorMessage = nil

        do {
            // Get device name
            let deviceName = Host.current().localizedName ?? "Mac"

            // Delete all existing records first
            try await deleteAllRecords()

            // Upload new records in batches
            let batchSize = 100
            for i in stride(from: 0, to: plugins.count, by: batchSize) {
                let batch = Array(plugins[i..<min(i + batchSize, plugins.count)])
                let records = batch.map { createRecord(from: $0) }

                _ = try await database.modifyRecords(saving: records, deleting: [])
            }

            // Save device info
            try await saveDeviceInfo(deviceName: deviceName)

            lastSyncDate = Date()
            sourceDeviceName = deviceName

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            AppLogger.error("CloudKit upload failed: \(error.localizedDescription)")
        }

        isSyncing = false
    }
    #endif

    // MARK: - Download Plugins (iOS & Mac)

    func syncFromCloud() async {
        isSyncing = true
        errorMessage = nil

        do {
            // Fetch device info first
            let deviceInfo = try await fetchDeviceInfo()
            sourceDeviceName = deviceInfo.deviceName
            lastSyncDate = deviceInfo.lastUpdated

            // Fetch all plugin records
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            var allPlugins: [PluginItem] = []
            var cursor: CKQueryOperation.Cursor?

            repeat {
                let (results, nextCursor) = try await fetchRecords(query: query, cursor: cursor)
                allPlugins.append(contentsOf: results)
                cursor = nextCursor
            } while cursor != nil

            plugins = allPlugins
            lastSyncDate = Date()

        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
            AppLogger.error("CloudKit sync failed: \(error.localizedDescription)")
        }

        isSyncing = false
    }

    // MARK: - CloudKit Operations

    private func createRecord(from plugin: PluginItem) -> CKRecord {
        let record = CKRecord(recordType: recordType)
        record["name"] = plugin.name as CKRecordValue
        record["publisher"] = plugin.publisher as CKRecordValue
        record["version"] = plugin.version as CKRecordValue
        record["type"] = plugin.type as CKRecordValue
        record["style"] = plugin.style as CKRecordValue
        record["architectures"] = plugin.architectures as CKRecordValue
        record["date"] = plugin.date as? CKRecordValue
        record["sizeBytes"] = plugin.sizeBytes as CKRecordValue
        record["path"] = plugin.path as CKRecordValue
        record["runtimeRequirement"] = plugin.runtimeRequirement as CKRecordValue
        record["obsolete"] = plugin.obsolete as CKRecordValue
        return record
    }

    private func createPlugin(from record: CKRecord) -> PluginItem? {
        guard let name = record["name"] as? String,
              let publisher = record["publisher"] as? String,
              let version = record["version"] as? String,
              let type = record["type"] as? String,
              let style = record["style"] as? String,
              let architectures = record["architectures"] as? String,
              let sizeBytes = record["sizeBytes"] as? Int,
              let path = record["path"] as? String else {
            return nil
        }

        return PluginItem(
            name: name,
            publisher: publisher,
            version: version,
            type: type,
            style: style,
            architectures: architectures,
            date: record["date"] as? Date,
            sizeBytes: Int64(sizeBytes),
            path: path,
            runtimeRequirement: record["runtimeRequirement"] as? String ?? "",
            obsolete: record["obsolete"] as? Bool ?? false
        )
    }

    private func fetchRecords(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> ([PluginItem], CKQueryOperation.Cursor?) {
        let operation: CKQueryOperation

        if let cursor = cursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            operation = CKQueryOperation(query: query)
        }

        operation.resultsLimit = 100

        var fetchedPlugins: [PluginItem] = []
        var resultCursor: CKQueryOperation.Cursor?

        // Wait for operation to complete
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let plugin = self.createPlugin(from: record) {
                        fetchedPlugins.append(plugin)
                    }
                case .failure(let error):
                    AppLogger.error("CloudKit record fetch failed: \(error.localizedDescription)")
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    resultCursor = cursor
                    continuation.resume()
                case .failure(let error):
                    AppLogger.error("CloudKit query failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }

        return (fetchedPlugins, resultCursor)
    }

    #if os(macOS)
    private func deleteAllRecords() async throws {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let results = try await database.records(matching: query)

        let recordIDs = results.matchResults.compactMap { try? $0.1.get().recordID }

        if !recordIDs.isEmpty {
            _ = try await database.modifyRecords(saving: [], deleting: recordIDs)
        }
    }

    private func saveDeviceInfo(deviceName: String) async throws {
        let record = CKRecord(recordType: deviceRecordType, recordID: CKRecord.ID(recordName: "deviceInfo"))
        record["deviceName"] = deviceName as CKRecordValue
        record["lastUpdated"] = Date() as CKRecordValue

        try await database.save(record)
    }
    #endif

    private func fetchDeviceInfo() async throws -> (deviceName: String, lastUpdated: Date?) {
        let recordID = CKRecord.ID(recordName: "deviceInfo")

        do {
            let record = try await database.record(for: recordID)
            let deviceName = record["deviceName"] as? String ?? "Unknown Mac"
            let lastUpdated = record["lastUpdated"] as? Date
            return (deviceName, lastUpdated)
        } catch {
            // No device info yet
            return ("Unknown Mac", nil)
        }
    }
}
