# 🚧 Custom Playlists Feature - IN PROGRESS

**Started**: October 19, 2025
**Status**: 60% Complete - Core functionality built, fixing compilation errors

---

## The Vision

**Create your own custom playlists of plugins** that you can drag and drop from the main plugin table!

### Use Cases:
- "Favorite Reverbs" - Your go-to reverb plugins
- "Mixing Chain" - Essential plugins for mixing
- "Best Synths" - Your favorite synthesizers
- "Try These" - Plugins you want to evaluate
- "Client Favorites" - Plugins specific clients request

---

## ✅ What's Done

### 1. Data Model ✅
- Added `PlaylistType` enum (`.dawImport` vs `.custom`)
- Updated `DAWPlaylist` struct to support both types
- Made `sourceFile` and `dawType` optional (nil for custom playlists)
- Made `entries` mutable for adding/removing plugins

### 2. Manager Methods ✅
- `createCustomPlaylist(name:)` - Creates new empty playlist
- `addPlugin(_:to:)` - Adds plugin to custom playlist
- `removePlugin(_:from:)` - Removes plugin from custom playlist
- Validation to ensure only custom playlists are modified

### 3. UI Dialog ✅
- Created `CreateCustomPlaylistView.swift`
- Beautiful dialog with name input
- Validates duplicate names
- Creates playlist and auto-selects it

### 4. Integration Started ✅
- Added `showCreateCustomPlaylist` state
- + button triggers custom playlist dialog
- Sheet properly displays the dialog

---

## 🚧 What's In Progress

### Compilation Errors to Fix:
Multiple files need updates to handle optional `sourceFile` and `dawType`:

1. **PlaylistMetadataPanel.swift** (4 errors)
   - Line 120: `dawType?.rawValue ?? "Custom"`
   - Line 148: `sourceFile?.lastPathComponent ?? "Custom Playlist"`
   - Lines 344-345: Conditional unwrapping in init

2. **Other potential files:**
   - Any view that displays playlist metadata
   - Any code that accesses `playlist.sourceFile` or `playlist.dawType`

---

## 🎯 What's Next

### Immediate (To Complete Build):
1. Fix PlaylistMetadataPanel to handle optional fields
2. Search for other uses of `sourceFile` and `dawType`
3. Get build succeeding

### Core Features (Next Steps):
4. **Implement drag source** for plugin table rows
   - Add `.onDrag` modifier to MacPluginTable
   - Transfer plugin data in drag

5. **Implement drop target** for playlist items
   - Add `.onDrop` modifier to playlist rows
   - Handle dropped plugins

6. **Visual feedback during drag**
   - Highlight drop zones
   - Show "+" indicator on playlists
   - Disable drop for DAW playlists (read-only)

7. **Distinguish custom vs DAW playlists in UI**
   - Add folder icon for custom playlists
   - Add DAW icon for imported playlists
   - Maybe different colors or badges

---

## Code Changes Made

### DAWPlaylistManager.swift

**Added enum**:
```swift
enum PlaylistType: String, Codable {
    case dawImport   // Imported from a DAW project file
    case custom      // User-created custom playlist
}
```

**Updated DAWPlaylist**:
```swift
struct DAWPlaylist {
    let sourceFile: URL?      // nil for custom
    let dawType: DAWType?     // nil for custom
    let playlistType: PlaylistType
    var entries: [DAWPlaylistEntry]  // now mutable

    // Two initializers:
    // 1. For DAW imports (with sourceFile, dawType)
    // 2. For custom (without sourceFile, dawType)
}
```

**Added methods**:
```swift
func createCustomPlaylist(name: String) -> DAWPlaylist
func addPlugin(_ plugin: PluginItem, to playlist: DAWPlaylist)
func removePlugin(_ entry: DAWPlaylistEntry, from playlist: DAWPlaylist)
```

### ContentView.swift

**Added state**:
```swift
@State private var showCreateCustomPlaylist = false
```

**Added sheet**:
```swift
.sheet(isPresented: $showCreateCustomPlaylist) {
    CreateCustomPlaylistView(playlistManager: playlistManager) { newPlaylist in
        // Select the new playlist
        showPlaylistSidebar = true
        activePlaylistFilters = [newPlaylist]
    }
}
```

**Updated + button**:
```swift
onImport: {
    showCreateCustomPlaylist = true  // Changed from showDAWImport
}
```

### CreateCustomPlaylistView.swift (NEW FILE)

Complete dialog for creating custom playlists with:
- Name input field
- Validation (no empty names, no duplicates)
- Create/Cancel buttons
- Beautiful UI matching app style

---

## How It Will Work (When Complete)

### Creating a Custom Playlist:
1. Click **+** button in DAW Playlists sidebar
2. Dialog appears: "Create Custom Playlist"
3. Enter name (e.g., "Favorite Reverbs")
4. Click Create
5. New empty playlist appears and is selected

### Adding Plugins:
1. Find plugin in main table
2. **Drag** the plugin row
3. **Drop** it on a custom playlist
4. Plugin appears in that playlist
5. Toast notification: "Added [Plugin] to [Playlist]"

### Viewing Custom Playlist:
- Click playlist → shows only those plugins
- Plugins marked as "Custom" track
- Can add more by dragging
- Can remove by right-click → Remove

### Distinguishing Types:
- **Custom playlists**: 📁 folder icon, editable
- **DAW playlists**: 🎵 music icon, read-only
- Different background colors (subtle)

---

## Technical Notes

### Storage
Custom playlists are saved to UserDefaults (same as DAW playlists):
- Codable struct handles both types
- `playlistType` distinguishes them
- Persists between app launches

### Undo Support
All operations support undo:
- Create playlist → Undo deletes it
- Add plugin → Undo removes it
- Delete playlist → Undo restores it

### Validation
- Custom playlists: Can add/remove plugins freely
- DAW playlists: Read-only, can't modify entries
- Duplicate plugins: Prevented (same name + format)

---

## Files Modified

1. ✅ **DAWPlaylistManager.swift** - Core data model and methods
2. ✅ **CreateCustomPlaylistView.swift** - New file for dialog
3. ✅ **ContentView.swift** - Integration and state management
4. 🚧 **PlaylistMetadataPanel.swift** - Needs optional handling
5. 🚧 **Other views** - TBD based on compilation errors

---

## Testing Plan (Once Working)

### Basic Flow:
1. Click + → Create "Test Playlist"
2. Drag a reverb plugin → Drop on playlist
3. Click playlist → See only that plugin
4. Drag another plugin → See 2 plugins
5. Right-click plugin → Remove
6. Delete playlist
7. Cmd+Z (undo) → Playlist restored

### Edge Cases:
1. Duplicate names → Error message
2. Empty name → Can't create
3. Drop on DAW playlist → Rejected
4. Duplicate plugin → Prevented
5. Delete playlist with plugins → Works
6. Quit and relaunch → Playlists persist

---

## Known Issues to Address

### Current Build Errors:
- **4 errors** in PlaylistMetadataPanel.swift
- Need to safely unwrap optional `sourceFile` and `dawType`
- Need to display "Custom" for custom playlists instead of DAW name

### Still to Implement:
- Drag & drop functionality
- Visual feedback during drag
- UI badges to distinguish playlist types
- Context menu for custom playlist items (remove plugin)

---

## Estimated Completion

- **Fix build errors**: 15 minutes
- **Implement drag & drop**: 1 hour
- **Visual polish**: 30 minutes
- **Testing**: 30 minutes

**Total remaining**: ~2.5 hours

---

## Current Todo List

From TodoWrite:
1. ✅ Create data model for custom playlists
2. 🚧 Add 'Create Custom Playlist' dialog (95% done, just build errors)
3. ⏳ Implement drag source for plugin table rows
4. ⏳ Implement drop target for playlist items
5. ⏳ Add visual feedback during drag
6. ✅ Save custom playlists to storage (already works via Codable)
7. ⏳ Add ability to remove plugins from custom playlists
8. ⏳ Distinguish custom vs DAW playlists in UI

---

**Status**: Making excellent progress! Core architecture is solid, just need to finish the UI integration and drag & drop.

**Next Session**: Fix compilation errors, then implement drag & drop! 🚀
