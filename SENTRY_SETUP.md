# 🐛 Sentry Crash Reporting Setup

## What You Get:
- Real-time crash notifications
- Detailed stack traces
- User impact tracking
- Performance monitoring
- **FREE tier: 5,000 errors/month**

---

## Quick Setup (15 minutes):

### **Step 1: Create Sentry Account** (3 min)

1. Go to: https://sentry.io/signup/
2. Sign up with GitHub (easiest)
3. Create new project:
   - Platform: **iOS** (works for macOS too)
   - Project name: **PluginReporter**
4. Copy your **DSN** (looks like: `https://abc123@o123.ingest.sentry.io/456`)

---

### **Step 2: Add Sentry SDK** (5 min)

#### Option A: Swift Package Manager (Recommended)

1. Open Xcode
2. File → Add Package Dependencies
3. Enter URL: `https://github.com/getsentry/sentry-cocoa`
4. Version: Latest (8.x)
5. Add to all three targets:
   - ✅ PR MAC
   - ✅ PR iPHONE
   - ✅ PR iPHONE (iPad)

#### Option B: Via Terminal (if you prefer)

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0")
]
```

---

### **Step 3: Initialize Sentry** (5 min)

Add this to your app's entry point (main Swift file):

#### For macOS (`PluginReporterApp.swift` or similar):

```swift
import SwiftUI
import Sentry  // Add this import

@main
struct PluginReporterApp: App {

    init() {
        // Initialize Sentry
        SentrySDK.start { options in
            options.dsn = "YOUR_DSN_HERE"  // Replace with your DSN
            options.debug = false  // Set to true for testing
            options.tracesSampleRate = 1.0  // Performance monitoring
            options.profilesSampleRate = 1.0

            // Environment
            options.environment = "production"

            // Release version
            options.releaseName = "plugin-reporter@1.0.0"
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### For iOS/iPadOS (same code):

```swift
import SwiftUI
import Sentry

@main
struct PluginReporteriOSApp: App {

    init() {
        SentrySDK.start { options in
            options.dsn = "YOUR_DSN_HERE"
            options.debug = false
            options.tracesSampleRate = 1.0
            options.environment = "production"
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

### **Step 4: Test It Works** (2 min)

Add a test crash button (temporary, remove after testing):

```swift
Button("Test Crash") {
    fatalError("Test crash for Sentry")
}
```

Or trigger programmatically:
```swift
SentrySDK.capture(message: "Test event from Plugin Reporter!")
```

Run the app, click the button, and check Sentry dashboard for the crash!

---

## 🔧 Advanced Features (Optional):

### Track Custom Events:
```swift
SentrySDK.capture(message: "User exported report")
```

### Track Errors:
```swift
do {
    try riskyOperation()
} catch {
    SentrySDK.capture(error: error)
}
```

### Add User Context:
```swift
let user = User(userId: "user123")
user.email = "user@example.com"
SentrySDK.setUser(user)
```

### Add Breadcrumbs (see what led to crash):
```swift
let crumb = Breadcrumb()
crumb.message = "User opened plugin list"
crumb.category = "navigation"
SentrySDK.addBreadcrumb(crumb)
```

---

## 🤖 Automate with GitHub Actions:

Already set up! Your CI/CD will automatically upload debug symbols:

```yaml
# Add to .github/workflows/build.yml
- name: Upload debug symbols to Sentry
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: your-org
    SENTRY_PROJECT: pluginreporter
  run: |
    brew install getsentry/tools/sentry-cli
    sentry-cli upload-dif build/
```

---

## 📊 Monitor from Terminal:

```bash
# Install Sentry CLI
brew install getsentry/tools/sentry-cli

# Login
sentry-cli login

# List recent issues
sentry-cli issues list

# View unresolved issues
sentry-cli issues list --query "is:unresolved"

# Get issue details
sentry-cli issues show <issue-id>
```

---

## 🎯 What You'll See in Dashboard:

**When app crashes:**
1. ⚡ Instant email notification
2. 📊 Crash details:
   - Exact line of code
   - Stack trace
   - Device info (macOS version, iOS version)
   - Number of users affected
3. 🔍 Breadcrumbs (what user did before crash)
4. 📈 Trends (is this crash increasing?)

---

## 💰 Free Tier Limits:

- ✅ 5,000 errors/month
- ✅ 10,000 performance transactions
- ✅ 30-day data retention
- ✅ Unlimited projects
- ✅ Email alerts

**More than enough for indie development!**

---

## 🔐 Security Best Practices:

### Don't commit your DSN directly!

Use environment variables or config files:

```swift
// Create Config.swift (add to .gitignore)
struct SentryConfig {
    static let dsn = "YOUR_DSN_HERE"
}

// In app:
options.dsn = SentryConfig.dsn
```

Or use Xcode build configurations.

---

## ✅ Checklist:

- [ ] Create Sentry account
- [ ] Create PluginReporter project
- [ ] Copy DSN
- [ ] Add Sentry SDK via SPM
- [ ] Initialize in app entry point
- [ ] Test with crash button
- [ ] See crash in Sentry dashboard
- [ ] Remove test crash code
- [ ] Install `sentry-cli` (optional)
- [ ] Add to GitHub Actions (optional)

---

## 🆘 Troubleshooting:

**Crashes not appearing?**
- Check DSN is correct
- Set `options.debug = true` temporarily
- Check console for Sentry logs
- Make sure you're building in Release mode

**Build errors?**
- Make sure Sentry SDK is added to all targets
- Clean build folder: Cmd+Shift+K
- Restart Xcode

---

## 📚 Resources:

- **Docs:** https://docs.sentry.io/platforms/apple/
- **Dashboard:** https://sentry.io/organizations/your-org/issues/
- **CLI:** https://docs.sentry.io/cli/

---

**Next:** Once Sentry is working, you'll know about every crash instantly! 🎯
