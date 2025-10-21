//
//  ViewExtensions+Table.swift
//  PluginReporter
//
//  Extracted from MacPluginTable.swift
//  View extensions for table-specific functionality
//

import SwiftUI

#if os(macOS)

extension View {
    @ViewBuilder
    func applyIfAvailableMac14FocusDisabled() -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}

#endif
