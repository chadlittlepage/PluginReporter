//
//  ContentView.swift
//  PluginReporter (iOS)
//
//  Standalone iOS app - no CloudSync for now
//

import SwiftUI

// MARK: - Main iOS View

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
            // Auto-load plugins on launch (simulating iCloud sync)
            if plugins.isEmpty {
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

    func loadPlugins() {
        // Load from shared storage (same location as macOS)
        isLoading = true

        guard let url = SharedStorage.pluginsURL else {
            debugMessage = "❌ Could not determine plugins URL"
            AppLogger.error("Could not get plugins URL")
            showDebugAlert = true
            isLoading = false
            return
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        var fileInfo = ""
        if exists, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            let size = attrs[.size] as? Int64 ?? 0
            fileInfo = "\nFile size: \(size) bytes"
        }

        AppLogger.debug("iPhone loading from: \(url.path), exists: \(exists)")
        debugMessage = "📍 Loading from:\n\(url.path)\n\n✅ Exists: \(exists)\(fileInfo)"

        do {
            let loadedPlugins = try SharedStorage.loadPlugins()
            AppLogger.info("Loaded \(loadedPlugins.count) plugins on iPhone")

            plugins = loadedPlugins
            isLoading = false

            if !plugins.isEmpty {
                debugMessage += "\n\n✅ Loaded \(plugins.count) plugins successfully!"
            } else {
                debugMessage += "\n\n⚠️ File loaded but parsed 0 plugins"
                debugMessage += "\n\nCheck Xcode console for details"
            }

            // Always show the debug alert when manually triggered
            showDebugAlert = true
        } catch {
            AppLogger.error("Failed to load plugins: \(error.localizedDescription)")
            debugMessage += "\n\n❌ Error: \(error.localizedDescription)"
            showDebugAlert = true
            plugins = []
            isLoading = false
        }
    }

    func loadPluginsFromFile() {
        AppLogger.debug("iPhone loadPluginsFromFile called")
        loadPlugins()
    }

    func loadPluginsSilently() {
        // Auto-load on launch without showing alerts
        do {
            let loadedPlugins = try SharedStorage.loadPlugins()
            plugins = loadedPlugins
            isLoading = false
            AppLogger.info("Auto-loaded \(plugins.count) plugins on launch")
        } catch {
            AppLogger.error("Failed to auto-load plugins: \(error.localizedDescription)")
            plugins = []
            isLoading = false
        }
    }

    func loadPluginsFromURL(_ url: URL) {
        do {
            // Validate file exists and is readable
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                debugMessage = "Error: File is not readable at \(url.path)"
                showDebugAlert = true
                isLoading = false
                return
            }

            let data = try Data(contentsOf: url)

            // Validate JSON format
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                debugMessage = "Error: Invalid JSON format in \(url.lastPathComponent)"
                showDebugAlert = true
                isLoading = false
                return
            }

            plugins = jsonArray.compactMap { dict -> PluginItem? in
                guard let name = dict["Name"] as? String,
                      let type = dict["Type"] as? String else {
                    return nil
                }

                let dateInterval = dict["Date"] as? Double ?? 0
                let date = dateInterval > 0 ? Date(timeIntervalSince1970: dateInterval) : nil

                return PluginItem(
                    name: name,
                    publisher: dict["Publisher"] as? String ?? "",
                    version: dict["Version"] as? String ?? "",
                    type: type,
                    style: dict["Style"] as? String ?? "",
                    architectures: dict["Architectures"] as? String ?? "",
                    date: date,
                    sizeBytes: Int64(dict["SizeBytes"] as? Int ?? 0),
                    path: dict["Path"] as? String ?? "",
                    runtimeRequirement: dict["Requirement"] as? String ?? "",
                    obsolete: dict["Obsolete"] as? Bool ?? false
                )
            }
            isLoading = false
        } catch let error as NSError {
            let errorDescription: String
            switch error.domain {
            case NSCocoaErrorDomain:
                if error.code == NSFileReadNoSuchFileError {
                    errorDescription = "File not found"
                } else if error.code == NSFileReadNoPermissionError {
                    errorDescription = "Permission denied"
                } else {
                    errorDescription = "File read error: \(error.localizedDescription)"
                }
            default:
                errorDescription = "Failed to load plugins: \(error.localizedDescription)"
            }

            debugMessage = errorDescription
            showDebugAlert = true
            isLoading = false
        }
    }
}

// MARK: - Navigation Bar Appearance

struct NavigationBarModifier: ViewModifier {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 30, weight: .bold)
        ]
        // Reduce top padding
        UINavigationBar.appearance().layoutMargins.top = 0
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    func body(content: Content) -> some View {
        content
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
