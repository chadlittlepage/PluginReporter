// PluginColumn.swift — FULL REPLACEMENT
// Canonical definition used by FastTableView / ContentView

import CoreGraphics
import Foundation

public enum PluginColumn: String, CaseIterable, Identifiable, Codable, Hashable {
    case name
    case publisher
    case version
    case type
    case style
    case date
    case size
    case path
    case requirement
    case obsolete
    case missing

    // MARK: Identifiable
    public var id: String { rawValue }

    // MARK: Display title used by NSTableColumn.header
    public var title: String {
        switch self {
        case .name:          return "Name"
        case .publisher:     return "Publisher"
        case .version:       return "Version"
        case .type:          return "Type"
        case .style:         return "Style"
        case .date:          return "Date"
        case .size:          return "Size"
        case .path:          return "Path"
        case .requirement:   return "Requirement"
        case .obsolete:      return "Obsolete"
        case .missing:       return "Missing"
        }
    }

    // MARK: Minimum width hint (used by FastTableView)
    public var minWidth: CGFloat {
        switch self {
        case .name:          return 160
        case .publisher:     return 120
        case .version:       return 80
        case .type:          return 60
        case .style:         return 100
        case .date:          return 110
        case .size:          return 80
        case .path:          return 260
        case .requirement:   return 140
        case .obsolete:      return 70
        case .missing:       return 70
        }
    }
}
