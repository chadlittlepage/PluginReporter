#!/bin/bash

# Generate macOS icons with ALL appearances (Default, Dark, Tinted)

set -e

SOURCE_DIR="Icons/PluginReporter Exports"
MACOS_DIR="Assets.xcassets/AppIcon.appiconset"

# Source files
DEFAULT_ICON="$SOURCE_DIR/icon-default.png"
DARK_ICON="$SOURCE_DIR/icon-dark.png"
TINTED_ICON="$SOURCE_DIR/icon-tinted.png"

echo "🎨 Generating macOS icons with ALL appearances..."
echo "   Default: $DEFAULT_ICON"
echo "   Dark: $DARK_ICON"
echo "   Tinted: $TINTED_ICON"
echo ""

# Function to generate a specific size
generate_size() {
    local source=$1
    local output=$2
    local size=$3

    sips -z $size $size "$source" --out "$output" > /dev/null 2>&1
}

# macOS icon sizes
SIZES=(16 32 64 128 256 512 1024)

echo "📱 Generating macOS Default icons..."
for size in "${SIZES[@]}"; do
    generate_size "$DEFAULT_ICON" "$MACOS_DIR/${size}.png" $size
    echo "   ✓ ${size}.png (${size}x${size})"
done

echo ""
echo "🌙 Generating macOS Dark appearance icons..."
for size in "${SIZES[@]}"; do
    generate_size "$DARK_ICON" "$MACOS_DIR/${size}-dark.png" $size
    echo "   ✓ ${size}-dark.png (${size}x${size})"
done

echo ""
echo "✨ Generating macOS Tinted appearance icons..."
for size in "${SIZES[@]}"; do
    generate_size "$TINTED_ICON" "$MACOS_DIR/${size}-tinted.png" $size
    echo "   ✓ ${size}-tinted.png (${size}x${size})"
done

echo ""
echo "✅ All macOS icons with appearances generated successfully!"
echo ""
echo "📋 Summary:"
echo "   Default: 7 sizes (16-1024px)"
echo "   Dark: 7 sizes (16-1024px)"
echo "   Tinted: 7 sizes (16-1024px)"
echo "   Total: 21 icon files"
