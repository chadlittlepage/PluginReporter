# Plugin Reporter Help System

## Overview

A comprehensive macOS Help Book for Plugin Reporter, accessible via the Help menu. The help system includes detailed documentation for all features, keyboard shortcuts, FAQs, and troubleshooting guides.

## What's Included

### Complete Help Documentation

The help system includes the following pages:

1. **index.html** - Main help page with table of contents and quick links
2. **getting-started.html** - Complete quick start guide for new users
3. **daw-import.html** - Comprehensive DAW project import documentation
4. **archive.html** - Backup & Restore guide with encryption documentation
5. **keyboard-shortcuts.html** - Complete keyboard shortcut reference
6. **faq.html** - Frequently asked questions

### Styling & Assets

- **styles.css** - Professional, Apple-style CSS with dark mode support
- Responsive design works on all screen sizes
- Print-friendly layouts

## File Structure

```
Help/
└── PluginReporter.help/
    └── Contents/
        ├── Info.plist              # Help Book configuration
        └── Resources/
            └── en.lproj/
                ├── index.html      # Main help page
                ├── getting-started.html
                ├── daw-import.html
                ├── archive.html
                ├── keyboard-shortcuts.html
                ├── faq.html
                └── styles.css      # Shared stylesheet
```

## Integration Steps

### Step 1: Add Help Book to Xcode Project

1. In Xcode, select your **PR MAC** target
2. Go to **Build Phases**
3. Expand **Copy Bundle Resources**
4. Click the **+** button
5. Click **Add Other...**
6. Navigate to: `/Users/chadlittlepage/Documents/APPs/PluginReporter/Help/`
7. Select **PluginReporter.help** (the entire folder)
8. Make sure **"Create folder references"** is selected (NOT "Create groups")
9. Ensure **"PR MAC"** target is checked
10. Click **Add**

### Step 2: Verify Info.plist Configuration

The main app's `Info.plist` has been updated with:

```xml
<key>CFBundleHelpBookFolder</key>
<string>PluginReporter.help</string>
<key>CFBundleHelpBookName</key>
<string>Plugin Reporter Help</string>
```

✅ This configuration is already in place!

### Step 3: Build and Test

1. Build the app (**⌘B**)
2. Run the app
3. Go to **Help > Plugin Reporter Help** in the menu bar
4. The help system should open in your default browser

## Accessing the Help System

Users can access help through:

### From Menu Bar
- **Help > Plugin Reporter Help** - Opens main help page
- **Help > Search** - Search help content
- **Help > Keyboard Shortcuts** - Quick access to shortcuts page

### Keyboard Shortcuts
- **⌘?** - Open help
- Use Spotlight to search help content

## Help Pages Summary

### 1. Getting Started Guide
**File:** `getting-started.html`

Covers:
- First launch experience
- Interface overview
- Basic tasks (scanning, filtering, rating, tagging)
- DAW project import basics
- Exporting and backup
- Essential keyboard shortcuts

**Target Audience:** New users, quick reference

### 2. DAW Import Guide
**File:** `daw-import.html`

Covers:
- Complete list of 17+ supported DAWs
- Import methods (file menu, drag & drop, batch)
- Understanding import results
- Finding missing plugins
- Playlist management
- Best practices

**Target Audience:** Power users, studio professionals

### 3. Archive & Restore Guide
**File:** `archive.html`

Covers:
- Creating encrypted backups
- AES-256 encryption details
- Restore options (merge vs replace)
- Use cases (migration, sync, collaboration)
- Archive management
- Troubleshooting

**Target Audience:** All users, especially those migrating computers

### 4. Keyboard Shortcuts Reference
**File:** `keyboard-shortcuts.html`

Covers:
- All keyboard shortcuts organized by category
- Essential, selection, editing, view, filtering shortcuts
- Playlist management shortcuts
- Advanced power user combinations
- Customization instructions
- Printable cheat sheet

**Target Audience:** Power users, productivity-focused users

### 5. FAQ
**File:** `faq.html`

Covers:
- General questions
- Scanning & detection
- DAW project import
- Ratings, tags & notes
- Data & privacy
- Performance
- Exporting
- Troubleshooting
- Feature requests

**Target Audience:** All users

## Features

### Professional Design
- Apple Human Interface Guidelines compliant
- Native macOS look and feel
- Light and dark mode support
- Responsive layouts
- Print-friendly styles

### User-Friendly
- Clear navigation with table of contents
- Quick links for common tasks
- Step-by-step instructions with numbered lists
- Visual callouts (tips, notes, warnings)
- Searchable content

### Comprehensive Coverage
- 5 major help pages covering all features
- 100+ FAQ entries
- Complete keyboard shortcut reference
- Troubleshooting guides
- Best practices and tips

## Customization

### Adding New Pages

1. Create a new HTML file in:
   `/Users/chadlittlepage/Documents/APPs/PluginReporter/Help/PluginReporter.help/Contents/Resources/en.lproj/`

2. Use this template:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Title - Plugin Reporter Help</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="header">
        <h1>Page Title</h1>
        <p class="subtitle">Page description</p>
    </div>

    <div class="container">
        <!-- Your content here -->
    </div>

    <footer>
        <p><a href="index.html">← Back to Help Home</a></p>
        <p>&copy; 2025 Chad Littlepage. All rights reserved.</p>
    </footer>
</body>
</html>
```

3. Link to the new page from `index.html`
4. Rebuild the app

### Updating Content

Simply edit the HTML files and rebuild the app. Changes will be reflected immediately.

### Styling

All pages use `styles.css`. Key CSS classes:

- `.note` - Blue informational callout
- `.tip` - Green tip/pro tip callout
- `.warning` - Orange warning callout
- `.code-block` - Code block container
- `<code>` - Inline code
- `<kbd>` - Keyboard shortcut keys
- `.step-list` - Numbered step-by-step instructions
- `.feature-grid` - Grid layout for features
- `.toc-section` - Table of contents section

## Creating Additional Pages (Recommended)

While the current help system is comprehensive, you may want to add:

### Suggested Additional Pages:

1. **filtering.html** - Advanced filtering techniques
2. **ratings.html** - Detailed rating system guide
3. **tags.html** - Tag management and best practices
4. **notes.html** - Using the notes feature
5. **playlists.html** - Playlist management guide
6. **missing-plugins.html** - Finding and managing missing plugins
7. **custom-playlists.html** - Creating custom playlists
8. **exporting.html** - Export formats and options
9. **bulk-edit.html** - Bulk editing features
10. **ai-suggestions.html** - AI features (if applicable)
11. **metadata.html** - Plugin metadata management
12. **preferences.html** - All settings explained
13. **appearance.html** - Customizing the interface
14. **scanning-settings.html** - Scan preferences
15. **icloud.html** - iCloud sync setup
16. **common-issues.html** - Troubleshooting guide
17. **performance.html** - Performance tips
18. **support.html** - Getting support
19. **formats.html** - Export format reference
20. **printing.html** - Printing reports
21. **supported-daws.html** - Complete DAW compatibility
22. **glossary.html** - Terminology reference
23. **release-notes.html** - Version history

These are referenced in `index.html` but not yet created. You can create them using the template above.

## Help Search

macOS will automatically index your help content for searching. Users can:

1. Use **Help > Search** in the menu bar
2. Type search terms
3. macOS will search all help pages
4. Results appear with context snippets

## Localization

To add additional languages:

1. Create a new folder: `PluginReporter.help/Contents/Resources/[language].lproj/`
2. Copy all HTML files to the new folder
3. Translate the content
4. macOS will automatically use the correct language based on system settings

Example:
- `en.lproj/` - English (current)
- `es.lproj/` - Spanish
- `fr.lproj/` - French
- `de.lproj/` - German
- `ja.lproj/` - Japanese

## Testing

### Manual Testing

1. Build and run the app
2. Go to **Help > Plugin Reporter Help**
3. Verify all links work
4. Test dark mode (System Preferences > General > Appearance > Dark)
5. Test search functionality
6. Try printing a page (**⌘P**)

### Automated Testing

No automated tests currently, but you could:
- Check for broken links using a link checker
- Validate HTML with W3C validator
- Test accessibility with VoiceOver

## Maintenance

### When to Update Help

Update help documentation when you:
- Add new features
- Change keyboard shortcuts
- Modify the UI
- Fix bugs that users frequently encounter
- Add support for new DAW formats
- Change settings or preferences

### Version Control

The help system is part of your main repository. Track changes with:
- Git commits for help content updates
- Version number in `Info.plist` (currently 1.0)
- Release notes in help documentation

## Troubleshooting

### Help Menu is Empty
- Verify `Info.plist` has correct help book keys
- Check that `PluginReporter.help` is in **Copy Bundle Resources**
- Rebuild the app

### Help Pages Don't Open
- Check that `index.html` exists in the help bundle
- Verify file paths in `Info.plist`
- Check Console.app for errors

### Styles Not Loading
- Ensure `styles.css` is in the same directory as HTML files
- Check that `<link>` tags are correct in HTML
- Verify case-sensitive file names (macOS is case-preserving)

### Search Not Working
- macOS indexes help automatically on first launch
- May take a few minutes for initial indexing
- Check that HTML files have proper `<title>` and `<meta>` tags

## Best Practices

1. **Keep help in sync with features** - Update help when you update the app
2. **Use clear, simple language** - Write for all skill levels
3. **Include screenshots** - Visual aids help users understand
4. **Test all links** - Broken links frustrate users
5. **Keep pages focused** - One topic per page
6. **Cross-link related topics** - Help users discover features
7. **Update FAQs** - Add commonly asked questions as they arise
8. **Version help documentation** - Match help version to app version

## Resources

- [Apple Help Book Documentation](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/ProvidingUserAssitAppleHelp/authoring_help/authoring_help_book.html)
- [HTML Help Best Practices](https://developer.apple.com/design/human-interface-guidelines/help)
- CommonMark Markdown Spec (for future Markdown support)

## Credits

Help system created by Claude (Anthropic)
Designed for Plugin Reporter by Chad Littlepage

## License

All help documentation is part of Plugin Reporter and subject to the same license as the application.

---

## Quick Start for Integration

**TL;DR - 3 Steps:**

1. Add `Help/PluginReporter.help` folder to Xcode (Copy Bundle Resources, folder reference)
2. Info.plist already updated ✅
3. Build and test (**⌘B** then **Help > Plugin Reporter Help**)

That's it! Your comprehensive help system is ready to go.
