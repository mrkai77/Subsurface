//
//  PinchGestureTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface
import Testing

struct PinchGestureTests {
    @Test("Pinch gesture detected when fingers spread apart")
    func pinchSpread() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let spread = ContactFactory.twoFingers(p1: (x: 0.35, y: 0.5), p2: (x: 0.65, y: 0.5))
        let result = recognizer.process(contacts: spread)

        if case let .pinch(pinch) = result {
            #expect(pinch.phase == .began)
            #expect(pinch.scale > 1.0)
        } else {
            Issue.record("Expected pinch event, got \(String(describing: result))")
        }
    }

    @Test("Pinch scale is ratio of current to initial distance")
    func pinchScale() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.6, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let spread = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.7, y: 0.5))
        let result = recognizer.process(contacts: spread)

        if case let .pinch(pinch) = result {
            #expect(abs(pinch.scale - 2.0) < 0.01)
        } else {
            Issue.record("Expected pinch event")
        }
    }

    @Test("Pinch takes priority over pan when both thresholds exceeded")
    func pinchPriorityOverPan() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.35, y: 0.5), p2: (x: 0.75, y: 0.5))
        let result = recognizer.process(contacts: moved)

        if case .pinch = result {
            // Expected
        } else {
            Issue.record("Expected pinch to take priority, got \(String(describing: result))")
        }
    }

    @Test("Pinch below threshold does not trigger")
    func pinchBelowThreshold() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let small = ContactFactory.twoFingers(p1: (x: 0.43, y: 0.5), p2: (x: 0.57, y: 0.5))
        let result = recognizer.process(contacts: small)
        #expect(result?.phase == .determining)
    }

    @Test("Pinch inward detected with scale < 1.0")
    func pinchInward() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        // Origin: fingers far apart (distance = 0.4)
        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.7, y: 0.5))
        _ = recognizer.process(contacts: origin)

        // Squeeze fingers together (distance = 0.2, delta = -0.2 > threshold)
        let squeeze = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.6, y: 0.5))
        let result = recognizer.process(contacts: squeeze)

        if case let .pinch(pinch) = result {
            #expect(pinch.phase == .began)
            #expect(pinch.scale < 1.0) // Squeezing = scale < 1
            #expect(abs(pinch.scale - 0.5) < 0.01) // 0.2 / 0.4 = 0.5
        } else {
            Issue.record("Expected pinch event for inward gesture, got \(String(describing: result))")
        }
    }

    @Test("Continued pinch emits changed events")
    func pinchChanged() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let spread1 = ContactFactory.twoFingers(p1: (x: 0.35, y: 0.5), p2: (x: 0.65, y: 0.5))
        _ = recognizer.process(contacts: spread1)

        let spread2 = ContactFactory.twoFingers(p1: (x: 0.25, y: 0.5), p2: (x: 0.75, y: 0.5))
        let result = recognizer.process(contacts: spread2)

        if case let .pinch(pinch) = result {
            #expect(pinch.phase == .changed)
            #expect(pinch.scale > 2.0)
        } else {
            Issue.record("Expected pinch .changed event")
        }
    }
}
