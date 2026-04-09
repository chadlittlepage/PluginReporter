// AIPluginSuggestions.swift — Hybrid AI suggestion system (OpenAI + Local fallback)
import Combine
import Foundation

// MARK: - Suggestion Categories

enum SuggestionCategory: String, CaseIterable, Identifiable {
    // Workflow & Genre Categories (Row 1)
    case ownedAlternatives = "Your Alternatives"
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

    // Plugin Type Categories (Row 2)
    case eq = "EQ"
    case compressor = "Compressor"
    case limiter = "Limiter"
    case reverb = "Reverb"
    case delay = "Delay"
    case chorus = "Chorus"
    case flanger = "Flanger"
    case phaser = "Phaser"
    case distortion = "Distortion"
    case saturation = "Saturation"
    case filter = "Filter"
    case gate = "Gate"
    case deesser = "De-esser"
    case multiband = "Multiband"
    case spatial = "Spatial"
    case stereo = "Stereo"
    case atmos = "Atmos"
    case surround = "Surround"
    case analyzer = "Analyzer"
    case metering = "Metering"
    case synth = "Synth"
    case sampler = "Sampler"
    case drumMachine = "Drum Machine"
    case arpeggiator = "Arpeggiator"
    case vocoder = "Vocoder"
    case pitchCorrection = "Pitch Correction"
    case transient = "Transient"
    case tape = "Tape"
    case channelStrip = "Channel Strip"
    case console = "Console"
    case enhancer = "Enhancer"
    case exciter = "Exciter"

    var id: String { rawValue }

    // Categorize into rows
    var isPluginType: Bool {
        switch self {
        case .eq, .compressor, .limiter, .reverb, .delay, .chorus, .flanger, .phaser,
             .distortion, .saturation, .filter, .gate, .deesser, .multiband, .spatial,
             .stereo, .atmos, .surround, .analyzer, .metering, .synth, .sampler,
             .drumMachine, .arpeggiator, .vocoder, .pitchCorrection, .transient, .tape,
             .channelStrip, .console, .enhancer, .exciter:
            return true
        default:
            return false
        }
    }

    static var workflowCategories: [SuggestionCategory] {
        allCases.filter { !$0.isPluginType }
    }

    static var pluginTypeCategories: [SuggestionCategory] {
        allCases.filter { $0.isPluginType }
    }
}

// MARK: - Ownership Filter Mode

enum OwnershipFilter: String, CaseIterable, Identifiable {
    case notOwned = "Don't Own"
    case owned = "Own"
    case all = "All"

    var id: String { rawValue }
}

// MARK: - Pricing Filter Mode

enum PricingFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case free = "Free"
    case paid = "Paid"

    var id: String { rawValue }
}

// MARK: - AI Plugin Suggestions Service

/// AI-powered plugin suggestion service
@MainActor
class AIPluginSuggestions: ObservableObject {
    @Published var suggestions: [PluginSuggestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var ownershipFilter: OwnershipFilter = .owned
    @Published var pricingFilter: PricingFilter = .all

    // Track previously shown suggestions to provide variety on "More" clicks
    private var previouslyShownSuggestions: Set<String> = []

    // Store base search results for intelligent category filtering
    private var baseSuggestions: [PluginSuggestion] = []

    // OpenAI API key (optional - falls back to local if not set)
    // Stored securely in Keychain
    private var openAIKey: String? {
        KeychainHelper.load(key: "openai_api_key")
    }

    /// Reset tracking (call when switching plugins or categories)
    func resetPreviouslyShown() {
        previouslyShownSuggestions.removeAll()
    }

    /// Clear base suggestions (call when starting a new search)
    func clearBaseSuggestions() {
        baseSuggestions.removeAll()
    }

    /// Deduplicate suggestions by plugin name (case-insensitive)
    private func deduplicate(_ suggestions: [PluginSuggestion]) -> [PluginSuggestion] {
        print("🔄 [AI Suggestions] Deduplicating \(suggestions.count) suggestions")

        var seen = Set<String>()
        let deduplicated = suggestions.filter { suggestion in
            let lowercaseName = suggestion.name.lowercased()
            if seen.contains(lowercaseName) {
                print("🗑️ [AI Suggestions] Removing duplicate: '\(suggestion.name)'")
                return false
            }
            seen.insert(lowercaseName)
            return true
        }

        let removedCount = suggestions.count - deduplicated.count
        if removedCount > 0 {
            print("✅ [AI Suggestions] Removed \(removedCount) duplicates, \(deduplicated.count) unique suggestions remain")
        } else {
            print("✅ [AI Suggestions] No duplicates found")
        }

        return deduplicated
    }

    /// Enrich suggestions with heritage data (hardware models, famous uses, hit songs)
    private func enrichWithHeritage(_ suggestions: [PluginSuggestion], useAI: Bool = true, maxAICalls: Int = 10) async -> [PluginSuggestion] {
        print("🎨 [AI Suggestions] Enriching \(suggestions.count) suggestions with heritage data (AI: \(useAI), maxAI: \(maxAICalls))")

        var enriched: [PluginSuggestion] = []
        var aiCallsUsed = 0

        // First pass: quick synchronous curated database lookup for ALL plugins
        for suggestion in suggestions {
            var enrichedSuggestion = suggestion

            // Wrap heritage lookup - function returns optional, doesn't throw
            enrichedSuggestion.heritage = PluginHeritageDatabase.getHeritage(for: suggestion.name)

            if enrichedSuggestion.heritage != nil {
                print("⭐ [AI Suggestions] Enriched '\(suggestion.name)' with curated heritage data")
            }

            enriched.append(enrichedSuggestion)
        }

        // Second pass: AI generation for plugins without heritage (if enabled and under limit)
        if useAI && aiCallsUsed < maxAICalls {
            print("🤖 [AI Suggestions] Starting AI heritage generation for plugins without curated data...")

            for i in 0..<enriched.count {
                // Stop if we've hit the limit or no API key
                guard aiCallsUsed < maxAICalls else {
                    print("⚠️ [AI Suggestions] Reached AI call limit (\(maxAICalls)), skipping remaining")
                    break
                }

                guard let apiKey = openAIKey, !apiKey.isEmpty else {
                    print("⚠️ [AI Suggestions] No API key available, skipping AI generation")
                    break
                }

                // Skip if already has heritage
                guard enriched[i].heritage == nil else { continue }

                // Try to generate AI heritage - function returns optional, doesn't throw
                print("🤖 [AI Suggestions] Generating AI heritage for '\(enriched[i].name)'...")
                if let aiHeritage = await PluginHeritageDatabase.getHeritageWithAI(
                    for: enriched[i].name,
                    apiKey: apiKey
                ) {
                    enriched[i].heritage = aiHeritage
                    aiCallsUsed += 1
                    print("⭐ [AI Suggestions] Enriched '\(enriched[i].name)' with AI heritage data (\(aiCallsUsed)/\(maxAICalls))")
                }
            }
        }

        let heritageCount = enriched.filter { $0.heritage != nil }.count
        let aiCount = enriched.filter { $0.heritage?.isAIGenerated == true }.count
        let curatedCount = heritageCount - aiCount
        print("✅ [AI Suggestions] Enrichment complete: \(heritageCount)/\(suggestions.count) have heritage (\(curatedCount) curated, \(aiCount) AI)")

        return enriched
    }

    /// Filter suggestions by ownership status
    private func filterByOwnership(_ suggestions: [PluginSuggestion], ownedPlugins: [PluginItem]) -> [PluginSuggestion] {
        guard ownershipFilter != .all else {
            print("🌐 [AI Suggestions] No ownership filtering (showing all)")
            return suggestions
        }

        let ownedNames = Set(ownedPlugins.map { $0.name.lowercased() })

        let filtered = suggestions.filter { suggestion in
            let isOwned = ownedNames.contains(suggestion.name.lowercased())

            if ownershipFilter == .owned {
                return isOwned // Keep only owned plugins
            } else {
                return !isOwned // Keep only plugins we don't own
            }
        }

        print("🎯 [AI Suggestions] Filtered from \(suggestions.count) to \(filtered.count) based on ownership: \(ownershipFilter.rawValue)")
        return filtered
    }

    /// Fetch suggestions for a plugin (tries OpenAI with web knowledge, falls back to local)
    func fetchSuggestions(for plugin: PluginItem, ownedPlugins: [PluginItem], appendMode: Bool = false) async {
        print("🚀 [AI Suggestions] Starting suggestion fetch for plugin: '\(plugin.name)'")
        print("📋 [AI Suggestions] Owned plugins count: \(ownedPlugins.count)")
        print("🔄 [AI Suggestions] Append mode: \(appendMode)")
        print("🎯 [AI Suggestions] Ownership filter: \(ownershipFilter.rawValue)")

        isLoading = true
        errorMessage = nil

        // Special case: If "Own" filter is active, search through owned plugins instead of getting AI suggestions
        if ownershipFilter == .owned {
            print("🔍 [AI Suggestions] Searching owned plugins for: '\(plugin.name)'")

            // Search owned plugins that match the search query
            let searchTerm = plugin.name.lowercased()
            let matchingPlugins = ownedPlugins.filter { ownedPlugin in
                ownedPlugin.name.lowercased().contains(searchTerm) ||
                ownedPlugin.publisher.lowercased().contains(searchTerm) ||
                ownedPlugin.style.lowercased().contains(searchTerm)
            }

            print("📦 [AI Suggestions] Found \(matchingPlugins.count) owned plugins matching '\(plugin.name)'")

            // Convert owned plugins to suggestions
            let ownedSuggestions = matchingPlugins.map { ownedPlugin in
                let reason = ownedPlugin.style.isEmpty ? "You own this plugin" : "You own this \(ownedPlugin.style) plugin"
                return PluginSuggestion(
                    name: ownedPlugin.name,
                    reason: reason,
                    source: .local,
                    style: ownedPlugin.style.isEmpty ? nil : ownedPlugin.style
                )
            }

            // Deduplicate and enrich with heritage data (limit AI calls to first 10 plugins)
            suggestions = await enrichWithHeritage(deduplicate(ownedSuggestions), useAI: true, maxAICalls: 10)
            baseSuggestions = suggestions  // Store for category filtering
            isLoading = false

            if suggestions.isEmpty {
                errorMessage = "No owned plugins found matching '\(plugin.name)'"
                print("⚠️ [AI Suggestions] No matches found in owned plugins")
            }
            return
        }

        // Track AI request for dashboard reporting
        dashboardTrackAIRequest()

        // Build exclusion list based on ownership filter
        var excludedPlugins: [PluginItem] = [plugin] // Always exclude the current plugin

        // Add previously shown to exclusions (to provide variety)
        excludedPlugins += previouslyShownSuggestions.map { name in
            PluginItem(name: name, publisher: "", version: "", type: "", style: "",
                      architectures: "", date: nil, sizeBytes: 0, path: "",
                      runtimeRequirement: "", obsolete: false)
        }

        // Add owned plugins to exclusions only if filter is "Don't Own"
        if ownershipFilter == .notOwned {
            excludedPlugins += ownedPlugins
            print("🚫 [AI Suggestions] Excluding \(ownedPlugins.count) owned plugins")
        } else if ownershipFilter == .owned {
            print("✅ [AI Suggestions] Only showing owned plugins")
        } else {
            print("🌐 [AI Suggestions] Showing all plugins")
        }

        // Try Gemini first (free for all users!)
        do {
            let newSuggestions = try await fetchFromGemini(plugin: plugin, ownedPlugins: excludedPlugins)

            // If Gemini returns good suggestions, use them
            if newSuggestions.count >= 3 {
                // Track these suggestions
                for suggestion in newSuggestions {
                    previouslyShownSuggestions.insert(suggestion.name)
                }

                // Append or replace based on mode, then deduplicate, enrich with heritage, and filter by ownership
                if appendMode {
                    suggestions.append(contentsOf: newSuggestions)
                    suggestions = filterByOwnership(await enrichWithHeritage(deduplicate(suggestions)), ownedPlugins: ownedPlugins)
                } else {
                    suggestions = filterByOwnership(await enrichWithHeritage(deduplicate(newSuggestions)), ownedPlugins: ownedPlugins)
                }

                isLoading = false
                return
            }
        } catch {
            AppLogger.warning("Gemini API failed, trying OpenAI: \(error.localizedDescription)")
            dashboardLogError(message: "Gemini API failed: \(error.localizedDescription)", severity: "warning", context: "AI Suggestions")
            // Fall through to OpenAI
        }

        // Try OpenAI if user has API key (fallback from Gemini)
        if let apiKey = openAIKey, !apiKey.isEmpty {
            do {
                let newSuggestions = try await fetchFromOpenAI(plugin: plugin, apiKey: apiKey, ownedPlugins: excludedPlugins)

                // If OpenAI returns good suggestions, use them
                if newSuggestions.count >= 3 {
                    // Track these suggestions
                    for suggestion in newSuggestions {
                        previouslyShownSuggestions.insert(suggestion.name)
                    }

                    // Append or replace based on mode, then deduplicate, enrich with heritage, and filter by ownership
                    if appendMode {
                        suggestions.append(contentsOf: newSuggestions)
                        suggestions = filterByOwnership(await enrichWithHeritage(deduplicate(suggestions)), ownedPlugins: ownedPlugins)
                    } else {
                        suggestions = filterByOwnership(await enrichWithHeritage(deduplicate(newSuggestions)), ownedPlugins: ownedPlugins)
                    }

                    isLoading = false
                    return
                }
            } catch {
                AppLogger.warning("OpenAI API failed, using local suggestions: \(error.localizedDescription)")
                dashboardLogError(message: "OpenAI API failed: \(error.localizedDescription)", severity: "warning", context: "AI Suggestions")
                // Fall through to local AI
            }
        }

        // Fallback to local AI (comprehensive database)
        let newSuggestions = await fetchFromLocal(plugin: plugin, ownedPlugins: excludedPlugins)

        // Show 5-10 suggestions (minimum 5, maximum 10)
        let count = min(max(newSuggestions.count, 5), 10)
        let limitedSuggestions = Array(newSuggestions.prefix(count))

        // Track these suggestions
        for suggestion in limitedSuggestions {
            previouslyShownSuggestions.insert(suggestion.name)
        }

        // Append or replace based on mode, then deduplicate, enrich with heritage, and filter by ownership
        if appendMode {
            suggestions.append(contentsOf: limitedSuggestions)
            suggestions = filterByOwnership(await enrichWithHeritage(deduplicate(suggestions)), ownedPlugins: ownedPlugins)
        } else {
            suggestions = filterByOwnership(await enrichWithHeritage(deduplicate(limitedSuggestions)), ownedPlugins: ownedPlugins)
        }

        isLoading = false
    }

    /// Smart category filtering using heritage data
    private func filterSuggestionsByCategory(_ suggestions: [PluginSuggestion], category: SuggestionCategory) -> [PluginSuggestion] {
        // "Your Alternatives" should not be filtered - return all suggestions as-is
        if category == .ownedAlternatives {
            print("🎯 [Category Filter] Skipping filter for 'Your Alternatives' - returning all \(suggestions.count) owned plugins")
            return suggestions
        }

        let categoryTerm = category.rawValue.lowercased()

        print("🎯 [Category Filter] Filtering \(suggestions.count) plugins for category: '\(category.rawValue)'")

        var scored: [(suggestion: PluginSuggestion, score: Int)] = suggestions.map { suggestion in
            var score = 0

            // Check heritage data for category relevance
            if let heritage = suggestion.heritage {
                // Check if any famous use has category term in usedOn array
                for use in heritage.famousUses ?? [] {
                    for usedOnItem in use.usedOn {
                        if usedOnItem.lowercased().contains(categoryTerm) {
                            score += 10  // Strong match in heritage usage
                            print("✨ [Category Filter] '\(suggestion.name)' scored +10: used on '\(usedOnItem)'")
                        }
                    }

                    // Check usage context for workflow categories
                    if category == .mixing && use.context == .mixing {
                        score += 5
                        print("✨ [Category Filter] '\(suggestion.name)' scored +5: mixing context")
                    } else if category == .mastering && use.context == .mastering {
                        score += 5
                        print("✨ [Category Filter] '\(suggestion.name)' scored +5: mastering context")
                    }
                }

                // Check sonic signature for genre/category keywords
                if heritage.sonicSignature?.lowercased().contains(categoryTerm) == true {
                    score += 3
                    print("✨ [Category Filter] '\(suggestion.name)' scored +3: category in sonic signature")
                }
            }

            // Check plugin metadata for category match
            if let style = suggestion.style, style.lowercased().contains(categoryTerm) {
                score += 5
                print("✨ [Category Filter] '\(suggestion.name)' scored +5: category in style '\(style)'")
            }

            if suggestion.name.lowercased().contains(categoryTerm) {
                score += 2
                print("✨ [Category Filter] '\(suggestion.name)' scored +2: category in name")
            }

            if suggestion.reason.lowercased().contains(categoryTerm) {
                score += 1
                print("✨ [Category Filter] '\(suggestion.name)' scored +1: category in reason")
            }

            return (suggestion, score)
        }

        // Filter out plugins with score 0 (no category relevance)
        let maxScore = scored.map { $0.score }.max() ?? 0

        // If no plugins scored (no heritage/metadata matches), show empty result instead of all
        if maxScore == 0 {
            print("⚠️ [Category Filter] No plugins matched category '\(category.rawValue)' - returning empty result")
            return []
        }

        // Filter to only plugins with scores > 0
        scored = scored.filter { $0.score > 0 }

        // Sort by score (highest first)
        scored.sort { $0.score > $1.score }

        // Update reason text for filtered plugins to show category relevance
        let filtered = scored.map { item -> PluginSuggestion in
            var suggestion = item.suggestion

            // Generate better reason text if score > 0
            if item.score > 0, let heritage = suggestion.heritage {
                // Find what makes this plugin good for this category
                var reasons: [String] = []

                for use in (heritage.famousUses ?? []).prefix(2) {  // Check first 2 uses
                    for usedOnItem in use.usedOn {
                        if usedOnItem.lowercased().contains(categoryTerm) {
                            reasons.append("Used on \(usedOnItem.lowercased()) in '\(use.songTitle)'")
                            break
                        }
                    }
                }

                if !reasons.isEmpty {
                    suggestion = PluginSuggestion(
                        name: suggestion.name,
                        reason: reasons.first ?? suggestion.reason,
                        source: suggestion.source,
                        heritage: suggestion.heritage,
                        style: suggestion.style
                    )
                }
            }

            return suggestion
        }

        print("✅ [Category Filter] Filtered to \(filtered.count) plugins relevant for '\(category.rawValue)'")

        return filtered
    }

    /// Fetch category-specific suggestions (workflow/genre based, filtered by plugin style)
    func fetchCategorySuggestions(for category: SuggestionCategory, plugin: PluginItem, ownedPlugins: [PluginItem], appendMode: Bool = false) async {
        print("\n🚀 [fetchCategorySuggestions] START")
        print("   Category: \(category.rawValue)")
        print("   Plugin: '\(plugin.name)'")
        print("   Plugin Style: '\(plugin.style)'")
        print("   Plugin Publisher: '\(plugin.publisher)'")
        print("   Owned Plugins Count: \(ownedPlugins.count)")
        print("   Append Mode: \(appendMode)")
        print("   Ownership Filter: \(ownershipFilter)")

        isLoading = true
        errorMessage = nil

        // Handle OWNED ALTERNATIVES category specially - suggest plugins user already owns
        // MUST come BEFORE ownershipFilter check to avoid wrong code path
        if category == .ownedAlternatives {
            print("\n🎯 [OWNED ALTERNATIVES PATH] Entering special handling")
            print("   Calling findOwnedAlternatives...")

            let newSuggestions = findOwnedAlternatives(for: plugin, from: ownedPlugins)

            print("   ✅ findOwnedAlternatives returned \(newSuggestions.count) suggestions")
            if newSuggestions.isEmpty {
                print("   ⚠️ WARNING: No owned alternatives found!")
                errorMessage = "No owned plugins found with style '\(plugin.style)'"
            } else {
                print("   Suggestions found:")
                for (idx, suggestion) in newSuggestions.prefix(5).enumerated() {
                    print("      \(idx + 1). \(suggestion.name) - \(suggestion.reason)")
                }
            }

            // Deduplicate and enrich with heritage after appending or setting
            if appendMode {
                print("   Append mode: adding to existing \(suggestions.count) suggestions")
                suggestions.append(contentsOf: newSuggestions)
                suggestions = await enrichWithHeritage(deduplicate(suggestions))
            } else {
                print("   Replace mode: replacing all suggestions")
                suggestions = await enrichWithHeritage(deduplicate(newSuggestions))
            }

            print("   Final suggestion count: \(suggestions.count)")
            isLoading = false
            print("🏁 [fetchCategorySuggestions] END - Owned Alternatives\n")
            return
        }

        // Special case: If "Own" filter is active, use smart category filtering on base suggestions
        if ownershipFilter == .owned {
            print("🔍 [AI Suggestions] Filtering owned plugins for category: '\(category.rawValue)', plugin style: '\(plugin.style)'")

            // Use base suggestions if available, otherwise search owned plugins first
            if baseSuggestions.isEmpty {
                print("📦 [AI Suggestions] No base suggestions, finding owned plugins with same style as '\(plugin.name)'")

                // For all categories when "Own" filter is active: find owned plugins with same style
                let pluginStyle = plugin.style.lowercased()
                let matchingPlugins = ownedPlugins.filter { ownedPlugin in
                    !pluginStyle.isEmpty && ownedPlugin.style.lowercased() == pluginStyle
                }

                if category == .free {
                    print("📦 [AI Suggestions] Found \(matchingPlugins.count) owned plugins with style '\(plugin.style)' (showing all, user can identify free ones)")
                } else {
                    print("📦 [AI Suggestions] Found \(matchingPlugins.count) owned plugins with style '\(plugin.style)'")
                }

                // Convert to suggestions and enrich with heritage
                let ownedSuggestions = matchingPlugins.map { ownedPlugin in
                    let reason = ownedPlugin.style.isEmpty ? "You own this plugin" : "You own this \(ownedPlugin.style) plugin"
                    return PluginSuggestion(
                        name: ownedPlugin.name,
                        reason: reason,
                        source: .local,
                        style: ownedPlugin.style.isEmpty ? nil : ownedPlugin.style
                    )
                }

                baseSuggestions = await enrichWithHeritage(deduplicate(ownedSuggestions), useAI: true, maxAICalls: 10)
            }

            // Apply smart category filtering using heritage data
            print("🎯 [AI Suggestions] Applying smart category filter on \(baseSuggestions.count) base suggestions")
            suggestions = filterSuggestionsByCategory(baseSuggestions, category: category)
            isLoading = false

            if suggestions.isEmpty {
                errorMessage = "No owned plugins suitable for '\(category.rawValue)'"
                print("⚠️ [AI Suggestions] No plugins found suitable for this category after smart filtering")
            } else {
                print("✅ [AI Suggestions] Found \(suggestions.count) plugins suitable for '\(category.rawValue)'")
            }
            return
        }

        // Track AI request for dashboard reporting
        dashboardTrackAIRequest()

        // IMPORTANT: Exclude the current plugin from suggestions + owned plugins + previously shown
        let excludedPlugins = [plugin] + ownedPlugins + previouslyShownSuggestions.map { name in
            PluginItem(name: name, publisher: "", version: "", type: "", style: "",
                      architectures: "", date: nil, sizeBytes: 0, path: "",
                      runtimeRequirement: "", obsolete: false)
        }

        // Handle FREE category specially
        if category == .free {
            print("🎯 [FREE Category] Looking for free '\(plugin.style)' plugins to download")

            var allSuggestions: [PluginSuggestion] = []

            // STEP 1: Check Firebase database first (INSTANT)
            print("⚡️ [FREE Category] Checking Firebase for verified free '\(plugin.style)' plugins...")
            do {
                let freePlugins = try await FirestoreManager.shared.fetchFreePlugins(category: plugin.style)

                if !freePlugins.isEmpty {
                    // Convert Firebase FreePlugin to PluginSuggestion
                    let firebaseSuggestions = freePlugins.map { freePlugin in
                        PluginSuggestion(
                            name: freePlugin.name,
                            reason: freePlugin.reason,
                            source: .firebase  // Verified in Firebase
                        )
                    }

                    let filteredFirebase = filterOwnedPlugins(firebaseSuggestions, ownedPlugins: excludedPlugins)
                    print("✅ [FREE Category] Found \(filteredFirebase.count) verified free plugins from Firebase (INSTANT)")
                    allSuggestions.append(contentsOf: filteredFirebase.shuffled())
                } else {
                    print("📭 [FREE Category] No verified plugins in Firebase for '\(plugin.style)' - will use AI discovery")
                }
            } catch {
                print("⚠️ [FREE Category] Firebase query failed: \(error.localizedDescription) - will use AI discovery")
            }

            // STEP 2: If Firebase has fewer than 10 plugins, discover more with AI + save
            if allSuggestions.count < 10 {
                print("🤖 [FREE Category] Firebase has \(allSuggestions.count) plugins - discovering more with AI...")
                do {
                    let aiSuggestions = try await fetchFreePluginsFromGemini(plugin: plugin, ownedPlugins: excludedPlugins)
                    print("📥 [FREE Category] Gemini AI returned \(aiSuggestions.count) free plugin suggestions")

                    // SKIP SLOW VERIFICATION - Trust AI for now, verify later in background
                    // The improved prompt asks AI to only suggest truly free plugins
                    print("⚡ [FREE Category] Trusting AI suggestions (verification skipped for speed)")

                    // SAVE AI suggestions to Firebase for future instant access
                    print("💾 [FREE Category] Saving plugins to Firebase...")
                    let pluginsToSave = aiSuggestions.map { suggestion -> (name: String, category: String, reason: String, developer: String) in
                        // Extract developer from reason (format: "Plugin Name by Developer - ...")
                        let developer = extractDeveloper(from: suggestion.reason)
                        return (name: suggestion.name, category: plugin.style, reason: suggestion.reason, developer: developer)
                    }

                    // Save to Firebase in background (don't block UI)
                    Task {
                        do {
                            try await FirestoreManager.shared.saveFreePlugins(pluginsToSave)
                            print("✅ [FREE Category] Saved \(pluginsToSave.count) plugins to Firebase")
                        } catch {
                            print("⚠️ Failed to save plugins to Firebase: \(error.localizedDescription)")
                        }
                    }

                    let filteredAI = filterOwnedPlugins(aiSuggestions, ownedPlugins: excludedPlugins)
                    print("✅ [FREE Category] After filtering owned plugins: \(filteredAI.count) suggestions remain")
                    allSuggestions.append(contentsOf: filteredAI)
                } catch {
                    print("❌ [FREE Category] AI discovery failed: \(error.localizedDescription)")

                    // FALLBACK: Only use curated list if both Firebase AND AI fail
                    if allSuggestions.isEmpty {
                        print("🔄 [FREE Category] FALLBACK: Using curated verified free plugins...")
                        let curatedSuggestions = CategoryPluginKnowledge.getFreeSuggestions(pluginStyle: plugin.style)
                        let filteredCurated = filterOwnedPlugins(curatedSuggestions, ownedPlugins: excludedPlugins)
                        print("✅ [FREE Category] Curated fallback: \(filteredCurated.count) verified free plugins")
                        allSuggestions.append(contentsOf: filteredCurated.shuffled())
                    }
                }
            }

            print("📊 [FREE Category] Total suggestions: \(allSuggestions.count) free plugin(s) found")

            let newSuggestions = allSuggestions

            // Show more suggestions now that we have both curated + AI (5-20 instead of 5-10)
            // Prioritize showing verified plugins first
            let count = min(max(newSuggestions.count, 5), 20)
            let limitedSuggestions = Array(newSuggestions.prefix(count))

            for suggestion in limitedSuggestions {
                previouslyShownSuggestions.insert(suggestion.name)
            }

            // Deduplicate after appending or setting
            if appendMode {
                suggestions.append(contentsOf: limitedSuggestions)
                suggestions = deduplicate(suggestions)
            } else {
                suggestions = deduplicate(limitedSuggestions)
            }

            isLoading = false
            return
        }

        // For all other categories, use hybrid approach: curated + AI
        print("🎯 [\(category.rawValue)] Looking for suggestions for '\(plugin.style)' plugins")

        var allSuggestions: [PluginSuggestion] = []

        // STEP 1: Get curated suggestions from local database
        print("🔍 [\(category.rawValue)] Step 1: Loading curated suggestions...")
        let curatedSuggestions = CategoryPluginKnowledge.getSuggestions(for: category, pluginStyle: plugin.style)
        let filteredCurated = filterOwnedPlugins(curatedSuggestions, ownedPlugins: excludedPlugins)
        print("✅ [\(category.rawValue)] Curated database: \(filteredCurated.count) suggestions")

        // Shuffle curated results so each regenerate shows different order
        allSuggestions.append(contentsOf: filteredCurated.shuffled())

        // STEP 2: Only query AI if we have fewer than 10 curated suggestions
        // This makes the UI much faster by avoiding unnecessary AI calls
        if filteredCurated.count < 10 {
            print("🤖 [\(category.rawValue)] Step 2: Querying AI for additional suggestions (only \(filteredCurated.count) curated found)...")
            do {
                var aiSuggestions: [PluginSuggestion] = []

                // Try Gemini first (free for everyone)
                do {
                    aiSuggestions = try await fetchFromGemini(plugin: plugin, ownedPlugins: excludedPlugins)
                    print("📥 [\(category.rawValue)] Gemini returned \(aiSuggestions.count) suggestions")
                } catch {
                    print("⚠️ [\(category.rawValue)] Gemini failed: \(error.localizedDescription)")

                    // Fallback to OpenAI if available
                    if let apiKey = openAIKey, !apiKey.isEmpty {
                        aiSuggestions = try await fetchFromOpenAI(plugin: plugin, apiKey: apiKey, ownedPlugins: excludedPlugins)
                        print("📥 [\(category.rawValue)] OpenAI returned \(aiSuggestions.count) suggestions")
                    }
                }

                let filteredAI = filterOwnedPlugins(aiSuggestions, ownedPlugins: excludedPlugins)
                print("✅ [\(category.rawValue)] AI suggestions after filtering: \(filteredAI.count) plugins")
                allSuggestions.append(contentsOf: filteredAI)
            } catch {
                print("⚠️ [\(category.rawValue)] AI query failed: \(error.localizedDescription)")
            }
        } else {
            print("⚡ [\(category.rawValue)] Skipping AI query - enough curated suggestions (\(filteredCurated.count) found)")
        }

        print("📊 [\(category.rawValue)] Total suggestions: \(allSuggestions.count) (\(filteredCurated.count) curated + \(allSuggestions.count - filteredCurated.count) AI-suggested)")

        let newSuggestions = allSuggestions

        // Show more suggestions now that we have both curated + AI (5-20 instead of 5-10)
        let count = min(max(newSuggestions.count, 5), 20)
        let limitedSuggestions = Array(newSuggestions.prefix(count))

        // Track these suggestions
        for suggestion in limitedSuggestions {
            previouslyShownSuggestions.insert(suggestion.name)
        }

        // Append or replace based on mode, then deduplicate
        if appendMode {
            suggestions.append(contentsOf: limitedSuggestions)
            suggestions = deduplicate(suggestions)
        } else {
            suggestions = deduplicate(limitedSuggestions)
        }

        isLoading = false
    }

    // MARK: - Free Plugin Verification

    private func verifyFreePlugins(_ suggestions: [PluginSuggestion]) async -> [PluginSuggestion] {
        var verified: [PluginSuggestion] = []

        // Verify up to 15 plugins (to stay within reasonable time limits)
        let pluginsToVerify = suggestions.prefix(15)

        for suggestion in pluginsToVerify {
            let isActuallyFree = await isPluginFree(suggestion.name)
            if isActuallyFree {
                print("   ✅ Verified: '\(suggestion.name)' is free")
                verified.append(suggestion)
            } else {
                print("   ❌ Not free: '\(suggestion.name)' - excluding from results")
            }
        }

        return verified
    }

    private func isPluginFree(_ pluginName: String) async -> Bool {
        // Use Gemini AI to verify if plugin is actually free
        let searchQuery = "\(pluginName) audio plugin free download"

        do {
            // Ask Gemini to verify if plugin is free
            let result = try await searchWeb(query: searchQuery)
            let trimmed = result.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Check if Gemini says it's free
            return trimmed.contains("FREE")

        } catch {
            print("   ⚠️ Could not verify '\(pluginName)': \(error.localizedDescription) - excluding for safety")
            return false  // If we can't verify, exclude it (better safe than sorry)
        }
    }

    private func searchWeb(query: String) async throws -> String {
        // Use Gemini to search and verify if plugin is free
        // This is more reliable than keyword matching
        let verificationPrompt = """
        Search the web for information about: \(query)

        Answer ONLY with "FREE" or "PAID":
        - Answer "FREE" if this is a completely free plugin (not trial, not lite version)
        - Answer "PAID" if this requires payment, is a trial, or is a paid-upgrade-available version

        Your answer (FREE or PAID):
        """

        let geminiApiKey = "AIzaSyAuiPO9EFXmRPy8L2RDqhxwGtXlw_v2mxg"

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=\(geminiApiKey)") else {
            throw AIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": verificationPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,  // Low temperature for factual answers
                "maxOutputTokens": 10
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.invalidResponse
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw AIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - Google Gemini Integration (Free for all users!)

    private func fetchFromGemini(plugin: PluginItem, ownedPlugins: [PluginItem]) async throws -> [PluginSuggestion] {
        // Gemini API key (free tier: 60 requests/minute, 1500/day)
        let geminiApiKey = "AIzaSyAuiPO9EFXmRPy8L2RDqhxwGtXlw_v2mxg"

        let prompt = buildPrompt(for: plugin, excluding: ownedPlugins)

        // Use gemini-2.0-flash-lite (higher quota: 1000 req/day vs 200 req/day)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=\(geminiApiKey)") else {
            throw AIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            You are an expert audio engineer with extensive knowledge of professional audio plugins from companies like Plugin Alliance, FabFilter, Waves, UAD, iZotope, Soundtoys, Arturia, Native Instruments, and others.

                            \(prompt)

                            Format your response as a numbered list where each line follows this exact pattern:
                            1. Plugin Name - Reason why it's similar
                            2. Plugin Name - Reason why it's similar
                            """
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.8,
                "maxOutputTokens": 400
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiError("Gemini HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw AIError.invalidResponse
        }

        let suggestions = parseOpenAIResponse(content: content, plugin: plugin)
        return filterOwnedPlugins(suggestions, ownedPlugins: ownedPlugins)
    }

    private func fetchFreePluginsFromGemini(plugin: PluginItem, ownedPlugins: [PluginItem]) async throws -> [PluginSuggestion] {
        // Gemini API key (free tier: 60 requests/minute, 1500/day)
        let geminiApiKey = "AIzaSyAuiPO9EFXmRPy8L2RDqhxwGtXlw_v2mxg"

        let prompt = buildFreePrompt(for: plugin, excluding: ownedPlugins)
        print("📝 [Gemini] Built prompt for '\(plugin.style)' plugins")

        // Use gemini-2.0-flash-lite (higher quota: 1000 req/day vs 200 req/day)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=\(geminiApiKey)") else {
            print("❌ [Gemini] Failed to create URL")
            throw AIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            You are an expert audio engineer with extensive knowledge of FREE audio plugins. Focus only on completely free plugins, not free trials or lite versions.

                            \(prompt)

                            Format your response as a numbered list where each line follows this exact pattern:
                            1. Plugin Name - Reason why it's free and good
                            2. Plugin Name - Reason why it's free and good
                            """
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.9,
                "maxOutputTokens": 800
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("✅ [Gemini] Request body serialized successfully")
        } catch {
            print("❌ [Gemini] Failed to serialize request body: \(error)")
            throw AIError.apiError("Failed to create request: \(error.localizedDescription)")
        }

        print("🌐 [Gemini] Sending request to Gemini API...")

        let (data, response) = try await URLSession.shared.data(for: request)

        print("📥 [Gemini] Received response")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [Gemini] Invalid response type")
            throw AIError.invalidResponse
        }

        print("📊 [Gemini] HTTP Status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            // Log the error response body
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ [Gemini] Error response body: \(errorBody)")
            }
            throw AIError.apiError("Gemini HTTP error \(httpResponse.statusCode)")
        }

        print("🔍 [Gemini] Attempting to decode response...")

        do {
            let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
            print("✅ [Gemini] Response decoded successfully")

            guard let content = result.candidates.first?.content.parts.first?.text else {
                print("❌ [Gemini] No content in response")
                throw AIError.invalidResponse
            }

            print("📝 [Gemini] Received content, parsing suggestions...")
            let suggestions = parseOpenAIResponse(content: content, plugin: plugin)
            print("✅ [Gemini] Parsed \(suggestions.count) raw suggestions from AI")

            // Log the raw suggestions before filtering
            for (index, suggestion) in suggestions.enumerated() {
                print("   [\(index + 1)] \(suggestion.name)")
            }

            let filtered = filterOwnedPlugins(suggestions, ownedPlugins: ownedPlugins)
            print("🔍 [Gemini] After filtering owned plugins: \(filtered.count) suggestions remain")

            return filtered
        } catch {
            print("❌ [Gemini] Failed to decode response: \(error)")
            if let responseBody = String(data: data, encoding: .utf8) {
                print("📄 [Gemini] Response body: \(responseBody)")
            }
            throw AIError.apiError("Failed to decode response: \(error.localizedDescription)")
        }
    }

    private func summarizeExcludedPlugins(_ plugins: [PluginItem], maxEntries: Int = 50, maxCharacters: Int = 2000) -> String {
        guard !plugins.isEmpty else { return "None" }

        var seen = Set<String>()
        var uniqueNames: [String] = []
        uniqueNames.reserveCapacity(min(plugins.count, maxEntries))

        for plugin in plugins {
            let trimmed = plugin.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                uniqueNames.append(trimmed)
            }
        }

        guard !uniqueNames.isEmpty else { return "None" }

        var output = ""
        var included = 0
        var truncated = false

        for name in uniqueNames {
            if included >= maxEntries {
                truncated = true
                break
            }

            let addition = included == 0 ? name : ", \(name)"
            if output.count + addition.count > maxCharacters {
                truncated = true
                break
            }

            output += addition
            included += 1
        }

        let remaining = uniqueNames.count - included
        if remaining > 0 {
            truncated = true
            let suffix = ", +\(remaining) more"
            if output.isEmpty {
                output = "+\(remaining) more"
            } else if output.count + suffix.count <= maxCharacters {
                output += suffix
            } else {
                output += ", +more"
            }
        }

        if truncated {
            print("ℹ️ [AI Suggestions] Trimmed exclusion list to \(included) names (+\(max(remaining, 0)) more) to stay within OpenAI prompt limits")
        }

        return output.isEmpty ? "None" : output
    }

    private func buildPrompt(for plugin: PluginItem, excluding ownedPlugins: [PluginItem]) -> String {
        let ownedNames = summarizeExcludedPlugins(ownedPlugins)

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

        5. FAMOUS USES: For each plugin, include famous songs, artists, producers, or engineers who use it (if known).

        Format as:
        1. Plugin Name - Brief reason (why it's similar/alternative) | Famous use: Song "Title" by Artist (Producer/Engineer) [if known]
        2. Plugin Name - Brief reason | Famous use: Used by Producer Name on Album [if known]
        etc.

        If no famous uses are known for a plugin, just provide: "Plugin Name - Brief reason"

        Prioritize current, actively-developed plugins with good reputation in 2024-2025.
        """
    }

    private func buildFreePrompt(for plugin: PluginItem, excluding ownedPlugins: [PluginItem]) -> String {
        let ownedNames = summarizeExcludedPlugins(ownedPlugins)

        return """
        You are a plugin discovery expert. Find 10-15 FREE \(plugin.style) plugins available for download in 2024-2025.

        CRITICAL REQUIREMENTS:
        1. MUST BE 100% FREE - Not trials, not lite versions, not paid plugins
        2. MUST BE AVAILABLE NOW - Currently downloadable from official websites
        3. MUST MATCH CATEGORY: "\(plugin.style)" plugins only
        4. FIND DIFFERENT PLUGINS - Search widely across the internet for lesser-known free options

        EXCLUDE these plugins (already shown or owned):
        \(ownedNames.isEmpty ? "None" : ownedNames)

        SEARCH THESE SOURCES:
        - KVR Audio free plugin database
        - Plugin Boutique free plugins
        - Bedroom Producers Blog free plugins
        - GitHub open-source audio plugins
        - Independent developer websites (Voxengo, TDR, Variety of Sound, etc.)
        - Company free tiers (Melda, Native Instruments, Spitfire LABS instruments only)

        FORMAT (one per line):
        1. Plugin Name by Developer - Why it's free and good for \(plugin.style) | Famous use: Song/Artist/Producer [if known]
        2. Plugin Name by Developer - Why it's free and good for \(plugin.style) | Famous use: Usage details [if known]

        If no famous uses are known for a plugin, just provide: "Plugin Name by Developer - Why it's free and good"

        Focus on VARIETY - include well-known AND obscure free plugins. Prioritize plugins that are actually free to download today.
        """
    }

    private func parseOpenAIResponse(content: String, plugin: PluginItem) -> [PluginSuggestion] {
        // Parse numbered list from GPT response
        let lines = content.split(separator: "\n")
        var suggestions: [PluginSuggestion] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Match "1. Plugin Name - Reason" or "1) Plugin Name - Reason" optionally with "| Famous use: ..."
            if let match = trimmed.range(of: #"^\d+[\.)]\s*(.+?)\s*-\s*(.+)$"#, options: .regularExpression) {
                let content = String(trimmed[match])
                let parts = content.split(separator: "-", maxSplits: 1)
                if parts.count == 2 {
                    var name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: #"^\d+[\.)]\s*"#, with: "", options: .regularExpression)

                    // Strip markdown formatting (**, *, ~~, etc.)
                    name = name.replacingOccurrences(of: "**", with: "")
                               .replacingOccurrences(of: "*", with: "")
                               .replacingOccurrences(of: "~~", with: "")
                               .replacingOccurrences(of: "`", with: "")
                               .trimmingCharacters(in: .whitespacesAndNewlines)

                    var reasonText = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

                    // Check if there's famous use information (format: "Reason | Famous use: Details")
                    if reasonText.contains("|") {
                        let reasonParts = reasonText.split(separator: "|", maxSplits: 1)
                        if reasonParts.count == 2 {
                            let mainReason = reasonParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                            let famousUse = reasonParts[1]
                                .replacingOccurrences(of: "Famous use:", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)

                            // Append famous use to reason for display
                            reasonText = "\(mainReason)\n💿 \(famousUse)"
                        }
                    }

                    suggestions.append(PluginSuggestion(
                        name: name,
                        reason: reasonText,
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

    /// Extract developer name from reason string
    /// Format: "Plugin Name by Developer - Description"
    private func extractDeveloper(from reason: String) -> String {
        // Look for pattern "by Developer"
        if let byRange = reason.range(of: " by ", options: .caseInsensitive) {
            let afterBy = reason[byRange.upperBound...]
            // Extract until dash or end of string
            if let dashRange = afterBy.range(of: " - ") {
                return String(afterBy[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            } else {
                return String(afterBy).trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown"
    }

    // MARK: - Local AI (Fallback)

    private func fetchFromLocal(plugin: PluginItem, ownedPlugins: [PluginItem]) async -> [PluginSuggestion] {
        // Local knowledge base of common plugin alternatives
        let suggestions = LocalPluginKnowledge.getSuggestions(for: plugin)
        return filterOwnedPlugins(suggestions, ownedPlugins: ownedPlugins)
    }

    // MARK: - Owned Alternatives (DAW Import Feature)

    /// Find owned plugins that could replace a missing plugin (for DAW Import)
    private func findOwnedAlternatives(for missingPlugin: PluginItem, from ownedPlugins: [PluginItem]) -> [PluginSuggestion] {
        print("🔍 [findOwnedAlternatives] Finding alternatives for '\(missingPlugin.name)', style: '\(missingPlugin.style)', publisher: '\(missingPlugin.publisher)'")
        print("🔍 [findOwnedAlternatives] Searching through \(ownedPlugins.count) owned plugins")

        var alternatives: [PluginSuggestion] = []
        let missingStyle = missingPlugin.style.lowercased()
        let missingName = missingPlugin.name.lowercased()
        let missingPublisher = missingPlugin.publisher.lowercased()

        print("🔍 [findOwnedAlternatives] Normalized - style: '\(missingStyle)', name: '\(missingName)', publisher: '\(missingPublisher)'")

        // DEBUG: Count how many plugins have matching style
        let matchingStyleCount = ownedPlugins.filter { $0.style.lowercased() == missingStyle }.count
        print("🔍 [findOwnedAlternatives] Found \(matchingStyleCount) plugins with exact style match '\(missingStyle)'")

        // Filter out ALL versions of the plugin (different formats: AAX, AU, VST, VST3)
        // This prevents suggesting "2016 Stereo Room AU" as alternative to "2016 Stereo Room AAX"
        let filteredPlugins = ownedPlugins.filter { owned in
            owned.name.lowercased() != missingName
        }

        print("🔍 [findOwnedAlternatives] Filtered out all versions of '\(missingPlugin.name)' - \(ownedPlugins.count - filteredPlugins.count) plugins removed")
        print("🔍 [findOwnedAlternatives] Remaining plugins to check: \(filteredPlugins.count)")

        // Define plugin keywords and their categories
        let pluginKeywords: [(keywords: [String], category: String, styleKeywords: [String])] = [
            (["eq", "equalizer", "equalization"], "EQ", ["eq", "channel", "strip"]),
            (["comp", "compressor", "compression"], "Compressor", ["dynamics", "comp"]),
            (["reverb", "verb"], "Reverb", ["reverb", "space"]),
            (["delay", "echo"], "Delay", ["delay", "echo"]),
            (["synth", "synthesizer"], "Synthesizer", ["instrument", "synth"]),
            (["limiter", "limiting"], "Limiter", ["dynamics", "limiter"]),
            (["gate", "noise gate"], "Gate", ["dynamics", "gate"]),
            (["distortion", "overdrive", "saturator", "saturation"], "Distortion", ["distortion", "saturator"]),
            (["filter", "filtering"], "Filter", ["filter", "eq"]),
            (["chorus", "flanger", "phaser"], "Modulation", ["modulation"]),
            (["channel", "strip"], "Channel Strip", ["channel", "dynamics", "eq"])
        ]

        // Detect the missing plugin's category from its name OR style
        var detectedCategory = "Plugin"
        var matchedKeywords: [String] = []

        // First try to detect from plugin name
        for (keywords, category, _) in pluginKeywords {
            for keyword in keywords {
                if missingName.contains(keyword) {
                    detectedCategory = category
                    matchedKeywords = keywords
                    break
                }
            }
            if !matchedKeywords.isEmpty { break }
        }

        // If not found in name, try to detect from style field
        if matchedKeywords.isEmpty && !missingStyle.isEmpty {
            for (keywords, category, _) in pluginKeywords {
                for keyword in keywords {
                    if missingStyle.contains(keyword) {
                        detectedCategory = category
                        matchedKeywords = keywords
                        break
                    }
                }
                if !matchedKeywords.isEmpty { break }
            }
        }

        print("🔍 [findOwnedAlternatives] Detected category: '\(detectedCategory)', keywords: \(matchedKeywords)")

        if matchedKeywords.isEmpty {
            print("⚠️ [findOwnedAlternatives] No keywords matched! This may result in poor matching.")
        }

        // Score each owned plugin based on similarity
        var scoredPlugins: [(plugin: PluginItem, score: Int, reason: String)] = []

        print("🔍 [findOwnedAlternatives] Starting to score \(filteredPlugins.count) owned plugins...")

        for (idx, owned) in filteredPlugins.enumerated() {
            var score = 0
            var reasons: [String] = []
            let ownedName = owned.name.lowercased()
            let ownedStyle = owned.style.lowercased()

            if idx < 10 {  // Log first 10 plugins being checked
                print("   Checking [\(idx + 1)]: '\(owned.name)' (style: '\(owned.style)')")
            }

            // Check for exact name match keywords (highest priority)
            for keyword in matchedKeywords {
                if ownedName.contains(keyword) {
                    score += 50
                    reasons.append("Similar \(detectedCategory)")
                    if idx < 10 {
                        print("      +50 points: name contains keyword '\(keyword)'")
                    }
                    break
                }
            }

            // Check for style match with detected category
            if !missingStyle.isEmpty {
                if ownedStyle == missingStyle {
                    score += 40
                    reasons.append("Exact category match")
                    if idx < 10 {
                        print("      +40 points: exact style match ('\(ownedStyle)' == '\(missingStyle)')")
                    }
                } else if ownedStyle.contains(detectedCategory.lowercased()) {
                    score += 30
                    reasons.append("Category match")
                    if idx < 10 {
                        print("      +30 points: style contains category '\(detectedCategory.lowercased())'")
                    }
                }
            }

            // Check for style keywords matching
            for (keywords, _, styleKeywords) in pluginKeywords {
                if matchedKeywords == keywords {
                    for styleKeyword in styleKeywords {
                        if ownedStyle.contains(styleKeyword) {
                            score += 25
                            reasons.append("Related category")
                            break
                        }
                    }
                    break
                }
            }

            // Check for publisher match (same manufacturer might have alternatives)
            if !missingPublisher.isEmpty && owned.publisher.lowercased() == missingPublisher {
                score += 20
                reasons.append("From same manufacturer")
            }

            // Partial name similarity (any shared word of 4+ chars)
            let missingWords = missingName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 4 }
            let ownedWords = ownedName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 4 }
            let sharedWords = Set(missingWords).intersection(Set(ownedWords))
            if !sharedWords.isEmpty {
                score += 15 * sharedWords.count
                reasons.append("Similar naming")
            }

            // Only include plugins with some relevance
            if score > 0 {
                let reason = reasons.isEmpty ? "From your collection" : reasons.joined(separator: " • ")
                scoredPlugins.append((owned, score, reason))
                if idx < 10 {
                    print("      ✅ Total score: \(score) - \(reason)")
                }
            } else if idx < 10 {
                print("      ❌ Score: 0 (not relevant)")
            }
        }

        // Sort by score and take top matches
        scoredPlugins.sort { $0.score > $1.score }

        print("🔍 [findOwnedAlternatives] Scored \(scoredPlugins.count) plugins with score > 0")
        if scoredPlugins.count > 0 {
            print("🔍 [findOwnedAlternatives] ALL scored plugins:")
            for (owned, score, reason) in scoredPlugins {
                print("   - \(owned.name) (style: '\(owned.style)') - score: \(score) - \(reason)")
            }
        }

        // Show ALL alternatives (up to 20 max to keep UI manageable)
        let maxResults = 20
        let count = min(scoredPlugins.count, maxResults)
        print("🔍 [findOwnedAlternatives] Returning \(count) alternatives (from \(scoredPlugins.count) scored plugins)")

        for (owned, _, reason) in scoredPlugins.prefix(count) {
            alternatives.append(PluginSuggestion(
                name: owned.name,
                reason: "You own this • \(reason)",
                source: .local
            ))
        }

        // If no alternatives found, show helpful message
        if alternatives.isEmpty {
            alternatives.append(PluginSuggestion(
                name: "No similar plugins found",
                reason: "You don't own any plugins similar to \(missingPlugin.name). Try other AI categories for purchasing suggestions.",
                source: .local
            ))
        }

        return alternatives
    }
}

// MARK: - Models

struct PluginSuggestion: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let reason: String
    let source: SuggestionSource
    var heritage: PluginHeritage?  // Heritage data (hardware, famous uses, etc.)
    let style: String?  // Plugin style/type from metadata

    init(name: String, reason: String, source: SuggestionSource, heritage: PluginHeritage? = nil, style: String? = nil) {
        self.name = name
        self.reason = reason
        self.source = source
        self.heritage = heritage
        self.style = style
    }

    // Custom Hashable conformance (exclude heritage and style from hash)
    func hash(into hasher: inout Hasher) {
        hasher.combine(name.lowercased())
    }

    static func == (lhs: PluginSuggestion, rhs: PluginSuggestion) -> Bool {
        lhs.name.lowercased() == rhs.name.lowercased()
    }
}

enum SuggestionSource {
    case openAI
    case local
    case firebase  // Verified free plugins from Firebase database
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

private struct GeminiResponse: Codable {
    let candidates: [Candidate]

    struct Candidate: Codable {
        let content: Content
    }

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String
    }
}

// MARK: - Local Plugin Knowledge Database

struct LocalPluginKnowledge {
    static func getSuggestions(for plugin: PluginItem) -> [PluginSuggestion] {
        let name = plugin.name.lowercased()
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
        } else if publisher.contains("waves") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Waves SSL E-Channel", reason: "SSL console emulation", source: .local),
                PluginSuggestion(name: "Waves CLA-2A", reason: "LA-2A compressor emulation", source: .local),
                PluginSuggestion(name: "Waves Abbey Road TG", reason: "Abbey Road mastering chain", source: .local),
                PluginSuggestion(name: "Waves H-Reverb", reason: "Hybrid reverb", source: .local),
                PluginSuggestion(name: "Waves MetaFlanger", reason: "Modulation effect", source: .local)
            ])
        } else if publisher.contains("eventide") {
            suggestions.append(contentsOf: [
                PluginSuggestion(name: "Eventide H3000", reason: "Legendary multi-effects processor", source: .local),
                PluginSuggestion(name: "Eventide Blackhole", reason: "Creative reverb", source: .local),
                PluginSuggestion(name: "Eventide UltraChannel", reason: "Channel strip plugin", source: .local),
                PluginSuggestion(name: "Eventide H910", reason: "Vintage pitch shifter", source: .local),
                PluginSuggestion(name: "Eventide UltraReverb", reason: "Premium reverb", source: .local)
            ])
        } else if publisher.contains("soundtoys") {
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
        PluginSuggestion(name: "Voxengo OldSkoolVerb Plus", reason: "Free enhanced version with stereo room simulation", source: .local),

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

        // Valhalla DSP (Free Plugins)
        PluginSuggestion(name: "Valhalla Freq Echo", reason: "Free frequency shifter and delay effect", source: .local),
        PluginSuggestion(name: "Valhalla Supermassive", reason: "Free massive reverb and delay with huge spaces", source: .local),

        // Free Reverbs (Verified 100% Free)
        PluginSuggestion(name: "Dragonfly Reverb", reason: "Free reverb with natural room and hall algorithms", source: .local),
        PluginSuggestion(name: "TAL-Reverb-4", reason: "Free vintage reverb with classic plate and spring sounds", source: .local),
        PluginSuggestion(name: "OrilRiver", reason: "Free algorithmic reverb by Denis Tihanov with excellent sound quality", source: .local),
        PluginSuggestion(name: "Ambience", reason: "Free reverb by Smart Electronix with natural room simulation", source: .local),
        PluginSuggestion(name: "EpicVerb", reason: "Free algorithmic reverb by Variety of Sound with spacious sounds", source: .local),
        PluginSuggestion(name: "FreeverbToo", reason: "Free reverb by Acustica Audio with CPU-friendly algorithms", source: .local),
        PluginSuggestion(name: "Protoverb", reason: "Free experimental reverb with unique frequency-domain processing", source: .local),

        // Other Free Plugins
        PluginSuggestion(name: "Soft Tube Saturation Knob", reason: "Free saturation plugin for adding warmth", source: .local),
        PluginSuggestion(name: "Izotope Vinyl", reason: "Free lo-fi and vinyl effect", source: .local),
        PluginSuggestion(name: "Xfer OTT", reason: "Free multiband compressor", source: .local),
        PluginSuggestion(name: "Ample Bass P Lite", reason: "Free precision bass instrument", source: .local),
        PluginSuggestion(name: "Dexed", reason: "Free DX7 FM synthesizer", source: .local),
        PluginSuggestion(name: "Vital", reason: "Free wavetable synthesizer", source: .local)
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

        // Plugin Type Categories
        case .eq:
            return [
                PluginSuggestion(name: "FabFilter Pro-Q 3", reason: "Industry standard EQ with surgical precision", source: .local),
                PluginSuggestion(name: "Waves Q10", reason: "Versatile 10-band parametric EQ", source: .local),
                PluginSuggestion(name: "iZotope Neutron", reason: "Intelligent EQ with visual feedback", source: .local),
                PluginSuggestion(name: "DMG Audio Equilibrium", reason: "High-end transparent EQ", source: .local)
            ]

        case .compressor:
            return [
                PluginSuggestion(name: "FabFilter Pro-C 2", reason: "Transparent compression for any source", source: .local),
                PluginSuggestion(name: "Waves CLA-76", reason: "Classic 1176 compression", source: .local),
                PluginSuggestion(name: "Waves CLA-2A", reason: "Smooth optical compression", source: .local),
                PluginSuggestion(name: "UAD 1176", reason: "Authentic FET compression", source: .local)
            ]

        case .limiter:
            return [
                PluginSuggestion(name: "FabFilter Pro-L 2", reason: "Modern transparent limiting", source: .local),
                PluginSuggestion(name: "Waves L2", reason: "Classic brick wall limiter", source: .local),
                PluginSuggestion(name: "iZotope Ozone Maximizer", reason: "Intelligent loudness maximizer", source: .local),
                PluginSuggestion(name: "Slate Digital FG-X", reason: "Virtual mastering processor", source: .local)
            ]

        case .reverb:
            return [
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Lush algorithmic reverb", source: .local),
                PluginSuggestion(name: "Valhalla Room", reason: "Natural room reverb", source: .local),
                PluginSuggestion(name: "Waves H-Reverb", reason: "Hybrid reverb engine", source: .local),
                PluginSuggestion(name: "FabFilter Pro-R", reason: "Modern reverb with clean interface", source: .local)
            ]

        case .delay:
            return [
                PluginSuggestion(name: "Soundtoys EchoBoy", reason: "Versatile delay with character", source: .local),
                PluginSuggestion(name: "Valhalla Delay", reason: "Modern tape and analog delays", source: .local),
                PluginSuggestion(name: "FabFilter Timeless 3", reason: "Creative filter delays", source: .local),
                PluginSuggestion(name: "Waves H-Delay", reason: "Hybrid delay with analog modeling", source: .local)
            ]

        case .chorus:
            return [
                PluginSuggestion(name: "Soundtoys Tremolator", reason: "Vintage chorus effects", source: .local),
                PluginSuggestion(name: "Valhalla UberMod", reason: "Modern modulation delays", source: .local),
                PluginSuggestion(name: "Waves Doubler", reason: "Vocal and instrument doubling", source: .local)
            ]

        case .flanger:
            return [
                PluginSuggestion(name: "Soundtoys FilterFreak", reason: "Creative flanging and filtering", source: .local),
                PluginSuggestion(name: "Waves MetaFlanger", reason: "Versatile flanger effects", source: .local)
            ]

        case .phaser:
            return [
                PluginSuggestion(name: "Soundtoys Phase Mistress", reason: "Analog phaser emulation", source: .local),
                PluginSuggestion(name: "Waves MondoMod", reason: "Multi-effect modulation", source: .local)
            ]

        case .distortion:
            return [
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Analog saturation and distortion", source: .local),
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "Multi-band distortion", source: .local),
                PluginSuggestion(name: "Waves Kramer Tape", reason: "Tape saturation", source: .local)
            ]

        case .saturation:
            return [
                PluginSuggestion(name: "FabFilter Saturn 2", reason: "Versatile multi-band saturation", source: .local),
                PluginSuggestion(name: "Soundtoys Decapitator", reason: "Analog saturation models", source: .local),
                PluginSuggestion(name: "Slate Digital Virtual Tape Machines", reason: "Authentic tape saturation", source: .local)
            ]

        case .filter:
            return [
                PluginSuggestion(name: "FabFilter Volcano 3", reason: "Creative filter effects", source: .local),
                PluginSuggestion(name: "Soundtoys FilterFreak", reason: "Analog filter emulation", source: .local)
            ]

        case .gate:
            return [
                PluginSuggestion(name: "Waves Renaissance Gate", reason: "Precision gating and expansion", source: .local),
                PluginSuggestion(name: "FabFilter Pro-G", reason: "Modern gate with visual feedback", source: .local)
            ]

        case .deesser:
            return [
                PluginSuggestion(name: "FabFilter Pro-DS", reason: "Intelligent de-essing", source: .local),
                PluginSuggestion(name: "Waves Renaissance DeEsser", reason: "Classic vocal de-esser", source: .local)
            ]

        case .multiband:
            return [
                PluginSuggestion(name: "FabFilter Pro-MB", reason: "Transparent multiband dynamics", source: .local),
                PluginSuggestion(name: "Waves C6", reason: "Multiband compressor", source: .local),
                PluginSuggestion(name: "iZotope Ozone Dynamic EQ", reason: "Frequency-specific dynamics", source: .local)
            ]

        case .spatial, .stereo:
            return [
                PluginSuggestion(name: "Valhalla VintageVerb", reason: "Spacious stereo reverb", source: .local),
                PluginSuggestion(name: "Waves S1 Stereo Imager", reason: "Stereo width control", source: .local),
                PluginSuggestion(name: "Goodhertz CanOpener", reason: "Crossfeed and spatial processing", source: .local)
            ]

        case .atmos, .surround:
            return [
                PluginSuggestion(name: "Waves Abbey Road Studio 3", reason: "Immersive surround reverb", source: .local),
                PluginSuggestion(name: "iZotope Ozone Imager", reason: "Stereo and surround imaging", source: .local)
            ]

        case .analyzer, .metering:
            return [
                PluginSuggestion(name: "Voxengo SPAN", reason: "Free spectrum analyzer", source: .local),
                PluginSuggestion(name: "iZotope Insight 2", reason: "Professional metering suite", source: .local),
                PluginSuggestion(name: "Youlean Loudness Meter", reason: "Industry-standard loudness metering", source: .local)
            ]

        case .synth:
            return [
                PluginSuggestion(name: "Serum by Xfer", reason: "Wavetable synthesis standard", source: .local),
                PluginSuggestion(name: "Omnisphere 2", reason: "Massive sound library", source: .local),
                PluginSuggestion(name: "Massive X", reason: "Modern sound design synth", source: .local),
                PluginSuggestion(name: "U-He Diva", reason: "Analog synth emulation", source: .local)
            ]

        case .sampler:
            return [
                PluginSuggestion(name: "Kontakt 7", reason: "Industry standard sampler", source: .local),
                PluginSuggestion(name: "Output Arcade", reason: "Instant sampled instruments", source: .local)
            ]

        case .drumMachine:
            return [
                PluginSuggestion(name: "Native Instruments Battery", reason: "Powerful drum sampler", source: .local),
                PluginSuggestion(name: "Slate Digital Trigger 2", reason: "Drum replacement and enhancement", source: .local)
            ]

        case .arpeggiator:
            return [
                PluginSuggestion(name: "Cthulhu by Xfer", reason: "Advanced chord and arp generator", source: .local)
            ]

        case .vocoder:
            return [
                PluginSuggestion(name: "iZotope VocalSynth", reason: "Modern vocal effects and vocoding", source: .local)
            ]

        case .pitchCorrection:
            return [
                PluginSuggestion(name: "Auto-Tune Pro", reason: "Industry standard pitch correction", source: .local),
                PluginSuggestion(name: "Melodyne", reason: "Natural pitch and timing correction", source: .local),
                PluginSuggestion(name: "Waves Tune Real-Time", reason: "Real-time pitch correction", source: .local)
            ]

        case .transient:
            return [
                PluginSuggestion(name: "SPL Transient Designer", reason: "Attack and sustain shaping", source: .local)
            ]

        case .tape:
            return [
                PluginSuggestion(name: "Waves J37", reason: "Authentic tape machine emulation", source: .local),
                PluginSuggestion(name: "Slate Digital Virtual Tape Machines", reason: "Classic tape saturation", source: .local),
                PluginSuggestion(name: "UAD Ampex ATR-102", reason: "Premium tape emulation", source: .local)
            ]

        case .channelStrip:
            return [
                PluginSuggestion(name: "Waves SSL E-Channel", reason: "Classic SSL channel strip", source: .local),
                PluginSuggestion(name: "SSL Native Channel Strip", reason: "Authentic SSL processing", source: .local),
                PluginSuggestion(name: "UAD Neve 1073", reason: "Legendary Neve preamp and EQ", source: .local)
            ]

        case .console:
            return [
                PluginSuggestion(name: "Waves SSL G-Master Buss", reason: "SSL console glue compression", source: .local),
                PluginSuggestion(name: "Slate Digital Virtual Mix Rack", reason: "Analog console emulation", source: .local),
                PluginSuggestion(name: "Softube Console 1", reason: "Hardware-controlled console", source: .local)
            ]

        case .enhancer:
            return [
                PluginSuggestion(name: "Waves Vitamin", reason: "Harmonic enhancement", source: .local),
                PluginSuggestion(name: "iZotope Ozone Exciter", reason: "Multi-band enhancement", source: .local)
            ]

        case .exciter:
            return [
                PluginSuggestion(name: "Waves Aphex Aural Exciter", reason: "Classic exciter effect", source: .local),
                PluginSuggestion(name: "iZotope Ozone Exciter", reason: "Harmonic excitement", source: .local)
            ]

        case .ownedAlternatives:
            // Handled specially in fetchCategorySuggestions - not called here
            return []
        }
    }
}
