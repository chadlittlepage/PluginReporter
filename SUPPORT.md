# Plugin Reporter Support

Welcome to Plugin Reporter support! We're here to help you get the most out of your audio plugin management experience.

## Quick Start

### First Time Setup
1. **Launch the App** - Plugin Reporter will automatically scan your Audio Plug-Ins folder
2. **View Your Library** - Browse all discovered plugins in the main table view
3. **Export Data** - Use the Export menu to save your plugin list in various formats

### Common Tasks

**Scanning for Plugins**
- macOS: Automatically scans `~/Library/Audio/Plug-Ins/`
- iOS/iPad: Import a `plugins.json` file from your Mac
- Refresh: Click the refresh button to rescan for new plugins

**Exporting Plugin Lists**
- **CSV**: Import into Excel, Google Sheets, or Numbers
- **JSON**: Use for automation or developer tools
- **HTML**: Create shareable web pages
- **PDF**: Professional documentation and archival

**AI Plugin Suggestions** (Optional)
- Add your OpenAI API key in Settings
- Get intelligent plugin recommendations
- Learn about alternatives and compatibility

## Frequently Asked Questions

### General

**Q: Is Plugin Reporter free?**
A: Yes, Plugin Reporter is free with optional paid features coming soon.

**Q: What platforms are supported?**
A: macOS 13.0+, iOS 17.0+, and iPadOS 17.0+

**Q: Does it work with all plugin formats?**
A: Yes! Supports VST, VST3, AU, AAX, CLAP, and more.

### Data & Privacy

**Q: Where is my data stored?**
A: All plugin data is stored locally on your device. Nothing is uploaded to the cloud unless you enable optional Dashboard Reporting.

**Q: Can I sync between my Mac and iPad?**
A: iCloud sync is coming soon! For now, use the export/import feature to transfer data.

**Q: Is my data secure?**
A: Yes. API keys are stored in your device's secure Keychain. Plugin data never leaves your device by default.

### Features

**Q: How do I enable AI suggestions?**
A: Go to Settings > AI Suggestions and add your OpenAI API key. Get your key from https://platform.openai.com/api-keys

**Q: What is Dashboard Reporting?**
A: An optional feature for developers to track plugin usage analytics. Configure your server endpoint in Settings.

**Q: Can I customize the columns shown?**
A: Yes! On macOS, right-click the table header to show/hide columns.

### Troubleshooting

**Q: Plugins aren't showing up**
Try:
1. Verify plugins are installed in `~/Library/Audio/Plug-Ins/`
2. Click the refresh button to rescan
3. Check that you have read permissions for the Plug-Ins folder
4. Restart the app

**Q: Export isn't working**
Try:
1. Check that you have write permissions to the destination folder
2. Ensure you've selected a valid export format
3. Try exporting to Desktop instead
4. Check free disk space

**Q: AI suggestions not working**
Try:
1. Verify your OpenAI API key is correct (Settings > AI Suggestions)
2. Check your internet connection
3. Ensure you have API credits in your OpenAI account
4. Try removing and re-adding your API key

**Q: App crashes on launch**
Try:
1. Restart your device
2. Delete and reinstall the app (you won't lose data)
3. Check for updates in the App Store
4. Contact support with crash details

### iOS/iPad Specific

**Q: How do I import plugin data on iOS?**
A:
1. Export `plugins.json` from the Mac app
2. Transfer via AirDrop, iCloud Drive, or Files app
3. Open Settings in the iOS app
4. Tap "Import JSON File" and select the file

**Q: Can I scan plugins directly on iOS?**
A: Not yet. iOS apps cannot access the system's plugin folders. You must import data from the Mac app.

## Feature Requests

Have an idea for Plugin Reporter? We'd love to hear it!

**In-App**: Settings > Support > Request a Feature
**Email**: chad.littlepage@example.com
**GitHub**: https://github.com/yourusername/pluginreporter/issues

## Bug Reports

Found a bug? Help us fix it!

**In-App**: Settings > Support > Report a Bug
**Email**: chad.littlepage@example.com
**Include**:
- What you were doing when the bug occurred
- Expected vs. actual behavior
- Device model and OS version
- Screenshots if applicable

## System Requirements

### macOS
- **Minimum**: macOS 13.0 Ventura
- **Recommended**: macOS 14.0 Sonoma or later
- **Disk Space**: 50 MB
- **RAM**: 4 GB minimum

### iOS/iPadOS
- **Minimum**: iOS/iPadOS 17.0
- **Recommended**: Latest iOS/iPadOS version
- **Disk Space**: 20 MB
- **Compatibility**: iPhone 8 and later, all iPad Pro models, iPad Air 3+, iPad mini 5+

## Privacy & Security

Your privacy is our priority:
- No tracking or analytics (unless you enable Dashboard Reporting)
- No ads
- No third-party data sharing
- API keys stored securely in Keychain

Read our full [Privacy Policy](https://yourwebsite.com/pluginreporter/privacy)

## Updates

Stay up to date:
- **App Store**: Automatic updates enabled by default
- **What's New**: Check the App Store listing for release notes
- **Newsletter**: Sign up at https://yourwebsite.com/newsletter (optional)

## Additional Resources

- **Privacy Policy**: https://yourwebsite.com/pluginreporter/privacy
- **Terms of Service**: https://yourwebsite.com/pluginreporter/terms
- **FAQ**: https://yourwebsite.com/pluginreporter/faq
- **Tutorials**: https://yourwebsite.com/pluginreporter/tutorials

## Contact Support

**Email**: chad.littlepage@example.com
**Website**: https://yourwebsite.com/pluginreporter
**Response Time**: Usually within 24-48 hours

For urgent issues, please include "URGENT" in your email subject line.

## Acknowledgements

Plugin Reporter uses open-source software:
- **Sentry SDK** - Crash reporting ([License](https://github.com/getsentry/sentry-cocoa/blob/main/LICENSE))

Thank you to the open-source community!

---

**Last Updated**: October 14, 2024
**Version**: 1.0.0

---

**Note to Developer**: Before publishing, update:
1. Email addresses (multiple locations)
2. Website URLs (multiple locations)
3. GitHub repository URL
4. Newsletter signup URL (if applicable)
5. Terms of Service URL (create if needed)
