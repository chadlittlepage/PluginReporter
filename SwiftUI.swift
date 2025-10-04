import SwiftUI

struct TypeBars: View {
    var counts: [String: Int]   // ["AU": 705, "VST": 479, ...]
    var obsoleteCount: Int      // passed in from scanner

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AU").frame(width: 70, alignment: .leading)
                ProgressView(value: Double(counts["AU"] ?? 0),
                             total: Double(maxCount))
                    .accentColor(.teal)
                Text("\(counts["AU"] ?? 0)")
                    .foregroundColor(.teal)
            }
            HStack {
                Text("VST").frame(width: 70, alignment: .leading)
                ProgressView(value: Double(counts["VST"] ?? 0),
                             total: Double(maxCount))
                    .accentColor(.green)
                Text("\(counts["VST"] ?? 0)")
                    .foregroundColor(.green)
            }
            HStack {
                Text("VST3").frame(width: 70, alignment: .leading)
                ProgressView(value: Double(counts["VST3"] ?? 0),
                             total: Double(maxCount))
                    .accentColor(.orange)
                Text("\(counts["VST3"] ?? 0)")
                    .foregroundColor(.orange)
            }
            HStack {
                Text("AAX").frame(width: 70, alignment: .leading)
                ProgressView(value: Double(counts["AAX"] ?? 0),
                             total: Double(maxCount))
                    .accentColor(.purple)
                Text("\(counts["AAX"] ?? 0)")
                    .foregroundColor(.purple)
            }
            HStack {
                Text("CLAP").frame(width: 70, alignment: .leading)
                ProgressView(value: Double(counts["CLAP"] ?? 0),
                             total: Double(maxCount))
                    .accentColor(.blue)
                Text("\(counts["CLAP"] ?? 0)")
                    .foregroundColor(.blue)
            }
            // ✅ New Obsolete row
            HStack {
                Text("Obsolete").frame(width: 70, alignment: .leading)
                ProgressView(value: Double(obsoleteCount),
                             total: Double(maxCount))
                    .accentColor(.red)
                Text("\(obsoleteCount)")
                    .foregroundColor(.red)
            }
        }
    }

    private var maxCount: Int {
        let allCounts = [counts["AU"], counts["VST"], counts["VST3"], counts["AAX"], counts["CLAP"], obsoleteCount]
        return allCounts.compactMap { $0 }.max() ?? 1
    }
}
