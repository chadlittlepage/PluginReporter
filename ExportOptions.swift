// ExportOptions.swift — shared export options
import Foundation
import Combine
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
    public var margin: CGFloat = 36
    public var fontSize: CGFloat = 9

    public init() {}
    
    public init(page: Page, landscape: Bool, margin: CGFloat, fontSize: CGFloat) {
        self.page = page
        self.landscape = landscape
        self.margin = margin
        self.fontSize = fontSize
    }
}

#if os(macOS)
import AppKit
#endif

