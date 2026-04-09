import Foundation

public enum PluginFormat: String, CaseIterable, Codable, Identifiable, Hashable {
    case AU, VST, VST3, AAX, CLAP, LV2, OBSLT
    case unknown = "Unknown"
    public var id: String { rawValue }
}

public struct PluginItem: Identifiable, Hashable, Codable {
    public var id: UUID = UUID()
    public var name: String
    public var publisher: String
    public var version: String
    /// Human-facing plugin type string (e.g. "AU", "VST3", ...)
    public var type: String
    /// Plugin category/style (e.g. "Effect", "Instrument", "Reverb")
    public var style: String
    public var architectures: String
    /// Preset name from DAW project (only populated when viewing a playlist)
    public var preset: String
    public var date: Date?
    public var sizeBytes: Int64
    public var path: String
    public var runtimeRequirement: String
    public var obsolete: Bool
    /// Track name from DAW project (only populated when viewing a playlist)
    public var trackName: String?
    /// Whether this plugin is missing (not installed on the system)
    public var missing: Bool
    /// Thumbnail URL for instant loading (from Firebase enrichment)
    public var thumbnailUrl: String?
    /// Full-size screenshot URL (from Firebase enrichment)
    public var screenshotUrl: String?
    /// User-uploaded custom image path (local file system)
    public var customImagePath: String?
    /// AI-generated or scraped description of the plugin
    public var description: String?
    /// Primary GUI colors (e.g., "grey", "silver", "black", "blue")
    public var colorScheme: String?
    /// Searchable tags/keywords (e.g., "compressor", "vintage", "analog")
    public var tags: [String]?
    /// User-created custom tags (cached from TagsManager for performance)
    public var customTags: Set<String>
    /// Feature bullet points from manufacturer (e.g., "Low CPU hit", "Simple parametric controls")
    public var features: [String]?
    /// FULL features text from manufacturer website (complete detailed description)
    public var fullFeatures: String?
    /// Technical specifications (e.g., "stereo", "mid-side", "multiband")
    public var specs: String?
    /// Enriched presets from Firebase (for dropdown display)
    public var enrichedPresets: [EnrichedPreset]?
    /// Hardware model that the plugin emulates (from plugin_metadata heritage data)
    public var hardwareOrigin: String?
    /// Detailed hardware model information (from plugin_metadata)
    public var hardwareModel: String?
    /// Famous uses of the plugin in hit songs/productions (from plugin_famous_uses collection)
    public var famousUses: [FamousUseData]?
    /// Sonic signature description (e.g., "warm analog compression", from plugin_metadata)
    public var sonicSignature: String?
    /// Plugin chains this plugin is part of (from plugin_chains collection)
    public var chains: [ChainData]?

    public init(
        id: UUID = UUID(),
        name: String,
        publisher: String = "",
        version: String = "",
        type: String,
        style: String = "",
        architectures: String = "",
        preset: String = "",
        date: Date? = nil,
        sizeBytes: Int64 = 0,
        path: String = "",
        runtimeRequirement: String = "",
        obsolete: Bool = false,
        trackName: String? = nil,
        missing: Bool = false,
        thumbnailUrl: String? = nil,
        screenshotUrl: String? = nil,
        customImagePath: String? = nil,
        description: String? = nil,
        colorScheme: String? = nil,
        tags: [String]? = nil,
        customTags: Set<String> = [],
        features: [String]? = nil,
        fullFeatures: String? = nil,
        specs: String? = nil,
        enrichedPresets: [EnrichedPreset]? = nil,
        hardwareOrigin: String? = nil,
        hardwareModel: String? = nil,
        famousUses: [FamousUseData]? = nil,
        sonicSignature: String? = nil,
        chains: [ChainData]? = nil
    ) {
        self.id = id
        self.name = name
        self.publisher = publisher
        self.version = version
        self.type = type
        self.style = style
        self.architectures = architectures
        self.preset = preset
        self.date = date
        self.sizeBytes = sizeBytes
        self.path = path
        self.runtimeRequirement = runtimeRequirement
        self.obsolete = obsolete
        self.trackName = trackName
        self.missing = missing
        self.thumbnailUrl = thumbnailUrl
        self.screenshotUrl = screenshotUrl
        self.customImagePath = customImagePath
        self.description = description
        self.colorScheme = colorScheme
        self.tags = tags
        self.customTags = customTags
        self.features = features
        self.fullFeatures = fullFeatures
        self.specs = specs
        self.enrichedPresets = enrichedPresets
        self.hardwareOrigin = hardwareOrigin
        self.hardwareModel = hardwareModel
        self.famousUses = famousUses
        self.sonicSignature = sonicSignature
        self.chains = chains
    }

    /// Human-readable display size (e.g., "1.5 MB") - alias for sizeString
    public var displaySize: String {
        // Missing plugins have no file, so no size
        if missing && sizeBytes == 0 {
            return ""
        }
        return Humanize.bytes(sizeBytes)
    }

    /// Human-readable date string - alias for dateString
    public var displayDate: String {
        date.map(Humanize.date) ?? ""
    }

    /// Sort key for Preset column - prioritizes enriched preset count over DAW preset string
    public var presetSortKey: String {
        if let presets = enrichedPresets, !presets.isEmpty {
            // Sort by count (zero-padded to 5 digits) then by first preset name
            let countKey = String(format: "%05d", presets.count)
            let nameKey = presets.first?.name ?? ""
            return "\(countKey)_\(nameKey)"
        } else if !preset.isEmpty {
            // Fall back to DAW preset string
            return "00000_\(preset)"
        } else {
            // Empty - sort to bottom
            return "00000_"
        }
    }
}

// MARK: - Enriched Preset Model
public struct EnrichedPreset: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String?
    public var description: String?
    public var genre: String?
    public var category: String?
    public var tags: [String]?

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        genre: String? = nil,
        category: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.genre = genre
        self.category = category
        self.tags = tags
    }
}

// MARK: - Heritage Data Models

/// Famous use of a plugin in a hit song/production (from plugin_famous_uses collection)
public struct FamousUseData: Codable, Hashable, Identifiable {
    public var id: String { "\(artist)_\(song)" }
    public let artist: String
    public let song: String
    public let year: Int?
    public let album: String?
    public let engineer: String?
    public let studio: String?
    public let quote: String?
    public let chartPosition: Int?

    enum CodingKeys: String, CodingKey {
        case artist, song, year, album, engineer, studio, quote, chartPosition
    }
}

/// Plugin chain data (from plugin_chains collection)
public struct ChainData: Codable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let plugins: [String]
    public let description: String?
    public let genre: String?
    public let usageContext: String?
}
