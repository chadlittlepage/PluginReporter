import Foundation

/// Heritage data for a plugin (hardware lineage, famous uses, etc.)
/// Recovered stub — the original was lost (never committed).
struct PluginHeritage: Codable {
    var hardwareModels: [HardwareModel]?
    var modelsHardware: [HardwareModel]?
    var famousUses: [FamousUse]?
    var history: String?
    var originalHardware: String?
    var isAIGenerated: Bool = false
    var sonicSignature: String?
}

struct HardwareModel: Codable, Identifiable {
    var id: String { name }
    var name: String
    var manufacturer: String?
    var yearIntroduced: String?
    var yearReleased: String?
    var description: String?
    var imageUrl: String?
    var priceRange: String?
    var unitsSold: String?
}

struct FamousUse: Codable, Identifiable {
    var id: String { "\(artist)-\(songTitle ?? song ?? album ?? "")" }
    var artist: String
    var song: String?
    var songTitle: String?
    var album: String?
    var year: String?
    var description: String?
    var engineer: String?
    var usedOn: [String] = []
    var context: UsageContext?
    var chartPosition: String?
    var studio: String?
    var quote: String?
}

enum UsageContext: String, Codable {
    case mixing, mastering, recording, production, liveSound, soundDesign, tracking, creative

    var displayName: String {
        switch self {
        case .mixing: return "Mixing"
        case .mastering: return "Mastering"
        case .recording: return "Recording"
        case .production: return "Production"
        case .liveSound: return "Live Sound"
        case .soundDesign: return "Sound Design"
        case .tracking: return "Tracking"
        case .creative: return "Creative"
        }
    }
}

/// Database for plugin heritage lookups.
enum PluginHeritageDatabase {
    private static var cache: [String: PluginHeritage] = [:]

    static func getHeritage(for pluginName: String) -> PluginHeritage? {
        cache[pluginName]
    }

    static func getHeritageWithAI(for pluginName: String, apiKey: String? = nil, publisher: String? = nil) async -> PluginHeritage? {
        // Placeholder — wire up Firestore or AI provider for real heritage lookups
        nil
    }
}
