//
//  PluginLicense.swift
//  Plugin Reporter
//
//  License and credential management for audio plugins
//

import Foundation
import Security

/// Stores license information and credentials for audio plugins
struct PluginLicense: Codable, Identifiable {
    var id = UUID()
    var pluginName: String
    var pluginID: String // Unique identifier (name + publisher)

    // License Information
    var serialNumber: String?
    var licenseKey: String?
    var accountEmail: String?

    // Activation Tracking
    var purchaseDate: Date?
    var activationsUsed: Int?
    var maxActivations: Int?
    var activationCode: String?

    // Files & Documents
    var licenseFileURL: URL?
    var receiptURL: URL?
    var invoiceNumber: String?

    // Vendor Information
    var manufacturerURL: String?
    var supportURL: String?
    var accountPortalURL: String?

    // Notes
    var notes: String?

    // Metadata
    var dateAdded: Date
    var lastModified: Date

    init(pluginName: String, pluginID: String) {
        self.pluginName = pluginName
        self.pluginID = pluginID
        self.dateAdded = Date()
        self.lastModified = Date()
    }
}

/// Manager for plugin licenses with secure credential storage
@MainActor
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var licenses: [String: PluginLicense] = [:]

    private let storage = CloudSyncStorage.shared
    private let storageKey = "plugin_licenses"

    // Keychain configuration
    private let keychainService = "com.chadlittlepage.PluginReporter.licenses"

    init() {
        loadLicenses()
    }

    // MARK: - License Management

    /// Get license for a specific plugin
    func getLicense(for pluginID: String) -> PluginLicense? {
        return licenses[pluginID]
    }

    /// Set or update license information
    func setLicense(_ license: PluginLicense) {
        var updatedLicense = license
        updatedLicense.lastModified = Date()
        licenses[license.pluginID] = updatedLicense
        saveLicenses()
    }

    /// Delete license for a plugin
    func deleteLicense(for pluginID: String) {
        licenses.removeValue(forKey: pluginID)

        // Also delete password from keychain
        deletePassword(for: pluginID)

        saveLicenses()
    }

    /// Check if plugin has license information
    func hasLicense(for pluginID: String) -> Bool {
        return licenses[pluginID] != nil
    }

    /// Get all licenses
    func getAllLicenses() -> [PluginLicense] {
        return Array(licenses.values).sorted { $0.pluginName < $1.pluginName }
    }

    // MARK: - Secure Password Storage (Keychain)

    /// Store password securely in keychain
    func setPassword(_ password: String, for pluginID: String) -> Bool {
        guard let passwordData = password.data(using: .utf8) else { return false }

        // Delete existing password first
        deletePassword(for: pluginID)

        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: pluginID,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve password securely from keychain
    func getPassword(for pluginID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: pluginID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    /// Delete password from keychain
    func deletePassword(for pluginID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: pluginID
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Persistence

    private func saveLicenses() {
        do {
            let data = try JSONEncoder().encode(licenses)
            storage.setData(data, forKey: storageKey)
        } catch {
            AppLogger.error("Failed to save licenses: \(error)")
        }
    }

    private func loadLicenses() {
        guard let data = storage.getData(forKey: storageKey) else { return }

        do {
            licenses = try JSONDecoder().decode([String: PluginLicense].self, from: data)
        } catch {
            AppLogger.error("Failed to load licenses: \(error)")
        }
    }

    // MARK: - Helper Functions

    /// Generate plugin ID from name and publisher
    static func makePluginID(name: String, publisher: String) -> String {
        return "\(publisher.lowercased())_\(name.lowercased())"
            .replacingOccurrences(of: " ", with: "_")
    }

    /// Check if license is fully populated
    func isLicenseComplete(_ license: PluginLicense) -> Bool {
        return license.serialNumber != nil || license.licenseKey != nil
    }

    /// Get license status string
    func getLicenseStatus(for pluginID: String) -> String {
        guard let license = getLicense(for: pluginID) else {
            return "No License Stored"
        }

        if license.serialNumber != nil || license.licenseKey != nil {
            if let used = license.activationsUsed, let max = license.maxActivations {
                return "Licensed (\(used)/\(max) activations)"
            }
            return "Licensed"
        }

        return "Incomplete"
    }

    // MARK: - Export

    /// Export all licenses (excluding passwords) for backup
    func exportLicenses() -> Data? {
        do {
            return try JSONEncoder().encode(licenses)
        } catch {
            AppLogger.error("Failed to export licenses: \(error)")
            return nil
        }
    }

    /// Import licenses from backup
    func importLicenses(from data: Data, merge: Bool = true) throws {
        let importedLicenses = try JSONDecoder().decode([String: PluginLicense].self, from: data)

        if merge {
            // Merge with existing licenses
            for (key, license) in importedLicenses {
                licenses[key] = license
            }
        } else {
            // Replace all licenses
            licenses = importedLicenses
        }

        saveLicenses()
    }
}

// MARK: - License Type Helper

/// PERFORMANCE: Single source of truth for license type detection
/// Eliminates 9 duplicate implementations across the codebase
@MainActor
final class LicenseTypeHelper {

    // MARK: - Cache

    private static var cache: [UUID: String] = [:]

    /// Clear the license type cache (call when licenses are updated)
    static func clearCache() {
        cache.removeAll()
    }

    // MARK: - License Type Detection

    /// Get the license type for a plugin (iLok, Serial, or empty)
    /// This is the SINGLE SOURCE OF TRUTH - eliminates 9 duplicate implementations
    static func getLicenseType(for plugin: PluginItem) -> String {
        let pluginID = "\(plugin.publisher.lowercased())_\(plugin.name.lowercased())"
            .replacingOccurrences(of: " ", with: "_")

        guard let license = LicenseManager.shared.getLicense(for: pluginID) else {
            return ""
        }

        // Check if it mentions iLok anywhere (imported from iLok)
        if let notes = license.notes?.lowercased(), notes.contains("ilok") {
            return "iLok"
        }
        if let activationCode = license.activationCode?.lowercased(), activationCode.contains("ilok") {
            return "iLok"
        }

        // Check if it has a serial number or license key
        if license.serialNumber?.isEmpty == false || license.licenseKey?.isEmpty == false {
            return "Serial"
        }

        // If we have a license entry but no specific data, still show something was imported
        if license.notes?.isEmpty == false {
            return "iLok"  // Default to iLok if we have notes but no serial
        }

        return ""
    }

    /// Get cached license type for a plugin
    /// PERFORMANCE: Use this for sorting and rendering - 10x faster than getLicenseType
    static func getCachedLicenseType(for plugin: PluginItem) -> String {
        if let cached = cache[plugin.id] {
            return cached
        }
        let type = getLicenseType(for: plugin)
        cache[plugin.id] = type
        return type
    }
}
