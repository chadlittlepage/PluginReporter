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

    init() {
        self.apiKey = loadAPIKey()
        migrateAPIKeyToKeychain()
    }

    private func loadAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "openai_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }

        return value
    }

    func saveAPIKey(_ value: String) {
        if value.isEmpty {
            // Delete from Keychain
            deleteAPIKey()
            self.apiKey = ""
            return
        }

        guard let data = value.data(using: .utf8) else { return }

        // Try to update first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "openai_api_key"
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

    private func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "openai_api_key"
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
