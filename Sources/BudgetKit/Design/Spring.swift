// Copied from Brimlight (Sources/NotchKit/Motion/Spring.swift) on 2026-10-19; changes marked "Budget:".
import Foundation

/// One damped spring in Apple's designer terms: `response` is roughly how long
/// it takes to arrive, and `damping` 1.0 means no overshoot.
public struct Spring: Sendable, Equatable {
    public var value: Double
    public var velocity: Double = 0
    public var target: Double

    public init(_ value: Double) {
        self.value = value
        self.target = value
    }

    /// Advance by `dt` seconds. A frame is capped at 1/30 s so a long gap
    /// (sleep, a paused timeline) cannot teleport the value, and sub-stepped
    /// at 480 Hz so stiff springs stay stable.
    public mutating func step(dt: Double, response: Double, damping: Double) {
        let r = max(response, 0.05)
        let stiffness = pow(2 * .pi / r, 2)
        let friction = 4 * .pi * damping / r
        var remaining = min(max(dt, 0), 1.0 / 30)
        while remaining > 0 {
            let h = min(1.0 / 480, remaining)
            remaining -= h
            velocity += (stiffness * (target - value) - friction * velocity) * h
            value += velocity * h
        }
        if isAtRest {
            value = target
            velocity = 0
        }
    }

    /// Within `distance` of its target and slower than `speed`: close enough to call it there.
    public func isNear(within distance: Double, slowerThan speed: Double) -> Bool {
        abs(target - value) < distance && abs(velocity) < speed
    }

    /// Within a quarter of a point of the target (half a pixel: the last of a spring nobody can
    /// see, which cost a third of a second of frames) and slower than 0.5 pt/s.
    public var isAtRest: Bool {
        abs(target - value) < 0.25 && abs(velocity) < 0.5
    }
}
