//
//  ContactFilterTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface
import Testing

struct ContactFilterTests {
    @Test("removePalms filters out contacts with nil finger or hand")
    func removePalms() {
        let contacts = [
            ContactFactory.contact(x: 0.3, y: 0.3, finger: .index, hand: .right),
            ContactFactory.palm(),
            ContactFactory.contact(x: 0.7, y: 0.7, finger: .middle, hand: .right),
            ContactFactory.contact(x: 0.5, y: 0.5, finger: nil, hand: .left)
        ]

        let filtered = SubsurfaceContactFilter.removePalms(from: contacts)
        #expect(filtered.count == 2)
    }

    @Test("centroid computes average position")
    func centroid() {
        let contacts = ContactFactory.twoFingers(
            p1: (x: 0.2, y: 0.4),
            p2: (x: 0.8, y: 0.6)
        )

        let c = SubsurfaceContactFilter.centroid(of: contacts)
        #expect(abs(c.x - 0.5) < 0.001)
        #expect(abs(c.y - 0.5) < 0.001)
    }

    @Test("centroid returns zero for empty array")
    func centroidEmpty() {
        let c = SubsurfaceContactFilter.centroid(of: [])
        #expect(c == .zero)
    }

    @Test("interFingerDistance computes euclidean distance")
    func interFingerDistance() throws {
        let contacts = ContactFactory.twoFingers(
            p1: (x: 0.0, y: 0.0),
            p2: (x: 0.3, y: 0.4)
        )

        let distance = SubsurfaceContactFilter.interFingerDistance(between: contacts)
        #expect(distance != nil)
        #expect(try abs(#require(distance) - 0.5) < 0.001)
    }

    @Test("interFingerDistance returns nil for non-two contacts")
    func interFingerDistanceWrongCount() {
        let single = [ContactFactory.contact(x: 0.5, y: 0.5)]
        #expect(SubsurfaceContactFilter.interFingerDistance(between: single) == nil)
        #expect(SubsurfaceContactFilter.interFingerDistance(between: []) == nil)
    }

    @Test("maxInterFingerDistance finds the largest pairwise distance")
    func maxInterFingerDistance() {
        let contacts = [
            ContactFactory.contact(x: 0.0, y: 0.0, finger: .index, id: 1),
            ContactFactory.contact(x: 0.1, y: 0.0, finger: .middle, id: 2),
            ContactFactory.contact(x: 0.5, y: 0.0, finger: .ring, id: 3)
        ]

        let maxDist = SubsurfaceContactFilter.maxInterFingerDistance(of: contacts)
        #expect(abs(maxDist - 0.5) < 0.001)
    }

    @Test("maxInterFingerDistance returns 0 for fewer than 2 contacts")
    func maxInterFingerDistanceTooFew() {
        #expect(SubsurfaceContactFilter.maxInterFingerDistance(of: []) == 0)
        #expect(SubsurfaceContactFilter.maxInterFingerDistance(of: [ContactFactory.contact(x: 0, y: 0)]) == 0)
    }

    @Test("interFingerAngle computes angle between farthest pair")
    func interFingerAngle() throws {
        let horizontal = ContactFactory.twoFingers(
            p1: (x: 0.2, y: 0.5),
            p2: (x: 0.8, y: 0.5)
        )
        let angle = SubsurfaceContactFilter.interFingerAngle(of: horizontal)
        #expect(angle != nil)
        #expect(try abs(#require(angle)) < 0.01)

        let vertical = ContactFactory.twoFingers(
            p1: (x: 0.5, y: 0.2),
            p2: (x: 0.5, y: 0.8)
        )
        let vAngle = SubsurfaceContactFilter.interFingerAngle(of: vertical)
        #expect(vAngle != nil)
        #expect(try abs(#require(vAngle) - .pi / 2) < 0.01)
    }

    @Test("interFingerAngle returns nil for fewer than 2 contacts")
    func interFingerAngleTooFew() {
        #expect(SubsurfaceContactFilter.interFingerAngle(of: []) == nil)
    }
}
