//
//  AppDelegate.swift
//  Plugin Reporter
//
//  Application delegate for managing app lifecycle and appearance
//  Extracted from PluginReporterApp.swift
//

import SwiftUI
import Combine
#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceCancellable: AnyCancellable?

    func setupAppearanceObserver(preferences: Preferences) {
        // Observe appearance changes with debounce to avoid triggering during view updates
        appearanceCancellable = preferences.$appearance
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] newAppearance in
                self?.applyAppearance(newAppearance)
            }

        // Apply initial appearance
        applyAppearance(preferences.appearance)
    }

    private func applyAppearance(_ appearance: Preferences.Appearance) {
        let targetAppearance: NSAppearance?
        switch appearance {
        case .system:
            // For System mode: explicitly check what the system appearance is
            let systemIsDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            targetAppearance = systemIsDark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            AppLogger.debug("System mode: detected system is \(systemIsDark ? "Dark" : "Light")")
        case .light:
            targetAppearance = NSAppearance(named: .aqua)
            AppLogger.debug("Light mode: applying .aqua")
        case .dark:
            targetAppearance = NSAppearance(named: .darkAqua)
            AppLogger.debug("Dark mode: applying .darkAqua")
        case .space:
            // Use Dark mode's .darkAqua appearance to get pure black titlebar
            targetAppearance = NSAppearance(named: .darkAqua)
            AppLogger.debug("Space mode: applying .darkAqua (Pure black titlebar)")
        }

        NSApp.appearance = targetAppearance

        // Apply to all windows
        for window in NSApp.windows {
            if window.title.contains("Settings") {
                // Settings window always stays dark (dark gray titlebar)
                window.appearance = NSAppearance(named: .darkAqua)
            } else {
                // Main window follows the selected appearance
                window.appearance = targetAppearance
            }
        }

        // Configure Space mode titlebar - match Settings window appearance exactly
        if appearance == .space {
            for window in NSApp.windows where !window.title.contains("Settings") {
                // Use exact same settings as Settings window
                window.titlebarSeparatorStyle = .none
            }
        } else {
            // Reset titlebar for non-Space modes
            for window in NSApp.windows where !window.title.contains("Settings") {
                window.titlebarSeparatorStyle = .automatic
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default print orientation to landscape
        NSPrintInfo.shared.orientation = .landscape

        // Set default margins to 0.25" (18 points) on all sides
        NSPrintInfo.shared.topMargin = 18
        NSPrintInfo.shared.bottomMargin = 18
        NSPrintInfo.shared.leftMargin = 18
        NSPrintInfo.shared.rightMargin = 18

        // Disable window tabbing entirely
        NSWindow.allowsAutomaticWindowTabbing = false

        // Also set tabbingMode for all windows
        Task { @MainActor in
            for window in NSApp.windows {
                window.tabbingMode = .disallowed
            }
        }

        // Try to remove menu items after a delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            self.removeTabMenuItems()
        }

        // Configure main window for black titlebar
        Task { @MainActor in
            self.configureMainWindowTitlebar()
        }
    }

    private func configureMainWindowTitlebar() {
        // Get the user's preference
        let prefs = Preferences()

        // Find main window (not Settings)
        guard let mainWindow = NSApp.windows.first(where: { !$0.title.contains("Settings") && $0.isVisible }) else { return }

        // Apply PURE BLACK titlebar for Space mode
        if prefs.appearance == .space {
            mainWindow.appearance = NSAppearance(named: .darkAqua)
            mainWindow.titlebarSeparatorStyle = .none
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure windows don't allow tabbing
        for window in NSApp.windows {
            window.tabbingMode = .disallowed
        }
        removeTabMenuItems()
    }

    private func removeTabMenuItems() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // Find View menu and remove ALL tab-related items
        for menuItem in mainMenu.items {
            if menuItem.title == "View", let submenu = menuItem.submenu {
                // Look through ALL items (including dynamically added ones)
                let allItems = submenu.items
                for item in allItems {
                    if item.title.contains("Tab") || item.action == #selector(NSWindow.toggleTabBar(_:)) || item.action == #selector(NSWindow.toggleTabOverview(_:)) {
                        item.isHidden = true
                        item.isEnabled = false
                    }
                }
                break
            }
        }
    }
}
#endif
