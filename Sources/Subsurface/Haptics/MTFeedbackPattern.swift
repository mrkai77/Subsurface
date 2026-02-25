//
//  MTFeedbackPattern.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

/// Uses empirically determined values
@frozen
public enum MTFeedbackPattern: Int32, CustomStringConvertible, CaseIterable {
    case firm = 1
    case firmStrong = 2

    case medium = 3
    case mediumStrong = 4

    case light = 5
    case lightStrong = 6

    case click = 15
    case secondaryClick = 16
    
    public var description: String {
        switch self {
        case .firm:
            "firm"
        case .firmStrong:
            "firm, strong"
        case .medium:
            "medium"
        case .mediumStrong:
            "medium, strong"
        case .light:
            "light"
        case .lightStrong:
            "light, strong"
        case .click:
            "click"
        case .secondaryClick:
            "secondary click"
        }
    }
}
