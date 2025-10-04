//
//  MissingComponents.swift
//  PluginReporter (iOS)
//
//  Placeholder components for iOS build
//

import SwiftUI

// MARK: - SortBadge
struct SortBadge: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - FilterChip
struct FilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
        .foregroundColor(.primary)
        .cornerRadius(16)
    }
}

// MARK: - ConsolidatedPluginDetailView
struct ConsolidatedPluginDetailView: View {
    let consolidated: PluginListView.ConsolidatedPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(consolidated.name)
                .font(.title2)
                .fontWeight(.bold)

            Text(consolidated.publisher)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Types: \(consolidated.types.joined(separator: ", "))")
                .font(.body)

            Text("Style: \(consolidated.style)")
                .font(.body)
        }
        .padding()
    }
}

// MARK: - ConsolidatedPluginRow
struct ConsolidatedPluginRow: View {
    let consolidated: PluginListView.ConsolidatedPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(consolidated.name)
                .font(.headline)

            HStack(spacing: 8) {
                Text(consolidated.publisher)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                Text(consolidated.style)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                // Show all type badges
                ForEach(consolidated.types, id: \.self) { type in
                    Text(type)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ColorUtilities.colorForFormat(type).opacity(0.2))
                        .foregroundColor(ColorUtilities.colorForFormat(type))
                        .cornerRadius(Constants.Layout.badgeCornerRadius)
                }

                // Show OBSLT badge if obsolete
                if consolidated.isObsolete {
                    Text("OBSLT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ColorUtilities.colorForFormat("OBSLT").opacity(0.2))
                        .foregroundColor(ColorUtilities.colorForFormat("OBSLT"))
                        .cornerRadius(Constants.Layout.badgeCornerRadius)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - MiniBarRow
struct MiniBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color
    let isSelected: Bool

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
