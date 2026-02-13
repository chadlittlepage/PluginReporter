//
//  ZoomEnvironment.swift
//  Plugin Reporter
//
//  Environment key for vector zoom (size multiplier)
//

import SwiftUI

// MARK: - Size Multiplier Environment Key (Vector Zoom)

private struct SizeMultiplierKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var sizeMultiplier: CGFloat {
        get { self[SizeMultiplierKey.self] }
        set { self[SizeMultiplierKey.self] = newValue }
    }
}

// MARK: - Scaled Font Modifier

struct ScaledFont: ViewModifier {
    @Environment(\.sizeMultiplier) var multiplier
    var size: CGFloat
    var weight: Font.Weight = .regular

    func body(content: Content) -> some View {
        content.font(.system(size: size * multiplier, weight: weight))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}
