#!/bin/bash

# Import plugins.json to iOS Simulator
# Usage: ./import_to_simulator.sh /path/to/plugins.json

if [ $# -eq 0 ]; then
    echo "Usage: ./import_to_simulator.sh <path-to-plugins.json>"
    echo ""
    echo "Example:"
    echo "  ./import_to_simulator.sh ~/Desktop/plugins.json"
    exit 1
fi

JSON_FILE="$1"

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: File not found: $JSON_FILE"
    exit 1
fi

echo "Finding iOS Simulator app container..."

# Get the booted simulator ID
DEVICE_ID=$(xcrun simctl list devices | grep "Booted" | grep -o '[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "Error: No booted simulator found. Please launch the iOS simulator first."
    exit 1
fi

echo "Found simulator: $DEVICE_ID"

# Find the PluginReporter app container
APP_CONTAINER=$(find ~/Library/Developer/CoreSimulator/Devices/$DEVICE_ID/data/Containers/Data/Application -name "Documents" -maxdepth 2 2>/dev/null | head -1)

if [ -z "$APP_CONTAINER" ]; then
    echo "Error: Could not find PluginReporter app container."
    echo "Make sure the app has been launched at least once in the simulator."
    exit 1
fi

DEST_FILE="$APP_CONTAINER/plugins.json"

echo "Copying $JSON_FILE to $DEST_FILE"
cp "$JSON_FILE" "$DEST_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Plugins imported to simulator."
    echo ""
    echo "Next steps:"
    echo "  1. Open the iOS app in the simulator"
    echo "  2. Go to Settings tab"
    echo "  3. Tap 'Reload Plugins'"
    echo ""
    PLUGIN_COUNT=$(cat "$JSON_FILE" | grep -c "\"Name\"")
    echo "📦 Imported $PLUGIN_COUNT plugins"
else
    echo "❌ Error: Failed to copy file"
    exit 1
fi
