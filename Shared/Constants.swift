//
//  Constants.swift
//  PluginReporter
//
//  Shared constants across all platforms
//

import CoreGraphics
import Foundation

enum Constants {
    enum PDF {
        static let pageWidth: CGFloat = 612  // 8.5 inches at 72 DPI
        static let pageHeight: CGFloat = 792  // 11 inches at 72 DPI
        static let pageMargin: CGFloat = 40
        static let titleFontSize: CGFloat = 24
        static let headerFontSize: CGFloat = 14
        static let bodyFontSize: CGFloat = 10
        static let lineSpacing: CGFloat = 16
    }

    enum FilePaths {
        static let csvExportFileName = "plugin-list.csv"
        static let pdfExportFileName = "plugin-list.pdf"
    }

    enum Layout {
        static let badgeCornerRadius: CGFloat = 4
        static let cardCornerRadius: CGFloat = 12
        static let standardSpacing: CGFloat = 20
        static let standardPadding: CGFloat = 16
        static let menuMinWidth: CGFloat = 150
    }

    enum Typography {
        static let titleSize: CGFloat = 28
        static let headlineSize: CGFloat = 17
        static let bodySize: CGFloat = 17
        static let captionSize: CGFloat = 12
    }
}
