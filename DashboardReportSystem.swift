import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Dashboard Report Models

/// Comprehensive dashboard report sent daily to server
struct DashboardReport: Codable {
    let timestamp: Date
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
    let pluginStats: PluginStats
    let usageMetrics: UsageMetrics
    let errorLogs: [ErrorLog]

    struct DeviceInfo: Codable {
        let deviceModel: String
        let osVersion: String
        let architecture: String
        let memory: String
        let screenResolution: String?
    }

    struct AppInfo: Codable {
        let version: String
        let build: String
        let installDate: Date?
        let lastLaunchDate: Date
        let totalLaunches: Int
    }

    struct PluginStats: Codable {
        let totalPlugins: Int
        let pluginsByFormat: [String: Int]  // e.g., "AU": 150, "VST3": 200
        let pluginsByPublisher: [String: Int]  // Top 10 publishers
        let pluginsByStyle: [String: Int]  // e.g., "EQ": 25, "Reverb": 30
        let obsoletePlugins: Int
        let totalSizeBytes: Int64
        let averageSizeBytes: Int64
    }

    struct UsageMetrics: Codable {
        let scansPerformed: Int
        let exportsPerformed: Int
        let aiSuggestionsRequested: Int
        let averageSessionDuration: TimeInterval
        let lastScanDate: Date?
        let lastExportDate: Date?
    }

    struct ErrorLog: Codable {
        let timestamp: Date
        let message: String
        let severity: String  // "error", "warning", "info"
        let context: String?
    }
}

// MARK: - Dashboard Report Builder

enum DashboardReportBuilder {

    /// Build a comprehensive dashboard report
    static func buildReport(plugins: [PluginItem]) -> DashboardReport {
        return DashboardReport(
            timestamp: Date(), deviceInfo: collectDeviceInfo(), appInfo: collectAppInfo(), pluginStats: collectPluginStats(plugins: plugins), usageMetrics: collectUsageMetrics(), errorLogs: collectErrorLogs()
        )
    }

    // MARK: - Device Information

    private static func collectDeviceInfo() -> DashboardReport.DeviceInfo {
        #if os(macOS)
        return collectMacOSDeviceInfo()
        #elseif os(iOS)
        return collectiOSDeviceInfo()
        #endif
    }

    #if os(macOS)
    private static func collectMacOSDeviceInfo() -> DashboardReport.DeviceInfo {
        let processInfo = ProcessInfo.processInfo

        // Device model
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model)

        // Architecture
        var archSize = 0
        sysctlbyname("hw.machine", nil, &archSize, nil, 0)
        var arch = [CChar](repeating: 0, count: archSize)
        sysctlbyname("hw.machine", &arch, &archSize, nil, 0)
        let archString = String(cString: arch)

        // Memory
        var memSize: UInt64 = 0
        var memSizeLen = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeLen, nil, 0)
        let memGB = Double(memSize) / 1_073_741_824.0

        return DashboardReport.DeviceInfo(
            deviceModel: modelString, osVersion: "macOS \(processInfo.operatingSystemVersionString)", architecture: archString, memory: String(format: "%.1f GB", memGB), screenResolution: nil
        )
    }
    #endif

    #if os(iOS)
    private static func collectiOSDeviceInfo() -> DashboardReport.DeviceInfo {
        let device = UIDevice.current
        let modelName = deviceModelName()

        // Memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memGB = Double(physicalMemory) / 1_073_741_824.0

        // Screen
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        let resolution = "\(Int(bounds.width * scale))x\(Int(bounds.height * scale)) @\(Int(scale))x"

        return DashboardReport.DeviceInfo(
            deviceModel: modelName, osVersion: "\(device.systemName) \(device.systemVersion)", architecture: architectureString(), memory: String(format: "%.1f GB", memGB), screenResolution: resolution
        )
    }

    private static func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private static func architectureString() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
    #endif

    // MARK: - App Information

    private static func collectAppInfo() -> DashboardReport.AppInfo {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        let defaults = UserDefaults.standard
        let installDate = defaults.object(forKey: "app_install_date") as? Date
        let lastLaunchDate = defaults.object(forKey: "app_last_launch") as? Date ?? Date()
        let totalLaunches = defaults.integer(forKey: "app_total_launches")

        // Update launch tracking
        defaults.set(Date(), forKey: "app_last_launch")
        defaults.set(totalLaunches + 1, forKey: "app_total_launches")
        if installDate == nil {
            defaults.set(Date(), forKey: "app_install_date")
        }

        return DashboardReport.AppInfo(
            version: version, build: build, installDate: installDate, lastLaunchDate: lastLaunchDate, totalLaunches: totalLaunches
        )
    }

    // MARK: - Plugin Statistics

    private static func collectPluginStats(plugins: [PluginItem]) -> DashboardReport.PluginStats {
        let totalPlugins = plugins.count

        // Group by format
        var byFormat: [String: Int] = [:]
        for plugin in plugins {
            byFormat[plugin.type, default: 0] += 1
        }

        // Group by publisher (top 10)
        var byPublisher: [String: Int] = [:]
        for plugin in plugins {
            let publisher = plugin.publisher.isEmpty ? "Unknown" : plugin.publisher
            byPublisher[publisher, default: 0] += 1
        }
        let sortedPublishers = byPublisher.sorted { $0.value > $1.value }
        let topPublishers = Dictionary(
            uniqueKeysWithValues: Array(sortedPublishers.prefix(10))
        )

        // Group by style
        var byStyle: [String: Int] = [:]
        for plugin in plugins {
            if !plugin.style.isEmpty {
                byStyle[plugin.style, default: 0] += 1
            }
        }

        // Count obsolete
        let obsoleteCount = plugins.filter { $0.obsolete }.count

        // Calculate sizes
        let totalSize = plugins.reduce(0) { $0 + $1.sizeBytes }
        let avgSize = totalPlugins > 0 ? totalSize / Int64(totalPlugins) : 0

        return DashboardReport.PluginStats(
            totalPlugins: totalPlugins, pluginsByFormat: byFormat, pluginsByPublisher: topPublishers, pluginsByStyle: byStyle, obsoletePlugins: obsoleteCount, totalSizeBytes: totalSize, averageSizeBytes: avgSize
        )
    }

    // MARK: - Usage Metrics

    private static func collectUsageMetrics() -> DashboardReport.UsageMetrics {
        let defaults = UserDefaults.standard

        let scansPerformed = defaults.integer(forKey: "usage_scans_performed")
        let exportsPerformed = defaults.integer(forKey: "usage_exports_performed")
        let aiRequests = defaults.integer(forKey: "usage_ai_requests")
        let avgDuration = defaults.double(forKey: "usage_avg_session_duration")
        let lastScan = defaults.object(forKey: "usage_last_scan") as? Date
        let lastExport = defaults.object(forKey: "usage_last_export") as? Date

        return DashboardReport.UsageMetrics(
            scansPerformed: scansPerformed, exportsPerformed: exportsPerformed, aiSuggestionsRequested: aiRequests, averageSessionDuration: avgDuration, lastScanDate: lastScan, lastExportDate: lastExport
        )
    }

    // MARK: - Error Logs

    private static func collectErrorLogs() -> [DashboardReport.ErrorLog] {
        // Retrieve stored error logs (last 24 hours)
        guard let logsData = UserDefaults.standard.data(forKey: "error_logs"), let allLogs = try? JSONDecoder().decode([DashboardReport.ErrorLog].self, from: logsData) else {
            return []
        }

        // Filter to last 24 hours
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        return allLogs.filter { $0.timestamp > yesterday }
    }

}

// MARK: - Usage Tracking Helpers (Standalone Functions)

func dashboardTrackScan() {
    let defaults = UserDefaults.standard
    let count = defaults.integer(forKey: "usage_scans_performed")
    defaults.set(count + 1, forKey: "usage_scans_performed")
    defaults.set(Date(), forKey: "usage_last_scan")
}

func dashboardTrackExport() {
    let defaults = UserDefaults.standard
    let count = defaults.integer(forKey: "usage_exports_performed")
    defaults.set(count + 1, forKey: "usage_exports_performed")
    defaults.set(Date(), forKey: "usage_last_export")
}

func dashboardTrackAIRequest() {
    let defaults = UserDefaults.standard
    let count = defaults.integer(forKey: "usage_ai_requests")
    defaults.set(count + 1, forKey: "usage_ai_requests")
}

func dashboardLogEvent(event: String, properties: [String: Any]) {
    // Log custom events with properties
    AppLogger.info("Dashboard event: \(event) with properties: \(properties)")

    // Store event in UserDefaults for dashboard reporting
    var events: [[String: Any]] = []
    if let eventsData = UserDefaults.standard.data(forKey: "dashboard_events"), let existingEvents = try? JSONSerialization.jsonObject(with: eventsData) as? [[String: Any]] {
        events = existingEvents
    }

    var eventData: [String: Any] = properties
    eventData["event"] = event
    eventData["timestamp"] = ISO8601DateFormatter().string(from: Date())
    events.append(eventData)

    // Keep only last 100 events
    if events.count > 100 {
        events = Array(events.suffix(100))
    }

    if let data = try? JSONSerialization.data(withJSONObject: events) {
        UserDefaults.standard.set(data, forKey: "dashboard_events")
    }
}

func dashboardLogError(message: String, severity: String = "error", context: String? = nil) {
    let errorLog = DashboardReport.ErrorLog(
        timestamp: Date(), message: message, severity: severity, context: context
    )

    var logs: [DashboardReport.ErrorLog] = []
    if let logsData = UserDefaults.standard.data(forKey: "error_logs"), let existingLogs = try? JSONDecoder().decode([DashboardReport.ErrorLog].self, from: logsData) {
        logs = existingLogs
    }

    logs.append(errorLog)

    if logs.count > 100 {
        logs = Array(logs.suffix(100))
    }

    if let encoded = try? JSONEncoder().encode(logs) {
        UserDefaults.standard.set(encoded, forKey: "error_logs")
    }
}