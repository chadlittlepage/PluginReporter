import Foundation

/// Translates raw `Error` values into messages safe to show end users,
/// plus richer technical strings suitable for logs and bug reports.
enum UserFriendlyError {

    // MARK: - User-facing messages

    /// Message for export failures (CSV / JSON / HTML / PDF / archive).
    static func exportMessage(for error: Error, format: String) -> String {
        let base = "Couldn't export your \(format) file."
        return "\(base) \(suggestion(for: error))"
    }

    /// Message for import failures.
    static func importMessage(for error: Error, source: String) -> String {
        let base = "Couldn't import from \(source)."
        return "\(base) \(suggestion(for: error))"
    }

    /// Message for CloudKit / iCloud sync failures.
    static func syncMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain.contains("CloudKit") {
            return "iCloud sync isn't available right now. Your changes are saved locally and will sync automatically when iCloud is reachable."
        }
        return "iCloud sync hit a problem. \(suggestion(for: error))"
    }

    // MARK: - Technical details (logs / bug reports)

    /// Verbose, developer-oriented description for `AppLogger` and bug reports.
    static func technicalDetails(for error: Error) -> String {
        let nsError = error as NSError
        var parts: [String] = []
        parts.append("domain=\(nsError.domain)")
        parts.append("code=\(nsError.code)")
        parts.append("desc=\(nsError.localizedDescription)")
        if let reason = nsError.localizedFailureReason {
            parts.append("reason=\(reason)")
        }
        if let suggestion = nsError.localizedRecoverySuggestion {
            parts.append("suggestion=\(suggestion)")
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying=(\(underlying.domain):\(underlying.code) \(underlying.localizedDescription))")
        }
        return parts.joined(separator: " | ")
    }

    // MARK: - Private

    private static func suggestion(for error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case NSFileWriteOutOfSpaceError:
            return "Your disk is full — free up space and try again."
        case NSFileWriteNoPermissionError, NSFileReadNoPermissionError:
            return "Plugin Reporter doesn't have permission to access that location. Choose a different folder and try again."
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
            return "The file couldn't be found. It may have been moved or deleted."
        default:
            return "Please try again. If the problem keeps happening, send a bug report from Settings."
        }
    }
}
