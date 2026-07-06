//
//  SwipeGestureTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface
import Testing

struct SwipeGestureTests {
    @Test("Swipe gesture emits began then changed when sliding right")
    func swipeRight() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        let result1 = recognizer.process(contacts: origin)
        #expect(result1?.phase == .determining)

        // Move centroid past minimumSwipeTranslation (0.08): centroid goes from 0.35 to 0.45
        let moved = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.5, y: 0.5))
        let result2 = recognizer.process(contacts: moved)
        #expect(result2 != nil)

        if case let .swipe(swipe) = result2 {
            #expect(swipe.phase == .began)
            #expect(swipe.translation.x > 0)
            #expect(abs(swipe.angle) < 0.3)
        } else {
            Issue.record("Expected swipe event")
        }

        let moved2 = ContactFactory.twoFingers(p1: (x: 0.5, y: 0.5), p2: (x: 0.6, y: 0.5))
        let result3 = recognizer.process(contacts: moved2)

        if case let .swipe(swipe) = result3 {
            #expect(swipe.phase == .changed)
        } else {
            Issue.record("Expected swipe .changed event")
        }
    }

    @Test("Swipe gesture emits correct angle for upward movement")
    func swipeUp() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.3), p2: (x: 0.5, y: 0.3))
        _ = recognizer.process(contacts: origin)

        // Move centroid upward past threshold (0.08): centroid y goes 0.3 to 0.4.
        // MT is y-up, so a pure upward translation gives angle +π/2.
        let moved = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.4), p2: (x: 0.5, y: 0.4))
        let result = recognizer.process(contacts: moved)

        if case let .swipe(swipe) = result {
            #expect(swipe.angle > 0)
            #expect(abs(swipe.angle - .pi / 2) < 0.01)
        } else {
            Issue.record("Expected swipe event")
        }
    }

    @Test("Swipe is not triggered below minimum translation threshold")
    func swipeBelowThreshold() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.5, y: 0.5), p2: (x: 0.6, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.501, y: 0.5), p2: (x: 0.601, y: 0.5))
        let result = recognizer.process(contacts: moved)
        #expect(result?.phase == .determining)
    }

    @Test("Unresolved gesture emits lifted when active finger count drops")
    func unresolvedGestureEndsOnLift() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.5, y: 0.5), p2: (x: 0.6, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let result = recognizer.process(contacts: [])
        if case .unresolvedEnded(.lifted) = result {
            #expect(result?.phase == .ended)
        } else {
            Issue.record("Expected unresolved lifted event")
        }
    }

    @Test("Breaking contacts do not keep unresolved gesture alive")
    func breakingContactsEndUnresolvedGesture() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.5, y: 0.5), p2: (x: 0.6, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let breakingContacts = [
            ContactFactory.contact(x: 0.5, y: 0.5, finger: .index, hand: .right, id: 1, contactState: .breaking),
            ContactFactory.contact(x: 0.6, y: 0.5, finger: .middle, hand: .right, id: 2, contactState: .breaking)
        ]
        let result = recognizer.process(contacts: breakingContacts)

        if case .unresolvedEnded(.lifted) = result {
            #expect(result?.phase == .ended)
        } else {
            Issue.record("Expected unresolved lifted event")
        }
    }

    @Test("Backward motion continues gesture with decreasing distance")
    func backwardMotionContinues() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        // Origin
        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        _ = recognizer.process(contacts: origin)

        // Slide right past threshold -> .began (centroid from 0.35 to 0.45)
        let step1 = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.5, y: 0.5))
        let began = recognizer.process(contacts: step1)
        #expect(began != nil)

        // Continue right -> .changed with growing distance (centroid 0.55)
        let step2 = ContactFactory.twoFingers(p1: (x: 0.5, y: 0.5), p2: (x: 0.6, y: 0.5))
        let changed1 = recognizer.process(contacts: step2)
        if case let .swipe(swipe) = changed1 {
            #expect(swipe.phase == .changed)
            #expect(swipe.distance > 0.1)
        }

        // Pull back left -> still .changed, distance decreases, no reset (centroid 0.45)
        let reverse = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.5, y: 0.5))
        let changed2 = recognizer.process(contacts: reverse)
        if case let .swipe(swipe) = changed2 {
            #expect(swipe.phase == .changed)
            #expect(swipe.distance < 0.1) // Closer to origin
        } else {
            Issue.record("Expected .changed on reversal, got \(String(describing: changed2))")
        }
    }

    @Test("Swipe keeps tracking when finger count stays >= 2")
    func panStaysWithMoreFingers() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.5, y: 0.5))
        _ = recognizer.process(contacts: moved)

        // Adding a third finger no longer cancels (macOS-style sticky behavior).
        let threeFinger = [
            ContactFactory.contact(x: 0.4, y: 0.5, finger: .index, hand: .right, id: 1),
            ContactFactory.contact(x: 0.5, y: 0.5, finger: .middle, hand: .right, id: 2),
            ContactFactory.contact(x: 0.6, y: 0.5, finger: .ring, hand: .right, id: 3)
        ]
        let result = recognizer.process(contacts: threeFinger)

        if case let .swipe(swipe) = result {
            #expect(swipe.phase == .changed)
            #expect(swipe.fingerCount == 3)
        } else {
            Issue.record("Expected .changed swipe event with 3 fingers, got \(String(describing: result))")
        }
    }

    @Test("Swipe ends when finger count drops below 2")
    func panEndsWhenFingersLifted() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.5, y: 0.5))
        _ = recognizer.process(contacts: moved)

        // Drop to 1 finger, gesture should end.
        let single = [ContactFactory.contact(x: 0.5, y: 0.5, finger: .index, hand: .right, id: 1)]
        let result = recognizer.process(contacts: single)

        if case let .swipe(swipe) = result {
            #expect(swipe.phase == .ended)
        } else {
            Issue.record("Expected .ended swipe event, got \(String(describing: result))")
        }
    }

    @Test("Swipe ends on finger count change when exact-count tracking is required")
    func panEndsOnFingerCountChangeWhenExactCountRequired() {
        let recognizer = SubsurfaceGestureRecognizer(
            fingerCount: 3,
            requiresExactFingerCountToContinue: true
        )

        let origin = [
            ContactFactory.contact(x: 0.3, y: 0.5, finger: .index, hand: .right, id: 1),
            ContactFactory.contact(x: 0.4, y: 0.5, finger: .middle, hand: .right, id: 2),
            ContactFactory.contact(x: 0.5, y: 0.5, finger: .ring, hand: .right, id: 3)
        ]
        _ = recognizer.process(contacts: origin)

        let moved = [
            ContactFactory.contact(x: 0.4, y: 0.5, finger: .index, hand: .right, id: 1),
            ContactFactory.contact(x: 0.5, y: 0.5, finger: .middle, hand: .right, id: 2),
            ContactFactory.contact(x: 0.6, y: 0.5, finger: .ring, hand: .right, id: 3)
        ]
        let began = recognizer.process(contacts: moved)
        #expect(began?.phase == .began)

        let lifted = [
            ContactFactory.contact(x: 0.4, y: 0.5, finger: .index, hand: .right, id: 1),
            ContactFactory.contact(x: 0.5, y: 0.5, finger: .middle, hand: .right, id: 2)
        ]
        let result = recognizer.process(contacts: lifted)

        if case let .swipe(swipe) = result {
            #expect(swipe.phase == .ended)
        } else {
            Issue.record("Expected .ended swipe event after finger-count change, got \(String(describing: result))")
        }
    }
}
