//
//  NotesManager.swift
//  PluginReporter
//
//  Manages user notes for plugins
//

import Foundation
import Combine

@MainActor
class NotesManager: ObservableObject {
    static let shared = NotesManager()

    @Published private var notes: [String: String] = [:]

    private let storageKey = "plugin_notes"

    private init() {
        loadNotes()
    }

    /// Get note for a plugin using its path as the key
    func getNote(for pluginPath: String) -> String {
        notes[pluginPath] ?? ""
    }

    /// Set note for a plugin
    func setNote(for pluginPath: String, note: String) {
        if note.isEmpty {
            notes.removeValue(forKey: pluginPath)
        } else {
            notes[pluginPath] = note
        }
        saveNotes()
    }

    /// Check if a plugin has a note
    func hasNote(for pluginPath: String) -> Bool {
        guard let note = notes[pluginPath] else { return false }
        return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Get all notes (for export/backup)
    func getAllNotes() -> [String: String] {
        return notes
    }

    /// Import notes (for restore/sync)
    func importNotes(_ importedNotes: [String: String]) {
        notes = importedNotes
        saveNotes()
    }

    /// Clear all notes
    func clearAllNotes() {
        notes.removeAll()
        saveNotes()
    }

    // MARK: - Persistence

    private func loadNotes() {
        guard let data = CloudSyncStorage.shared.getData(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            print("📝 No saved notes found")
            return
        }
        notes = decoded
        print("📝 Loaded \(notes.count) plugin notes (\(CloudSyncStorage.shared.getSyncStatus()))")
    }

    private func saveNotes() {
        guard let encoded = try? JSONEncoder().encode(notes) else {
            print("❌ Failed to encode notes")
            return
        }
        CloudSyncStorage.shared.setData(encoded, forKey: storageKey)
        print("📝 Saved \(notes.count) plugin notes (\(CloudSyncStorage.shared.getSyncStatus()))")
        objectWillChange.send()
    }

    /// Export notes to JSON file
    func exportNotes() -> String? {
        guard let data = try? JSONEncoder().encode(notes),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// Get statistics about notes
    func getStatistics() -> (totalNotes: Int, totalCharacters: Int) {
        let totalChars = notes.values.reduce(0) { $0 + $1.count }
        return (notes.count, totalChars)
    }
}
