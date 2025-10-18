// iOS_SettingsView.swift - iOS Settings Screen
// Add this file to iOS target ONLY
import SwiftUI

struct iOS_SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var cloudSync: CloudSyncManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // iCloud Sync Section
            Section {
                Toggle("Sync with iCloud", isOn: $prefs.cloudSyncEnabled)
                    .onChange(of: prefs.cloudSyncEnabled) { newValue in
                        if newValue {
                            Task {
                                await cloudSync.syncFromCloud()
                            }
                        }
                    }

                if prefs.cloudSyncEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: cloudSync.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud.fill")
                                .foregroundColor(cloudSync.isSyncing ? .blue : .green)

                            if cloudSync.isSyncing {
                                Text("Syncing...")
                            } else if let syncDate = cloudSync.lastSyncDate {
                                Text("Last synced: \(timeAgo(syncDate))")
                            } else {
                                Text("Not synced")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        if let deviceName = cloudSync.sourceDeviceName {
                            Text("Synced from: \(deviceName)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        Task {
                            await cloudSync.syncFromCloud()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                    }
                    .disabled(cloudSync.isSyncing)
                }
            } header: {
                Text("iCloud Sync")
            } footer: {
                Text("Syncs your plugin library from your Mac to your iPhone. Requires iCloud enabled on both devices.")
            }

            // Appearance Section
            Section("Appearance") {
                Picker("Interface", selection: $prefs.appearance) {
                    ForEach(Preferences.Appearance.allCases) { mode in
                        Text(title(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // AI Suggestions Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    SecureField("Enter API key (optional)", text: Binding(
                        get: { KeychainHelper.load(key: "openai_api_key") ?? "" },
                        set: { newValue in
                            if newValue.isEmpty {
                                KeychainHelper.delete(key: "openai_api_key")
                            } else {
                                KeychainHelper.save(key: "openai_api_key", value: newValue)
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                    Text("For enhanced AI plugin suggestions. Stored securely in Keychain.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("AI Suggestions")
            }

            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }

                if let url = URL(string: SentryConfig.privacyPolicyURL) {
                    Link("Privacy Policy", destination: url)
                }
                if let url = URL(string: SentryConfig.supportURL) {
                    Link("Support", destination: url)
                }
            }

            // App Info
            Section {
                VStack(alignment: .center, spacing: 8) {
                    Text("Plugin Reporter")
                        .font(.headline)
                    Text("© 2025 Chad Littlepage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func title(for appearance: Preferences.Appearance) -> String {
        switch appearance {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .space: return "Space"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) hours ago" }
        return "\(Int(seconds / 86400)) days ago"
    }
}

#Preview {
    NavigationStack {
        iOS_SettingsView(prefs: Preferences(), cloudSync: CloudSyncManager())
    }
}
