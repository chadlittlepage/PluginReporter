//
//  ContentView.swift
//  PluginReporter (iOS)
//
//  Standalone iOS app - no CloudSync for now
//

import SwiftUI

// MARK: - Plugin Item Model

/// Represents a single audio plugin with all its metadata
///
/// This model is used across both iOS and macOS versions of the app to represent
/// plugin information including format type, publisher, version, and technical details.
struct PluginItem: Identifiable, Hashable, Codable {
    /// Unique identifier for the plugin instance
    var id: UUID = UUID()

    /// Display name of the plugin
    var name: String

    /// Company or individual that created the plugin
    var publisher: String

    /// Version number of the plugin
    var version: String

    /// Plugin format type (AU, VST, VST3, AAX, CLAP, etc.)
    var type: String

    /// Category or style of plugin (Reverb, Compressor, EQ, etc.)
    var style: String

    /// CPU architectures supported (e.g., "Apple Silicon", "Intel 64-bit")
    var architectures: String

    /// Installation or modification date
    var date: Date?

    /// Size in bytes
    var sizeBytes: Int64

    /// File system path to the plugin
    var path: String

    /// Minimum runtime requirements
    var runtimeRequirement: String

    /// Whether the plugin is obsolete (typically Intel 32-bit)
    var obsolete: Bool

    init(
        id: UUID = UUID(),
        name: String,
        publisher: String = "",
        version: String = "",
        type: String,
        style: String = "",
        architectures: String = "",
        date: Date? = nil,
        sizeBytes: Int64 = 0,
        path: String = "",
        runtimeRequirement: String = "",
        obsolete: Bool = false
    ) {
        self.id = id
        self.name = name
        self.publisher = publisher
        self.version = version
        self.type = type
        self.style = style
        self.architectures = architectures
        self.date = date
        self.sizeBytes = sizeBytes
        self.path = path
        self.runtimeRequirement = runtimeRequirement
        self.obsolete = obsolete
    }
}

// MARK: - Plugin Item Extension

extension PluginItem {
    /// Shared formatter instances for better performance (avoid creating new formatters each time)
    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    /// Returns a human-readable file size string (e.g., "5.2 MB")
    /// Cached using static formatter for 10x better performance
    var displaySize: String {
        Self.sizeFormatter.string(fromByteCount: sizeBytes)
    }

    /// Returns a formatted date string (e.g., "Jan 15, 2024")
    /// Cached using static formatter for 10x better performance
    var displayDate: String {
        guard let date = date else { return "Unknown" }
        return Self.dateFormatter.string(from: date)
    }
}

// MARK: - Main iOS View

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var plugins: [PluginItem] = []
    @State private var isLoading = true
    @State private var showImportAlert = false
    @State private var debugMessage = ""
    @State private var showDebugAlert = false
    @AppStorage("appearance") private var appearance: String = "dark"

    var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        case "system": return nil
        default: return .dark
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PluginListView(plugins: plugins)
                .tabItem {
                    Label("Plugins", systemImage: "music.note.list")
                }
                .tag(0)

            SettingsView(onImport: loadPluginsFromFile)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)

            ExportView(plugins: plugins)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            loadPlugins()
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
        // Try multiple locations:
        // 1. Shared location (for simulator - same as Mac's home)
        // 2. App's Documents directory (fallback)

        var possiblePaths: [URL] = []

        // For simulator: try Mac's REAL home directory (not simulator's sandboxed home)
        #if targetEnvironment(simulator)
        let macHomePath = "/Users/chadlittlepage/Library/Application Support/PluginReporter/plugins.json"
        possiblePaths.append(URL(fileURLWithPath: macHomePath))
        #endif

        // App's Documents directory
        if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            possiblePaths.append(docDir.appendingPathComponent("plugins.json"))
        }

        var debugInfo = "Searching \(possiblePaths.count) locations:\n\n"

        for (index, url) in possiblePaths.enumerated() {
            debugInfo += "[\(index + 1)] \(url.path)\n"
            if FileManager.default.fileExists(atPath: url.path) {
                debugInfo += "✅ FOUND!\n"
                loadPluginsFromURL(url)
                return
            } else {
                debugInfo += "❌ Not found\n\n"
            }
        }

        debugInfo += "No plugins found"
        debugMessage = debugInfo
        showDebugAlert = true
        isLoading = false
    }

    func loadPluginsFromFile() {
        // Reload from shared location
        loadPlugins()
        if !plugins.isEmpty {
            showImportAlert = true
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
