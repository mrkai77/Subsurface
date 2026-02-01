//
//  MTIntensityMultipliers.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

public struct MTIntensityMultipliers {
    public let light: Float
    public let medium: Float
    public let firm: Float

    public init(light: Float = 1.0, medium: Float = 1.0, firm: Float = 1.0) {
        self.light = light
        self.medium = medium
        self.firm = firm
    }

    func toDictionary() -> CFDictionary {
        [
            "Light" as CFString: light as CFNumber,
            "Medium" as CFString: medium as CFNumber,
            "Firm" as CFString: firm as CFNumber
        ] as CFDictionary
    }
}
