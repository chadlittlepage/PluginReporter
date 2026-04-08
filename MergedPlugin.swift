// MergedPlugin.swift - Combined CloudKit + Firestore Data
// Add this file to BOTH macOS and iOS targets
import Foundation

/// MergedPlugin combines user's personal plugin data (CloudKit)
/// with shared enrichment data (Firestore)
struct MergedPlugin: Identifiable, Hashable {
    var id: UUID

    // MARK: - From CloudKit (User's Personal Data)
    var isInstalled: Bool
    var installedDate: Date?
    var lastScannedDate: Date?
    var installedOnDevice: String?
    var localPath: String?
    var localVersion: String?
    var localType: String?
    var isActive: Bool

    // MARK: - From Firestore (Shared Enrichment)
    var enrichment: EnrichedPlugin?

    // MARK: - Computed Properties

    /// Display name (prefer enrichment display name, fallback to name)
    var displayName: String {
        enrichment?.displayName ?? enrichment?.name ?? "Unknown Plugin"
    }

    /// Plugin name
    var name: String {
        enrichment?.name ?? "Unknown"
    }

    /// Publisher/Vendor name
    var publisher: String {
        enrichment?.publisher ?? "Unknown"
    }

    /// Description
    var description: String? {
        enrichment?.description
    }

    /// Category
    var category: String? {
        enrichment?.category
    }

    /// Is this plugin truly enriched (has meaningful data)?
    var isEnriched: Bool {
        enrichment?.isEnriched ?? false
    }

    /// Has any enrichment data at all?
    var hasAnyEnrichment: Bool {
        enrichment != nil
    }

    /// Screenshot URL
    var screenshotUrl: String? {
        enrichment?.screenshotUrl ?? enrichment?.screenshot?.screenshotUrl
    }

    /// Has screenshot?
    var hasScreenshot: Bool {
        screenshotUrl != nil || enrichment?.hasScreenshot == true
    }

    /// Manufacturer URL
    var url: String? {
        enrichment?.url ?? enrichment?.manufacturerUrl
    }

    /// Sonic signature
    var sonicSignature: String? {
        enrichment?.sonicSignature ?? enrichment?.soundCharacter
    }

    /// CPU usage percentage
    var cpuUsage: Int? {
        enrichment?.cpuUsage
    }

    /// DSP usage percentage
    var dspUsage: Int? {
        enrichment?.dspUsage
    }

    /// Famous uses count
    var famousUsesCount: Int {
        enrichment?.famousUses?.count ?? 0
    }

    /// Presets count
    var presetsCount: Int {
        enrichment?.presets?.count ?? 0
    }

    /// Chains count
    var chainsCount: Int {
        enrichment?.chains?.count ?? 0
    }

    /// Hit songs count (#1 chart positions)
    var hitSongsCount: Int? {
        enrichment?.hitSongsCount
    }

    /// User ownership status
    var owned: Bool? {
        enrichment?.owned
    }

    /// Composite key for matching
    var compositeKey: String {
        "\(name)_\(publisher)".lowercased()
    }

    /// Device display name
    var deviceDisplayName: String {
        guard let device = installedOnDevice else {
            return "Unknown Device"
        }

        // Clean up device name
        return device
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }

    /// Installation status text
    var installationStatusText: String {
        if isInstalled {
            if installedOnDevice != nil {
                return "Installed on \(deviceDisplayName)"
            } else {
                return "Installed"
            }
        } else {
            return "Not Installed"
        }
    }

    /// Format installation date nicely
    var formattedInstallDate: String? {
        guard let date = installedDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Hashable Conformance
    static func == (lhs: MergedPlugin, rhs: MergedPlugin) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Convenience Initializers

extension MergedPlugin {
    /// Create from CloudKit PluginItem only (no enrichment)
    init(from pluginItem: PluginItem) {
        self.id = pluginItem.id
        self.isInstalled = true
        self.installedDate = pluginItem.date
        self.lastScannedDate = pluginItem.date
        self.installedOnDevice = nil  // PluginItem doesn't have device info yet
        self.localPath = pluginItem.path
        self.localVersion = pluginItem.version
        self.localType = pluginItem.type
        self.isActive = !pluginItem.obsolete
        self.enrichment = nil
    }

    /// Create from Firestore EnrichedPlugin only (not installed)
    init(from enrichedPlugin: EnrichedPlugin) {
        self.id = UUID()
        self.isInstalled = false
        self.installedDate = nil
        self.lastScannedDate = nil
        self.installedOnDevice = nil
        self.localPath = nil
        self.localVersion = nil
        self.localType = nil
        self.isActive = false
        self.enrichment = enrichedPlugin
    }

    /// Create from both sources (merged)
    init(pluginItem: PluginItem, enrichment: EnrichedPlugin?) {
        self.id = pluginItem.id
        self.isInstalled = true
        self.installedDate = pluginItem.date
        self.lastScannedDate = pluginItem.date
        self.installedOnDevice = nil  // Will add device tracking later
        self.localPath = pluginItem.path
        self.localVersion = pluginItem.version
        self.localType = pluginItem.type
        self.isActive = !pluginItem.obsolete
        self.enrichment = enrichment
    }
}

// MARK: - Display Helpers

extension MergedPlugin {
    /// Get formatted version string
    var versionDisplay: String {
        localVersion ?? enrichment?.specifications?["version"] ?? "Unknown"
    }

    /// Get formatted type string
    var typeDisplay: String {
        localType ?? "Unknown"
    }

    /// Get enrichment status badge text
    var enrichmentBadge: String {
        if !hasAnyEnrichment {
            return "Not Enriched"
        } else if isEnriched {
            return "Fully Enriched"
        } else {
            return "Partially Enriched"
        }
    }

    /// Get enrichment status color
    var enrichmentBadgeColor: String {
        if !hasAnyEnrichment {
            return "gray"
        } else if isEnriched {
            return "green"
        } else {
            return "orange"
        }
    }

    /// Get installation badge color
    var installationBadgeColor: String {
        isInstalled ? "blue" : "gray"
    }
}
