//
//  APIKeyManager.swift
//  Plugin Reporter
//
//  Manages secure storage of OpenAI API key using Keychain
//

import Foundation
import Combine

@MainActor
class APIKeyManager: ObservableObject {
    @Published var apiKey: String = ""
    @Published var validationError: String?

    init() {
        self.apiKey = loadAPIKey()
        migrateAPIKeyToKeychain()
    }

    private func loadAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "openai_api_key", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            return ""
        }

        return value
    }

    func saveAPIKey(_ value: String) {
        // Clear any previous validation errors
        validationError = nil

        if value.isEmpty {
            // Delete from Keychain
            deleteAPIKey()
            self.apiKey = ""
            return
        }

        // Validate API key format before saving
        guard isValidOpenAIKey(value) else {
            validationError = validateOpenAIKey(value) // Get specific error message
            return
        }

        guard let data = value.data(using: .utf8) else { return }

        // Try to update first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "openai_api_key"
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, add it
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }

        self.apiKey = value
    }

    // MARK: - API Key Validation

    /// Validates OpenAI API key format
    /// - Parameter key: The API key to validate
    /// - Returns: Error message if invalid, nil if valid
    private func validateOpenAIKey(_ key: String) -> String? {
        // Trim whitespace
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if empty
        if trimmedKey.isEmpty {
            return nil // Empty is allowed (will delete key)
        }

        // Check prefix (OpenAI keys start with "sk-" or "sk-proj-")
        guard trimmedKey.hasPrefix("sk-") || trimmedKey.hasPrefix("sk-proj-") else {
            return "Invalid format: OpenAI API keys must start with 'sk-' or 'sk-proj-'"
        }

        // Check minimum length (OpenAI keys are typically 48-56 characters)
        guard trimmedKey.count >= 40 else {
            return "Invalid length: OpenAI API keys must be at least 40 characters"
        }

        // Check maximum length (prevent extremely long strings)
        guard trimmedKey.count <= 200 else {
            return "Invalid length: Key is too long (max 200 characters)"
        }

        // Check for valid characters (alphanumeric, hyphens, underscores)
        let validCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard trimmedKey.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            return "Invalid characters: API key can only contain letters, numbers, hyphens, and underscores"
        }

        // Check for common placeholder values
        let placeholders = ["sk-...", "sk-your-key-here", "sk-1234567890", "sk-placeholder"]
        if placeholders.contains(trimmedKey) {
            return "Placeholder detected: Please enter your actual OpenAI API key"
        }

        // All checks passed
        return nil
    }

    /// Quick validation check (returns boolean)
    private func isValidOpenAIKey(_ key: String) -> Bool {
        return validateOpenAIKey(key) == nil
    }

    private func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "openai_api_key"
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func migrateAPIKeyToKeychain() {
        // Legacy: check UserDefaults for old API key
        if let legacyKey = UserDefaults.standard.string(forKey: "openai_api_key"), !legacyKey.isEmpty {
            saveAPIKey(legacyKey)
            UserDefaults.standard.removeObject(forKey: "openai_api_key")
        }
    }
}