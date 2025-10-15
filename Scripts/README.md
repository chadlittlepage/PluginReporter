# Build Scripts

This directory contains build scripts for creating standalone macOS installers and builds.

## Scripts

### 1. `build_installer.sh` - Full Installer Package

Creates both a `.pkg` installer and `.dmg` disk image for distribution.

**Usage:**
```bash
cd /Users/chadlittlepage/Documents/APPs/PluginReporter
./Scripts/build_installer.sh
```

**Output:**
- `build/PluginReporter-Installer.pkg` - PKG installer
- `build/PluginReporter.dmg` - DMG disk image
- `build/Export/Plugin Reporter.app` - App bundle

**Requirements:**
- Xcode
- `create-dmg` (install with: `brew install create-dmg`)

**Install Options:**
1. **PKG Installer**: Double-click `.pkg` file → Follow installer → App installs to `/Applications`
2. **DMG Image**: Double-click `.dmg` → Drag app to Applications folder

---

### 2. `build_simple.sh` - Quick Build

Fast build for testing - creates app bundle only (no installer packaging).

**Usage:**
```bash
./Scripts/build_simple.sh
```

**Output:**
- `build/DerivedData/Build/Products/Release/Plugin Reporter.app`

**To Install:**
```bash
cp -R "build/DerivedData/Build/Products/Release/Plugin Reporter.app" /Applications/
```

**To Run Directly:**
```bash
open "build/DerivedData/Build/Products/Release/Plugin Reporter.app"
```

---

## Handling "Unidentified Developer" Warning

Since these are unsigned builds for testing, macOS will show a security warning:

### First Launch:
1. Try to open the app
2. macOS will block it with: *"Plugin Reporter can't be opened because it is from an unidentified developer"*
3. Go to **System Settings** → **Privacy & Security**
4. Scroll down to find: *"Plugin Reporter was blocked from use"*
5. Click **"Open Anyway"**
6. Confirm in the popup dialog

### Alternative (Command Line):
```bash
xattr -cr "/Applications/Plugin Reporter.app"
open "/Applications/Plugin Reporter.app"
```

---

## Code Signing (For Distribution)

To properly sign the app for distribution:

1. **Get a Developer ID certificate** from Apple Developer Program
2. **Sign the app:**
   ```bash
   codesign --deep --force --sign "Developer ID Application: Your Name (TEAM_ID)" "/Applications/Plugin Reporter.app"
   ```

3. **Notarize the app** (required for distribution):
   ```bash
   # Create a ZIP of the app
   ditto -c -k --keepParent "/Applications/Plugin Reporter.app" "PluginReporter.zip"

   # Submit for notarization
   xcrun notarytool submit "PluginReporter.zip" \
       --apple-id "your@email.com" \
       --team-id "TEAM_ID" \
       --password "app-specific-password" \
       --wait

   # Staple the notarization ticket
   xcrun stapler staple "/Applications/Plugin Reporter.app"
   ```

4. **Verify signing:**
   ```bash
   codesign -vvv --deep --strict "/Applications/Plugin Reporter.app"
   spctl -a -vvv "/Applications/Plugin Reporter.app"
   ```

---

## Build Configurations

Both scripts use **Release** configuration with:
- Optimizations enabled
- Debug symbols stripped
- Code signing disabled (for unsigned testing builds)

### Disabling Entitlements for Testing

The scripts use `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` to allow unsigned builds. This means:

⚠️ **iCloud and other entitlements will NOT work** in unsigned builds.

To test iCloud features, you must:
1. Enable code signing in Xcode
2. Configure signing & capabilities
3. Build from Xcode (not these scripts)

---

## Troubleshooting

### Error: "Archive failed"
- Check that the scheme name matches exactly: "Plugin Reporter"
- Verify the project file exists at: `PluginReporter.xcodeproj`
- Try building in Xcode first to identify issues

### Error: "create-dmg not found"
```bash
brew install create-dmg
```

### Error: "Package creation failed"
- Check that `pkgbuild` is available (comes with Xcode Command Line Tools)
- Verify the app bundle exists in `build/Export/`

### App Won't Open
1. Check console for errors: `open -a Console`
2. Try removing quarantine flag: `xattr -cr "/Applications/Plugin Reporter.app"`
3. Check permissions: `ls -la "/Applications/Plugin Reporter.app"`

---

## Output File Sizes (Approximate)

- **App Bundle**: ~8-12 MB
- **PKG Installer**: ~8-12 MB (compressed)
- **DMG Image**: ~6-10 MB (compressed)

---

## Build Time

- `build_simple.sh`: ~30-60 seconds
- `build_installer.sh`: ~2-3 minutes (includes archiving, packaging, DMG creation)

---

*Last updated: October 15, 2025*
