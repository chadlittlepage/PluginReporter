//
//  FadingScrollbar.swift
//  PluginReporter
//
//  Extracted from MacPluginTable.swift
//  Configures scrollbars to auto-fade using overlay style
//

import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Simple Fading Scrollbar

struct FadingScrollbarConfigurator: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = ConfigView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class ConfigView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }

            // Find and configure the ScrollView with retries
            for delay in [0.0, 0.2, 0.5] {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    self.findAndConfigure()
                }
            }
        }

        func findAndConfigure() {
            guard let contentView = window?.contentView else { return }

            // Search for ALL ScrollViews (horizontal and vertical)
            var queue: [NSView] = [contentView]
            var configured = 0

            while !queue.isEmpty {
                let view = queue.removeFirst()

                if let scrollView = view as? NSScrollView {
                    // Configure with overlay style (auto-fading) for both horizontal and vertical
                    scrollView.scrollerStyle = .overlay
                    scrollView.autohidesScrollers = true // Let macOS handle fade

                    // Keep whatever scrollers it has (horizontal or vertical)
                    // Just make them overlay style

                    configured += 1
                    print("✅ Configured fading scrollbar #\(configured)")
                }

                queue.append(contentsOf: view.subviews)
            }

            if configured > 0 {
                print("✅ Total: Configured \(configured) scrollbar(s)")
            }
        }
    }
}

#endif
