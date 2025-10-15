import Foundation
import Combine

// MARK: - Dashboard Scheduler

/// Manages daily dashboard report scheduling with custom time selection
@MainActor
class DashboardScheduler: ObservableObject {

    // MARK: - Published State

    @Published var isScheduled: Bool = false
    @Published var nextReportTime: Date?
    @Published var reportHour: Int = 9  // Default 9 AM
    @Published var reportMinute: Int = 0  // Default 9:00 AM

    // MARK: - Private State

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let checkInterval: TimeInterval = 60 // Check every minute

    // MARK: - Dependencies

    private let httpClient: DashboardHTTPClient
    private var plugins: [PluginItem] = []

    // MARK: - Singleton

    static let shared = DashboardScheduler()

    private init(httpClient: DashboardHTTPClient = .shared) {
        self.httpClient = httpClient
        loadScheduleSettings()
        startScheduler()
    }

    // MARK: - Public API

    /// Update the plugin list (call this after scanning)
    func updatePlugins(_ plugins: [PluginItem]) {
        self.plugins = plugins
    }

    /// Start the scheduler
    func start() {
        guard !isScheduled else { return }
        startScheduler()
        isScheduled = true
        saveScheduleSettings()
        AppLogger.info("Dashboard: Scheduler started (reports at \(reportHour):\(String(format: "%02d", reportMinute)))")
    }

    /// Stop the scheduler
    func stop() {
        timer?.invalidate()
        timer = nil
        isScheduled = false
        nextReportTime = nil
        saveScheduleSettings()
        AppLogger.info("Dashboard: Scheduler stopped")
    }

    /// Update the scheduled time
    func setScheduledTime(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            AppLogger.error("Dashboard: Invalid time \(hour):\(minute)")
            return
        }

        reportHour = hour
        reportMinute = minute
        saveScheduleSettings()

        if isScheduled {
            // Restart scheduler with new time
            stop()
            start()
        }

        AppLogger.info("Dashboard: Schedule time updated to \(hour):\(String(format: "%02d", minute))")
    }

    /// Send report immediately (manual trigger)
    func sendNow() async {
        AppLogger.info("Dashboard: Manual report triggered")
        await generateAndSendReport()
    }

    // MARK: - Private Implementation

    private func startScheduler() {
        // Calculate next report time
        calculateNextReportTime()

        // Start timer to check every minute
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndSendReport()
            }
        }
        timer?.tolerance = 10  // Allow 10 second tolerance for battery efficiency

        AppLogger.info("Dashboard: Timer started, next report at \(nextReportTime?.formatted() ?? "unknown")")
    }

    private func checkAndSendReport() async {
        guard let nextReport = nextReportTime else {
            calculateNextReportTime()
            return
        }

        let now = Date()

        // Check if it's time to send report (within the check interval)
        if now >= nextReport {
            AppLogger.info("Dashboard: Scheduled report time reached")
            await generateAndSendReport()

            // Calculate next report time (tomorrow)
            calculateNextReportTime()
        }
    }

    private func generateAndSendReport() async {
        // Build comprehensive report
        let report = DashboardReportBuilder.buildReport(plugins: plugins)

        // Send via HTTP client
        await httpClient.sendReport(report)
    }

    private func calculateNextReportTime() {
        let now = Date()
        let calendar = Calendar.current

        // Create components for today at scheduled time
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = reportHour
        components.minute = reportMinute
        components.second = 0

        guard let todayAtScheduledTime = calendar.date(from: components) else {
            AppLogger.error("Dashboard: Failed to calculate next report time")
            return
        }

        // If today's scheduled time has passed, schedule for tomorrow
        if todayAtScheduledTime <= now {
            nextReportTime = calendar.date(byAdding: .day, value: 1, to: todayAtScheduledTime)
        } else {
            nextReportTime = todayAtScheduledTime
        }

        AppLogger.info("Dashboard: Next report scheduled for \(nextReportTime?.formatted() ?? "unknown")")
    }

    // MARK: - Persistence

    private func loadScheduleSettings() {
        let defaults = UserDefaults.standard

        isScheduled = defaults.bool(forKey: "dashboard_scheduled")
        reportHour = defaults.integer(forKey: "dashboard_report_hour")
        reportMinute = defaults.integer(forKey: "dashboard_report_minute")

        // Set defaults if not configured
        if reportHour == 0 && reportMinute == 0 && !defaults.bool(forKey: "dashboard_time_configured") {
            reportHour = 9  // Default to 9 AM
            reportMinute = 0
        }
    }

    private func saveScheduleSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isScheduled, forKey: "dashboard_scheduled")
        defaults.set(reportHour, forKey: "dashboard_report_hour")
        defaults.set(reportMinute, forKey: "dashboard_report_minute")
        defaults.set(true, forKey: "dashboard_time_configured")
    }
}

// MARK: - Schedule Configuration View Model

@MainActor
class ScheduleConfigViewModel: ObservableObject {
    @Published var selectedHour: Int = 9
    @Published var selectedMinute: Int = 0

    private let scheduler: DashboardScheduler

    init(scheduler: DashboardScheduler = .shared) {
        self.scheduler = scheduler
        self.selectedHour = scheduler.reportHour
        self.selectedMinute = scheduler.reportMinute
    }

    func updateSchedule() {
        scheduler.setScheduledTime(hour: selectedHour, minute: selectedMinute)
    }

    var formattedTime: String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = selectedHour
        components.minute = selectedMinute

        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "\(selectedHour):\(String(format: "%02d", selectedMinute))"
    }

    var hours: [Int] { Array(0...23) }
    var minutes: [Int] { Array(stride(from: 0, to: 60, by: 5)) }  // 5-minute intervals
}
