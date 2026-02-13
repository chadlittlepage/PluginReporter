//
//  PluginLicensePanel.swift
//  Plugin Reporter
//
//  License management UI for plugin detail panel
//

import SwiftUI

struct PluginLicensePanel: View {
    let plugin: PluginItem

    @StateObject private var licenseManager = LicenseManager.shared
    @State private var license: PluginLicense?
    @State private var editedLicense: PluginLicense?
    @State private var password: String = ""
    @State private var isEditing = false
    @State private var showingFilePicker = false
    @State private var showCopiedAlert = false
    @State private var copiedItem = ""
    @State private var showDeleteConfirmation = false

    // Cache parsed iLok data to avoid re-parsing on every view update
    @State private var cachedILokData: [String: String] = [:]
    @State private var isILok: Bool = false

    private var pluginID: String {
        LicenseManager.makePluginID(name: plugin.name, publisher: plugin.publisher)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("License & Credentials", systemImage: "key.fill")
                    .font(.headline)

                Spacer()

                if license != nil {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveLicense()
                        } else {
                            startEditing()
                        }
                        isEditing.toggle()
                    }
                } else {
                    Button("Add License Info") {
                        createNewLicense()
                        startEditing()
                        isEditing = true
                    }
                }
            }

            if let license = isEditing ? editedLicense : license {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Quick Info Section (iLok data in compact format) - using CACHED data
                        if !isEditing && isILok {
                            // Show iLok-specific info using cached parsed data
                            VStack(alignment: .leading, spacing: 12) {
                                Text("iLOK LICENSE INFO")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                licenseInfoRow(label: "PRODUCT NAME:", value: license.pluginName)

                                if let validLocations = cachedILokData["Valid Locations"] {
                                    licenseInfoRow(label: "VALID LOCATIONS:", value: validLocations)
                                }

                                if let activations = cachedILokData["Activations"] {
                                    licenseInfoRow(label: "ACTIVATIONS:", value: activations)
                                }

                                if let licenseStatus = cachedILokData["License Status"] {
                                    licenseInfoRow(label: "LICENSE STATUS:", value: licenseStatus)
                                }

                                if let type = cachedILokData["Type"] {
                                    licenseInfoRow(label: "TYPE:", value: type)
                                }

                                if let activationLocation = cachedILokData["Activation Location"], !activationLocation.isEmpty {
                                    licenseInfoRow(label: "ACTIVATION LOCATION:", value: activationLocation)
                                }

                                if let subtype = cachedILokData["Subtype"] {
                                    licenseInfoRow(label: "SUBTYPE:", value: subtype)
                                }

                                if let depositDate = cachedILokData["Deposit Date"] {
                                    licenseInfoRow(label: "DEPOSIT DATE:", value: depositDate)
                                }

                                if let licensePeriod = cachedILokData["License Period"], !licensePeriod.isEmpty {
                                    licenseInfoRow(label: "LICENSE PERIOD:", value: licensePeriod)
                                }

                                if let launchCount = cachedILokData["Launch Count"], !launchCount.isEmpty {
                                    licenseInfoRow(label: "LAUNCH COUNT:", value: launchCount)
                                }

                                if let owner = cachedILokData["Owner"] {
                                    licenseInfoRow(label: "OWNER:", value: owner)
                                }

                                if let publisherLicenseID = cachedILokData["Publisher License ID"], !publisherLicenseID.isEmpty {
                                    licenseInfoRow(label: "PUBLISHER LICENSE ID:", value: publisherLicenseID)
                                }
                            }

                            Divider()
                        }

                        // Serial Number Section - only show if editing or has data
                        if isEditing {
                            licenseSection(
                                title: "Serial Number",
                                icon: "number",
                                value: Binding(
                                    get: { editedLicense?.serialNumber ?? "" },
                                    set: { editedLicense?.serialNumber = $0.isEmpty ? nil : $0 }
                                ),
                                placeholder: "Enter serial number or license key",
                                canCopy: true,
                                isEditing: true
                            )
                        } else if license.serialNumber != nil {
                            licenseSection(
                                title: "Serial Number",
                                icon: "number",
                                value: .constant(license.serialNumber ?? ""),
                                placeholder: "",
                                canCopy: true,
                                isEditing: false
                            )
                        }

                        // Account Credentials Section - only show if editing or has data
                        if isEditing || license.accountEmail != nil || !password.isEmpty {
                            if isEditing || license.serialNumber != nil {
                                Divider()
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Account Credentials", systemImage: "person.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                // Email - only show if editing or has data
                                if isEditing || license.accountEmail != nil {
                                    HStack {
                                        Image(systemName: "envelope")
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)

                                        if isEditing {
                                            TextField("Account email", text: Binding(
                                                get: { editedLicense?.accountEmail ?? "" },
                                                set: { editedLicense?.accountEmail = $0.isEmpty ? nil : $0 }
                                            ))
                                            .textFieldStyle(.roundedBorder)
                                        } else if let email = license.accountEmail {
                                            Text(email)
                                                .foregroundColor(.primary)

                                            Spacer()
                                            Button(action: { copyToClipboard(email) }) {
                                                Image(systemName: "doc.on.doc")
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }

                                // Password - only show if editing or has data
                                if isEditing || !password.isEmpty {
                                    HStack {
                                        Image(systemName: "lock")
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)

                                        if isEditing {
                                            SecureField("Password", text: $password)
                                                .textFieldStyle(.roundedBorder)
                                        } else {
                                            Text("••••••••")
                                                .foregroundColor(.primary)

                                            Spacer()
                                            Button(action: { copyToClipboard(password, item: "Password") }) {
                                                Image(systemName: "doc.on.doc")
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                            }
                        }

                        // Activation Tracking - only show if editing or has data
                        if isEditing || license.activationsUsed != nil || license.activationCode != nil {
                            if isEditing || license.accountEmail != nil || !password.isEmpty || license.serialNumber != nil {
                                Divider()
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Activation Tracking", systemImage: "desktopcomputer")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if isEditing || license.activationsUsed != nil {
                                    HStack {
                                        Text("Activations Used:")
                                            .foregroundColor(.secondary)

                                        if isEditing {
                                            TextField("0", value: Binding(
                                                get: { editedLicense?.activationsUsed ?? 0 },
                                                set: { editedLicense?.activationsUsed = $0 }
                                            ), format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 60)

                                            Text("of")

                                            TextField("0", value: Binding(
                                                get: { editedLicense?.maxActivations ?? 0 },
                                                set: { editedLicense?.maxActivations = $0 }
                                            ), format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 60)
                                        } else if let used = license.activationsUsed, let max = license.maxActivations {
                                            Text("\(used) of \(max)")
                                                .fontWeight(.medium)

                                            if used >= max {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }
                                }

                                if isEditing {
                                    TextField("Activation code (optional)", text: Binding(
                                        get: { editedLicense?.activationCode ?? "" },
                                        set: { editedLicense?.activationCode = $0.isEmpty ? nil : $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                } else if let code = license.activationCode {
                                    HStack {
                                        Text("Activation Code:")
                                            .foregroundColor(.secondary)
                                        Text(code)
                                        Spacer()
                                        Button(action: { copyToClipboard(code, item: "Activation Code") }) {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }

                        // Purchase Information - only show if editing or has data
                        if isEditing || license.purchaseDate != nil || license.invoiceNumber != nil {
                            if isEditing || license.activationsUsed != nil || license.activationCode != nil || license.accountEmail != nil || !password.isEmpty || license.serialNumber != nil {
                                Divider()
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Purchase Information", systemImage: "cart.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if isEditing || license.purchaseDate != nil {
                                    HStack {
                                        Text("Purchase Date:")
                                            .foregroundColor(.secondary)

                                        if isEditing {
                                            DatePicker("", selection: Binding(
                                                get: { editedLicense?.purchaseDate ?? Date() },
                                                set: { editedLicense?.purchaseDate = $0 }
                                            ), displayedComponents: .date)
                                            .labelsHidden()
                                        } else if let date = license.purchaseDate {
                                            Text(date, style: .date)
                                        }
                                    }
                                }

                                if isEditing {
                                    TextField("Invoice number (optional)", text: Binding(
                                        get: { editedLicense?.invoiceNumber ?? "" },
                                        set: { editedLicense?.invoiceNumber = $0.isEmpty ? nil : $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                } else if let invoice = license.invoiceNumber {
                                    HStack {
                                        Text("Invoice:")
                                            .foregroundColor(.secondary)
                                        Text(invoice)
                                    }
                                }
                            }
                        }

                        // Links - only show if has any links
                        if license.manufacturerURL != nil || license.accountPortalURL != nil || license.supportURL != nil {
                            if isEditing || license.purchaseDate != nil || license.invoiceNumber != nil || license.activationsUsed != nil || license.activationCode != nil || license.accountEmail != nil || !password.isEmpty || license.serialNumber != nil {
                                Divider()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Vendor Links", systemImage: "link")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let url = license.manufacturerURL, let link = URL(string: url) {
                                    Link(destination: link) {
                                        HStack {
                                            Image(systemName: "globe")
                                            Text("Manufacturer Website")
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                        }
                                    }
                                }

                                if let url = license.accountPortalURL, let link = URL(string: url) {
                                    Link(destination: link) {
                                        HStack {
                                            Image(systemName: "person.crop.circle")
                                            Text("Account Portal")
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                        }
                                    }
                                }

                                if let url = license.supportURL, let link = URL(string: url) {
                                    Link(destination: link) {
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                            Text("Support")
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "note.text")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if isEditing {
                                TextEditor(text: Binding(
                                    get: { editedLicense?.notes ?? "" },
                                    set: { editedLicense?.notes = $0.isEmpty ? nil : $0 }
                                ))
                                .frame(minHeight: 60)
                                .border(Color.secondary.opacity(0.3))
                            } else {
                                Text(license.notes ?? "No notes")
                                    .foregroundColor(license.notes == nil ? .secondary : .primary)
                            }
                        }

                        // Delete Button
                        if !isEditing {
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete License Info", systemImage: "trash")
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No license information stored")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Store your serial numbers, passwords, and activation codes securely")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }

            // Copied Alert
            if showCopiedAlert {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(copiedItem) copied to clipboard")
                        .font(.caption)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
        .onAppear {
            loadLicense()
        }
        .alert("Delete License Info?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLicense()
            }
        } message: {
            Text("Are you sure you want to delete the license information for \(plugin.name)?")
        }
    }

    // MARK: - Helper Functions

    private func parseILokNotes(_ notes: String) -> [String: String] {
        var data: [String: String] = [:]

        let lines = notes.components(separatedBy: "\n")
        for line in lines {
            if line.contains(": ") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    data[key] = value
                }
            }
        }

        return data
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Helper Views

    private func licenseInfoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private func licenseSection(title: String, icon: String, value: Binding<String>, placeholder: String, canCopy: Bool = false, isEditing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                if isEditing {
                    TextField(placeholder, text: value)
                    .textFieldStyle(.roundedBorder)
                } else {
                    Text(value.wrappedValue.isEmpty ? "Not set" : value.wrappedValue)
                        .foregroundColor(value.wrappedValue.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)

                    if canCopy && !value.wrappedValue.isEmpty {
                        Spacer()
                        Button(action: { copyToClipboard(value.wrappedValue, item: title) }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadLicense() {
        let currentPluginID = pluginID

        // Load license data
        let newLicense = licenseManager.getLicense(for: currentPluginID)
        let newPassword = licenseManager.getPassword(for: currentPluginID) ?? ""

        // Parse iLok data if needed
        let newIsILok = newLicense?.notes?.contains("Imported from iLok License Manager") ?? false
        let newCachedData = newIsILok ? parseILokNotes(newLicense?.notes ?? "") : [:]

        // Update all state at once
        license = newLicense
        password = newPassword
        isILok = newIsILok
        cachedILokData = newCachedData
    }

    private func createNewLicense() {
        let newLicense = PluginLicense(pluginName: plugin.name, pluginID: pluginID)
        license = newLicense
        editedLicense = newLicense
    }

    private func startEditing() {
        editedLicense = license
    }

    private func saveLicense() {
        guard var updatedLicense = editedLicense else { return }

        // Update modification date
        updatedLicense.lastModified = Date()

        // Save license
        licenseManager.setLicense(updatedLicense)

        // Save password to keychain if provided
        if !password.isEmpty {
            _ = licenseManager.setPassword(password, for: pluginID)
        }

        self.license = updatedLicense
        editedLicense = nil
    }

    private func deleteLicense() {
        licenseManager.deleteLicense(for: pluginID)
        license = nil
        password = ""
    }

    private func copyToClipboard(_ text: String, item: String = "Serial") {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        copiedItem = item
        withAnimation {
            showCopiedAlert = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedAlert = false
            }
        }
    }
}
