import Foundation

public enum PluginFormat: String, CaseIterable, Codable, Identifiable {
    case AU, VST, VST3, AAX, CLAP, LV2
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
    public var date: Date?
    public var sizeBytes: Int64
    public var path: String
    public var runtimeRequirement: String
    public var obsolete: Bool

    public init(
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

    /// Human-readable display size (e.g., "1.5 MB") - alias for sizeString
    public var displaySize: String {
        Humanize.bytes(sizeBytes)
    }

    /// Human-readable date string - alias for dateString
    public var displayDate: String {
        date.map(Humanize.date) ?? ""
    }
}
