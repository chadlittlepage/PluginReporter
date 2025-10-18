# DAW Playlist Feature - Detailed Specification
## Plugin Reporter - Ableton Live Integration

**Feature Request**: Parse Ableton Live projects and create detailed playlists
**Date**: October 17, 2025

---

## 🎯 FEATURE CLARIFICATION

### What You Actually Want:

**INPUT**: Ableton Live project file (`.als`)

**OUTPUT**: Playlist in Plugin Reporter containing:
1. **Playlist Name**: Same as Live project name
2. **Plugin List**: All plugins used in the project
3. **Track Context**: Which track each plugin was used on

**Example**:

```
Ableton Project: "My Epic Song.als"
├── Track 1: "Drums"
│   ├── Valhalla Room (Reverb)
│   └── FabFilter Pro-Q 3 (EQ)
├── Track 2: "Bass"
│   ├── Serum (Synth)
│   └── iZotope Ozone (Mastering)
└── Track 3: "Vocals"
    ├── Melodyne (Pitch)
    └── Waves CLA-2A (Compression)

↓ ↓ ↓ BECOMES ↓ ↓ ↓

Plugin Reporter Playlist: "My Epic Song"
├── Valhalla Room (used on: Drums)
├── FabFilter Pro-Q 3 (used on: Drums)
├── Serum (used on: Bass)
├── iZotope Ozone (used on: Bass)
├── Melodyne (used on: Vocals)
└── Waves CLA-2A (used on: Vocals)
```

---

## 🔍 UPDATED DIFFICULTY ASSESSMENT

### With Track Information Added

**Difficulty**: ⭐⭐⭐⭐ (4/10) - **EASY-MEDIUM**

**Why Slightly Harder**:
- Need to parse track names (additional XML parsing)
- Need to associate plugins with their tracks
- Need to handle duplicates (same plugin on multiple tracks)
- Need new data model for "plugin + track context"

**Time Estimate**:
- Previous (just plugin list): 10 hours
- Updated (with track info): **15-20 hours**

---

## 📊 DATA MODEL CHANGES NEEDED

### Current Plugin Reporter Model:

```swift
// Current: Simple playlist
struct Playlist {
    let name: String
    let plugins: [String]  // Just plugin names
}
```

### New Model for DAW Playlists:

```swift
// Enhanced: Playlist with track context
struct DAWPlaylist {
    let name: String                    // "My Epic Song"
    let sourceFile: URL                 // Path to .als file
    let dateImported: Date              // When imported
    let entries: [DAWPlaylistEntry]     // Detailed entries
}

struct DAWPlaylistEntry {
    let pluginName: String              // "Valhalla Room"
    let pluginManufacturer: String      // "Valhalla DSP"
    let trackName: String               // "Drums"
    let trackIndex: Int                 // 0 (first track)
    let deviceIndex: Int                // 1 (second device on track)
    let isInstalled: Bool               // true if found in scan
    let matchedPlugin: PluginItem?      // Link to actual plugin if found
}
```

---

## 🎨 UI DESIGN

### Playlist View Options:

**Option A: Grouped by Track (Recommended)**

```
Playlist: "My Epic Song"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Track 1: Drums (2 plugins)
  ✅ Valhalla Room                     [Show Details]
  ✅ FabFilter Pro-Q 3                 [Show Details]

📁 Track 2: Bass (2 plugins)
  ✅ Serum                             [Show Details]
  ❌ iZotope Ozone (Not Installed)    [Find Similar]

📁 Track 3: Vocals (2 plugins)
  ✅ Melodyne                          [Show Details]
  ✅ Waves CLA-2A                      [Show Details]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary: 6 plugins total, 5 installed, 1 missing
```

**Option B: Flat List with Track Tags**

```
Playlist: "My Epic Song"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Valhalla Room              Track: Drums      ⭐⭐⭐⭐⭐
✅ FabFilter Pro-Q 3          Track: Drums      ⭐⭐⭐⭐⭐
✅ Serum                      Track: Bass       ⭐⭐⭐⭐⭐
❌ iZotope Ozone              Track: Bass       (Not Installed)
✅ Melodyne                   Track: Vocals     ⭐⭐⭐⭐⭐
✅ Waves CLA-2A               Track: Vocals     ⭐⭐⭐⭐

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary: 6 plugins total, 5 installed, 1 missing
```

**Option C: Hybrid (Most Flexible)**

```
Playlist: "My Epic Song"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

View: [By Track ▼] [Group By] [Sort By]

🎹 Drums (2)
  • Valhalla Room              Reverb    ✅
  • FabFilter Pro-Q 3          EQ        ✅

🎸 Bass (2)
  • Serum                      Synth     ✅
  • iZotope Ozone              Master    ❌ Missing

🎤 Vocals (2)
  • Melodyne                   Pitch     ✅
  • Waves CLA-2A               Comp      ✅
```

---

## 🔧 IMPLEMENTATION DETAILS

### 1. Parsing Ableton Live XML

**Key XML Elements to Extract**:

```xml
<Ableton>
  <LiveSet>
    <Tracks>
      <AudioTrack Id="0">
        <Name>
          <EffectiveName Value="Drums" />
        </Name>
        <DeviceChain>
          <Devices>
            <PluginDevice Id="0">
              <PluginDesc>
                <VstPluginInfo>
                  <PlugName Value="ValhallaRoom" />
                  <PluginVendor Value="Valhalla DSP" />
                </VstPluginInfo>
              </PluginDesc>
            </PluginDevice>
            <PluginDevice Id="1">
              <PluginDesc>
                <VstPluginInfo>
                  <PlugName Value="FabFilter Pro-Q 3" />
                  <PluginVendor Value="FabFilter" />
                </VstPluginInfo>
              </PluginDesc>
            </PluginDevice>
          </Devices>
        </DeviceChain>
      </AudioTrack>

      <MidiTrack Id="1">
        <Name>
          <EffectiveName Value="Bass" />
        </Name>
        <!-- More plugins... -->
      </MidiTrack>
    </Tracks>
  </LiveSet>
</Ableton>
```

**What to Extract**:
1. ✅ Track name: `<EffectiveName Value="...">`
2. ✅ Track type: `AudioTrack` vs `MidiTrack` vs `ReturnTrack`
3. ✅ Plugin name: `<PlugName Value="...">`
4. ✅ Plugin vendor: `<PluginVendor Value="...">`
5. ✅ Plugin type: VST, VST3, AU (from `<VstPluginInfo>`, `<AuPluginInfo>`)

---

### 2. Enhanced Parser Code

```swift
class AbletonLiveParser {

    struct ParsedProject {
        let name: String
        let tracks: [ParsedTrack]
        let allPlugins: [String]  // Unique plugin names
        let totalPluginInstances: Int
    }

    struct ParsedTrack {
        let name: String
        let type: TrackType  // Audio, MIDI, Return, Master
        let index: Int
        let plugins: [ParsedPlugin]
    }

    struct ParsedPlugin {
        let name: String
        let vendor: String
        let format: PluginFormat  // VST, VST3, AU
        let deviceIndex: Int
    }

    enum TrackType: String {
        case audio = "AudioTrack"
        case midi = "MidiTrack"
        case `return` = "ReturnTrack"
        case master = "MasterTrack"
    }

    enum PluginFormat: String {
        case vst = "VST"
        case vst3 = "VST3"
        case au = "AU"
    }

    static func parseProject(url: URL) -> ParsedProject? {
        // 1. Decompress .als file
        guard let gzippedData = try? Data(contentsOf: url),
              let xmlData = decompress(gzippedData) else {
            return nil
        }

        // 2. Parse XML with enhanced parser
        let parser = EnhancedALSXMLParser()
        parser.parse(xmlData)

        // 3. Return structured data
        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            tracks: parser.tracks,
            allPlugins: Array(Set(parser.tracks.flatMap { $0.plugins.map { $0.name } })),
            totalPluginInstances: parser.tracks.reduce(0) { $0 + $1.plugins.count }
        )
    }
}

class EnhancedALSXMLParser: NSObject, XMLParserDelegate {
    var tracks: [AbletonLiveParser.ParsedTrack] = []

    private var currentTrackName = ""
    private var currentTrackType = ""
    private var currentTrackPlugins: [AbletonLiveParser.ParsedPlugin] = []
    private var currentPluginName = ""
    private var currentPluginVendor = ""
    private var currentPluginFormat = ""

    private var inTrack = false
    private var inPluginDevice = false
    private var trackIndex = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {

        switch elementName {
        case "AudioTrack", "MidiTrack", "ReturnTrack", "MasterTrack":
            inTrack = true
            currentTrackType = elementName
            currentTrackName = ""
            currentTrackPlugins = []

        case "EffectiveName":
            if inTrack, let name = attributeDict["Value"] {
                currentTrackName = name
            }

        case "PluginDevice":
            inPluginDevice = true

        case "PlugName":
            if inPluginDevice, let name = attributeDict["Value"] {
                currentPluginName = name
            }

        case "PluginVendor":
            if inPluginDevice, let vendor = attributeDict["Value"] {
                currentPluginVendor = vendor
            }

        case "VstPluginInfo":
            currentPluginFormat = "VST"

        case "Vst3PluginInfo":
            currentPluginFormat = "VST3"

        case "AuPluginInfo":
            currentPluginFormat = "AU"

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        switch elementName {
        case "PluginDevice":
            if inPluginDevice, !currentPluginName.isEmpty {
                let plugin = AbletonLiveParser.ParsedPlugin(
                    name: currentPluginName,
                    vendor: currentPluginVendor,
                    format: AbletonLiveParser.PluginFormat(rawValue: currentPluginFormat) ?? .vst,
                    deviceIndex: currentTrackPlugins.count
                )
                currentTrackPlugins.append(plugin)
            }
            inPluginDevice = false
            currentPluginName = ""
            currentPluginVendor = ""
            currentPluginFormat = ""

        case "AudioTrack", "MidiTrack", "ReturnTrack", "MasterTrack":
            if inTrack {
                let track = AbletonLiveParser.ParsedTrack(
                    name: currentTrackName.isEmpty ? "Track \(trackIndex + 1)" : currentTrackName,
                    type: AbletonLiveParser.TrackType(rawValue: currentTrackType) ?? .audio,
                    index: trackIndex,
                    plugins: currentTrackPlugins
                )
                tracks.append(track)
                trackIndex += 1
            }
            inTrack = false

        default:
            break
        }
    }
}
```

---

### 3. Creating DAW Playlist in Plugin Reporter

```swift
class DAWPlaylistManager {

    static func createFromAbletonProject(url: URL) -> DAWPlaylist? {
        // 1. Parse Ableton project
        guard let parsed = AbletonLiveParser.parseProject(url: url) else {
            return nil
        }

        // 2. Match plugins with installed ones
        var entries: [DAWPlaylistEntry] = []

        for track in parsed.tracks {
            for plugin in track.plugins {
                // Try to find plugin in PluginScanner
                let matchedPlugin = findInstalledPlugin(
                    name: plugin.name,
                    vendor: plugin.vendor
                )

                let entry = DAWPlaylistEntry(
                    pluginName: plugin.name,
                    pluginManufacturer: plugin.vendor,
                    trackName: track.name,
                    trackIndex: track.index,
                    deviceIndex: plugin.deviceIndex,
                    isInstalled: matchedPlugin != nil,
                    matchedPlugin: matchedPlugin
                )
                entries.append(entry)
            }
        }

        // 3. Create playlist
        let playlist = DAWPlaylist(
            name: parsed.name,
            sourceFile: url,
            dateImported: Date(),
            entries: entries
        )

        return playlist
    }

    private static func findInstalledPlugin(name: String, vendor: String) -> PluginItem? {
        let scanner = PluginScanner.shared

        // Try exact match first
        if let plugin = scanner.plugins.first(where: {
            $0.name.lowercased() == name.lowercased() &&
            $0.publisher.lowercased() == vendor.lowercased()
        }) {
            return plugin
        }

        // Try partial match
        if let plugin = scanner.plugins.first(where: {
            $0.name.lowercased().contains(name.lowercased()) ||
            name.lowercased().contains($0.name.lowercased())
        }) {
            return plugin
        }

        return nil
    }
}
```

---

## 📱 USER WORKFLOW

### Step-by-Step:

**1. User Action**:
```
File → Import → Ableton Live Project...
(or drag .als file to app)
```

**2. Parsing Progress**:
```
┌─────────────────────────────────────┐
│ Importing "My Epic Song.als"...    │
│                                     │
│ ████████████░░░░░░░░░░  60%        │
│                                     │
│ • Decompressing file...        ✓   │
│ • Parsing XML structure...     ✓   │
│ • Extracting tracks...         ✓   │
│ • Finding plugins...           ...  │
│ • Matching installed plugins...     │
└─────────────────────────────────────┘
```

**3. Import Summary**:
```
┌─────────────────────────────────────────────┐
│ Import Complete!                            │
│                                             │
│ Project: "My Epic Song"                     │
│ Tracks: 12                                  │
│ Plugins: 23 total                           │
│                                             │
│ ✅ Installed: 20 plugins                    │
│ ❌ Missing: 3 plugins                       │
│                                             │
│ Missing Plugins:                            │
│ • iZotope Ozone (Bass)                      │
│ • UAD LA-2A (Vocals)                        │
│ • Soundtoys Devil-Loc (Drums)               │
│                                             │
│ [View Playlist]  [Export Missing List]      │
└─────────────────────────────────────────────┘
```

**4. Playlist View**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Playlist: My Epic Song
Imported: October 17, 2025
Source: ~/Music/Ableton/My Epic Song.als

View: [By Track ▼]  Search: [________]  [⚙️]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎹 Drums (4 plugins)
├─ ✅ Native Instruments Battery 4
├─ ✅ Valhalla Room
├─ ✅ FabFilter Pro-Q 3
└─ ❌ Soundtoys Devil-Loc (Not Installed)

🎸 Bass (3 plugins)
├─ ✅ Serum
├─ ✅ Waves CLA-76
└─ ❌ iZotope Ozone (Not Installed)

🎤 Vocals (5 plugins)
├─ ✅ Auto-Tune Pro
├─ ✅ Melodyne
├─ ✅ Waves CLA-2A
├─ ❌ UAD LA-2A (Not Installed)
└─ ✅ FabFilter Pro-R

[Show All Tracks]  [Export]  [Find Missing]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## ⏱️ UPDATED TIME ESTIMATE

### Complete Implementation:

**Phase 1: Basic Parsing** (5-7 hours)
- Decompress .als files
- Parse XML structure
- Extract track names
- Extract plugin names + vendors

**Phase 2: Data Model** (3-4 hours)
- DAWPlaylist struct
- DAWPlaylistEntry struct
- Plugin matching logic
- Track association

**Phase 3: UI Implementation** (4-5 hours)
- Import dialog
- Progress indicator
- Playlist view (grouped by track)
- Missing plugins alert

**Phase 4: Polish** (3-4 hours)
- Handle edge cases
- Error messages
- Export playlist
- "Find Missing" feature

**Total: 15-20 hours** (realistic: 18 hours)

---

## 🎯 FINAL DIFFICULTY RATING

### With Track Context:

**Difficulty**: ⭐⭐⭐⭐ (4/10) - **EASY-MEDIUM**

**Breakdown**:
- XML parsing: ⭐⭐ (Easy - you know this)
- Data modeling: ⭐⭐⭐ (Medium - new structs)
- Plugin matching: ⭐⭐⭐⭐ (Medium - fuzzy matching)
- UI design: ⭐⭐⭐ (Medium - grouping/sorting)

**Skills Required**:
- ✅ Swift (you have this)
- ✅ XML parsing (you know this)
- ✅ SwiftUI (you have this)
- ⚠️ Fuzzy string matching (new, but easy)
- ✅ File I/O (you have this)

---

## 💡 FEATURE ENHANCEMENTS

### Future Ideas:

**v1.2.1 - Enhanced Matching**:
- Fuzzy search for plugin names
- "Did you mean?" suggestions
- Auto-download missing plugins (link to vendors)

**v1.2.2 - Export Features**:
- Export missing plugins list
- Share playlist with other users
- Generate "shopping list" for missing plugins

**v1.3 - Time-Based Analysis**:
- "Plugins I used most in 2024"
- "Most used plugin on vocals"
- Track-based statistics

---

## ✅ CLARIFICATION SUMMARY

### Yes, Your Feature Will:

✅ Parse Ableton Live project files (.als)
✅ Extract ALL plugins used in the project
✅ Extract track names (Drums, Bass, Vocals, etc.)
✅ Associate each plugin with its track
✅ Create playlist named after Live project
✅ Show which plugins are installed
✅ Show which plugins are missing
✅ Group plugins by track in the UI
✅ Allow clicking to see plugin details
✅ Export the playlist

### Example Output:

```
Playlist: "My Epic Song" (from My Epic Song.als)

Track: Drums
  • Valhalla Room ✅
  • FabFilter Pro-Q 3 ✅

Track: Bass
  • Serum ✅
  • iZotope Ozone ❌ Not Installed

Track: Vocals
  • Melodyne ✅
  • Waves CLA-2A ✅
```

**Is this what you wanted?** ✅ Yes!

---

**Difficulty**: 4/10
**Time**: 18 hours
**Recommendation**: ✅ **Great feature for v1.2!**
