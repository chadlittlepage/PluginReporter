//
//  ZoomState.swift
//  Plugin Reporter
//
//  Manages zoom state for the application
//  Extracted from PluginReporterApp.swift
//

import SwiftUI

// MARK: - Zoom State
@MainActor
class ZoomState: ObservableObject {
    @Published var scale: CGFloat = 1.0

    func zoomIn() {
        scale = min(scale + 0.1, 2.0)
        AppLogger.debug("Zoom in: scale = \(scale)")
    }

    func zoomOut() {
        scale = max(scale - 0.1, 0.5)
        AppLogger.debug("Zoom out: scale = \(scale)")
    }

    func reset() {
        scale = 1.0
        AppLogger.debug("Zoom reset: scale = \(scale)")
    }
}
