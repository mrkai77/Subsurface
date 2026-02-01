//
//  MultitouchDevice.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

/// Represents a multitouch device (trackpad)
public final class MultitouchDevice {
    private let deviceRef: MTDeviceRef
    private var contactStream: AsyncStream<[MTContact]>?
    private var pathStream: AsyncStream<(MTContact, Int, Int)>?

    init(deviceRef: MTDeviceRef) {
        self.deviceRef = deviceRef
    }

    deinit {
        if isRunning {
            stop()
        }
        removeContactFrameCallback()
        removePathCallback()
        MTDeviceRelease(deviceRef)
    }

    // MARK: - Device Control

    @discardableResult
    public func start(mode: MTRunMode = .verbose) -> Bool {
        let error = MTDeviceStart(deviceRef, mode.rawValue)

        if error != noErr {
            print("Error starting device with mode '\(mode)': \(error)")
        }

        return error == noErr
    }

    @discardableResult
    public func stop() -> Bool {
        MTDeviceStop(deviceRef) == noErr
    }

    // MARK: - Device Status

    public var isRunning: Bool {
        MTDeviceIsRunning(deviceRef)
    }

    public var isBuiltIn: Bool {
        MTDeviceIsBuiltIn(deviceRef)
    }

    public var isOpaqueSurface: Bool {
        MTDeviceIsOpaqueSurface(deviceRef)
    }

    public var isAlive: Bool {
        MTDeviceIsAlive(deviceRef)
    }

    public var isHIDDevice: Bool {
        MTDeviceIsMTHIDDevice(deviceRef)
    }

    public var supportsForce: Bool {
        MTDeviceSupportsForce(deviceRef)
    }

    public var supportsActuation: Bool {
        MTDeviceSupportsActuation(deviceRef)
    }

    public var isSystemActuationsEnabled: Bool {
        get { MTActuatorGetSystemActuationsEnabled(deviceRef) }
        set { _ = MTActuatorSetSystemActuationsEnabled(deviceRef, newValue) }
    }

    public var isDriverReady: Bool {
        MTDeviceDriverIsReady(deviceRef)
    }

    public var supportsPowerControl: Bool {
        MTDevicePowerControlSupported(deviceRef)
    }

    // MARK: - Device Information

    public var service: io_service_t {
        MTDeviceGetService(deviceRef)
    }

    public var sensorSurfaceDimensions: (width: Int, height: Int)? {
        var width: Int32 = 0
        var height: Int32 = 0
        guard MTDeviceGetSensorSurfaceDimensions(deviceRef, &width, &height) == noErr else {
            return nil
        }
        return (Int(width), Int(height))
    }

    public var sensorDimensions: (rows: Int, columns: Int)? {
        var rows: Int32 = 0
        var cols: Int32 = 0
        guard MTDeviceGetSensorDimensions(deviceRef, &rows, &cols) == noErr else {
            return nil
        }
        return (Int(rows), Int(cols))
    }

    public var familyID: Int? {
        var familyID: Int32 = 0
        guard MTDeviceGetFamilyID(deviceRef, &familyID) == noErr else {
            return nil
        }
        return Int(familyID)
    }

    public var deviceID: UInt64? {
        var deviceID: UInt64 = 0
        guard MTDeviceGetDeviceID(deviceRef, &deviceID) == noErr else {
            return nil
        }
        return deviceID
    }

    public var version: Int? {
        var version: Int32 = 0
        guard MTDeviceGetVersion(deviceRef, &version) == noErr else {
            return nil
        }
        return Int(version)
    }

    public var driverType: Int? {
        var driverType: Int32 = 0
        guard MTDeviceGetDriverType(deviceRef, &driverType) == noErr else {
            return nil
        }
        return Int(driverType)
    }

    public var transportMethod: Int? {
        var transportMethod: Int32 = 0
        guard MTDeviceGetTransportMethod(deviceRef, &transportMethod) == noErr else {
            return nil
        }
        return Int(transportMethod)
    }

    public var guid: UUID? {
        var guid = uuid_t(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        guard MTDeviceGetGUID(deviceRef, &guid) == noErr else {
            return nil
        }
        return UUID(uuid: guid)
    }

    public var serialNumber: String? {
        var serialNumber: CFString?
        guard MTDeviceGetSerialNumber(deviceRef, &serialNumber) == noErr,
              let serial = serialNumber else {
            return nil
        }
        return serial as String
    }

    // MARK: - Force Touch & Click Control

    public var isSystemForceResponseEnabled: Bool {
        get { MTDeviceGetSystemForceResponseEnabled(deviceRef) }
        set { MTDeviceSetSystemForceResponseEnabled(deviceRef, newValue) }
    }

    public var supportsSilentClick: Bool {
        var supported = false
        return MTDeviceSupportsSilentClick(deviceRef, &supported) == noErr && supported
    }

    // MARK: - Power Control

    public var isPowerEnabled: Bool {
        get {
            var enabled = false
            MTDevicePowerGetEnabled(deviceRef, &enabled)
            return enabled
        }
        set {
            _ = MTDevicePowerSetEnabled(deviceRef, newValue)
        }
    }

    // MARK: - Callbacks

    /// Create an async stream of contact frame events
    public func contactFrames() -> AsyncStream<[MTContact]> {
        if let existing = contactStream {
            return existing
        }

        let stream = MultitouchCallbackManager.shared.registerContactFrameCallback(for: deviceRef)
        contactStream = stream
        return stream
    }

    /// Remove contact frame callback
    public func removeContactFrameCallback() {
        guard contactStream != nil else { return }
        MultitouchCallbackManager.shared.unregisterContactFrameCallback(for: deviceRef)
        contactStream = nil
    }

    /// Create an async stream of individual touch path events
    public func pathEvents() -> AsyncStream<(MTContact, Int, Int)> {
        if let existing = pathStream {
            return existing
        }

        let stream = MultitouchCallbackManager.shared.registerPathCallback(for: deviceRef)
        pathStream = stream
        return stream
    }

    /// Remove path event callback
    public func removePathCallback() {
        guard pathStream != nil else { return }
        MultitouchCallbackManager.shared.unregisterPathCallback(for: deviceRef)
        pathStream = nil
    }

    // MARK: - Haptics

    public var actuator: MultitouchActuator? {
        guard let actuatorRef = MTDeviceGetMTActuator(deviceRef) else {
            return nil
        }
        return MultitouchActuator(actuatorRef: actuatorRef)
    }
}
