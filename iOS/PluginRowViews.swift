//
//  PluginRowViews.swift
//  PluginReporter (iOS)
//

import SwiftUI

// MARK: - Consolidated Plugin Row

struct ConsolidatedPluginRow: View, Equatable {
    let consolidated: PluginListView.ConsolidatedPlugin

    // SPEED: Only redraw if the actual plugin data changed
    static func == (lhs: ConsolidatedPluginRow, rhs: ConsolidatedPluginRow) -> Bool {
        lhs.consolidated.id == rhs.consolidated.id
    }

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

// MARK: - Plugin Row

struct PluginRow: View, Equatable {
    let plugin: PluginItem

    // SPEED: Only redraw if the actual plugin changed
    static func == (lhs: PluginRow, rhs: PluginRow) -> Bool {
        lhs.plugin.id == rhs.plugin.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plugin.name)
                .font(.headline)

            HStack(spacing: 8) {
                Text(plugin.publisher)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                Text(plugin.style)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                // Show actual type badge
                Text(plugin.type)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ColorUtilities.colorForFormat(plugin.type).opacity(0.2))
                    .foregroundColor(ColorUtilities.colorForFormat(plugin.type))
                    .cornerRadius(6)

                // Show OBSLT badge if obsolete
                if plugin.obsolete {
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
