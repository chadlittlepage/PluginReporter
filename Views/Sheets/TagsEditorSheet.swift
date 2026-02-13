//
//  TagsEditorSheet.swift
//  PluginReporter
//
//  Extracted from MacPluginTable.swift
//  Sheet for managing plugin tags with suggestions
//

import SwiftUI

#if os(macOS)

// MARK: - Tags Editor Sheet

struct TagsEditorSheet: View {
    let plugin: PluginItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tagsManager = TagsManager.shared

    @State private var currentTags: Set<String> = []
    @State private var newTag: String = ""

    var suggestedTags: [String] {
        return tagsManager.getSuggestedTags(for: plugin).prefix(12).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Manage Tags")
                .font(.title)
                .fontWeight(.bold)

            Text(plugin.name)
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()

            // Current Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Tags")
                    .font(.headline)

                if currentTags.isEmpty {
                    Text("No tags yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(currentTags).sorted(), id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.caption)
                                    Button(action: {
                                        currentTags.remove(tag)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
            }

            Divider()

            // Add New Tag
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Tag")
                    .font(.headline)

                HStack {
                    TextField("Type tag name...", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addNewTag()
                        }

                    Button("Add") {
                        addNewTag()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Divider()

            // Suggested Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Tags")
                    .font(.headline)

                Text("Click to add")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Button(action: {
                                currentTags.insert(tag)
                            }) {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.bordered)
                            .disabled(currentTags.contains(tag))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }

            Spacer()

            HStack {
                Button("Clear All") {
                    currentTags.removeAll()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveTags()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600, height: 550)
        .onAppear {
            currentTags = tagsManager.getTags(for: plugin.path)
        }
    }

    private func addNewTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tag.isEmpty else { return }
        currentTags.insert(tag)
        newTag = ""
    }

    private func saveTags() {
        tagsManager.setTags(currentTags, for: plugin.path)
    }
}

#endif
