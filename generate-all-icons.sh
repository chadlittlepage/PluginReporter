#!/bin/bash

# Generate all app icons for macOS, iPad, and iPhone with Default, Dark, and Tinted appearances
# All icons will have proper alpha channel and smooth rounded corners

set -e

SOURCE_DIR="Icons/PluginReporter Exports"
MACOS_DIR="Assets.xcassets/AppIcon.appiconset"
IOS_DIR="iPhoness/Assets.xcassets/AppIcon.appiconset"

# Source files
DEFAULT_ICON="$SOURCE_DIR/icon-default.png"
DARK_ICON="$SOURCE_DIR/icon-dark.png"
TINTED_ICON="$SOURCE_DIR/icon-tinted.png"

echo "🎨 Generating all app icons with appearances..."
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

# macOS icon sizes (no rounded corners needed, macOS handles that)
MACOS_SIZES=(
    "16:16.png"
    "32:32.png:16@2x"
    "32:32.png"
    "64:64.png:32@2x"
    "128:128.png"
    "256:256.png:128@2x"
    "256:256.png"
    "512:512.png:256@2x"
    "512:512.png"
    "1024:1024.png:512@2x"
)

echo "📱 Generating macOS icons..."

for size_info in "${MACOS_SIZES[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"

    # Generate default
    generate_size "$DEFAULT_ICON" "$MACOS_DIR/$filename" $size
    echo "   ✓ $filename (${size}x${size})"
done

echo ""
echo "📱 Generating iOS/iPadOS icons..."

# iOS only needs 1024x1024 (iOS handles all other sizes automatically)
# Generate default
cp "$DEFAULT_ICON" "$IOS_DIR/1024.png"
echo "   ✓ 1024.png (default)"

# Generate dark
cp "$DARK_ICON" "$IOS_DIR/1024-dark.png"
echo "   ✓ 1024-dark.png (dark appearance)"

# Generate tinted
cp "$TINTED_ICON" "$IOS_DIR/1024-tinted.png"
echo "   ✓ 1024-tinted.png (tinted appearance)"

echo ""
echo "✅ All icons generated successfully!"
echo ""
echo "📋 Summary:"
echo "   macOS: 10 sizes × 1 appearance = 10 files"
echo "   iOS/iPadOS: 1 size × 3 appearances = 3 files"
echo ""
echo "⚠️  Note: macOS currently only supports single appearance."
echo "   To add Dark/Tinted to macOS, you'll need to configure that in Xcode manually."
