//
//  InactivityTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface
import Testing

struct InactivityTests {
    @Test("Inactivity timeout emits ended event via AsyncStream")
    func inactivityEndsGesture() async {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)
        recognizer.inactivityTimeout = .milliseconds(100)

        let contactStream = AsyncStream<[MTContact]> { continuation in
            let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
            continuation.yield(origin)

            // Move past minimumSwipeTranslation (0.08) to trigger .began
            let moved = ContactFactory.twoFingers(p1: (x: 0.4, y: 0.5), p2: (x: 0.5, y: 0.5))
            continuation.yield(moved)
        }

        var events: [SubsurfaceGestureEvent] = []
        let eventStream = recognizer.events(from: contactStream)

        let deadline = ContinuousClock.now + .seconds(2)
        for await event in eventStream {
            events.append(event)
            if event.phase == .ended { break }
            if ContinuousClock.now > deadline { break }
        }

        #expect(events.count >= 2)

        if let last = events.last {
            #expect(last.phase == .ended)
        }
    }

    @Test("Determining gesture timeout emits unresolved timedOut event")
    func inactivityEndsUnresolvedGesture() async {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)
        recognizer.inactivityTimeout = .milliseconds(100)

        let contactStream = AsyncStream<[MTContact]> { continuation in
            let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
            continuation.yield(origin)
        }

        var events: [SubsurfaceGestureEvent] = []
        let eventStream = recognizer.events(from: contactStream)

        let deadline = ContinuousClock.now + .seconds(2)
        for await event in eventStream {
            events.append(event)
            if event.phase == .ended { break }
            if ContinuousClock.now > deadline { break }
        }

        if case .unresolvedEnded(.timedOut) = events.last {
            #expect(events.last?.phase == .ended)
        } else {
            Issue.record("Expected unresolved timedOut event")
        }
    }

    @Test("Reset clears recognizer state")
    func resetClearsState() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.4, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let moved = ContactFactory.twoFingers(p1: (x: 0.36, y: 0.5), p2: (x: 0.46, y: 0.5))
        _ = recognizer.process(contacts: moved)

        recognizer.reset()

        let newOrigin = ContactFactory.twoFingers(p1: (x: 0.5, y: 0.5), p2: (x: 0.6, y: 0.5))
        let result = recognizer.process(contacts: newOrigin)
        #expect(result?.phase == .determining)
    }
}
