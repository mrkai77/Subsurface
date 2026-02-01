//
//  MTFeedbackPattern.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

/// Based on https://github.com/mrsuperwealthy/Clicky
/// Note that these names aren't really relevant, as medium seems to be stronger than strong on my Macbook?
public enum MTFeedbackPattern: Int32 {
    case weak = 1 // Gentle click feedback
    case medium = 2 // Medium click / Double tap feel
    case strong = 3 // Strong click
    case buzz = 4 // Short buzz
    case doubleBuzz = 5 // Double buzz pattern
    case limit = 6 // Sharp "limit" click - metallic clack (Typewriter)
    case heavy = 15 // Heavy thunk (Force)
    case light = 16 // Light tap
}
