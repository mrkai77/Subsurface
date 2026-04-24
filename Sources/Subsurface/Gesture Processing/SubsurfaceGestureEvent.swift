//
//  SubsurfaceGestureEvent.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-04-05.
//

import CoreGraphics

/// A gesture event emitted by a ``SubsurfaceGestureRecognizer``.
public enum SubsurfaceGestureEvent: Sendable {
    /// Correct finger count detected, but gesture type not yet determined.
    case determining(centroid: CGPoint, fingerCount: Int)
    /// A pan (directional swipe) gesture was detected.
    case pan(PanEvent)
    /// A pinch (spread/squeeze) gesture was detected.
    case pinch(PinchEvent)
    /// A rotation gesture was detected.
    case rotation(RotationEvent)

    /// The gesture phase of this event.
    public var phase: SubsurfaceGesturePhase {
        switch self {
        case .determining: .determining
        case let .pan(event): event.phase
        case let .pinch(event): event.phase
        case let .rotation(event): event.phase
        }
    }

    /// A pan (directional swipe) gesture event.
    public struct PanEvent: Sendable {
        /// The current phase of this gesture.
        public let phase: SubsurfaceGesturePhase

        /// Translation from the gesture's origin point, in normalized coordinates.
        public let translation: CGPoint

        /// Estimated velocity of the centroid, in normalized units per second.
        public let velocity: CGPoint

        /// Average position of all active fingers, normalized to `0...1`.
        public let centroid: CGPoint

        /// Angle from the gesture origin, in radians. MT uses y-up coordinates,
        /// so 0 points right, π/2 up, and -π/2 down. Positive is counterclockwise,
        /// matching the rotation event convention.
        public let angle: CGFloat

        /// Euclidean distance from the gesture origin, in normalized coordinates.
        public let distance: CGFloat

        /// Number of active fingers in this gesture.
        public let fingerCount: Int
    }

    /// A pinch (spread/squeeze) gesture event.
    public struct PinchEvent: Sendable {
        /// The current phase of this gesture.
        public let phase: SubsurfaceGesturePhase

        /// Ratio of current inter-finger distance to the initial distance.
        ///
        /// Values greater than `1.0` indicate fingers are spreading apart;
        /// values less than `1.0` indicate fingers are squeezing together.
        public let scale: CGFloat

        /// Rate of scale change per second.
        public let velocity: CGFloat

        /// Midpoint between fingers, normalized to `0...1`.
        public let centroid: CGPoint

        /// Number of active fingers in this gesture.
        public let fingerCount: Int
    }

    /// A rotation gesture event.
    public struct RotationEvent: Sendable {
        /// The current phase of this gesture.
        public let phase: SubsurfaceGesturePhase

        /// Rotation from the initial inter-finger angle, in radians.
        ///
        /// Positive values indicate counterclockwise rotation, and negative values indicate clockwise rotation.
        public let rotation: CGFloat

        /// Rate of rotation change, in radians per second.
        public let velocity: CGFloat

        /// Midpoint between the reference fingers, normalized to `0...1`.
        public let centroid: CGPoint

        /// Number of active fingers in this gesture.
        public let fingerCount: Int
    }
}
