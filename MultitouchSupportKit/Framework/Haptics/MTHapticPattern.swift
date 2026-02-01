//
//  MTHapticPattern.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

@frozen
public struct MTHapticPattern {
    public let baseWaveform: MTBaseWaveform
    public let tones: [MTToneWaveform]
    public let baseMultipliers: MTIntensityMultipliers?
    public let toneMultipliers: MTIntensityMultipliers?

    public init(
        baseWaveform: MTBaseWaveform,
        tones: [MTToneWaveform] = [],
        baseMultipliers: MTIntensityMultipliers? = nil,
        toneMultipliers: MTIntensityMultipliers? = nil
    ) {
        self.baseWaveform = baseWaveform
        self.tones = tones
        self.baseMultipliers = baseMultipliers
        self.toneMultipliers = toneMultipliers
    }

    func toDictionary() -> CFDictionary {
        var dict: [CFString: Any] = [
            "BaseWaveform" as CFString: baseWaveform.toDictionary()
        ]

        if !tones.isEmpty {
            let tonesArray = tones.map { $0.toDictionary() } as CFArray
            dict["Tones" as CFString] = tonesArray
        }

        if let baseMultipliers {
            dict["BaseMultipliers" as CFString] = baseMultipliers.toDictionary()
        }

        if let toneMultipliers {
            dict["ToneMultipliers" as CFString] = toneMultipliers.toDictionary()
        }

        return dict as CFDictionary
    }
}
