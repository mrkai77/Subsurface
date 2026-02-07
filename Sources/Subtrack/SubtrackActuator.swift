//
//  SubtrackActuator.swift
//  Subtrack
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation
import IOKit
import Scribe

@Loggable
public final class SubtrackActuator {
    private let actuatorRef: MTActuatorRef

    init(actuatorRef: MTActuatorRef) {
        self.actuatorRef = actuatorRef
    }

    deinit {
        if isOpen {
            _ = close()
        }
    }

    public var isOpen: Bool {
        guard let MTActuatorIsOpen else {
            log.warn("Failed to load MTActuatorIsOpen")
            return false
        }
        return MTActuatorIsOpen(actuatorRef)
    }

    @discardableResult
    public func open() -> Bool {
        guard let MTActuatorOpen else {
            log.warn("Failed to load MTActuatorOpen")
            return false
        }

        return MTActuatorOpen(actuatorRef) == kIOReturnSuccess
    }

    @discardableResult
    public func close() -> Bool {
        guard let MTActuatorClose else {
            log.warn("Failed to load MTActuatorClose")
            return false
        }

        return MTActuatorClose(actuatorRef) == kIOReturnSuccess
    }

    @discardableResult
    public func actuate(
        pattern: MTFeedbackPattern,
        intensity: Float = 1.0
    ) -> Bool {
        guard isOpen else {
            log.error("Please open the actuator first.")
            return false
        }

        guard let MTActuatorActuate else {
            log.warn("Failed to load MTActuatorActuate")
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
        guard isOpen else {
            log.error("Please open the actuator first.")
            return false
        }

        guard let MTActuationCreateFromDictionary else {
            log.warn("Failed to load MTActuationCreateFromDictionary")
            return false
        }

        guard let MTActuationActuate else {
            log.warn("Failed to load MTActuationActuate")
            return false
        }

        let dict = pattern.toDictionary()
        guard let actuation = MTActuationCreateFromDictionary(dict, actuatorRef) else {
            log.error("Failed to create actuation")
            return false
        }

        return MTActuationActuate(actuation, actuatorRef, 0) == kIOReturnSuccess
    }
}
