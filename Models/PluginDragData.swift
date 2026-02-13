//
//  PluginDragData.swift
//  PluginReporter
//
//  Extracted from MacPluginTable.swift
//  Data structure for dragging plugins to playlists
//

import Foundation

#if os(macOS)

// MARK: - Plugin Drag Data

/// Data structure for dragging plugins to playlists
struct PluginDragData: Codable {
    let plugins: [PluginInfo]

    struct PluginInfo: Codable {
        let name: String
        let publisher: String
        let type: String
        let path: String
    }
}

#endif
