// Preferences.swift — FULL FILE
import Combine
import Foundation
import SwiftUI

/// App preferences (simple observable model).
/// - Stores: extra scan folders, visible formats, appearance.
/// - You can later persist these with UserDefaults if you like.
final class Preferences: ObservableObject {

    // MARK: Appearance

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark, space
        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            case .space:  return .dark  // Space mode uses dark color scheme
            }
        }

        var usesTrueBlack: Bool {
            return self == .space
        }
    }

    /// UI appearance (System / Light / Dark). Used by SettingsView.
    #if os(macOS)
    @Published var appearance: Appearance = .dark
    #else
    @Published var appearance: Appearance = .system
    #endif

    // MARK: Scan Options

    /// Additional folders to include during scans.
    @Published var extraScanPaths: [String] = []

    /// Which plugin formats are visible in the table/filter.
    /// Defaults to *all* formats visible.
    @Published var selectedFormats: Set<PluginFormat> = []

    /// Which publishers are visible in the table/filter. Empty means "all".
    @Published var selectedPublishers: Set<String> = []

    /// Which plugin styles are visible in the table/filter. Empty means "all".
    @Published var selectedStyles: Set<String> = []

    /// Which star ratings are visible in the table/filter. Empty means "all".
    @Published var selectedStarRatings: Set<Int> = []

    // MARK: UI Font Size
    /// Base font size offset for the entire UI (-5 to +5 pt increments)
    /// Default is 0, which uses standard system sizes
    @Published var uiFontSizeOffset: CGFloat = 0

    // MARK: Font Size Helpers
    /// Helper to get scaled font sizes
    func scaledSize(_ baseSize: CGFloat) -> CGFloat {
        return baseSize + uiFontSizeOffset
    }

    // MARK: Table Column Visibility
    // Which columns to show in the main plugin table (all enabled by default)
    @Published var showColumnRating: Bool = true
    @Published var showColumnName: Bool = true
    @Published var showColumnPublisher: Bool = true
    @Published var showColumnVersion: Bool = true
    @Published var showColumnType: Bool = true
    @Published var showColumnStyle: Bool = true
    @Published var showColumnLicense: Bool = true
    @Published var showColumnDate: Bool = true
    @Published var showColumnSize: Bool = true
    @Published var showColumnPath: Bool = true
    @Published var showColumnRequirement: Bool = true
    @Published var showColumnObsolete: Bool = true
    @Published var showColumnMissing: Bool = true
    @Published var showColumnTrack: Bool = true
    @Published var showColumnNotes: Bool = true

    // MARK: PDF Export Options - Column Visibility
    // Which columns to include in PDF export (all enabled by default)
    @Published var pdfShowRating: Bool = true
    @Published var pdfShowName: Bool = true
    @Published var pdfShowPublisher: Bool = true
    @Published var pdfShowType: Bool = true
    @Published var pdfShowStyle: Bool = true
    @Published var pdfShowVersion: Bool = true
    @Published var pdfShowLicense: Bool = true
    @Published var pdfShowArch: Bool = true
    @Published var pdfShowDate: Bool = true
    @Published var pdfShowSize: Bool = true
    @Published var pdfShowRequirement: Bool = true
    @Published var pdfShowObsolete: Bool = true
    @Published var pdfShowMissing: Bool = true
    @Published var pdfShowTrack: Bool = true
    @Published var pdfShowNotes: Bool = true
    @Published var pdfShowPath: Bool = true

    // MARK: PDF Export Options (Page Setup settings)
    @Published var pdfPage: PDFExportOptions.Page = .letter
    @Published var pdfLandscape: Bool = true  // Default to landscape
    @Published var pdfMargin: CGFloat = 36  // Legacy: average of all margins
    @Published var pdfTopMargin: CGFloat = 36
    @Published var pdfBottomMargin: CGFloat = 36
    @Published var pdfLeftMargin: CGFloat = 36
    @Published var pdfRightMargin: CGFloat = 36
    @Published var pdfFontSize: CGFloat = 9

    /// When true, show only obsolete plugins in the table/filter.
    @Published var showObsoleteOnly: Bool = false

    /// Enable/disable cloud sync at runtime. No backend yet; wired to Noop by default.
    @Published var cloudSyncEnabled: Bool = false

    // MARK: Accessibility

    /// High contrast mode for improved visibility (accessibility feature)
    /// Increases contrast ratios, uses bolder text, and enhances visual separation
    @Published var highContrastMode: Bool = false

    // MARK: Privacy & Analytics

    /// Enable crash reporting (opt-in)
    /// Managed by CrashReportingAnalytics.shared
    var crashReportingEnabled: Bool {
        get {
            CrashReportingAnalytics.shared.isCrashReportingEnabled
        }
        set {
            CrashReportingAnalytics.shared.isCrashReportingEnabled = newValue
        }
    }

    // MARK: Column Visibility Helper

    /// Check if a specific column should be visible
    func isColumnVisible(_ column: PluginColumn) -> Bool {
        switch column {
        case .name: return showColumnName
        case .publisher: return showColumnPublisher
        case .version: return showColumnVersion
        case .type: return showColumnType
        case .style: return showColumnStyle
        case .date: return showColumnDate
        case .size: return showColumnSize
        case .path: return showColumnPath
        case .requirement: return showColumnRequirement
        case .obsolete: return showColumnObsolete
        case .missing: return showColumnMissing
        }
    }

    // MARK: Init

    init() {
        // Load Appearance
        if let appearanceRaw = UserDefaults.standard.string(forKey: "appearance"),
           let appearance = Appearance(rawValue: appearanceRaw) {
            self.appearance = appearance
        }

        // Load Scan Options
        self.extraScanPaths = UserDefaults.standard.stringArray(forKey: "extraScanPaths") ?? []

        if let formatsData = UserDefaults.standard.data(forKey: "selectedFormats"),
           let formats = try? JSONDecoder().decode(Set<PluginFormat>.self, from: formatsData) {
            self.selectedFormats = formats
        }

        if let publishersData = UserDefaults.standard.data(forKey: "selectedPublishers"),
           let publishers = try? JSONDecoder().decode(Set<String>.self, from: publishersData) {
            self.selectedPublishers = publishers
        }

        if let stylesData = UserDefaults.standard.data(forKey: "selectedStyles"),
           let styles = try? JSONDecoder().decode(Set<String>.self, from: stylesData) {
            self.selectedStyles = styles
        }

        if let ratingsData = UserDefaults.standard.data(forKey: "selectedStarRatings"),
           let ratings = try? JSONDecoder().decode(Set<Int>.self, from: ratingsData) {
            self.selectedStarRatings = ratings
        }

        // Load UI Font Size
        let savedFontOffset = UserDefaults.standard.double(forKey: "uiFontSizeOffset")
        if UserDefaults.standard.object(forKey: "uiFontSizeOffset") != nil {
            self.uiFontSizeOffset = CGFloat(savedFontOffset)
        }

        // Load Table Column Visibility
        self.showColumnRating = UserDefaults.standard.object(forKey: "showColumnRating") as? Bool ?? true
        self.showColumnName = UserDefaults.standard.object(forKey: "showColumnName") as? Bool ?? true
        self.showColumnPublisher = UserDefaults.standard.object(forKey: "showColumnPublisher") as? Bool ?? true
        self.showColumnVersion = UserDefaults.standard.object(forKey: "showColumnVersion") as? Bool ?? true
        self.showColumnType = UserDefaults.standard.object(forKey: "showColumnType") as? Bool ?? true
        self.showColumnStyle = UserDefaults.standard.object(forKey: "showColumnStyle") as? Bool ?? true
        self.showColumnLicense = UserDefaults.standard.object(forKey: "showColumnLicense") as? Bool ?? true
        self.showColumnDate = UserDefaults.standard.object(forKey: "showColumnDate") as? Bool ?? true
        self.showColumnSize = UserDefaults.standard.object(forKey: "showColumnSize") as? Bool ?? true
        self.showColumnPath = UserDefaults.standard.object(forKey: "showColumnPath") as? Bool ?? true
        self.showColumnRequirement = UserDefaults.standard.object(forKey: "showColumnRequirement") as? Bool ?? true
        self.showColumnObsolete = UserDefaults.standard.object(forKey: "showColumnObsolete") as? Bool ?? true
        self.showColumnMissing = UserDefaults.standard.object(forKey: "showColumnMissing") as? Bool ?? true
        self.showColumnTrack = UserDefaults.standard.object(forKey: "showColumnTrack") as? Bool ?? true
        self.showColumnNotes = UserDefaults.standard.object(forKey: "showColumnNotes") as? Bool ?? true

        // Load PDF Column Visibility
        self.pdfShowRating = UserDefaults.standard.object(forKey: "pdfShowRating") as? Bool ?? true
        self.pdfShowName = UserDefaults.standard.object(forKey: "pdfShowName") as? Bool ?? true
        self.pdfShowPublisher = UserDefaults.standard.object(forKey: "pdfShowPublisher") as? Bool ?? true
        self.pdfShowType = UserDefaults.standard.object(forKey: "pdfShowType") as? Bool ?? true
        self.pdfShowStyle = UserDefaults.standard.object(forKey: "pdfShowStyle") as? Bool ?? true
        self.pdfShowVersion = UserDefaults.standard.object(forKey: "pdfShowVersion") as? Bool ?? true
        self.pdfShowLicense = UserDefaults.standard.object(forKey: "pdfShowLicense") as? Bool ?? true
        self.pdfShowArch = UserDefaults.standard.object(forKey: "pdfShowArch") as? Bool ?? true
        self.pdfShowDate = UserDefaults.standard.object(forKey: "pdfShowDate") as? Bool ?? true
        self.pdfShowSize = UserDefaults.standard.object(forKey: "pdfShowSize") as? Bool ?? true
        self.pdfShowRequirement = UserDefaults.standard.object(forKey: "pdfShowRequirement") as? Bool ?? true
        self.pdfShowObsolete = UserDefaults.standard.object(forKey: "pdfShowObsolete") as? Bool ?? true
        self.pdfShowMissing = UserDefaults.standard.object(forKey: "pdfShowMissing") as? Bool ?? true
        self.pdfShowTrack = UserDefaults.standard.object(forKey: "pdfShowTrack") as? Bool ?? true
        self.pdfShowNotes = UserDefaults.standard.object(forKey: "pdfShowNotes") as? Bool ?? true
        self.pdfShowPath = UserDefaults.standard.object(forKey: "pdfShowPath") as? Bool ?? true

        // Load PDF Export Options (Page Setup)
        if let pageRaw = UserDefaults.standard.string(forKey: "pdfPage"),
           let page = PDFExportOptions.Page(rawValue: pageRaw) {
            self.pdfPage = page
        }
        self.pdfLandscape = UserDefaults.standard.object(forKey: "pdfLandscape") as? Bool ?? true
        self.pdfMargin = CGFloat(UserDefaults.standard.double(forKey: "pdfMargin"))
        if self.pdfMargin == 0 { self.pdfMargin = 36 }

        self.pdfTopMargin = CGFloat(UserDefaults.standard.double(forKey: "pdfTopMargin"))
        if self.pdfTopMargin == 0 { self.pdfTopMargin = 36 }

        self.pdfBottomMargin = CGFloat(UserDefaults.standard.double(forKey: "pdfBottomMargin"))
        if self.pdfBottomMargin == 0 { self.pdfBottomMargin = 36 }

        self.pdfLeftMargin = CGFloat(UserDefaults.standard.double(forKey: "pdfLeftMargin"))
        if self.pdfLeftMargin == 0 { self.pdfLeftMargin = 36 }

        self.pdfRightMargin = CGFloat(UserDefaults.standard.double(forKey: "pdfRightMargin"))
        if self.pdfRightMargin == 0 { self.pdfRightMargin = 36 }

        self.pdfFontSize = CGFloat(UserDefaults.standard.double(forKey: "pdfFontSize"))
        if self.pdfFontSize == 0 { self.pdfFontSize = 9 }

        // Load Filter Options
        self.showObsoleteOnly = UserDefaults.standard.bool(forKey: "showObsoleteOnly")

        // Load Cloud Sync
        self.cloudSyncEnabled = UserDefaults.standard.bool(forKey: "cloudSyncEnabled")

        // Load Accessibility
        self.highContrastMode = UserDefaults.standard.bool(forKey: "highContrastMode")

        // Setup save on change
        setupUserDefaultsSync()
    }

    private func setupUserDefaultsSync() {
        // Appearance
        $appearance.sink { UserDefaults.standard.set($0.rawValue, forKey: "appearance") }.store(in: &cancellables)

        // Scan Options
        $extraScanPaths.sink { UserDefaults.standard.set($0, forKey: "extraScanPaths") }.store(in: &cancellables)

        $selectedFormats.sink { formats in
            if let data = try? JSONEncoder().encode(formats) {
                UserDefaults.standard.set(data, forKey: "selectedFormats")
            }
        }.store(in: &cancellables)

        $selectedPublishers.sink { publishers in
            if let data = try? JSONEncoder().encode(publishers) {
                UserDefaults.standard.set(data, forKey: "selectedPublishers")
            }
        }.store(in: &cancellables)

        $selectedStyles.sink { styles in
            if let data = try? JSONEncoder().encode(styles) {
                UserDefaults.standard.set(data, forKey: "selectedStyles")
            }
        }.store(in: &cancellables)

        $selectedStarRatings.sink { ratings in
            if let data = try? JSONEncoder().encode(ratings) {
                UserDefaults.standard.set(data, forKey: "selectedStarRatings")
            }
        }.store(in: &cancellables)

        // UI Font Size
        $uiFontSizeOffset.sink { UserDefaults.standard.set(Double($0), forKey: "uiFontSizeOffset") }.store(in: &cancellables)

        // Table Column Visibility
        $showColumnRating.sink { UserDefaults.standard.set($0, forKey: "showColumnRating") }.store(in: &cancellables)
        $showColumnName.sink { UserDefaults.standard.set($0, forKey: "showColumnName") }.store(in: &cancellables)
        $showColumnPublisher.sink { UserDefaults.standard.set($0, forKey: "showColumnPublisher") }.store(in: &cancellables)
        $showColumnVersion.sink { UserDefaults.standard.set($0, forKey: "showColumnVersion") }.store(in: &cancellables)
        $showColumnType.sink { UserDefaults.standard.set($0, forKey: "showColumnType") }.store(in: &cancellables)
        $showColumnStyle.sink { UserDefaults.standard.set($0, forKey: "showColumnStyle") }.store(in: &cancellables)
        $showColumnLicense.sink { UserDefaults.standard.set($0, forKey: "showColumnLicense") }.store(in: &cancellables)
        $showColumnDate.sink { UserDefaults.standard.set($0, forKey: "showColumnDate") }.store(in: &cancellables)
        $showColumnSize.sink { UserDefaults.standard.set($0, forKey: "showColumnSize") }.store(in: &cancellables)
        $showColumnPath.sink { UserDefaults.standard.set($0, forKey: "showColumnPath") }.store(in: &cancellables)
        $showColumnRequirement.sink { UserDefaults.standard.set($0, forKey: "showColumnRequirement") }.store(in: &cancellables)
        $showColumnObsolete.sink { UserDefaults.standard.set($0, forKey: "showColumnObsolete") }.store(in: &cancellables)
        $showColumnMissing.sink { UserDefaults.standard.set($0, forKey: "showColumnMissing") }.store(in: &cancellables)
        $showColumnTrack.sink { UserDefaults.standard.set($0, forKey: "showColumnTrack") }.store(in: &cancellables)
        $showColumnNotes.sink { UserDefaults.standard.set($0, forKey: "showColumnNotes") }.store(in: &cancellables)

        // PDF Column Visibility
        $pdfShowRating.sink { UserDefaults.standard.set($0, forKey: "pdfShowRating") }.store(in: &cancellables)
        $pdfShowName.sink { UserDefaults.standard.set($0, forKey: "pdfShowName") }.store(in: &cancellables)
        $pdfShowPublisher.sink { UserDefaults.standard.set($0, forKey: "pdfShowPublisher") }.store(in: &cancellables)
        $pdfShowType.sink { UserDefaults.standard.set($0, forKey: "pdfShowType") }.store(in: &cancellables)
        $pdfShowStyle.sink { UserDefaults.standard.set($0, forKey: "pdfShowStyle") }.store(in: &cancellables)
        $pdfShowVersion.sink { UserDefaults.standard.set($0, forKey: "pdfShowVersion") }.store(in: &cancellables)
        $pdfShowLicense.sink { UserDefaults.standard.set($0, forKey: "pdfShowLicense") }.store(in: &cancellables)
        $pdfShowArch.sink { UserDefaults.standard.set($0, forKey: "pdfShowArch") }.store(in: &cancellables)
        $pdfShowDate.sink { UserDefaults.standard.set($0, forKey: "pdfShowDate") }.store(in: &cancellables)
        $pdfShowSize.sink { UserDefaults.standard.set($0, forKey: "pdfShowSize") }.store(in: &cancellables)
        $pdfShowRequirement.sink { UserDefaults.standard.set($0, forKey: "pdfShowRequirement") }.store(in: &cancellables)
        $pdfShowObsolete.sink { UserDefaults.standard.set($0, forKey: "pdfShowObsolete") }.store(in: &cancellables)
        $pdfShowMissing.sink { UserDefaults.standard.set($0, forKey: "pdfShowMissing") }.store(in: &cancellables)
        $pdfShowTrack.sink { UserDefaults.standard.set($0, forKey: "pdfShowTrack") }.store(in: &cancellables)
        $pdfShowNotes.sink { UserDefaults.standard.set($0, forKey: "pdfShowNotes") }.store(in: &cancellables)
        $pdfShowPath.sink { UserDefaults.standard.set($0, forKey: "pdfShowPath") }.store(in: &cancellables)

        // PDF Export Options (Page Setup)
        $pdfPage.sink { UserDefaults.standard.set($0.rawValue, forKey: "pdfPage") }.store(in: &cancellables)
        $pdfLandscape.sink { UserDefaults.standard.set($0, forKey: "pdfLandscape") }.store(in: &cancellables)
        $pdfMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfMargin") }.store(in: &cancellables)
        $pdfTopMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfTopMargin") }.store(in: &cancellables)
        $pdfBottomMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfBottomMargin") }.store(in: &cancellables)
        $pdfLeftMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfLeftMargin") }.store(in: &cancellables)
        $pdfRightMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfRightMargin") }.store(in: &cancellables)
        $pdfFontSize.sink { UserDefaults.standard.set(Double($0), forKey: "pdfFontSize") }.store(in: &cancellables)

        // Filter Options
        $showObsoleteOnly.sink { UserDefaults.standard.set($0, forKey: "showObsoleteOnly") }.store(in: &cancellables)

        // Cloud Sync
        $cloudSyncEnabled.sink { UserDefaults.standard.set($0, forKey: "cloudSyncEnabled") }.store(in: &cancellables)

        // Accessibility
        $highContrastMode.sink { UserDefaults.standard.set($0, forKey: "highContrastMode") }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}
