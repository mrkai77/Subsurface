//
//  SubsurfaceGesturePhase.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-04-05.
//

/// The phase of a gesture recognizer's lifecycle.
///
/// Follows the Apple `UIGestureRecognizer` state machine pattern:
/// - Continuous gestures: `possible -> began -> changed -> ended`
/// - Any phase can transition to `cancelled`
/// - `failed` indicates the gesture pattern was not matched
public enum SubsurfaceGesturePhase: Sendable, Equatable {
    /// Evaluating touches, not yet recognized.
    case possible

    /// Correct finger count detected, but gesture type not yet determined.
    case determining

    /// Gesture recognized, first event emitted.
    case began

    /// Ongoing gesture with updated values.
    case changed

    /// Fingers lifted cleanly, gesture complete.
    case ended

    /// Interrupted (e.g., finger count changed mid-gesture).
    case cancelled

    /// Did not match the expected gesture pattern.
    case failed
}
