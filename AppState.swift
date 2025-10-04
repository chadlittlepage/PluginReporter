//
//  AppState.swift
//  Plugin Reporter
//
//  Created by Chad Littlepage on 9/21/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

// AppState.swift — FULL REPLACEMENT (shared selection + clipboard actions)
import Foundation
import AppKit

final class AppState: ObservableObject {
    @Published var selected: [PluginItem] = []   // currently selected rows in the table

    // MARK: Clipboard

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
}
