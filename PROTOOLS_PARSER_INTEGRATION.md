# Pro Tools Parser Integration Guide

## Overview

The ProToolsParser provides support for parsing Pro Tools session files (.ptx). Due to the proprietary and encrypted nature of PTX files, this parser has specific limitations that users should understand.

## File Format Support

### 1. PTX Files (.ptx) - Limited Support ⚠️

**What are PTX files?**
- Binary session files used by Pro Tools 10+
- Proprietary format with XOR encryption
- Contains tracks, plugins, automation, and mixer settings

**What the parser CAN extract:**
- ✓ Session name
- ✓ Track names (basic extraction from binary)
- ✓ Sample rate (when detectable)
- ✓ Pro Tools version hint

**What the parser CANNOT extract:**
- ✗ Plugin information (encrypted in binary format)
- ✗ Detailed track settings
- ✗ Automation data
- ✗ Mixer/routing configuration

**Why the limitations?**
PTX files use proprietary encryption. The track names and basic metadata can be extracted as plain strings from the binary data, but plugin data is stored in encrypted binary structures that would require reverse engineering Pro Tools' encryption scheme.

### 2. Text Export Files (.txt) - Full Support ✅

**Recommended Method for Plugin Data**

Use Pro Tools' built-in export feature:

1. Open your session in Pro Tools
2. Go to **File → Export → Session Info as Text**
3. Save the .txt file
4. Import the .txt file in Plugin Reporter

**What the text export includes:**
- ✓ Complete session metadata
- ✓ All tracks with names and settings
- ✓ **All plugins with:**
  - Plugin name
  - Manufacturer
  - Version
  - Format (AAX Native, AU, VST, etc.)
  - Stereo/Mono configuration
  - Instance count
- ✓ Sample rate, bit depth, timecode
- ✓ Audio file count and clip information

## Usage Examples

### Example 1: Parsing PTX Binary File (Limited)

```swift
let ptxURL = URL(fileURLWithPath: "/path/to/session.ptx")

do {
    let result = try ProToolsParser.parseProject(url: ptxURL)

    print("Session: \(result.name)")
    print("Tracks: \(result.tracks.count)")

    for track in result.tracks {
        print("  - \(track.name)")
        // Note: track.plugins will be empty for .ptx files
    }
} catch {
    print("Error: \(error)")
}
```

**Expected Output:**
```
Session: My Song
Tracks: 3
  - Click 1
  - Inst 1
  - Master 1
```

### Example 2: Parsing Text Export (Complete)

```swift
let txtURL = URL(fileURLWithPath: "/path/to/session_info.txt")

do {
    let result = try ProToolsParser.parseProject(url: ptxURL)

    print("Session: \(result.name)")
    print("Sample Rate: \(result.sampleRate ?? 0) Hz")
    print("Tracks: \(result.tracks.count)")

    for track in result.tracks {
        print("\n  Track: \(track.name)")
        print("  Plugins: \(track.plugins.count)")

        for plugin in track.plugins {
            print("    • \(plugin.name)")
            print("      by \(plugin.manufacturer)")
            print("      Format: \(plugin.format)")
        }
    }
} catch {
    print("Error: \(error)")
}
```

**Expected Output:**
```
Session: My Song
Sample Rate: 48000 Hz
Tracks: 12

  Track: Vocals
  Plugins: 5
    • SSL 4K E
      by Waves
      Format: AAX Native
    • CLA-76
      by Waves
      Format: AAX Native
    ...
```

## Technical Details

### PTX Binary Format

The PTX format structure (based on open-source reverse engineering):

```
Header:
- Magic number: "0010111100101011"
- Version indicator
- XOR encryption key patterns

Data Sections:
- Tracks (encrypted)
- Regions (encrypted)
- Plugins (encrypted binary structures)
- Automation (encrypted)
- Mixer state (encrypted)
- Audio file references
```

The parser uses string extraction from the binary data to find track names, but plugin data requires decryption which is not implemented.

### Text Export Format

Example of Pro Tools text export format:

```
SESSION NAME: My Song
SAMPLE RATE: 48000
BIT DEPTH: 24-bit
# OF AUDIO TRACKS: 24
# OF AUDIO CLIPS: 156
# OF AUDIO FILES: 89

P L U G - I N S  L I S T I N G

MANUFACTURER  PLUG-IN NAME    VERSION     FORMAT      STEMS           INSTANCES
Waves         SSL 4K E        12.0        AAX Native  Mono/Mono       3
Waves         CLA-76          12.0        AAX Native  Stereo/Stereo   2
...

T R A C K  L I S T I N G

TRACK NAME: Vocals
COMMENTS: Lead vocal track
PLUG-INS: SSL 4K E (mono)	CLA-76 (stereo)	Pro-Q 3 (stereo)
...
```

## Comparison with Other DAW Parsers

| Feature | Pro Tools (.ptx) | Pro Tools (.txt) | Logic Pro | Ableton Live |
|---------|------------------|------------------|-----------|--------------|
| Format | Encrypted Binary | Plain Text | Package/Plist | Gzipped XML |
| Tracks | ⚠️  Limited | ✅ Full | ✅ Full | ✅ Full |
| Plugins | ❌ No | ✅ Full | ✅ Full | ✅ Full |
| Automation | ❌ No | ⚠️  Partial | ⚠️  Partial | ⚠️  Partial |
| Mixer | ❌ No | ⚠️  Partial | ⚠️  Partial | ⚠️  Partial |

## User Guidance

### Message to Display for PTX Files

When a user imports a .ptx file, show this guidance:

```
⚠️  Limited PTX Support

You've imported a Pro Tools binary session file (.ptx).

For complete plugin information, please:

1. Open your session in Pro Tools
2. Go to File → Export → Session Info as Text
3. Import the resulting .txt file

Why? PTX files are encrypted and don't expose plugin
data in a readable format. The text export contains
all session details including plugins, manufacturers,
versions, and formats.
```

## Implementation Notes

### String Extraction Logic

The parser extracts plain strings from the PTX binary by:

1. Scanning for consecutive printable ASCII characters (0x20-0x7E)
2. Filtering for likely track names:
   - 3-50 characters length
   - >= 80% alphanumeric + common punctuation
   - Contains at least one letter
   - No more than 2 consecutive special characters
   - Excludes system keywords (protools, media, session, etc.)
   - Excludes dates and paths

3. Counting string occurrences:
   - Track names typically appear 2-5 times in the file
   - Standard tracks (Click 1, Inst 1, Master 1) are recognized even with higher occurrence

### Known Limitations

1. **Track Detection is Heuristic**: May miss tracks with unusual names or include false positives
2. **No Plugin Data**: The binary plugin structures are encrypted
3. **No Routing Information**: Bus sends, routing, and I/O are encrypted
4. **No Automation**: Automation curves are in binary format
5. **No MIDI Data**: MIDI notes and CC are encoded

### Future Improvements

Potential enhancements if Pro Tools opens their format:

- [ ] Full PTX decryption (requires Avid documentation/cooperation)
- [ ] Plugin binary structure parsing
- [ ] Automation curve extraction
- [ ] MIDI event parsing
- [ ] Bus routing reconstruction

### References

- **ptformat library**: https://github.com/zamaudio/ptformat
  - Open-source C++ library for parsing PTX files
  - Handles decryption and basic track/region extraction
  - Does NOT parse plugins (they're in encrypted binary structures)

- **Library of Congress Format Documentation**:
  - https://www.loc.gov/preservation/digital/formats/fdd/fdd000639.shtml

## Testing

### Test Cases

1. **Standard Session**
   - File: "My Session.ptx"
   - Expected: Extract session name, basic track names
   - Plugins: None (show guidance message)

2. **Text Export**
   - File: "My Session_SessionInfo.txt"
   - Expected: Full session data with all plugins

3. **Large Session**
   - File: "Film Score.ptx" (500+ tracks)
   - Expected: Extract standard tracks, may miss user tracks

4. **Error Cases**
   - Corrupted PTX: Throw ParserError.invalidFileType
   - Empty file: Throw appropriate error
   - Wrong extension: Route to correct parser

## Support

For questions or issues:

1. Check if user is importing .ptx or .txt
2. If .ptx, guide to text export method
3. If .txt, troubleshoot text parser
4. For feature requests regarding fuller PTX support, explain encryption limitations

---

**Last Updated**: 2025-10-18
**Parser Version**: 1.0
**Status**: Production Ready (with documented limitations)
