//
//  SubsurfaceActuator.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation
import IOKit
import Scribe

/// Represents a haptic actuator for a multitouch device
@Loggable
public final class SubsurfaceActuator {
    private let actuatorRef: MTActuatorRef

    init(actuatorRef: MTActuatorRef) {
        self.actuatorRef = actuatorRef
    }

    deinit {
        if isOpen {
            _ = close()
        }
    }

    /// Indicates whether the actuator is currently open and ready to trigger haptic feedback
    public var isOpen: Bool {
        guard let MTActuatorIsOpen else {
            log.warn("Failed to load MTActuatorIsOpen")
            return false
        }
        return MTActuatorIsOpen(actuatorRef)
    }

    /// Opens the actuator for use
    /// - Returns: `true` if the actuator opened successfully, `false` otherwise
    @discardableResult
    public func open() -> Bool {
        guard let MTActuatorOpen else {
            log.warn("Failed to load MTActuatorOpen")
            return false
        }

        return MTActuatorOpen(actuatorRef) == kIOReturnSuccess
    }

    /// Closes the actuator
    /// - Returns: `true` if the actuator closed successfully, `false` otherwise
    @discardableResult
    public func close() -> Bool {
        guard let MTActuatorClose else {
            log.warn("Failed to load MTActuatorClose")
            return false
        }

        return MTActuatorClose(actuatorRef) == kIOReturnSuccess
    }

    /// Triggers a haptic feedback pattern
    /// - Parameters:
    ///   - pattern: The haptic feedback pattern to trigger
    ///   - intensity: The intensity of the haptic feedback (0.0 to 1.0, default is 1.0)
    /// - Returns: `true` if the actuation succeeded, `false` otherwise
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

    /// Creates and triggers a custom haptic pattern
    /// - Parameter pattern: The custom haptic pattern to trigger
    /// - Returns: `true` if the actuation succeeded, `false` otherwise
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
        guard let actuation = MTActuationCreateFromDictionary(dict, actuatorRef)?.takeRetainedValue() else {
            log.error("Failed to create actuation")
            return false
        }

        return MTActuationActuate(actuation, actuatorRef, 0) == kIOReturnSuccess
    }
}
