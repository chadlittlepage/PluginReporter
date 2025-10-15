// AISuggestionsView.swift — UI for AI plugin suggestions
import SwiftUI
import Combine
import Security
#if os(iOS)
import UIKit
#endif

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
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Suggestions")
                        .font(.headline)
                    if let category = selectedCategory {
                        Text("For: \(category.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Similar to: \(plugin.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding()

            Divider()

            // Category Cloud
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)

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
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(aiService.suggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion)
                        }
                    }
                    .padding()
                }
            }

            // Footer with source indicator and Done button
            Divider()
            HStack {
                if !aiService.isLoading && !aiService.suggestions.isEmpty {
                    Image(systemName: aiService.suggestions.first?.source == .openAI ? "sparkles" : "cpu")
                        .foregroundColor(.secondary)
                    Text(aiService.suggestions.first?.source == .openAI ? "Powered by OpenAI" : "Local AI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .background(.ultraThinMaterial)
        #if os(macOS)
        .frame(width: 600, height: 550)
        #endif
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
            "FabFilter Timeless 3": "https://www.fabfilter.com/products/timeless-3-delay-plug-in",
            "FabFilter Timeless": "https://www.fabfilter.com/products/timeless-3-delay-plug-in",
            "FabFilter Volcano": "https://www.fabfilter.com/products/volcano-3-filter-plug-in",
            "FabFilter Effects Bundle": "https://www.fabfilter.com/shop",

            // Valhalla DSP
            "Valhalla VintageVerb": "https://valhalladsp.com/shop/reverb/valhalla-vintage-verb/",
            "Valhalla Delay": "https://valhalladsp.com/shop/delay/valhalla-delay/",
            "Valhalla UberMod": "https://valhalladsp.com/shop/modulation/valhalla-ubermod/",

            // Soundtoys
            "Soundtoys 5": "https://www.soundtoys.com/product/soundtoys-5/",
            "Soundtoys EchoBoy": "https://www.soundtoys.com/product/echoboy/",
            "Soundtoys Decapitator": "https://www.soundtoys.com/product/decapitator/",
            "Soundtoys PhaseMistress": "https://www.soundtoys.com/product/phasemistress/",
            "Soundtoys FilterFreak": "https://www.soundtoys.com/product/filterfreak/",
            "Soundtoys Little AlterBoy": "https://www.soundtoys.com/product/little-alterboy/",

            // iZotope
            "iZotope Ozone": "https://www.izotope.com/en/products/ozone.html",
            "iZotope Ozone EQ": "https://www.izotope.com/en/products/ozone.html",
            "iZotope Ozone Imager": "https://www.izotope.com/en/products/ozone-imager.html",
            "iZotope RX": "https://www.izotope.com/en/products/rx.html",
            "iZotope Trash 2": "https://www.izotope.com/en/products/trash.html",
            "iZotope Insight 2": "https://www.izotope.com/en/products/insight.html",
            "iZotope Relay": "https://www.izotope.com/en/products/relay.html",

            // Waves
            "Waves SSL E-Channel": "https://www.waves.com/plugins/ssl-e-channel",
            "Waves CLA-76": "https://www.waves.com/plugins/cla-76",
            "Waves CLA-2A": "https://www.waves.com/plugins/cla-2a",
            "Waves Q10": "https://www.waves.com/plugins/q10-equalizer",
            "Waves H-Reverb": "https://www.waves.com/plugins/h-reverb-hybrid-reverb",
            "Waves H-Delay": "https://www.waves.com/plugins/h-delay-hybrid-delay",
            "Waves MetaFlanger": "https://www.waves.com/plugins/metaflanger",
            "Waves Abbey Road TG": "https://www.waves.com/plugins/abbey-road-tg-mastering-chain",
            "Waves Abbey Road Saturator": "https://www.waves.com/plugins/abbey-road-saturator",
            "Waves Abbey Road Studio 3": "https://www.waves.com/plugins/abbey-road-studio-3",
            "Waves NS1": "https://www.waves.com/plugins/ns1-noise-suppressor",
            "Waves WLM Plus": "https://www.waves.com/plugins/wlm-loudness-meter",
            "Waves S1 Stereo Imager": "https://www.waves.com/plugins/s1-stereo-imager",
            "Waves InPhase": "https://www.waves.com/plugins/inphase",
            "Waves SoundShifter": "https://www.waves.com/plugins/soundshifter",
            "Waves Gold Bundle": "https://www.waves.com/bundles/gold",

            // Universal Audio
            "UAD 1176": "https://www.uaudio.com/uad-plugins/compressors-limiters/1176.html",
            "UAD LA-2A": "https://www.uaudio.com/uad-plugins/compressors-limiters/la-2a.html",
            "UAD Neve 1073": "https://www.uaudio.com/uad-plugins/equalizers/neve-1073.html",
            "UAD Ampex ATR-102": "https://www.uaudio.com/uad-plugins/tape-machines/ampex-atr-102.html",
            "UAD Dimension D": "https://www.uaudio.com/uad-plugins/modulation/dimension-d.html",
            "UAD Galaxy Tape Echo": "https://www.uaudio.com/uad-plugins/delay/galaxy-tape-echo.html",
            "UAD Moog Multimode Filter": "https://www.uaudio.com/uad-plugins/filters/moog-multimode-filter.html",
            "UAD Precision Mastering": "https://www.uaudio.com/uad-plugins/mastering.html",

            // Eventide
            "Eventide Blackhole": "https://www.eventideaudio.com/plug-ins/blackhole/",
            "Eventide H3000": "https://www.eventideaudio.com/plug-ins/h3000-factory/",
            "Eventide H910": "https://www.eventideaudio.com/plug-ins/h910-harmonizer/",
            "Eventide UltraChannel": "https://www.eventideaudio.com/plug-ins/ultrachannel/",
            "Eventide UltraTap": "https://www.eventideaudio.com/plug-ins/ultratap/",
            "Eventide UltraReverb": "https://www.eventideaudio.com/plug-ins/ultrareverb/",

            // Native Instruments
            "Native Instruments Komplete": "https://www.native-instruments.com/en/products/komplete/bundles/komplete-14/",
            "Native Instruments VC 76": "https://www.native-instruments.com/en/products/komplete/effects/vintage-compressors/",
            "Native Instruments Filter": "https://www.native-instruments.com/en/products/komplete/effects/",
            "Kontakt 7": "https://www.native-instruments.com/en/products/komplete/samplers/kontakt-7/",

            // Arturia
            "Arturia V Collection": "https://www.arturia.com/products/software-instruments/v-collection/overview",

            // Other Major Brands
            "Serum by Xfer": "https://xferrecords.com/products/serum",
            "Omnisphere 2": "https://www.spectrasonics.net/products/omnisphere/",
            "Melodyne": "https://www.celemony.com/en/melodyne/what-is-melodyne",
            "Auto-Tune Pro": "https://www.antarestech.com/product/auto-tune-pro/",
            "Lexicon PCM Native": "https://lexiconpro.com/en/products/pcm-native-reverb-plug-in-bundle",
            "Slate Digital FG-X": "https://slatedigital.com/fg-x/",
            "Plugin Alliance Black Box": "https://www.plugin-alliance.com/en/products/black_box_analog_design_hg-2.html",
            "Plugin Alliance Masterdesk": "https://www.plugin-alliance.com/en/products/townhouse_masterdesk.html",
            "Plugin Alliance LUFS Meter": "https://www.plugin-alliance.com/en/products/tb_lm2n.html",
            "Plugin Alliance bx_solo": "https://www.plugin-alliance.com/en/products/bx_solo.html",
            "Softube Saturation Knob": "https://www.softube.com/saturationknob",
            "DMG Audio EQuilibrium": "https://dmgaudio.com/equilibrium",
            "Seventh Heaven": "https://www.liquidsonics.com/software/seventh-heaven/",
            "Cedar DNS One": "https://www.cedaraudio.com/dns-one.html",
            "Accusonus ERA Bundle": "https://accusonus.com/products/audio-repair/era-bundle-pro",
            "Acon Digital DeNoise": "https://acondigital.com/products/denoise/",
            "Goodhertz CanOpener": "https://goodhertz.com/canopener-studio/",
            "Dear Reality dearVR": "https://www.dear-reality.com/products/dearvr-pro",
            "Voxengo SPAN": "https://www.voxengo.com/product/span/",
            "Youlean Loudness Meter": "https://youlean.co/youlean-loudness-meter/",
            "Nugen VisLM": "https://nugenaudio.com/vislm/",
            "Kilohearts Multipass": "https://kilohearts.com/products/multipass",
            "SoundID Reference": "https://www.sonarworks.com/soundid-reference",
            "Sonimus Burnley 73": "https://www.sonimus.com/products/burnley-73/"
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
            #if os(macOS)
            NSWorkspace.shared.open(pluginURL)
            #else
            UIApplication.shared.open(pluginURL)
            #endif
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "waveform")
                        .foregroundColor(.accentColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(suggestion.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            #if os(macOS)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
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
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : .ultraThinMaterial)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            #if os(macOS)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
    }
}

// MARK: - Compact Button for Table

struct AISuggestionsButton: View {
    let plugin: PluginItem
    let ownedPlugins: [PluginItem]
    @State private var showingSuggestions = false

    var body: some View {
        Button {
            showingSuggestions = true
        } label: {
            Label("AI Suggestions", systemImage: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.borderless)
        #if os(iOS)
        .popover(isPresented: $showingSuggestions) {
            NavigationView {
                AISuggestionsView(plugin: plugin, ownedPlugins: ownedPlugins)
            }
            .navigationViewStyle(.stack)
            .frame(
                width: min(400, UIScreen.main.bounds.width * 0.92),
                height: min(600, UIScreen.main.bounds.height * 0.75)
            )
            .presentationCompactAdaptation(.popover)
        }
        #else
        .sheet(isPresented: $showingSuggestions) {
            AISuggestionsView(plugin: plugin, ownedPlugins: ownedPlugins)
        }
        #endif
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
            Text("Optional: Add your OpenAI API key for smarter suggestions. Leave blank to use local AI only.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if showingKey {
                    TextField("sk-...", text: $manager.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: manager.apiKey) { newValue in
                            manager.saveAPIKey(newValue)
                        }
                } else {
                    SecureField("sk-...", text: $manager.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: manager.apiKey) { newValue in
                            manager.saveAPIKey(newValue)
                        }
                }

                Button {
                    showingKey.toggle()
                } label: {
                    Image(systemName: showingKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Get a free API key at")
                    .font(.caption)
                if let url = URL(string: "https://platform.openai.com/api-keys") {
                    Link("platform.openai.com", destination: url)
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)

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
    }
}

#Preview {
    AISuggestionsView(
        plugin: PluginItem(
            name: "FabFilter Pro-Q 3",
            publisher: "FabFilter",
            version: "3.0",
            type: "AU",
            style: "EQ",
            architectures: "Apple, Intel 64",
            date: nil,
            sizeBytes: 0,
            path: "/Library/Audio/Plug-Ins/Components/FabFilter Pro-Q 3.component",
            runtimeRequirement: "Universal",
            obsolete: false
        ),
        ownedPlugins: []
    )
}
