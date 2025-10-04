import Foundation

public enum Diagnostics {
    public static func summarize(_ items: [PluginItem]) {
        guard !items.isEmpty else {
            AppLogger.scanner.info("Scan complete: 0 items")
            return
        }

        let byType = Dictionary(grouping: items, by: { $0.type })
            .mapValues { $0.count }
        let byReq = Dictionary(grouping: items, by: { ($0.runtimeRequirement.isEmpty ? "Unknown" : $0.runtimeRequirement) })
            .mapValues { $0.count }

        AppLogger.scanner.info("Scan complete: \(items.count) items")
        AppLogger.scanner.debug("Types: " + byType.sorted { $0.key < $1.key }
              .map { "\($0.key)=\($0.value)" }
              .joined(separator: ", "))
        AppLogger.scanner.debug("Requirements: " + byReq.sorted { $0.key < $1.key }
              .map { "\($0.key)=\($0.value)" }
              .joined(separator: ", "))

        #if DEBUG
        for sample in items.prefix(3) {
            AppLogger.scanner.debug("Sample: \(sample.name) · \(sample.publisher) · \(sample.type)")
        }
        #endif
    }
}
