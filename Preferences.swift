// Preferences.swift — FULL FILE
import Foundation
import SwiftUI
import Combine

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

    // MARK: Init

    init() {
        // Load from UserDefaults
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

        // Setup save on change
        setupUserDefaultsSync()
    }

    private func setupUserDefaultsSync() {
        $pdfPage.sink { UserDefaults.standard.set($0.rawValue, forKey: "pdfPage") }.store(in: &cancellables)
        $pdfLandscape.sink { UserDefaults.standard.set($0, forKey: "pdfLandscape") }.store(in: &cancellables)
        $pdfMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfMargin") }.store(in: &cancellables)
        $pdfTopMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfTopMargin") }.store(in: &cancellables)
        $pdfBottomMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfBottomMargin") }.store(in: &cancellables)
        $pdfLeftMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfLeftMargin") }.store(in: &cancellables)
        $pdfRightMargin.sink { UserDefaults.standard.set(Double($0), forKey: "pdfRightMargin") }.store(in: &cancellables)
        $pdfFontSize.sink { UserDefaults.standard.set(Double($0), forKey: "pdfFontSize") }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}

