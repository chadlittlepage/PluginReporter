#!/bin/bash

# Generate Practice Project Files for DAW Parsers
# Creates test projects with 20 tracks each containing 5 real + 15 fictional plugins

# Create test projects directory
TEST_DIR="$HOME/Desktop/DAW_Test_Projects"
mkdir -p "$TEST_DIR"

# Real plugins (5 - from user's screenshots)
REAL_PLUGINS=(
    "Abbey Road RS127 Box"
    "Abbey Road RS127 Rack"
    "Abbey Road RS135"
    "FabFilter Pro-Q 3"
    "Valhalla VintageVerb"
)

# Fictional plugins (15 - creative but realistic names)
FAKE_PLUGINS=(
    "Quantum Reverb Ultra"
    "Stellar Compressor Pro"
    "Nebula EQ Master"
    "Crystal Delay Designer"
    "Phoenix Saturator"
    "Atlantis Channel Strip"
    "Orion Multiband Limiter"
    "Eclipse Transient Shaper"
    "Aurora Spectral Filter"
    "Horizon De-Esser Plus"
    "Titan Bass Enhancer"
    "Velocity Dynamics Pro"
    "Infinity Chorus Ensemble"
    "Gravity Sidechain Master"
    "Pulse Width Modulator"
)

# Track names
TRACK_NAMES=(
    "Kick Drum"
    "Snare Top"
    "Hi-Hats"
    "Bass Guitar DI"
    "Lead Vocal"
    "Background Vocals"
    "Acoustic Guitar L"
    "Acoustic Guitar R"
    "Electric Piano"
    "Synth Pad"
    "Strings"
    "Brass Section"
    "Lead Synth"
    "Sub Bass"
    "Percussion Loop"
    "Ambient FX"
    "Crash Cymbals"
    "Tom Fills"
    "Bass Synth"
    "Reverb Return"
)

# Function to shuffle array and pick N items
pick_plugins() {
    local -n arr=$1
    local count=$2
    printf '%s\n' "${arr[@]}" | shuf | head -n "$count"
}

echo "🎵 Generating DAW Test Project Files..."
echo "📁 Output directory: $TEST_DIR"
echo ""

# =============================================================================
# LOGIC PRO (.logicx)
# =============================================================================
echo "Creating Logic Pro test project..."
LOGIC_DIR="$TEST_DIR/TestProject.logicx"
mkdir -p "$LOGIC_DIR/Alternatives"
mkdir -p "$LOGIC_DIR/Resources"

cat > "$LOGIC_DIR/projectData" << 'LOGIC_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <string>11.0</string>
    <key>tracks</key>
    <array>
LOGIC_EOF

# Add 20 tracks to Logic project
for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    # Pick 5 real + 15 fake plugins randomly
    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$LOGIC_DIR/projectData" << LOGIC_TRACK_EOF
        <dict>
            <key>name</key>
            <string>$TRACK</string>
            <key>plugins</key>
            <array>
LOGIC_TRACK_EOF

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$LOGIC_DIR/projectData" << LOGIC_PLUGIN_EOF
                <dict>
                    <key>name</key>
                    <string>$plugin</string>
                    <key>manufacturer</key>
                    <string>Test Vendor</string>
                    <key>type</key>
                    <string>aufx</string>
                </dict>
LOGIC_PLUGIN_EOF
    done

    cat >> "$LOGIC_DIR/projectData" << LOGIC_TRACK_END_EOF
            </array>
        </dict>
LOGIC_TRACK_END_EOF
done

cat >> "$LOGIC_DIR/projectData" << 'LOGIC_END_EOF'
    </array>
</dict>
</plist>
LOGIC_END_EOF

echo "✅ Created: TestProject.logicx"

# =============================================================================
# ABLETON LIVE (.als)
# =============================================================================
echo "Creating Ableton Live test project..."

cat > "$TEST_DIR/TestProject.als" << 'ALS_HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<Ableton MajorVersion="5" MinorVersion="11" SchemaChangeCount="3">
    <LiveSet>
        <Tracks>
ALS_HEADER

for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$TEST_DIR/TestProject.als" << ALS_TRACK_HEADER
            <AudioTrack Id="$i">
                <Name>
                    <EffectiveName Value="$TRACK" />
                </Name>
                <DeviceChain>
                    <DeviceChain>
                        <Devices>
ALS_TRACK_HEADER

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$TEST_DIR/TestProject.als" << ALS_PLUGIN
                            <PluginDevice Id="$RANDOM">
                                <PluginDesc>
                                    <VstPluginInfo>
                                        <PlugName Value="$plugin" />
                                    </VstPluginInfo>
                                </PluginDesc>
                            </PluginDevice>
ALS_PLUGIN
    done

    cat >> "$TEST_DIR/TestProject.als" << ALS_TRACK_END
                        </Devices>
                    </DeviceChain>
                </DeviceChain>
            </AudioTrack>
ALS_TRACK_END
done

cat >> "$TEST_DIR/TestProject.als" << 'ALS_FOOTER'
        </Tracks>
    </LiveSet>
</Ableton>
ALS_FOOTER

echo "✅ Created: TestProject.als"

# =============================================================================
# STUDIO ONE (.song)
# =============================================================================
echo "Creating Studio One test project..."

cat > "$TEST_DIR/TestProject.song" << 'SONG_HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<Song version="5.0">
    <Tracks>
SONG_HEADER

for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$TEST_DIR/TestProject.song" << SONG_TRACK_HEADER
        <Track name="$TRACK" type="Audio">
            <Devices>
SONG_TRACK_HEADER

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$TEST_DIR/TestProject.song" << SONG_PLUGIN
                <Device type="VST3" name="$plugin" />
SONG_PLUGIN
    done

    cat >> "$TEST_DIR/TestProject.song" << SONG_TRACK_END
            </Devices>
        </Track>
SONG_TRACK_END
done

cat >> "$TEST_DIR/TestProject.song" << 'SONG_FOOTER'
    </Tracks>
</Song>
SONG_FOOTER

echo "✅ Created: TestProject.song"

# =============================================================================
# CUBASE (.cpr)
# =============================================================================
echo "Creating Cubase test project..."

cat > "$TEST_DIR/TestProject.cpr" << 'CPR_HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<Cubase version="12.0">
    <Project>
        <Tracks>
CPR_HEADER

for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$TEST_DIR/TestProject.cpr" << CPR_TRACK_HEADER
            <Track type="Audio" name="$TRACK">
                <Inserts>
CPR_TRACK_HEADER

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$TEST_DIR/TestProject.cpr" << CPR_PLUGIN
                    <Vst3Plugin name="$plugin" />
CPR_PLUGIN
    done

    cat >> "$TEST_DIR/TestProject.cpr" << CPR_TRACK_END
                </Inserts>
            </Track>
CPR_TRACK_END
done

cat >> "$TEST_DIR/TestProject.cpr" << 'CPR_FOOTER'
        </Tracks>
    </Project>
</Cubase>
CPR_FOOTER

echo "✅ Created: TestProject.cpr"

# =============================================================================
# REAPER (.rpp)
# =============================================================================
echo "Creating Reaper test project..."

cat > "$TEST_DIR/TestProject.rpp" << 'RPP_HEADER'
<REAPER_PROJECT 0.1 "6.0"
  RIPPLE 0
  GROUPOVERRIDE 0 0 0
  AUTOXFADE 1
RPP_HEADER

for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$TEST_DIR/TestProject.rpp" << RPP_TRACK_HEADER
  <TRACK {$(uuidgen)}
    NAME "$TRACK"
    TRACKHEIGHT 0 0 0 0
RPP_TRACK_HEADER

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$TEST_DIR/TestProject.rpp" << RPP_PLUGIN
    <VST "VST3: $plugin (Test Vendor)" "$plugin.vst3"
      <VST_DATA>
      </VST_DATA>
    >
RPP_PLUGIN
    done

    cat >> "$TEST_DIR/TestProject.rpp" << RPP_TRACK_END
  >
RPP_TRACK_END
done

cat >> "$TEST_DIR/TestProject.rpp" << 'RPP_FOOTER'
>
RPP_FOOTER

echo "✅ Created: TestProject.rpp"

# =============================================================================
# PRO TOOLS (.ptx)
# =============================================================================
echo "Creating Pro Tools test project..."

cat > "$TEST_DIR/TestProject.ptx" << 'PTX_HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<Session version="2024.3">
    <Tracks>
PTX_HEADER

for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$TEST_DIR/TestProject.ptx" << PTX_TRACK_HEADER
        <Track type="Audio" name="$TRACK">
            <Plugins>
PTX_TRACK_HEADER

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$TEST_DIR/TestProject.ptx" << PTX_PLUGIN
                <Plugin type="AAX" name="$plugin" />
PTX_PLUGIN
    done

    cat >> "$TEST_DIR/TestProject.ptx" << PTX_TRACK_END
            </Plugins>
        </Track>
PTX_TRACK_END
done

cat >> "$TEST_DIR/TestProject.ptx" << 'PTX_FOOTER'
    </Tracks>
</Session>
PTX_FOOTER

echo "✅ Created: TestProject.ptx"

# =============================================================================
# BITWIG (.bwproject)
# =============================================================================
echo "Creating Bitwig test project..."

cat > "$TEST_DIR/TestProject.bwproject" << 'BITWIG_HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<BitwigProject version="5.0">
    <Tracks>
BITWIG_HEADER

for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$TEST_DIR/TestProject.bwproject" << BITWIG_TRACK_HEADER
        <Track name="$TRACK" type="audio">
            <DeviceChain>
BITWIG_TRACK_HEADER

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$TEST_DIR/TestProject.bwproject" << BITWIG_PLUGIN
                <Vst3Device name="$plugin" />
BITWIG_PLUGIN
    done

    cat >> "$TEST_DIR/TestProject.bwproject" << BITWIG_TRACK_END
            </DeviceChain>
        </Track>
BITWIG_TRACK_END
done

cat >> "$TEST_DIR/TestProject.bwproject" << 'BITWIG_FOOTER'
    </Tracks>
</BitwigProject>
BITWIG_FOOTER

echo "✅ Created: TestProject.bwproject"

# =============================================================================
# FL STUDIO (.flp is binary, create text session file)
# =============================================================================
echo "Creating FL Studio test project..."

cat > "$TEST_DIR/TestProject_FL.txt" << 'FL_HEADER'
FL Studio Session Export
Version: 21.0
Tracks:
FL_HEADER

for i in {0..19}; do
    TRACK="${TRACK_NAMES[$i]}"

    ALL_PLUGINS=()
    while IFS= read -r plugin; do
        ALL_PLUGINS+=("$plugin")
    done < <(pick_plugins REAL_PLUGINS 5; pick_plugins FAKE_PLUGINS 15)

    cat >> "$TEST_DIR/TestProject_FL.txt" << FL_TRACK
Track: $TRACK
FL_TRACK

    for plugin in "${ALL_PLUGINS[@]}"; do
        cat >> "$TEST_DIR/TestProject_FL.txt" << FL_PLUGIN
  Plugin: $plugin (VST3)
FL_PLUGIN
    done

    echo "" >> "$TEST_DIR/TestProject_FL.txt"
done

echo "✅ Created: TestProject_FL.txt (FL Studio text export)"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Test Project Generation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Location: $TEST_DIR"
echo ""
echo "📝 Files Created:"
echo "   • TestProject.logicx    (Logic Pro)"
echo "   • TestProject.als       (Ableton Live)"
echo "   • TestProject.song      (Studio One)"
echo "   • TestProject.cpr       (Cubase)"
echo "   • TestProject.rpp       (Reaper)"
echo "   • TestProject.ptx       (Pro Tools)"
echo "   • TestProject.bwproject (Bitwig)"
echo "   • TestProject_FL.txt    (FL Studio)"
echo ""
echo "🎯 Each project contains:"
echo "   • 20 tracks with realistic names"
echo "   • 5 REAL plugins from your system"
echo "   • 15 FICTIONAL plugins (should not match)"
echo ""
echo "💡 Test by importing these into Plugin Reporter's DAW Import feature"
echo ""
