# Privacy Policy for Plugin Reporter

**Last Updated: October 14, 2024**

## Introduction

Plugin Reporter ("the App") is committed to protecting your privacy. This Privacy Policy explains how the App collects, uses, and safeguards your information.

## Information Collection and Use

### What We Collect Automatically

Plugin Reporter collects **minimal information** and operates primarily locally on your device:

- **File System Scanning**: The App scans your Audio Plug-Ins folders to catalog installed plugins (VST, AU, VST3, AAX, CLAP formats)
- **Local Data Storage**: Plugin information (names, publishers, versions, file sizes) is stored locally on your device
- **Optional iCloud Sync**: If you enable iCloud sync, plugin catalog data is stored in your private iCloud account
- **Crash Reports**: We use Sentry.io to collect anonymous crash reports to improve app stability (device model, OS version, stack traces - NO personal information)

### Optional Features You Control

**Dashboard Reporting (OFF by default)**
If you choose to enable Dashboard Reporting and provide a server endpoint:
- Device model and OS version
- App version and build number
- Plugin statistics (count, publishers, formats)
- Usage metrics (scan count, export count, session duration)
- Error logs (crash details, error messages)
- **You control**: whether enabled, where data is sent, and can disable anytime

**AI Plugin Suggestions (Requires your API key)**
If you provide your own OpenAI API key:
- Plugin names and metadata may be sent to OpenAI's API
- Your API key is stored securely in device Keychain
- Subject to OpenAI's privacy policy: https://openai.com/privacy
- Can be disabled by removing your API key

### What We DO NOT Collect

- ❌ Personal identifying information (name, email, phone)
- ❌ Location data
- ❌ Contact information
- ❌ Advertising identifiers (IDFA)
- ❌ Cross-app tracking
- ❌ Browsing history
- ❌ Financial information

## Data Storage

### Local Storage

All plugin catalog data is stored locally on your device using:
- **UserDefaults**: For app preferences and settings
- **Local file system**: For temporary export files (CSV/PDF)

### iCloud Storage (Optional)

If you enable iCloud sync:
- Plugin catalog data is encrypted and stored in **your private iCloud account**
- Data is synchronized across your personal devices signed into the same iCloud account
- Plugin Reporter **NEVER** has access to your iCloud data
- You can disable iCloud sync at any time in Settings

## Data Sharing

Plugin Reporter **DOES NOT share any data** with third parties, including:
- ❌ No advertising networks
- ❌ No analytics services
- ❌ No data brokers
- ❌ No social media platforms

## Data Security

### File Access

- **Read-Only Access**: Plugin Reporter only reads plugin files; it never modifies, deletes, or moves them
- **Local Processing**: All scanning and analysis happens on your device
- **No Network Access**: The App does not send any data to external servers (except optional iCloud sync to **your** iCloud account)

### Export Data

When you export plugin catalogs:
- **CSV/PDF files** are created in your device's temporary directory
- **You control sharing**: Export files are only shared when you explicitly use the Share button
- **Automatic deletion**: Temporary files are deleted when no longer needed

## Third-Party Services

Plugin Reporter integrates with the following third-party services:

**Sentry.io** (Crash Reporting - Automatic)
- Purpose: Collect anonymous crash reports to fix bugs
- Data Collected: Device model, OS version, app version, stack traces
- Privacy Policy: https://sentry.io/privacy/
- Cannot be disabled (essential for app stability)

**OpenAI API** (AI Suggestions - Optional, requires your API key)
- Purpose: Provide AI-powered plugin recommendations
- Data Sent: Plugin names and metadata
- Privacy Policy: https://openai.com/privacy/
- Your control: Disabled unless you add your own API key

**No Other Third-Party Services:**
- ❌ No advertising SDKs
- ❌ No analytics frameworks beyond crash reporting
- ❌ No social media integrations
- ❌ No data brokers

## Children's Privacy

Plugin Reporter does not knowingly collect information from children under 13. The App is rated 4+ and is safe for all ages.

## Your Rights

You have the right to:
- **Access your data**: All data is stored locally on your device; you can view it in the App
- **Delete your data**: Uninstalling the App deletes all local data
- **Disable iCloud sync**: Turn off iCloud sync in Settings to remove data from iCloud
- **Export your data**: Use the Export feature to save your plugin catalog as CSV/PDF

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated "Last Updated" date.

## Contact Us

If you have questions about this Privacy Policy, please contact:

**Chad Littlepage**
Email: chad.littlepage@example.com
Website: https://yourwebsite.com/pluginreporter
Support: https://yourwebsite.com/pluginreporter/support

**Note**: Update these URLs before publishing to App Store

## App Store Compliance

This Privacy Policy complies with:
- Apple App Store Review Guidelines (Section 5.1.1)
- California Consumer Privacy Act (CCPA)
- General Data Protection Regulation (GDPR)
- Children's Online Privacy Protection Act (COPPA)

---

**Summary**: Plugin Reporter is a privacy-first app. We collect **NO personal information**, store everything **locally on your device**, and **NEVER** share data with third parties. Your plugin catalog is yours alone.
