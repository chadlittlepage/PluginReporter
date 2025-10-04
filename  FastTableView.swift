// FastTableView.swift — minimal placeholder to avoid SwiftUI in AppKit file
import AppKit
import SwiftUI

/// Placeholder so references to `FastTableView` still compile.
/// If you're no longer using a custom NSTableView bridge, you may delete this file.
struct FastTableView: NSViewRepresentable {
    typealias NSViewType = NSScrollView

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        // Empty content view so it takes space but does nothing
        let placeholder = NSView(frame: .zero)
        let clip = NSClipView()
        clip.documentView = placeholder
        scroll.contentView = clip
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // no-op
    }
}
