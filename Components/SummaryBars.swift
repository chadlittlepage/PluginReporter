//
//  SummaryBars.swift
//  Plugin Reporter
//
//  Summary bar graph components for plugin format visualization
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Summary Bars Helpers

func summaryBarsFromList(rows: [AppPluginItem]) -> some View {
    // INSTANT bar graph - direct counting without function call overhead
    var counts = FormatCounts()

    // Ultra-fast counting - single pass, no function calls
    if !rows.isEmpty {
        for row in rows {
            switch row.type {
            case "AU":   counts.au += 1
            case "VST":  counts.vst += 1
            case "VST3": counts.vst3 += 1
            case "AAX":  counts.aax += 1
            case "CLAP": counts.clap += 1
            case "LV2":  counts.lv2 += 1
            default:
                switch row.type.uppercased() {
                case "AU":   counts.au += 1
                case "VST":  counts.vst += 1
                case "VST3": counts.vst3 += 1
                case "AAX":  counts.aax += 1
                case "CLAP": counts.clap += 1
                case "LV2":  counts.lv2 += 1
                default: break
                }
            }
            if row.obsolete { counts.obsolete += 1 }
        }
    }

    // Use MAX value instead of total, so largest bar fills 100%
    let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)
    let hasData = !rows.isEmpty

    return VStack(alignment: .leading, spacing: 6) {
        BarRow(label: "AU",    value: counts.au,       fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0, color: Color.blue)
        BarRow(label: "VST",   value: counts.vst,      fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0, color: Color.green)
        BarRow(label: "VST3",  value: counts.vst3,     fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0, color: Color.teal)
        BarRow(label: "AAX",   value: counts.aax,      fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0, color: Color.purple)
        BarRow(label: "CLAP",  value: counts.clap,     fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0, color: Color.orange)
        BarRow(label: "LV2",   value: counts.lv2,      fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0, color: Color.gray)
        BarRow(label: "OBSLT", value: counts.obsolete, fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0, color: Color.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 12)
    .id(rows.count) // Force re-render only when count changes
    .transaction { $0.animation = nil } // NO animation - INSTANT updates!
}

func summaryBars(rows: [ScannerPluginItem]) -> some View {
    // INSTANT bar graph display
    let counts = formatCounts(for: rows)
    let hasData = !rows.isEmpty
    // Use MAX value instead of total, so largest bar fills 100%
    let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)

    return VStack(alignment: .leading, spacing: 6) {
        BarRow(label: "AU",    value: counts.au,       fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0, color: Color.blue)
        BarRow(label: "VST",   value: counts.vst,      fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0, color: Color.green)
        BarRow(label: "VST3",  value: counts.vst3,     fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0, color: Color.teal)
        BarRow(label: "AAX",   value: counts.aax,      fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0, color: Color.purple)
        BarRow(label: "CLAP",  value: counts.clap,     fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0, color: Color.orange)
        BarRow(label: "LV2",   value: counts.lv2,      fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0, color: Color.gray)
        BarRow(label: "OBSLT", value: counts.obsolete, fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0, color: Color.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 12)
    .transaction { $0.animation = nil } // NO animation - INSTANT updates!
}

// FormatCounts now defined in FormatCounts+Extensions.swift
// Keep local helpers for iOS compatibility
func formatCountsFromList(for rows: [AppPluginItem]) -> FormatCounts {
    var counts = FormatCounts()
    for item in rows {
        counts.increment(for: item.type)
        if item.obsolete { counts.obsolete += 1 }
        if item.missing { counts.missing += 1 }
    }
    return counts
}

func formatCounts(for rows: [ScannerPluginItem]) -> FormatCounts {
    var counts = FormatCounts()
    for item in rows {
        counts.increment(for: item.type)
        if item.obsolete { counts.obsolete += 1 }
    }
    return counts
}

// MARK: - Bar Row Component

struct BarRow: View {
    let label: String
    let value: Int
    let fraction: Double
    let color: Color
    var onTap: (() -> Void)? = nil  // Optional click handler
    var isSelected: Bool = false     // Show if this format is filtered
    var onUninstall: (() -> Void)? = nil  // Optional uninstall handler
    var playlistCount: Int? = nil  // Optional playlist-specific count

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let textColor: Color = {
            if isSelected {
                return color
            } else if colorScheme == .light {
                // Light mode: 55% darker text (was 30%, now adding 25% more)
                return Color.black.opacity(0.8)
            } else {
                return .secondary
            }
        }()

        HStack(spacing: 8) {
            Text(label)
                .frame(width: 50, alignment: .leading)
                .font(.caption)
                .foregroundStyle(textColor)
                .fontWeight(isSelected ? .bold : .regular)

            ZStack(alignment: .leading) {
                // Background - fills available space
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: isSelected ? 8 : 6)

                // Foreground - scales with fraction
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: isSelected ? 8 : 6)
                }
                .frame(height: isSelected ? 8 : 6)
            }
            .frame(maxWidth: .infinity)

            // Show playlist count + total if available, otherwise just total
            if let playlistCount = playlistCount {
                HStack(spacing: 4) {
                    Text("\(playlistCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                        .monospacedDigit()
                    Text("/")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(value)")
                        .font(.caption2)
                        .fontWeight(isSelected ? .bold : .semibold)
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                }
                .frame(width: 70, alignment: .trailing)
            } else {
                Text("\(value)")
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .foregroundStyle(textColor)
                    .frame(width: 40, alignment: .trailing)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 14)
        .opacity(isSelected ? 1.0 : 0.8)  // Match iOS: selected = full opacity, unselected = dimmed
        .contentShape(Rectangle())  // Make entire row tappable
        .onTapGesture {
            onTap?()
        }
        .onHover { isHovering in
            #if os(macOS)
            if onTap != nil {
                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            #endif
        }
        #if os(macOS)
        .contextMenu {
            if value > 0, let onUninstall = onUninstall {
                Button("Uninstall All \(label) Plugins (\(value))") {
                    onUninstall()
                }
            }
        }
        #endif
    }
}

// MARK: - Helper Shape

struct RoundedRect: Shape {
    let rect: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        return Path(roundedRect: self.rect, cornerRadius: cornerRadius)
    }
}
