//
//  SpaceModeButtonStyle.swift
//  Plugin Reporter
//
//  Custom button style for Space Mode appearance
//

import SwiftUI

#if os(macOS)
struct SpaceModeButtonStyle: ButtonStyle {
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let backgroundColor: Color = {
            if prefs.appearance == .space {
                return Color(red: 25/255, green: 25/255, blue: 25/255)
            } else if colorScheme == .dark {
                return Color(red: 0.2, green: 0.2, blue: 0.2)
            } else {
                // Light mode: match header grey
                return Color(red: 0.82, green: 0.82, blue: 0.84)
            }
        }()

        let textColor: Color = {
            if colorScheme == .light {
                // Light mode: 10% darker text
                return Color.black.opacity(0.9)
            } else {
                return Color.primary
            }
        }()

        return configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .foregroundColor(textColor)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
#endif
