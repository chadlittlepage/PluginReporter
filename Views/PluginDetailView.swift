//
//  PluginDetailView.swift
//  Plugin Reporter
//
//  Compact detail view for iOS
//

import SwiftUI

struct PluginDetailView: View {
    let item: AppPluginItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Info")) {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Publisher", value: item.publisher)
                    LabeledContent("Version", value: item.version)
                    LabeledContent("Type", value: item.type)
                }
                Section(header: Text("Compatibility")) {
                    LabeledContent("Architectures", value: item.architectures)
                    LabeledContent("Requirement", value: item.runtimeRequirement)
                    LabeledContent("Obsolete", value: item.obsolete ? "Yes" : "No")
                }
                Section(header: Text("File")) {
                    LabeledContent("Date", value: item.dateString)
                    LabeledContent("Size", value: item.sizeString)
                    LabeledContent("Path", value: item.path)
                }
            }
            .navigationTitle("Details")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}
