// SavePanelHelpers.swift
#if os(macOS)
import AppKit

enum SavePanelHelpers {
    static func saveCSV() -> URL?  { save(suggested: "PluginReport.csv") }
    static func saveJSON() -> URL? { save(suggested: "PluginReport.json") }
    static func saveHTML() -> URL? { save(suggested: "PluginReport.html") }
    static func savePDF() -> URL?  { save(suggested: "PluginReport.pdf") }

    private static func save(suggested: String) -> URL? {
        let p = NSSavePanel()
        p.nameFieldStringValue = suggested
        return p.runModal() == .OK ? p.url : nil
    }
}
#endif
