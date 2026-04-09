// CloudSyncManager.swift - iCloud CloudKit Sync
// Add this file to BOTH macOS and iOS targets
import CloudKit
import Combine
import Foundation
import SwiftUI

@MainActor
class CloudSyncManager: ObservableObject {
    // MARK: - Singleton
    static let shared = CloudSyncManager()

    @Published var plugins: [PluginItem] = []
    @Published var lastSyncDate: Date?
    @Published var sourceDeviceName: String?
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?

    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "PluginItem"
    private let deviceRecordType = "DeviceInfo"
    private var schemaInitialized = false

    private init() {
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

            // Upload new records in batches (CloudKit will update existing records with same ID)
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
            errorMessage = UserFriendlyError.syncMessage(for: error)
            AppLogger.error("CloudKit upload failed: \(UserFriendlyError.technicalDetails(for: error))")
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
            // Check if error is due to missing CloudKit schema
            if isSchemaNotFoundError(error) && !schemaInitialized {
                AppLogger.info("CloudKit schema not found - attempting to initialize...")
                schemaInitialized = true

                // Try to initialize schema in development mode
                await initializeCloudKitSchema()

                // Don't set error message - this is expected on first run
                errorMessage = nil
            } else {
                errorMessage = UserFriendlyError.syncMessage(for: error)
                // Suppress verbose CloudKit schema errors (known issue - recordName field needs to be marked queryable in CloudKit Dashboard)
                let errorDetails = UserFriendlyError.technicalDetails(for: error)
                if !errorDetails.contains("recordName") && !errorDetails.contains("not marked queryable") {
                    AppLogger.error("CloudKit sync failed: \(errorDetails)")
                } else {
                    AppLogger.debug("CloudKit query failed: \(errorDetails)")
                }
            }
        }

        isSyncing = false
    }

    // MARK: - CloudKit Operations

    private func createRecord(from plugin: PluginItem) -> CKRecord {
        // Use plugin path as unique record ID so updates replace old records
        let recordID = CKRecord.ID(recordName: plugin.path.replacingOccurrences(of: "/", with: "_"))
        let record = CKRecord(recordType: recordType, recordID: recordID)
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
        record["customImagePath"] = plugin.customImagePath as? CKRecordValue
        return record
    }

    // Update a single plugin's custom image path in CloudKit
    func updatePluginInCloudKit(_ plugin: PluginItem) async {
        do {
            let record = createRecord(from: plugin)
            _ = try await database.modifyRecords(saving: [record], deleting: [])
            print("✅ Updated plugin in CloudKit: \(plugin.name)")

            // Update local array
            if let index = plugins.firstIndex(where: { $0.id == plugin.id }) {
                plugins[index] = plugin
            }
        } catch {
            print("❌ Failed to update plugin in CloudKit: \(error)")
            errorMessage = UserFriendlyError.syncMessage(for: error)
        }
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
            obsolete: record["obsolete"] as? Bool ?? false,
            customImagePath: record["customImagePath"] as? String
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
            operation.recordMatchedBlock = { _, result in
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
        let recordID = CKRecord.ID(recordName: "deviceInfo")

        // Try to fetch existing record first, or create new one
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: deviceRecordType, recordID: recordID)
        }

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

    // MARK: - Schema Initialization

    /// Check if error is due to missing CloudKit record type (schema not created)
    private func isSchemaNotFoundError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Check for CKError.unknownItem (code 11)
        if nsError.domain == CKError.errorDomain, nsError.code == CKError.unknownItem.rawValue {
            return true
        }

        // Check for internal error with "Did not find record type" message
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            if let description = underlyingError.userInfo["ServerErrorDescription"] as? String,
               description.contains("Did not find record type") {
                return true
            }
        }

        // Check top-level ServerErrorDescription
        if let description = nsError.userInfo["ServerErrorDescription"] as? String,
           description.contains("Did not find record type") {
            return true
        }

        return false
    }

    /// Initialize CloudKit schema by creating sample records
    /// This only works in CloudKit Development environment
    private func initializeCloudKitSchema() async {
        AppLogger.info("🔧 Initializing CloudKit schema...")

        #if os(macOS)
        // Only macOS can upload - create a sample PluginItem record to initialize schema
        do {
            // Check account status first
            let accountStatus = try await container.accountStatus()

            guard accountStatus == .available else {
                AppLogger.info("⚠️ iCloud account not available - cannot initialize schema")
                AppLogger.info("   Please sign in to iCloud in System Settings")
                return
            }

            // Create a temporary sample record to initialize the schema
            let samplePlugin = PluginItem(
                name: "_SchemaInit",
                publisher: "System",
                version: "1.0.0",
                type: "VST3",
                style: "Effect",
                architectures: "arm64",
                date: Date(),
                sizeBytes: 0,
                path: "/tmp/schema_init",
                runtimeRequirement: "",
                obsolete: false
            )

            let record = createRecord(from: samplePlugin)

            // Save the record to create the schema
            _ = try await database.save(record)

            AppLogger.info("✅ CloudKit schema initialized successfully")
            AppLogger.info("   The app will now sync properly on next launch")

            // Clean up the sample record
            _ = try? await database.deleteRecord(withID: record.recordID)

        } catch {
            AppLogger.info("⚠️ Could not initialize CloudKit schema: \(error.localizedDescription)")
            AppLogger.info("   This is normal if you're not in CloudKit Development mode")
            AppLogger.info("   To fix: Open CloudKit Dashboard and create schema manually, or scan plugins from Mac to auto-create schema")
        }
        #else
        // iOS cannot create schema - provide helpful message
        AppLogger.info("ℹ️ CloudKit schema not initialized yet")
        AppLogger.info("   To sync between devices, first scan plugins on your Mac")
        AppLogger.info("   The Mac app will create the CloudKit schema automatically")
        #endif
    }
}
