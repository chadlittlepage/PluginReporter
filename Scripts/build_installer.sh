#!/bin/bash

#
# build_installer.sh
# Creates standalone macOS installer (.pkg) and disk image (.dmg) for PluginReporter
#
# Usage:
#   ./Scripts/build_installer.sh
#
# Requirements:
#   - Xcode
#   - create-dmg (install with: brew install create-dmg)
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="PR MAC"
BUNDLE_ID="com.chadlittlepage.PluginReporter"
SCHEME="PR MAC"
CONFIGURATION="Release"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/PluginReporter.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
PKG_PATH="${BUILD_DIR}/PluginReporter-Installer.pkg"
DMG_PATH="${BUILD_DIR}/PluginReporter.dmg"

# Get version from Info.plist (after build)
get_version() {
    if [ -d "${APP_PATH}" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1.0.0"
    else
        echo "1.0.0"
    fi
}

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}PluginReporter - Standalone Installer Build${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Step 1: Clean previous builds
echo -e "${YELLOW}[1/6]${NC} Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${EXPORT_PATH}"

# Step 2: Build and Archive the app
echo -e "${YELLOW}[2/6]${NC} Building app for distribution..."
xcodebuild archive \
    -project "${PROJECT_DIR}/PluginReporter.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    | xcpretty || xcodebuild archive \
    -project "${PROJECT_DIR}/PluginReporter.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}ERROR: Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Archive created successfully${NC}"

# Step 3: Export the app
echo -e "${YELLOW}[3/6]${NC} Exporting app bundle..."
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${EXPORT_PATH}/"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}ERROR: App export failed${NC}"
    exit 1
fi

VERSION=$(get_version)
echo -e "${GREEN}✓ App exported (Version: ${VERSION})${NC}"

# Step 4: Create .pkg installer
echo -e "${YELLOW}[4/6]${NC} Creating .pkg installer..."

# Create package structure
PKG_ROOT="${BUILD_DIR}/pkg_root"
mkdir -p "${PKG_ROOT}/Applications"
cp -R "${APP_PATH}" "${PKG_ROOT}/Applications/"

# Build the package
pkgbuild \
    --root "${PKG_ROOT}" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --install-location "/" \
    "${PKG_PATH}"

if [ ! -f "${PKG_PATH}" ]; then
    echo -e "${RED}ERROR: Package creation failed${NC}"
    exit 1
fi

PKG_SIZE=$(du -h "${PKG_PATH}" | cut -f1)
echo -e "${GREEN}✓ Package created: ${PKG_PATH} (${PKG_SIZE})${NC}"

# Step 5: Create .dmg disk image
echo -e "${YELLOW}[5/6]${NC} Creating .dmg disk image..."

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}⚠ create-dmg not found. Installing via Homebrew...${NC}"
    if command -v brew &> /dev/null; then
        brew install create-dmg
    else
        echo -e "${RED}ERROR: Homebrew not installed. Install create-dmg manually:${NC}"
        echo -e "${RED}  brew install create-dmg${NC}"
        echo -e "${YELLOW}Skipping DMG creation...${NC}"
        DMG_CREATED=false
    fi
fi

if command -v create-dmg &> /dev/null; then
    # Create DMG with app bundle
    create-dmg \
        --volname "PluginReporter ${VERSION}" \
        --volicon "${APP_PATH}/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 120 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 120 \
        --no-internet-enable \
        "${DMG_PATH}" \
        "${EXPORT_PATH}" \
        2>/dev/null || true  # create-dmg returns non-zero on success sometimes

    if [ -f "${DMG_PATH}" ]; then
        DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)
        echo -e "${GREEN}✓ Disk image created: ${DMG_PATH} (${DMG_SIZE})${NC}"
        DMG_CREATED=true
    else
        echo -e "${YELLOW}⚠ DMG creation failed (non-critical)${NC}"
        DMG_CREATED=false
    fi
else
    DMG_CREATED=false
fi

# Step 6: Summary
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ Build Complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "App Version:     ${GREEN}${VERSION}${NC}"
echo -e "App Bundle:      ${APP_PATH}"
echo -e "PKG Installer:   ${PKG_PATH} (${PKG_SIZE})"

if [ "${DMG_CREATED}" = true ]; then
    echo -e "DMG Image:       ${DMG_PATH} (${DMG_SIZE})"
fi

echo ""
echo -e "${BLUE}Installation Instructions:${NC}"
echo -e "  ${YELLOW}PKG Installer:${NC}"
echo -e "    - Double-click ${PKG_PATH}"
echo -e "    - Follow the installer prompts"
echo -e "    - App will be installed to /Applications"
echo ""

if [ "${DMG_CREATED}" = true ]; then
    echo -e "  ${YELLOW}DMG Image:${NC}"
    echo -e "    - Double-click ${DMG_PATH}"
    echo -e "    - Drag '${APP_NAME}' to Applications folder"
    echo ""
fi

echo -e "${BLUE}Testing Instructions:${NC}"
echo -e "  1. Install the app using PKG or DMG"
echo -e "  2. Open System Settings → Privacy & Security"
echo -e "  3. Click 'Open Anyway' if macOS blocks the unsigned app"
echo -e "  4. Launch '${APP_NAME}' from Applications"
echo ""

echo -e "${YELLOW}Note: This is an unsigned build for testing only.${NC}"
echo -e "${YELLOW}For distribution, you'll need to code sign with:${NC}"
echo -e "  ${BLUE}codesign --deep --force --sign \"Developer ID Application\" \"${APP_PATH}\"${NC}"
echo ""
