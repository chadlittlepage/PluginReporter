// ExportOptions.swift — shared export options
import Combine
import Foundation
import SwiftUI

public struct PDFExportOptions: Equatable {
    public enum Page: String, CaseIterable, Identifiable {
        case letter = "US Letter"
        case a4 = "A4"
        public var id: String { rawValue }
        public var sizePoints: CGSize { // 72 dpi points
            switch self {
            case .letter: return CGSize(width: 612, height: 792)
            case .a4:     return CGSize(width: 595, height: 842)
            }
        }
    }

    public var page: Page = .letter
    public var landscape: Bool = false
    public var margin: CGFloat = 36  // Legacy: for backward compatibility
    public var topMargin: CGFloat = 36
    public var bottomMargin: CGFloat = 36
    public var leftMargin: CGFloat = 36
    public var rightMargin: CGFloat = 36
    public var fontSize: CGFloat = 9

    public init() {}

    public init(page: Page, landscape: Bool, margin: CGFloat, fontSize: CGFloat) {
        self.page = page
        self.landscape = landscape
        self.margin = margin
        self.topMargin = margin
        self.bottomMargin = margin
        self.leftMargin = margin
        self.rightMargin = margin
        self.fontSize = fontSize
    }

    public init(page: Page, landscape: Bool, topMargin: CGFloat, bottomMargin: CGFloat, leftMargin: CGFloat, rightMargin: CGFloat, fontSize: CGFloat) {
        self.page = page
        self.landscape = landscape
        self.topMargin = topMargin
        self.bottomMargin = bottomMargin
        self.leftMargin = leftMargin
        self.rightMargin = rightMargin
        self.margin = (topMargin + bottomMargin + leftMargin + rightMargin) / 4
        self.fontSize = fontSize
    }
}

#if os(macOS)
import AppKit
#endif
