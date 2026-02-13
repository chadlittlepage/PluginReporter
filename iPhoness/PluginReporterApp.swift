//
//  PluginReporterApp.swift
//  PluginReporter
//
//  Created by Chad Littlepage on 10/3/24.
//  Copyright © 2024 Chad Littlepage. All rights reserved.
//

import SwiftUI
import Sentry

@main
struct PluginReporterApp: App {
    init() {
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
