# iCloud Sync Setup Guide

## Overview

PluginReporter now supports **automatic iCloud synchronization** for:
- ⭐ **Star Ratings** - Your plugin ratings sync across all your devices
- 🏷️ **Tags** - Custom tags you create for organization
- 📝 **Notes** - Personal notes about presets, techniques, etc.
- ✏️ **Metadata Overrides** - Custom publisher names, versions, and styles

## Current Status

✅ **Code is ready** - All managers (RatingsManager, TagsManager, NotesManager, MetadataManager) use CloudSyncStorage
✅ **Graceful fallback** - Works offline, syncs automatically when iCloud is available
🔧 **Requires setup** - Need to add CloudSyncStorage.swift to Xcode project and enable entitlements

## How It Works

### Without iCloud (Current Behavior)
- Data is stored locally using `UserDefaults`
- Each device has its own separate data
- Still works perfectly, just doesn't sync

### With iCloud Enabled
- Data is stored in `NSUbiquitousKeyValueStore` (iCloud Key-Value storage)
- **Automatic sync** across all your Mac, iPad, and iPhone devices
- Changes sync in real-time when online
- Local backup is maintained in UserDefaults as fallback

## Setup Instructions

### 1. Add CloudSyncStorage.swift to Xcode Project

The file `/Users/chadlittlepage/Documents/APPs/PluginReporter/CloudSyncStorage.swift` exists but needs to be added to the Xcode project:

1. Open `PluginReporter.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on the root folder
3. Select "Add Files to PluginReporter..."
4. Select `CloudSyncStorage.swift`
5. **Important**: Check all targets (PR MAC, PR iPHONE, PR iPAD) in the "Add to targets" section
6. Click "Add"

### 2. Enable iCloud Entitlements

Edit `Plugin Reporter.entitlements` and uncomment the iCloud Key-Value Store section:

```xml
<!-- iCloud Key-Value Storage for ratings, tags, notes, and metadata sync -->
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

### 3. Configure Xcode Signing & Capabilities

For **each target** (PR MAC, PR iPHONE, PR iPAD):

1. Select the target in Xcode
2. Go to "Signing & Capabilities" tab
3. Ensure "Automatically manage signing" is enabled
4. **Add Capability**: Click "+ Capability" button
5. Add "iCloud"
6. Enable "Key-value storage" checkbox
7. Your Apple Developer Team should be selected

### 4. Requirements

- **Apple Developer Account** (free or paid)
- **Devices signed in to iCloud** with the same Apple ID
- **Network connection** for initial sync (works offline after)

## Testing iCloud Sync

### 1. Build and run on Device A (e.g., Mac)
- Open a plugin detail
- Add a 5-star rating
- Add tags like "favorite", "mixing"
- Add a note "Great for vocals"

### 2. Build and run on Device B (e.g., iPad)
- Open the same plugin
- **The rating, tags, and notes should sync automatically** ✨

### 3. Check Console Output
Look for these log messages:
```
☁️ iCloud Key-Value Store available and syncing
⭐ Loaded 42 plugin ratings (☁️ Syncing with iCloud)
```

Or without iCloud:
```
💾 Using local storage only (iCloud not available)
⭐ Loaded 42 plugin ratings (💾 Local storage only)
```

## Architecture

### CloudSyncStorage.swift
- Wrapper class that abstracts storage
- Automatically uses iCloud when available
- Falls back to UserDefaults when offline
- Provides sync status for UI display

### Key Features
- **Transparent operation**: Managers don't need to know if iCloud is enabled
- **Local backup**: Always keeps local copy in UserDefaults
- **External change notifications**: Listens for updates from other devices
- **64KB limit per key**: Perfect for metadata (ratings, tags, notes)
- **Automatic conflict resolution**: Last-write-wins (standard for KVStore)

## Troubleshooting

### "Build Failed - Requires Development Certificate"
- You need to enable code signing with your Apple Developer account
- Go to Signing & Capabilities and select your team

### "iCloud not syncing"
- Check that devices are signed in to the same iCloud account
- Check network connection
- iCloud sync can take a few seconds to a few minutes
- Force sync by calling `CloudSyncStorage.shared.forceSynchronize()`

### "Cannot find CloudSyncStorage in scope"
- The file wasn't added to all targets in Xcode
- Make sure CloudSyncStorage.swift is checked for all three targets

## Future Enhancements

Possible additions:
- CloudKit for richer data sync (scan history, export templates)
- Conflict resolution UI for manual merge
- Sync status indicator in settings
- Manual sync button
- Selective sync options (choose what to sync)

## Benefits

✨ **Seamless workflow across devices**
- Start rating plugins on your Mac studio
- Continue on iPad in the living room
- Check your favorites on iPhone on the go

🔄 **No manual export/import needed**
- Your preferences follow you automatically
- New device? Sign in and your data appears

💾 **Safe and private**
- Data never leaves your iCloud account
- Apple's iCloud infrastructure handles security
- Local backup ensures you never lose data
