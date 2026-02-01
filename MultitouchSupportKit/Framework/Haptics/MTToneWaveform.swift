//
//  MTToneWaveform.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

@frozen
public struct MTToneWaveform {
    public let type: MTToneWaveformType
    public let delayMS: Double
    public let durationMS: Double
    public let amplitude: Double
    public let frequencykHz: Double

    public init(
        type: MTToneWaveformType,
        delayMS: Double = 0.0,
        durationMS: Double,
        amplitude: Double,
        frequencykHz: Double
    ) {
        self.type = type
        self.delayMS = delayMS
        self.durationMS = durationMS
        self.amplitude = amplitude
        self.frequencykHz = frequencykHz
    }

    func toDictionary() -> CFDictionary {
        let typeString: CFString = switch type {
        case .none: "None" as CFString
        case .sine: "Sine" as CFString
        case .square: "Square" as CFString
        case .sawtooth: "Sawtooth" as CFString
        }

        return [
            "Type" as CFString: typeString,
            "DelayMS" as CFString: delayMS as CFNumber,
            "DurationMS" as CFString: durationMS as CFNumber,
            "Amplitude" as CFString: amplitude as CFNumber,
            "FrequencykHz" as CFString: frequencykHz as CFNumber
        ] as CFDictionary
    }
}
