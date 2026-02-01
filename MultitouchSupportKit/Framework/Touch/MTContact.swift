//
//  MTContact.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

public struct MTContact {
    /// The frame ID in the same way a framerate works. Can be used to link different `MTTouch`es to the same event.
    let frame: Int32

    /// The timestamp of this touch's event. Seems to be the the amount of seconds since the device booted.
    let timestamp: Double

    /// Exact meaning unknown; seems to be consistent across events for each finger.
    let identifier: Int32

    /// The state of this touch.
    let touchState: MTContactState

    /// The finger's ID from what looks to be 1 for the thumb all the way up to 5 for the fingers. Other may be considered as the palm.
    let fingerID: Int32

    /// -1 for the left hand, +1 for the right hand. 0 for unknown values?
    let handID: Int32

    /// Vector for this touch (normalized from 0...1)
    let normalizedVector: MTVector

    /// Helps to determine how much of the user's finger/palm is touching the trackpad
    let totalCapacitance: Float

    /// The pressue of the user's finger on the trackpad. Ranges from 0 (no touch) all the way to 1500+ (high-pressure touch).
    let pressure: Float

    /// The angle of the oval formed by this touch.
    let angle: Float

    /// The radius of the major axis of this touch's representative oval.
    let majorAxis: Float

    /// The radius of the minor axis of this touch's representative oval.
    let minorAxis: Float

    /// Vector in the trackpad coordinates?
    let absoluteVector: MTVector

    let field14: Float
    let field15: Float

    /// The density of this touch. Ranges from 0 (no touch), 1 (normal-range touch), or higher for a higher-pressured touch.
    let density: Float
}
