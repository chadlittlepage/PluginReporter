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
    @State private var hasLoadedOnce = false
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
        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                Group {
                    if selectedTab == 0 {
                        PluginListView(plugins: plugins, filteredPluginsForExport: $filteredPlugins)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height) // Fixed size from parent
                .ignoresSafeArea(.keyboard) // Don't resize for keyboard
                .tabItem {
                    Label("Plugins", systemImage: "music.note.list")
                }
                .tag(0)

                Group {
                    if selectedTab == 1 {
                        SettingsView(onImport: loadPluginsFromFile)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height) // Fixed size from parent
                .ignoresSafeArea(.keyboard) // Don't resize for keyboard
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)

                Group {
                    if selectedTab == 2 {
                        ExportView(plugins: filteredPlugins)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height) // Fixed size from parent
                .ignoresSafeArea(.keyboard) // Don't resize for keyboard
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)
            }
            .tabViewStyle(.automatic) // Use system default WITHOUT page animation
            .frame(width: geometry.size.width, height: geometry.size.height) // Lock TabView size
            .ignoresSafeArea(.keyboard, edges: .bottom) // Ignore keyboard throughout
            .transaction { transaction in
                transaction.animation = nil // Kill ALL animations
                transaction.disablesAnimations = true // FORCE disable
            }
            .preferredColorScheme(colorScheme)
            .animation(.linear(duration: 0), value: appearance) // Instant transition
            .animation(.linear(duration: 0), value: selectedTab) // Instant tab change
            .onChange(of: selectedTab) { _ in
                // Suppress only the bounce/resize animation
                UIView.animate(withDuration: 0) {
                    // Instant layout change
                }
            }
        }
        .ignoresSafeArea() // GeometryReader ignores all safe areas
        .onAppear {
            // INSTANT LOAD - Load plugins immediately without async delay
            if !hasLoadedOnce {
                hasLoadedOnce = true
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
        AppLogger.debug("iPad loadPluginsFromFile called")
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

    func loadPluginsSilentlyAsync() async {
        // Auto-load on launch without showing alerts - async version
        do {
            let loadedPlugins = try await Task.detached {
                try SharedStorage.loadPlugins()
            }.value
            await MainActor.run {
                plugins = loadedPlugins
                isLoading = false
            }
        } catch {
            await MainActor.run {
                plugins = []
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}
