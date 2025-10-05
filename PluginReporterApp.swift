import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct PluginReporterApp: App {
    @StateObject private var scanner = PluginScanner()
    @StateObject private var prefs = Preferences()
    @State private var sync = makeSyncServices(backend: .none) // CloudKit disabled until Apple ID is added to Xcode
    @StateObject private var zoomState = ZoomState()

    private func applyAppAppearance(_ appearance: Preferences.Appearance) {
        #if os(macOS)
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .space:
            NSApp.appearance = NSAppearance(named: .darkAqua)  // Space mode uses dark appearance
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanner)
                .environmentObject(prefs)
                .environmentObject(zoomState)
                .id(prefs.appearance)
                .preferredColorScheme(prefs.appearance.colorScheme)
                .onAppear { applyAppAppearance(prefs.appearance) }
                .onChange(of: prefs.appearance) { newValue in applyAppAppearance(newValue) }
                .onChange(of: prefs.cloudSyncEnabled) { enabled in
                    if enabled { sync.preferences.startSync(prefs: prefs) }
                    else { sync.preferences.stopSync() }
                }
                .onAppear {
                    if prefs.cloudSyncEnabled { sync.preferences.startSync(prefs: prefs) }
                }
        }

        .defaultPosition(.center)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Zoom In") { zoomState.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { zoomState.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { zoomState.reset() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView(prefs: prefs)
                .id(prefs.appearance)
                .preferredColorScheme(prefs.appearance.colorScheme)
                .onAppear { applyAppAppearance(prefs.appearance) }
                .onChange(of: prefs.appearance) { newValue in applyAppAppearance(newValue) }
        }
        #endif
    }
}

// MARK: - Zoom State
class ZoomState: ObservableObject {
    @Published var scale: CGFloat = 1.0

    func zoomIn() {
        print("🔍 ZOOM IN called - current: \(scale)")
        scale = min(scale + 0.1, 2.0)
        print("🔍 New scale: \(scale)")
        #if os(macOS)
        applyWindowScale()
        #endif
    }

    func zoomOut() {
        print("🔍 ZOOM OUT called - current: \(scale)")
        scale = max(scale - 0.1, 0.5)
        print("🔍 New scale: \(scale)")
        #if os(macOS)
        applyWindowScale()
        #endif
    }

    func reset() {
        print("🔍 RESET called")
        scale = 1.0
        print("🔍 New scale: \(scale)")
        #if os(macOS)
        applyWindowScale()
        #endif
    }

    #if os(macOS)
    private func applyWindowScale() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }),
                  let hostingView = window.contentView?.subviews.first(where: { String(describing: type(of: $0)).contains("HostingView") }) else {
                print("❌ Could not find hosting view")
                return
            }

            // Apply scaling using bounds transformation (vector-based)
            let currentBounds = hostingView.bounds
            let scaledBounds = CGRect(
                x: 0,
                y: 0,
                width: currentBounds.width / self.scale,
                height: currentBounds.height / self.scale
            )

            hostingView.bounds = scaledBounds
            hostingView.setBoundsSize(scaledBounds.size)

            print("✅ Applied bounds scale: \(self.scale), new bounds: \(scaledBounds)")
        }
    }
    #endif
}
