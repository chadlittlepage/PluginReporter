# In-App Purchase (IAP) Setup Guide

This guide covers the implementation of the 10-plugin free tier and unlimited unlock purchase in PluginReporter.

---

## ✅ What's Been Implemented

### 1. Core IAP System

**Files Created:**
- `Shared/PurchaseManager.swift` - Handles all StoreKit operations
- `Shared/UpgradePromptView.swift` - UI for upgrade prompts and banners
- Updated `PluginScanner.swift` - Enforces 10-plugin limit

**Features:**
- ✅ 10-plugin limit for free tier users
- ✅ StoreKit 2 integration (async/await)
- ✅ Automatic transaction listening and updates
- ✅ Purchase state management
- ✅ Restore purchases functionality
- ✅ Error handling and user feedback
- ✅ Cross-platform support (macOS, iOS, iPad)
- ✅ Debug unlock/reset functions

### 2. Product Configuration

**Product ID:** `com.chadlittlepage.PluginReporter.unlockUnlimited`

**Type:** Non-Consumable (one-time purchase)

**Description:** "Remove the 10-plugin limit and unlock all export features"

---

## 📋 Setup Steps

### Step 1: Add StoreKit Configuration File (For Testing)

1. In Xcode, go to **File** → **New** → **File...**
2. Choose **StoreKit Configuration File**
3. Name it `PluginReporter.storekit`
4. Add a product with:
   - **Reference Name**: Unlock Unlimited Plugins
   - **Product ID**: `com.chadlittlepage.PluginReporter.unlockUnlimited`
   - **Type**: Non-Consumable
   - **Price**: $19.99 (or your chosen price)
   - **Localization**: Add descriptions for your target markets

5. Enable the StoreKit configuration:
   - **Product** → **Scheme** → **Edit Scheme...**
   - Select **Run** → **Options** tab
   - Under **StoreKit Configuration**, select `PluginReporter.storekit`

### Step 2: Add StoreKit Capability

For each target (macOS, iPhone, iPad):

1. Select the target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **In-App Purchase** capability

### Step 3: Configure App Store Connect (When Ready)

⚠️ **Do this when you have an Apple Developer account:**

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create your app listing for each platform
3. Go to **Features** → **In-App Purchases**
4. Create new In-App Purchase:
   - **Type**: Non-Consumable
   - **Reference Name**: Unlock Unlimited Plugins
   - **Product ID**: `com.chadlittlepage.PluginReporter.unlockUnlimited`
   - **Price**: $19.99 (or your tier)
   - **Localization**: Add all required metadata

5. Submit for review along with your app

### Step 4: Update Info.plist (Optional)

Add purchase description for App Store review:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## 🧪 Testing IAP

### Local Testing (Xcode)

1. **Test Free Tier Limit:**
   - Run the app
   - Scan plugins
   - Verify only 10 plugins are shown if you have more
   - Check status message shows upgrade prompt

2. **Test Purchase Flow:**
   - Click "Upgrade" button
   - Verify `UpgradePromptView` appears
   - Click purchase button
   - StoreKit Testing popup should appear (because of .storekit file)
   - Confirm purchase
   - Verify all plugins are now visible

3. **Test Restore Purchases:**
   - Delete app
   - Reinstall
   - Scan plugins (should show 10)
   - Click "Restore Purchases"
   - Verify all plugins appear

### Debug Functions

In DEBUG builds, you can manually control unlock state:

```swift
// Unlock for testing
PurchaseManager.shared.debugUnlock()

// Reset to free tier
PurchaseManager.shared.debugReset()
```

### Sandbox Testing (Real Device)

1. **Create Sandbox Tester:**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - **Users and Access** → **Sandbox Testers**
   - Create a test Apple ID

2. **Sign Out of App Store:**
   - On device: Settings → App Store → Sign Out
   - **Do not** sign in with sandbox account yet

3. **Test Purchase:**
   - Run app from Xcode
   - Trigger purchase
   - Device will prompt for App Store login
   - Enter sandbox tester credentials
   - Complete purchase (always free in sandbox)

⚠️ **Never use sandbox testers in production App Store!**

---

## 💰 Pricing Strategy

Based on market research (see `MARKETPLACE_EVALUATION.md`):

### Recommended Pricing:

**Option 1: Platform-Specific (Recommended)**
- **macOS**: $19.99
- **iOS**: $14.99
- **iPad**: $14.99
- **Universal Bundle**: $24.99 (save $10)

**Option 2: Single Price**
- **All Platforms**: $19.99

**Option 3: Subscription**
- **Monthly**: $4.99/mo
- **Annual**: $39.99/yr (save 33%)

### Competitor Comparison:
- **PlugInfo**: $2.99 (basic features, Mac only)
- **Plughub**: $10-$30 (no mobile, no reporting)
- **OwlPlug**: Free (desktop only, basic features)

**Your Advantage:** Only mobile plugin manager + advanced reporting justifies premium pricing.

---

## 🎨 UI Integration Points

### 1. Main App Banner

Add to `ContentView.swift` (macOS) or main view:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = PluginScanner()
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Upgrade banner (shows when limit exceeded)
            UpgradeBanner(pluginCount: scanner.plugins.count)

            // Your existing content
            // ...
        }
    }
}
```

### 2. Settings Panel

Add a "Purchase" or "Upgrade" section in `SettingsView.swift`:

```swift
Section("Unlock Features") {
    if purchaseManager.isUnlocked {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Unlimited Plugins Unlocked")
        }
    } else {
        Button("Upgrade to Unlimited") {
            showUpgradeSheet = true
        }
        .buttonStyle(.borderedProminent)

        Text("Free: Limited to \(PurchaseManager.freePluginLimit) plugins")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
.sheet(isPresented: $showUpgradeSheet) {
    UpgradePromptView()
}
```

### 3. Export Limit

Add to export views (`ExportView.swift`):

```swift
if !purchaseManager.isUnlocked {
    Text("⚠️ Free tier exports limited to \(PurchaseManager.freePluginLimit) plugins")
        .font(.caption)
        .foregroundColor(.orange)
        .padding(.top, 8)
}
```

---

## 🐛 Troubleshooting

### "Unable to load pricing"

**Cause:** StoreKit configuration not set or product IDs don't match.

**Fix:**
1. Check scheme has `.storekit` file enabled
2. Verify product ID matches exactly: `com.chadlittlepage.PluginReporter.unlockUnlimited`
3. Clean build folder: **Product** → **Clean Build Folder**

### Purchase completes but doesn't unlock

**Cause:** Transaction verification failed or state not updating.

**Fix:**
1. Check `AppLogger` output for errors
2. Verify `PurchaseManager.shared` is being used (not creating new instances)
3. Call `await purchaseManager.restorePurchases()`

### "Invalid Product Identifier" in production

**Cause:** Product not approved in App Store Connect.

**Fix:**
1. Ensure IAP is approved (can take 24-48 hours)
2. Check product ID matches exactly
3. Verify app bundle ID matches App Store Connect

### App crashes on purchase

**Cause:** StoreKit framework not linked.

**Fix:**
1. Select target → **Build Phases** → **Link Binary With Libraries**
2. Add `StoreKit.framework`

---

## 📊 Analytics & Monitoring

### Track These Metrics:

1. **Conversion Rate:**
   ```swift
   // When user hits limit
   Analytics.logEvent("free_limit_reached", parameters: [
       "plugin_count": pluginCount
   ])

   // When user purchases
   Analytics.logEvent("purchase_completed", parameters: [
       "product_id": product.id,
       "price": product.price
   ])
   ```

2. **Upgrade Prompt Views:**
   - Track how many users see the upgrade prompt
   - Track dismiss rate vs. purchase rate

3. **Revenue:**
   - Monitor in App Store Connect → **Sales and Trends**
   - Track per-platform revenue

### Recommended Tools:
- Apple's built-in analytics (App Store Connect)
- Firebase Analytics (free)
- RevenueCat (advanced IAP analytics)

---

## 🚀 Launch Checklist

Before submitting to App Store:

- [ ] Test purchase flow on all platforms (Mac, iPhone, iPad)
- [ ] Test restore purchases
- [ ] Test with sandbox account
- [ ] Verify 10-plugin limit works correctly
- [ ] Add IAP in App Store Connect
- [ ] Screenshot upgrade prompt for App Store review notes
- [ ] Write clear IAP description for App Review
- [ ] Test on clean device (no previous purchases)
- [ ] Verify analytics tracking
- [ ] Set up customer support email for purchase issues

---

## 💡 Future Enhancements

### Phase 2 Features (Post-Launch):
- [ ] Family Sharing support
- [ ] Educational/Student discount tier
- [ ] Subscription model option
- [ ] Free trial period (7 days)
- [ ] "Tip Jar" donations
- [ ] Bundle pricing across platforms

### Advanced Features:
- [ ] Usage-based limits (scans per month)
- [ ] Cloud storage limit for synced plugins
- [ ] Premium export formats (e.g., Notion, Airtable)
- [ ] Plugin update notifications (premium feature)

---

## 📱 Platform-Specific Notes

### macOS
- Users expect one-time purchases for utilities
- Trial periods less common than on iOS
- Higher price tolerance ($19.99-$29.99)

### iOS/iPadOS
- Subscriptions are common and accepted
- Free trials expected for subscriptions
- Lower price tolerance than macOS ($9.99-$14.99)
- Family Sharing highly valued

### Cross-Platform
- Universal purchase is a strong selling point
- Sync between devices increases perceived value
- Consider bundle pricing for multi-platform

---

## 🆘 Support Resources

- [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [In-App Purchase Guide](https://developer.apple.com/in-app-purchase/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [StoreKit Testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)

---

*Last updated: October 15, 2025*
