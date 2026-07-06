//
//  MagnifyGestureTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface
import Testing

struct MagnifyGestureTests {
    @Test("Magnify outward gesture detected when fingers move apart")
    func magnifyOutward() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let outward = ContactFactory.twoFingers(p1: (x: 0.35, y: 0.5), p2: (x: 0.65, y: 0.5))
        let result = recognizer.process(contacts: outward)

        if case let .magnify(magnify) = result {
            #expect(magnify.phase == .began)
            #expect(magnify.distance > magnify.originDistance)
        } else {
            Issue.record("Expected magnify event, got \(String(describing: result))")
        }
    }

    @Test("Magnify reports current and origin inter-finger distance")
    func magnifyDistance() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.6, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let outward = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.7, y: 0.5))
        let result = recognizer.process(contacts: outward)

        if case let .magnify(magnify) = result {
            #expect(abs(magnify.originDistance - 0.2) < 0.01)
            #expect(abs(magnify.distance - 0.4) < 0.01)
        } else {
            Issue.record("Expected magnify event")
        }
    }

    @Test("Magnify takes priority over swipe when both thresholds exceeded")
    func magnifyPriorityOverSwipe() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.35, y: 0.5), p2: (x: 0.75, y: 0.5))
        let result = recognizer.process(contacts: moved)

        if case .magnify = result {
            // Expected
        } else {
            Issue.record("Expected magnify to take priority, got \(String(describing: result))")
        }
    }

    @Test("Magnify below threshold does not trigger")
    func magnifyBelowThreshold() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let small = ContactFactory.twoFingers(p1: (x: 0.43, y: 0.5), p2: (x: 0.57, y: 0.5))
        let result = recognizer.process(contacts: small)
        #expect(result?.phase == .determining)
    }

    @Test("Magnify inward detected when distance shrinks below origin")
    func magnifyInward() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        // Origin: fingers far apart (distance = 0.4)
        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.7, y: 0.5))
        _ = recognizer.process(contacts: origin)

        // Squeeze fingers together (distance = 0.2, delta = -0.2 > threshold)
        let squeeze = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.6, y: 0.5))
        let result = recognizer.process(contacts: squeeze)

        if case let .magnify(magnify) = result {
            #expect(magnify.phase == .began)
            #expect(magnify.distance < magnify.originDistance)
            #expect(abs(magnify.originDistance - 0.4) < 0.01)
            #expect(abs(magnify.distance - 0.2) < 0.01)
        } else {
            Issue.record("Expected magnify event for inward gesture, got \(String(describing: result))")
        }
    }

    @Test("Continued magnify emits changed events")
    func magnifyChanged() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.45, y: 0.5), p2: (x: 0.55, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let outward1 = ContactFactory.twoFingers(p1: (x: 0.35, y: 0.5), p2: (x: 0.65, y: 0.5))
        _ = recognizer.process(contacts: outward1)

        let outward2 = ContactFactory.twoFingers(p1: (x: 0.25, y: 0.5), p2: (x: 0.75, y: 0.5))
        let result = recognizer.process(contacts: outward2)

        if case let .magnify(magnify) = result {
            #expect(magnify.phase == .changed)
            #expect(magnify.distance > 2.0 * magnify.originDistance)
        } else {
            Issue.record("Expected magnify .changed event")
        }
    }
}
