//
//  NotesCell.swift
//  PluginReporter
//
//  Extracted from MacPluginTable.swift
//  Inline editable notes cell for table rows
//

import SwiftUI

#if os(macOS)

// MARK: - Notes Cell

struct NotesCell: View {
    let pluginPath: String
    let width: CGFloat
    @ObservedObject var notesManager: NotesManager
    let fontSize: CGFloat

    @State private var isEditing = false
    @State private var editingText = ""
    @FocusState private var isFocused: Bool
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            if isEditing {
                TextField("Add notes...", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSize))
                    .fontWeight(prefs.highContrastMode ? .semibold : .regular)
                    .padding(.leading, 6)
                    .frame(width: width, height: 32, alignment: .leading)
                    .focused($isFocused)
                    .onSubmit {
                        saveNote()
                    }
                    .onAppear {
                        isFocused = true
                    }
            } else {
                let note = notesManager.getNote(for: pluginPath)
                Text(note.isEmpty ? "" : note)
                    .font(.system(size: fontSize))
                    .fontWeight(prefs.highContrastMode ? .semibold : .regular)
                    .foregroundColor(note.isEmpty ? .secondary.opacity(0.5) : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 6)
                    .frame(width: width, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing()
                    }
            }
        }
        .onChange(of: isFocused) { focused in
            if !focused && isEditing {
                saveNote()
            }
        }
    }

    private func startEditing() {
        editingText = notesManager.getNote(for: pluginPath)
        isEditing = true
    }

    private func saveNote() {
        notesManager.setNote(for: pluginPath, note: editingText)
        isEditing = false
    }
}

#endif
