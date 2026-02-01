//
//  MultitouchActuator.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

public final class MultitouchActuator {
    private let actuatorRef: MTActuatorRef

    public init?(deviceID: UInt64) {
        guard let ref = MTActuatorCreateFromDeviceID(deviceID) else {
            return nil
        }
        self.actuatorRef = ref
    }

    init(actuatorRef: MTActuatorRef) {
        self.actuatorRef = actuatorRef
    }

    deinit {
        if actuatorIsOpen {
            close()
        }
    }

    public var actuatorIsOpen: Bool {
        MTActuatorIsOpen(actuatorRef)
    }

    @discardableResult
    public func open() -> Bool {
        guard MTActuatorOpen(actuatorRef) == kIOReturnSuccess else {
            return false
        }
        return true
    }

    @discardableResult
    public func close() -> Bool {
        guard MTActuatorClose(actuatorRef) == kIOReturnSuccess else {
            return false
        }
        return true
    }

    @discardableResult
    public func actuate(
        pattern: MTFeedbackPattern,
        intensity: Float = 1.0
    ) -> Bool {
        guard actuatorIsOpen else {
            print("Please open the actuator first.")
            return false
        }
        return MTActuatorActuate(
            actuatorRef,
            pattern.rawValue,
            0,
            intensity,
            1.0
        ) == kIOReturnSuccess
    }

    /// Create and trigger a custom haptic pattern
    @discardableResult
    public func actuate(customPattern pattern: MTHapticPattern) -> Bool {
        guard actuatorIsOpen else {
            print("Please open the actuator first.")
            return false
        }

        let dict = pattern.toDictionary()
        guard let actuation = MTActuationCreateFromDictionary(dict, actuatorRef) else {
            print("Failed to create actuation")
            return false
        }

        return MTActuationActuate(actuation, actuatorRef, 0) == kIOReturnSuccess
    }
}
