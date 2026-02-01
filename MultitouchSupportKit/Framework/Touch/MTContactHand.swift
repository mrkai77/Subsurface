//
//  MTContactHand.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-02-01.
//

import Foundation

@frozen
public enum MTContactHand: Int32, CustomStringConvertible {
    case left = -1
    case right = 1
    case unknown = 0

    public var description: String {
        switch self {
        case .right:
            "Right"
        case .left:
            "Left"
        case .unknown:
            "Unknown"
        }
    }
}
