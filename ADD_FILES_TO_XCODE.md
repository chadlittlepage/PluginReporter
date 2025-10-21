# Adding New Files to Xcode Project

The refactoring created 22 new Swift files that need to be added to your Xcode project.

## Quick Instructions

1. Open `PluginReporter.xcodeproj` in Xcode
2. Select all the new files in Finder:
   - AppDelegate.swift
   - ZoomState.swift
   - Components/ (entire folder)
   - Extensions/ (entire folder)
   - Helpers/ (entire folder - PrintHelper.swift, ZoomEnvironment.swift)
   - Models/ (entire folder)
   - Styles/ (entire folder)
   - Views/Playlists/ (folder)
   - Views/Sheets/ (folder)
   - Views/PluginDetailView.swift
   - Views/PrintablePluginTextView.swift

3. Drag them into the Xcode project navigator
4. In the dialog that appears:
   - ☑️ Check "Copy items if needed" (NOT needed - files are already in place)
   - ☑️ Check "Create groups"
   - ☑️ Check "Add to targets": PR MAC
   - Click "Finish"

## OR: Use Terminal Command

Run this from the project directory:

```bash
# This will open Xcode and you can manually add files
open PluginReporter.xcodeproj
```

Then in Xcode:
- Right-click on "PluginReporter" in the project navigator
- Select "Add Files to 'PluginReporter'..."
- Select all the new directories and files listed above
- Make sure "PR MAC" target is checked
- Click "Add"

## List of New Files (22 total)

### Root Level (2)
- AppDelegate.swift
- ZoomState.swift

### Components/ (7)
- FadingScrollbar.swift
- FilterDropdowns.swift
- StarsSelector.swift
- SummaryBars.swift
- TableCells/NotesCell.swift
- TableCells/RatingCell.swift

### Extensions/ (1)
- ViewExtensions+Table.swift

### Helpers/ (2)
- PrintHelper.swift
- ZoomEnvironment.swift

### Models/ (1)
- PluginDragData.swift

### Styles/ (1)
- SpaceModeButtonStyle.swift

### Views/ (6)
- Playlists/PlaylistRowView.swift
- Playlists/PlaylistSidebarView.swift
- PluginDetailView.swift
- PrintablePluginTextView.swift
- Sheets/MetadataEditorSheet.swift
- Sheets/TagsEditorSheet.swift

## After Adding

The build errors should disappear:
- ✅ AppDelegate will be found
- ✅ ZoomState will be found
- ✅ All extracted components will compile

Then rebuild the project:
- Cmd+Shift+K (Clean Build Folder)
- Cmd+B (Build)
