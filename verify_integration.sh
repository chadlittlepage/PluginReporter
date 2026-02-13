#!/bin/bash

# Plugin Reporter - Integration Verification Script
# Checks that all 18 DAW parsers are properly integrated

echo "🔍 Plugin Reporter - Parser Integration Verification"
echo "=================================================="
echo ""

PROJECT_DIR="/Users/chadlittlepage/Documents/APPs/PluginReporter"
XCODEPROJ="$PROJECT_DIR/PluginReporter.xcodeproj/project.pbxproj"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Expected parsers
PARSERS=(
    "AbletonLiveParser"
    "ArdourParser"
    "BitwigParser"
    "CubaseParser"
    "DigitalPerformerParser"
    "FairlightParser"
    "FLStudioParser"
    "GarageBandParser"
    "LogicProParser"
    "MainStageParser"
    "MixbusParser"
    "ProToolsParser"
    "ProToolsTextParser"
    "ReaperParser"
    "ReasonParser"
    "RenoiseParser"
    "StudioOneParser"
    "TracktionParser"
)

TOTAL=${#PARSERS[@]}
FOUND_IN_DIR=0
FOUND_IN_XCODE=0
MISSING_IN_XCODE=()

echo "📁 Step 1: Checking parser files in directory..."
echo ""

for parser in "${PARSERS[@]}"; do
    FILE="$PROJECT_DIR/${parser}.swift"
    if [ -f "$FILE" ]; then
        echo -e "${GREEN}✓${NC} $parser.swift exists"
        ((FOUND_IN_DIR++))
    else
        echo -e "${RED}✗${NC} $parser.swift MISSING"
    fi
done

echo ""
echo -e "Directory: ${GREEN}$FOUND_IN_DIR${NC}/$TOTAL parsers found"
echo ""
echo "=================================================="
echo ""

echo "🔨 Step 2: Checking if parsers are in Xcode project..."
echo ""

for parser in "${PARSERS[@]}"; do
    if grep -q "${parser}.swift in Sources" "$XCODEPROJ" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $parser.swift in Xcode project"
        ((FOUND_IN_XCODE++))
    else
        echo -e "${YELLOW}⚠${NC}  $parser.swift NOT in Xcode project"
        MISSING_IN_XCODE+=("$parser")
    fi
done

echo ""
echo -e "Xcode Project: ${GREEN}$FOUND_IN_XCODE${NC}/$TOTAL parsers added"
echo ""

if [ $FOUND_IN_XCODE -lt $TOTAL ]; then
    echo "=================================================="
    echo ""
    echo -e "${YELLOW}⚠️  ACTION REQUIRED${NC}"
    echo ""
    echo "The following parsers need to be added to Xcode:"
    echo ""
    for missing in "${MISSING_IN_XCODE[@]}"; do
        echo "  • ${missing}.swift"
    done
    echo ""
    echo "To add them:"
    echo "  1. Open PluginReporter.xcodeproj in Xcode"
    echo "  2. Drag these files from Finder into the project"
    echo "  3. Check 'Copy items if needed' and select targets"
    echo ""
fi

echo "=================================================="
echo ""

echo "📋 Step 3: Checking DAWParserProtocol.swift..."
echo ""

PROTOCOL_FILE="$PROJECT_DIR/DAWParserProtocol.swift"
if [ -f "$PROTOCOL_FILE" ]; then
    echo -e "${GREEN}✓${NC} DAWParserProtocol.swift exists"

    # Check registrations
    REGISTRATIONS=$(grep -c "registerParser" "$PROTOCOL_FILE")
    echo -e "   Found $REGISTRATIONS parser registrations"

    if [ $REGISTRATIONS -ge 18 ]; then
        echo -e "   ${GREEN}✓${NC} All parsers appear to be registered"
    else
        echo -e "   ${YELLOW}⚠${NC}  Expected 18 registrations, found $REGISTRATIONS"
    fi
else
    echo -e "${RED}✗${NC} DAWParserProtocol.swift NOT FOUND"
fi

echo ""
echo "=================================================="
echo ""

echo "🎯 Step 4: Checking DAWType enum..."
echo ""

DAW_MANAGER="$PROJECT_DIR/DAWPlaylistManager.swift"
if [ -f "$DAW_MANAGER" ]; then
    echo -e "${GREEN}✓${NC} DAWPlaylistManager.swift exists"

    # Check for new DAW types
    EXPECTED_TYPES=("mainStage" "renoise" "mixbus")
    for daw_type in "${EXPECTED_TYPES[@]}"; do
        if grep -q "case $daw_type" "$DAW_MANAGER"; then
            echo -e "   ${GREEN}✓${NC} $daw_type enum case found"
        else
            echo -e "   ${RED}✗${NC} $daw_type enum case MISSING"
        fi
    done
else
    echo -e "${RED}✗${NC} DAWPlaylistManager.swift NOT FOUND"
fi

echo ""
echo "=================================================="
echo ""

echo "🏗️  Step 5: Attempting test build..."
echo ""

if command -v xcodebuild &> /dev/null; then
    echo "Running xcodebuild (this may take 30-60 seconds)..."

    BUILD_OUTPUT=$(xcodebuild -project "$PROJECT_DIR/PluginReporter.xcodeproj" \
                               -scheme "PR MAC" \
                               -configuration Debug \
                               -dry-run \
                               build 2>&1)

    BUILD_EXIT=$?

    if [ $BUILD_EXIT -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Build configuration is valid"
    else
        echo -e "${RED}✗${NC} Build configuration has issues"
        echo ""
        echo "Build output (last 20 lines):"
        echo "$BUILD_OUTPUT" | tail -20
    fi
else
    echo -e "${YELLOW}⚠${NC}  xcodebuild not available in PATH"
    echo "   Skipping build test"
fi

echo ""
echo "=================================================="
echo ""

echo "📊 SUMMARY"
echo "=========="
echo ""
echo -e "Parser Files in Directory:  ${GREEN}$FOUND_IN_DIR${NC}/$TOTAL"
echo -e "Parser Files in Xcode:      ${GREEN}$FOUND_IN_XCODE${NC}/$TOTAL"
echo ""

if [ $FOUND_IN_DIR -eq $TOTAL ] && [ $FOUND_IN_XCODE -eq $TOTAL ]; then
    echo -e "${GREEN}🎉 SUCCESS!${NC} All 18 parsers are integrated!"
    echo ""
    echo "Next steps:"
    echo "  1. Open Xcode and build (Cmd+B)"
    echo "  2. Run the app (Cmd+R)"
    echo "  3. Test importing files from different DAWs"
    echo ""
elif [ $FOUND_IN_DIR -eq $TOTAL ] && [ $FOUND_IN_XCODE -lt $TOTAL ]; then
    echo -e "${YELLOW}⚠️  PARTIALLY COMPLETE${NC}"
    echo ""
    echo "All parser files exist, but some are not in Xcode project."
    echo "See instructions above to add them."
    echo ""
elif [ $FOUND_IN_DIR -lt $TOTAL ]; then
    echo -e "${RED}✗ INCOMPLETE${NC}"
    echo ""
    echo "Some parser files are missing from the directory."
    echo "Review the parser creation steps."
    echo ""
else
    echo -e "${YELLOW}⚠️  UNKNOWN STATUS${NC}"
    echo ""
    echo "Please review the output above."
    echo ""
fi

echo "=================================================="
echo ""
echo "Verification complete!"
echo ""
