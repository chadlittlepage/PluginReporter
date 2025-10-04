# iOS App Setup Instructions

## 📱 Complete Guide to Adding iOS Support to Plugin Reporter

---

## STEP 1: Add iOS Target in Xcode

1. **Open your Xcode project**
   - Open `PluginReporter.xcodeproj`

2. **Add new iOS target:**
   - Click on project name in left sidebar
   - Click the `+` button at bottom of targets list
   - Select **iOS** → **App**
   - Click **Next**
   - Product Name: `PluginReporter` (same name)
   - Organization Identifier: `com.yourcompany` (use your ID)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Click **Finish**

3. **Delete duplicate files:**
   - Xcode will create duplicate files. **Delete these:**
     - `PluginReporterApp.swift` (iOS version)
     - `ContentView.swift` (iOS version)
   - Keep the macOS versions!

---

## STEP 2: Add Files to Correct Targets

### Files for **BOTH macOS AND iOS:**

Check both boxes in File Inspector (right sidebar):

```
☑ PluginReporter (macOS)
☑ PluginReporter (iOS)
```

**Shared files:**
- `PluginItem.swift`
- `Preferences.swift`
- `AIPluginSuggestions.swift`
- `AISuggestionsView.swift`
- `CloudSyncManager.swift` ← NEW FILE
- `SearchEngine.swift`
- `ExportManager.swift` (parts will need `#if os(macOS)`)

### Files for **iOS ONLY:**

Check ONLY iOS box:

```
☐ PluginReporter (macOS)
☑ PluginReporter (iOS)
```

**iOS-specific files:**
- `iOS_ContentView.swift` ← NEW FILE (main iOS app)
- `PluginDetailView.swift` ← NEW FILE
- `StatsView.swift` ← NEW FILE
- `FilterSidebarView.swift` ← NEW FILE
- `iOS_SettingsView.swift` ← NEW FILE

### Files for **macOS ONLY:**

Keep as-is (already macOS only):
- `ContentView.swift` (your existing Mac UI)
- `MacPluginTable.swift`
- `PluginScanner.swift`

---

## STEP 3: Update Main App Entry Point

**Edit: `PluginReporterApp.swift`**

Replace with cross-platform version:

```swift
import SwiftUI

@main
struct PluginReporterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var prefs = Preferences()
    @StateObject private var appState = AppState()

    var body: some Scene {
        #if os(macOS)
        // Mac version - existing code
        WindowGroup {
            ContentView()
                .environmentObject(prefs)
                .environmentObject(appState)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView(prefs: prefs)
                .environmentObject(prefs)
        }

        #else
        // iOS version - NEW
        WindowGroup {
            iOS_ContentView()
                .environmentObject(prefs)
                .preferredColorScheme(colorScheme)
        }
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch prefs.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// AppDelegate only for macOS
#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    var settingsWindow: NSWindow?

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("Settings")
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
#endif
```

---

## STEP 4: Enable iCloud CloudKit

### 4.1 Add Capabilities (macOS Target)

1. Select **PluginReporter (macOS)** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **iCloud**
5. Check **CloudKit**
6. Click **+** under CloudKit Containers
7. Enter: `iCloud.com.yourcompany.PluginReporter`
   (Replace `yourcompany` with your actual organization ID)

### 4.2 Add Capabilities (iOS Target)

1. Select **PluginReporter (iOS)** target
2. Repeat same steps as macOS
3. Use **same container name**: `iCloud.com.yourcompany.PluginReporter`

### 4.3 Update CloudSyncManager.swift

In `CloudSyncManager.swift`, line 17, update container identifier:

```swift
container = CKContainer(identifier: "iCloud.com.yourcompany.PluginReporter")
```

Replace with your actual container ID!

---

## STEP 5: Integrate Cloud Sync into Mac App

**Edit: `ContentView.swift` (macOS)**

Add CloudSync upload after scanning:

```swift
struct ContentView: View {
    @StateObject private var scanner = PluginScanner()
    @StateObject private var cloudSync = CloudSyncManager()  // ← ADD THIS
    @StateObject private var prefs = Preferences()
    // ... rest of your code

    var body: some View {
        // ... your existing UI

        // After scan completes, upload to iCloud
        .onChange(of: scanner.isScanning) { isScanning in
            if !isScanning && prefs.cloudSyncEnabled {  // ← ADD THIS
                Task {
                    await cloudSync.uploadPlugins(scanner.plugins.map(PluginItem.init))
                }
            }
        }
    }
}
```

---

## STEP 6: Test the App

### Test on Mac:

1. Select **PluginReporter (macOS)** scheme
2. Click **Run** (⌘R)
3. Scan your plugins
4. Go to Settings → Enable "Sync with iCloud"
5. Plugins will upload to CloudKit

### Test on iOS Simulator:

1. Select **PluginReporter (iOS)** scheme
2. Choose iPhone simulator (e.g., iPhone 15 Pro)
3. Click **Run** (⌘R)
4. Wait for sync from iCloud
5. Browse your Mac's plugin library on iPhone!

### Test on Real iPhone:

1. Connect iPhone via USB
2. Select **PluginReporter (iOS)** scheme
3. Choose your iPhone as destination
4. Click **Run**
5. Xcode will install and launch app
6. Enable iCloud in iOS Settings app first!

---

## STEP 7: Troubleshooting

### Problem: "No iCloud account"
**Solution:**
- Mac: System Settings → iCloud → Sign in
- iOS: Settings → [Your Name] → iCloud → Sign in

### Problem: "CloudKit not available"
**Solution:**
- Check internet connection
- Verify you added CloudKit capability to BOTH targets
- Use same container ID for both targets

### Problem: "Plugins not syncing"
**Solution:**
- Check "Sync with iCloud" is ON in Settings
- Wait 30 seconds after first scan
- Pull down to refresh on iOS

### Problem: "Build errors"
**Solution:**
- Make sure files are in correct targets
- Check `#if os(macOS)` conditionals
- Clean build folder (⌘⇧K)

---

## File Structure Summary

```
Your Project/
├── Shared (Both platforms)
│   ├── Models/
│   │   ├── PluginItem.swift
│   │   ├── Preferences.swift
│   │   └── CloudSyncManager.swift ← NEW
│   ├── Views/
│   │   ├── AISuggestionsView.swift
│   │   └── AISettingsView.swift
│   └── Utilities/
│       ├── AIPluginSuggestions.swift
│       └── SearchEngine.swift
│
├── macOS/
│   ├── ContentView.swift (Desktop)
│   ├── MacPluginTable.swift
│   ├── PluginScanner.swift
│   └── SettingsView.swift
│
└── iOS/ ← NEW
    ├── iOS_ContentView.swift ← Main iOS app
    ├── PluginDetailView.swift
    ├── StatsView.swift
    ├── FilterSidebarView.swift
    └── iOS_SettingsView.swift
```

---

## Next Steps

Once iOS app is working:

### Phase 2 Enhancements:
- [ ] iPad optimization (side-by-side layout)
- [ ] Apple Watch companion (quick stats)
- [ ] Widget for Home Screen (plugin count)
- [ ] Push notifications for new plugins
- [ ] Siri shortcuts ("Hey Siri, how many reverbs do I have?")
- [ ] Family Sharing (share with bandmates)

### Phase 3 Advanced:
- [ ] Multi-Mac support (sync from multiple Macs)
- [ ] Compare plugins across devices
- [ ] Export directly from iOS (PDF/CSV)
- [ ] AR view of plugin rack (fun feature!)

---

## Quick Reference: Platform Conditionals

Use these in shared files:

```swift
#if os(macOS)
// Mac-specific code
import AppKit
#else
// iOS-specific code
import UIKit
#endif

// Check at runtime
#if os(iOS)
// iOS only
#endif
```

---

## Support

If you run into issues:
1. Check this document
2. Clean build folder (⌘⇧K)
3. Restart Xcode
4. Check CloudKit dashboard: developer.apple.com

---

**You're all set!** 🎉

Your Plugin Reporter now works on:
- ✅ Mac (scanning + viewing)
- ✅ iPhone (viewing via iCloud sync)
- ✅ iPad (viewing via iCloud sync)

Enjoy browsing your plugin library from anywhere!
