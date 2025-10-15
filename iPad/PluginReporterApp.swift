//
//  PluginReporterApp.swift
//  PluginReporter (iPad)
//
//  iPad app entry point
//

import SwiftUI
import Sentry

@main
struct PluginReporterApp: App {
    init() {
        // Initialize Sentry for crash reporting (only if configured)
        if let dsn = SentryConfig.dsn {
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
