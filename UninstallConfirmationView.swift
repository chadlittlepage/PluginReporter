//
//  UninstallConfirmationView.swift
//  PluginReporter
//
//  Confirmation dialog for uninstalling plugins
//

import SwiftUI

// MARK: - Uninstall Confirmation View

struct UninstallConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var uninstallManager = UninstallManager.shared

    let plugins: [PluginItem]
    let onComplete: (UninstallResult) -> Void

    @State private var deletionType: UninstallManager.DeletionType = .moveToTrash
    @State private var checkDAWs: Bool = true
    @State private var showWarning: Bool = false
    @State private var isUninstalling: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private var totalSize: String {
        uninstallManager.calculateTotalSize(plugins)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : Color(red: 242/255, green: 242/255, blue: 247/255)
    }

    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.10, green: 0.10, blue: 0.12)
            ]), startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var body: some View {
        #if os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }

    // MARK: - macOS View

    @ViewBuilder
    private var macOSView: some View {
        ZStack {
            gradientBackground

            ScrollView(.vertical, showsIndicators: true) {
                contentView
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("Warning", isPresented: $showWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                performUninstall()
            }
        } message: {
            Text("This will permanently delete \(plugins.count) plugin\(plugins.count == 1 ? "" : "s"). This action cannot be undone.\n\nAre you absolutely sure?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - iOS View (if needed)

    #if os(iOS)
    @ViewBuilder
    private var iOSView: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                contentView
            }
            .navigationTitle("Uninstall Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Warning", isPresented: $showWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                performUninstall()
            }
        } message: {
            Text("This will permanently delete \(plugins.count) plugin\(plugins.count == 1 ? "" : "s"). This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    #endif

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 20) {

            // MARK: - Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Uninstall Plugins")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)

                Text("You are about to uninstall \(plugins.count) plugin\(plugins.count == 1 ? "" : "s") (\(totalSize))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 20)

            // MARK: - Plugin List
            VStack(alignment: .leading, spacing: 8) {
                Text("Plugins to Delete")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                ScrollView(.vertical) {
                    VStack(spacing: 8) {
                        ForEach(plugins, id: \.id) { plugin in
                            PluginDeleteRow(plugin: plugin)
                        }
                    }
                    .padding(16)
                }
                .frame(maxHeight: 200)
                .background(cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }

            // MARK: - Deletion Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Deletion Method")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    // Move to Trash option
                    HStack {
                        Button(action: {
                            deletionType = .moveToTrash
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: deletionType == .moveToTrash ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(deletionType == .moveToTrash ? .blue : .secondary)
                                    .font(.system(size: 20))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Move to Trash")
                                        .font(.headline)
                                    Text("Safe and recoverable (recommended)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(deletionType == .moveToTrash ? Color.blue.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // Permanent Delete option
                    HStack {
                        Button(action: {
                            deletionType = .permanentDelete
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: deletionType == .permanentDelete ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(deletionType == .permanentDelete ? .red : .secondary)
                                    .font(.system(size: 20))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Delete Permanently")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text("Cannot be recovered - use with caution")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(deletionType == .permanentDelete ? Color.red.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }

            // MARK: - Safety Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Safety Checks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Toggle("Check for running DAWs before uninstalling", isOn: $checkDAWs)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    Text("Prevents deletion if Logic, Ableton, Pro Tools, or other DAWs are running.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .background(cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }

            // MARK: - Progress (if uninstalling)
            if isUninstalling {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        ProgressView(value: uninstallManager.uninstallProgress)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Text(uninstallManager.currentOperation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
            }

            // MARK: - Action Buttons
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isUninstalling)

                Button(action: {
                    if deletionType == .permanentDelete {
                        showWarning = true
                    } else {
                        performUninstall()
                    }
                }) {
                    HStack {
                        if isUninstalling {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isUninstalling ? "Uninstalling..." : "Uninstall")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(deletionType == .permanentDelete ? .red : .blue)
                .controlSize(.large)
                .disabled(isUninstalling)

                Spacer()
            }
            .padding(.vertical, 16)

            Spacer(minLength: 40)
        }
        .padding(.top, 20)
    }

    // MARK: - Perform Uninstall

    private func performUninstall() {
        isUninstalling = true

        Task {
            do {
                let result = try await uninstallManager.uninstallPlugins(
                    plugins, deletionType: deletionType, checkDAWs: checkDAWs
                )

                await MainActor.run {
                    isUninstalling = false
                    onComplete(result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUninstalling = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Plugin Delete Row

private struct PluginDeleteRow: View {
    let plugin: PluginItem

    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: plugin.sizeBytes, countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundColor(.red)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 8) {
                    Text(plugin.publisher)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(plugin.type)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(sizeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color.red.opacity(0.05))
        .cornerRadius(6)
    }
}