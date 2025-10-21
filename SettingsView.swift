import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @EnvironmentObject private var scanner: PluginScanner
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
                            ColumnToggleButton(label: "License", isOn: $prefs.pdfShowLicense)
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
                                prefs.pdfShowLicense = true
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
                                prefs.pdfShowLicense = false
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

                // MARK: - Backup & Restore
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backup & Restore")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        // Export Archive
                        Button(action: {
                            exportArchive()
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.doc.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Export Archive")
                                        .foregroundColor(.primary)
                                    Text("Create a complete backup of all your data")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.horizontal, 16)

                        // Import Archive
                        Button(action: {
                            importArchive()
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Import Archive")
                                        .foregroundColor(.primary)
                                    Text("Restore data from a backup file")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // Info text
                    Text("Archive files contain all your ratings, tags, notes, playlists, metadata, and preferences. Use this to backup your data or transfer to a new computer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }

                // MARK: - License Import
                VStack(alignment: .leading, spacing: 8) {
                    Text("License Import")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        // iLok Import
                        Button(action: {
                            openiLokImportWindow()
                        }) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Import from iLok")
                                        .foregroundColor(.primary)
                                    Text("Import license data from iLok License Manager CSV export")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // Info text
                    Text("Import serial numbers, activation codes, and other license information from iLok License Manager to automatically populate your plugin license vault.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
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

    func openiLokImportWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Import from iLok License Manager"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.minSize = NSSize(width: 600, height: 600)
        window.maxSize = NSSize(width: 600, height: 1000)

        // Get plugins from scanner
        let plugins = scanner.plugins

        // Provide environment objects to the view
        let hostingView = NSHostingView(
            rootView: iLokImportView(plugins: plugins)
                .environmentObject(scanner)
                .environmentObject(prefs)
        )
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

    // MARK: - Archive Export/Import

    func exportArchive() {
        // Ensure we're on main thread for immediate UI response
        Task { @MainActor in
            // First, ask if user wants encryption
            let encryptAlert = NSAlert()
            encryptAlert.messageText = "Archive Encryption"
            encryptAlert.informativeText = "Do you want to encrypt this archive with a password?\n\nEncrypted archives use AES-256 encryption and require the password to restore."
            encryptAlert.alertStyle = .informational
            encryptAlert.addButton(withTitle: "Encrypt with Password")
            encryptAlert.addButton(withTitle: "No Encryption")
            encryptAlert.addButton(withTitle: "Cancel")

            let encryptChoice = encryptAlert.runModal()

            if encryptChoice == .alertThirdButtonReturn {
                return // User cancelled
            }

            let useEncryption = (encryptChoice == .alertFirstButtonReturn)
            var password: String? = nil

            if useEncryption {
                // Prompt for password
                let passwordAlert = NSAlert()
                passwordAlert.messageText = "Set Archive Password"
                passwordAlert.informativeText = "Enter a strong password to encrypt your archive.\n\n⚠️ Important: Store this password safely - you will need it to restore the archive."
                passwordAlert.alertStyle = .informational

                let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                passwordField.placeholderString = "Password"
                passwordAlert.accessoryView = passwordField

                passwordAlert.addButton(withTitle: "Encrypt")
                passwordAlert.addButton(withTitle: "Cancel")

                let passwordResponse = passwordAlert.runModal()

                if passwordResponse == .alertSecondButtonReturn {
                    return // User cancelled
                }

                password = passwordField.stringValue

                if password?.isEmpty ?? true {
                    let emptyAlert = NSAlert()
                    emptyAlert.messageText = "Password Required"
                    emptyAlert.informativeText = "Please enter a password to encrypt the archive, or choose 'No Encryption'."
                    emptyAlert.alertStyle = .warning
                    emptyAlert.addButton(withTitle: "OK")
                    emptyAlert.runModal()
                    return
                }

                // Confirm password
                let confirmAlert = NSAlert()
                confirmAlert.messageText = "Confirm Password"
                confirmAlert.informativeText = "Re-enter your password to confirm:"
                confirmAlert.alertStyle = .informational

                let confirmField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                confirmField.placeholderString = "Password"
                confirmAlert.accessoryView = confirmField

                confirmAlert.addButton(withTitle: "Confirm")
                confirmAlert.addButton(withTitle: "Cancel")

                let confirmResponse = confirmAlert.runModal()

                if confirmResponse == .alertSecondButtonReturn {
                    return // User cancelled
                }

                if confirmField.stringValue != password {
                    let mismatchAlert = NSAlert()
                    mismatchAlert.messageText = "Passwords Don't Match"
                    mismatchAlert.informativeText = "The passwords you entered don't match. Please try again."
                    mismatchAlert.alertStyle = .warning
                    mismatchAlert.addButton(withTitle: "OK")
                    mismatchAlert.runModal()
                    return
                }
            }

            // Now show save panel
            let panel = NSSavePanel()
            panel.title = "Export Plugin Reporter Archive"
            panel.message = "Choose a location to save your complete Plugin Reporter backup"
            panel.nameFieldStringValue = "Plugin Reporter Backup \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)).pluginreporter"
            panel.allowedContentTypes = [.init(filenameExtension: ArchiveManager.archiveExtension)!]
            panel.canCreateDirectories = true

            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }

                Task {
                    do {
                        try ArchiveManager.shared.exportArchive(to: url, password: password)

                        await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = "Archive Exported Successfully"
                            let encryptionStatus = useEncryption ? "🔐 Encrypted with AES-256" : "⚠️ Unencrypted"
                            alert.informativeText = """
                            Your Plugin Reporter data has been backed up to:
                            \(url.lastPathComponent)

                            Status: \(encryptionStatus)
                            """
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "OK")
                            alert.addButton(withTitle: "Show in Finder")

                            let response = alert.runModal()
                            if response == .alertSecondButtonReturn {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        }
                    } catch {
                        await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = "Export Failed"
                            alert.informativeText = "Failed to export archive: \(error.localizedDescription)"
                            alert.alertStyle = .critical
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }

    func importArchive() {
        let panel = NSOpenPanel()
        panel.title = "Import Plugin Reporter Archive"
        panel.message = "Choose a Plugin Reporter archive file to restore"
        panel.allowedContentTypes = [.init(filenameExtension: ArchiveManager.archiveExtension)!]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task {
                // Check if archive is encrypted
                let isEncrypted = ArchiveManager.shared.isArchiveEncrypted(at: url)
                var password: String? = nil

                if isEncrypted {
                    // Prompt for password
                    await MainActor.run {
                        let passwordAlert = NSAlert()
                        passwordAlert.messageText = "Encrypted Archive"
                        passwordAlert.informativeText = "This archive is encrypted. Enter the password to decrypt:"
                        passwordAlert.alertStyle = .informational

                        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                        passwordField.placeholderString = "Password"
                        passwordAlert.accessoryView = passwordField

                        passwordAlert.addButton(withTitle: "Decrypt")
                        passwordAlert.addButton(withTitle: "Cancel")

                        let passwordResponse = passwordAlert.runModal()

                        if passwordResponse == .alertSecondButtonReturn {
                            return // User cancelled
                        }

                        password = passwordField.stringValue
                    }

                    guard password != nil && !password!.isEmpty else {
                        return
                    }
                }

                do {
                    // Validate the archive
                    let (manifest, _) = try ArchiveManager.shared.validateArchive(at: url, password: password)

                    // Show confirmation dialog with archive details
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Import Archive?"
                        alert.informativeText = """
                        This will import data from:

                        Export Date: \(DateFormatter.localizedString(from: manifest.exportDate, dateStyle: .medium, timeStyle: .short))
                        App Version: \(manifest.appVersion)
                        Platform: \(manifest.platform)

                        Contents:
                        • \(manifest.inventory.ratingsCount) ratings
                        • \(manifest.inventory.tagsCount) tags
                        • \(manifest.inventory.notesCount) notes
                        • \(manifest.inventory.playlistsCount) playlists
                        • \(manifest.inventory.metadataCount) metadata items

                        Choose how to import:
                        """
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "Replace All Data")
                        alert.addButton(withTitle: "Merge with Existing")
                        alert.addButton(withTitle: "Cancel")

                        let response = alert.runModal()

                        if response == .alertThirdButtonReturn {
                            return // User cancelled
                        }

                        let mergeMode = (response == .alertSecondButtonReturn)

                        Task {
                            do {
                                _ = try ArchiveManager.shared.importArchive(from: url, password: password, mergeMode: mergeMode)

                                await MainActor.run {
                                    let successAlert = NSAlert()
                                    successAlert.messageText = "Archive Imported Successfully"
                                    successAlert.informativeText = mergeMode ?
                                        "Your data has been merged with the imported archive. The app will now restart to load the new data." :
                                        "Your data has been replaced with the imported archive. The app will now restart to load the new data."
                                    successAlert.alertStyle = .informational
                                    successAlert.addButton(withTitle: "Restart Now")
                                    successAlert.runModal()

                                    // Restart the app to reload all data
                                    NSApplication.shared.terminate(nil)
                                }
                            } catch {
                                await MainActor.run {
                                    let errorAlert = NSAlert()
                                    errorAlert.messageText = "Import Failed"
                                    errorAlert.informativeText = "Failed to import archive: \(error.localizedDescription)"
                                    errorAlert.alertStyle = .critical
                                    errorAlert.addButton(withTitle: "OK")
                                    errorAlert.runModal()
                                }
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Invalid Archive"
                        alert.informativeText = "This archive file is invalid or corrupted: \(error.localizedDescription)"
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
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
