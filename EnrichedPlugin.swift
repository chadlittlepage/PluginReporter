// EnrichedPlugin.swift - Firestore Enrichment Data Model
// Add this file to BOTH macOS and iOS targets
import Foundation
import FirebaseFirestore

// MARK: - Main Enriched Plugin Model
struct EnrichedPlugin: Identifiable, Codable {
    var id: String  // Firestore document ID

    // Basic fields (from plugin_metadata)
    var name: String
    var publisher: String
    var displayName: String?
    var description: String?
    var category: String?
    var url: String?
    var manufacturerUrl: String?

    // Enrichment metadata
    var enrichmentStatus: String?
    var enrichmentMethod: String?
    var enrichedAt: Timestamp?
    var updatedAt: Timestamp?

    // Heritage fields
    var sonicSignature: String?
    var soundCharacter: String?
    var hitSongsCount: Int?
    var owned: Bool?

    // Resource usage
    var cpuUsage: Int?
    var dspUsage: Int?
    var resourceUsage: String?

    // Capabilities
    var capabilities: PluginCapabilities?
    var capabilityType: String?
    var capabilitySubType: String?
    var processingType: String?

    // Features and keywords
    var features: [String]?
    var keywords: [String]?
    var searchTags: [String]?

    // Visual
    var screenshot: PluginScreenshot?
    var screenshotUrl: String?
    var screenshotPath: String?
    var hasScreenshot: Bool?

    // Specifications
    var bitDepth: String?
    var channels: String?
    var hasSpecifications: Bool?
    var specifications: [String: String]?

    // Pricing
    var price: String?
    var priceRange: String?
    var trialAvailable: Bool?

    // System Requirements
    var systemRequirements: SystemRequirements?

    // Formats
    var formats: [String]?

    // Hardware DSP
    var hardwareDSP: HardwareDSPInfo?
    var dspInfo: DSPInfo?
    var dspChips: [FirestoreDSPChip]?

    // Hardware equivalent
    var hardwareEquivalent: String?

    // Relations (loaded separately for performance)
    var presets: [FirestorePreset]?
    var chains: [FirestorePluginChain]?
    var famousUses: [FirestoreFamousUse]?

    // Computed properties
    var compositeKey: String {
        "\(name)_\(publisher)".lowercased()
    }

    var isEnriched: Bool {
        // Use same validation as dashboard
        let hasDescription = (description?.count ?? 0) > 50
        let hasRealCategory = category != nil && category != "Other"
        let hasUrl = url != nil && !(url?.isEmpty ?? true)
        let hasScreenshotData = screenshot != nil || screenshotUrl != nil || screenshotPath != nil

        let hasRealCapabilities = capabilities != nil &&
                                  capabilityType != nil &&
                                  capabilityType != "Unknown"

        let hasFeatures = (features?.count ?? 0) > 0
        let hasKeywords = (keywords?.count ?? 0) > 0
        let hasFamousUsesData = (famousUses?.count ?? 0) > 0
        let hasPresetsData = (presets?.count ?? 0) > 0
        let hasSpecs = bitDepth != nil || channels != nil || hasSpecifications == true

        let substantiveCount = [hasDescription, hasRealCategory, hasUrl, hasScreenshotData]
            .filter { $0 }.count

        let enrichedDataCount = [hasFeatures, hasKeywords, hasFamousUsesData, hasPresetsData, hasSpecs]
            .filter { $0 }.count

        return substantiveCount >= 2 && (hasRealCapabilities || enrichedDataCount >= 2)
    }
}

// MARK: - Supporting Models

struct PluginCapabilities: Codable {
    var type: String?
    var subType: String?
    var processingType: String?
    var features: [String]?
    var keywords: [String]?
    var searchTags: [String]?
    var specifications: [String: String]?
}

struct PluginScreenshot: Codable {
    var screenshotUrl: String?
    var thumbnailUrl: String?
    var source: String?
    var uploadMethod: String?
    var visualDescription: String?
    var primaryColor: String?
    var secondaryColor: String?
    var colorTags: [String]?
    var colors: ColorAnalysis?
}

struct ColorAnalysis: Codable {
    var primary: String?
    var secondary: String?
    var dominant: [String]?
    var tags: [String]?
}

struct SystemRequirements: Codable {
    var mac: String?
    var windows: String?
    var processor: String?
    var supportedDAWs: [String]?
}

struct HardwareDSPInfo: Codable {
    var description: String?
}

struct DSPInfo: Codable {
    var systemCount: Int?
    var chipCount: Int?
}

struct FirestoreDSPChip: Codable {
    var name: String?
    var active: Bool?
    var allocation: Int?
}

// MARK: - Preset Model (Firestore)
struct FirestorePreset: Identifiable, Codable {
    var id: String?
    var pluginName: String
    var publisher: String
    var name: String?
    var description: String?
    var genre: String?
    var useCase: String?
    var tags: [String]?
    var author: String?
    var adaptedFrom: String?
    var pluginChain: [FirestorePresetPlugin]?
    var cpuUsage: Int?
    var dspUsage: Int?
    var lastUsed: Timestamp?
    var isInstalled: Bool?
}

struct FirestorePresetPlugin: Codable {
    var pluginName: String
    var publisher: String
    var position: Int
}

// MARK: - Plugin Chain Model (Firestore)
struct FirestorePluginChain: Identifiable, Codable {
    var id: String?
    var name: String
    var instrument: String?
    var context: String?
    var engineer: String?
    var plugins: [FirestoreChainPlugin]?
    var positionInChain: Int?
    var famousUses: [FirestoreChainFamousUse]?

    // Heritage fields
    var complexity: String?  // "Light", "Medium", "Heavy"
    var confidence: Int?     // 0-100
    var rating: Double?      // 0-5
    var cpuPercent: Int?
    var hasWarning: Bool?
}

struct FirestoreChainPlugin: Codable {
    var pluginName: String?
    var name: String?
    var publisher: String?
    var position: Int?
    var hasWarning: Bool?
    var warningType: String?
}

struct FirestoreChainFamousUse: Codable {
    var song: String?
    var production: String?
    var artist: String?
}

// MARK: - Famous Use Model (Firestore)
struct FirestoreFamousUse: Identifiable, Codable {
    var id: String?
    var pluginName: String
    var publisher: String
    var artist: String?
    var track: String?
    var album: String?
    var year: Int?
    var engineer: String?
    var role: String?
    var notes: String?

    // Heritage fields
    var chartPosition: Int?
    var chartType: String?
    var certified: String?
    var studio: String?
    var usedOn: [String]?  // Instruments
}

// MARK: - Firestore Coding Keys
extension EnrichedPlugin {
    enum CodingKeys: String, CodingKey {
        case id
        case name, publisher, displayName, description, category, url, manufacturerUrl
        case enrichmentStatus, enrichmentMethod, enrichedAt, updatedAt
        case sonicSignature, soundCharacter, hitSongsCount, owned
        case cpuUsage, dspUsage, resourceUsage
        case capabilities, capabilityType, capabilitySubType, processingType
        case features, keywords, searchTags
        case screenshot, screenshotUrl, screenshotPath, hasScreenshot
        case bitDepth, channels, hasSpecifications, specifications
        case price, priceRange, trialAvailable
        case systemRequirements, formats
        case hardwareDSP, dspInfo, dspChips
        case hardwareEquivalent
        case presets, chains, famousUses
    }
}
