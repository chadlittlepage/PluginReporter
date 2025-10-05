// AIPluginSuggestions.swift — Hybrid AI suggestion system (OpenAI + Local fallback)
import Foundation

/// AI-powered plugin suggestion service
@MainActor
class AIPluginSuggestions: ObservableObject {
    @Published var suggestions: [PluginSuggestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Track previously shown suggestions to provide variety on "More" clicks
    private var previouslyShownSuggestions: Set<String> = []

    // OpenAI API key (optional - falls back to local if not set)
    private var openAIKey: String? {
        // User can set this in Settings or leave empty for local-only mode
        UserDefaults.standard.string(forKey: "openai_api_key")
    }

    /// Reset tracking (call when switching plugins or categories)
    func resetPreviouslyShown() {
        previouslyShownSuggestions.removeAll()
    }

    /// Fetch suggestions for a plugin (tries OpenAI with web knowledge, falls back to local)
    func fetchSuggestions(for plugin: PluginItem, ownedPlugins: [PluginItem], appendMode: Bool = false) async {
        isLoading = true
        errorMessage = nil

        // Combine owned plugins + previously shown suggestions to exclude
        let excludedPlugins = ownedPlugins + previouslyShownSuggestions.map { name in
            PluginItem(name: name, publisher: "", version: "", type: "", style: "",
                      architectures: "", date: nil, sizeBytes: 0, path: "",
                      runtimeRequirement: "", obsolete: false)
        }

        // Try OpenAI first if API key is available (uses GPT's extensive plugin knowledge)
        if let apiKey = openAIKey, !apiKey.isEmpty {
            do {
                var newSuggestions = try await fetchFromOpenAI(plugin: plugin, apiKey: apiKey, ownedPlugins: excludedPlugins)

                // If OpenAI returns good suggestions, use them
                if newSuggestions.count >= 3 {
                    // Track these suggestions
                    for suggestion in newSuggestions {
                        previouslyShownSuggestions.insert(suggestion.name)
                    }

                    // Append or replace based on mode
                    if appendMode {
                        suggestions.append(contentsOf: newSuggestions)
                    } else {
                        suggestions = newSuggestions
                    }

                    isLoading = false
                    return
                }
            } catch {
                AppLogger.warning("OpenAI API failed, using local suggestions: \(error.localizedDescription)")
                // Fall through to local AI
            }
        }

        // Fallback to local AI (comprehensive database)
        var newSuggestions = await fetchFromLocal(plugin: plugin, ownedPlugins: excludedPlugins)

        // Limit to 5 suggestions per request (so "More" has more to show)
        let limitedSuggestions = Array(newSuggestions.prefix(5))

        // Track these suggestions
        for suggestion in limitedSuggestions {
            previouslyShownSuggestions.insert(suggestion.name)
        }

        // Append or replace based on mode
        if appendMode {
            suggestions.append(contentsOf: limitedSuggestions)
        } else {
            suggestions = limitedSuggestions
        }

        isLoading = false
    }

    /// Fetch category-specific suggestions (workflow/genre based, filtered by plugin style)
    func fetchCategorySuggestions(for category: SuggestionCategory, plugin: PluginItem, ownedPlugins: [PluginItem], appendMode: Bool = false) async {
        isLoading = true
        errorMessage = nil

        // Combine owned plugins + previously shown suggestions to exclude
        let excludedPlugins = ownedPlugins + previouslyShownSuggestions.map { name in
            PluginItem(name: name, publisher: "", version: "", type: "", style: "",
                      architectures: "", date: nil, sizeBytes: 0, path: "",
                      runtimeRequirement: "", obsolete: false)
        }

        // Handle FREE category specially
        if category == .free {
            // Try OpenAI for free plugin suggestions if API key is available
            if let apiKey = openAIKey, !apiKey.isEmpty {
                do {
                    var newSuggestions = try await fetchFreePluginsFromOpenAI(plugin: plugin, apiKey: apiKey, ownedPlugins: excludedPlugins)

                    if newSuggestions.count >= 3 {
                        for suggestion in newSuggestions {
                            previouslyShownSuggestions.insert(suggestion.name)
                        }

                        if appendMode {
                            suggestions.append(contentsOf: newSuggestions)
                        } else {
                            suggestions = newSuggestions
                        }

                        isLoading = false
                        return
                    }
                } catch {
                    AppLogger.warning("OpenAI free plugins API failed, using local suggestions: \(error.localizedDescription)")
                }
            }

            // Fallback to local free plugins
            var newSuggestions = CategoryPluginKnowledge.getFreeSuggestions(pluginStyle: plugin.style)
            newSuggestions = filterOwnedPlugins(newSuggestions, ownedPlugins: excludedPlugins)

            let limitedSuggestions = Array(newSuggestions.prefix(5))

            for suggestion in limitedSuggestions {
                previouslyShownSuggestions.insert(suggestion.name)
            }

            if appendMode {
                suggestions.append(contentsOf: limitedSuggestions)
            } else {
                suggestions = limitedSuggestions
            }

            isLoading = false
            return
        }

        // Use local knowledge base for category suggestions, filtered by plugin style
        var newSuggestions = CategoryPluginKnowledge.getSuggestions(for: category, pluginStyle: plugin.style)
        newSuggestions = filterOwnedPlugins(newSuggestions, ownedPlugins: excludedPlugins)

        // Limit to 5 suggestions per request (so "More" has more to show)
        let limitedSuggestions = Array(newSuggestions.prefix(5))

        // Track these suggestions
        for suggestion in limitedSuggestions {
            previouslyShownSuggestions.insert(suggestion.name)
        }

        // Append or replace based on mode
        if appendMode {
            suggestions.append(contentsOf: limitedSuggestions)
        } else {
            suggestions = limitedSuggestions
        }

        isLoading = false
    }

    // MARK: - OpenAI Integration

    private func fetchFromOpenAI(plugin: PluginItem, apiKey: String, ownedPlugins: [PluginItem]) async throws -> [PluginSuggestion] {
        let prompt = buildPrompt(for: plugin, excluding: ownedPlugins)

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",  // Better model with more recent plugin knowledge
            "messages": [
                ["role": "system", "content": "You are an expert audio engineer with extensive knowledge of professional audio plugins from companies like Plugin Alliance, FabFilter, Waves, UAD, iZotope, Soundtoys, Arturia, Native Instruments, and others. Suggest the best similar alternatives based on your knowledge of current plugin offerings."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 400,  // More tokens for better suggestions
            "temperature": 0.8  // Slightly more creative for variety
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiError("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw AIError.invalidResponse
        }

        let suggestions = parseOpenAIResponse(content: content, plugin: plugin)
        return filterOwnedPlugins(suggestions, ownedPlugins: ownedPlugins)
    }

    private func fetchFreePluginsFromOpenAI(plugin: PluginItem, apiKey: String, ownedPlugins: [PluginItem]) async throws -> [PluginSuggestion] {
        let prompt = buildFreePrompt(for: plugin, excluding: ownedPlugins)

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are an expert audio engineer with extensive knowledge of FREE audio plugins. Focus only on completely free plugins, not free trials or lite versions."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 400,
            "temperature": 0.8
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiError("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw AIError.invalidResponse
        }

        let suggestions = parseOpenAIResponse(content: content, plugin: plugin)
        return filterOwnedPlugins(suggestions, ownedPlugins: ownedPlugins)
    }

    private func buildPrompt(for plugin: PluginItem, excluding ownedPlugins: [PluginItem]) -> String {
        let ownedNames = ownedPlugins.map { $0.name }.joined(separator: ", ")

        return """
        Suggest 5-8 professional audio plugins similar to:
        Name: \(plugin.name)
        Type: \(plugin.type)
        Category/Style: \(plugin.style)
        Publisher: \(plugin.publisher)

        REQUIREMENTS:
        1. SAME CATEGORY ONLY: "\(plugin.style)" - Match this category EXACTLY
           - Instrument → instruments/synths/samplers only
           - EQ → EQ plugins only
           - Dynamics → compressors/limiters only
           - Reverb → reverb plugins only
           - etc.

        2. QUALITY: Suggest industry-standard, professional plugins from reputable companies:
           - Plugin Alliance (bx_digital, Brainworx, etc.)
           - FabFilter (Pro-Q, Pro-C, Pro-L, Saturn, etc.)
           - Waves (SSL, CLA, Abbey Road, etc.)
           - Universal Audio (UAD plugins)
           - iZotope (Ozone, Neutron, RX, etc.)
           - Soundtoys (Decapitator, EchoBoy, etc.)
           - Native Instruments (Komplete, Kontakt, etc.)
           - Arturia (V Collection, etc.)
           - Eventide, Slate Digital, Valhalla DSP, and other top brands

        3. VARIETY: Mix well-known and lesser-known alternatives

        4. EXCLUDE these owned plugins:
        \(ownedNames.isEmpty ? "None" : ownedNames)

        Format as:
        1. Plugin Name - Brief reason (why it's similar/alternative)
        2. Plugin Name - Brief reason
        etc.

        Prioritize current, actively-developed plugins with good reputation in 2024-2025.
        """
    }

    private func buildFreePrompt(for plugin: PluginItem, excluding ownedPlugins: [PluginItem]) -> String {
        let ownedNames = ownedPlugins.map { $0.name }.joined(separator: ", ")

        return """
        Suggest 5-8 FREE audio plugins similar to:
        Name: \(plugin.name)
        Type: \(plugin.type)
        Category/Style: \(plugin.style)

        REQUIREMENTS:
        1. MUST BE 100% FREE - No trials, no lite versions, completely free plugins only
        2. SAME CATEGORY: "\(plugin.style)" - Match this category
        3. QUALITY: Suggest well-known free plugins from reputable developers:
           - TDR (Tokyo Dawn Records) - TDR Nova, Kotelnikov, VOS SlickEQ
           - Voxengo - Span, Marvel GEQ, OldSkoolVerb
           - Variety of Sound - ThrillseekerLA, Nasty DLA
           - Melda Production - MFreeFXBundle
           - Native Instruments - Komplete Start
           - Spitfire Audio LABS
           - Other trusted free plugin developers

        4. EXCLUDE these owned plugins:
        \(ownedNames.isEmpty ? "None" : ownedNames)

        Format as:
        1. Plugin Name - Brief reason
        2. Plugin Name - Brief reason
        etc.

        Focus on currently available, actively maintained FREE plugins (2024-2025).
        """
    }

    private func parseOpenAIResponse(content: String, plugin: PluginItem) -> [PluginSuggestion] {
        // Parse numbered list from GPT response
        let lines = content.split(separator: "\n")
        var suggestions: [PluginSuggestion] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Match "1. Plugin Name - Reason" or "1) Plugin Name - Reason"
            if let match = trimmed.range(of: #"^\d+[\.)]\s*(.+?)\s*-\s*(.+)$"#, options: .regularExpression) {
                let content = String(trimmed[match])
                let parts = content.split(separator: "-", maxSplits: 1)
                if parts.count == 2 {
                    let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: #"^\d+[\.)]\s*"#, with: "", options: .regularExpression)
                    let reason = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    suggestions.append(PluginSuggestion(
                        name: name,
                        reason: reason,
                        source: .openAI
                    ))
                }
            }
        }

        return suggestions.isEmpty ? [PluginSuggestion(name: "No suggestions found", reason: "Try a different plugin", source: .local)] : suggestions
    }

    // MARK: - Filtering Helper

    private func filterOwnedPlugins(_ suggestions: [PluginSuggestion], ownedPlugins: [PluginItem]) -> [PluginSuggestion] {
        let ownedNames = Set(ownedPlugins.map { $0.name.lowercased() })

        return suggestions.filter { suggestion in
            let suggestionName = suggestion.name.lowercased()
            // Check if the suggestion name matches any owned plugin
            return !ownedNames.contains(where: { ownedName in
                // Exact match or contains match (handles versions like "Pro-Q 3" vs "Pro-Q")
                suggestionName.contains(ownedName) || ownedName.contains(suggestionName)
            })
        }
    }

    // MARK: - Local AI (Fallback)

    private func fetchFromLocal(plugin: PluginItem, ownedPlugins: [PluginItem]) async -> [PluginSuggestion] {
        // Local knowledge base of common plugin alternatives
        let suggestions = LocalPluginKnowledge.getSuggestions(for: plugin)
        return filterOwnedPlugins(suggestions, ownedPlugins: ownedPlugins)
    }
}

// MARK: - Models

struct PluginSuggestion: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let reason: String
    let source: SuggestionSource
}

enum SuggestionSource {
    case openAI
    case local
}

enum AIError: Error {
    case apiError(String)
    case invalidResponse
    case networkError
}

// MARK: - OpenAI Response Models

private struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

// MARK: - Local Plugin Knowledge Database

struct LocalPluginKnowledge {
    static func getSuggestions(for plugin: PluginItem) -> [PluginSuggestion] {
        let name = plugin.name.lowercased()
        let type = plugin.type.uppercased()
        let publisher = plugin.publisher.lowercased()
        let style = plugin.style.lowercased()

        // Common plugin categories and alternatives
        var suggestions: [PluginSuggestion] = []

        // PRIORITY: Match by Style first (most accurate) - COMPREHENSIVE COVERAGE
        switch style {
        case "instrument":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Arturia V Collection", reason: "Vintage synthesizer collection", source: .local),
                PluginSuggestion(name: "Native Instruments Komplete", reason: "Comprehensive instrument bundle", source: .local),
                PluginSuggestion(name: "Serum by Xfer", reason: "Popular wavetable synthesizer", source: .local),
                PluginSuggestion(name: "Omnisphere 2", reason: "Powerful hybrid synthesizer", source: .local),
                PluginSuggestion(name: "Kontakt 7", reason: "Industry standard sampler", source: .local)
            ])

        case "eq":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Industry standard EQ with excellent workflow", source: .local),
                PluginSuggestion(name: "iZotope Ozone EQ", reason: "Professional mastering EQ", source: .local),
                PluginSuggestion(name: "Waves SSL E-Channel", reason: "SSL console EQ/dynamics", source: .local),
                PluginSuggestion(name: "UAD Neve 1073", reason: "Vintage console EQ emulation", source: .local),
                PluginSuggestion(name: "DMG Audio EQuilibrium", reason: "High-end transparent EQ", source: .local),
                PluginSuggestion(name: "Sonimus Burnley 73", reason: "Affordable Neve-style EQ", source: .local),
                PluginSuggestion(name: "Waves Q10", reason: "Classic 10-band parametric EQ", source: .local),
                PluginSuggestion(name: "Plugin Alliance bx_digital V3", reason: "Mid-side mastering EQ", source: .local),
                PluginSuggestion(name: "Waves API 550", reason: "Classic API console EQ", source: .local),
                PluginSuggestion(name: "UAD Pultec EQP-1A", reason: "Legendary tube EQ", source: .local),
                PluginSuggestion(name: "Slate Digital Virtual Mix Rack", reason: "Analog console emulation EQ", source: .local),
                PluginSuggestion(name: "TDR Nova", reason: "Free dynamic EQ", source: .local),
                PluginSuggestion(name: "Tone Empire Goliath", reason: "Modern mastering EQ", source: .local),
                PluginSuggestion(name: "Kirchhoff EQ", reason: "Zero-latency mastering EQ", source: .local),
                PluginSuggestion(name: "SSL Native Channel Strip", reason: "SSL console channel EQ", source: .local)
            ])

        case "dynamics":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "Versatile modern compressor", source: .local),
                PluginSuggestion(name: "UAD 1176", reason: "Classic FET compressor", source: .local),
                PluginSuggestion(name: "Waves CLA-76", reason: "Popular 1176 emulation", source: .local),
                PluginSuggestion(name: "Slate Digital FG-X", reason: "Mastering compressor/limiter", source: .local),
                PluginSuggestion(name: "UAD LA-2A", reason: "Legendary optical compressor", source: .local),
                PluginSuggestion(name: "Waves CLA-2A", reason: "LA-2A emulation", source: .local),
                PluginSuggestion(name: "Native Instruments VC 76", reason: "Affordable vintage compressor", source: .local),
                PluginSuggestion(name: "Waves SSL G-Master Buss", reason: "Mix glue compression", source: .local),
                PluginSuggestion(name: "Empirical Labs Distressor", reason: "Versatile studio compressor", source: .local),
                PluginSuggestion(name: "Plugin Alliance bx_townhouse", reason: "Mix bus compressor", source: .local),
                PluginSuggestion(name: "Arturia Comp VCA-65", reason: "Vintage VCA compressor", source: .local),
                PluginSuggestion(name: "TDR Kotelnikov", reason: "Free transparent compressor", source: .local),
                PluginSuggestion(name: "Cytomic The Glue", reason: "SSL bus compressor", source: .local),
                PluginSuggestion(name: "Waves Renaissance Compressor", reason: "Smooth versatile compression", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Transparent true peak limiter", source: .local)
            ])

        case "reverb":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Affordable high-quality reverb", source: .local),
                PluginSuggestion(name: "FabFilter Pro-R", reason: "Modern algorithmic reverb", source: .local),
                PluginSuggestion(name: "Lexicon PCM Native", reason: "Industry standard reverb", source: .local),
                PluginSuggestion(name: "Eventide Blackhole", reason: "Creative ambient reverb", source: .local),
                PluginSuggestion(name: "Seventh Heaven", reason: "Bricasti M7 emulation", source: .local),
                PluginSuggestion(name: "Valhalla Room", reason: "Natural room reverb", source: .local),
                PluginSuggestion(name: "Waves H-Reverb", reason: "Hybrid reverb with vintage character", source: .local),
                PluginSuggestion(name: "UAD EMT 140", reason: "Classic plate reverb", source: .local),
                PluginSuggestion(name: "Eventide UltraReverb", reason: "Premium reverb processor", source: .local),
                PluginSuggestion(name: "Waves Abbey Road Chambers", reason: "Abbey Road echo chambers", source: .local),
                PluginSuggestion(name: "2CAudio Aether", reason: "High-end algorithmic reverb", source: .local),
                PluginSuggestion(name: "Plugin Alliance NEOLD V76U73", reason: "Vintage console reverb", source: .local),
                PluginSuggestion(name: "Exponential Audio R4", reason: "Professional reverb suite", source: .local),
                PluginSuggestion(name: "TC Electronic M40", reason: "Studio reverb emulation", source: .local),
                PluginSuggestion(name: "Arturia Rev PLATE-140", reason: "Plate reverb emulation", source: .local)
            ])

        case "delay":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Vintage delay emulations", source: .local),
                PluginSuggestion(name: "FabFilter Timeless 3", reason: "Creative tape delay", source: .local),
                PluginSuggestion(name: "Waves H-Delay", reason: "Classic hybrid delay", source: .local),
                PluginSuggestion(name: "Valhalla Delay", reason: "Versatile modern delay", source: .local),
                PluginSuggestion(name: "UAD Galaxy Tape Echo", reason: "Vintage tape echo", source: .local)
            ])

        case "modulation":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Soundtoys PhaseMistress", reason: "Vintage phaser with analog character", source: .local),
                PluginSuggestion(name: "Waves MetaFlanger", reason: "Modern flanger with vintage modes", source: .local),
                PluginSuggestion(name: "UAD Dimension D", reason: "Classic chorus/ensemble effect", source: .local),
                PluginSuggestion(name: "Eventide UltraTap", reason: "Rhythmic multi-tap delay", source: .local),
                PluginSuggestion(name: "Valhalla UberMod", reason: "Creative modulation and delay", source: .local)
            ])

        case "pitch shift":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Soundtoys Little AlterBoy", reason: "Vocal pitch and formant shifter", source: .local),
                PluginSuggestion(name: "Eventide H910", reason: "Legendary vintage pitch shifter", source: .local),
                PluginSuggestion(name: "Waves SoundShifter", reason: "Professional pitch/time manipulation", source: .local),
                PluginSuggestion(name: "Melodyne", reason: "Industry standard pitch correction", source: .local),
                PluginSuggestion(name: "Auto-Tune Pro", reason: "Iconic vocal tuning", source: .local)
            ])

        case "harmonic":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "Multiband distortion/saturation", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Analog saturation emulation", source: .local),
                PluginSuggestion(name: "UAD Ampex ATR-102", reason: "Tape machine emulation", source: .local),
                PluginSuggestion(name: "Plugin Alliance Black Box", reason: "Mastering grade saturation", source: .local),
                PluginSuggestion(name: "Softube Saturation Knob", reason: "Simple analog saturation", source: .local)
            ])

        case "noise reduction":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "iZotope RX", reason: "Industry standard audio repair suite", source: .local),
                PluginSuggestion(name: "Waves NS1", reason: "Intelligent noise suppressor", source: .local),
                PluginSuggestion(name: "Cedar DNS One", reason: "Professional dialogue noise suppressor", source: .local),
                PluginSuggestion(name: "Accusonus ERA Bundle", reason: "One-knob audio repair tools", source: .local),
                PluginSuggestion(name: "Acon Digital DeNoise", reason: "Affordable noise reduction", source: .local)
            ])

        case "sound field":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "iZotope Ozone Imager", reason: "Stereo width enhancement", source: .local),
                PluginSuggestion(name: "Waves S1 Stereo Imager", reason: "MS processing and width control", source: .local),
                PluginSuggestion(name: "Goodhertz CanOpener", reason: "Speaker to headphone translator", source: .local),
                PluginSuggestion(name: "Waves Abbey Road Studio 3", reason: "Immersive spatial processing", source: .local),
                PluginSuggestion(name: "Dear Reality dearVR", reason: "3D audio spatializer", source: .local)
            ])

        case "mastering":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "iZotope Ozone", reason: "Complete mastering suite", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Transparent limiting", source: .local),
                PluginSuggestion(name: "Waves Abbey Road TG", reason: "Vintage mastering chain", source: .local),
                PluginSuggestion(name: "Plugin Alliance Masterdesk", reason: "All-in-one mastering console", source: .local),
                PluginSuggestion(name: "UAD Precision Mastering", reason: "High-end mastering tools", source: .local)
            ])

        case "metering":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "iZotope Insight 2", reason: "Comprehensive metering suite", source: .local),
                PluginSuggestion(name: "Waves WLM Plus", reason: "Loudness meter for broadcast", source: .local),
                PluginSuggestion(name: "Plugin Alliance LUFS Meter", reason: "Free loudness metering", source: .local),
                PluginSuggestion(name: "Youlean Loudness Meter", reason: "Free multi-platform loudness meter", source: .local),
                PluginSuggestion(name: "Nugen VisLM", reason: "Professional loudness metering", source: .local)
            ])

        case "filter":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Volcano", reason: "Versatile filter effect", source: .local),
                PluginSuggestion(name: "Soundtoys FilterFreak", reason: "Dual filter with modulation", source: .local),
                PluginSuggestion(name: "UAD Moog Multimode Filter", reason: "Classic Moog ladder filter", source: .local),
                PluginSuggestion(name: "Kilohearts Multipass", reason: "Multiband filter and effects", source: .local),
                PluginSuggestion(name: "Native Instruments Filter", reason: "Versatile resonant filter", source: .local)
            ])

        case "utility":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Voxengo SPAN", reason: "Free spectrum analyzer", source: .local),
                PluginSuggestion(name: "Plugin Alliance bx_solo", reason: "Intelligent solo monitoring", source: .local),
                PluginSuggestion(name: "Waves InPhase", reason: "Phase alignment tool", source: .local),
                PluginSuggestion(name: "SoundID Reference", reason: "Room correction and monitoring", source: .local),
                PluginSuggestion(name: "iZotope Relay", reason: "Gain staging utility", source: .local)
            ])

        case "effect":
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Soundtoys 5", reason: "Creative effects bundle", source: .local),
                PluginSuggestion(name: "Eventide H3000", reason: "Legendary multi-effects processor", source: .local),
                PluginSuggestion(name: "FabFilter Effects Bundle", reason: "Modern creative effects suite", source: .local),
                PluginSuggestion(name: "Waves Gold Bundle", reason: "Essential mixing effects", source: .local),
                PluginSuggestion(name: "iZotope Trash 2", reason: "Creative distortion and effects", source: .local)
            ])

        default:
            break
        }

        // Fallback: Match by name patterns if style didn't match
        if suggestions.isEmpty && (name.contains("chorus") || name.contains("flanger") || name.contains("phaser")) {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Soundtoys PhaseMistress", reason: "Vintage phaser with analog character", source: .local),
                PluginSuggestion(name: "Eventide UltraChannel", reason: "Studio channel strip with modulation", source: .local),
                PluginSuggestion(name: "Waves MetaFlanger", reason: "Modern flanger with vintage modes", source: .local),
                PluginSuggestion(name: "UAD Dimension D", reason: "Classic chorus/ensemble effect", source: .local),
                PluginSuggestion(name: "FabFilter Timeless", reason: "Creative modulation and delay", source: .local)
            ])
        }

        // EQ plugins
        else if name.contains("eq") || name.contains("equalizer") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Industry standard EQ with excellent workflow", source: .local),
                PluginSuggestion(name: "iZotope Ozone EQ", reason: "Professional mastering EQ", source: .local),
                PluginSuggestion(name: "Waves Q10", reason: "Classic 10-band parametric EQ", source: .local),
                PluginSuggestion(name: "UAD Neve 1073", reason: "Vintage console EQ emulation", source: .local),
                PluginSuggestion(name: "Sonimus Burnley 73", reason: "Affordable Neve-style EQ", source: .local)
            ])
        }

        // Compressor plugins
        else if name.contains("comp") || name.contains("压缩") || name.contains("limiter") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "Versatile modern compressor", source: .local),
                PluginSuggestion(name: "UAD 1176", reason: "Classic FET compressor", source: .local),
                PluginSuggestion(name: "Waves CLA-76", reason: "Popular 1176 emulation", source: .local),
                PluginSuggestion(name: "Slate Digital FG-X", reason: "Mastering compressor/limiter", source: .local),
                PluginSuggestion(name: "Native Instruments VC 76", reason: "Affordable vintage compressor", source: .local)
            ])
        }

        // Reverb plugins
        else if name.contains("reverb") || name.contains("verb") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Affordable high-quality reverb", source: .local),
                PluginSuggestion(name: "FabFilter Pro-R", reason: "Modern algorithmic reverb", source: .local),
                PluginSuggestion(name: "Waves H-Reverb", reason: "Hybrid reverb with vintage character", source: .local),
                PluginSuggestion(name: "Lexicon PCM Native", reason: "Industry standard reverb", source: .local),
                PluginSuggestion(name: "Eventide Blackhole", reason: "Creative ambient reverb", source: .local)
            ])
        }

        // Delay plugins
        else if name.contains("delay") || name.contains("echo") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Vintage delay emulations", source: .local),
                PluginSuggestion(name: "FabFilter Timeless", reason: "Creative tape delay", source: .local),
                PluginSuggestion(name: "Waves H-Delay", reason: "Classic hybrid delay", source: .local),
                PluginSuggestion(name: "Valhalla Delay", reason: "Versatile modern delay", source: .local),
                PluginSuggestion(name: "Eventide H3000", reason: "Legendary multi-effects delay", source: .local)
            ])
        }

        // Saturation/Distortion
        else if name.contains("saturate") || name.contains("distort") || name.contains("drive") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "Multiband distortion/saturation", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Analog saturation emulation", source: .local),
                PluginSuggestion(name: "UAD Ampex ATR-102", reason: "Tape saturation", source: .local),
                PluginSuggestion(name: "iZotope Trash 2", reason: "Creative distortion tool", source: .local),
                PluginSuggestion(name: "Waves Abbey Road Saturator", reason: "Vintage saturation", source: .local)
            ])
        }

        // Publisher-based suggestions (when no category match)
        else if publisher.contains("fabfilter") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Popular FabFilter EQ", source: .local),
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "FabFilter compressor", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "FabFilter limiter", source: .local),
                PluginSuggestion(name: "FabFilter Timeless", reason: "FabFilter delay/modulation", source: .local),
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "FabFilter distortion", source: .local)
            ])
        }
        else if publisher.contains("waves") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Waves SSL E-Channel", reason: "SSL console emulation", source: .local),
                PluginSuggestion(name: "Waves CLA-2A", reason: "LA-2A compressor emulation", source: .local),
                PluginSuggestion(name: "Waves Abbey Road TG", reason: "Abbey Road mastering chain", source: .local),
                PluginSuggestion(name: "Waves H-Reverb", reason: "Hybrid reverb", source: .local),
                PluginSuggestion(name: "Waves MetaFlanger", reason: "Modulation effect", source: .local)
            ])
        }
        else if publisher.contains("eventide") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Eventide H3000", reason: "Legendary multi-effects processor", source: .local),
                PluginSuggestion(name: "Eventide Blackhole", reason: "Creative reverb", source: .local),
                PluginSuggestion(name: "Eventide UltraChannel", reason: "Channel strip plugin", source: .local),
                PluginSuggestion(name: "Eventide H910", reason: "Vintage pitch shifter", source: .local),
                PluginSuggestion(name: "Eventide UltraReverb", reason: "Premium reverb", source: .local)
            ])
        }
        else if publisher.contains("soundtoys") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Analog saturation", source: .local),
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Vintage delay", source: .local),
                PluginSuggestion(name: "Soundtoys PhaseMistress", reason: "Vintage phaser", source: .local),
                PluginSuggestion(name: "Soundtoys Devil-Loc", reason: "Aggressive compression", source: .local),
                PluginSuggestion(name: "Soundtoys Tremolator", reason: "Tremolo effect", source: .local)
            ])
        }

        // Generic fallback based on type
        if suggestions.isEmpty {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Versatile EQ for any source", source: .local),
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "Transparent compression", source: .local),
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "High-quality reverb", source: .local),
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Creative delay effects", source: .local),
                PluginSuggestion(name: "iZotope Ozone Elements", reason: "Mastering suite basics", source: .local)
            ])
        }

        // Return all suggestions (no limit - filtering happens in fetch methods)
        return suggestions
    }
}

// MARK: - Category Knowledge Database (Workflow/Genre)

struct CategoryPluginKnowledge {
    static func getSuggestions(for category: SuggestionCategory, pluginStyle: String) -> [PluginSuggestion] {
        // Get all plugins for the category
        // For workflow/genre categories, return ALL suggestions without style filtering
        // The category itself defines the use case, not the plugin's style
        return getAllPluginsForCategory(category)
    }

    static func getFreeSuggestions(pluginStyle: String) -> [PluginSuggestion] {
        return freePlugins.filter { isStyleMatch(suggestion: $0, style: pluginStyle.lowercased()) }
    }

    private static let freePlugins: [PluginSuggestion] = [
        // TDR (Tokyo Dawn Records)
        PluginSuggestion(name: "TDR Nova", reason: "Free dynamic EQ with multiband compression and dynamics", source: .local),
        PluginSuggestion(name: "TDR Kotelnikov", reason: "Free transparent compressor with advanced features", source: .local),
        PluginSuggestion(name: "TDR VOS SlickEQ", reason: "Free vintage-style equalizer", source: .local),
        PluginSuggestion(name: "TDR Molotok", reason: "Free compressor with character", source: .local),

        // Voxengo
        PluginSuggestion(name: "Voxengo SPAN", reason: "Free spectrum analyzer for mixing and mastering", source: .local),
        PluginSuggestion(name: "Voxengo Marvel GEQ", reason: "Free 16-band graphic equalizer", source: .local),
        PluginSuggestion(name: "Voxengo OldSkoolVerb", reason: "Free algorithmic reverb with classic room sounds", source: .local),

        // Variety of Sound
        PluginSuggestion(name: "ThrillseekerLA", reason: "Free LA-style opto compressor", source: .local),
        PluginSuggestion(name: "Nasty DLA", reason: "Free analog-style compressor", source: .local),

        // MeldaProduction
        PluginSuggestion(name: "MFreeFXBundle", reason: "Free bundle of 37 professional effects", source: .local),
        PluginSuggestion(name: "MEqualizer", reason: "Free linear-phase equalizer from Melda", source: .local),
        PluginSuggestion(name: "MCompressor", reason: "Free compressor with advanced features", source: .local),
        PluginSuggestion(name: "MConvolutionEZ", reason: "Free convolution reverb for realistic spaces", source: .local),

        // Native Instruments
        PluginSuggestion(name: "Komplete Start", reason: "Free collection of instruments and effects", source: .local),

        // Spitfire Audio
        PluginSuggestion(name: "LABS", reason: "Free collection of unique instruments and synths", source: .local),

        // Other Free Plugins
        PluginSuggestion(name: "Valhalla Freq Echo", reason: "Free frequency shifter and delay effect", source: .local),
        PluginSuggestion(name: "Valhalla Supermassive", reason: "Free massive reverb and delay with huge spaces", source: .local),
        PluginSuggestion(name: "Dragonfly Reverb", reason: "Free reverb with natural room and hall algorithms", source: .local),
        PluginSuggestion(name: "CloudReverb", reason: "Free reverb plugin for ambient spaces", source: .local),
        PluginSuggestion(name: "Soft Tube Saturation Knob", reason: "Free saturation plugin for adding warmth", source: .local),
        PluginSuggestion(name: "Izotope Vinyl", reason: "Free lo-fi and vinyl effect", source: .local),
        PluginSuggestion(name: "Xfer OTT", reason: "Free multiband compressor", source: .local),
        PluginSuggestion(name: "Ample Bass P Lite", reason: "Free precision bass instrument", source: .local),
        PluginSuggestion(name: "Dexed", reason: "Free DX7 FM synthesizer", source: .local),
        PluginSuggestion(name: "Vital", reason: "Free wavetable synthesizer", source: .local),
        PluginSuggestion(name: "TAL-Reverb-4", reason: "Free vintage reverb with classic plate and spring sounds", source: .local)
    ]

    /// Check if suggestion matches the plugin style
    private static func isStyleMatch(suggestion: PluginSuggestion, style: String) -> Bool {
        let name = suggestion.name.lowercased()
        let reason = suggestion.reason.lowercased()

        // Check for direct style mentions
        if reason.contains(style) || name.contains(style) {
            return true
        }

        // Check for style categories with broader matching
        switch style {
        case "eq", "equalizer":
            return name.contains("eq") || name.contains("1073") || name.contains("ssl") ||
                   reason.contains("eq") || reason.contains("frequency") || reason.contains("equalizer")

        case "dynamics", "compressor", "limiter":
            return name.contains("comp") || name.contains("limit") || name.contains("1176") ||
                   name.contains("la-2") || name.contains("ssl") || name.contains("fg-x") ||
                   reason.contains("compress") || reason.contains("dynamic") || reason.contains("limit")

        case "reverb":
            return name.contains("verb") || name.contains("reverb") || name.contains("valhalla") ||
                   name.contains("lexicon") || name.contains("seventh heaven") ||
                   reason.contains("reverb") || reason.contains("space") || reason.contains("room")

        case "delay", "echo":
            return name.contains("delay") || name.contains("echo") || name.contains("tape") ||
                   reason.contains("delay") || reason.contains("echo")

        case "instrument", "synth", "sampler":
            return name.contains("komplete") || name.contains("serum") || name.contains("omnisphere") ||
                   name.contains("kontakt") || name.contains("arturia") || name.contains("massive") ||
                   name.contains("keyscape") || name.contains("spitfire") ||
                   reason.contains("synth") || reason.contains("instrument") || reason.contains("sampler")

        case "harmonic", "saturation", "distortion":
            return name.contains("saturate") || name.contains("saturn") || name.contains("decapitator") ||
                   name.contains("ampex") || name.contains("tape") ||
                   reason.contains("saturation") || reason.contains("distortion") || reason.contains("warmth") ||
                   reason.contains("analog") || reason.contains("grit")

        case "modulation", "chorus", "flanger", "phaser":
            return name.contains("chorus") || name.contains("flanger") || name.contains("phaser") ||
                   name.contains("dimension") || reason.contains("modulation")

        case "mastering":
            return name.contains("ozone") || name.contains("pro-l") || name.contains("master") ||
                   name.contains("abbey road") || reason.contains("master")

        case "filter":
            return name.contains("filter") || name.contains("volcano") || reason.contains("filter")

        case "pitch shift", "pitch correction", "tuning":
            return name.contains("tune") || name.contains("melodyne") || name.contains("alter") ||
                   name.contains("auto-tune") || reason.contains("pitch") || reason.contains("tuning")

        case "metering", "analyzer":
            return name.contains("span") || name.contains("insight") || name.contains("meter") ||
                   reason.contains("meter") || reason.contains("analyzer")

        case "noise reduction":
            return name.contains("rx") || name.contains("dns") || name.contains("ns1") ||
                   reason.contains("noise") || reason.contains("suppressor")

        default:
            // For unrecognized styles, accept all suggestions
            return true
        }
    }

    private static func getAllPluginsForCategory(_ category: SuggestionCategory) -> [PluginSuggestion] {
        switch category {
        case .free:
            return freePlugins

        case .mixing:
            return [
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Essential mixing EQ with surgical precision", source: .local),
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "Transparent compression for any source", source: .local),
                PluginSuggestion(name: "Valhalla Room", reason: "Natural reverb for mix depth", source: .local),
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Versatile delay for mixing", source: .local),
                PluginSuggestion(name: "iZotope Neutron", reason: "AI-assisted mixing suite", source: .local),
                PluginSuggestion(name: "Waves SSL E-Channel", reason: "Classic console channel strip", source: .local),
                PluginSuggestion(name: "Waves CLA-76", reason: "Fast compression for drums/vocals", source: .local),
                PluginSuggestion(name: "UAD Neve 1073", reason: "Vintage console tone shaping", source: .local)
            ]

        case .mastering:
            return [
                PluginSuggestion(name: "iZotope Ozone", reason: "Complete mastering suite", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Transparent true peak limiting", source: .local),
                PluginSuggestion(name: "Waves Abbey Road TG", reason: "Vintage mastering chain", source: .local),
                PluginSuggestion(name: "Plugin Alliance Masterdesk", reason: "All-in-one mastering console", source: .local),
                PluginSuggestion(name: "iZotope Insight 2", reason: "Professional metering suite", source: .local),
                PluginSuggestion(name: "Slate Digital FG-X", reason: "Transparent mastering compression", source: .local),
                PluginSuggestion(name: "DMG Audio EQuilibrium", reason: "High-end mastering EQ", source: .local),
                PluginSuggestion(name: "Voxengo SPAN", reason: "Free spectrum analyzer", source: .local)
            ]

        case .vocals:
            return [
                PluginSuggestion(name: "Waves CLA-2A", reason: "Smooth optical compression for vocals", source: .local),
                PluginSuggestion(name: "iZotope Nectar", reason: "Complete vocal production suite", source: .local),
                PluginSuggestion(name: "Auto-Tune Pro", reason: "Industry standard pitch correction", source: .local),
                PluginSuggestion(name: "Melodyne", reason: "Natural pitch and timing editing", source: .local),
                PluginSuggestion(name: "Waves Renaissance Vox", reason: "One-knob vocal compressor", source: .local),
                PluginSuggestion(name: "FabFilter Pro-DS", reason: "Intelligent de-esser", source: .local),
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Smooth vocal reverb", source: .local),
                PluginSuggestion(name: "Soundtoys Little AlterBoy", reason: "Creative vocal pitch shifting", source: .local)
            ]

        case .drums:
            return [
                PluginSuggestion(name: "Waves CLA-76", reason: "Aggressive parallel compression", source: .local),
                PluginSuggestion(name: "FabFilter Pro-MB", reason: "Multiband processing for control", source: .local),
                PluginSuggestion(name: "Slate Digital Trigger", reason: "Drum sample replacement", source: .local),
                PluginSuggestion(name: "UAD 1176", reason: "Punchy drum bus compression", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Add punch and grit to drums", source: .local),
                PluginSuggestion(name: "Waves SSL G-Master Buss", reason: "Glue compression for drum bus", source: .local),
                PluginSuggestion(name: "Valhalla Room", reason: "Natural drum room ambience", source: .local),
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Surgical drum EQ", source: .local)
            ]

        case .instruments:
            return [
                PluginSuggestion(name: "Native Instruments Komplete", reason: "Comprehensive instrument library", source: .local),
                PluginSuggestion(name: "Arturia V Collection", reason: "Vintage synth emulations", source: .local),
                PluginSuggestion(name: "Serum by Xfer", reason: "Modern wavetable synthesis", source: .local),
                PluginSuggestion(name: "Omnisphere 2", reason: "Massive sound design library", source: .local),
                PluginSuggestion(name: "Kontakt 7", reason: "Industry standard sampler", source: .local),
                PluginSuggestion(name: "Keyscape", reason: "Premium keyboard instruments", source: .local),
                PluginSuggestion(name: "Spitfire Audio", reason: "Orchestral and cinematic sounds", source: .local),
                PluginSuggestion(name: "Native Instruments Massive X", reason: "Powerful wavetable synth", source: .local)
            ]

        case .rock:
            return [
                PluginSuggestion(name: "Waves CLA Guitars", reason: "Guitar processing by Chris Lord-Alge", source: .local),
                PluginSuggestion(name: "UAD Ampex ATR-102", reason: "Tape saturation for rock warmth", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Analog grit and saturation", source: .local),
                PluginSuggestion(name: "Waves SSL E-Channel", reason: "Rock mixing console sound", source: .local),
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "Distortion and drive tones", source: .local),
                PluginSuggestion(name: "UAD 1176", reason: "Classic rock compression", source: .local),
                PluginSuggestion(name: "Waves Abbey Road Chambers", reason: "Natural rock reverb", source: .local),
                PluginSuggestion(name: "Slate Digital Virtual Mix Rack", reason: "Analog console emulation", source: .local)
            ]

        case .pop:
            return [
                PluginSuggestion(name: "Waves Renaissance Compressor", reason: "Smooth pop production dynamics", source: .local),
                PluginSuggestion(name: "Auto-Tune Pro", reason: "Modern pop vocal tuning", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Loud, polished pop masters", source: .local),
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Lush pop reverb", source: .local),
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Creative pop delays", source: .local),
                PluginSuggestion(name: "Serum by Xfer", reason: "Modern pop synth sounds", source: .local),
                PluginSuggestion(name: "Waves CLA-2A", reason: "Gentle vocal compression", source: .local),
                PluginSuggestion(name: "FabFilter Pro-MB", reason: "Clean multiband control", source: .local)
            ]

        case .hipHop:
            return [
                PluginSuggestion(name: "Waves CLA-76", reason: "Punchy hip hop compression", source: .local),
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "808 and bass saturation", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Add grit to drums and vocals", source: .local),
                PluginSuggestion(name: "Auto-Tune Pro", reason: "Hip hop vocal effects", source: .local),
                PluginSuggestion(name: "Waves SSL G-Master Buss", reason: "Hip hop mix glue", source: .local),
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Precise low-end control", source: .local),
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Vocal space and depth", source: .local),
                PluginSuggestion(name: "RC-20 Retro Color", reason: "Lo-fi hip hop texture", source: .local)
            ]

        case .dub:
            return [
                PluginSuggestion(name: "Valhalla Delay", reason: "Deep dub echo trails", source: .local),
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Tape echo for dub effects", source: .local),
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Spacious dub reverb", source: .local),
                PluginSuggestion(name: "UAD Galaxy Tape Echo", reason: "Vintage dub delay", source: .local),
                PluginSuggestion(name: "FabFilter Timeless 3", reason: "Creative dub delays", source: .local),
                PluginSuggestion(name: "Eventide H3000", reason: "Classic dub effects processor", source: .local),
                PluginSuggestion(name: "Waves H-Delay", reason: "Analog-style dub echoes", source: .local),
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Filter sweeps and cuts", source: .local)
            ]

        case .house:
            return [
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "Sidechain compression for pumping", source: .local),
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Precise frequency carving", source: .local),
                PluginSuggestion(name: "Valhalla Room", reason: "Dance floor reverb spaces", source: .local),
                PluginSuggestion(name: "FabFilter Volcano", reason: "House filter sweeps", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Warm analog saturation", source: .local),
                PluginSuggestion(name: "Serum by Xfer", reason: "House bass and lead sounds", source: .local),
                PluginSuggestion(name: "Waves SSL G-Master Buss", reason: "Mix glue compression", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Loud house masters", source: .local)
            ]

        case .techno:
            return [
                PluginSuggestion(name: "FabFilter Pro-MB", reason: "Multiband dynamics for techno", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Industrial techno saturation", source: .local),
                PluginSuggestion(name: "FabFilter Timeless 3", reason: "Techno delay effects", source: .local),
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Dark techno spaces", source: .local),
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "Heavy distortion and drive", source: .local),
                PluginSuggestion(name: "Serum by Xfer", reason: "Aggressive techno synthesis", source: .local),
                PluginSuggestion(name: "UAD Galaxy Tape Echo", reason: "Industrial tape delays", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Maximum loudness limiting", source: .local)
            ]

        case .edm:
            return [
                PluginSuggestion(name: "Serum by Xfer", reason: "EDM industry standard synth", source: .local),
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Maximum loudness for EDM", source: .local),
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "Sidechain and dynamic control", source: .local),
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Massive EDM reverb tails", source: .local),
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "EDM distortion and warmth", source: .local),
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Creative EDM delays", source: .local),
                PluginSuggestion(name: "Omnisphere 2", reason: "Huge EDM soundscapes", source: .local),
                PluginSuggestion(name: "FabFilter Pro-MB", reason: "Multiband mixing control", source: .local)
            ]
        }
    }
}
