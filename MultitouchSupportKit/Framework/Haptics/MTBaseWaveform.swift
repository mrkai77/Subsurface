//
//  MTBaseWaveform.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

@frozen
public struct MTBaseWaveform {
    public let type: MTBaseWaveformType
    public let durationMS: Double
    public let amplitude: Double // 0-255

    public init(type: MTBaseWaveformType, durationMS: Double, amplitude: Double) {
        self.type = type
        self.durationMS = durationMS
        self.amplitude = amplitude
    }

    func toDictionary() -> CFDictionary {
        [
            "Type" as CFString: type.rawValue as CFString,
            "DurationMS" as CFString: durationMS as CFNumber,
            "Amplitude" as CFString: amplitude as CFNumber
        ] as CFDictionary
    }
}
