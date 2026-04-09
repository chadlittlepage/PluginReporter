//
//  PluginLicense.swift
//  Plugin Reporter
//
//  License and credential management for audio plugins
//

import Foundation
import Security
import CryptoKit

/// Stores license information and credentials for audio plugins
struct PluginLicense: Codable, Identifiable {
    var id = UUID()
    var pluginName: String
    var pluginID: String // Unique identifier (name + publisher)

    // License Information (ENCRYPTED in storage)
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
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: pluginID, kSecValueData as String: passwordData, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve password securely from keychain
    func getPassword(for pluginID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: pluginID, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    /// Delete password from keychain
    func deletePassword(for pluginID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: pluginID
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Persistence

    private func saveLicenses() {
        do {
            // Encrypt sensitive license data before saving
            let encryptedLicenses = licenses.mapValues { license in
                encryptLicenseFields(license)
            }

            let data = try JSONEncoder().encode(encryptedLicenses)
            storage.setData(data, forKey: storageKey)
        } catch {
            AppLogger.error("Failed to save licenses: \(error)")
        }
    }

    private func loadLicenses() {
        guard let data = storage.getData(forKey: storageKey) else { return }

        do {
            let encryptedLicenses = try JSONDecoder().decode([String: PluginLicense].self, from: data)

            // Decrypt sensitive license data after loading
            licenses = encryptedLicenses.mapValues { license in
                decryptLicenseFields(license)
            }
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

    // MARK: - Encryption (AES-256-GCM)

    /// Get or create encryption key from keychain
    private func getEncryptionKey() -> SymmetricKey {
        let keyAccount = "license_encryption_key"

        // Try to retrieve existing key from keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }

        // Create new key if it doesn't exist
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // Store key in keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(addQuery as CFDictionary, nil)

        return newKey
    }

    /// Encrypt a string using AES-256-GCM
    private func encryptString(_ plaintext: String?) -> String? {
        guard let plaintext = plaintext, !plaintext.isEmpty else { return nil }
        guard let data = plaintext.data(using: .utf8) else { return nil }

        do {
            let key = getEncryptionKey()
            let sealed = try AES.GCM.seal(data, using: key)

            // Combine nonce + ciphertext + tag into single Data
            guard let combined = sealed.combined else { return nil }

            // Return base64-encoded encrypted data
            return combined.base64EncodedString()
        } catch {
            AppLogger.error("Encryption failed: \(error)")
            return nil
        }
    }

    /// Decrypt a string using AES-256-GCM
    private func decryptString(_ encrypted: String?) -> String? {
        guard let encrypted = encrypted, !encrypted.isEmpty else { return nil }
        guard let combined = Data(base64Encoded: encrypted) else { return nil }

        do {
            let key = getEncryptionKey()
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(sealedBox, using: key)

            return String(data: decrypted, encoding: .utf8)
        } catch {
            AppLogger.error("Decryption failed: \(error)")
            return nil
        }
    }

    /// Encrypt sensitive fields of a license before storage
    private func encryptLicenseFields(_ license: PluginLicense) -> PluginLicense {
        var encrypted = license

        // Encrypt sensitive fields
        encrypted.serialNumber = encryptString(license.serialNumber)
        encrypted.licenseKey = encryptString(license.licenseKey)
        encrypted.accountEmail = encryptString(license.accountEmail)
        encrypted.activationCode = encryptString(license.activationCode)
        encrypted.invoiceNumber = encryptString(license.invoiceNumber)

        return encrypted
    }

    /// Decrypt sensitive fields of a license after loading
    private func decryptLicenseFields(_ license: PluginLicense) -> PluginLicense {
        var decrypted = license

        // Decrypt sensitive fields
        decrypted.serialNumber = decryptString(license.serialNumber)
        decrypted.licenseKey = decryptString(license.licenseKey)
        decrypted.accountEmail = decryptString(license.accountEmail)
        decrypted.activationCode = decryptString(license.activationCode)
        decrypted.invoiceNumber = decryptString(license.invoiceNumber)

        return decrypted
    }
}

// MARK: - License Type Helper