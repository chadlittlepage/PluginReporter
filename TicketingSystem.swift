import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Handles bug reports and feature requests via mailto: links
public struct TicketingSystem {

    // MARK: - Configuration

    /// Email address to receive bug reports and feature requests
    private static let supportEmail = "support@yourapp.com" // Change this to your email

    // MARK: - Public API

    /// Opens default mail client with pre-filled bug report
    public static func reportBug() {
        let deviceInfo = collectDeviceInfo()
        let crashLog = collectRecentCrashLog()

        let subject = "Bug Report - Plugin Reporter"

        var body = """
        Please describe the bug you encountered:



        ---
        Device Information:
        \(deviceInfo)

        """

        if !crashLog.isEmpty {
            body += """
            Recent Crash Log:
            \(crashLog)

            """
        }

        openMailClient(subject: subject, body: body)
    }

    /// Opens default mail client with pre-filled feature request
    public static func requestFeature() {
        let deviceInfo = collectDeviceInfo()

        let subject = "Feature Request - Plugin Reporter"

        let body = """
        Please describe the feature you would like to see:



        ---
        Device Information:
        \(deviceInfo)
        """

        openMailClient(subject: subject, body: body)
    }

    // MARK: - Device Information Collection

    private static func collectDeviceInfo() -> String {
        var info: [String] = []

        #if os(macOS)
        // macOS specific info
        let processInfo = ProcessInfo.processInfo

        // Device model
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model)

        info.append("Device: \(modelString)")
        info.append("OS: macOS \(processInfo.operatingSystemVersionString)")
        info.append("App Version: \(appVersion())")

        // Processor info
        var cpuSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &cpuSize, nil, 0)
        var cpu = [CChar](repeating: 0, count: cpuSize)
        sysctlbyname("machdep.cpu.brand_string", &cpu, &cpuSize, nil, 0)
        let cpuString = String(cString: cpu)
        info.append("Processor: \(cpuString)")

        // Memory
        var memSize: UInt64 = 0
        var memSizeLen = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeLen, nil, 0)
        let memGB = Double(memSize) / 1_073_741_824.0
        info.append("Memory: \(String(format: "%.1f", memGB)) GB")

        #elseif os(iOS)
        // iOS/iPadOS specific info
        let device = UIDevice.current

        // Device model (gets actual model like "iPhone 15 Pro" or "iPad Pro 12.9-inch")
        let modelName = deviceModelName()
        info.append("Device: \(modelName)")
        info.append("OS: \(device.systemName) \(device.systemVersion)")
        info.append("App Version: \(appVersion())")

        // Screen size
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        info.append("Screen: \(Int(bounds.width * scale))x\(Int(bounds.height * scale)) @\(Int(scale))x")

        // Memory (approximate)
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memGB = Double(physicalMemory) / 1_073_741_824.0
        info.append("Memory: \(String(format: "%.1f", memGB)) GB")

        #endif

        // Build info
        info.append("Build: \(buildNumber())")

        return info.joined(separator: "\n")
    }

    #if os(iOS)
    /// Returns human-readable device model name
    private static func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Map identifiers to human-readable names
        switch identifier {
        // iPhone models
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"

        // iPad models
        case "iPad13,18", "iPad13,19": return "iPad (10th generation)"
        case "iPad14,3", "iPad14,4": return "iPad Pro 11-inch (4th generation)"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9-inch (6th generation)"
        case "iPad14,8", "iPad14,9": return "iPad Pro 11-inch (M4)"
        case "iPad14,10", "iPad14,11": return "iPad Pro 13-inch (M4)"
        case "iPad13,16", "iPad13,17": return "iPad Air (5th generation)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th generation)"

        // Simulators
        case "i386", "x86_64", "arm64":
            if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
                return deviceModelName(for: simulatorModel) + " (Simulator)"
            }
            return "iOS Simulator"

        default:
            return identifier
        }
    }

    private static func deviceModelName(for identifier: String) -> String {
        // Recursive call for simulator models
        switch identifier {
        case "iPhone14,7": return "iPhone 14"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPad14,3": return "iPad Pro 11-inch (4th gen)"
        case "iPad14,5": return "iPad Pro 12.9-inch (6th gen)"
        default: return identifier
        }
    }
    #endif

    // MARK: - Crash Log Collection

    private static func collectRecentCrashLog() -> String {
        #if os(macOS)
        return collectMacOSCrashLog()
        #elseif os(iOS)
        return collectiOSCrashLog()
        #else
        return ""
        #endif
    }

    #if os(macOS)
    private static func collectMacOSCrashLog() -> String {
        // Try to find recent crash logs in ~/Library/Logs/DiagnosticReports/
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let diagnosticReportsDir = homeDir.appendingPathComponent("Library/Logs/DiagnosticReports")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diagnosticReportsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ""
        }

        // Find crash logs for our app from the last 7 days
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "PluginReporter"
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

        let recentCrashes = files.filter { url in
            guard url.lastPathComponent.contains(appName) else { return false }
            guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey]) else { return false }
            guard let creationDate = resourceValues.creationDate else { return false }
            return creationDate > sevenDaysAgo
        }.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        }

        guard let mostRecent = recentCrashes.first else {
            return ""
        }

        // Read the crash log (limit to first 100 lines to avoid huge emails)
        guard let crashContent = try? String(contentsOf: mostRecent) else {
            return ""
        }

        let lines = crashContent.components(separatedBy: .newlines)
        let limitedLines = lines.prefix(100).joined(separator: "\n")

        return """
        Found recent crash: \(mostRecent.lastPathComponent)

        \(limitedLines)

        [Crash log truncated to 100 lines]
        """
    }
    #endif

    #if os(iOS)
    private static func collectiOSCrashLog() -> String {
        // iOS apps don't have direct access to crash logs
        // But we can include any app-specific error logs if we implement logging
        return "(iOS crash logs are not directly accessible. Please describe what happened before the crash.)"
    }
    #endif

    // MARK: - App Version Info

    private static func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        return version
    }

    private static func buildNumber() -> String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return build
    }

    // MARK: - Mail Client Integration

    private static func openMailClient(subject: String, body: String) {
        // URL encode the subject and body
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            AppLogger.error("Failed to encode email parameters")
            return
        }

        let mailtoString = "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"

        guard let mailtoURL = URL(string: mailtoString) else {
            AppLogger.error("Failed to create mailto URL")
            return
        }

        #if os(macOS)
        NSWorkspace.shared.open(mailtoURL)
        #elseif os(iOS)
        UIApplication.shared.open(mailtoURL, options: [:]) { success in
            if !success {
                AppLogger.error("Failed to open mail client")
            }
        }
        #endif
    }
}
