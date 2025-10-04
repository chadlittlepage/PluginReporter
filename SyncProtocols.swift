// SyncProtocols.swift — abstraction for pluggable sync backends (CloudKit now, Firebase later)
import Foundation
#if os(macOS) || os(iOS)
import Combine
#endif

// MARK: - Protocols

protocol PreferencesSyncing {
    func startSync(prefs: Preferences)
    func stopSync()
}

protocol ReportsSyncing {
    func saveReport(rows: [PluginItem]) async throws
    func subscribeToReports(_ handler: @escaping ([ReportSummary]) -> Void)
    func stopReportsSubscription()
}

// A tiny cross-platform summary for report lists
struct ReportSummary: Identifiable, Equatable, Hashable {
    let id: String
    let createdAt: Date
    let deviceName: String
    let counts: [String: Int] // e.g., ["AU": 705, "VST": 479, ...]
}

// MARK: - Noop implementations (default)

final class NoopPreferencesSync: PreferencesSyncing {
    func startSync(prefs: Preferences) { /* no-op */ }
    func stopSync() { /* no-op */ }
}

enum NoopError: Error { case notImplemented }

final class NoopReportsSync: ReportsSyncing {
    func saveReport(rows: [PluginItem]) async throws { throw NoopError.notImplemented }
    func subscribeToReports(_ handler: @escaping ([ReportSummary]) -> Void) { /* no-op */ }
    func stopReportsSubscription() { /* no-op */ }
}

// MARK: - Backend selection

enum SyncBackend {
    case none
    case cloudKit
    case firebase
    case both
}

struct SyncServices {
    let preferences: PreferencesSyncing
    let reports: ReportsSyncing
}

// MARK: - CloudKit Implementation

#if os(macOS) || os(iOS)
import Combine

final class CloudKitPreferencesSync: PreferencesSyncing {
    private let store = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    private weak var prefs: Preferences?

    // Keys for iCloud sync
    private enum Keys {
        static let appearance = "sync_appearance"
        static let extraScanPaths = "sync_extraScanPaths"
        static let selectedFormats = "sync_selectedFormats"
        static let selectedPublishers = "sync_selectedPublishers"
        static let pdfPage = "sync_pdfPage"
        static let pdfLandscape = "sync_pdfLandscape"
        static let pdfMargin = "sync_pdfMargin"
        static let pdfFontSize = "sync_pdfFontSize"
        static let showObsoleteOnly = "sync_showObsoleteOnly"
    }

    func startSync(prefs: Preferences) {
        self.prefs = prefs

        // Load initial values from iCloud
        loadFromCloud(prefs: prefs)

        // Listen for remote changes
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] _ in
                self?.loadFromCloud(prefs: prefs)
            }
            .store(in: &cancellables)

        // Sync local changes to cloud
        prefs.$appearance
            .dropFirst() // Skip initial value
            .sink { [weak self] value in
                self?.store.set(value.rawValue, forKey: Keys.appearance)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$extraScanPaths
            .dropFirst()
            .sink { [weak self] value in
                self?.store.set(value, forKey: Keys.extraScanPaths)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$selectedFormats
            .dropFirst()
            .sink { [weak self] value in
                let array = Array(value).map { $0.rawValue }
                self?.store.set(array, forKey: Keys.selectedFormats)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$selectedPublishers
            .dropFirst()
            .sink { [weak self] value in
                self?.store.set(Array(value), forKey: Keys.selectedPublishers)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$pdfPage
            .dropFirst()
            .sink { [weak self] value in
                self?.store.set(value.rawValue, forKey: Keys.pdfPage)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$pdfLandscape
            .dropFirst()
            .sink { [weak self] value in
                self?.store.set(value, forKey: Keys.pdfLandscape)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$pdfMargin
            .dropFirst()
            .sink { [weak self] value in
                self?.store.set(Double(value), forKey: Keys.pdfMargin)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$pdfFontSize
            .dropFirst()
            .sink { [weak self] value in
                self?.store.set(Double(value), forKey: Keys.pdfFontSize)
                self?.store.synchronize()
            }
            .store(in: &cancellables)

        prefs.$showObsoleteOnly
            .dropFirst()
            .sink { [weak self] value in
                self?.store.set(value, forKey: Keys.showObsoleteOnly)
                self?.store.synchronize()
            }
            .store(in: &cancellables)
    }

    func stopSync() {
        cancellables.removeAll()
        prefs = nil
    }

    private func loadFromCloud(prefs: Preferences) {
        // Load appearance
        if let rawValue = store.string(forKey: Keys.appearance),
           let appearance = Preferences.Appearance(rawValue: rawValue) {
            prefs.appearance = appearance
        }

        // Load extra scan paths
        if let paths = store.array(forKey: Keys.extraScanPaths) as? [String] {
            prefs.extraScanPaths = paths
        }

        // Load selected formats
        if let formatStrings = store.array(forKey: Keys.selectedFormats) as? [String] {
            prefs.selectedFormats = Set(formatStrings.compactMap { PluginFormat(rawValue: $0) })
        }

        // Load selected publishers
        if let publishers = store.array(forKey: Keys.selectedPublishers) as? [String] {
            prefs.selectedPublishers = Set(publishers)
        }

        // Load PDF settings
        if let rawValue = store.string(forKey: Keys.pdfPage),
           let page = PDFExportOptions.Page(rawValue: rawValue) {
            prefs.pdfPage = page
        }

        if store.object(forKey: Keys.pdfLandscape) != nil {
            prefs.pdfLandscape = store.bool(forKey: Keys.pdfLandscape)
        }

        if store.object(forKey: Keys.pdfMargin) != nil {
            prefs.pdfMargin = CGFloat(store.double(forKey: Keys.pdfMargin))
        }

        if store.object(forKey: Keys.pdfFontSize) != nil {
            prefs.pdfFontSize = CGFloat(store.double(forKey: Keys.pdfFontSize))
        }

        if store.object(forKey: Keys.showObsoleteOnly) != nil {
            prefs.showObsoleteOnly = store.bool(forKey: Keys.showObsoleteOnly)
        }
    }
}
#endif

func makeSyncServices(backend: SyncBackend) -> SyncServices {
    switch backend {
    case .none:
        return SyncServices(preferences: NoopPreferencesSync(), reports: NoopReportsSync())
    case .cloudKit:
        #if os(macOS) || os(iOS)
        return SyncServices(preferences: CloudKitPreferencesSync(), reports: NoopReportsSync())
        #else
        return SyncServices(preferences: NoopPreferencesSync(), reports: NoopReportsSync())
        #endif
    case .firebase:
        // Placeholder until Firebase implementations are added
        return SyncServices(preferences: NoopPreferencesSync(), reports: NoopReportsSync())
    case .both:
        // Fan-out can be added later; for now return CloudKit
        #if os(macOS) || os(iOS)
        return SyncServices(preferences: CloudKitPreferencesSync(), reports: NoopReportsSync())
        #else
        return SyncServices(preferences: NoopPreferencesSync(), reports: NoopReportsSync())
        #endif
    }
}
