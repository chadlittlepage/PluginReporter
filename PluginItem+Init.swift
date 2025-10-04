// PluginItem+Init.swift — convenience init from ScannerPluginItem
import Foundation

extension PluginItem {
    init(_ s: ScannerPluginItem) {
        self.init(
            id: s.id,
            name: s.name,
            publisher: s.publisher,
            version: s.version,
            type: s.type,
            style: s.style,
            architectures: s.architectures,
            date: s.date,
            sizeBytes: s.sizeBytes,
            path: s.path,
            runtimeRequirement: s.runtimeRequirement,
            obsolete: s.obsolete
        )
    }
}
