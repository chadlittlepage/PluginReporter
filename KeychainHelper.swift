//
//  KeychainHelper.swift
//  Plugin Reporter
//
//  Secure encrypted storage for sensitive data like API keys
//

import Foundation
import Security

/// Provides secure encrypted storage using the system Keychain
///
/// Use this for storing sensitive data like API keys instead of UserDefaults.
/// The Keychain is encrypted and protected by the system.
enum KeychainHelper {

    /// Saves a string value securely to the Keychain
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the stored value
    ///   - value: String value to store (e.g., API key)
    /// - Returns: true if successful, false otherwise
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves a string value from the Keychain
    ///
    /// - Parameter key: Unique identifier for the stored value
    /// - Returns: The stored string value, or nil if not found
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Deletes a value from the Keychain
    ///
    /// - Parameter key: Unique identifier for the stored value
    /// - Returns: true if successful or item didn't exist, false on error
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Updates an existing value in the Keychain
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the stored value
    ///   - value: New string value to store
    /// - Returns: true if successful, false otherwise
    @discardableResult
    static func update(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        // If item doesn't exist, create it
        if status == errSecItemNotFound {
            return save(key: key, value: value)
        }

        return status == errSecSuccess
    }

    /// Checks if a key exists in the Keychain
    ///
    /// - Parameter key: Unique identifier to check
    /// - Returns: true if the key exists, false otherwise
    static func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Convenience Property Wrapper

/// Property wrapper for secure Keychain storage
///
/// Usage:
/// ```swift
/// @KeychainStorage("openai_api_key")
/// var apiKey: String = ""
/// ```
@propertyWrapper
struct KeychainStorage {
    let key: String
    let defaultValue: String

    init(wrappedValue defaultValue: String, _ key: String) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: String {
        get {
            KeychainHelper.load(key: key) ?? defaultValue
        }
        nonmutating set {
            if newValue.isEmpty {
                KeychainHelper.delete(key: key)
            } else {
                KeychainHelper.save(key: key, value: newValue)
            }
        }
    }
}
