//
//  ContentView.swift
//  PluginReporter (iPad)
//
//  Simple TabView - no changes
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0 {
        didSet {
            let timestamp = Date()
            print("🔄 [TAB SWITCH] \(timestamp) - Changed from tab \(oldValue) to \(selectedTab)")
            print("   └─ Tab names: \(tabName(oldValue)) → \(tabName(selectedTab))")
        }
    }
    @State private var plugins: [PluginItem] = []
    @State private var filteredPlugins: [PluginItem] = []
    @State private var isLoading = true
    @State private var showImportAlert = false
    @State private var debugMessage = ""
    @State private var showDebugAlert = false
    @State private var hasLoadedOnce = false
    @AppStorage("appearance") private var appearance: String = "space"

    private func tabName(_ index: Int) -> String {
        switch index {
        case 0: return "Plugins"
        case 1: return "Settings"
        case 2: return "Export"
        default: return "Unknown"
        }
    }

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
            // OPTIMIZATION: Keep view alive when not selected (iPhone pattern)
            Group {
                if selectedTab == 0 {
                    PluginListView(plugins: plugins, filteredPluginsForExport: $filteredPlugins)
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label("Plugins", systemImage: "music.note.list")
            }
            .tag(0)
            .onAppear {
                print("👁️ [VIEW APPEAR] Plugins tab appeared at \(Date())")
            }
            .onDisappear {
                print("👋 [VIEW DISAPPEAR] Plugins tab disappeared at \(Date())")
            }

            Group {
                if selectedTab == 1 {
                    SettingsView(onImport: loadPluginsFromFile)
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(1)
            .onAppear {
                print("👁️ [VIEW APPEAR] Settings tab appeared at \(Date())")
            }
            .onDisappear {
                print("👋 [VIEW DISAPPEAR] Settings tab disappeared at \(Date())")
            }

            Group {
                if selectedTab == 2 {
                    ExportView(plugins: filteredPlugins)
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .tag(2)
            .onAppear {
                print("👁️ [VIEW APPEAR] Export tab appeared at \(Date())")
            }
            .onDisappear {
                print("👋 [VIEW DISAPPEAR] Export tab disappeared at \(Date())")
            }
        }
        .onChange(of: selectedTab) { newValue in
            print("📊 [TABVIEW CHANGE] TabView detected selection change to \(newValue) (\(tabName(newValue)))")
        }
        .animation(.none, value: selectedTab)
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            print("✅ [CONTENTVIEW] ContentView appeared at \(Date())")
            print("   └─ Initial tab: \(selectedTab) (\(tabName(selectedTab)))")
            if !hasLoadedOnce {
                hasLoadedOnce = true
                loadPluginsSilently()
            }
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

    /// Enriches plugins with metadata and screenshot URLs from Firebase using PluginEnrichmentService
    func enrichPlugins(_ plugins: [PluginItem]) async -> [PluginItem] {
        print("🔄 Starting enrichment for \(plugins.count) plugins using PluginEnrichmentService...")

        var mutablePlugins = plugins
        await PluginEnrichmentService.shared.batchFetchEnrichment(for: &mutablePlugins)

        print("✅ Enrichment complete - plugins updated with Firebase data")
        return mutablePlugins
    }

    func loadPluginsFromFile() {
        AppLogger.debug("iPad loadPluginsFromFile called")
        do {
            let loadedPlugins = try SharedStorage.loadPlugins()

            // Show plugins immediately
            plugins = loadedPlugins
            isLoading = false
            AppLogger.info("Loaded \(plugins.count) plugins on iPad")
            showImportAlert = true

            // Enrich plugins with metadata and screenshots from Firebase in background
            Task {
                print("🔄 [iPad] Starting Firebase enrichment for \(loadedPlugins.count) plugins...")
                var mutablePlugins = loadedPlugins
                await PluginEnrichmentService.shared.batchFetchEnrichment(for: &mutablePlugins)
                await MainActor.run {
                    plugins = mutablePlugins
                    print("✅ [iPad] Enrichment complete - plugins updated with screenshot URLs")
                }
            }
        } catch {
            AppLogger.error("Failed to load plugins: \(error.localizedDescription)")
            debugMessage = "❌ Error: \(error.localizedDescription)"
            showDebugAlert = true
            plugins = []
            isLoading = false
        }
    }

    func loadPluginsSilently() {
        let startTime = Date()
        print("📦 [LOAD START] Loading plugins at \(startTime)")
        do {
            let loadedPlugins = try SharedStorage.loadPlugins()

            // Show plugins immediately
            plugins = loadedPlugins
            isLoading = false
            let duration = Date().timeIntervalSince(startTime)
            print("✅ [LOAD SUCCESS] Loaded \(plugins.count) plugins in \(String(format: "%.3f", duration))s")
            AppLogger.info("Auto-loaded \(plugins.count) plugins on iPad launch")

            // Enrich plugins with metadata and screenshots from Firebase in background
            Task {
                print("🔄 [iPad] Starting Firebase enrichment for \(loadedPlugins.count) plugins...")
                var mutablePlugins = loadedPlugins
                await PluginEnrichmentService.shared.batchFetchEnrichment(for: &mutablePlugins)
                await MainActor.run {
                    plugins = mutablePlugins
                    print("✅ [iPad] Enrichment complete - plugins updated with screenshot URLs")
                }
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ [LOAD FAILED] Failed after \(String(format: "%.3f", duration))s: \(error.localizedDescription)")
            AppLogger.error("Failed to auto-load plugins on iPad: \(error.localizedDescription)")
            plugins = []
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
