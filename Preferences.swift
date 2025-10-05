// Preferences.swift — FULL FILE
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
    @Published var appearance: Appearance = .system

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

    // MARK: PDF Export Options (shown in Settings)
    @Published var pdfPage: PDFExportOptions.Page = .letter
    @Published var pdfLandscape: Bool = true  // Default to landscape
    @Published var pdfMargin: CGFloat = 36
    @Published var pdfFontSize: CGFloat = 9

    /// When true, show only obsolete plugins in the table/filter.
    @Published var showObsoleteOnly: Bool = false

    /// Enable/disable cloud sync at runtime. No backend yet; wired to Noop by default.
    @Published var cloudSyncEnabled: Bool = false

    // MARK: Init

    init() {}
}

