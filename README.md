# Plugin Reporter v001 (1.0.0)

![Plugin Reporter Icon](SampleExports/PluginReporter_IconPreview.png)

**Dark Mode-only** macOS app that scans your system for audio plugins and exports a report.

**Columns:** Name, Publisher, Version, Type, Architectures, Date, Size, Path, Requirement, Obsolete.

## Build & Run (Xcode, minimal steps)
1. Unzip this package.
2. Open **PluginReporter_v001.xcodeproj** in Xcode. (Select your Team if prompted; *Automatically manage signing* is recommended.)
3. Press **⌘R** to run. The table starts **empty**—click **Scan** to populate.

> Tip: If results are empty, grant **Full Disk Access** in **System Settings → Privacy & Security** to the built app, then relaunch and scan again.

## Using the App
- **Search**: `type:AU,VST3 pub:fabfilter arch:arm64 req:rosetta path:Spitfire obsolete:true !demo`
- **Formats**: AU / VST / VST3 / AAX / CLAP / LV2 toggles.
- **Context menu**: Right-click a row → Show in Finder, Copy Path.
- **Exports**: CSV, JSON, HTML (dark), PDF (dark) — all columns included.
- **Settings**: Add/remove **Custom Scan Paths**.

## Screenshots (Mockups, Retina)
![Main Window](SampleExports/MainWindow@2x.png)
![Settings Window](SampleExports/SettingsWindow@2x.png)
![Export Preview](SampleExports/ExportPreview@2x.png)

## DMG Template (Unsigned)
- See **DMGTemplate/README_DMG.md** and run `create-dmg.sh` after archiving.
- Apple-style background and Applications alias included.

## Version History
- **v001 (1.0.0)** — First full release: Dark Mode only; scanner (AU, VST, VST3, AAX, CLAP, LV2); advanced search;
  exports (CSV/JSON/HTML/PDF); custom scan paths; context menu; sample exports & icon preview.

— Built on 2025-09-22
