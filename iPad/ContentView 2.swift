//
//  ContentView.swift
//  PluginReporter (iPad)
//
//  Main content view for iPad with optimized layout
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PluginListViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PluginListView(plugins: viewModel.plugins)
                .tabItem {
                    Label("Plugins", systemImage: "music.note.list")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)

            ExportView(plugins: viewModel.plugins)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
