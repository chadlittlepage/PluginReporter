# Reason Studios Parser - Xcode Integration Guide

## Overview
This guide walks you through adding the **Reason Studios Parser** to your Plugin Reporter Xcode project, enabling DAW import support for Reason project files (`.reason` and `.rns`).

## Files Created
- ✅ `ReasonParser.swift` - Main parser implementation
- ✅ `DAWParserProtocol.swift` - Updated registry (already modified)
- ✅ `DAWPlaylistManager.swift` - Added `.reason` to DAWType enum (already modified)

---

## Step-by-Step Integration

### Step 1: Add ReasonParser.swift to Xcode Project

1. Open `PluginReporter.xcodeproj` in Xcode
2. In the Project Navigator, locate the DAW parser group (with other parsers)
3. **Right-click** → **Add Files to "Plugin Reporter"...**
4. Select: `/Users/chadlittlepage/Documents/APPs/PluginReporter/ReasonParser.swift`
5. Ensure these options are checked:
   - ✅ **Copy items if needed**
   - ✅ **Create groups**
   - ✅ **Add to targets: Plugin Reporter**
6. Click **Add**

### Step 2: Update DAWImportView.swift

Add Reason Studios support to the import dialog:

**File:** `DAWImportView.swift`

**Find (around line 38):**
```swift
Text("Import plugins from Ableton (.als), Logic Pro (.logic/.logicx), Pro Tools (.txt), or Bitwig (.bwproject)")
```

**Replace with:**
```swift
Text("Import plugins from Ableton (.als), Logic Pro (.logic/.logicx), Reason (.reason/.rns), Pro Tools (.txt), or Bitwig (.bwproject)")
```

**Find (around line 119-127):**
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

**Replace with:**
```swift
panel.message = "Choose a DAW project file (.als for Ableton, .logic/.logicx for Logic Pro, .reason/.rns for Reason, .txt for Pro Tools, .bwproject for Bitwig)"
panel.allowedContentTypes = [
    .init(filenameExtension: "als"),
    .init(filenameExtension: "logic"),
    .init(filenameExtension: "logicx"),
    .init(filenameExtension: "reason"),
    .init(filenameExtension: "rns"),
    .init(filenameExtension: "txt"),
    .init(filenameExtension: "bwproject")
].compactMap { $0 }
```

**Find (around line 165+):**
```swift
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

**Add case for Reason:**
```swift
var dawIcon: String {
    switch playlist.dawType {
    case .abletonLive: return "waveform"
    case .logicPro: return "music.quarternote.3"
    case .reason: return "line.3.crossed.swirl.circle.fill"
    case .proTools: return "waveform.path.ecg"
    case .bitwig: return "circle.hexagongrid.fill"
    default: return "music.note"
    }
}
```

### Step 3: Verify Registration (Already Done)

The parser is already registered in `DAWParserProtocol.swift:97`:

```swift
registerParser(ReasonParser.self)
```

✅ **No action needed** - this was done automatically.

---

## Testing the Implementation

### Test 1: Build the Project

1. Press **⌘B** (Product → Build)
2. Verify no compilation errors
3. Check Build Phases:
   - Select **Plugin Reporter** target
   - **Build Phases** → **Compile Sources**
   - Confirm `ReasonParser.swift` is listed

### Test 2: Test Reason Import

1. Run the app (**⌘R**)
2. Navigate to **DAW Import**
3. Click **"Select Project File"**
4. File picker should show `.reason` and `.rns` formats
5. Select a Reason project file
6. Verify:
   - ✅ Devices grouped into tracks (Reason Rack, VST Plugins, Rack Extensions)
   - ✅ Plugins detected and listed
   - ✅ Native Reason devices recognized
   - ✅ VST/VST3 plugins parsed
   - ✅ Rack Extensions identified

### Test 3: Verify Parser Registry

```swift
let registry = DAWParserRegistry.shared
print("📦 Supported DAWs: \(registry.supportedDAWs.map { $0.rawValue })")
print("📂 Supported Extensions: \(registry.supportedExtensions)")
```

Expected output:
```
📦 Supported DAWs: ["Ableton Live", "Pro Tools", "Bitwig", "Logic Pro", "Reason Studios"]
📂 Supported Extensions: ["als", "txt", "bwproject", "logic", "logicx", "reason", "rns"]
```

---

## Reason File Format Details

### Project Structure

Reason projects are **hybrid binary/XML** files:

```
MyProject.reason        ← Compressed binary + XML (Reason 12+)
MyOldProject.rns        ← Older format (Reason 1-11)
```

**Format characteristics:**
- Compressed with gzip
- Contains embedded XML chunks
- Binary device data
- Embedded patches and samples

### What the Parser Extracts

| Data | Method | Notes |
|------|--------|-------|
| **Native Devices** | String pattern matching | Thor, Malstrom, Subtractor, Kong, etc. |
| **VST Plugins** | `.vst` file path detection | VST2 format |
| **VST3 Plugins** | `.vst3` file path detection | VST3 format |
| **Rack Extensions** | `.re` identifier parsing | Reason's proprietary format |
| **Manufacturer** | Context search + name extraction | From nearby strings or plugin name |
| **Tempo** | BPM value extraction | Searches for "tempo" keywords |
| **Sample Rate** | Standard rates (44100, 48000, etc.) | Common audio rates |
| **Version** | Version string parsing | "Reason 12.5", etc. |

### Track Organization

Since Reason doesn't have traditional tracks in its file format, devices are grouped by type:

1. **Reason Rack** - Native Reason instruments and effects
2. **VST Plugins** - VST2 plugins
3. **VST3 Plugins** - VST3 plugins
4. **Rack Extensions** - Third-party Reason extensions

---

## Supported Device Types

### 1. Reason Native Instruments
Automatically recognized devices include:

**Synthesizers:**
- Thor Polysonic Synthesizer
- Malström Graintable Synthesizer
- Subtractor Analog Synthesizer
- Europa Shapeshifting Synthesizer
- Grain Sample Manipulator
- Monotone Bass Synthesizer
- Klang Tuned Percussion

**Samplers:**
- NN-19 Digital Sampler
- NN-XT Advanced Sampler
- Dr. Octo Rex Loop Player
- Kong Drum Designer
- Redrum Drum Computer

**New in Reason 12:**
- Algoritm FM Synthesizer
- Friktion Physical Modeling
- Scenic Hybrid Instrument
- Radical Piano

### 2. Reason Native Effects

**Reverbs & Delays:**
- RV7000 Advanced Reverb
- The Echo
- DDL-1 Digital Delay Line

**Distortion & Dynamics:**
- Scream 4 Sound Destruction Unit
- Alligator Pattern Gate
- Pulveriser Demolition
- COMP-01 Auto Compressor
- MClass Compressor
- MClass Maximizer

**Modulation & Filters:**
- Synchronous Modulation Effect
- Polar Dual Pitch Shifter
- Sweeper Modulation Effect
- PH-90 Phaser
- UN-16 Unison
- ECF-42 Envelope Controlled Filter
- CF-101 Chorus/Flanger

**EQ & Mastering:**
- MClass Equalizer
- MClass Stereo Imager
- PEQ-2 Two Band Parametric EQ

**Utilities:**
- Combinator (device container)
- Line Mixer 6:2
- Spider CV Merger & Splitter
- Spider Audio Merger & Splitter
- Matrix Pattern Sequencer
- BV512 Vocoder

### 3. VST Plugins

The parser detects VST2 and VST3 plugins by:
- File path patterns (`.vst`, `.vst3`)
- Manufacturer name extraction
- Plugin name parsing

### 4. Rack Extensions

Reason's proprietary plugin format:
- Identified by `.re` extension or `RackExtension` string
- Reverse domain notation parsing (e.g., `se.propellerheads.device`)
- Manufacturer extracted from domain name

---

## Known Manufacturers

The parser recognizes these manufacturers automatically:

- Reason Studios (formerly Propellerhead)
- FabFilter
- Waves
- Native Instruments
- Arturia
- iZotope
- Soundtoys
- Plugin Alliance
- UAD
- Slate Digital
- Valhalla DSP
- Xfer Records
- u-he
- Kilohearts
- And more...

---

## Troubleshooting

### Issue: "No devices found in Reason project"

**Cause:** File format not recognized or corrupted project

**Solutions:**
- Verify the file is a valid Reason project (open in Reason first)
- Try re-saving the project in Reason
- Older Reason versions (<7) may have different formats

### Issue: Native devices not recognized

**Cause:** Device name not in recognition list

**Solution:**
- Add the device name to `isReasonNativeDevice()` in `ReasonParser.swift:276`
- Common pattern: Look for exact device names in Reason's documentation

### Issue: VST plugins missing manufacturer

**Cause:** Manufacturer info not in file or not near plugin path

**Solution:**
- Parser attempts to extract from plugin name (e.g., "FabFilter Pro-Q" → "FabFilter")
- Falls back to "Unknown" if extraction fails
- This is expected for some plugins

### Issue: Rack Extensions show wrong manufacturer

**Cause:** Reverse domain notation parsing failed

**Example:**
```
se.propellerheads.RV7000
└── manufacturer: "propellerheads" (extracted correctly)

Bad format: MyPlugin.re
└── manufacturer: "Reason Studios" (fallback)
```

**Solution:**
- Well-formatted Rack Extensions should parse correctly
- Malformed names fall back to "Reason Studios"

---

## File Extensions Reference

| DAW | Extension(s) | Parser | Status |
|-----|-------------|---------|--------|
| **Ableton Live** | `.als` | `AbletonLiveParserV2` | ✅ Active |
| **Logic Pro** | `.logic`, `.logicx` | `LogicProParser` | ✅ Active |
| **Reason Studios** | `.reason`, `.rns` | `ReasonParser` | ✅ **NEW** |
| **Pro Tools** | `.txt` (Session Info) | `ProToolsTextParser` | ✅ Active |
| **Bitwig Studio** | `.bwproject` | `BitwigParser` | ✅ Active |
| **Cubase** | `.cpr` | Not implemented | ⏳ Planned |
| **Studio One** | `.song` | Not implemented | ⏳ Planned |

---

## Technical Implementation Details

### String Extraction Algorithm

Reason files are binary, so the parser:

1. **Reads raw file data**
2. **Extracts ASCII strings** (min 4 characters)
3. **Searches for patterns**:
   - Device names
   - File paths (`.vst`, `.vst3`, `.re`)
   - Metadata (tempo, version)
4. **Groups findings** into logical tracks

### Device Detection Strategy

```
┌─────────────────────────────────────┐
│   Read Reason Project File          │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Extract ASCII Strings              │
│   (min 4 chars, printable only)      │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Pattern Match Strings              │
│   • .vst3 → VST3 Plugin              │
│   • .vst → VST Plugin                │
│   • .re → Rack Extension             │
│   • "Thor" → Native Device           │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Extract Manufacturer               │
│   • Search nearby strings            │
│   • Parse from plugin name           │
│   • Default to "Reason Studios"      │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Group into Tracks                  │
│   • Reason Rack                      │
│   • VST Plugins                      │
│   • VST3 Plugins                     │
│   • Rack Extensions                  │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Return ParsedProject               │
└─────────────────────────────────────┘
```

### Deduplication

The parser uses a `Set<String>` to track seen devices:
- Key: `"\(device.name)_\(device.manufacturer)"`
- Prevents duplicates when device appears multiple times in binary data

---

## Advanced Usage

### Manual Parsing

```swift
import Foundation

let reasonURL = URL(fileURLWithPath: "/path/to/MyProject.reason")

do {
    let project = try ReasonParser.parseProject(url: reasonURL)

    print("📀 Project: \(project.name)")
    print("🎛️  Tracks: \(project.tracks.count)")

    for track in project.tracks {
        print("\n🎚️ \(track.name)")
        for plugin in track.plugins {
            print("   • \(plugin.name) by \(plugin.manufacturer) [\(plugin.format)]")
        }
    }

    if let tempo = project.tempo {
        print("\n⏱️  Tempo: \(tempo) BPM")
    }
} catch {
    print("❌ Parse failed: \(error)")
}
```

### Example Output

```
📀 Project: MyDanceTrack
🎛️  Tracks: 3

🎚️ Reason Rack
   • Thor by Reason Studios [VST3]
   • Malström by Reason Studios [VST3]
   • RV7000 by Reason Studios [VST3]
   • Scream 4 by Reason Studios [VST3]

🎚️ VST3 Plugins
   • Pro-Q 3 by FabFilter [VST3]
   • Serum by Xfer [VST3]

🎚️ Rack Extensions
   • A-List Acoustic Guitarist by Reason Studios [VST3]
   • Radical Piano by Reason Studios [VST3]

⏱️  Tempo: 128.0 BPM
```

---

## Adding New Native Devices

To support future Reason devices, update the device list:

**File:** `ReasonParser.swift:276`

```swift
private static func isReasonNativeDevice(_ string: String) -> Bool {
    let nativeDevices = [
        // Add new devices here
        "NewSynth", "NewEffect",

        // Existing devices...
        "Thor", "Malstrom", ...
    ]

    return nativeDevices.contains { string.contains($0) }
}
```

---

## Summary Checklist

- [ ] `ReasonParser.swift` added to Xcode project
- [ ] `DAWImportView.swift` updated with Reason support
- [ ] Build succeeds (**⌘B**)
- [ ] File picker shows `.reason` and `.rns`
- [ ] Tested with actual Reason project
- [ ] Parser registry includes "Reason Studios"
- [ ] Devices properly categorized into track groups
- [ ] Icons display correctly

---

## Version History

| Version | Reason Support | Notes |
|---------|---------------|-------|
| **1-11** | `.rns` | Older format, binary structure |
| **12+** | `.reason` | Modern format, improved compression |
| **13** | `.reason` | Enhanced plugin support (VST3) |

---

## Next Steps

Consider adding parsers for:
1. **Reaper** (`.rpp`) - Plain text, very easy to parse
2. **Cubase** (`.cpr`) - XML-based
3. **FL Studio** (`.flp`) - Binary, complex
4. **Studio One** (`.song`) - Compressed XML

---

**Last Updated:** 2025-10-18
**Version:** 1.0
**Author:** Claude Code
**Status:** Ready for Integration ✅
