//
//  MTFeedbackPattern.swift
//  Subtrack
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

/// Uses empirically determined values
@frozen
public enum MTFeedbackPattern: Int32 {
    case firm = 1
    case firmStrong = 2

    case medium = 3
    case mediumStrong = 4

    case light = 5
    case lightStrong = 6

    case click = 15
    case secondaryClick = 16
}
