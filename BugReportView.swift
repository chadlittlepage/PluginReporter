import SwiftUI

// MARK: - Bug Report View

struct BugReportView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var stepsToReproduce: String = ""
    @State private var expectedBehavior: String = ""
    @State private var actualBehavior: String = ""
    @State private var severity: BugSeverity = .medium
    @State private var includeSystemInfo: Bool = true
    @State private var includeCrashLog: Bool = true
    @State private var email: String = ""

    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    enum BugSeverity: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .low: return .yellow
            case .medium: return Color(red: 1.0, green: 0.6, blue: 0.2) // Light orange
            case .high: return Color(red: 1.0, green: 0.3, blue: 0.1) // Orange red
            case .critical: return .red
            }
        }
    }

    // Match Settings card background colors
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : Color(red: 242/255, green: 242/255, blue: 247/255)
    }

    private var appBackground: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    private var textEditorBackground: Color {
        Color.black
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Bug Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bug Details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("", text: $title, prompt: Text("Bug Title"))
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $description)
                                .frame(height: 150)
                                .padding(8)
                                .background(textEditorBackground)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Severity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Severity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    HStack(spacing: 4) {
                        ForEach(BugSeverity.allCases, id: \.self) { sev in
                            Button(action: {
                                severity = sev
                            }) {
                                Text(sev.rawValue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(severity == sev ? sev.color : Color.clear)
                                    .foregroundColor(severity == sev ? .white : sev.color)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Additional Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Steps to Reproduce")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $stepsToReproduce)
                                .frame(height: 120)
                                .padding(8)
                                .background(textEditorBackground)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expected Behavior")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $expectedBehavior)
                                .frame(height: 100)
                                .padding(8)
                                .background(textEditorBackground)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Actual Behavior")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $actualBehavior)
                                .frame(height: 100)
                                .padding(8)
                                .background(textEditorBackground)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Diagnostic Data
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diagnostic Data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        Toggle("Include system information", isOn: $includeSystemInfo)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        Toggle("Include recent crash logs", isOn: $includeCrashLog)
                            .padding(.horizontal, 16)

                        Text("System info helps us diagnose the issue. No personal data is sent.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Contact
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        TextField("", text: $email, prompt: Text("Email"))
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Text("Provide your email if you'd like a response.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Send Button
                HStack {
                    Spacer()
                    Button(action: sendBugReport) {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSending ? "Sending..." : "Send Bug Report")
                    }
                    .disabled(isSending || title.isEmpty || description.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Spacer()
                }
                .padding(.vertical, 16)

                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .background(appBackground)
        .frame(minWidth: 700, minHeight: 800)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Report Sent!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for reporting this issue. We'll look into it as soon as possible.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
    }

    private func sendBugReport() {
        guard !title.isEmpty, !description.isEmpty else { return }

        isSending = true

        Task {
            do {
                let report = BugReport(
                    title: title,
                    description: description,
                    stepsToReproduce: stepsToReproduce.isEmpty ? nil : stepsToReproduce,
                    expectedBehavior: expectedBehavior.isEmpty ? nil : expectedBehavior,
                    actualBehavior: actualBehavior.isEmpty ? nil : actualBehavior,
                    severity: severity.rawValue,
                    email: email.isEmpty ? nil : email,
                    systemInfo: includeSystemInfo ? collectSystemInfo() : nil,
                    crashLog: includeCrashLog ? collectRecentCrashLogs() : nil,
                    timestamp: Date()
                )

                try await UserFeedbackClient.shared.sendBugReport(report)

                await MainActor.run {
                    isSending = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = "Failed to send report: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func collectSystemInfo() -> BugReport.SystemInfo {
        #if os(macOS)
        return collectMacSystemInfo()
        #elseif os(iOS)
        return collectiOSSystemInfo()
        #endif
    }

    #if os(macOS)
    private func collectMacSystemInfo() -> BugReport.SystemInfo {
        let processInfo = ProcessInfo.processInfo

        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        return BugReport.SystemInfo(
            appVersion: version,
            appBuild: build,
            osVersion: "macOS \(processInfo.operatingSystemVersionString)",
            deviceModel: modelString
        )
    }
    #endif

    #if os(iOS)
    private func collectiOSSystemInfo() -> BugReport.SystemInfo {
        let device = UIDevice.current
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        return BugReport.SystemInfo(
            appVersion: version,
            appBuild: build,
            osVersion: "\(device.systemName) \(device.systemVersion)",
            deviceModel: device.model
        )
    }
    #endif

    private func collectRecentCrashLogs() -> String? {
        // Retrieve recent error logs from dashboard system
        guard let logsData = UserDefaults.standard.data(forKey: "error_logs"),
              let logs = try? JSONDecoder().decode([DashboardReport.ErrorLog].self, from: logsData) else {
            return nil
        }

        let recentLogs = logs.suffix(10)
        let logString = recentLogs.map { log in
            "[\(log.severity.uppercased())] \(log.timestamp): \(log.message)"
        }.joined(separator: "\n")

        return logString.isEmpty ? nil : logString
    }
}

// MARK: - Bug Report Model

struct BugReport: Codable {
    let title: String
    let description: String
    let stepsToReproduce: String?
    let expectedBehavior: String?
    let actualBehavior: String?
    let severity: String
    let email: String?
    let systemInfo: SystemInfo?
    let crashLog: String?
    let timestamp: Date

    struct SystemInfo: Codable {
        let appVersion: String
        let appBuild: String
        let osVersion: String
        let deviceModel: String
    }
}
