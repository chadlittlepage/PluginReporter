//
//  RatingCell.swift
//  PluginReporter
//
//  Extracted from MacPluginTable.swift
//  Interactive 5-star rating cell for table rows
//

import SwiftUI

#if os(macOS)

// MARK: - Rating Cell

struct RatingCell: View {
    let pluginName: String
    let pluginPublisher: String
    let pluginPath: String
    let allRows: [PluginItem]
    let width: CGFloat
    @ObservedObject var ratingsManager: RatingsManager
    let fontSize: CGFloat

    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let currentRating = ratingsManager.getRating(forName: pluginName)

        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    // Get the current rating
                    let current = ratingsManager.getRating(forName: pluginName)
                    let newRating = (current == star) ? 0 : star

                    // Set rating using plugin name - all formats will share this rating
                    ratingsManager.setRating(forName: pluginName, rating: newRating)
                }) {
                    Image(systemName: star <= currentRating ? "star.fill" : "star")
                        .font(.system(size: fontSize - 2))
                        .fontWeight(prefs.highContrastMode ? .semibold : .regular)
                        .foregroundColor(star <= currentRating
                            ? (prefs.highContrastMode ? Color(red: 1.0, green: 0.85, blue: 0.0) : .yellow)
                            : .secondary.opacity(prefs.highContrastMode ? 0.5 : 0.3))
                }
                .buttonStyle(.plain)
                .help("Rate \(star) star\(star == 1 ? "" : "s")")
            }
        }
        .padding(.leading, 6)
        .frame(width: width, height: 32, alignment: .leading)
    }
}

#endif
