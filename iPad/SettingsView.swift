//
//  SettingsView.swift
//  PluginReporter (iPad)
//
//  iPad settings view
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("iPad")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Information")) {
                    Text("Plugin Reporter helps you manage and export your audio plugin inventory.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
