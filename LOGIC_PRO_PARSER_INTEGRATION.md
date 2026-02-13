# Logic Pro Parser - Xcode Integration Guide

## Overview
This guide walks you through adding the new **Logic Pro Parser** to your Plugin Reporter Xcode project, enabling DAW import support for Logic Pro project files (`.logic` and `.logicx`).

## Files Created
- ✅ `LogicProParser.swift` - Main parser implementation
- ✅ `DAWParserProtocol.swift` - Updated registry (already modified)

---

## Step-by-Step Integration

### Step 1: Add LogicProParser.swift to Xcode Project

1. Open `PluginReporter.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), locate the DAW parser group (where `AbletonLiveParser.swift`, `BitwigParser.swift`, etc. are located)
3. **Right-click** on the parser group → **Add Files to "Plugin Reporter"...**
4. Navigate to and select: `/Users/chadlittlepage/Documents/APPs/PluginReporter/LogicProParser.swift`
5. Ensure these options are checked:
   - ✅ **Copy items if needed**
   - ✅ **Create groups**
   - ✅ **Add to targets: Plugin Reporter** (main app target)
6. Click **Add**

### Step 2: Update DAWImportView.swift

The import dialog needs to support Logic Pro file extensions. Update the file picker:

**File:** `DAWImportView.swift`

**Find (around line 38):**
```swift
Text("Import plugins from Ableton (.als), Pro Tools (.txt), or Bitwig (.bwproject)")
```

**Replace with:**
```swift
Text("Import plugins from Ableton (.als), Logic Pro (.logic/.logicx), Pro Tools (.txt), or Bitwig (.bwproject)")
```

**Find (around line 119-124):**
```swift
panel.message = "Choose a DAW project file (.als for Ableton, .txt for Pro Tools, .bwproject for Bitwig)"
panel.allowedContentTypes = [
    .init(filenameExtension: "als"),
    .init(filenameExtension: "txt"),
    .init(filenameExtension: "bwproject")
].compactMap { $0 }
```

**Replace with:**
```swift
panel.message = "Choose a DAW project file (.als for Ableton, .logic/.logicx for Logic Pro, .txt for Pro Tools, .bwproject for Bitwig)"
panel.allowedContentTypes = [
    .init(filenameExtension: "als"),
    .init(filenameExtension: "logic"),
    .init(filenameExtension: "logicx"),
    .init(filenameExtension: "txt"),
    .init(filenameExtension: "bwproject")
].compactMap { $0 }
```

**Find (around line 165):**
```swift
Image(systemName: playlist.dawType == .abletonLive ? "waveform" : "music.note")
```

**Replace with:**
```swift
Image(systemName: {
    switch playlist.dawType {
    case .abletonLive: return "waveform"
    case .logicPro: return "music.quarternote.3"
    case .proTools: return "waveform.path"
    case .bitwig: return "circle.hexagongrid"
    default: return "music.note"
    }
}())
```

### Step 3: Verify Registration (Already Done)

The parser is already registered in `DAWParserProtocol.swift:96`:

```swift
registerParser(LogicProParser.self)
```

✅ **No action needed** - this was done automatically.

---

## Testing the Implementation

### Test 1: Build the Project

1. In Xcode, press **⌘B** (Product → Build)
2. Verify no compilation errors
3. Check that `LogicProParser.swift` appears in the build phases:
   - Select the **Plugin Reporter** target
   - Go to **Build Phases** → **Compile Sources**
   - Confirm `LogicProParser.swift` is listed

### Test 2: Test Logic Pro Import

1. Run the app (**⌘R**)
2. Navigate to the **DAW Import** section
3. Click **"Select Project File"**
4. The file picker should now show `.logic` and `.logicx` as supported formats
5. Select a Logic Pro project file
6. Verify that:
   - ✅ Tracks are imported
   - ✅ Plugins are detected and listed
   - ✅ Plugin formats are correctly identified (AU, VST3, etc.)
   - ✅ Metadata (tempo, sample rate) is extracted if available

### Test 3: Verify Parser Registry

Add this temporary debug code to verify registration:

```swift
// In AppDelegate or main view's onAppear
let registry = DAWParserRegistry.shared
print("📦 Supported DAWs: \(registry.supportedDAWs.map { $0.rawValue })")
print("📂 Supported Extensions: \(registry.supportedExtensions)")
```

Expected output:
```
📦 Supported DAWs: ["Ableton Live", "Pro Tools", "Bitwig", "Logic Pro"]
📂 Supported Extensions: ["als", "txt", "bwproject", "logic", "logicx"]
```

---

## Logic Pro File Format Details

### Project Structure

Logic Pro projects are **package directories** (bundles), not single files:

```
MyProject.logic/
├── Alternatives/
│   └── 000/
│       └── ProjectData          ← Main plist file
├── Resources/
└── Media/
```

Or in newer versions:
```
MyProject.logicx/
├── ProjectData                  ← Root-level plist
├── Alternatives/
├── Resources/
└── Media/
```

### What the Parser Extracts

| Data | Source | Notes |
|------|--------|-------|
| **Tracks** | `Tracks` or `TrackList` arrays | Track names and indices |
| **Plugins** | `PluginData`, `Inserts`, `ChannelStrip` | Per-track plugin chains |
| **Plugin Names** | `Name`, `PluginName`, `identifier` | Cleaned and normalized |
| **Manufacturers** | `Manufacturer`, `Vendor` | Defaults to "Apple" for native plugins |
| **Format** | `Type` field | AU (default), VST, VST3, AAX, CLAP |
| **Tempo** | `Tempo`, `DefaultTempo` | BPM value |
| **Sample Rate** | `SampleRate`, `ProjectSampleRate` | Hz (e.g., 44100, 48000) |
| **Version** | `Version`, `ApplicationVersion` | Logic Pro version string |

---

## Supported Plugin Formats in Logic Pro

The parser can identify:

- ✅ **Audio Units (AU)** - Primary format for Logic Pro
- ✅ **VST3** - Supported in Logic Pro 10.7+
- ✅ **VST** - Legacy support
- ✅ **AAX** - Cross-platform plugins
- ✅ **CLAP** - Modern open format

### Native Logic Plugins

Apple's built-in plugins are handled specially:
- Manufacturer: `"Apple"`
- Format: `AU`
- Names extracted from bundle identifiers (e.g., `com.apple.logic.EQ` → `"EQ"`)

---

## Troubleshooting

### Issue: "ProjectData file not found"

**Cause:** Logic Pro version differences or corrupted project

**Solution:**
- The parser checks both `Alternatives/000/ProjectData` and root-level `ProjectData`
- If neither exists, the project may be corrupted or from a very old Logic version

### Issue: No plugins detected

**Cause:** Different plist structure in older Logic versions

**Solution:**
- The parser includes a **deep search fallback** that recursively scans the plist
- This should catch plugins even in non-standard locations

### Issue: Plugin names appear as bundle IDs

**Cause:** Name field missing from plist

**Solution:**
- Parser extracts names from bundle IDs as fallback
- Example: `com.fabfilter.ProQ3` → `"ProQ3"`

### Issue: Build errors about DAWParser protocol

**Cause:** Swift compiler can't find protocol definition

**Solution:**
1. Clean build folder: **⌘⇧K** (Product → Clean Build Folder)
2. Rebuild: **⌘B**
3. Verify `DAWParserProtocol.swift` is in the target's compile sources

---

## File Extensions Reference

| DAW | Extension(s) | Parser | Status |
|-----|-------------|---------|--------|
| **Ableton Live** | `.als` | `AbletonLiveParserV2` | ✅ Active |
| **Logic Pro** | `.logic`, `.logicx` | `LogicProParser` | ✅ **NEW** |
| **Pro Tools** | `.txt` (Session Info export) | `ProToolsTextParser` | ✅ Active |
| **Bitwig Studio** | `.bwproject` | `BitwigParser` | ✅ Active |
| **Cubase** | `.cpr` | Not implemented | ⏳ Planned |
| **Studio One** | `.song` | Not implemented | ⏳ Planned |

---

## Additional Enhancements (Optional)

### Enhanced Icon Support

Add better DAW-specific icons to the playlist view:

```swift
// In PlaylistRow
var dawIcon: String {
    switch playlist.dawType {
    case .abletonLive: return "waveform"
    case .logicPro: return "music.quarternote.3"
    case .proTools: return "waveform.path.ecg"
    case .bitwig: return "circle.hexagongrid.fill"
    default: return "music.note"
    }
}
```

### Add File Extension Validation

```swift
// In DAWImportView
private func validateLogicProject(_ url: URL) -> Bool {
    // Logic projects are bundles/packages
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    return isDirectory.boolValue
}
```

### Add Progress Feedback

The parser can provide progress updates during import:

```swift
// In LogicProParser
static func parseProject(url: URL, progress: ((Double) -> Void)? = nil) throws -> ParsedProject {
    progress?(0.2) // Read file
    let data = try Data(contentsOf: dataURL)

    progress?(0.5) // Parse plist
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)

    progress?(0.8) // Parse tracks
    let tracks = parseTracks(from: plist)

    progress?(1.0) // Complete
    return ParsedProject(...)
}
```

---

## Summary Checklist

Before releasing:

- [ ] `LogicProParser.swift` added to Xcode project
- [ ] `DAWImportView.swift` updated with Logic Pro support
- [ ] Build succeeds with no errors (**⌘B**)
- [ ] File picker shows `.logic` and `.logicx` formats
- [ ] Tested with actual Logic Pro project file
- [ ] Parser registry shows "Logic Pro" in supported DAWs
- [ ] Plugins correctly extracted and matched
- [ ] Icons display correctly for Logic Pro playlists

---

## Example Usage

```swift
// Manual parser usage (if needed)
let logicProjectURL = URL(fileURLWithPath: "/path/to/MyProject.logicx")

do {
    let parsed = try LogicProParser.parseProject(url: logicProjectURL)
    print("Project: \(parsed.name)")
    print("Tracks: \(parsed.tracks.count)")
    print("Total Plugins: \(parsed.allPlugins.count)")
    print("Tempo: \(parsed.tempo ?? 0) BPM")
    print("Sample Rate: \(parsed.sampleRate ?? 0) Hz")
} catch {
    print("Parse failed: \(error)")
}
```

---

## Support & Further Development

### Next Steps

Consider adding parsers for:
1. **Cubase** (`.cpr`) - XML-based format
2. **Studio One** (`.song`) - XML in compressed archive
3. **Reaper** (`.rpp`) - Plain text format (easiest)
4. **FL Studio** (`.flp`) - Binary format (complex)

### Resources

- Logic Pro plist structure varies by version
- Test with projects from Logic Pro 9, X, 10.x, and 11
- Some third-party libraries may have custom structures

---

**Last Updated:** 2025-10-18
**Version:** 1.0
**Author:** Claude Code
**Status:** Ready for Integration ✅
