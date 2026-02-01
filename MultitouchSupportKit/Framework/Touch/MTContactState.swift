//
//  MTContactState.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

public enum MTContactState: UInt32 {
    case notTracking
    case starting
    case hovering
    case making
    case touching
    case breaking
    case lingering
    case outOfRange
}
