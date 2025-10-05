//
//  ExportView.swift
//  PluginReporter (iPad)
//
//  iPad-optimized export view
//

import SwiftUI

struct ExportView: View {
    let plugins: [PluginItem]
    @StateObject private var viewModel = ExportViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)

                Text("Export Plugin List")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Export all \(plugins.count) plugins")
                    .font(.title3)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Button(action: {
                        viewModel.updatePlugins(plugins)
                        viewModel.exportCSV()
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 50))
                            Text("Export as CSV")
                                .font(.headline)
                        }
                        .frame(width: 200, height: 150)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }

                    Button(action: {
                        viewModel.updatePlugins(plugins)
                        viewModel.exportPDF()
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 50))
                            Text("Export as PDF")
                                .font(.headline)
                        }
                        .frame(width: 200, height: 150)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                }

                Spacer()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
