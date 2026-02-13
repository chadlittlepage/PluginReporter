# Bulk Edit Context Menu Feature

## Overview

When you select multiple plugins in the macOS version of PluginReporter and right-click, you now have access to all the same bulk editing features available in the side panel - directly from the context menu.

**✅ FIXED**: The context menu now correctly shows bulk editing options when multiple plugins are selected. The row-level context menu intelligently switches between single-plugin and multi-plugin modes.

## How to Use

### 1. Select Multiple Plugins
- Click and drag to select multiple plugins
- Or hold **⌘ Command** and click individual plugins to add them to selection
- Or hold **⇧ Shift** and click to select a range

### 2. Right-Click to Access Bulk Edit Menu
When 2 or more plugins are selected, right-clicking shows these options:

#### **Set Rating**
- Choose from 1-5 stars to apply to all selected plugins
- Or choose "Clear Ratings" to remove ratings from all

#### **Add Tag**
- "Add Custom Tag..." - Enter your own tag name
- Quick access to common tags:
  - Favorite, Mixing, Mastering, Vocal, Guitar
  - Effects, Dynamics, EQ, Reverb, Delay

#### **Edit Metadata**
- "Set Publisher..." - Override publisher name for all selected
- "Set Version..." - Override version number for all selected
- "Set Style..." - Override style/category for all selected
- "Clear All Metadata" - Remove all metadata overrides

#### **Add Notes**
- Opens a text editor to enter notes
- The same note will be added to all selected plugins
- Useful for documenting common issues, settings, or usage notes

#### **Uninstall All**
- Shows count: "Uninstall All (X)..."
- Opens confirmation dialog before uninstalling

#### **Show in Finder**
- Opens Finder and selects all selected plugin files

## Features

### Smart Context-Aware Menu
- **Single plugin selected**: Shows individual plugin options (AI Suggestions, Edit Metadata, Manage Tags, etc.)
- **Multiple plugins selected**: Shows bulk editing options

### Input Prompts
All bulk editing operations use native macOS alert dialogs:
- Clean, native interface
- Keyboard-friendly (Tab to navigate, Enter to confirm, Esc to cancel)
- Text inputs auto-focus for quick entry
- **Smart placeholders** - Shows current metadata values:
  - If all selected plugins have the same value: "Current: Eventide"
  - If plugins have different values: "Multiple values: Eventide, Waves, FabFilter..."
- Notes dialog includes a scrollable text view for longer entries

### Visual Feedback
- Console logs confirm successful operations:
  - `⭐ Set rating 5 for 12 plugins`
  - `🏷️ Added tag 'favorite' to 12 plugins`
  - `✏️ Set publisher 'Waves' for 12 plugins`
  - `📝 Added notes to 12 plugins`
  - `🗑️ Cleared metadata for 12 plugins`

### iCloud Sync Integration
All bulk edits automatically sync via iCloud (when enabled):
- Ratings sync by plugin name across all formats
- Tags, notes, and metadata sync by plugin path
- Changes appear on all your devices

## Comparison: Context Menu vs. Side Panel

### Context Menu Advantages:
- **Faster access** - Right-click instead of switching panels
- **Works anywhere** - Don't need to show/hide the detail panel
- **Less screen space** - No panel to manage
- **Quick operations** - Perfect for rapid bulk edits

### Side Panel Advantages:
- **Visual persistence** - See all options at once
- **Batch operations** - Set multiple attributes before applying
- **Copy from first** - Notes panel has "Copy from first selected" button
- **Better for complex workflows** - When you need to set ratings, tags, AND metadata together

## Use Cases

### Common Workflows:

1. **Tag favorite plugins from a specific publisher**
   - Filter by publisher
   - ⌘A to select all
   - Right-click → Add Tag → "favorite"

2. **Set version for outdated plugins**
   - Sort by version
   - Select all old versions
   - Right-click → Edit Metadata → Set Version → "2.0.1"

3. **Rate your most-used effects**
   - Filter by style "Effects"
   - Select the ones you use frequently
   - Right-click → Set Rating → 5 Stars

4. **Add notes about known issues**
   - Select problematic plugins
   - Right-click → Add Notes → "Causes CPU spikes in Logic Pro"

5. **Clean up metadata overrides**
   - Select plugins with incorrect overrides
   - Right-click → Edit Metadata → Clear All Metadata

## Technical Details

### Implementation
- Location: `MacPluginTable.swift:538-622`
- Uses native `NSAlert` dialogs for input prompts
- Integrates with existing managers:
  - `RatingsManager.shared`
  - `TagsManager.shared`
  - `MetadataManager.shared`
  - `NotesManager.shared`

### Menu Structure
```
[Multi-selection context menu]
├── Set Rating
│   ├── 5 Stars
│   ├── 4 Stars
│   ├── 3 Stars
│   ├── 2 Stars
│   ├── 1 Star
│   └── Clear Ratings
├── Add Tag
│   ├── Add Custom Tag...
│   ├── [Divider]
│   └── [10 common tags]
├── Edit Metadata
│   ├── Set Publisher...
│   ├── Set Version...
│   ├── Set Style...
│   ├── [Divider]
│   └── Clear All Metadata
├── Add Notes...
├── [Divider]
├── Uninstall All (X)...
├── [Divider]
└── Show in Finder
```

### Keyboard Shortcuts
While context menu is open:
- **↑/↓** - Navigate menu items
- **→** - Open submenu
- **←** - Close submenu
- **Enter/Return** - Select item
- **Esc** - Close menu

## Future Enhancements

Possible additions:
- "Copy tags from first selected" option
- "Apply rating distribution" (5 stars to top, 4 to next, etc.)
- "Export selected as..." quick export option
- Undo/Redo support for bulk operations
- Multi-step bulk edit wizard
