//
//  ContactFactory.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-04-05.
//

@testable import Subsurface

/// Factory for creating `MTContact` instances in tests.
enum ContactFactory {
    /// Creates a contact at the given normalized position with specified finger and hand.
    static func contact(
        x: Float,
        y: Float,
        finger: MTContactFinger? = .index,
        hand: MTContactHand? = .right,
        id: Int32 = 0,
        contactState: MTContactState = .touching
    ) -> MTContact {
        MTContact(
            id: id,
            contactState: contactState,
            finger: finger,
            hand: hand,
            normalizedVector: MTVector(
                position: MTPoint(x: x, y: y),
                velocity: MTPoint(x: 0, y: 0)
            )
        )
    }

    /// Creates a pair of contacts at the given positions, suitable for two-finger gesture testing.
    static func twoFingers(
        p1: (x: Float, y: Float),
        p2: (x: Float, y: Float)
    ) -> [MTContact] {
        [
            contact(x: p1.x, y: p1.y, finger: .index, hand: .right, id: 1),
            contact(x: p2.x, y: p2.y, finger: .middle, hand: .right, id: 2)
        ]
    }

    /// Creates a palm contact (finger is nil).
    static func palm(x: Float = 0.5, y: Float = 0.5) -> MTContact {
        contact(x: x, y: y, finger: nil, hand: nil)
    }
}
