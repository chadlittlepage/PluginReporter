import SwiftUI

// MARK: - Dashboard Report Preview View

struct DashboardReportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var report: DashboardReport?
    @State private var jsonString: String = ""
    @State private var showingJSON: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let report = report {
                        // Device Info Section
                        PreviewSection(title: "Device Information", icon: "desktopcomputer") {
                            PreviewRow(label: "Device", value: report.deviceInfo.deviceModel)
                            PreviewRow(label: "OS", value: report.deviceInfo.osVersion)
                            PreviewRow(label: "Architecture", value: report.deviceInfo.architecture)
                            PreviewRow(label: "Memory", value: report.deviceInfo.memory)
                            if let resolution = report.deviceInfo.screenResolution {
                                PreviewRow(label: "Screen", value: resolution)
                            }
                        }

                        // App Info Section
                        PreviewSection(title: "App Information", icon: "app.badge") {
                            PreviewRow(label: "Version", value: report.appInfo.version)
                            PreviewRow(label: "Build", value: report.appInfo.build)
                            PreviewRow(label: "Total Launches", value: "\(report.appInfo.totalLaunches)")
                            if let installDate = report.appInfo.installDate {
                                PreviewRow(label: "Installed", value: installDate.formatted(date: .abbreviated, time: .omitted))
                            }
                        }

                        // Plugin Stats Section
                        PreviewSection(title: "Plugin Statistics", icon: "waveform") {
                            PreviewRow(label: "Total Plugins", value: "\(report.pluginStats.totalPlugins)")
                            PreviewRow(label: "Obsolete", value: "\(report.pluginStats.obsoletePlugins)")
                            PreviewRow(label: "Total Size", value: formatBytes(report.pluginStats.totalSizeBytes))
                            PreviewRow(label: "Average Size", value: formatBytes(report.pluginStats.averageSizeBytes))

                            if !report.pluginStats.pluginsByFormat.isEmpty {
                                Divider()
                                Text("By Format")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                ForEach(report.pluginStats.pluginsByFormat.sorted(by: { $0.value > $1.value }), id: \.key) { format, count in
                                    PreviewRow(label: format, value: "\(count)")
                                }
                            }

                            if !report.pluginStats.pluginsByStyle.isEmpty {
                                Divider()
                                Text("By Style (Top 5)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                ForEach(report.pluginStats.pluginsByStyle.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { style, count in
                                    PreviewRow(label: style, value: "\(count)")
                                }
                            }

                            if !report.pluginStats.pluginsByPublisher.isEmpty {
                                Divider()
                                Text("Top Publishers")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                ForEach(report.pluginStats.pluginsByPublisher.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { publisher, count in
                                    PreviewRow(label: publisher, value: "\(count)")
                                }
                            }
                        }

                        // Usage Metrics Section
                        PreviewSection(title: "Usage Metrics", icon: "chart.bar") {
                            PreviewRow(label: "Scans Performed", value: "\(report.usageMetrics.scansPerformed)")
                            PreviewRow(label: "Exports Performed", value: "\(report.usageMetrics.exportsPerformed)")
                            PreviewRow(label: "AI Requests", value: "\(report.usageMetrics.aiSuggestionsRequested)")
                            PreviewRow(label: "Avg Session", value: formatDuration(report.usageMetrics.averageSessionDuration))

                            if let lastScan = report.usageMetrics.lastScanDate {
                                PreviewRow(label: "Last Scan", value: lastScan.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let lastExport = report.usageMetrics.lastExportDate {
                                PreviewRow(label: "Last Export", value: lastExport.formatted(date: .abbreviated, time: .shortened))
                            }
                        }

                        // Error Logs Section
                        if !report.errorLogs.isEmpty {
                            PreviewSection(title: "Error Logs (Last 24h)", icon: "exclamationmark.triangle") {
                                Text("\(report.errorLogs.count) errors logged")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(report.errorLogs.prefix(5), id: \.timestamp) { log in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            severityBadge(log.severity)
                                            Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(log.message)
                                            .font(.caption)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                }

                                if report.errorLogs.count > 5 {
                                    Text("+ \(report.errorLogs.count - 5) more errors")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // JSON Toggle
                        Toggle("Show Raw JSON", isOn: $showingJSON)
                            .padding()

                        if showingJSON && !jsonString.isEmpty {
                            GroupBox {
                                ScrollView(.horizontal, showsIndicators: true) {
                                    Text(jsonString)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding()
                                }
                            }
                            .padding(.horizontal)
                        }

                    } else {
                        ProgressView("Generating report preview...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Report Preview")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
        .task {
            await generatePreview()
        }
    }

    // MARK: - Helpers

    private func generatePreview() async {
        // Get plugins from app state or use empty array
        let plugins: [PluginItem] = []  // In real implementation, get from AppState

        let generatedReport = DashboardReportBuilder.buildReport(plugins: plugins)
        report = generatedReport

        // Generate JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let jsonData = try? encoder.encode(generatedReport),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            jsonString = jsonStr
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

    @ViewBuilder
    private func severityBadge(_ severity: String) -> some View {
        let color: Color = {
            switch severity.lowercased() {
            case "error": return .red
            case "warning": return .orange
            default: return .blue
            }
        }()

        Text(severity.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
    }
}

// MARK: - Preview Section Component

struct PreviewSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.headline)
                }

                Divider()

                content
            }
            .padding(8)
        }
    }
}

// MARK: - Preview Row Component

struct PreviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    DashboardReportPreviewView()
}
