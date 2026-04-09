import SwiftUI

// MARK: - Dashboard Settings View

struct DashboardSettingsView: View {
    @StateObject private var httpClient = DashboardHTTPClient.shared
    @StateObject private var scheduler = DashboardScheduler.shared
    @StateObject private var scheduleConfig = ScheduleConfigViewModel()

    @State private var serverEndpoint: String = ""
    @State private var apiKey: String = ""
    @State private var dashboardEnabled: Bool = false
    @State private var showingAPIKey: Bool = false

    @State private var testingConnection: Bool = false
    @State private var testResult: String = ""
    @State private var showTestResult: Bool = false

    @State private var showingReportPreview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle
            Toggle("Enable Daily Reports", isOn: $dashboardEnabled)
                .onChange(of: dashboardEnabled) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "dashboard_enabled")
                    if newValue && !serverEndpoint.isEmpty {
                        scheduler.start()
                    } else {
                        scheduler.stop()
                    }
                }

            Text("Send daily usage reports to your server for analytics and monitoring.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if dashboardEnabled {
                // Server Configuration
                GroupBox(label: Label("Server Configuration", systemImage: "server.rack")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server Endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("https://your-server.com/api/reports", text: $serverEndpoint)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                #if os(macOS)
                                .autocorrectionDisabled()
                                #else
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                #endif
                                .onChange(of: serverEndpoint) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "dashboard_server_endpoint")
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key (Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                if showingAPIKey {
                                    TextField("your-api-key-here", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                        #if os(macOS)
                                        .autocorrectionDisabled()
                                        #else
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        #endif
                                        .onChange(of: apiKey) { newValue in
                                            KeychainHelper.save(key: "dashboard_api_key", value: newValue)
                                        }
                                } else {
                                    SecureField("your-api-key-here", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                        #if os(macOS)
                                        .autocorrectionDisabled()
                                        #else
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        #endif
                                        .onChange(of: apiKey) { newValue in
                                            KeychainHelper.save(key: "dashboard_api_key", value: newValue)
                                        }
                                }

                                Button {
                                    showingAPIKey.toggle()
                                } label: {
                                    Image(systemName: showingAPIKey ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        // Connection Status
                        HStack(spacing: 8) {
                            Circle()
                                .fill(httpClient.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)

                            Text(httpClient.isConnected ? "Connected" : "Not Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let lastSync = httpClient.lastSyncDate {
                                Text("• Last sync: \(lastSync, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Test Connection Button
                            Button {
                                testConnection()
                            } label: {
                                HStack(spacing: 4) {
                                    if testingConnection {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                    }
                                    Text("Test")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .disabled(serverEndpoint.isEmpty || testingConnection)
                        }

                        if showTestResult && !testResult.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: httpClient.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(httpClient.isConnected ? .green : .red)
                                Text(testResult)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(white: 0.5, opacity: 0.05))
                            )
                        }
                    }
                    .padding(8)
                }

                // Schedule Configuration
                GroupBox(label: Label("Schedule", systemImage: "clock.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Send report daily at:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            // Hour picker
                            Picker("Hour", selection: $scheduleConfig.selectedHour) {
                                ForEach(scheduleConfig.hours, id: \.self) { hour in
                                    Text(String(format: "%02d", hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)

                            Text(":")

                            // Minute picker
                            Picker("Minute", selection: $scheduleConfig.selectedMinute) {
                                ForEach(scheduleConfig.minutes, id: \.self) { minute in
                                    Text(String(format: "%02d", minute)).tag(minute)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)

                            Button("Update") {
                                scheduleConfig.updateSchedule()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!dashboardEnabled)
                        }

                        if let nextReport = scheduler.nextReportTime {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.accentColor)
                                Text("Next report: \(nextReport, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if httpClient.queuedReportsCount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "tray.full")
                                    .foregroundColor(.orange)
                                Text("\(httpClient.queuedReportsCount) reports queued for retry")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await scheduler.sendNow()
                        }
                    } label: {
                        Label("Send Now", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(serverEndpoint.isEmpty || !dashboardEnabled)

                    Button {
                        showingReportPreview = true
                    } label: {
                        Label("Preview Report", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                }

                if let error = httpClient.lastError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }

            // Info Footer
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Reports include plugin statistics, usage metrics, and device info. No personal data is sent.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingReportPreview) {
            DashboardReportPreviewView()
        }
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - Actions

    func testConnection() {
        testingConnection = true
        testResult = ""
        showTestResult = false

        Task {
            let result = await httpClient.testConnection()

            await MainActor.run {
                testingConnection = false
                showTestResult = true

                switch result {
                case .success(let message): 
                    testResult = message
                case .failure(let error): 
                    testResult = error.localizedDescription
                }
            }
        }
    }

    private func loadSettings() {
        serverEndpoint = UserDefaults.standard.string(forKey: "dashboard_server_endpoint") ?? ""
        apiKey = KeychainHelper.load(key: "dashboard_api_key") ?? ""
        dashboardEnabled = UserDefaults.standard.bool(forKey: "dashboard_enabled")
    }
}

// MARK: - Preview

#Preview {
    DashboardSettingsView()
        .frame(width: 600)
}