import SwiftUI
import AppKit

struct SettingsView: View {
    /// Pass an instance from the caller if you have one, otherwise this
    /// initializer provides a local instance so the view always compiles.
    @ObservedObject var prefs: Preferences

    init(prefs: Preferences = Preferences()) {
        self._prefs = ObservedObject(initialValue: prefs)
    }

    var body: some View {
        ScrollView {
            Form {
                // Cloud Sync Status
                Section("iCloud Sync") {
                HStack {
                    Toggle("Sync Preferences", isOn: $prefs.cloudSyncEnabled)
                    Spacer()
                    if prefs.cloudSyncEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.green)
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Text("Syncs appearance, formats, scan paths, and export settings across all your devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Appearance
            Section("Appearance") {
                Picker("Interface", selection: $prefs.appearance) {
                    ForEach(Preferences.Appearance.allCases) { mode in
                        Text(title(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Formats visibility
            Section("Visible Formats") {
                HStack(spacing: 16) {
                    ForEach(PluginFormat.allCases, id: \.self) { fmt in
                        Toggle(isOn: Binding(
                            get: { prefs.selectedFormats.contains(fmt) },
                            set: { on in
                                if on { prefs.selectedFormats.insert(fmt) }
                                else { prefs.selectedFormats.remove(fmt) }
                            })) {
                                Text(fmt.rawValue)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                    }
                }
            }

            // Extra scan paths
            Section("Extra Scan Folders") {
                if prefs.extraScanPaths.isEmpty {
                    Text("No extra folders").foregroundStyle(.secondary)
                } else {
                    // Avoid generic inference issues by using enumerated() + \.offset
                    ForEach(Array(prefs.extraScanPaths.enumerated()), id: \.offset) { idx, path in
                        HStack {
                            Text(path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button(role: .destructive) {
                                prefs.extraScanPaths.remove(at: idx)
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Remove")
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        addFolder()
                    } label: {
                        Label("Add Folder…", systemImage: "plus")
                    }
                }
            }

            // AI Suggestions
            Section {
                AISettingsView()
            }

            // PDF Export
            Section("PDF Export") {
                HStack {
                    Picker("Page Size", selection: $prefs.pdfPage) {
                        ForEach(PDFExportOptions.Page.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    Toggle("Landscape", isOn: $prefs.pdfLandscape)
                }
                HStack {
                    Text("Margins")
                    Slider(value: Binding(get: { Double(prefs.pdfMargin) }, set: { prefs.pdfMargin = CGFloat($0) }), in: 12...72)
                    Text("\(Int(prefs.pdfMargin)) pt").monospacedDigit()
                }
                HStack {
                    Text("Font Size")
                    Slider(value: Binding(get: { Double(prefs.pdfFontSize) }, set: { prefs.pdfFontSize = CGFloat($0) }), in: 7...14)
                    Text("\(Int(prefs.pdfFontSize)) pt").monospacedDigit()
                }
            }
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 600)
    }

    // MARK: Helpers

    func title(for a: Preferences.Appearance) -> String {
        switch a {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    func addFolder() {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.allowsMultipleSelection = true
        p.prompt = "Add"
        if p.runModal() == .OK {
            let new = p.urls.map { $0.path }
            // De-dup
            let merged = Array(Set(prefs.extraScanPaths).union(new)).sorted()
            prefs.extraScanPaths = merged
        }
    }
}
