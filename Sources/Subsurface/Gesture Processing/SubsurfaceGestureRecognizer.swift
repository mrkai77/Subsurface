//
//  SubsurfaceGestureRecognizer.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-04-05.
//

import CoreGraphics
import Foundation
import Scribe

/// A combined gesture recognizer that disambiguates between pan, pinch, and rotation gestures.
///
/// Consumes raw `[MTContact]` frames and emits typed ``SubsurfaceGestureEvent``s via an `AsyncStream`.
/// Supports any finger count (default 2). The first gesture type to exceed its threshold wins
/// and locks the recognizer for the remainder of the gesture.
///
/// Priority order: pinch -> rotation -> pan.
///
/// Usage with a monitor (all devices):
/// ```swift
/// let monitor = SubsurfaceMonitor()
/// let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)
/// monitor.start()
///
/// for await event in recognizer.events(from: monitor) {
///     switch event {
///     case .pan(let pan): ...
///     case .pinch(let pinch): ...
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
@Loggable
public final class SubsurfaceGestureRecognizer: @unchecked Sendable {
    /// The required number of fingers for this gesture (after palm rejection).
    public var requiredFingerCount: Int

    /// Minimum centroid translation (normalized) to trigger a pan gesture.
    public var minimumPanTranslation: CGFloat = 0.08

    /// Minimum inter-finger distance delta (normalized) to trigger a pinch gesture.
    public var minimumPinchDistance: CGFloat = 0.1

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
        case pan
        case pinch
        case rotation
    }

    public init(fingerCount: Int = 2) {
        self.requiredFingerCount = fingerCount
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
                    if let event = makeEndEvent() {
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
    /// Once a gesture kind is locked, the gesture stays alive as long as at least 2
    /// fingers remain on the surface, regardless of the originally-required count. It
    /// only ends when the count drops below 2. Mirrors macOS system gestures, where a
    /// 3-finger swipe keeps tracking after the user drops to 2 fingers.
    public func process(contacts: [MTContact]) -> SubsurfaceGestureEvent? {
        let filtered = SubsurfaceContactFilter.removePalms(from: contacts)
        let count = filtered.count

        if gestureKind != nil {
            guard count >= 2 else {
                let event = makeEndEvent()
                resetState()
                return event
            }
            return emitTracked(filtered: filtered, phase: .changed, count: count)
        }

        guard count == requiredFingerCount else {
            if phase == .determining {
                let event = makeCancelEvent()
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

        // Disambiguation priority: pinch, rotation, then pan.
        let distanceDelta = distance - originDistance
        let angleDelta = angleDifference(from: originAngle, to: angle)
        let translation = hypot(centroid.x - originCentroid.x, centroid.y - originCentroid.y)

        if abs(distanceDelta) > minimumPinchDistance {
            gestureKind = .pinch
        } else if abs(angleDelta) > minimumRotation {
            gestureKind = .rotation
        } else if translation > minimumPanTranslation {
            gestureKind = .pan
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
            if let event = makeEndEvent() {
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
                if let event = makeEndEvent() {
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
        case .pan:
            let translation = CGPoint(
                x: centroid.x - originCentroid.x,
                y: centroid.y - originCentroid.y
            )
            // MT coords are y-up, so atan2(dy, dx) matches the rotation convention
            // (positive = counterclockwise from +x).
            let panAngle = atan2(translation.y, translation.x)
            let panDistance = hypot(translation.x, translation.y)

            let velocity: CGPoint = if timeDelta > 0, let lastCentroid {
                CGPoint(
                    x: (centroid.x - lastCentroid.x) / timeDelta,
                    y: (centroid.y - lastCentroid.y) / timeDelta
                )
            } else {
                .zero
            }

            return .pan(SubsurfaceGestureEvent.PanEvent(
                phase: phase,
                translation: translation,
                velocity: velocity,
                centroid: centroid,
                angle: panAngle,
                distance: panDistance,
                fingerCount: fingerCount
            ))

        case .pinch:
            let scale = originDistance > 0 ? distance / originDistance : 1.0

            let velocity: CGFloat
            if timeDelta > 0, let lastDistance {
                let lastScale = originDistance > 0 ? lastDistance / originDistance : 1.0
                velocity = (scale - lastScale) / timeDelta
            } else {
                velocity = 0
            }

            return .pinch(SubsurfaceGestureEvent.PinchEvent(
                phase: phase,
                scale: scale,
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

    private func makeEndEvent() -> SubsurfaceGestureEvent? {
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

    private func makeCancelEvent() -> SubsurfaceGestureEvent? {
        guard let lastCentroid, let lastDistance, let lastAngle else { return nil }
        return makeEvent(
            phase: .cancelled,
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
