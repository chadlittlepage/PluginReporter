//
//  UIComponents.swift
//  PluginReporter (iOS)
//

import SwiftUI

// MARK: - Mini Bar Row

struct MiniBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color
    var isSelected: Bool = false

    var fraction: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? color : .secondary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: isSelected ? 8 : 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: isSelected ? 8 : 6)
                }
            }
            .frame(height: 8)

            Text("\(count)")
                .font(.caption)
                .fontWeight(isSelected ? .bold : .semibold)
                .foregroundColor(isSelected ? color : .primary)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
        .opacity(isSelected ? 1.0 : 0.8)
    }
}

// MARK: - Sort Badge

struct SortBadge: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.15))
        .foregroundColor(.yellow)
        .cornerRadius(12)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    var color: Color = .blue  // Default to blue for non-format filters

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(12)
    }
}

// MARK: - Stats Bar Row

struct StatsBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color

    var fraction: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
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
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

// MARK: - Share Sheet
// ShareSheet is defined in ShareSheet.swift
