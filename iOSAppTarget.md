import SwiftUI

@main
struct PluginReporter_iOSApp: App {
    @StateObject private var scanner = PluginScanner()
    @StateObject private var prefs = Preferences()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanner)
                .environmentObject(prefs)
        }
    }
}
