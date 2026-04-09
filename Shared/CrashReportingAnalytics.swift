import Foundation

/// Singleton that owns the user's crash-reporting / analytics opt-in state
/// and decides whether to surface the opt-in prompt at launch.
final class CrashReportingAnalytics {

    static let shared = CrashReportingAnalytics()

    // MARK: - Persisted preference keys

    private enum Key {
        static let enabled = "crashReporting.isEnabled"
        static let promptShown = "crashReporting.optInPromptShown"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public state

    /// Whether the user has opted in to crash reporting. Persisted in `UserDefaults`.
    var isCrashReportingEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set {
            defaults.set(newValue, forKey: Key.enabled)
            // Once the user makes a choice (either way), don't prompt again.
            defaults.set(true, forKey: Key.promptShown)
        }
    }

    /// True if the opt-in prompt has already been shown to the user.
    var hasShownOptInPrompt: Bool {
        defaults.bool(forKey: Key.promptShown)
    }

    // MARK: - Prompt gating

    /// If the user hasn't seen the prompt yet, request that the app show it.
    /// `PluginReporterApp` observes `.showCrashReportingPrompt` and presents
    /// `CrashReportingPromptView` in an `NSHostingView`.
    func showOptInPromptIfNeeded() {
        guard !hasShownOptInPrompt else { return }
        NotificationCenter.default.post(name: .showCrashReportingPrompt, object: nil)
    }

    /// Mark the prompt as shown without changing the opt-in value (used when
    /// the user dismisses without making an explicit choice).
    func markPromptShown() {
        defaults.set(true, forKey: Key.promptShown)
    }

    // MARK: - Event tracking

    /// Record that the user submitted a bug report. No-op when the user has
    /// not opted in to crash reporting.
    func trackBugReportSubmitted(includedCrashLog: Bool) {
        guard isCrashReportingEnabled else { return }
        // Hook for whatever analytics backend the app uses (Sentry, Firebase, etc.).
        // Intentionally minimal — wire up the real call site when integrating.
        AppLogger.info("Bug report submitted (crashLog=\(includedCrashLog))")
    }
}

extension Notification.Name {
    /// Posted by `CrashReportingAnalytics` to ask the app to display the
    /// crash-reporting opt-in prompt.
    static let showCrashReportingPrompt = Notification.Name("CrashReportingAnalytics.showCrashReportingPrompt")
}
