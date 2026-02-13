# Dashboard Reporting System - Integration Guide

## Overview

The Dashboard Reporting System automatically sends comprehensive daily reports about your Plugin Reporter users to your server. This helps you understand how users are engaging with your app.

## Features Implemented

### ✅ Full-Featured Client (120 min implementation)

1. **Comprehensive Analytics** (`DashboardReportSystem.swift`)
   - Device information (model, OS, memory, screen)
   - App statistics (version, launches, install date)
   - Plugin analytics (count by format, publisher, style, sizes)
   - Usage metrics (scans, exports, AI requests, session duration)
   - Error logging (last 24 hours of issues)

2. **HTTP Client with Offline Queuing** (`DashboardHTTPClient.swift`)
   - Automatic retry logic (3 attempts with exponential backoff)
   - Offline queue (stores up to 10 reports)
   - Connection status monitoring
   - Secure API key authentication
   - Test connection feature

3. **Daily Scheduler** (`DashboardScheduler.swift`)
   - Custom time selection (hour and minute)
   - Automatic daily execution
   - Manual "Send Now" trigger
   - Next report countdown

4. **Settings UI** (`DashboardSettingsView.swift`)
   - Server endpoint configuration
   - API key management (stored securely in Keychain)
   - Enable/disable toggle
   - Connection status indicator
   - Test connection button
   - Schedule time picker
   - Queued reports counter

5. **Report Preview** (`DashboardReportPreviewView.swift`)
   - Visual preview of all data before sending
   - Toggle between formatted view and raw JSON
   - Transparency for users

6. **Free Cloudflare Worker Template** (`cloudflare-worker/`)
   - Receives reports via HTTP POST
   - Sends beautiful HTML emails via Resend
   - 100% free to operate (within generous limits)
   - Fully documented setup instructions

## Integration Steps

### 1. Add Files to Xcode Project

Add these new files to your Xcode project:
- `DashboardReportSystem.swift`
- `DashboardHTTPClient.swift`
- `DashboardScheduler.swift`
- `DashboardSettingsView.swift`
- `DashboardReportPreviewView.swift`

### 2. Update AppDelegate/App Entry Point

Initialize the scheduler when the app launches:

```swift
import SwiftUI

@main
struct PluginReporterApp: App {
    @StateObject private var scheduler = DashboardScheduler.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Pass plugins to scheduler after scan
                    // scheduler.updatePlugins(yourPluginArray)
                }
        }
    }
}
```

### 3. Hook Up Plugin Updates

Whenever you scan for plugins, update the scheduler:

```swift
// In your PluginScanner or wherever you load plugins:
func scanCompleted(plugins: [PluginItem]) {
    // Track the scan
    DashboardReportBuilder.trackScan()

    // Update scheduler with latest plugin list
    DashboardScheduler.shared.updatePlugins(plugins)
}
```

### 4. Track User Actions

Add tracking calls throughout your app:

```swift
// When user exports
DashboardReportBuilder.trackExport()

// When user requests AI suggestions
DashboardReportBuilder.trackAIRequest()

// When errors occur
DashboardReportBuilder.logError(
    message: "Failed to load plugin",
    severity: "error",
    context: "PluginScanner.swift:123"
)
```

### 5. Test the Integration

1. **Build and Run** the app
2. Go to **Settings** → **Dashboard Reporting**
3. Follow the setup in `cloudflare-worker/README.md`
4. Enter your Cloudflare Worker URL
5. Click **"Test Connection"**
6. Click **"Preview Report"** to see what will be sent
7. Click **"Send Now"** to send your first report
8. Check your email!

## Usage Tracking Locations

Add these tracking calls in your app:

### Scan Tracking
```swift
// In PluginScanner.swift or wherever scan completes
DashboardReportBuilder.trackScan()
DashboardScheduler.shared.updatePlugins(scannedPlugins)
```

### Export Tracking
```swift
// In ExportManager.swift or export completion handlers
DashboardReportBuilder.trackExport()
```

### AI Request Tracking
```swift
// In AIPluginSuggestions.swift
func fetchSuggestions(...) async {
    DashboardReportBuilder.trackAIRequest()
    // ... existing code
}
```

### Error Logging
```swift
// Replace or augment existing error logging
catch {
    DashboardReportBuilder.logError(
        message: error.localizedDescription,
        severity: "error",
        context: "File: \(#file), Line: \(#line)"
    )
}
```

## What Users See

In Settings, users will see:

1. **Dashboard Reporting Section** with:
   - Enable/Disable toggle
   - Server endpoint field
   - API key field (optional, with show/hide)
   - Connection status (green/red indicator)
   - Last sync time
   - Test connection button
   - Schedule time picker (hour and minute)
   - Next report countdown
   - Queued reports counter (if offline)
   - "Send Now" button
   - "Preview Report" button

2. **Privacy Notice**:
   > "Reports include plugin statistics, usage metrics, and device info. No personal data is sent."

## Data Privacy

The system only collects:
- ✅ Device specs (model, OS version, memory)
- ✅ App version and usage counts
- ✅ Plugin statistics (aggregated, no user files)
- ✅ Anonymous usage metrics
- ❌ NO personal information
- ❌ NO plugin file contents
- ❌ NO user credentials
- ❌ NO location data

## Testing Checklist

Before shipping:

- [ ] Reports send successfully via Test Connection
- [ ] Email arrives and looks correct
- [ ] Preview shows accurate data
- [ ] Offline queue works (disable internet, trigger report, re-enable)
- [ ] Scheduler triggers at correct time
- [ ] Manual "Send Now" works
- [ ] Connection status updates correctly
- [ ] API key authentication works (if enabled)
- [ ] Error logs appear in reports
- [ ] Usage tracking increments correctly

## Server Setup (100% Free)

See detailed instructions in `cloudflare-worker/README.md`:

1. Create Cloudflare Worker (free)
2. Setup Resend email (free tier: 3,000 emails/month)
3. Configure environment variables
4. Deploy worker code
5. Copy worker URL to app settings

**Total monthly cost: $0** ✅

## Monitoring

### In Cloudflare Dashboard:
- View request logs
- Monitor success/error rates
- Check latency

### In Resend Dashboard:
- View sent emails
- Check delivery status
- See bounce/spam reports

### In App Settings:
- Connection status (green/red)
- Last sync time
- Queued report count
- Test connection results

## Advanced Customization

### Change Report Schedule
Users can pick any time in Settings. Default is 9:00 AM.

### Modify Report Content
Edit `DashboardReportSystem.swift` to add/remove metrics:

```swift
struct DashboardReport: Codable {
    // Add your custom fields here
    let customMetric: Int?
}
```

### Alternative Email Services
Replace Resend in `worker.js` with:
- SendGrid (free tier: 100 emails/day)
- Mailgun (free tier: 5,000 emails/month)
- Amazon SES (cheap, but not free)

### Store Historical Data
Add Cloudflare D1 database to worker for free storage.

## Support

If issues arise:

1. Check Cloudflare Worker logs
2. Check Resend email logs
3. Use "Test Connection" for detailed errors
4. Review `cloudflare-worker/README.md` troubleshooting

## Next Steps

1. ✅ Set up Cloudflare Worker (15 min)
2. ✅ Add tracking calls to your app (30 min)
3. ✅ Test end-to-end (15 min)
4. ✅ Ship and start receiving insights!

Total setup time: ~60 minutes
Monthly cost: $0
Value: Priceless insights into user behavior! 📊
