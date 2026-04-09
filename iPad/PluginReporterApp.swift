//
//  PluginReporterApp.swift
//  PluginReporter (iPad)
//
//  iPad app entry point
//

import FirebaseCore
import Sentry
import SwiftUI

@main
struct PluginReporterApp: App {
    init() {
        // Initialize Firebase first (required before any Firebase services)
        // Only configure if GoogleService-Info.plist exists
        if let _ = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            FirebaseApp.configure()
            AppLogger.info("Firebase initialized")
        } else {
            AppLogger.info("Firebase not configured - GoogleService-Info.plist not found. Enrichment disabled.")
        }

        // Initialize Sentry for crash reporting (only if configured)
        // Read DSN directly from Info.plist to avoid dependency on SentryConfig file
        if let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
           !dsn.isEmpty,
           !dsn.contains("YOUR_") {
            SentrySDK.start { options in
                options.dsn = dsn
                options.debug = false
                options.tracesSampleRate = 1.0
                options.environment = "production"
                options.enableAutoSessionTracking = true
            }
            AppLogger.info("Sentry crash reporting initialized")
        } else {
            AppLogger.info("Sentry not configured - running without crash reporting")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
