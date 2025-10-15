import SwiftUI
import AppKit

struct SettingsView: View {
    /// Pass an instance from the caller if you have one, otherwise this
    /// initializer provides a local instance so the view always compiles.
    @ObservedObject var prefs: Preferences

    @State private var showBugReport = false
    @State private var showFeatureRequest = false

    init(prefs: Preferences = Preferences()) {
        self._prefs = ObservedObject(initialValue: prefs)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Form {
                // MARK: - Display
                Section {
                    Picker("Appearance", selection: $prefs.appearance) {
                        ForEach(Preferences.Appearance.allCases) { mode in
                            Text(title(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    HStack {
                        Text("UI Font Size")
                        Slider(value: $prefs.uiFontSizeOffset, in: -5...5, step: 1)
                        Text("\(Int(prefs.uiFontSizeOffset) >= 0 ? "+" : "")\(Int(prefs.uiFontSizeOffset)) pt")
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                        Button("Reset") {
                            prefs.uiFontSizeOffset = 0
                        }
                        .buttonStyle(.borderless)
                        .disabled(prefs.uiFontSizeOffset == 0)
                    }

                    Text("Adjusts all font sizes throughout the interface")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Display")
                }

                // MARK: - Data Sync
                Section {
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
                } header: {
                    Text("Data Sync")
                }

                // MARK: - Format Filters
                Section {
                    Text("Check formats to show only those types. Leave all unchecked to show all plugins.")
                        .font(.caption)
                        .foregroundColor(.secondary)

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
                } header: {
                    Text("Format Filters")
                }

                // MARK: - Extra Scan Folders
                Section {
                    if prefs.extraScanPaths.isEmpty {
                        Text("No extra folders").foregroundStyle(.secondary)
                    } else {
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
                } header: {
                    Text("Extra Scan Folders")
                }

                // MARK: - AI Suggestions
                Section {
                    AISettingsView()
                } header: {
                    Text("AI Suggestions")
                }

                // MARK: - PDF Export
                Section {
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
                } header: {
                    Text("PDF Export")
                }

                // MARK: - Dashboard Reporting
                Section {
                    DashboardSettingsView()
                } header: {
                    Text("Dashboard Reporting")
                }

                // MARK: - Support
                Section {
                    VStack(spacing: 12) {
                        Button {
                            openBugReportWindow()
                        } label: {
                            HStack {
                                Image(systemName: "ant.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Report a Bug")
                                        .font(.headline)
                                    Text("Send crash reports and bug details")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button {
                            openFeatureRequestWindow()
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Request a Feature")
                                        .font(.headline)
                                    Text("Suggest new features or improvements")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                    Text("Your device information will be automatically included to help us assist you better.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Support")
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("macOS")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 800)
    }

    // MARK: Helpers

    func openBugReportWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 950),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Report a Bug"
        window.level = .floating
        window.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: BugReportView())
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
    }

    func openFeatureRequestWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Request a Feature"
        window.level = .floating
        window.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: FeatureRequestView())
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
    }

    func title(for a: Preferences.Appearance) -> String {
        switch a {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .space:  return "Space"
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
