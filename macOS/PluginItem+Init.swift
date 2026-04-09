// PluginItem+Init.swift — convenience init from ScannerPluginItem
import Foundation

extension PluginItem {
    init(_ scannerItem: ScannerPluginItem) {
        let archLower = scannerItem.architectures.lowercased()
        let requirementLower = scannerItem.runtimeRequirement.lowercased()
        let typeUpper = scannerItem.type.uppercased()
        let derivedObsolete =
            scannerItem.obsolete ||
            typeUpper == "OBSLT" ||
            requirementLower.contains("rosetta") ||
            (requirementLower.contains("intel") && !requirementLower.contains("apple")) ||
            (archLower.contains("intel") && !archLower.contains("apple"))

        self.init(
            id: scannerItem.id,
            name: scannerItem.name,
            publisher: scannerItem.publisher,
            version: scannerItem.version,
            type: scannerItem.type,
            style: scannerItem.style,
            architectures: scannerItem.architectures,
            date: scannerItem.date,
            sizeBytes: scannerItem.sizeBytes,
            path: scannerItem.path,
            runtimeRequirement: scannerItem.runtimeRequirement,
            obsolete: derivedObsolete,
            trackName: nil,
            missing: false
        )

        // CRITICAL: Copy enrichment data from scanner item
        // Without this, enrichment data gets lost when converting ScannerPluginItem -> PluginItem
        self.thumbnailUrl = scannerItem.thumbnailUrl
        self.screenshotUrl = scannerItem.screenshotUrl
        self.description = scannerItem.description
        self.colorScheme = scannerItem.colorScheme
        self.tags = scannerItem.tags
        self.features = scannerItem.features
        self.fullFeatures = scannerItem.fullFeatures
        self.specs = scannerItem.specs
        self.enrichedPresets = scannerItem.enrichedPresets

        // Load custom tags from TagsManager (cached for filtering performance)
        self.customTags = TagsManager.shared.getTags(for: scannerItem.path)
    }
}
