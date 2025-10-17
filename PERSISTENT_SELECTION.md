# Persistent Selection Across Filters

## Overview

Selection now persists across filter changes in the macOS version of PluginReporter. When you select plugins, apply filters that hide them, then clear the filters, your selection is automatically restored.

## How It Works

### Selection Persistence
- Selection is tracked by **plugin UUID**, not by display position
- The selected plugin IDs are preserved in memory even when plugins are filtered out
- When you clear filters and plugins become visible again, they are automatically re-selected

### Example Workflow

1. **Start with all plugins visible** (100 plugins)
   - Select 5 plugins from different publishers

2. **Apply a publisher filter** (shows only Waves plugins - 20 plugins)
   - Your 5 selected plugins might not all be Waves plugins
   - Some selected plugins are now hidden by the filter
   - But their IDs remain in the selection set

3. **Clear the filter** (shows all 100 plugins again)
   - ✅ All 5 originally selected plugins are **automatically re-selected**
   - No need to manually re-select them

## Use Cases

### Bulk Editing Across Publishers
1. Search for plugins by name pattern (e.g., "Reverb")
2. Select the ones you want to tag
3. Filter by publisher to verify which are from each vendor
4. Clear filter - selection is preserved
5. Right-click → Add Tag → "reverb" to all selected

### Multi-Stage Selection
1. Filter by format (e.g., VST3 only)
2. Select some VST3 plugins
3. Change filter to AAX only
4. Select some AAX plugins (adds to existing selection)
5. Clear all filters
6. All selected VST3 and AAX plugins are still selected

### Rating Workflow
1. Filter by publisher "Eventide"
2. Select all their reverb plugins
3. Filter by publisher "Valhalla"
4. Add Valhalla reverbs to selection
5. Clear publisher filter
6. Right-click → Set Rating → 5 Stars for all selected reverbs

## Technical Details

### Implementation

**Critical Fix - ContentView.swift:695**:
Removed `.id(displayedPlugins.map(\.id))` modifier that was causing the table to be recreated (and lose all state) whenever filters changed.

**Selection Persistence - MacPluginTable.swift:709-713**:
The key change is in the selection handling:

```swift
.onChange(of: rows) { newRows in
    // When rows change (due to filtering), restore selection for visible plugins
    // macSelection already contains all selected IDs, just update the binding
    selection = newRows.filter { macSelection.contains($0.id) }
}
```

### How Selection is Tracked

1. **Internal Selection Set**: `macSelection = Set<UUID>()`
   - Maintains ALL selected plugin IDs
   - Never cleared by filter changes
   - Only cleared when user explicitly deselects

2. **External Selection Binding**: `@Binding var selection: [PluginItem]`
   - Contains only the selected plugins that are **currently visible**
   - Updates automatically when filters change
   - Used by the detail panel and bulk edit operations

3. **Row Changes Detection**:
   - When `rows` (filtered plugin list) changes
   - System checks which selected IDs are now visible
   - Updates the binding with the intersection

### Selection States

| Filter State | macSelection (IDs) | selection (visible items) | Behavior |
|--------------|-------------------|---------------------------|----------|
| No filter | {id1, id2, id3} | [plugin1, plugin2, plugin3] | All selected visible |
| Filter applied | {id1, id2, id3} | [plugin1] | Only plugin1 matches filter |
| Filter cleared | {id1, id2, id3} | [plugin1, plugin2, plugin3] | All selected visible again |

## Benefits

✅ **No lost work** - Selections persist across filter changes
✅ **Intuitive behavior** - Works like modern file browsers (Finder, Windows Explorer)
✅ **Supports complex workflows** - Build selections across multiple filter states
✅ **Bulk operations** - Select items from different filter views, then act on all

## Limitations

- Selection is maintained only for plugins that still exist in the dataset
- If plugins are uninstalled, they are removed from selection
- Sorting does not affect selection (selection persists across sort changes too)

## Related Features

This feature works seamlessly with:
- **Bulk Edit Context Menu** - Right-click selected items for bulk operations
- **Bulk Edit Panel** - Side panel shows when multiple items selected
- **Filter System** - All filter types (format, publisher, style, stars, search)
- **Sort System** - Selection persists across all sort operations

## Future Enhancements

Possible additions:
- Visual indicator showing "X selected (Y hidden)" when filters hide selected items
- "Select All Matching" command to add filter results to existing selection
- "Invert Selection" command
- Selection history/undo
