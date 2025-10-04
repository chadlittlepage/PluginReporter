//
//  PrivacyDisclosureView.swift
//  PluginReporter
//
//  Privacy disclosure alert for App Store compliance
//

import SwiftUI

struct PrivacyDisclosureView: View {
    let onAcknowledge: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color.white
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding(.top, 20)

            // Title
            Text("File Access Disclosure")
                .font(.title2)
                .fontWeight(.bold)

            // Message
            VStack(alignment: .leading, spacing: 12) {
                Text("Plugin Reporter needs to scan your Audio Plug-Ins folder to catalog installed plugins.")
                    .font(.body)
                    .multilineTextAlignment(.center)

                Divider()

                Label("Read-only access", systemImage: "eye")
                    .font(.subheadline)
                Label("No plugins are modified", systemImage: "lock.shield")
                    .font(.subheadline)
                Label("No data collected or shared", systemImage: "hand.raised")
                    .font(.subheadline)
            }
            .padding(.horizontal)

            // Learn More
            Text("Your privacy is important. Plugin Reporter only accesses files locally and never sends data to external servers.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Button
            Button(action: {
                onAcknowledge()
                dismiss()
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 400)
        .background(backgroundColor)
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

#Preview {
    PrivacyDisclosureView {
        print("Acknowledged")
    }
}
