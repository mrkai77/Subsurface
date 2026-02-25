//
//  MTContactState.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

@frozen
public enum MTContactState: Int32, CustomStringConvertible {
    case notTracking = 0
    case starting = 1
    case hovering = 2
    case making = 3
    case touching = 4
    case breaking = 5
    case lingering = 6
    case outOfRange = 7

    public var description: String {
        switch self {
        case .notTracking:
            "Not tracking"
        case .starting:
            "Starting"
        case .hovering:
            "Hovering"
        case .making:
            "Making"
        case .touching:
            "Touching"
        case .breaking:
            "Breaking"
        case .lingering:
            "Lingering"
        case .outOfRange:
            "Out of range"
        }
    }
}
