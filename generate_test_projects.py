#!/usr/bin/env python3
"""
Generate Practice Project Files for ALL DAW Parsers
Creates test projects with 20 tracks each containing 5 real + 15 fictional plugins
"""

import os
import random
import uuid
from pathlib import Path

# Output directory
TEST_DIR = Path.home() / "Desktop" / "DAW_Test_Projects"
TEST_DIR.mkdir(exist_ok=True)

# Real plugins (5 - from user's system)
REAL_PLUGINS = [
    "Abbey Road RS127 Box",
    "Abbey Road RS127 Rack",
    "Abbey Road RS135",
    "FabFilter Pro-Q 3",
    "Valhalla VintageVerb"
]

# Fictional plugins (15 - creative but realistic names)
FAKE_PLUGINS = [
    "Quantum Reverb Ultra",
    "Stellar Compressor Pro",
    "Nebula EQ Master",
    "Crystal Delay Designer",
    "Phoenix Saturator",
    "Atlantis Channel Strip",
    "Orion Multiband Limiter",
    "Eclipse Transient Shaper",
    "Aurora Spectral Filter",
    "Horizon De-Esser Plus",
    "Titan Bass Enhancer",
    "Velocity Dynamics Pro",
    "Infinity Chorus Ensemble",
    "Gravity Sidechain Master",
    "Pulse Width Modulator"
]

# Track names
TRACK_NAMES = [
    "Kick Drum",
    "Snare Top",
    "Hi-Hats",
    "Bass Guitar DI",
    "Lead Vocal",
    "Background Vocals",
    "Acoustic Guitar L",
    "Acoustic Guitar R",
    "Electric Piano",
    "Synth Pad",
    "Strings",
    "Brass Section",
    "Lead Synth",
    "Sub Bass",
    "Percussion Loop",
    "Ambient FX",
    "Crash Cymbals",
    "Tom Fills",
    "Bass Synth",
    "Reverb Return"
]

def get_random_plugins():
    """Get 20 plugins: 5 real + 15 fake, shuffled"""
    all_plugins = REAL_PLUGINS.copy() + random.sample(FAKE_PLUGINS, 15)
    random.shuffle(all_plugins)
    return all_plugins

print("🎵 Generating DAW Test Project Files for ALL Parsers...")
print(f"📁 Output directory: {TEST_DIR}\n")

# ====================================================================================
# 1. LOGIC PRO (.logicx)
# ====================================================================================
print("Creating Logic Pro test project...")
logic_dir = TEST_DIR / "Test Logic Pro Import.logicx"
logic_dir.mkdir(exist_ok=True)
(logic_dir / "Alternatives").mkdir(exist_ok=True)
(logic_dir / "Resources").mkdir(exist_ok=True)

with open(logic_dir / "projectData", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <string>11.0</string>
    <key>Tracks</key>
    <array>
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        f.write(f"""        <dict>
            <key>Name</key>
            <string>{track_name}</string>
            <key>Plugins</key>
            <array>
""")
        for plugin in plugins:
            f.write(f"""                <dict>
                    <key>Name</key>
                    <string>{plugin}</string>
                    <key>Manufacturer</key>
                    <string>Test Vendor</string>
                    <key>type</key>
                    <string>aufx</string>
                </dict>
""")
        f.write("""            </array>
        </dict>
""")
    f.write("""    </array>
</dict>
</plist>
""")
print("✅ Created: Test Logic Pro Import.logicx")

# ====================================================================================
# 2. GARAGEBAND (.band)
# ====================================================================================
print("Creating GarageBand test project...")
garage_dir = TEST_DIR / "Test GarageBand Import.band"
garage_dir.mkdir(exist_ok=True)
(garage_dir / "Alternatives").mkdir(exist_ok=True)
(garage_dir / "Media").mkdir(exist_ok=True)

with open(garage_dir / "projectData", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <string>10.4</string>
    <key>Tracks</key>
    <array>
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        f.write(f"""        <dict>
            <key>Name</key>
            <string>{track_name}</string>
            <key>Plugins</key>
            <array>
""")
        for plugin in plugins:
            f.write(f"""                <dict>
                    <key>Name</key>
                    <string>{plugin}</string>
                    <key>type</key>
                    <string>aufx</string>
                </dict>
""")
        f.write("""            </array>
        </dict>
""")
    f.write("""    </array>
</dict>
</plist>
""")
print("✅ Created: Test GarageBand Import.band")

# ====================================================================================
# 3. MAINSTAGE (.concert)
# ====================================================================================
print("Creating MainStage test project...")
mainstage_dir = TEST_DIR / "Test MainStage Import.concert"
mainstage_dir.mkdir(exist_ok=True)
(mainstage_dir / "Alternatives").mkdir(exist_ok=True)

with open(mainstage_dir / "projectData", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <string>3.6</string>
    <key>patches</key>
    <array>
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        f.write(f"""        <dict>
            <key>Name</key>
            <string>{track_name}</string>
            <key>channelStrips</key>
            <array>
                <dict>
                    <key>Plugins</key>
                    <array>
""")
        for plugin in plugins:
            f.write(f"""                        <dict>
                            <key>Name</key>
                            <string>{plugin}</string>
                        </dict>
""")
        f.write("""                    </array>
                </dict>
            </array>
        </dict>
""")
    f.write("""    </array>
</dict>
</plist>
""")
print("✅ Created: Test MainStage Import.concert")

# ====================================================================================
# 4. ABLETON LIVE (.als)
# ====================================================================================
print("Creating Ableton Live test project...")
with open(TEST_DIR / "Test Ableton Import.als", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<Ableton MajorVersion="5" MinorVersion="11" SchemaChangeCount="3">
    <LiveSet>
        <Tracks>
""")
    for i, track_name in enumerate(TRACK_NAMES):
        plugins = get_random_plugins()
        f.write(f"""            <AudioTrack Id="{i}">
                <Name>
                    <EffectiveName Value="{track_name}" />
                </Name>
                <DeviceChain>
                    <DeviceChain>
                        <Devices>
""")
        for plugin in plugins:
            f.write(f"""                            <PluginDevice Id="{random.randint(1000, 9999)}">
                                <PluginDesc>
                                    <Vst3PluginInfo>
                                        <Name Value="{plugin}" />
                                    </Vst3PluginInfo>
                                </PluginDesc>
                            </PluginDevice>
""")
        f.write("""                        </Devices>
                    </DeviceChain>
                </DeviceChain>
            </AudioTrack>
""")
    f.write("""        </Tracks>
    </LiveSet>
</Ableton>
""")
print("✅ Created: Test Ableton Import.als")

# ====================================================================================
# 5. STUDIO ONE (.song)
# ====================================================================================
print("Creating Studio One test project...")
with open(TEST_DIR / "Test Studio One Import.song", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<Song version="5.0">
    <Tracks>
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        f.write(f"""        <Track name="{track_name}" type="Audio">
            <Devices>
""")
        for plugin in plugins:
            f.write(f"""                <Device type="VST3" name="{plugin}" />
""")
        f.write("""            </Devices>
        </Track>
""")
    f.write("""    </Tracks>
</Song>
""")
print("✅ Created: Test Studio One Import.song")

# ====================================================================================
# 6. CUBASE (.cpr)
# ====================================================================================
print("Creating Cubase test project...")
with open(TEST_DIR / "Test Cubase Import.cpr", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<Cubase version="12.0">
    <Project>
        <Tracks>
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        f.write(f"""            <Track type="Audio" name="{track_name}">
                <Inserts>
""")
        for plugin in plugins:
            f.write(f"""                    <VSTPlugin name="{plugin}" />
""")
        f.write("""                </Inserts>
            </Track>
""")
    f.write("""        </Tracks>
    </Project>
</Cubase>
""")
print("✅ Created: Test Cubase Import.cpr")

# ====================================================================================
# 7. REAPER (.rpp)
# ====================================================================================
print("Creating Reaper test project...")
with open(TEST_DIR / "Test Reaper Import.rpp", "w") as f:
    f.write("""<REAPER_PROJECT 0.1 "6.0"
  RIPPLE 0
  GROUPOVERRIDE 0 0 0
  AUTOXFADE 1
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        track_id = str(uuid.uuid4()).upper()
        f.write(f"""  <TRACK {{{track_id}}}
    NAME "{track_name}"
    TRACKHEIGHT 0 0 0 0
""")
        for plugin in plugins:
            f.write(f"""    <VST "VST3: {plugin} (Test Vendor)" "{plugin}.vst3"
      <VST_DATA>
      </VST_DATA>
    >
""")
        f.write("""  >
""")
    f.write(""">
""")
print("✅ Created: Test Reaper Import.rpp")

# ====================================================================================
# 8. PRO TOOLS (.ptx)
# ====================================================================================
print("Creating Pro Tools test project...")
with open(TEST_DIR / "Test Pro Tools Import.ptx", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<Session version="2024.3">
    <Tracks>
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        f.write(f"""        <Track type="Audio" name="{track_name}">
            <Plugins>
""")
        for plugin in plugins:
            f.write(f"""                <Plugin type="AAX" name="{plugin}" />
""")
        f.write("""            </Plugins>
        </Track>
""")
    f.write("""    </Tracks>
</Session>
""")
print("✅ Created: Test Pro Tools Import.ptx")

# ====================================================================================
# 9. BITWIG (.bwproject)
# ====================================================================================
print("Creating Bitwig test project...")
# Bitwig parser extracts strings from binary data looking for .vst3 paths
# We'll create a binary-like file with embedded plugin strings
with open(TEST_DIR / "Test Bitwig Import.bwproject", "wb") as f:
    # Write a binary header (simulating Bitwig format)
    f.write(b"BITWIG\x00\x00\x00\x05\x00\x00\x00")

    # Embed plugin paths as null-terminated strings (what parser looks for)
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        # Write track name
        f.write(track_name.encode('utf-8') + b'\x00')

        # Write plugin paths with .vst3 extension
        for plugin in plugins:
            # Create a fake VST3 path that parser can extract
            plugin_path = f"/Library/Audio/Plug-Ins/VST3/{plugin}.vst3"
            f.write(plugin_path.encode('utf-8') + b'\x00')
            # Add some padding bytes (simulating binary data)
            f.write(b'\x00\x00\x00\x00')
print("✅ Created: Test Bitwig Import.bwproject")

# ====================================================================================
# 10. REASON (.reason)
# ====================================================================================
print("Creating Reason test project...")
# Reason parser extracts strings from binary/compressed data
# Similar to Bitwig, embed plugin strings as binary data
with open(TEST_DIR / "Test Reason Import.reason", "wb") as f:
    # Write header
    f.write(b"REASON\x00\x00\x00\x12\x00\x00\x00")

    # Embed plugin strings
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        # Write track name
        f.write(track_name.encode('utf-8') + b'\x00')

        # Write plugin paths
        for plugin in plugins:
            plugin_path = f"/Library/Audio/Plug-Ins/VST3/{plugin}.vst3"
            f.write(plugin_path.encode('utf-8') + b'\x00')
            # Add padding
            f.write(b'\x00\x00\x00\x00')
print("✅ Created: Test Reason Import.reason")

# ====================================================================================
# 11. DIGITAL PERFORMER (.motu)
# ====================================================================================
print("Creating Digital Performer test project...")
# Digital Performer parser extracts strings from binary data
# Must contain "Digital Performer" or "MOTU" string
with open(TEST_DIR / "Test Digital Performer Import.motu", "wb") as f:
    # Write header identifying as DP file
    f.write(b"MOTU\x00\x00\x00\x00")
    f.write(b"Digital Performer\x00")
    f.write(b"Version 11.0\x00")

    # Embed plugin strings
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        # Write track name
        f.write(b"Track\x00")
        f.write(track_name.encode('utf-8') + b'\x00')

        # Write plugin paths
        for plugin in plugins:
            plugin_path = f"/Library/Audio/Plug-Ins/VST3/{plugin}.vst3"
            f.write(plugin_path.encode('utf-8') + b'\x00')
            # Add padding
            f.write(b'\x00\x00')
print("✅ Created: Test Digital Performer Import.motu")

# ====================================================================================
# 12. FL STUDIO (.flp is binary format)
# ====================================================================================
print("Creating FL Studio test project...")
# FL Studio parser extracts strings from binary data
# Must start with "FLhd" header
with open(TEST_DIR / "Test FL Studio Import.flp", "wb") as f:
    # Write FL Studio header
    f.write(b"FLhd")
    f.write(b"\x00\x00\x00\x00")
    f.write(b"FLdt")
    f.write(b"\x00\x00\x00\x00")

    # Embed plugin strings
    for i, track_name in enumerate(TRACK_NAMES):
        plugins = get_random_plugins()
        # Write track/channel name
        f.write(b"CHAN")
        f.write(track_name.encode('utf-8') + b'\x00')

        # Write plugin names as strings that parser can extract
        for plugin in plugins:
            # FL Studio stores VST paths
            plugin_path = f"/Library/Audio/Plug-Ins/VST3/{plugin}.vst3"
            f.write(plugin_path.encode('utf-8') + b'\x00')
            # Also write plain plugin name
            f.write(plugin.encode('utf-8') + b'\x00')
            # Add padding
            f.write(b'\x00\x00')
print("✅ Created: Test FL Studio Import.flp")

# ====================================================================================
# 13. RENOISE (.xrns is ZIP - create XML)
# ====================================================================================
print("Creating Renoise test project...")
with open(TEST_DIR / "Test Renoise Import.xrns", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<RenoiseSong doc_version="58">
    <Tracks>
""")
    for i, track_name in enumerate(TRACK_NAMES):
        plugins = get_random_plugins()
        f.write(f"""        <SequencerTrack type="SequencerTrack">
            <Name>{track_name}</Name>
            <Devices>
""")
        for plugin in plugins:
            f.write(f"""                <PluginDevice type="VSTPluginDevice">
                    <PluginIdentifier>{plugin}</PluginIdentifier>
                </PluginDevice>
""")
        f.write("""            </Devices>
        </SequencerTrack>
""")
    f.write("""    </Tracks>
</RenoiseSong>
""")
print("✅ Created: Test Renoise Import.xrns")

# ====================================================================================
# 14. ARDOUR (.ardour)
# ====================================================================================
print("Creating Ardour test project...")
with open(TEST_DIR / "Test Ardour Import.ardour", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<Session version="7.0">
    <Routes>
""")
    for i, track_name in enumerate(TRACK_NAMES):
        plugins = get_random_plugins()
        f.write(f"""        <Route id="{i+1000}" name="{track_name}" default-type="audio">
""")
        for plugin in plugins:
            f.write(f"""            <Processor type="lv2" name="{plugin}" />
""")
        f.write("""        </Route>
""")
    f.write("""    </Routes>
</Session>
""")
print("✅ Created: Test Ardour Import.ardour")

# ====================================================================================
# 15. MIXBUS (.mixbus)
# ====================================================================================
print("Creating Mixbus test project...")
with open(TEST_DIR / "Test Mixbus Import.mixbus", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<Session version="7.0" name="Mixbus">
    <Routes>
""")
    for i, track_name in enumerate(TRACK_NAMES):
        plugins = get_random_plugins()
        f.write(f"""        <Route id="{i+2000}" name="{track_name}" default-type="audio">
""")
        for plugin in plugins:
            f.write(f"""            <Processor type="lv2" name="{plugin}" />
""")
        f.write("""        </Route>
""")
    f.write("""    </Routes>
</Session>
""")
print("✅ Created: Test Mixbus Import.mixbus")

# ====================================================================================
# 16. TRACKTION (.tracktionedit)
# ====================================================================================
print("Creating Tracktion test project...")
with open(TEST_DIR / "Test Tracktion Import.tracktionedit", "w") as f:
    f.write("""<?xml version="1.0" encoding="UTF-8"?>
<TRACKTION version="9">
    <EDIT>
        <TRACK>
""")
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        f.write(f"""            <TRACK name="{track_name}">
                <PLUGIN>
""")
        for plugin in plugins:
            f.write(f"""                    <VSTPLUGIN name="{plugin}" />
""")
        f.write("""                </PLUGIN>
            </TRACK>
""")
    f.write("""        </TRACK>
    </EDIT>
</TRACKTION>
""")
print("✅ Created: Test Tracktion Import.tracktionedit")

# ====================================================================================
# 17. FAIRLIGHT (.drp - DaVinci Resolve Project)
# ====================================================================================
print("Creating Fairlight test project...")
# Fairlight parser extracts strings from binary database format
with open(TEST_DIR / "Test Fairlight Import.drp", "wb") as f:
    # Write header identifying as DaVinci/Fairlight project
    f.write(b"DaVinci\x00")
    f.write(b"Fairlight\x00")
    f.write(b"Version 18.0\x00")

    # Embed plugin strings
    for track_name in TRACK_NAMES:
        plugins = get_random_plugins()
        # Write track name
        f.write(b"AudioTrack\x00")
        f.write(track_name.encode('utf-8') + b'\x00')

        # Write plugin paths
        for plugin in plugins:
            plugin_path = f"/Library/Audio/Plug-Ins/VST3/{plugin}.vst3"
            f.write(plugin_path.encode('utf-8') + b'\x00')
            # Also write plain plugin name (parser looks for likely plugin names)
            f.write(plugin.encode('utf-8') + b'\x00')
            # Add padding
            f.write(b'\x00\x00')
print("✅ Created: Test Fairlight Import.drp")

# ====================================================================================
# SUMMARY
# ====================================================================================
print("\n" + "="*70)
print("✨ Test Project Generation Complete!")
print("="*70)
print(f"\n📁 Location: {TEST_DIR}\n")
print("📝 Files Created (17 DAW Parsers):")
print("   1.  Test Logic Pro Import.logicx")
print("   2.  Test GarageBand Import.band")
print("   3.  Test MainStage Import.concert")
print("   4.  Test Ableton Import.als")
print("   5.  Test Studio One Import.song")
print("   6.  Test Cubase Import.cpr")
print("   7.  Test Reaper Import.rpp")
print("   8.  Test Pro Tools Import.ptx")
print("   9.  Test Bitwig Import.bwproject")
print("   10. Test Reason Import.reason")
print("   11. Test Digital Performer Import.motu")
print("   12. Test FL Studio Import.flp")
print("   13. Test Renoise Import.xrns")
print("   14. Test Ardour Import.ardour")
print("   15. Test Mixbus Import.mixbus")
print("   16. Test Tracktion Import.tracktionedit")
print("   17. Test Fairlight Import.drp")
print("\n🎯 Each project contains:")
print("   • 20 tracks with realistic names")
print("   • 20 plugins per track (400 total)")
print("   • 5 REAL plugins from your system (100 instances)")
print("   • 15 FICTIONAL plugins (300 instances)")
print("\n💡 Test by importing into Plugin Reporter's DAW Import feature")
print()

# ====================================================================================
# POST-PROCESSING: Fix special formats
# ====================================================================================
print("\n🔧 Post-processing special formats...")

# Fix Ableton - needs gzip compression
import gzip
als_file = TEST_DIR / "Test Ableton Import.als"
with open(als_file, 'rb') as f:
    xml_data = f.read()
with gzip.open(als_file, 'wb') as f:
    f.write(xml_data)
print("✅ Compressed Ableton file with gzip")

# Fix Renoise - needs ZIP archive with Song.xml
import zipfile
xrns_file = TEST_DIR / "Test Renoise Import.xrns"
with open(xrns_file, 'rb') as f:
    xml_content = f.read()
with zipfile.ZipFile(xrns_file, 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr('Song.xml', xml_content)
print("✅ Created ZIP archive for Renoise")

# Fix Studio One - needs ZIP archive with song.xml
song_file = TEST_DIR / "Test Studio One Import.song"
with open(song_file, 'rb') as f:
    xml_content = f.read()
with zipfile.ZipFile(song_file, 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr('song.xml', xml_content)
print("✅ Created ZIP archive for Studio One")

print("\n" + "="*70)
print("✨ All formats processed and ready for testing!")
print("="*70)

