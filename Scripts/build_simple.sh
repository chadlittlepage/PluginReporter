#!/bin/bash

#
# build_simple.sh
# Quick build script - creates app bundle only (no installer)
#
# Usage:
#   ./Scripts/build_simple.sh
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_NAME="Plugin Reporter"
SCHEME="Plugin Reporter"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"

echo -e "${BLUE}Building ${APP_NAME}...${NC}"

# Clean and build
xcodebuild clean build \
    -project "${PROJECT_DIR}/PluginReporter.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

# Find the built app
APP_PATH=$(find "${BUILD_DIR}/DerivedData/Build/Products/Release" -name "${APP_NAME}.app" -maxdepth 1 | head -n 1)

if [ -d "${APP_PATH}" ]; then
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo -e "App location: ${APP_PATH}"
    echo ""
    echo -e "${YELLOW}To install:${NC}"
    echo -e "  cp -R \"${APP_PATH}\" /Applications/"
    echo ""
    echo -e "${YELLOW}To run directly:${NC}"
    echo -e "  open \"${APP_PATH}\""
else
    echo -e "${RED}ERROR: Build failed${NC}"
    exit 1
fi
