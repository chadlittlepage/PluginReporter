//
//  RatingsManager.swift
//  PluginReporter
//
//  Manages user ratings (1-5 stars) for plugins
//

import Foundation
import Combine

@MainActor
class RatingsManager: ObservableObject {
    static let shared = RatingsManager()

    @Published private var ratings: [String: Int] = [:]

    private let storageKey = "plugin_ratings"

    private init() {
        loadRatings()
    }

    /// Get rating for a plugin using its name as the key (0 = unrated)
    /// This allows all formats (AU, VST, VST3, etc.) of the same plugin to share the same rating
    func getRating(forName pluginName: String) -> Int {
        ratings[pluginName] ?? 0
    }

    /// Set rating for a plugin using its name (0-5, where 0 = unrated)
    /// All formats of the same plugin will share this rating
    func setRating(forName pluginName: String, rating: Int) {
        guard rating >= 0 && rating <= 5 else { return }

        if rating == 0 {
            ratings.removeValue(forKey: pluginName)
        } else {
            ratings[pluginName] = rating
        }
        saveRatings()
    }

    // Legacy path-based methods for backward compatibility
    func getRating(for pluginPath: String) -> Int {
        // Extract plugin name from path if needed
        // For now, keep the old behavior
        ratings[pluginPath] ?? 0
    }

    func setRating(for pluginPath: String, rating: Int) {
        guard rating >= 0 && rating <= 5 else { return }

        if rating == 0 {
            ratings.removeValue(forKey: pluginPath)
        } else {
            ratings[pluginPath] = rating
        }
        saveRatings()
    }

    /// Toggle rating - if clicking the same star, clear it; otherwise set it
    func toggleRating(for pluginPath: String, rating: Int) {
        let currentRating = getRating(for: pluginPath)
        if currentRating == rating {
            setRating(for: pluginPath, rating: 0) // Clear rating
        } else {
            setRating(for: pluginPath, rating: rating)
        }
    }

    /// Check if a plugin has a rating
    func hasRating(for pluginPath: String) -> Bool {
        return getRating(for: pluginPath) > 0
    }

    /// Get all ratings (for export/backup)
    func getAllRatings() -> [String: Int] {
        return ratings
    }

    /// Import ratings (for restore/sync)
    func importRatings(_ importedRatings: [String: Int]) {
        ratings = importedRatings
        saveRatings()
    }

    /// Clear all ratings
    func clearAllRatings() {
        ratings.removeAll()
        saveRatings()
    }

    /// Get plugins by rating
    func getPluginPaths(withRating rating: Int) -> [String] {
        return ratings.filter { $0.value == rating }.map { $0.key }
    }

    /// Get rating statistics
    func getStatistics() -> (totalRated: Int, averageRating: Double, distribution: [Int: Int]) {
        let distribution = Dictionary(grouping: ratings.values, by: { $0 })
            .mapValues { $0.count }

        let total = ratings.count
        let sum = ratings.values.reduce(0, +)
        let average = total > 0 ? Double(sum) / Double(total) : 0.0

        return (total, average, distribution)
    }

    // MARK: - Persistence

    private func loadRatings() {
        guard let data = CloudSyncStorage.shared.getData(forKey: storageKey), let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            print("⭐ No saved ratings found")
            return
        }
        ratings = decoded
        print("⭐ Loaded \(ratings.count) plugin ratings (\(CloudSyncStorage.shared.getSyncStatus()))")
    }

    private func saveRatings() {
        guard let encoded = try? JSONEncoder().encode(ratings) else {
            print("❌ Failed to encode ratings")
            return
        }
        CloudSyncStorage.shared.setData(encoded, forKey: storageKey)
        print("⭐ Saved \(ratings.count) plugin ratings (\(CloudSyncStorage.shared.getSyncStatus()))")
        objectWillChange.send()
    }

    /// Export ratings to JSON
    func exportRatings() -> String? {
        guard let data = try? JSONEncoder().encode(ratings), let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// Get star display string for a rating
    func getStarDisplay(for rating: Int) -> String {
        guard rating > 0 && rating <= 5 else { return "" }
        return String(repeating: "⭐", count: rating)
    }

    /// Get Roman numeral for rating (for filter display)
    func getRomanNumeral(for rating: Int) -> String {
        switch rating {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        case 4: return "IIII"
        case 5: return "IIIII"
        default: return ""
        }
    }
}