import Foundation

public enum Humanize {
    nonisolated private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    nonisolated public static func date(_ d: Date?) -> String {
        guard let d else { return "" }
        return dateFormatter.string(from: d)
    }

    public static func bytes(_ n: Int64?) -> String {
        guard let n else { return "" }
        if n < 1024 { return "\(n) B" }
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var v = Double(n); var i = -1
        repeat { v /= 1024; i += 1 } while v >= 1024 && i < units.count - 1
        let s = String(format: v >= 10 ? "%.0f" : "%.1f", v)
        return "\(s) \(units[i])"
    }
}
