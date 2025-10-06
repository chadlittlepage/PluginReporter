//
//  ContentView.swift
//  PluginReporter (iPad)
//
//  Main content view for iPad with optimized layout
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var plugins: [PluginItem] = []
    @State private var filteredPlugins: [PluginItem] = []
    @State private var isLoading = true
    @State private var showImportAlert = false
    @State private var debugMessage = ""
    @State private var showDebugAlert = false
    @AppStorage("appearance") private var appearance: String = "space"

    var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        case "space": return .dark
        case "system": return nil
        default: return .dark
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PluginListView(plugins: plugins, filteredPluginsForExport: $filteredPlugins)
                .tabItem {
                    Label("Plugins", systemImage: "music.note.list")
                }
                .tag(0)

            SettingsView(onImport: loadPluginsFromFile)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)

            ExportView(plugins: filteredPlugins)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            // Auto-load plugins on launch
            if plugins.isEmpty {
                loadPluginsSilently()
            }

            // Request full screen on iPad
            #if os(iOS)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all)) { error in
                    AppLogger.error("Geometry update error: \(error)")
                }
            }
            #endif
        }
        .alert("Plugins Loaded", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(plugins.count) plugins imported successfully")
        }
        .alert("Debug Info", isPresented: $showDebugAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(debugMessage)
        }
    }

    func loadPluginsFromFile() {
        // Reload from shared storage with debug info
        print("📱 iPad loadPluginsFromFile() called")
        do {
            let loadedPlugins = try SharedStorage.loadPlugins()
            plugins = loadedPlugins
            isLoading = false
            AppLogger.info("Loaded \(plugins.count) plugins on iPad")
            showImportAlert = true
        } catch {
            AppLogger.error("Failed to load plugins: \(error.localizedDescription)")
            debugMessage = "❌ Error: \(error.localizedDescription)"
            showDebugAlert = true
            plugins = []
            isLoading = false
        }
    }

    func loadPluginsSilently() {
        // Auto-load on launch without showing alerts
        do {
            let loadedPlugins = try SharedStorage.loadPlugins()
            plugins = loadedPlugins
            isLoading = false
            AppLogger.info("Auto-loaded \(plugins.count) plugins on iPad launch")
        } catch {
            AppLogger.error("Failed to auto-load plugins on iPad: \(error.localizedDescription)")
            plugins = []
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
