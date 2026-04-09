// AISuggestionsView.swift — iOS version of AI plugin suggestions
import Combine
import Security
import SwiftUI

// Note: SuggestionCategory is now defined in AIPluginSuggestions.swift (shared across platforms)

struct AISuggestionsView: View {
    let plugin: PluginItem
    let ownedPlugins: [PluginItem]
    @StateObject private var aiService = AIPluginSuggestions()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: SuggestionCategory?

    var body: some View {
        VStack(spacing: 0) {
            // Category Cloud - Two Rows
            VStack(spacing: 0) {
                // Row 1: Workflow & Genre Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SuggestionCategory.workflowCategories) { category in
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                Divider()

                // Row 2: Plugin Type Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SuggestionCategory.pluginTypeCategories) { category in
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .background(Color(UIColor.systemGray6))

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
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(aiService.suggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion, ownedPlugins: ownedPlugins)
                        }

                        // Footer inline with content
                        if !aiService.isLoading && !aiService.suggestions.isEmpty {
                            HStack(spacing: 5) {
                                Image(systemName: aiService.suggestions.first?.source == .openAI ? "sparkles" : "cpu")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(aiService.suggestions.first?.source == .openAI ? "Powered by OpenAI" : "Local AI")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
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
    let ownedPlugins: [PluginItem]
    @State private var showHeritageDetail = false

    // Find the actual plugin to get its types
    private var matchedPlugin: PluginItem? {
        ownedPlugins.first { $0.name.lowercased() == suggestion.name.lowercased() }
    }

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
        VStack(spacing: 0) {
            Button {
                // If heritage data exists, show detail sheet; otherwise open URL
                if suggestion.heritage != nil {
                    showHeritageDetail = true
                } else {
                    UIApplication.shared.open(pluginURL)
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    // Icon - show star if heritage exists
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: suggestion.heritage != nil ? "star.fill" : "waveform")
                            .font(.callout)
                            .foregroundColor(suggestion.heritage != nil ? .orange : .accentColor)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(suggestion.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            // Show info icon if heritage exists
                            if suggestion.heritage != nil {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }

                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor)
                        }

                        Text(suggestion.reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        // Show heritage teaser if available
                        if let heritage = suggestion.heritage, !heritage.famousUses.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text("Used on \(heritage.famousUses.count) hit song\(heritage.famousUses.count > 1 ? "s" : "")")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        }

                        // Type badges - show actual formats from database or owned plugins
                        TypeBadges(plugin: matchedPlugin, suggestionName: suggestion.name)
                            .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            suggestion.heritage != nil ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: suggestion.heritage != nil ? 1 : 0.5
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showHeritageDetail) {
            if let heritage = suggestion.heritage {
                HeritageDetailView(heritage: heritage, pluginName: suggestion.name)
            }
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
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        Capsule().fill(Color.accentColor)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Type Badges

private struct TypeBadges: View {
    let plugin: PluginItem?
    let suggestionName: String

    private var formats: [String] {
        if let plugin = plugin {
            // Show actual formats from owned plugin, sorted by canonical order
            return PluginFormat.allCases
                .filter { format in plugin.type.localizedCaseInsensitiveContains(format.rawValue) }
                .map { $0.rawValue }
                .sorted { ColorUtilities.formatSortOrder($0) < ColorUtilities.formatSortOrder($1) }
        } else {
            // Look up actual formats from database, sorted by canonical order
            return PluginFormatDatabase.formatsFor(suggestionName)
                .sorted { ColorUtilities.formatSortOrder($0) < ColorUtilities.formatSortOrder($1) }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(formats, id: \.self) { format in
                let color = ColorUtilities.colorForFormat(format)
                let isOwned = plugin != nil
                Text(format)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isOwned ? color : color.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color.opacity(isOwned ? 0.2 : 0.15))
                            .overlay(
                                isOwned ? nil : RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(color.opacity(0.3), lineWidth: 1, antialiased: true)
                            )
                    )
            }
        }
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
            Label("AI Suggestions", systemImage: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showingSuggestions) {
            NavigationStack {
                AISuggestionsView(plugin: plugin, ownedPlugins: ownedPlugins)
            }
            .frame(
                width: min(520, UIScreen.main.bounds.width * 0.95),
                height: min(780, UIScreen.main.bounds.height * 0.85)
            )
            .presentationCompactAdaptation(.popover)
        }
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

// MARK: - Heritage Detail View (Main Sheet)

struct HeritageDetailView: View {
    let heritage: PluginHeritage
    let pluginName: String
    @Environment(\.dismiss) var dismiss

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
                        if let hardware = heritage.modelsHardware {
                            HardwareModelCard(hardware: hardware)
                        }

                        // Sonic Signature
                        SonicSignatureCard(signature: heritage.sonicSignature)
                    }
                    .padding(.horizontal)

                    // Famous Uses
                    if !heritage.famousUses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.orange)
                                Text("Used On These Hit Songs")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            ForEach(heritage.famousUses) { use in
                                FamousUseCard(use: use)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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

            Text(hardware.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Label(String(hardware.yearReleased), systemImage: "calendar")
                Label(hardware.priceRange, systemImage: "dollarsign.circle")
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
                    Text(use.context.displayName)
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

                    HeritageFlowLayoutiOS(spacing: 4) {
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
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var contextIcon: String {
        switch use.context {
        case .tracking: return "mic.fill"
        case .mixing: return "slider.horizontal.3"
        case .mastering: return "waveform.badge.magnifyingglass"
        case .creative: return "sparkles"
        }
    }

    private var contextColor: Color {
        switch use.context {
        case .tracking: return .red
        case .mixing: return .blue
        case .mastering: return .purple
        case .creative: return .orange
        }
    }
}

// MARK: - Flow Layout (for wrapping tags)

private struct HeritageFlowLayoutiOS: Layout {
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
