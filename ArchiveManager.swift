//
//  ArchiveManager.swift
//  PluginReporter
//
//  Complete backup and restore system for Plugin Reporter data
//  Exports all user data (ratings, tags, notes, playlists, metadata) to a single archive file
//  Uses AES-256 encryption for secure backups
//

import Foundation
import CryptoKit
import CommonCrypto
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Manages complete backup and restore of all Plugin Reporter user data
class ArchiveManager {

    static let shared = ArchiveManager()

    // Archive format version for future compatibility
    private let archiveFormatVersion = 1

    // File extension for archives
    static let archiveExtension = "pluginreporter"

    private init() {}

    // MARK: - Archive Structure

    /// Complete archive manifest
    struct ArchiveManifest: Codable {
        let version: Int
        let exportDate: Date
        let appVersion: String
        let platform: String

        struct DataInventory: Codable {
            let ratingsCount: Int
            let tagsCount: Int
            let notesCount: Int
            let playlistsCount: Int
            let metadataCount: Int
            let licensesCount: Int
        }

        let inventory: DataInventory
    }

    /// Archive contents structure
    struct ArchiveContents: Codable {
        let manifest: ArchiveManifest
        let ratingsData: Data?
        let tagsData: Data?
        let notesData: Data?
        let playlistsData: Data?
        let metadataData: Data?
        let licensesData: Data?
        let preferencesData: Data?
    }

    // MARK: - Encryption

    /// Encrypt data using AES-256-GCM with password-derived key
    private func encrypt(data: Data, password: String) throws -> Data {
        // Derive 256-bit key from password using PBKDF2
        let salt = SymmetricKey(size: .bits256)
        let saltData = salt.withUnsafeBytes { Data($0) }

        let key = try deriveKey(from: password, salt: saltData)

        // Encrypt using AES-GCM (provides authentication)
        let sealedBox = try AES.GCM.seal(data, using: key)

        // Combine salt + nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw ArchiveError.encryptionFailed
        }

        // Prepend salt for decryption
        var encryptedData = saltData
        encryptedData.append(combined)

        return encryptedData
    }

    /// Decrypt data using AES-256-GCM with password-derived key
    private func decrypt(data: Data, password: String) throws -> Data {
        // Extract salt (first 32 bytes)
        guard data.count > 32 else {
            throw ArchiveError.decryptionFailed
        }

        let saltData = data.prefix(32)
        let encryptedData = data.suffix(from: 32)

        // Derive key from password and salt
        let key = try deriveKey(from: password, salt: saltData)

        // Decrypt using AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    /// Derive encryption key from password using PBKDF2
    private func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw ArchiveError.invalidPassword
        }

        // Use PBKDF2 with 100,000 iterations (OWASP recommendation)
        let iterations = 100_000
        let derivedKeyData = try pbkdf2(
            password: passwordData, salt: salt, keyByteCount: 32, // 256 bits
            rounds: iterations
        )

        return SymmetricKey(data: derivedKeyData)
    }

    /// PBKDF2 key derivation
    private func pbkdf2(password: Data, salt: Data, keyByteCount: Int, rounds: Int) throws -> Data {
        var derivedKeyData = Data(count: keyByteCount)
        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self), password.count, saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(rounds), derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), keyByteCount
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw ArchiveError.keyDerivationFailed
        }

        return derivedKeyData
    }

    // MARK: - Export

    /// Export complete Plugin Reporter data to archive file
    /// - Parameters:
    ///   - url: Destination URL for the archive file
    ///   - password: Optional password for AES-256 encryption
    /// - Throws: Export errors
    func exportArchive(to url: URL, password: String? = nil) throws {
        print("📦 Starting archive export to: \(url.path)")

        // Gather all data from storage
        let storage = CloudSyncStorage.shared

        let ratingsData = storage.getData(forKey: "plugin_ratings_v2")
        let tagsData = storage.getData(forKey: "plugin_tags")
        let notesData = storage.getData(forKey: "plugin_notes")
        let playlistsData = storage.getData(forKey: "daw_playlists")
        let metadataData = storage.getData(forKey: "plugin_metadata")
        let licensesData = storage.getData(forKey: "plugin_licenses")

        // Export preferences (UserDefaults)
        let preferencesData = try exportPreferences()

        // Count items for inventory
        let ratingsCount = countItems(in: ratingsData)
        let tagsCount = countItems(in: tagsData)
        let notesCount = countItems(in: notesData)
        let playlistsCount = countPlaylists(in: playlistsData)
        let metadataCount = countItems(in: metadataData)
        let licensesCount = countItems(in: licensesData)

        // Create manifest
        let manifest = ArchiveManifest(
            version: archiveFormatVersion, exportDate: Date(), appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown", platform: {
                #if os(macOS)
                return "macOS"
                #else
                return "iOS"
                #endif
            }(), inventory: ArchiveManifest.DataInventory(
                ratingsCount: ratingsCount, tagsCount: tagsCount, notesCount: notesCount, playlistsCount: playlistsCount, metadataCount: metadataCount, licensesCount: licensesCount
            )
        )

        print("📊 Archive inventory:")
        print("   - Ratings: \(ratingsCount)")
        print("   - Tags: \(tagsCount)")
        print("   - Notes: \(notesCount)")
        print("   - Playlists: \(playlistsCount)")
        print("   - Metadata: \(metadataCount)")
        print("   - Licenses: \(licensesCount)")

        // Create archive contents
        let contents = ArchiveContents(
            manifest: manifest, ratingsData: ratingsData, tagsData: tagsData, notesData: notesData, playlistsData: playlistsData, metadataData: metadataData, licensesData: licensesData, preferencesData: preferencesData
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        var jsonData = try encoder.encode(contents)

        // Encrypt if password provided
        if let password = password, !password.isEmpty {
            print("🔐 Encrypting archive with AES-256...")
            jsonData = try encrypt(data: jsonData, password: password)
            print("✅ Archive encrypted")
        } else {
            print("⚠️  Archive is NOT encrypted (no password provided)")
        }

        // Compress to ZIP
        #if os(macOS)
        try createZipArchive(jsonData: jsonData, to: url)
        #else
        // iOS: Just write the data
        try jsonData.write(to: url)
        #endif

        print("✅ Archive export completed: \(url.lastPathComponent)")
        print("   Size: \(ByteCountFormatter.string(fromByteCount: Int64(jsonData.count), countStyle: .file))")
    }

    // MARK: - Import

    /// Import complete Plugin Reporter data from archive file
    /// - Parameters:
    ///   - url: Source URL of the archive file
    ///   - password: Password for encrypted archives (nil for unencrypted)
    ///   - mergeMode: Whether to merge with existing data or replace
    /// - Throws: Import errors
    func importArchive(from url: URL, password: String? = nil, mergeMode: Bool = false) throws -> ArchiveManifest {
        print("📥 Starting archive import from: \(url.path)")

        // Read and decompress archive
        var jsonData: Data
        #if os(macOS)
        jsonData = try extractZipArchive(from: url)
        #else
        jsonData = try Data(contentsOf: url)
        #endif

        // Try to decrypt if password provided
        if let password = password, !password.isEmpty {
            print("🔓 Decrypting archive with provided password...")
            jsonData = try decrypt(data: jsonData, password: password)
            print("✅ Archive decrypted successfully")
        } else {
            print("ℹ️  No password provided - attempting to read as unencrypted archive")
        }

        // Decode archive contents
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let contents = try decoder.decode(ArchiveContents.self, from: jsonData)

        // Validate archive version
        guard contents.manifest.version <= archiveFormatVersion else {
            throw ArchiveError.incompatibleVersion(contents.manifest.version)
        }

        print("📊 Archive manifest:")
        print("   - Export date: \(contents.manifest.exportDate)")
        print("   - App version: \(contents.manifest.appVersion)")
        print("   - Platform: \(contents.manifest.platform)")
        print("   - Ratings: \(contents.manifest.inventory.ratingsCount)")
        print("   - Tags: \(contents.manifest.inventory.tagsCount)")
        print("   - Notes: \(contents.manifest.inventory.notesCount)")
        print("   - Playlists: \(contents.manifest.inventory.playlistsCount)")
        print("   - Metadata: \(contents.manifest.inventory.metadataCount)")
        print("   - Licenses: \(contents.manifest.inventory.licensesCount)")

        // If not merging, clear existing data first
        if !mergeMode {
            print("🗑️ Replacing existing data...")
            clearAllData()
        } else {
            print("🔀 Merging with existing data...")
        }

        // Restore all data to storage
        let storage = CloudSyncStorage.shared

        if let ratingsData = contents.ratingsData {
            storage.setData(ratingsData, forKey: "plugin_ratings_v2")
            print("✅ Restored ratings")
        }

        if let tagsData = contents.tagsData {
            storage.setData(tagsData, forKey: "plugin_tags")
            print("✅ Restored tags")
        }

        if let notesData = contents.notesData {
            storage.setData(notesData, forKey: "plugin_notes")
            print("✅ Restored notes")
        }

        if let playlistsData = contents.playlistsData {
            storage.setData(playlistsData, forKey: "daw_playlists")
            print("✅ Restored playlists")
        }

        if let metadataData = contents.metadataData {
            storage.setData(metadataData, forKey: "plugin_metadata")
            print("✅ Restored metadata")
        }

        if let licensesData = contents.licensesData {
            storage.setData(licensesData, forKey: "plugin_licenses")
            print("✅ Restored licenses")
        }

        if let preferencesData = contents.preferencesData {
            try importPreferences(preferencesData)
            print("✅ Restored preferences")
        }

        // Force sync to iCloud if available
        storage.forceSynchronize()

        print("✅ Archive import completed successfully")

        return contents.manifest
    }

    // MARK: - Helper Methods

    private func countItems(in data: Data?) -> Int {
        guard let data = data else { return 0 }

        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict.count
            }
        } catch {
            print("⚠️ Failed to count items: \(error)")
        }

        return 0
    }

    private func countPlaylists(in data: Data?) -> Int {
        guard let data = data else { return 0 }

        do {
            if let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return array.count
            }
        } catch {
            print("⚠️ Failed to count playlists: \(error)")
        }

        return 0
    }

    private func exportPreferences() throws -> Data {
        // Export user preferences (non-sensitive settings only)
        let prefs = UserDefaults.standard

        var prefsDict: [String: Any] = [:]

        // Export appearance preferences
        if let appearance = prefs.string(forKey: "appearance") {
            prefsDict["appearance"] = appearance
        }

        // Export filter preferences
        if let selectedFormats = prefs.array(forKey: "selectedFormats") {
            prefsDict["selectedFormats"] = selectedFormats
        }

        if let selectedStarRatings = prefs.array(forKey: "selectedStarRatings") {
            prefsDict["selectedStarRatings"] = selectedStarRatings
        }

        if let selectedStyles = prefs.array(forKey: "selectedStyles") {
            prefsDict["selectedStyles"] = selectedStyles
        }

        // Export view preferences
        prefsDict["showObsoletePlugins"] = prefs.bool(forKey: "showObsoletePlugins")
        prefsDict["showArchitectureBadges"] = prefs.bool(forKey: "showArchitectureBadges")

        return try JSONSerialization.data(withJSONObject: prefsDict)
    }

    private func importPreferences(_ data: Data) throws {
        let prefs = UserDefaults.standard

        guard let prefsDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ArchiveError.invalidPreferencesData
        }

        // Restore preferences
        for (key, value) in prefsDict {
            prefs.set(value, forKey: key)
        }

        prefs.synchronize()
    }

    private func clearAllData() {
        let storage = CloudSyncStorage.shared

        storage.removeData(forKey: "plugin_ratings_v2")
        storage.removeData(forKey: "plugin_tags")
        storage.removeData(forKey: "plugin_notes")
        storage.removeData(forKey: "daw_playlists")
        storage.removeData(forKey: "plugin_metadata")
    }

    #if os(macOS)
    private func createZipArchive(jsonData: Data, to url: URL) throws {
        // Create temporary directory for archive contents
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Write JSON to temp file
        let jsonFile = tempDir.appendingPathComponent("archive.json")
        try jsonData.write(to: jsonFile)

        // Create ZIP using ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", jsonFile.path, url.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ArchiveError.zipCreationFailed
        }
    }

    private func extractZipArchive(from url: URL) throws -> Data {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Extract ZIP using ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", url.path, tempDir.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ArchiveError.zipExtractionFailed
        }

        // Read extracted JSON
        let jsonFile = tempDir.appendingPathComponent("archive.json")
        return try Data(contentsOf: jsonFile)
    }
    #endif

    // MARK: - Validation

    /// Validate an archive file without importing
    /// - Parameters:
    ///   - url: Archive file URL
    ///   - password: Optional password for encrypted archives
    /// - Returns: Archive manifest if valid
    func validateArchive(at url: URL, password: String? = nil) throws -> (manifest: ArchiveManifest, isEncrypted: Bool) {
        print("🔍 Validating archive: \(url.path)")

        // Read and decompress
        var jsonData: Data
        #if os(macOS)
        jsonData = try extractZipArchive(from: url)
        #else
        jsonData = try Data(contentsOf: url)
        #endif

        // Try to decode directly first (unencrypted)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let contents = try decoder.decode(ArchiveContents.self, from: jsonData)

            // Validate version
            guard contents.manifest.version <= archiveFormatVersion else {
                throw ArchiveError.incompatibleVersion(contents.manifest.version)
            }

            print("✅ Archive is valid (unencrypted)")
            return (contents.manifest, false)
        } catch {
            // Failed to decode - might be encrypted
            print("ℹ️  Archive appears to be encrypted")

            if let password = password, !password.isEmpty {
                // Try to decrypt with provided password
                jsonData = try decrypt(data: jsonData, password: password)
                let contents = try decoder.decode(ArchiveContents.self, from: jsonData)

                guard contents.manifest.version <= archiveFormatVersion else {
                    throw ArchiveError.incompatibleVersion(contents.manifest.version)
                }

                print("✅ Archive is valid (encrypted)")
                return (contents.manifest, true)
            } else {
                // No password provided for encrypted archive
                throw ArchiveError.passwordRequired
            }
        }
    }

    /// Check if an archive is encrypted without validating
    func isArchiveEncrypted(at url: URL) -> Bool {
        do {
            // Read archive
            var jsonData: Data
            #if os(macOS)
            jsonData = try extractZipArchive(from: url)
            #else
            jsonData = try Data(contentsOf: url)
            #endif

            // Try to decode as JSON
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            _ = try decoder.decode(ArchiveContents.self, from: jsonData)

            // If successful, it's unencrypted
            return false
        } catch {
            // Failed to decode - likely encrypted
            return true
        }
    }
}

// MARK: - Errors

enum ArchiveError: LocalizedError {
    case incompatibleVersion(Int)
    case zipCreationFailed
    case zipExtractionFailed
    case invalidPreferencesData
    case noDataToExport
    case encryptionFailed
    case decryptionFailed
    case invalidPassword
    case passwordRequired
    case keyDerivationFailed

    var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let version): 
            return "Archive version \(version) is not compatible with this version of Plugin Reporter"
        case .zipCreationFailed: 
            return "Failed to create ZIP archive"
        case .zipExtractionFailed: 
            return "Failed to extract ZIP archive"
        case .invalidPreferencesData: 
            return "Invalid preferences data in archive"
        case .noDataToExport: 
            return "No data available to export"
        case .encryptionFailed: 
            return "Failed to encrypt archive data"
        case .decryptionFailed: 
            return "Failed to decrypt archive - incorrect password or corrupted file"
        case .invalidPassword: 
            return "Password is invalid or cannot be processed"
        case .passwordRequired: 
            return "This archive is encrypted and requires a password"
        case .keyDerivationFailed: 
            return "Failed to derive encryption key from password"
        }
    }
}