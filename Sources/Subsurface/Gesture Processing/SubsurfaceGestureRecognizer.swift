//
//  SubsurfaceGestureRecognizer.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-04-05.
//

import CoreGraphics
import Foundation
import Scribe

/// Gesture kinds that a ``SubsurfaceGestureRecognizer`` can resolve.
public struct SubsurfaceGestureTypes: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Directional swipe gestures.
    public static let swipe = SubsurfaceGestureTypes(rawValue: 1 << 0)

    /// Magnification gestures.
    public static let magnify = SubsurfaceGestureTypes(rawValue: 1 << 1)

    /// Rotation gestures.
    public static let rotation = SubsurfaceGestureTypes(rawValue: 1 << 2)

    /// All supported gesture kinds.
    public static let all: SubsurfaceGestureTypes = [.swipe, .magnify, .rotation]
}

/// A combined gesture recognizer that disambiguates between swipe, magnify, and rotation gestures.
///
/// Consumes raw `[MTContact]` frames and emits typed ``SubsurfaceGestureEvent``s via an `AsyncStream`.
/// Supports any finger count (default 2). The first gesture type to exceed its threshold wins
/// and locks the recognizer for the remainder of the gesture.
///
/// Priority order: magnify -> rotation -> swipe.
///
/// Usage with a monitor (all devices):
/// ```swift
/// let monitor = SubsurfaceMonitor()
/// let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)
/// monitor.start()
///
/// for await event in recognizer.events(from: monitor) {
///     switch event {
///     case .swipe(let swipe): ...
///     case .magnify(let magnify): ...
///     case .rotation(let rotation): ...
///     }
/// }
/// ```
///
/// Usage with a single device:
/// ```swift
/// let device = SubsurfaceDevice.defaultDevice!
/// let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)
/// device.start()
///
/// for await event in recognizer.events(from: device) {
///     // ...
/// }
/// ```
///
/// Pass `recognizedGestureTypes` to restrict disambiguation to the gesture
/// kinds your app supports.
@Loggable
public final class SubsurfaceGestureRecognizer: @unchecked Sendable {
    /// The required number of fingers for this gesture (after palm rejection).
    public var requiredFingerCount: Int

    /// Whether a resolved gesture must keep the original finger count to continue.
    ///
    /// When enabled, resolved gestures end as soon as the active finger count differs
    /// from ``requiredFingerCount``. When disabled, resolved gestures keep tracking as
    /// long as at least two fingers remain active.
    public var requiresExactFingerCountToContinue: Bool

    /// Gesture kinds that this recognizer is allowed to resolve.
    public var recognizedGestureTypes: SubsurfaceGestureTypes

    /// Minimum centroid translation (normalized) to trigger a swipe gesture.
    public var minimumSwipeTranslation: CGFloat = 0.08

    /// Minimum inter-finger distance delta (normalized) to trigger a magnify gesture.
    public var minimumMagnificationDistance: CGFloat = 0.1

    /// Minimum inter-finger angle change (radians) to trigger a rotation gesture.
    public var minimumRotation: CGFloat = 0.15

    /// Duration of inactivity before the gesture is automatically ended.
    public var inactivityTimeout: Duration = .milliseconds(250)

    private var phase: SubsurfaceGesturePhase = .possible
    private var gestureKind: GestureKind?

    private var originCentroid: CGPoint?
    private var originDistance: CGFloat?
    private var originAngle: CGFloat?

    private var lastCentroid: CGPoint?
    private var lastDistance: CGFloat?
    private var lastAngle: CGFloat?
    private var lastEventTime: TimeInterval?

    private var inactivityTask: Task<(), Never>?

    private var continuation: AsyncStream<SubsurfaceGestureEvent>.Continuation?

    private enum GestureKind {
        case swipe
        case magnify
        case rotation
    }

    public init(
        fingerCount: Int = 2,
        recognizedGestureTypes: SubsurfaceGestureTypes = .all,
        requiresExactFingerCountToContinue: Bool = false
    ) {
        self.requiredFingerCount = fingerCount
        self.recognizedGestureTypes = recognizedGestureTypes
        self.requiresExactFingerCountToContinue = requiresExactFingerCountToContinue
    }

    /// Creates an `AsyncStream` of gesture events from a ``SubsurfaceMonitor``.
    ///
    /// Convenience that extracts the contact frames from the monitor's device+contact stream.
    public func events(from monitor: SubsurfaceMonitor) -> AsyncStream<SubsurfaceGestureEvent> {
        let contactStream = AsyncStream<[MTContact]> { continuation in
            let bridgeTask = Task {
                for await (_, contacts) in monitor.contacts() {
                    continuation.yield(contacts)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in bridgeTask.cancel() }
        }
        return events(from: contactStream)
    }

    /// Creates an `AsyncStream` of gesture events from a ``SubsurfaceDevice``.
    ///
    /// Convenience for monitoring a single device directly.
    public func events(from device: SubsurfaceDevice) -> AsyncStream<SubsurfaceGestureEvent> {
        events(from: device.contactFrames())
    }

    /// Creates an `AsyncStream` of gesture events by processing a raw contact stream.
    ///
    /// The recognizer handles palm filtering, finger count validation, gesture disambiguation,
    /// and inactivity timeouts internally.
    public func events(from contactStream: AsyncStream<[MTContact]>) -> AsyncStream<SubsurfaceGestureEvent> {
        AsyncStream { continuation in
            self.continuation = continuation

            let task = Task { [weak self] in
                for await contacts in contactStream {
                    guard let self, !Task.isCancelled else { break }
                    resetInactivityTimer()

                    if let event = process(contacts: contacts) {
                        continuation.yield(event)
                    }
                }

                // Stream ended, so finalize if mid-gesture
                if let self, phase == .began || phase == .changed || phase == .determining {
                    if let event = makeEndEvent(reason: .cancelled) {
                        continuation.yield(event)
                    }
                    resetState()
                }

                continuation.finish()
            }

            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.inactivityTask?.cancel()
                self?.resetState()
            }
        }
    }

    /// Process a single frame of contacts. Returns a gesture event if one should be emitted.
    ///
    /// Once a gesture kind is locked, the default behavior keeps the gesture alive as
    /// long as at least 2 fingers remain on the surface, regardless of the originally-
    /// required count. Set ``requiresExactFingerCountToContinue`` to `true` to
    /// require the exact finger count for the whole gesture.
    public func process(contacts: [MTContact]) -> SubsurfaceGestureEvent? {
        let filtered = SubsurfaceContactFilter.activeTouches(
            from: SubsurfaceContactFilter.removePalms(from: contacts)
        )
        let count = filtered.count

        if gestureKind != nil {
            guard shouldContinueResolvedGesture(activeFingerCount: count) else {
                let event = makeEndEvent(reason: .lifted)
                resetState()
                return event
            }
            return emitTracked(filtered: filtered, phase: .changed, count: count)
        }

        guard count == requiredFingerCount else {
            if phase == .determining {
                let event: SubsurfaceGestureEvent = count < requiredFingerCount
                    ? .unresolvedEnded(.lifted)
                    : .unresolvedEnded(.cancelled)
                resetState()
                return event
            }
            return nil
        }

        let centroid = SubsurfaceContactFilter.centroid(of: filtered)
        let distance = SubsurfaceContactFilter.maxInterFingerDistance(of: filtered)
        let angle = SubsurfaceContactFilter.interFingerAngle(of: filtered) ?? 0
        let now = Date.timeIntervalSinceReferenceDate

        guard let originCentroid, let originDistance, let originAngle else {
            originCentroid = centroid
            originDistance = distance
            originAngle = angle
            lastCentroid = centroid
            lastDistance = distance
            lastAngle = angle
            lastEventTime = now
            phase = .determining
            return .determining(centroid: centroid, fingerCount: count)
        }

        // Disambiguation priority: magnify, rotation, then swipe.
        let distanceDelta = distance - originDistance
        let angleDelta = angleDifference(from: originAngle, to: angle)
        let translation = hypot(centroid.x - originCentroid.x, centroid.y - originCentroid.y)

        if recognizedGestureTypes.contains(.magnify), abs(distanceDelta) > minimumMagnificationDistance {
            gestureKind = .magnify
        } else if recognizedGestureTypes.contains(.rotation), abs(angleDelta) > minimumRotation {
            gestureKind = .rotation
        } else if recognizedGestureTypes.contains(.swipe), translation > minimumSwipeTranslation {
            gestureKind = .swipe
        } else {
            lastCentroid = centroid
            lastDistance = distance
            lastAngle = angle
            lastEventTime = now
            return .determining(centroid: centroid, fingerCount: count)
        }

        phase = .began
        let event = makeEvent(
            phase: .began,
            centroid: centroid,
            distance: distance,
            angle: angle,
            now: now,
            fingerCount: count
        )
        lastCentroid = centroid
        lastDistance = distance
        lastAngle = angle
        lastEventTime = now
        return event
    }

    private func shouldContinueResolvedGesture(activeFingerCount count: Int) -> Bool {
        if requiresExactFingerCountToContinue {
            return count == requiredFingerCount
        }

        return count >= 2
    }

    /// Emits a `.changed` (or `.ended`/`.cancelled`) event for an already-locked gesture.
    private func emitTracked(
        filtered: [MTContact],
        phase newPhase: SubsurfaceGesturePhase,
        count: Int
    ) -> SubsurfaceGestureEvent? {
        let centroid = SubsurfaceContactFilter.centroid(of: filtered)
        let distance = SubsurfaceContactFilter.maxInterFingerDistance(of: filtered)
        let angle = SubsurfaceContactFilter.interFingerAngle(of: filtered) ?? 0
        let now = Date.timeIntervalSinceReferenceDate

        phase = newPhase
        let event = makeEvent(
            phase: newPhase,
            centroid: centroid,
            distance: distance,
            angle: angle,
            now: now,
            fingerCount: count
        )
        lastCentroid = centroid
        lastDistance = distance
        lastAngle = angle
        lastEventTime = now
        return event
    }

    /// Reset the recognizer to its initial state.
    public func reset() {
        if phase == .began || phase == .changed || phase == .determining {
            if let event = makeEndEvent(reason: .cancelled) {
                continuation?.yield(event)
            }
        }
        resetState()
    }

    private func resetInactivityTimer() {
        inactivityTask?.cancel()

        inactivityTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: inactivityTimeout)
            if Task.isCancelled { return }

            if phase == .began || phase == .changed || phase == .determining {
                if let event = makeEndEvent(reason: .timedOut) {
                    continuation?.yield(event)
                }
            }

            resetState()
        }
    }

    private func makeEvent(
        phase: SubsurfaceGesturePhase,
        centroid: CGPoint,
        distance: CGFloat,
        angle: CGFloat,
        now: TimeInterval,
        fingerCount: Int
    ) -> SubsurfaceGestureEvent? {
        guard let originCentroid, let originDistance, let originAngle else { return nil }

        let timeDelta = now - (lastEventTime ?? now)

        switch gestureKind {
        case .swipe:
            let translation = CGPoint(
                x: centroid.x - originCentroid.x,
                y: centroid.y - originCentroid.y
            )
            // MT coords are y-up, so atan2(dy, dx) matches the rotation convention
            // (positive = counterclockwise from +x).
            let swipeAngle = atan2(translation.y, translation.x)
            let swipeDistance = hypot(translation.x, translation.y)

            let velocity: CGPoint = if timeDelta > 0, let lastCentroid {
                CGPoint(
                    x: (centroid.x - lastCentroid.x) / timeDelta,
                    y: (centroid.y - lastCentroid.y) / timeDelta
                )
            } else {
                .zero
            }

            return .swipe(SubsurfaceGestureEvent.SwipeEvent(
                phase: phase,
                translation: translation,
                velocity: velocity,
                centroid: centroid,
                angle: swipeAngle,
                distance: swipeDistance,
                fingerCount: fingerCount
            ))

        case .magnify:
            let velocity: CGFloat = if timeDelta > 0, let lastDistance {
                (distance - lastDistance) / timeDelta
            } else {
                0
            }

            return .magnify(SubsurfaceGestureEvent.MagnifyEvent(
                phase: phase,
                distance: distance,
                originDistance: originDistance,
                velocity: velocity,
                centroid: centroid,
                fingerCount: fingerCount
            ))

        case .rotation:
            let rotation = angleDifference(from: originAngle, to: angle)

            let velocity: CGFloat
            if timeDelta > 0, let lastAngle {
                let lastRotation = angleDifference(from: originAngle, to: lastAngle)
                velocity = (rotation - lastRotation) / timeDelta
            } else {
                velocity = 0
            }

            return .rotation(SubsurfaceGestureEvent.RotationEvent(
                phase: phase,
                rotation: rotation,
                velocity: velocity,
                centroid: centroid,
                fingerCount: fingerCount
            ))

        case nil:
            return nil
        }
    }

    private func makeEndEvent(reason: SubsurfaceGestureEvent.UnresolvedEndReason) -> SubsurfaceGestureEvent? {
        guard gestureKind != nil else {
            return .unresolvedEnded(reason)
        }

        guard let lastCentroid, let lastDistance, let lastAngle else { return nil }
        return makeEvent(
            phase: .ended,
            centroid: lastCentroid,
            distance: lastDistance,
            angle: lastAngle,
            now: Date.timeIntervalSinceReferenceDate,
            fingerCount: requiredFingerCount
        )
    }

    private func resetState() {
        phase = .possible
        gestureKind = nil
        originCentroid = nil
        originDistance = nil
        originAngle = nil
        lastCentroid = nil
        lastDistance = nil
        lastAngle = nil
        lastEventTime = nil
    }

    /// Computes the shortest signed angular difference between two angles.
    private func angleDifference(from a: CGFloat, to b: CGFloat) -> CGFloat {
        var diff = b - a
        while diff > .pi {
            diff -= 2 * .pi
        }
        while diff < -.pi {
            diff += 2 * .pi
        }
        return diff
    }
}
