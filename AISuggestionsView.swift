// AISuggestionsView.swift — UI for AI plugin suggestions
import Combine
import Security
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Note: SuggestionCategory is defined in AIPluginSuggestions.swift (shared across platforms)

struct AISuggestionsView: View {
    var initialPlugin: PluginItem?  // Optional - can open without a plugin selected
    let ownedPlugins: [PluginItem]
    var initialOwnershipFilter: OwnershipFilter = .owned
    @StateObject private var aiService = AIPluginSuggestions()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: SuggestionCategory?
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with Ownership Filter - COMPACT
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("AI Suggestions")
                            .font(.system(size: 13, weight: .medium))
                            .lineSpacing(0)
                        if let category = selectedCategory {
                            Text("For: \(category.rawValue)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineSpacing(0)
                        } else if !searchText.isEmpty {
                            Text("Similar to: \(searchText)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineSpacing(0)
                        } else {
                            Text("Search for any plugin to find similar alternatives")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineSpacing(0)
                        }
                    }

                    Spacer()

                    // Regenerate Button - Center
                    if !searchText.isEmpty && !aiService.suggestions.isEmpty {
                        Button {
                            regenerateSuggestions()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                Text("Regenerate")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(red: 16/255, green: 73/255, blue: 135/255))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(aiService.isLoading)
                        .opacity(aiService.isLoading ? 0.5 : 1.0)
                    }

                    Spacer()

                    // Ownership Filter - Top Right - COMPACT (Own - Don't Own order, no All)
                    Picker("Show plugins", selection: $aiService.ownershipFilter) {
                        Text(OwnershipFilter.owned.rawValue)
                            .font(.system(size: 11))
                            .tag(OwnershipFilter.owned)
                        Text(OwnershipFilter.notOwned.rawValue)
                            .font(.system(size: 11))
                            .tag(OwnershipFilter.notOwned)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160, height: 22)
                    .controlSize(.small)
                    .tint(Color(red: 16/255, green: 73/255, blue: 135/255))
                    .onChange(of: aiService.ownershipFilter) { newValue in
                        guard !searchText.isEmpty else { return }

                        print("🎯 [Ownership Filter] Changed to \(newValue.rawValue)")

                        // Clear base suggestions when ownership filter changes
                        aiService.clearBaseSuggestions()

                        // Use the original plugin if available, otherwise create search plugin
                        let searchPlugin: PluginItem
                        if let original = initialPlugin {
                            // Preserve original plugin data (especially style!) when changing ownership filter
                            searchPlugin = original
                            print("🔄 [Ownership Filter Change] Using original plugin with style: '\(original.style)'")
                        } else {
                            // Create search plugin for manual searches
                            searchPlugin = PluginItem(
                                name: searchText,
                                publisher: "",
                                version: "",
                                type: "",
                                style: "",
                                architectures: "",
                                date: nil,
                                sizeBytes: 0,
                                path: "",
                                runtimeRequirement: "",
                                obsolete: false
                            )
                            print("🔍 [Ownership Filter Change] Using search plugin (no original)")
                        }

                        // Re-fetch suggestions with new filter
                        Task {
                            if let category = selectedCategory {
                                await aiService.fetchCategorySuggestions(for: category, plugin: searchPlugin, ownedPlugins: ownedPlugins)
                            } else {
                                await aiService.fetchSuggestions(for: searchPlugin, ownedPlugins: ownedPlugins)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                Spacer()

                // Plugin count at bottom center
                Text("\(aiService.suggestions.count) plugins shown")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineSpacing(0)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
            }
            .frame(height: 74)
            .padding(.vertical, 0)

            Divider()

            // Search Bar - COMPACT
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))

                TextField("Search plugin name...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        aiService.suggestions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }

                Button("Search") {
                    performSearch()
                }
                .buttonStyle(BlueGradientButtonStyle())
                .disabled(searchText.isEmpty)
            }
            .frame(height: 64)
            .padding(.horizontal, 10)
            .padding(.vertical, 0)
            .background(Color.gray.opacity(0.05))

            Divider()

            // Category Cloud - COMPACT
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(SuggestionCategory.allCases) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                guard !searchText.isEmpty else { return }

                                // Create search plugin with the CATEGORY as the style (not the original plugin's style!)
                                // This ensures we search for the category type, not the original plugin type
                                let categoryStyle = category.rawValue.lowercased()
                                let searchPlugin = PluginItem(
                                    name: searchText,
                                    publisher: initialPlugin?.publisher ?? "",
                                    version: "",
                                    type: categoryStyle,
                                    style: categoryStyle,  // USE CATEGORY as style!
                                    architectures: "",
                                    date: nil,
                                    sizeBytes: 0,
                                    path: "",
                                    runtimeRequirement: "",
                                    obsolete: false
                                )
                                print("🔄 [Category Switch] Created plugin with category style: '\(categoryStyle)' (category: \(category.rawValue))")

                                // Auto-switch to "Don't Own" when FREE category is clicked
                                if category == .free && aiService.ownershipFilter == .owned {
                                    print("🔄 [Category Switch] FREE clicked - auto-switching to Don't Own")
                                    aiService.ownershipFilter = .notOwned
                                }

                                // Reset tracking when switching categories
                                aiService.resetPreviouslyShown()

                                if selectedCategory == category {
                                    selectedCategory = nil
                                    Task { await aiService.fetchSuggestions(for: searchPlugin, ownedPlugins: ownedPlugins) }
                                } else {
                                    selectedCategory = category
                                    Task { await aiService.fetchCategorySuggestions(for: category, plugin: searchPlugin, ownedPlugins: ownedPlugins) }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 0)
            }
            .frame(height: 42)
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
                            SuggestionRow(suggestion: suggestion, ownedPlugins: ownedPlugins)
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
                    .buttonStyle(BlueGradientButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .background(Color(red: 18/255, green: 18/255, blue: 18/255))
        .preferredColorScheme(.dark)
        .onAppear {
            // Set initial ownership filter
            aiService.ownershipFilter = initialOwnershipFilter
            print("🎯 [AI Suggestions] Initial ownership filter: \(initialOwnershipFilter.rawValue)")

            // Auto-populate search if plugin was selected
            if let plugin = initialPlugin {
                searchText = plugin.name
                print("🔍 [AI Suggestions] Auto-populated search with: '\(plugin.name)'")

                // Auto-select "Your Alternatives" category for owned plugins
                selectedCategory = .ownedAlternatives
                print("🎯 [AI Suggestions] Auto-selected 'Your Alternatives' category")
            }

            // Auto-focus search field when window opens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
                print("⌨️ [AI Suggestions] Auto-focused search field")
            }
        }
        .task {
            // Auto-search if plugin was provided
            if let plugin = initialPlugin {
                print("\n🎬 [AISuggestionsView] .task starting auto-fetch")
                print("   Plugin: '\(plugin.name)'")
                print("   Style: '\(plugin.style)'")
                print("   Publisher: '\(plugin.publisher)'")
                print("   Calling fetchCategorySuggestions for .ownedAlternatives...")

                // Fetch "Your Alternatives" category suggestions
                await aiService.fetchCategorySuggestions(for: .ownedAlternatives, plugin: plugin, ownedPlugins: ownedPlugins)

                print("   ✅ fetchCategorySuggestions completed")
                print("   Suggestions count: \(aiService.suggestions.count)")
                print("   Error message: \(aiService.errorMessage ?? "none")")
                print("   Is loading: \(aiService.isLoading)")
                print("🎬 [AISuggestionsView] .task completed\n")
            }
        }
    }

    // MARK: - Regenerate Function
    private func regenerateSuggestions() {
        guard !searchText.isEmpty else { return }

        print("🔄 [Regenerate] User clicked Regenerate - fetching NEW suggestions (excluding previously shown)")
        print("   Currently shown: \(aiService.suggestions.count) suggestions")

        // Create search plugin
        let searchPlugin: PluginItem
        if let original = initialPlugin {
            searchPlugin = original
            print("🔄 [Regenerate] Using original plugin: '\(original.name)' (style: '\(original.style)')")
        } else {
            searchPlugin = PluginItem(
                name: searchText,
                publisher: "",
                version: "",
                type: "",
                style: "",
                architectures: "",
                date: nil,
                sizeBytes: 0,
                path: "",
                runtimeRequirement: "",
                obsolete: false
            )
            print("🔄 [Regenerate] Using search plugin: '\(searchText)'")
        }

        // Fetch suggestions in append mode (which automatically excludes previously shown)
        Task {
            if let category = selectedCategory {
                print("🔄 [Regenerate] Fetching category: '\(category.rawValue)'")
                await aiService.fetchCategorySuggestions(for: category, plugin: searchPlugin, ownedPlugins: ownedPlugins, appendMode: true)
            } else {
                print("🔄 [Regenerate] Fetching general suggestions")
                await aiService.fetchSuggestions(for: searchPlugin, ownedPlugins: ownedPlugins, appendMode: true)
            }
            print("✅ [Regenerate] Complete - now showing \(aiService.suggestions.count) suggestions")
        }
    }

    // MARK: - Search Function
    private func performSearch() {
        guard !searchText.isEmpty else { return }

        print("🔎 [AI Suggestions] User initiated search for: '\(searchText)'")

        // Create a temporary PluginItem for search
        let searchPlugin = PluginItem(
            name: searchText,
            publisher: "",
            version: "",
            type: "",
            style: "",
            architectures: "",
            date: nil,
            sizeBytes: 0,
            path: "",
            runtimeRequirement: "",
            obsolete: false
        )

        // Reset category selection when doing manual search
        selectedCategory = nil

        // Clear base suggestions for fresh start
        aiService.clearBaseSuggestions()

        // Fetch suggestions
        Task {
            await aiService.fetchSuggestions(for: searchPlugin, ownedPlugins: ownedPlugins)
        }
    }
}

struct SuggestionRow: View {
    let suggestion: PluginSuggestion
    let ownedPlugins: [PluginItem]
    @State private var showHeritageDetail = false

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
            // If heritage data exists, show detail sheet; otherwise open URL
            if suggestion.heritage != nil {
                print("👆 [Suggestion Row] User tapped '\(suggestion.name)' - showing heritage detail")
                showHeritageDetail = true
            } else {
                print("👆 [Suggestion Row] User tapped '\(suggestion.name)' - opening URL (no heritage)")

                #if os(macOS)
                NSWorkspace.shared.open(pluginURL)
                #else
                UIApplication.shared.open(pluginURL)
                #endif
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Icon - show star if heritage exists
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill((suggestion.heritage != nil ? Color.orange : Color.accentColor).opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: suggestion.heritage != nil ? "star.fill" : "waveform")
                        .foregroundColor(suggestion.heritage != nil ? .orange : .accentColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Show heritage teaser if available
                    if let heritage = suggestion.heritage, !(heritage.famousUses ?? []).isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.system(size: 10))
                            Text("Used on \((heritage.famousUses ?? []).count) hit song\((heritage.famousUses ?? []).count > 1 ? "s" : "")")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    }
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
                    .stroke(
                        suggestion.heritage != nil ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.2),
                        lineWidth: suggestion.heritage != nil ? 1 : 0.5
                    )
            )
            .overlay(
                // Blue arrow at top right corner - opens website
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(8)
                    }
                    Spacer()
                },
                alignment: .topTrailing
            )
            .overlay(
                // Orange info icon + chevron at bottom right corner - shows heritage (only for heritage plugins)
                Group {
                    if suggestion.heritage != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        }
                        .padding(8)
                    }
                },
                alignment: .bottomTrailing
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
        .sheet(isPresented: $showHeritageDetail) {
            if let heritage = suggestion.heritage {
                HeritageDetailView(heritage: heritage, pluginName: suggestion.name)
            }
        }
    }
}

// MARK: - Blue Gradient Button Style

struct BlueGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 16/255, green: 73/255, blue: 135/255), Color(red: 16/255, green: 73/255, blue: 135/255)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: SuggestionCategory
    let isSelected: Bool
    let action: () -> Void

    var blueGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 16/255, green: 73/255, blue: 135/255), Color(red: 16/255, green: 73/255, blue: 135/255)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.system(size: 12))
                .fontWeight(isSelected ? .semibold : .regular)
                .lineSpacing(0)
                .padding(.horizontal, 8)
                .frame(height: 40)
                .background {
                    if isSelected {
                        Capsule().fill(blueGradient)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 0.5)
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

// MARK: - Shared Window Manager

#if os(macOS)
class AISuggestionsWindowManager {
    static let shared = AISuggestionsWindowManager()
    private(set) var window: NSWindow?

    private init() {}

    func openOrUpdateWindow(plugin: PluginItem?, ownedPlugins: [PluginItem], ownershipFilter: OwnershipFilter = .owned) {
        print("📊 [AISuggestionsWindowManager] openOrUpdateWindow called with:")
        print("   Plugin: \(plugin?.name ?? "nil")")
        print("   Owned Plugins: \(ownedPlugins.count)")
        print("   Ownership Filter: \(ownershipFilter)")

        // If window already exists and is visible, update its content and bring to front
        if let existingWindow = window, existingWindow.isVisible {
            // Update the content with new plugin
            let hostingView = NSHostingView(
                rootView: AISuggestionsView(initialPlugin: plugin, ownedPlugins: ownedPlugins, initialOwnershipFilter: ownershipFilter)
            )
            hostingView.autoresizingMask = [.width, .height]
            hostingView.translatesAutoresizingMaskIntoConstraints = true

            existingWindow.contentView = hostingView
            existingWindow.makeKeyAndOrderFront(nil)
            if let plugin = plugin {
                print("🔄 [AI Suggestions] Reusing existing window for plugin: \(plugin.name)")
            } else {
                print("🔄 [AI Suggestions] Reusing existing window for general search")
            }
            return
        }

        // Create new window if none exists
        let hostingView = NSHostingView(
            rootView: AISuggestionsView(initialPlugin: plugin, ownedPlugins: ownedPlugins, initialOwnershipFilter: ownershipFilter)
        )

        // Configure hosting view
        hostingView.autoresizingMask = [.width, .height]
        hostingView.translatesAutoresizingMaskIntoConstraints = true

        // Create a STANDARD macOS window (not modal, not sheet)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingView
        newWindow.title = "AI Suggestions"
        newWindow.minSize = NSSize(width: 700, height: 600)
        newWindow.isReleasedWhenClosed = false
        newWindow.isMovableByWindowBackground = true
        newWindow.backgroundColor = NSColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0)

        // Store strong reference to keep window alive
        window = newWindow

        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        if let plugin = plugin {
            print("✨ [AI Suggestions] Created new window for plugin: \(plugin.name)")
        } else {
            print("✨ [AI Suggestions] Created new window for general search")
        }
    }
}
#endif

// MARK: - Compact Button for Table

struct AISuggestionsButton: View {
    let plugin: PluginItem?  // Now optional - can open without selection
    let ownedPlugins: [PluginItem]

    #if !os(macOS)
    @State private var showingSuggestions = false
    #endif

    var body: some View {
        Button {
            #if os(macOS)
            openAISuggestionsWindow()
            #else
            showingSuggestions = true
            #endif
        } label: {
            Label("AI Suggestions", systemImage: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.borderless)
        #if os(iOS)
        .popover(isPresented: $showingSuggestions) {
            NavigationStack {
                AISuggestionsView(initialPlugin: plugin, ownedPlugins: ownedPlugins)
            }
            .frame(
                width: min(400, UIScreen.main.bounds.width * 0.92),
                height: min(600, UIScreen.main.bounds.height * 0.75)
            )
            .presentationCompactAdaptation(.popover)
        }
        #endif
    }

    #if os(macOS)
    private func openAISuggestionsWindow() {
        AISuggestionsWindowManager.shared.openOrUpdateWindow(
            plugin: plugin,
            ownedPlugins: ownedPlugins,
            ownershipFilter: .owned
        )
    }
    #endif
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
                        .transaction { transaction in
                            transaction.animation = nil
                            transaction.disablesAnimations = true
                        }
                } else {
                    SecureField("sk-...", text: $manager.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: manager.apiKey) { newValue in
                            manager.saveAPIKey(newValue)
                        }
                        .transaction { transaction in
                            transaction.animation = nil
                            transaction.disablesAnimations = true
                        }
                }

                Button {
                    showingKey.toggle()
                } label: {
                    Image(systemName: showingKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
            .animation(nil, value: manager.apiKey)
            .animation(nil, value: showingKey)

            // Validation error message
            if let error = manager.validationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
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

// MARK: - Heritage Detail View (Main Sheet)

struct HeritageDetailView: View {
    let heritage: PluginHeritage
    let pluginName: String
    @Environment(\.dismiss) var dismiss

    init(heritage: PluginHeritage, pluginName: String) {
        self.heritage = heritage
        self.pluginName = pluginName
        print("🎭 [Heritage View] Opening heritage detail for: '\(pluginName)'")
        print("📊 [Heritage View] Famous uses count: \((heritage.famousUses ?? []).count)")
        print("🔧 [Heritage View] Has hardware model: \(heritage.modelsHardware != nil)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pluginName)
                            .font(.title)
                            .fontWeight(.bold)

                        // Hardware Model Info
                        if let models = heritage.modelsHardware {
                            ForEach(models) { hardware in
                                HardwareModelCard(hardware: hardware)
                            }
                        }

                        // Sonic Signature
                        SonicSignatureCard(signature: heritage.sonicSignature ?? "")
                    }
                    .padding(.horizontal)

                    // Famous Uses
                    if !(heritage.famousUses ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.orange)
                                Text("Used On These Hit Songs")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            ForEach(heritage.famousUses ?? []) { use in
                                FamousUseCard(use: use)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        openPluginWebsite()
                    }) {
                        Image(systemName: "arrow.up.right")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func openPluginWebsite() {
        let searchQuery = pluginName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pluginName
        if let url = URL(string: "https://www.google.com/search?q=\(searchQuery)+audio+plugin") {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
}

// MARK: - Hardware Model Card

struct HardwareModelCard: View {
    let hardware: HardwareModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundColor(.blue)
                Text("Models: \(hardware.name)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(hardware.description ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Label(String(hardware.yearReleased ?? ""), systemImage: "calendar")
                Label(hardware.priceRange ?? "", systemImage: "dollarsign.circle")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if let units = hardware.unitsSold {
                Label(units, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Sonic Signature Card

struct SonicSignatureCard: View {
    let signature: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.purple)
                Text("Sonic Signature")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text(signature)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Famous Use Card

struct FamousUseCard: View {
    let use: FamousUse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Song info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(use.artist) - \(use.songTitle)")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        if let album = use.album {
                            Text(album)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("(\(use.year))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let chart = use.chartPosition {
                            HStack(spacing: 2) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 10))
                                Text("#\(chart)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                // Context badge
                HStack(spacing: 4) {
                    Image(systemName: contextIcon)
                        .font(.system(size: 10))
                    Text((use.context?.displayName ?? "Unknown"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(contextColor.opacity(0.2))
                .foregroundColor(contextColor)
                .cornerRadius(6)
            }

            // What it was used on
            if !use.usedOn.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used on:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HeritageFlowLayout(spacing: 4) {
                        ForEach(use.usedOn, id: \.self) { item in
                            Text(item)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            // Engineer & Studio
            if use.engineer != nil || use.studio != nil {
                HStack(spacing: 12) {
                    if let engineer = use.engineer {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text(engineer)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let studio = use.studio {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 10))
                            Text(studio)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            // Quote
            if let quote = use.quote {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .offset(y: -2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(quote)
                            .font(.caption)
                            .italic()
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var contextIcon: String {
        switch use.context {
        case .tracking: return "mic.fill"
        case .mixing: return "slider.horizontal.3"
        case .mastering: return "waveform.badge.magnifyingglass"
        case .creative: return "sparkles"
        default: return "questionmark.circle"
        }
    }

    private var contextColor: Color {
        switch use.context {
        case .tracking: return .red
        case .mixing: return .blue
        case .mastering: return .purple
        case .creative: return .orange
        default: return .gray
        }
    }
}

// MARK: - Flow Layout (for wrapping tags)

private struct HeritageFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrangeRows(proposal: ProposedViewSize, subviews: Subviews) -> [(subviews: [LayoutSubview], height: CGFloat)] {
        var rows: [(subviews: [LayoutSubview], height: CGFloat)] = []
        var currentRow: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentWidth + size.width > maxWidth && !currentRow.isEmpty {
                rows.append((currentRow, currentHeight))
                currentRow = []
                currentWidth = 0
                currentHeight = 0
            }

            currentRow.append(subview)
            currentWidth += size.width + spacing
            currentHeight = max(currentHeight, size.height)
        }

        if !currentRow.isEmpty {
            rows.append((currentRow, currentHeight))
        }

        return rows
    }
}

#Preview {
    AISuggestionsView(
        initialPlugin: PluginItem(
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
