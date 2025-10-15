// AISuggestionsView.swift — iOS version of AI plugin suggestions
import SwiftUI
import Combine
import Security

// MARK: - Suggestion Categories

enum SuggestionCategory: String, CaseIterable, Identifiable {
    case free = "FREE"
    case mixing = "Mixing"
    case mastering = "Mastering"
    case vocals = "Vocals"
    case drums = "Drums"
    case instruments = "Instruments"
    case rock = "Rock"
    case pop = "Pop"
    case hipHop = "Hip Hop"
    case dub = "Dub"
    case house = "House"
    case techno = "Techno"
    case edm = "EDM"

    var id: String { rawValue }
}

struct AISuggestionsView: View {
    let plugin: PluginItem
    let ownedPlugins: [PluginItem]
    @StateObject private var aiService = AIPluginSuggestions()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: SuggestionCategory?

    var body: some View {
        VStack(spacing: 0) {
            // Category Cloud (compact)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SuggestionCategory.allCases) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                // Reset tracking when switching categories
                                aiService.resetPreviouslyShown()

                                if selectedCategory == category {
                                    selectedCategory = nil
                                    Task { await aiService.fetchSuggestions(for: plugin, ownedPlugins: ownedPlugins) }
                                } else {
                                    selectedCategory = category
                                    Task { await aiService.fetchCategorySuggestions(for: category, plugin: plugin, ownedPlugins: ownedPlugins) }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(Color(UIColor.systemBackground))

            Divider()

            // Content
            if aiService.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Finding similar plugins...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = aiService.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if aiService.suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No suggestions found")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(aiService.suggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion)
                        }

                        // Footer inline with content
                        if !aiService.isLoading && !aiService.suggestions.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: aiService.suggestions.first?.source == .openAI ? "sparkles" : "cpu")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text(aiService.suggestions.first?.source == .openAI ? "Powered by OpenAI" : "Local AI")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                }
            }
        }
        .navigationTitle(selectedCategory?.rawValue ?? "AI Suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await aiService.fetchSuggestions(for: plugin, ownedPlugins: ownedPlugins)
        }
    }
}

struct SuggestionRow: View {
    let suggestion: PluginSuggestion

    private var pluginURL: URL {
        // Direct links to plugin manufacturer pages
        let directLinks: [String: String] = [
            // FabFilter
            "FabFilter Pro-Q 3": "https://www.fabfilter.com/products/pro-q-3-equalizer-plug-in",
            "FabFilter Pro-C 2": "https://www.fabfilter.com/products/pro-c-2-compressor-plug-in",
            "FabFilter Pro-L 2": "https://www.fabfilter.com/products/pro-l-2-limiter-plug-in",
            "FabFilter Pro-R": "https://www.fabfilter.com/products/pro-r-reverb-plug-in",
            "FabFilter Saturn 2": "https://www.fabfilter.com/products/saturn-2-multiband-distortion-plug-in",

            // Valhalla DSP
            "Valhalla VintageVerb": "https://valhalladsp.com/shop/reverb/valhalla-vintage-verb/",
            "Valhalla Delay": "https://valhalladsp.com/shop/delay/valhalla-delay/",

            // Soundtoys
            "Soundtoys 5": "https://www.soundtoys.com/product/soundtoys-5/",
            "Soundtoys EchoBoy": "https://www.soundtoys.com/product/echoboy/",
            "Soundtoys Decapitator": "https://www.soundtoys.com/product/decapitator/",

            // iZotope
            "iZotope Ozone": "https://www.izotope.com/en/products/ozone.html",
            "iZotope RX": "https://www.izotope.com/en/products/rx.html",

            // Waves
            "Waves SSL E-Channel": "https://www.waves.com/plugins/ssl-e-channel",
            "Waves CLA-76": "https://www.waves.com/plugins/cla-76",

            // Universal Audio
            "UAD 1176": "https://www.uaudio.com/uad-plugins/compressors-limiters/1176.html",
            "UAD LA-2A": "https://www.uaudio.com/uad-plugins/compressors-limiters/la-2a.html",

            // Eventide
            "Eventide Blackhole": "https://www.eventideaudio.com/plug-ins/blackhole/",

            // Native Instruments
            "Native Instruments Komplete": "https://www.native-instruments.com/en/products/komplete/bundles/komplete-14/",
            "Kontakt 7": "https://www.native-instruments.com/en/products/komplete/samplers/kontakt-7/",

            // Other
            "Serum by Xfer": "https://xferrecords.com/products/serum",
            "Omnisphere 2": "https://www.spectrasonics.net/products/omnisphere/",
            "Melodyne": "https://www.celemony.com/en/melodyne/what-is-melodyne"
        ]

        // Try to find direct link, fallback to Google search
        if let directURL = directLinks[suggestion.name], let url = URL(string: directURL) {
            return url
        }

        // Try Google search with encoded query
        let query = suggestion.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? suggestion.name
        if let searchURL = URL(string: "https://www.google.com/search?q=\(query)+audio+plugin") {
            return searchURL
        }

        // Final safe fallback - this URL is guaranteed to be valid
        return URL(string: "https://www.google.com")!
    }

    var body: some View {
        Button {
            UIApplication.shared.open(pluginURL)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                // Icon (smaller)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(suggestion.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                            .foregroundColor(.accentColor)
                    }
                    Text(suggestion.reason)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: SuggestionCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Button for Detail View

struct AISuggestionsButton: View {
    let plugin: PluginItem
    let ownedPlugins: [PluginItem]
    @State private var showingSuggestions = false

    var body: some View {
        Button {
            showingSuggestions = true
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("AI Suggestions")
            }
        }
        .popover(isPresented: $showingSuggestions) {
            NavigationView {
                AISuggestionsView(plugin: plugin, ownedPlugins: ownedPlugins)
            }
            .navigationViewStyle(.stack)
            .frame(width: 400, height: 600)
            .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Settings Panel for OpenAI API Key

// Helper class to manage API key state
class APIKeyManager: ObservableObject {
    @Published var apiKey: String = ""

    init() {
        self.apiKey = loadAPIKey()
        migrateAPIKeyToKeychain()
    }

    private func loadAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "openai_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }

        return value
    }

    func saveAPIKey(_ value: String) {
        if value.isEmpty {
            // Delete from Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "openai_api_key"
            ]
            SecItemDelete(query as CFDictionary)
        } else {
            // Save to Keychain
            saveToKeychain(key: "openai_api_key", value: value)
        }
    }

    private func migrateAPIKeyToKeychain() {
        // Check if we need to migrate from old UserDefaults storage
        if let oldKey = UserDefaults.standard.string(forKey: "openai_api_key"), !oldKey.isEmpty {
            // Only migrate if Keychain doesn't already have a key
            if !keychainItemExists(key: "openai_api_key") {
                saveToKeychain(key: "openai_api_key", value: oldKey)
            }
            // Remove from UserDefaults for security
            UserDefaults.standard.removeObject(forKey: "openai_api_key")
        }
    }

    private func keychainItemExists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }
}

struct AISettingsView: View {
    @StateObject private var manager = APIKeyManager()
    @State private var showingKey: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("AI Suggestions")
                    .font(.headline)
            }

            Text("Optional: Add your OpenAI API key for smarter suggestions. Leave blank to use local AI only.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if showingKey {
                    TextField("sk-...", text: $manager.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: manager.apiKey) { newValue in
                            manager.saveAPIKey(newValue)
                        }
                } else {
                    SecureField("sk-...", text: $manager.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: manager.apiKey) { newValue in
                            manager.saveAPIKey(newValue)
                        }
                }

                Button {
                    showingKey.toggle()
                } label: {
                    Image(systemName: showingKey ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Get a free API key at")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let url = URL(string: "https://platform.openai.com/api-keys") {
                    Link("platform.openai.com", destination: url)
                        .font(.caption)
                }
            }

            if manager.apiKey.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Local AI mode (works offline)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                    Text("OpenAI mode (requires internet)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}
