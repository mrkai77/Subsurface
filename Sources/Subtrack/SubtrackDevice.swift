//
//  SubtrackDevice.swift
//  Subtrack
//
//  Created by Kai Azim on 2026-01-31.
//

import AppKit
import Scribe

/// Represents a multitouch device (trackpad)
@Loggable
public final class SubtrackDevice: @unchecked Sendable {
    private let deviceRef: MTDeviceRef
    private var contactStream: AsyncStream<[MTContact]>?
    private var pathStream: AsyncStream<(MTContact, Int, Int)>?

    private var wakeObserver: NSObjectProtocol?
    public var autoRestartOnWake: Bool = true

    init(deviceRef: MTDeviceRef) {
        self.deviceRef = deviceRef
    }

    deinit {
        if isRunning {
            stop()
        }
        removeContactFrameCallback()
        removePathCallback()
        MTDeviceRelease?(deviceRef)
    }

    // MARK: - Device Control

    @discardableResult
    public func start(mode: MTRunMode = .verbose) -> Bool {
        let error = MTDeviceStart?(deviceRef, mode.rawValue)

        if error != noErr {
            log.error("Error starting device with mode '\(mode)': \(error ?? -1)")
            return false
        }

        // Add sleep/wake observers when device starts
        addSleepWakeObservers()
        return true
    }

    @discardableResult
    public func stop() -> Bool {
        removeSleepWakeObservers()
        return MTDeviceStop?(deviceRef) == noErr
    }

    private func restart() async {
        guard autoRestartOnWake else { return }
        guard wakeObserver != nil else { return }

        log.info("Restarting device after wake")

        // Stop device (without removing observers)
        _ = MTDeviceStop?(deviceRef)

        try? await Task.sleep(for: .milliseconds(500))

        // Restart device
        let error = MTDeviceStart?(deviceRef, MTRunMode.verbose.rawValue)
        if error == noErr {
            log.info("Device restarted successfully")
        } else {
            log.error("Failed to restart device: \(error ?? -1)")
        }
    }

    private func addSleepWakeObservers() {
        guard wakeObserver == nil else { return }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            Task {
                await restart()
            }
        }
    }

    private func removeSleepWakeObservers() {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
    }

    // MARK: - Device Status

    public var isRunning: Bool {
        guard let MTDeviceIsRunning else {
            log.warn("Failed to load MTDeviceIsRunning")
            return false
        }
        return MTDeviceIsRunning(deviceRef)
    }

    public var isBuiltIn: Bool {
        guard let MTDeviceIsBuiltIn else {
            log.warn("Failed to load MTDeviceIsBuiltIn")
            return false
        }
        return MTDeviceIsBuiltIn(deviceRef)
    }

    public var isOpaqueSurface: Bool {
        guard let MTDeviceIsOpaqueSurface else {
            log.warn("Failed to load MTDeviceIsOpaqueSurface")
            return false
        }
        return MTDeviceIsOpaqueSurface(deviceRef)
    }

    public var isAlive: Bool {
        guard let MTDeviceIsAlive else {
            log.warn("Failed to load MTDeviceIsAlive")
            return false
        }
        return MTDeviceIsAlive(deviceRef)
    }

    public var isHIDDevice: Bool {
        guard let MTDeviceIsMTHIDDevice else {
            log.warn("Failed to load MTDeviceIsMTHIDDevice")
            return true
        }
        return MTDeviceIsMTHIDDevice(deviceRef)
    }

    public var supportsForce: Bool {
        guard let MTDeviceSupportsForce else {
            log.warn("Failed to load MTDeviceSupportsForce")
            return false
        }
        return MTDeviceSupportsForce(deviceRef)
    }

    public var supportsActuation: Bool {
        guard let MTDeviceSupportsActuation else {
            log.warn("Failed to load MTDeviceSupportsActuation")
            return false
        }
        return MTDeviceSupportsActuation(deviceRef)
    }

    public var isSystemActuationsEnabled: Bool {
        get {
            guard let MTActuatorGetSystemActuationsEnabled else {
                log.warn("Failed to load MTActuatorGetSystemActuationsEnabled")
                return true
            }
            return MTActuatorGetSystemActuationsEnabled(deviceRef)
        }
        set {
            guard let MTActuatorSetSystemActuationsEnabled else {
                log.warn("Failed to load MTActuatorSetSystemActuationsEnabled")
                return
            }
            _ = MTActuatorSetSystemActuationsEnabled(deviceRef, newValue)
        }
    }

    public var isDriverReady: Bool {
        guard let MTDeviceDriverIsReady else {
            log.warn("Failed to load MTDeviceDriverIsReady")
            return false
        }
        return MTDeviceDriverIsReady(deviceRef)
    }

    public var supportsPowerControl: Bool {
        guard let MTDevicePowerControlSupported else {
            log.warn("Failed to load MTDevicePowerControlSupported")
            return false
        }
        return MTDevicePowerControlSupported(deviceRef)
    }

    // MARK: - Device Information

    public var sensorSurfaceDimensions: (width: Int, height: Int)? {
        guard let MTDeviceGetSensorSurfaceDimensions else {
            log.warn("Failed to load MTDeviceGetSensorSurfaceDimensions")
            return nil
        }

        var width: Int32 = 0
        var height: Int32 = 0
        guard MTDeviceGetSensorSurfaceDimensions(deviceRef, &width, &height) == noErr else {
            return nil
        }
        return (Int(width), Int(height))
    }

    public var sensorDimensions: (rows: Int, columns: Int)? {
        guard let MTDeviceGetSensorDimensions else {
            log.warn("Failed to load MTDeviceGetSensorDimensions")
            return nil
        }

        var rows: Int32 = 0
        var cols: Int32 = 0
        guard MTDeviceGetSensorDimensions(deviceRef, &rows, &cols) == noErr else {
            return nil
        }
        return (Int(rows), Int(cols))
    }

    public var familyID: Int? {
        guard let MTDeviceGetFamilyID else {
            log.warn("Failed to load MTDeviceGetFamilyID")
            return nil
        }

        var familyID: Int32 = 0
        guard MTDeviceGetFamilyID(deviceRef, &familyID) == noErr else {
            return nil
        }
        return Int(familyID)
    }

    public var deviceID: UInt64? {
        guard let MTDeviceGetDeviceID else {
            log.warn("Failed to load MTDeviceGetDeviceID")
            return nil
        }

        var deviceID: UInt64 = 0
        guard MTDeviceGetDeviceID(deviceRef, &deviceID) == noErr else {
            return nil
        }
        return deviceID
    }

    public var version: Int? {
        guard let MTDeviceGetVersion else {
            log.warn("Failed to load MTDeviceGetVersion")
            return nil
        }

        var version: Int32 = 0
        guard MTDeviceGetVersion(deviceRef, &version) == noErr else {
            return nil
        }
        return Int(version)
    }

    public var driverType: Int? {
        guard let MTDeviceGetDriverType else {
            log.warn("Failed to load MTDeviceGetDriverType")
            return nil
        }

        var driverType: Int32 = 0
        guard MTDeviceGetDriverType(deviceRef, &driverType) == noErr else {
            return nil
        }
        return Int(driverType)
    }

    public var transportMethod: Int? {
        guard let MTDeviceGetTransportMethod else {
            log.warn("Failed to load MTDeviceGetTransportMethod")
            return nil
        }

        var transportMethod: Int32 = 0
        guard MTDeviceGetTransportMethod(deviceRef, &transportMethod) == noErr else {
            return nil
        }
        return Int(transportMethod)
    }

    public var serialNumber: String? {
        guard let MTDeviceGetSerialNumber else {
            log.warn("Failed to load MTDeviceGetSerialNumber")
            return nil
        }

        var serialNumber: CFString?
        guard MTDeviceGetSerialNumber(deviceRef, &serialNumber) == noErr,
              let serial = serialNumber else {
            return nil
        }
        return serial as String
    }

    // MARK: - Force Touch & Click Control

    public var isSystemForceResponseEnabled: Bool {
        get {
            guard let MTDeviceGetSystemForceResponseEnabled else {
                log.warn("Failed to load MTDeviceGetSystemForceResponseEnabled")
                return false
            }
            return MTDeviceGetSystemForceResponseEnabled(deviceRef)
        }
        set {
            guard let MTDeviceSetSystemForceResponseEnabled else {
                log.warn("Failed to load MTDeviceSetSystemForceResponseEnabled")
                return
            }
            MTDeviceSetSystemForceResponseEnabled(deviceRef, newValue)
        }
    }

    public var supportsSilentClick: Bool {
        guard let MTDeviceSupportsSilentClick else {
            log.warn("Failed to load MTDeviceSupportsSilentClick")
            return false
        }

        var supported = false
        return MTDeviceSupportsSilentClick(deviceRef, &supported) == noErr && supported
    }

    // MARK: - Power Control

    public var isPowerEnabled: Bool {
        get {
            guard let MTDevicePowerGetEnabled else {
                log.warn("Failed to load MTDevicePowerGetEnabled")
                return false
            }

            var enabled = false
            MTDevicePowerGetEnabled(deviceRef, &enabled)
            return enabled
        }
        set {
            guard let MTDevicePowerSetEnabled else {
                log.warn("Failed to load MTDevicePowerSetEnabled")
                return
            }
            _ = MTDevicePowerSetEnabled(deviceRef, newValue)
        }
    }

    // MARK: - Callbacks

    /// Create an async stream of contact frame events
    public func contactFrames() -> AsyncStream<[MTContact]> {
        if let existing = contactStream {
            return existing
        }

        let stream = SubtrackCallbackManager.shared.registerContactFrameCallback(for: deviceRef)
        contactStream = stream
        return stream
    }

    /// Remove contact frame callback
    public func removeContactFrameCallback() {
        guard contactStream != nil else { return }
        SubtrackCallbackManager.shared.unregisterContactFrameCallback(for: deviceRef)
        contactStream = nil
    }

    /// Create an async stream of individual touch path events
    public func pathEvents() -> AsyncStream<(MTContact, Int, Int)> {
        if let existing = pathStream {
            return existing
        }

        let stream = SubtrackCallbackManager.shared.registerPathCallback(for: deviceRef)
        pathStream = stream
        return stream
    }

    /// Remove path event callback
    public func removePathCallback() {
        guard pathStream != nil else { return }
        SubtrackCallbackManager.shared.unregisterPathCallback(for: deviceRef)
        pathStream = nil
    }

    // MARK: - Haptics

    public var actuator: SubtrackActuator? {
        guard let MTDeviceGetMTActuator else {
            log.warn("Failed to load MTDeviceGetMTActuator")
            return nil
        }

        guard let actuatorRef = MTDeviceGetMTActuator(deviceRef) else {
            return nil
        }

        return SubtrackActuator(actuatorRef: actuatorRef)
    }
}

extension SubtrackDevice: CustomStringConvertible {
    public var description: String {
        "MultitouchDevice(isRunning: \(isRunning), familyID: \(familyID ?? -1), version: \(version ?? -1)))"
    }
}
