import Foundation
import Combine

// MARK: - Dashboard HTTP Client

/// Handles sending dashboard reports to server with offline queuing and retry logic
@MainActor
class DashboardHTTPClient: ObservableObject {

    // MARK: - Published State

    @Published var isConnected: Bool = false
    @Published var lastSyncDate: Date?
    @Published var queuedReportsCount: Int = 0
    @Published var lastError: String?

    // MARK: - Configuration

    private let maxRetries = 3
    private let retryDelay: TimeInterval = 5.0
    private let queueKey = "dashboard_report_queue"
    private let lastSyncKey = "dashboard_last_sync"

    // MARK: - Singleton

    static let shared = DashboardHTTPClient()

    private init() {
        _ = loadQueuedReports()
        loadLastSyncDate()
    }

    // MARK: - Public API

    /// Send a dashboard report to the configured server endpoint
    func sendReport(_ report: DashboardReport) async {
        // Load configuration
        guard let config = loadConfiguration() else {
            lastError = "Server endpoint not configured"
            AppLogger.error("Dashboard: Server endpoint not configured")
            return
        }

        guard config.enabled else {
            AppLogger.info("Dashboard: Reporting disabled in settings")
            return
        }

        // Try to send immediately
        let success = await attemptSend(report: report, config: config)

        if success {
            isConnected = true
            lastSyncDate = Date()
            saveLastSyncDate()
            lastError = nil

            // Process any queued reports
            await processQueue(config: config)
        } else {
            isConnected = false
            // Queue for later if offline
            queueReport(report)
        }
    }

    /// Test connection to server (for settings UI)
    func testConnection() async -> Result<String, Error> {
        guard let config = loadConfiguration() else {
            return .failure(DashboardError.notConfigured)
        }

        // Create a minimal test report
        let testReport = DashboardReport(
            timestamp: Date(),
            deviceInfo: DashboardReport.DeviceInfo(
                deviceModel: "Test",
                osVersion: "Test",
                architecture: "Test",
                memory: "Test",
                screenResolution: nil
            ),
            appInfo: DashboardReport.AppInfo(
                version: "Test",
                build: "Test",
                installDate: nil,
                lastLaunchDate: Date(),
                totalLaunches: 0
            ),
            pluginStats: DashboardReport.PluginStats(
                totalPlugins: 0,
                pluginsByFormat: [:],
                pluginsByPublisher: [:],
                pluginsByStyle: [:],
                obsoletePlugins: 0,
                totalSizeBytes: 0,
                averageSizeBytes: 0
            ),
            usageMetrics: DashboardReport.UsageMetrics(
                scansPerformed: 0,
                exportsPerformed: 0,
                aiSuggestionsRequested: 0,
                averageSessionDuration: 0,
                lastScanDate: nil,
                lastExportDate: nil
            ),
            errorLogs: []
        )

        do {
            let response = try await sendHTTPRequest(report: testReport, config: config)
            isConnected = true
            return .success("Connected successfully! Status: \(response.statusCode)")
        } catch {
            isConnected = false
            return .failure(error)
        }
    }

    /// Process any queued reports (call this when connectivity is restored)
    func processQueuedReports() async {
        guard let config = loadConfiguration(), config.enabled else { return }
        await processQueue(config: config)
    }

    // MARK: - Private Implementation

    private func attemptSend(report: DashboardReport, config: DashboardConfiguration, retryCount: Int = 0) async -> Bool {
        do {
            _ = try await sendHTTPRequest(report: report, config: config)
            AppLogger.info("Dashboard: Report sent successfully")
            return true
        } catch {
            AppLogger.error("Dashboard: Send failed (attempt \(retryCount + 1)/\(maxRetries)): \(error.localizedDescription)")

            if retryCount < maxRetries {
                // Wait and retry
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                return await attemptSend(report: report, config: config, retryCount: retryCount + 1)
            } else {
                lastError = error.localizedDescription
                return false
            }
        }
    }

    private func sendHTTPRequest(report: DashboardReport, config: DashboardConfiguration) async throws -> HTTPResponse {
        guard let url = URL(string: config.serverEndpoint) else {
            throw DashboardError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication if configured
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Encode report as JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(report)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DashboardError.invalidResponse
        }

        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DashboardError.serverError(code: httpResponse.statusCode, message: errorMessage)
        }

        return HTTPResponse(statusCode: httpResponse.statusCode, data: data)
    }

    // MARK: - Offline Queue Management

    private func queueReport(_ report: DashboardReport) {
        var queue = loadQueuedReports()
        queue.append(report)

        // Limit queue size to prevent storage bloat
        if queue.count > 10 {
            queue = Array(queue.suffix(10))
        }

        saveQueuedReports(queue)
        queuedReportsCount = queue.count

        AppLogger.info("Dashboard: Report queued (total: \(queue.count))")
    }

    private func processQueue(config: DashboardConfiguration) async {
        var queue = loadQueuedReports()
        guard !queue.isEmpty else { return }

        AppLogger.info("Dashboard: Processing \(queue.count) queued reports")

        var processedIndices: [Int] = []

        for (index, report) in queue.enumerated() {
            let success = await attemptSend(report: report, config: config)
            if success {
                processedIndices.append(index)
            } else {
                // Stop processing on first failure to preserve order
                break
            }
        }

        // Remove successfully sent reports
        for index in processedIndices.reversed() {
            queue.remove(at: index)
        }

        saveQueuedReports(queue)
        queuedReportsCount = queue.count

        if !queue.isEmpty {
            AppLogger.warning("Dashboard: \(queue.count) reports remain queued")
        }
    }

    private func loadQueuedReports() -> [DashboardReport] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let reports = try? JSONDecoder().decode([DashboardReport].self, from: data) else {
            return []
        }
        return reports
    }

    private func saveQueuedReports(_ reports: [DashboardReport]) {
        if let encoded = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(encoded, forKey: queueKey)
        }
    }

    // MARK: - Configuration Management

    private func loadConfiguration() -> DashboardConfiguration? {
        guard let serverEndpoint = UserDefaults.standard.string(forKey: "dashboard_server_endpoint"),
              !serverEndpoint.isEmpty else {
            return nil
        }

        let enabled = UserDefaults.standard.bool(forKey: "dashboard_enabled")

        // Load API key from Keychain
        let apiKey = KeychainHelper.load(key: "dashboard_api_key") ?? ""

        return DashboardConfiguration(
            serverEndpoint: serverEndpoint,
            apiKey: apiKey,
            enabled: enabled
        )
    }

    // MARK: - Last Sync Tracking

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
    }
}

// MARK: - Supporting Types

struct DashboardConfiguration {
    let serverEndpoint: String
    let apiKey: String
    let enabled: Bool
}

struct HTTPResponse {
    let statusCode: Int
    let data: Data
}

enum DashboardError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case serverError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server endpoint not configured"
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        }
    }
}
