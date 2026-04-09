import SwiftUI

/// Modal prompt asking the user whether to opt in to crash reporting.
/// Hosted via `NSHostingView(rootView: CrashReportingPromptView())` from
/// `PluginReporterApp`.
struct CrashReportingPromptView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Help Improve Plugin Reporter")
                .font(.title2.weight(.semibold))

            Text("Plugin Reporter can send anonymous crash reports and basic usage data so we can fix bugs faster. No plugin names, file paths, or session contents are ever included.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("You can change this anytime in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button("Not Now") {
                    CrashReportingAnalytics.shared.isCrashReportingEnabled = false
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Enable Crash Reporting") {
                    CrashReportingAnalytics.shared.isCrashReportingEnabled = true
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

#Preview {
    CrashReportingPromptView()
}
