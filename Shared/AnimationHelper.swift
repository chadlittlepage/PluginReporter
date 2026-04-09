import SwiftUI

/// Accessibility-aware animation wrapper.
///
/// Honors the user's "Reduce Motion" system setting: when enabled, animations
/// are returned as `nil` (or executed without animation), so callers don't have
/// to branch on `reduceMotion` everywhere.
enum AnimationHelper {

    // MARK: - Animation factories

    /// A snappy spring used for most UI state transitions. Returns `nil` when
    /// reduce-motion is on so SwiftUI applies the change instantly.
    static func snappy(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .snappy(duration: 0.25, extraBounce: 0.0)
    }

    /// A standard spring suitable for list inserts/removes.
    static func spring(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    // MARK: - withAnimation helpers

    /// Run `body` inside `withAnimation` using a caller-provided animation,
    /// or with no animation if reduce-motion is enabled.
    @discardableResult
    static func withAnimation<Result>(
        _ reduceMotion: Bool,
        _ animation: Animation,
        _ body: () throws -> Result
    ) rethrows -> Result {
        if reduceMotion {
            return try body()
        } else {
            return try SwiftUI.withAnimation(animation, body)
        }
    }

    /// Convenience: run `body` with the standard spring animation.
    @discardableResult
    static func withSpringAnimation<Result>(
        _ reduceMotion: Bool,
        _ body: () throws -> Result
    ) rethrows -> Result {
        try withAnimation(reduceMotion, .spring(response: 0.35, dampingFraction: 0.85), body)
    }

    /// Convenience: run `body` with the snappy animation.
    @discardableResult
    static func withSnappyAnimation<Result>(
        _ reduceMotion: Bool,
        _ body: () throws -> Result
    ) rethrows -> Result {
        try withAnimation(reduceMotion, .snappy(duration: 0.25, extraBounce: 0.0), body)
    }
}
