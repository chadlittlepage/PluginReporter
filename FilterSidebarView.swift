// FilterSidebarView.swift - iOS Filter Sidebar
// Add this file to iOS target ONLY
import SwiftUI

struct FilterSidebarView: View {
    @ObservedObject var prefs: Preferences
    let allPlugins: [PluginItem]
    @Environment(\.dismiss) private var dismiss

    // Extract unique styles and publishers
    private var availableStyles: [String] {
        Array(Set(allPlugins.map(\.style).filter { !$0.isEmpty })).sorted()
    }

    private var availablePublishers: [String] {
        Array(Set(allPlugins.map(\.publisher).filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        NavigationView {
            Form {
                // Format Filters
                Section("Formats") {
                    ForEach(PluginFormat.allCases) { format in
                        Toggle(format.rawValue, isOn: Binding(
                            get: { prefs.selectedFormats.contains(format) },
                            set: { isOn in
                                if isOn {
                                    prefs.selectedFormats.insert(format)
                                } else {
                                    prefs.selectedFormats.remove(format)
                                }
                            }
                        ))
                    }
                }

                // Style Filters
                Section("Styles") {
                    ForEach(availableStyles, id: \.self) { style in
                        Toggle(style, isOn: Binding(
                            get: { prefs.selectedStyles.contains(style) },
                            set: { isOn in
                                if isOn {
                                    prefs.selectedStyles.insert(style)
                                } else {
                                    prefs.selectedStyles.remove(style)
                                }
                            }
                        ))
                    }
                }

                // Publisher Filters
                Section("Publishers") {
                    ForEach(availablePublishers.prefix(20), id: \.self) { publisher in
                        Toggle(publisher, isOn: Binding(
                            get: { prefs.selectedPublishers.contains(publisher) },
                            set: { isOn in
                                if isOn {
                                    prefs.selectedPublishers.insert(publisher)
                                } else {
                                    prefs.selectedPublishers.remove(publisher)
                                }
                            }
                        ))
                    }

                    if availablePublishers.count > 20 {
                        Text("+ \(availablePublishers.count - 20) more publishers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Actions
                Section {
                    Button(role: .destructive) {
                        clearAllFilters()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Clear All Filters")
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Apply Filters")
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func clearAllFilters() {
        prefs.selectedFormats.removeAll()
        prefs.selectedStyles.removeAll()
        prefs.selectedPublishers.removeAll()
    }
}

#Preview {
    FilterSidebarView(
        prefs: Preferences(),
        allPlugins: [
            PluginItem(name: "Test", publisher: "TestPub", version: "1.0", type: "AU", style: "Reverb", architectures: "Universal", date: Date(), sizeBytes: 1000, path: "/test", runtimeRequirement: "", obsolete: false)
        ]
    )
}
