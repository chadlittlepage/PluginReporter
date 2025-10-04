// StatsView.swift - iOS Statistics Dashboard
// Add this file to iOS target ONLY
import SwiftUI

struct StatsView: View {
    @ObservedObject var cloudSync: CloudSyncManager

    private var formatCounts: (au: Int, vst: Int, vst3: Int, aax: Int, clap: Int, lv2: Int, obsolete: Int) {
        var au = 0, vst = 0, vst3 = 0, aax = 0, clap = 0, lv2 = 0, obsolete = 0
        for plugin in cloudSync.plugins {
            switch plugin.type.uppercased() {
            case "AU": au += 1
            case "VST": vst += 1
            case "VST3": vst3 += 1
            case "AAX": aax += 1
            case "CLAP": clap += 1
            case "LV2": lv2 += 1
            default: break
            }
            if plugin.obsolete { obsolete += 1 }
        }
        return (au, vst, vst3, aax, clap, lv2, obsolete)
    }

    private var topPublishers: [(String, Int)] {
        let publishers = Dictionary(grouping: cloudSync.plugins, by: { $0.publisher })
        return publishers.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    private var topStyles: [(String, Int)] {
        let styles = Dictionary(grouping: cloudSync.plugins, by: { $0.style })
        return styles.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Total Plugins Card
                    totalPluginsCard

                    // Format Breakdown
                    formatBreakdown

                    // Top Publishers
                    topPublishersCard

                    // Top Styles
                    topStylesCard
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .refreshable {
                await cloudSync.syncFromCloud()
            }
        }
    }

    // MARK: - Total Plugins Card

    private var totalPluginsCard: some View {
        VStack(spacing: 12) {
            Text("Total Plugins")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("\(cloudSync.plugins.count)")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            if let syncDate = cloudSync.lastSyncDate {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundColor(.green)
                        Text("Last synced: \(timeAgo(syncDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let deviceName = cloudSync.sourceDeviceName {
                        Text("From: \(deviceName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Format Breakdown

    private var formatBreakdown: some View {
        let counts = formatCounts
        let maxCount = max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Plugin Formats")
                .font(.headline)

            VStack(spacing: 10) {
                StatsBarRow(label: "AU", count: counts.au, maxCount: maxCount, color: .blue)
                StatsBarRow(label: "VST", count: counts.vst, maxCount: maxCount, color: .green)
                StatsBarRow(label: "VST3", count: counts.vst3, maxCount: maxCount, color: .teal)
                StatsBarRow(label: "AAX", count: counts.aax, maxCount: maxCount, color: .purple)
                StatsBarRow(label: "CLAP", count: counts.clap, maxCount: maxCount, color: .orange)
                StatsBarRow(label: "LV2", count: counts.lv2, maxCount: maxCount, color: .gray)

                if counts.obsolete > 0 {
                    Divider()
                    StatsBarRow(label: "Obsolete", count: counts.obsolete, maxCount: maxCount, color: .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Top Publishers Card

    private var topPublishersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Publishers")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(Array(topPublishers.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)

                        Text(item.0)
                            .font(.body)

                        Spacer()

                        Text("\(item.1)")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 6)

                    if index < topPublishers.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Top Styles Card

    private var topStylesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Styles")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(Array(topStyles.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)

                        Text(item.0)
                            .font(.body)

                        Spacer()

                        Text("\(item.1)")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                    .padding(.vertical, 6)

                    if index < topStyles.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) hours ago" }
        return "\(Int(seconds / 86400)) days ago"
    }
}

// MARK: - Stats Bar Row

struct StatsBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color

    var fraction: Double {
        Double(count) / Double(maxCount)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

#Preview {
    StatsView(cloudSync: CloudSyncManager())
}
