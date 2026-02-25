//
//  MTContactFinger.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-02-01.
//

import Foundation

@frozen
public enum MTContactFinger: Int32, CustomStringConvertible {
    case thumb = 1
    case index = 2
    case middle = 3
    case ring = 4
    case pinky = 5

    public var description: String {
        switch self {
        case .thumb:
            "Thumb"
        case .index:
            "Index"
        case .middle:
            "Middle"
        case .ring:
            "Ring"
        case .pinky:
            "Pinky"
        }
    }
}
