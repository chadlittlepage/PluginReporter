# 🚀 Fastlane Setup for Plugin Reporter

## What You Get:
- Automated screenshots for App Store
- Automated TestFlight uploads
- Automated App Store submissions
- Build automation
- **Saves 50+ hours per year**

---

## Installation (5 minutes):

### **Step 1: Install Fastlane**

```bash
# Install via Homebrew (recommended)
brew install fastlane

# Or via RubyGems
sudo gem install fastlane

# Verify installation
fastlane --version
```

---

### **Step 2: Initialize Fastlane**

```bash
cd /Users/chadlittlepage/Documents/APPs/PluginReporter

# Initialize (will create fastlane/ directory)
fastlane init

# Answer the prompts:
# 1. "What would you like to use fastlane for?"
#    → Select: 4 (Manual setup)
#
# 2. Press Enter to continue
```

This creates:
- `fastlane/Fastfile` (your automation scripts)
- `fastlane/Appfile` (app configuration)

---

## 📝 Pre-configured Fastfile

I've created a ready-to-use Fastfile below. Create it manually or use the one from init:

### **File: `fastlane/Fastfile`**

```ruby
# Plugin Reporter Fastlane Configuration
# Run with: fastlane <lane_name>

default_platform(:mac)

#########################
# macOS Platform
#########################

platform :mac do
  desc "Run tests for macOS"
  lane :test do
    scan(
      scheme: "PR MAC",
      destination: "platform=macOS",
      clean: true
    )
  end

  desc "Build macOS app (Release)"
  lane :build do
    gym(
      scheme: "PR MAC",
      configuration: "Release",
      destination: "platform=macOS",
      output_directory: "./fastlane/builds/macOS",
      output_name: "PluginReporter.app",
      clean: true
    )

    UI.success("✅ macOS build complete!")
    UI.message("📦 Location: ./fastlane/builds/macOS/PluginReporter.app")
  end

  desc "Take App Store screenshots (macOS)"
  lane :screenshots do
    snapshot(
      scheme: "PR MAC",
      devices: ["Mac"],
      output_directory: "./fastlane/screenshots/macOS"
    )

    UI.success("📸 Screenshots saved to ./fastlane/screenshots/macOS")
  end

  desc "Full release: test + build"
  lane :release do
    test
    build
    UI.success("🚀 macOS release ready!")
  end
end

#########################
# iOS Platform
#########################

platform :ios do
  desc "Run tests for iOS"
  lane :test do
    scan(
      scheme: "PR iPHONE",
      destination: "platform=iOS Simulator,name=iPhone 15 Pro",
      clean: true
    )
  end

  desc "Build iOS app (Debug for Simulator)"
  lane :build do
    gym(
      scheme: "PR iPHONE",
      configuration: "Debug",
      destination: "platform=iOS Simulator,name=iPhone 15 Pro",
      output_directory: "./fastlane/builds/iOS",
      skip_package_ipa: true,
      clean: true
    )

    UI.success("✅ iOS build complete!")
  end

  desc "Take App Store screenshots (iOS)"
  lane :screenshots do
    snapshot(
      scheme: "PR iPHONE",
      devices: [
        "iPhone 15 Pro",
        "iPhone 15 Pro Max",
        "iPhone SE (3rd generation)",
        "iPad Pro (12.9-inch) (6th generation)"
      ],
      output_directory: "./fastlane/screenshots/iOS",
      languages: ["en-US"]
    )

    UI.success("📸 Screenshots saved to ./fastlane/screenshots/iOS")
  end

  desc "Build and upload to TestFlight (requires Apple Developer Account)"
  lane :beta do
    # Increment build number
    increment_build_number

    # Build for distribution
    gym(
      scheme: "PR iPHONE",
      export_method: "app-store",
      output_directory: "./fastlane/builds/iOS"
    )

    # Upload to TestFlight
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )

    UI.success("🚀 Uploaded to TestFlight!")
  end

  desc "Submit to App Store (requires Apple Developer Account)"
  lane :release do
    # Ensure tests pass
    test

    # Increment build number
    increment_build_number

    # Build for distribution
    gym(
      scheme: "PR iPHONE",
      export_method: "app-store",
      output_directory: "./fastlane/builds/iOS"
    )

    # Upload to App Store
    deliver(
      submit_for_review: false,  # Manual review submission
      automatic_release: false
    )

    UI.success("🚀 Uploaded to App Store Connect!")
  end
end

#########################
# Custom Lanes
#########################

desc "Build all platforms"
lane :build_all do
  mac(:build)
  ios(:build)
  UI.success("✅ All platforms built successfully!")
end

desc "Test all platforms"
lane :test_all do
  mac(:test)
  ios(:test)
  UI.success("✅ All tests passed!")
end

desc "Generate all screenshots"
lane :screenshots_all do
  mac(:screenshots)
  ios(:screenshots)
  UI.success("📸 All screenshots generated!")
end
```

---

### **File: `fastlane/Appfile`**

```ruby
# App Configuration
app_identifier("com.yourdomain.pluginreporter")  # Update with your bundle ID
apple_id("your.email@example.com")  # Update with your Apple ID

# Team ID (find at: https://developer.apple.com/account)
# team_id("YOUR_TEAM_ID")

# App Store Connect Team ID
# itc_team_id("YOUR_ITC_TEAM_ID")
```

---

## 🎯 Usage - Terminal Commands:

### **Build Commands:**
```bash
# Build macOS app
fastlane mac build

# Build iOS app
fastlane ios build

# Build all platforms
fastlane build_all
```

### **Testing:**
```bash
# Test macOS
fastlane mac test

# Test iOS
fastlane ios test

# Test everything
fastlane test_all
```

### **Screenshots:**
```bash
# Generate macOS screenshots
fastlane mac screenshots

# Generate iOS screenshots
fastlane ios screenshots

# Generate all screenshots
fastlane screenshots_all
```

### **Release (requires Apple Developer Account):**
```bash
# Upload iOS to TestFlight
fastlane ios beta

# Submit iOS to App Store
fastlane ios release

# Full macOS release
fastlane mac release
```

---

## 📸 Screenshot Automation Setup:

For automated screenshots, you need UI tests. Create a simple UI test:

### **Step 1: Add UI Test Target** (in Xcode)

1. File → New → Target
2. Select "UI Testing Bundle"
3. Name: "PluginReporterUITests"

### **Step 2: Create Snapfile**

```bash
cd fastlane
cat > Snapfile << 'EOF'
# Snapshot Configuration
devices([
  "iPhone 15 Pro",
  "iPhone 15 Pro Max",
  "iPad Pro (12.9-inch) (6th generation)"
])

languages([
  "en-US"
])

scheme("PR iPHONE")

output_directory("./screenshots")

clear_previous_screenshots(true)
EOF
```

### **Step 3: Simple UI Test**

Add to your UI test file:

```swift
import XCTest

class PluginReporterUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func testTakeScreenshots() {
        let app = XCUIApplication()

        // Wait for app to load
        sleep(2)

        // Take main screen screenshot
        snapshot("01-MainScreen")

        // Navigate and take more screenshots
        // Add your navigation here

        snapshot("02-PluginList")
    }
}
```

---

## 🤖 Add to GitHub Actions:

Add to `.github/workflows/build.yml`:

```yaml
- name: Install Fastlane
  run: brew install fastlane

- name: Build with Fastlane
  run: fastlane build_all

- name: Run Fastlane tests
  run: fastlane test_all

- name: Generate screenshots
  run: fastlane screenshots_all
  if: startsWith(github.ref, 'refs/tags/v')
```

---

## 💡 Pro Tips:

### **1. Speed Up Builds:**
```bash
# Build without cleaning (faster)
fastlane mac build skip_clean:true
```

### **2. Custom Variables:**
```ruby
lane :build do |options|
  configuration = options[:config] || "Release"
  gym(configuration: configuration)
end
```

Usage: `fastlane mac build config:Debug`

### **3. Notifications:**
```ruby
lane :release do
  build
  slack(message: "New release built! 🚀")
end
```

---

## 📊 Time Savings:

| Task | Manual | Fastlane | Saved |
|------|--------|----------|-------|
| Screenshots | 30 min | 2 min | 28 min |
| TestFlight Upload | 15 min | 1 min | 14 min |
| App Store Submit | 20 min | 2 min | 18 min |
| Build All Platforms | 10 min | 1 min | 9 min |

**Per release:** ~69 minutes saved
**10 releases/year:** ~11.5 hours saved
**With iterations:** 50+ hours saved

---

## 🔧 Troubleshooting:

### **Fastlane not found:**
```bash
brew install fastlane
# Or
sudo gem install fastlane
```

### **Certificate issues:**
```bash
# Match for code signing (advanced)
fastlane match development
fastlane match appstore
```

### **Scheme not found:**
```bash
# Make schemes shared in Xcode:
# Product → Scheme → Manage Schemes → Check "Shared"
```

---

## 🎓 Next Steps:

### **Without Apple Developer Account:**
- ✅ Use for builds
- ✅ Use for testing
- ✅ Use for screenshots
- ❌ Can't upload to TestFlight/App Store

### **With Apple Developer Account ($99/year):**
- ✅ Everything above
- ✅ Upload to TestFlight
- ✅ Submit to App Store
- ✅ Full automation

---

## 📚 Resources:

- **Docs:** https://docs.fastlane.tools/
- **Actions:** https://docs.fastlane.tools/actions/
- **Best Practices:** https://docs.fastlane.tools/best-practices/

---

## ✅ Installation Checklist:

- [ ] Install Fastlane: `brew install fastlane`
- [ ] Initialize: `fastlane init`
- [ ] Create Fastfile (use example above)
- [ ] Create Appfile (update with your IDs)
- [ ] Test build: `fastlane mac build`
- [ ] Make schemes shared in Xcode
- [ ] Add to GitHub Actions (optional)
- [ ] Setup screenshot automation (optional)

---

**Run your first lane:** `fastlane mac build` 🚀
