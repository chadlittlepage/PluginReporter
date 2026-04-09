//
//  MergeSuggestionsSheet.swift
//  PluginReporter
//
//  Sheet to show and approve smart merge suggestions for similar publisher names
//

import SwiftUI

struct MergeSuggestionsSheet: View {
    let plugins: [PluginItem]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var metadataManager = MetadataManager.shared

    @State private var suggestions: [PublisherMergeSuggestion] = []
    @State private var isScanning = false
    @State private var selectedSuggestions: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Merge Suggestions")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Similar publisher names detected in your plugin library")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Rescan") {
                    scanForSuggestions()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            // Suggestions list
            if isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning for similar publisher names...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No similar publisher names found")
                        .font(.headline)
                    Text("All publisher names appear to be unique")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(suggestions.count) suggestion\(suggestions.count == 1 ? "" : "s") found")
                            .font(.headline)

                        Spacer()

                        if !selectedSuggestions.isEmpty {
                            Text("\(selectedSuggestions.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(suggestions) { suggestion in
                                MergeSuggestionRow(
                                    suggestion: suggestion, isSelected: selectedSuggestions.contains(suggestion.id), onToggle: {
                                        if selectedSuggestions.contains(suggestion.id) {
                                            selectedSuggestions.remove(suggestion.id)
                                        } else {
                                            selectedSuggestions.insert(suggestion.id)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Select All") {
                    selectedSuggestions = Set(suggestions.map { $0.id })
                }
                .buttonStyle(.bordered)
                .disabled(suggestions.isEmpty)

                Button("Deselect All") {
                    selectedSuggestions.removeAll()
                }
                .buttonStyle(.bordered)
                .disabled(selectedSuggestions.isEmpty)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply Selected") {
                    applySelectedSuggestions()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedSuggestions.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 700, height: 500)
        .onAppear {
            scanForSuggestions()
        }
    }

    private func scanForSuggestions() {
        isScanning = true
        selectedSuggestions.removeAll()

        // Run asynchronously
        Task { @MainActor in
            let publishers = plugins.map { $0.publisher }
            let foundSuggestions = metadataManager.findMergeSuggestions(from: publishers)

            self.suggestions = foundSuggestions
            self.isScanning = false
        }
    }

    private func applySelectedSuggestions() {
        let selected = suggestions.filter { selectedSuggestions.contains($0.id) }

        for suggestion in selected {
            metadataManager.applyMergeSuggestion(suggestion)
        }

        // Remove applied suggestions from the list
        suggestions.removeAll { selectedSuggestions.contains($0.id) }
        selectedSuggestions.removeAll()

        // If no suggestions left, close the sheet
        if suggestions.isEmpty {
            dismiss()
        }
    }
}

// MARK: - Merge Suggestion Row

private struct MergeSuggestionRow: View {
    let suggestion: PublisherMergeSuggestion
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 8) {
                    // Canonical name
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.green)
                        Text(suggestion.canonical)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Variants
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Merge these \(suggestion.variants.count) variant\(suggestion.variants.count == 1 ? "" : "s"):")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(suggestion.variants, id: \.self) { variant in
                            HStack(spacing: 6) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4))
                                    .foregroundColor(.secondary)
                                Text(variant)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showSheet = true

        var body: some View {
            Button("Show Suggestions") {
                showSheet = true
            }
            .sheet(isPresented: $showSheet) {
                MergeSuggestionsSheet(plugins: [])
            }
        }
    }

    return PreviewWrapper()
}