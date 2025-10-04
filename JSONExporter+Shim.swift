//
//  JSONExporter+Shim.swift
//  Plugin Reporter
//
//  Created by Chad Littlepage on 9/23/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import Foundation
import AppKit

extension JSONExporter {
    /// Shim to match the exporters that take (`rows:to:`).
    /// Writes an array of `PluginItem` as pretty-printed JSON to `url`.
    static func write(rows: [PluginItem], to url: URL) {
        let payload: [[String: Any]] = rows.map { i in
            [
                "Name": i.name,
                "Publisher": i.publisher,
                "Version": i.version,
                "Type": i.type,
                "Architectures": i.architectures,
                "Date": i.date?.timeIntervalSince1970 as Any,
                "SizeBytes": i.sizeBytes,
                "Path": i.path,
                "Requirement": i.runtimeRequirement,
                "Obsolete": i.obsolete
            ]
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
            AppLogger.export.error("JSONExporter shim failed: \(error.localizedDescription)")
        }
    }
}
