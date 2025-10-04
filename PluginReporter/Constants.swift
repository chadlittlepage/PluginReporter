//
//  Constants.swift
//  Plugin Reporter
//
//  Centralized constants for consistent values across the app
//

import Foundation

/// Global constants used throughout the application
enum Constants {

    // MARK: - UI Layout

    enum Layout {
        /// Standard horizontal padding for main content
        static let standardPadding: CGFloat = 16

        /// Standard vertical spacing between elements
        static let standardSpacing: CGFloat = 8

        /// Corner radius for cards and containers
        static let cardCornerRadius: CGFloat = 16

        /// Corner radius for badges and small elements
        static let badgeCornerRadius: CGFloat = 6

        /// Menu dropdown minimum width
        static let menuMinWidth: CGFloat = 220
    }

    // MARK: - Typography

    enum Typography {
        /// Large title font size
        static let titleSize: CGFloat = 28

        /// Navigation bar title size
        static let navTitleSize: CGFloat = 30

        /// Badge text size
        static let badgeSize: CGFloat = 10
    }

    // MARK: - Search

    enum Search {
        /// Threshold for enabling concurrent filtering (number of items)
        static let concurrentFilterThreshold = 1000
    }

    // MARK: - File Paths

    enum FilePaths {
        /// Standard filename for plugin data
        static let pluginsFileName = "plugins.json"

        /// Application support directory name
        static let appSupportDirectory = "PluginReporter"

        /// CSV export filename
        static let csvExportFileName = "plugins.csv"

        /// PDF export filename
        static let pdfExportFileName = "plugins.pdf"
    }

    // MARK: - PDF Generation

    enum PDF {
        /// Page width in points (8.5 inches)
        static let pageWidth: CGFloat = 8.5 * 72.0

        /// Page height in points (11 inches)
        static let pageHeight: CGFloat = 11 * 72.0

        /// Page margin in points
        static let pageMargin: CGFloat = 40

        /// Title font size
        static let titleFontSize: CGFloat = 24

        /// Header font size
        static let headerFontSize: CGFloat = 10

        /// Body font size
        static let bodyFontSize: CGFloat = 9

        /// Line spacing
        static let lineSpacing: CGFloat = 15
    }

    // MARK: - Performance

    enum Performance {
        /// Chunk size divisor for concurrent operations (based on processor count)
        static let chunkSizeDivisor = 1
    }
}
