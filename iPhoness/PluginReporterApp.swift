//
//  PluginReporterApp.swift
//  PluginReporter
//
//  Created by Chad Littlepage on 10/3/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import SwiftUI
import Sentry

@main
struct PluginReporterApp: App {
    init() {
        // Initialize Sentry for crash reporting and performance monitoring
        SentrySDK.start { options in
            options.dsn = "https://2e4766b1965fd54a27939749c41484e0@o4510140548055040.ingest.us.sentry.io/4510140566929408"
            options.debug = false // Set to true for debugging
            options.tracesSampleRate = 1.0 // Performance monitoring
            options.environment = "production"
            options.enableAutoSessionTracking = true
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
