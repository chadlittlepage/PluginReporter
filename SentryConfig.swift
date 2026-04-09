//
//  SentryConfig.swift
//  PluginReporter
//
//  Secure configuration manager for Sentry DSN
//  Copyright © 2024 Chad Littlepage. All rights reserved.
//

import Foundation

/// Secure configuration manager that reads from build settings
enum SentryConfig {
    /// Sentry DSN from secure build configuration
    /// Returns nil if not configured (for development builds without Sentry)
    static var dsn: String? {
        // Try to read from Info.plist which gets build setting injected
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String, !dsn.isEmpty, !dsn.contains("YOUR_") else {
            AppLogger.warning("Sentry DSN not configured - crash reporting disabled")
            return nil
        }
        return dsn
    }

    /// Privacy policy URL from configuration
    static var privacyPolicyURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "PRIVACY_POLICY_URL") as? String, !url.contains("yourwebsite.com") else {
            AppLogger.error("Privacy policy URL not configured!")
            return "https://github.com/yourusername/pluginreporter/privacy"
        }
        return url
    }

    /// Support URL from configuration
    static var supportURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPPORT_URL") as? String, !url.contains("yourwebsite.com") else {
            AppLogger.error("Support URL not configured!")
            return "https://github.com/yourusername/pluginreporter/support"
        }
        return url
    }
}