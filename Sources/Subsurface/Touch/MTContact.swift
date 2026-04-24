//
//  MTContact.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

@frozen
public struct MTContact: Identifiable, Equatable {
    /// The frame ID in the same way a framerate works. Can be used to link different `MTTouch`es to the same event.
    public let frame: Int32

    /// The timestamp of this touch's event.
    public let timestamp: Double

    /// Exact meaning unknown; seems to be consistent across events for each finger.
    public let id: Int32

    /// The state of this touch.
    private let _contactState: Int32
    public var contactState: MTContactState { .init(rawValue: _contactState) ?? .outOfRange }

    /// The finger's ID from what looks to be 1 for the thumb all the way up to 5 for the fingers. Other may be considered as the palm.
    private let _fingerID: Int32
    public var finger: MTContactFinger? { .init(rawValue: _fingerID) }

    /// -1 for left, +1 for right. Any other value maps to `nil`, which usually
    /// means the framework couldn't pick a side (e.g. for palms).
    private let _handID: Int32
    public var hand: MTContactHand? { .init(rawValue: _handID) }

    /// Vector for this touch (normalized from 0...1)
    public let normalizedVector: MTVector

    /// Helps to determine how much of the user's finger/palm is touching the trackpad. Can be greater than 1.
    public let totalCapacitance: Float

    /// The pressue of the user's finger on the trackpad. Ranges from 0 (no touch) all the way to 1500+ (high-pressure touch).
    public let pressure: Float

    /// The angle of the oval formed by this touch.
    public let angle: Float

    /// The radius of the major axis of this touch's representative oval.
    public let majorAxis: Float

    /// The radius of the minor axis of this touch's representative oval.
    public let minorAxis: Float

    /// Vector in the trackpad coordinates?
    public let absoluteVector: MTVector

    private let field14: Float // Always 0, likely padding
    private let field15: Float // Always 0, likely padding

    /// The density of this touch. Ranges from 0 (no touch), 1 (normal-range touch), or higher for a higher-pressured touch.
    public let density: Float

    /// Internal initializer for testing purposes. Accessible via `@testable import Subsurface`.
    init(
        frame: Int32 = 0,
        timestamp: Double = 0,
        id: Int32 = 0,
        contactState: MTContactState = .touching,
        finger: MTContactFinger? = .index,
        hand: MTContactHand? = .right,
        normalizedVector: MTVector = MTVector(position: MTPoint(x: 0, y: 0), velocity: MTPoint(x: 0, y: 0)),
        totalCapacitance: Float = 0,
        pressure: Float = 0,
        angle: Float = 0,
        majorAxis: Float = 0,
        minorAxis: Float = 0,
        absoluteVector: MTVector = MTVector(position: MTPoint(x: 0, y: 0), velocity: MTPoint(x: 0, y: 0)),
        density: Float = 0
    ) {
        self.frame = frame
        self.timestamp = timestamp
        self.id = id
        self._contactState = contactState.rawValue
        self._fingerID = finger?.rawValue ?? 0
        self._handID = hand?.rawValue ?? 0
        self.normalizedVector = normalizedVector
        self.totalCapacitance = totalCapacitance
        self.pressure = pressure
        self.angle = angle
        self.majorAxis = majorAxis
        self.minorAxis = minorAxis
        self.absoluteVector = absoluteVector
        self.field14 = 0
        self.field15 = 0
        self.density = density
    }
}
