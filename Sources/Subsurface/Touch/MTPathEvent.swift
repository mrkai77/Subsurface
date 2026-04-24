//
//  MTPathEvent.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-04-23.
//

import Foundation

/// A single-path update from the MultitouchSupport path callback. Fires per
/// finger transition rather than per full frame; the `stage` reuses
/// ``MTContactState`` since both APIs describe the same lifecycle
/// (notTracking, making, touching, breaking, lingering).
public struct MTPathEvent: Equatable, Sendable {
    /// Framework-assigned identifier for this path, stable across events for
    /// the same contact's lifetime.
    public let pathID: Int

    /// Current lifecycle stage of the path.
    public let stage: MTContactState

    /// Contact snapshot at this stage.
    public let contact: MTContact
}
