//
//  PanGestureTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface
import Testing

struct PanGestureTests {
    @Test("Pan gesture emits began then changed when sliding right")
    func panRight() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        let result1 = recognizer.process(contacts: origin)
        #expect(result1 == nil)

        let moved = ContactFactory.twoFingers(p1: (x: 0.36, y: 0.5), p2: (x: 0.46, y: 0.5))
        let result2 = recognizer.process(contacts: moved)
        #expect(result2 != nil)

        if case let .pan(pan) = result2 {
            #expect(pan.phase == .began)
            #expect(pan.translation.x > 0)
            #expect(abs(pan.angle) < 0.3)
        } else {
            Issue.record("Expected pan event")
        }

        let moved2 = ContactFactory.twoFingers(p1: (x: 0.42, y: 0.5), p2: (x: 0.52, y: 0.5))
        let result3 = recognizer.process(contacts: moved2)

        if case let .pan(pan) = result3 {
            #expect(pan.phase == .changed)
        } else {
            Issue.record("Expected pan .changed event")
        }
    }

    @Test("Pan gesture emits correct angle for upward movement")
    func panUp() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.3), p2: (x: 0.5, y: 0.3))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.36), p2: (x: 0.5, y: 0.36))
        let result = recognizer.process(contacts: moved)

        if case let .pan(pan) = result {
            #expect(pan.angle < 0)
        } else {
            Issue.record("Expected pan event")
        }
    }

    @Test("Pan is not triggered below minimum translation threshold")
    func panBelowThreshold() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.5, y: 0.5), p2: (x: 0.6, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.501, y: 0.5), p2: (x: 0.601, y: 0.5))
        let result = recognizer.process(contacts: moved)
        #expect(result == nil)
    }

    @Test("Backward motion continues gesture with decreasing distance")
    func backwardMotionContinues() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        // Origin
        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        _ = recognizer.process(contacts: origin)

        // Slide right -> .began
        let step1 = ContactFactory.twoFingers(p1: (x: 0.36, y: 0.5), p2: (x: 0.46, y: 0.5))
        let began = recognizer.process(contacts: step1)
        #expect(began != nil)

        // Continue right -> .changed with growing distance
        let step2 = ContactFactory.twoFingers(p1: (x: 0.46, y: 0.5), p2: (x: 0.56, y: 0.5))
        let changed1 = recognizer.process(contacts: step2)
        if case let .pan(pan) = changed1 {
            #expect(pan.phase == .changed)
            #expect(pan.distance > 0.1)
        }

        // Pull back left -> still .changed, distance decreases, no reset
        let reverse = ContactFactory.twoFingers(p1: (x: 0.36, y: 0.5), p2: (x: 0.46, y: 0.5))
        let changed2 = recognizer.process(contacts: reverse)
        if case let .pan(pan) = changed2 {
            #expect(pan.phase == .changed)
            #expect(pan.distance < 0.1) // Closer to origin
        } else {
            Issue.record("Expected .changed on reversal, got \(String(describing: changed2))")
        }
    }

    @Test("Three fingers cancels a two-finger pan")
    func threeFingersCancels() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.36, y: 0.5), p2: (x: 0.46, y: 0.5))
        let began = recognizer.process(contacts: moved)
        #expect(began != nil)

        let threeFinger = [
            ContactFactory.contact(x: 0.36, y: 0.5, finger: .index, hand: .right, id: 1),
            ContactFactory.contact(x: 0.46, y: 0.5, finger: .middle, hand: .right, id: 2),
            ContactFactory.contact(x: 0.56, y: 0.5, finger: .ring, hand: .right, id: 3)
        ]
        let result = recognizer.process(contacts: threeFinger)

        if case let .pan(pan) = result {
            #expect(pan.phase == .cancelled)
        } else {
            Issue.record("Expected cancelled pan event")
        }
    }
}
