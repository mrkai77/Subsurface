//
//  RotationGestureTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface
import Testing

struct RotateGestureTests {
    @Test("Rotation detected when fingers orbit around centroid")
    func rotationDetected() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.7, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let cos30: Float = 0.866
        let sin30: Float = 0.5
        let r: Float = 0.2
        let cx: Float = 0.5
        let cy: Float = 0.5

        let rotated = ContactFactory.twoFingers(
            p1: (x: cx - r * cos30, y: cy - r * sin30),
            p2: (x: cx + r * cos30, y: cy + r * sin30)
        )
        let result = recognizer.process(contacts: rotated)

        if case let .rotation(rotation) = result {
            #expect(rotation.phase == .began)
            #expect(rotation.rotation > 0.15)
        } else {
            Issue.record("Expected rotation event, got \(String(describing: result))")
        }
    }

    @Test("Clockwise rotation produces negative angle")
    func clockwiseRotation() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.7, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let cos30: Float = 0.866
        let sin30: Float = 0.5
        let r: Float = 0.2
        let cx: Float = 0.5
        let cy: Float = 0.5

        let rotated = ContactFactory.twoFingers(
            p1: (x: cx - r * cos30, y: cy + r * sin30),
            p2: (x: cx + r * cos30, y: cy - r * sin30)
        )
        let result = recognizer.process(contacts: rotated)

        if case let .rotation(rotation) = result {
            #expect(rotation.rotation < -0.15)
        } else {
            Issue.record("Expected rotation event")
        }
    }

    @Test("Small rotation below threshold does not trigger")
    func rotationBelowThreshold() {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

        let origin = ContactFactory.twoFingers(p1: (x: 0.3, y: 0.5), p2: (x: 0.7, y: 0.5))
        _ = recognizer.process(contacts: origin)

        let cos5: Float = 0.996
        let sin5: Float = 0.087
        let r: Float = 0.2
        let cx: Float = 0.5
        let cy: Float = 0.5

        let rotated = ContactFactory.twoFingers(
            p1: (x: cx - r * cos5, y: cy - r * sin5),
            p2: (x: cx + r * cos5, y: cy + r * sin5)
        )
        let result = recognizer.process(contacts: rotated)
        #expect(result == nil)
    }
}
