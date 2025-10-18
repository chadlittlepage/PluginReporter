//
//  AppState.swift
//  Plugin Reporter
//
//  Created by Chad Littlepage on 9/21/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

// AppState.swift — FULL REPLACEMENT (shared selection + clipboard actions)
import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

final class AppState: ObservableObject {
    @Published var selected: [PluginItem] = []   // currently selected rows in the table

    // Track selected IDs to persist selection across filter changes
    var selectedIDs: Set<UUID> = []

    // Update ID set when selection changes (called from onChange)
    func updateSelectionIDs() {
        selectedIDs = Set(selected.map(\.id))
    }

    // Restore selection from available plugins based on stored IDs
    func restoreSelection(from availablePlugins: [PluginItem]) {
        // Only update if the selection would actually change to avoid loops
        let restoredSelection = availablePlugins.filter { selectedIDs.contains($0.id) }
        if Set(restoredSelection.map(\.id)) != Set(selected.map(\.id)) {
            selected = restoredSelection
        }
    }

    // MARK: Clipboard

    #if os(macOS)
    func copyPaths() {
        guard !selected.isEmpty else { return }
        let text = selected.map { $0.path }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyFullDetails() {
        guard !selected.isEmpty else { return }
        // Tab-separated per item, newline between items (TSV)
        let lines: [String] = selected.map { i in
            [
                i.name,
                i.publisher,
                i.version,
                i.type,
                i.architectures,
                Humanize.date(i.date),
                Humanize.bytes(i.sizeBytes),
                i.path,
                i.runtimeRequirement,
                i.obsolete ? "Yes" : "No"
            ].joined(separator: "\t")
        }
        let tsv = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tsv, forType: .string)
    }

    var copyPathsTitle: String { selected.count > 1 ? "Copy Paths" : "Copy Path" }
    #endif
}
