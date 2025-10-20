import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @State private var showBugReport = false
    @State private var showFeatureRequest = false
    @Environment(\.colorScheme) var colorScheme

    // Local state for appearance to prevent publishing during view updates
    @State private var selectedAppearance: Preferences.Appearance = .dark

    init(prefs: Preferences = Preferences()) {
        self._prefs = ObservedObject(initialValue: prefs)
        self._selectedAppearance = State(initialValue: prefs.appearance)
    }

    // Match iOS card background colors
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : Color(red: 242/255, green: 242/255, blue: 247/255)
    }

    private var appBackground: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        Picker("Appearance", selection: $selectedAppearance) {
                            ForEach(Preferences.Appearance.allCases) { mode in
                                Text(title(for: mode)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .onChange(of: selectedAppearance) { newValue in
                            // Update prefs asynchronously to avoid publishing during view update
                            Task { @MainActor in
                                prefs.appearance = newValue
                            }
                        }
                        .onAppear {
                            // Sync local state with prefs on appear
                            selectedAppearance = prefs.appearance
                        }
                        .onChange(of: prefs.appearance) { newValue in
                            // Keep selectedAppearance in sync if prefs changes externally
                            if selectedAppearance != newValue {
                                selectedAppearance = newValue
                            }
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        VStack(spacing: 8) {
                            HStack {
                                Text("UI Font Size")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(Int(prefs.uiFontSizeOffset) >= 0 ? "+" : "")\(Int(prefs.uiFontSizeOffset)) pt")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                Button("Reset") {
                                    prefs.uiFontSizeOffset = 0
                                }
                                .buttonStyle(.borderless)
                                .disabled(prefs.uiFontSizeOffset == 0)
                            }
                            .padding(.horizontal, 16)

                            Slider(value: $prefs.uiFontSizeOffset, in: -5...5, step: 1)
                                .padding(.horizontal, 16)

                            Text("Adjusts all font sizes throughout the interface")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Data Sync
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Sync")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
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
                        .padding(16)

                        Text("Syncs appearance, formats, scan paths, and export settings across all your devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Format Filters
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format Filters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        Text("Check formats to show only those types. Leave all unchecked to show all plugins.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(16)

                        HStack(spacing: 8) {
                            ForEach(PluginFormat.allCases, id: \.self) { fmt in
                                Toggle(isOn: Binding(
                                    get: { prefs.selectedFormats.contains(fmt) },
                                    set: { on in
                                        if on { prefs.selectedFormats.insert(fmt) }
                                        else { prefs.selectedFormats.remove(fmt) }
                                    })) {
                                        Text(fmt.rawValue)
                                            .font(.caption)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .toggleStyle(.button)
                                    .buttonStyle(.bordered)
                                    .tint(ColorUtilities.colorForFormat(fmt.rawValue))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Extra Scan Folders
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extra Scan Folders")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        if prefs.extraScanPaths.isEmpty {
                            Text("No extra folders")
                                .foregroundStyle(.secondary)
                                .padding(16)
                        } else {
                            ForEach(Array(prefs.extraScanPaths.enumerated()), id: \.offset) { idx, path in
                                HStack {
                                    Text(path)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .font(.caption)
                                    Spacer()
                                    Button(role: .destructive) {
                                        prefs.extraScanPaths.remove(at: idx)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)

                                if idx < prefs.extraScanPaths.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        HStack {
                            Spacer()
                            Button {
                                addFolder()
                            } label: {
                                Label("Add Folder...", systemImage: "plus")
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - AI Suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Suggestions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        AISettingsView()
                            .padding(16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Export Column Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Columns")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        Text("Select which columns to include in PDF exports")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Column toggle buttons in correct order
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 10) {  // 120 * 0.8 = 96, 12 * 0.8 = 9.6 ≈ 10
                            ColumnToggleButton(label: "Rating", isOn: $prefs.pdfShowRating)
                            ColumnToggleButton(label: "Name", isOn: $prefs.pdfShowName)
                            ColumnToggleButton(label: "Publisher", isOn: $prefs.pdfShowPublisher)
                            ColumnToggleButton(label: "Type", isOn: $prefs.pdfShowType)
                            ColumnToggleButton(label: "Style", isOn: $prefs.pdfShowStyle)
                            ColumnToggleButton(label: "Version", isOn: $prefs.pdfShowVersion)
                            ColumnToggleButton(label: "Arch", isOn: $prefs.pdfShowArch)
                            ColumnToggleButton(label: "Date", isOn: $prefs.pdfShowDate)
                            ColumnToggleButton(label: "Size", isOn: $prefs.pdfShowSize)
                            ColumnToggleButton(label: "Requirement", isOn: $prefs.pdfShowRequirement)
                            ColumnToggleButton(label: "Obsolete", isOn: $prefs.pdfShowObsolete)
                            ColumnToggleButton(label: "Missing", isOn: $prefs.pdfShowMissing)
                            ColumnToggleButton(label: "Track", isOn: $prefs.pdfShowTrack)
                            ColumnToggleButton(label: "Notes", isOn: $prefs.pdfShowNotes)
                            ColumnToggleButton(label: "Path", isOn: $prefs.pdfShowPath)
                        }

                        // Quick actions
                        HStack {
                            Button("Select All") {
                                prefs.pdfShowRating = true
                                prefs.pdfShowName = true
                                prefs.pdfShowPublisher = true
                                prefs.pdfShowType = true
                                prefs.pdfShowStyle = true
                                prefs.pdfShowVersion = true
                                prefs.pdfShowArch = true
                                prefs.pdfShowDate = true
                                prefs.pdfShowSize = true
                                prefs.pdfShowRequirement = true
                                prefs.pdfShowObsolete = true
                                prefs.pdfShowMissing = true
                                prefs.pdfShowTrack = true
                                prefs.pdfShowNotes = true
                                prefs.pdfShowPath = true
                            }
                            .buttonStyle(.bordered)

                            Button("Deselect All") {
                                prefs.pdfShowRating = false
                                prefs.pdfShowName = false
                                prefs.pdfShowPublisher = false
                                prefs.pdfShowType = false
                                prefs.pdfShowStyle = false
                                prefs.pdfShowVersion = false
                                prefs.pdfShowArch = false
                                prefs.pdfShowDate = false
                                prefs.pdfShowSize = false
                                prefs.pdfShowRequirement = false
                                prefs.pdfShowObsolete = false
                                prefs.pdfShowMissing = false
                                prefs.pdfShowTrack = false
                                prefs.pdfShowNotes = false
                                prefs.pdfShowPath = false
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Dashboard Reporting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dashboard Reporting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        DashboardSettingsView()
                            .padding(16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Support
                VStack(alignment: .leading, spacing: 8) {
                    Text("Support")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        Button {
                            openBugReportWindow()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "ant.fill")
                                    .foregroundColor(.red)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Report a Bug")
                                        .foregroundColor(.primary)
                                    Text("Send crash reports and bug details")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(16)

                        Divider()
                            .padding(.horizontal, 16)

                        Button {
                            openFeatureRequestWindow()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Request a Feature")
                                        .foregroundColor(.primary)
                                    Text("Suggest new features or improvements")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(16)

                        Text("Your device information will be automatically included to help us assist you better.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - About
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                        .padding(16)

                        Divider()
                            .padding(.horizontal, 16)

                        HStack {
                            Text("Platform")
                            Spacer()
                            Text("macOS")
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .background(appBackground)
        .frame(minWidth: 700, idealWidth: 900, maxWidth: .infinity, minHeight: 800, idealHeight: 1000, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReportBug"))) { _ in
            openBugReportWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestFeature"))) { _ in
            openFeatureRequestWindow()
        }
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
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

        let hostingView = NSHostingView(rootView: BugReportView())
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
    }

    func openFeatureRequestWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Request a Feature"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

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
            let merged = Array(Set(prefs.extraScanPaths).union(new)).sorted()
            prefs.extraScanPaths = merged
        }
    }
}

// MARK: - Column Toggle Button

struct ColumnToggleButton: View {
    let label: String
    @Binding var isOn: Bool

    // Desaturated blue - 20% less saturated (moved 20% towards grey)
    private var desaturatedBlue: Color {
        #if os(macOS)
        Color(red: 0.24, green: 0.52, blue: 0.78)  // Less saturated blue
        #else
        Color.accentColor
        #endif
    }

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 6) {  // 8 * 0.8 = 6.4 ≈ 6
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? desaturatedBlue : .secondary)
                    .font(.system(size: 13))  // 16 * 0.8 = 12.8 ≈ 13

                Text(label)
                    .font(.system(size: 12))  // 8 + 4 = 12
                    .foregroundColor(isOn ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)  // 8 * 0.8 = 6.4 ≈ 6
            .padding(.horizontal, 10)  // 12 * 0.8 = 9.6 ≈ 10
            .background(
                RoundedRectangle(cornerRadius: 6)  // 8 * 0.8 = 6.4 ≈ 6
                    .fill(isOn ? desaturatedBlue.opacity(0.15) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)  // 8 * 0.8 = 6.4 ≈ 6
                    .strokeBorder(isOn ? desaturatedBlue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
