//
//  SubsurfaceDevice.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-01-31.
//

import AppKit
import os
import Scribe

/// Represents a multitouch device (trackpad)
@Loggable
public final class SubsurfaceDevice: @unchecked Sendable {
    private let deviceRef: MTDeviceRef

    struct ContactState {
        var stream: AsyncStream<[MTContact]>?
        var continuation: AsyncStream<[MTContact]>.Continuation?
    }
    /// Lock guarding the contact stream pair. The C frame callback fires on a
    /// framework thread, while register/unregister can run on any caller thread.
    let contactState = OSAllocatedUnfairLock<ContactState>(initialState: .init())

    /// Controls whether the device should automatically restart after the system wakes from sleep
    public var autoRestartOnWake: Bool = true
    private var wakeObserver: NSObjectProtocol?

    private init(deviceRef: MTDeviceRef) {
        self.deviceRef = deviceRef
    }

    // MARK: - Static Properties

    /// Check if multitouch support is available on the system
    public static var isAvailable: Bool {
        guard let MTDeviceIsAvailable else {
            Log.warn("Failed to load MTDeviceIsAvailable", category: logCategory)
            return false
        }

        return MTDeviceIsAvailable()
    }

    /// Get the default multitouch device (usually the built-in trackpad)
    public static var defaultDevice: SubsurfaceDevice? {
        guard let MTDeviceCreateDefault else {
            Log.warn("Failed to load MTDeviceCreateDefault", category: logCategory)
            return nil
        }

        guard let deviceRef = MTDeviceCreateDefault() else {
            Log.warn("Failed to create default device with MTDeviceCreateDefault", category: Self.logCategory)
            return nil
        }

        return SubsurfaceDevice(deviceRef: deviceRef)
    }

    /// Get all available multitouch devices
    public static var allDevices: [SubsurfaceDevice] {
        guard let MTDeviceCreateList else {
            Log.warn("Failed to load MTDeviceCreateList", category: logCategory)
            return []
        }

        guard let deviceList = MTDeviceCreateList()?.takeRetainedValue() else {
            Log.warn("Failed to load available devices with MTDeviceCreateList", category: Self.logCategory)
            return []
        }

        let count = CFArrayGetCount(deviceList)
        var devices: [MTDeviceRef] = []
        devices.reserveCapacity(count)

        for i in 0 ..< count {
            let raw = CFArrayGetValueAtIndex(deviceList, i) // UnsafeRawPointer!
            guard let raw else { continue }

            // The element itself is the MTDeviceRef pointer value.
            let deviceRef = UnsafeMutableRawPointer(mutating: raw)

            // We will manually release the device ref in the deinit
            _ = Unmanaged<CFTypeRef>.fromOpaque(deviceRef).retain()

            devices.append(deviceRef)
        }

        return devices.map { SubsurfaceDevice(deviceRef: $0) }
    }

    /// Get the current absolute time from the multitouch framework
    public static var currentAbsoluteTime: Double {
        guard let MTAbsoluteTimeGetCurrent else {
            Log.warn("Failed to load MTAbsoluteTimeGetCurrent", category: logCategory)
            return 0
        }

        return MTAbsoluteTimeGetCurrent()
    }

    // MARK: - Initializers

    /// Create a device from a device ID
    public convenience init?(deviceID: UInt64) {
        guard let MTDeviceCreateFromDeviceID else {
            Log.warn("Failed to load MTDeviceCreateFromDeviceID", category: Self.logCategory)
            return nil
        }

        guard let deviceRef = MTDeviceCreateFromDeviceID(deviceID) else {
            return nil
        }

        self.init(deviceRef: deviceRef)
    }

    /// Create a device from an IOKit service
    public convenience init?(service: io_service_t) {
        guard let MTDeviceCreateFromService else {
            Log.warn("Failed to load MTDeviceCreateFromService", category: Self.logCategory)
            return nil
        }

        guard let deviceRef = MTDeviceCreateFromService(service) else {
            return nil
        }

        self.init(deviceRef: deviceRef)
    }

    deinit {
        if isRunning {
            stop()
        }
        MTDeviceRelease?(deviceRef)
    }

    // MARK: - Device Control

    /// Starts the device and begins collecting touch data
    /// - Returns: `true` if the device started successfully, `false` otherwise
    @discardableResult
    public func start() -> Bool {
        guard rawStart() else { return false }
        addSleepWakeObservers()
        return true
    }

    /// Stops the device and stops collecting touch data
    /// - Returns: `true` if the device stopped successfully, `false` otherwise
    @discardableResult
    public func stop() -> Bool {
        removeSleepWakeObservers()
        removeContactFrameCallback()
        return rawStop()
    }

    /// Start the underlying MT device without touching observers/callbacks.
    private func rawStart() -> Bool {
        let error = MTDeviceStart?(deviceRef, MTRunMode.verbose.rawValue)
        if error != noErr {
            log.error("Error starting device: \(error ?? -1)")
            return false
        }
        return true
    }

    /// Stop the underlying MT device without touching observers/callbacks.
    @discardableResult
    private func rawStop() -> Bool {
        MTDeviceStop?(deviceRef) == noErr
    }

    private func restart() async {
        guard autoRestartOnWake, wakeObserver != nil else { return }

        log.info("Restarting device after wake")
        _ = rawStop()
        try? await Task.sleep(for: .seconds(1))

        if rawStart() {
            log.info("Device restarted successfully")
        } else {
            log.error("Failed to restart device")
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

    /// Checks if this device is running (is be changed when `start()`/`stop()` is called)
    public var isRunning: Bool {
        guard let MTDeviceIsRunning else {
            log.warn("Failed to load MTDeviceIsRunning")
            return false
        }
        return MTDeviceIsRunning(deviceRef)
    }

    /// Determines if a device is built-in (e.g. a MacBook trackpad)
    public var isBuiltIn: Bool {
        guard let MTDeviceIsBuiltIn else {
            log.warn("Failed to load MTDeviceIsBuiltIn")
            return false
        }
        return MTDeviceIsBuiltIn(deviceRef)
    }

    /// Indicates whether the device has an opaque surface
    /// Maybe differentiates Magic Trackpads from older resistive trackpads?
    public var isOpaqueSurface: Bool {
        guard let MTDeviceIsOpaqueSurface else {
            log.warn("Failed to load MTDeviceIsOpaqueSurface")
            return false
        }
        return MTDeviceIsOpaqueSurface(deviceRef)
    }

    /// Checks if this device's driver is responsive (basically a ping)
    public var isAlive: Bool {
        guard let MTDeviceIsAlive else {
            log.warn("Failed to load MTDeviceIsAlive")
            return false
        }
        return MTDeviceIsAlive(deviceRef)
    }

    /// Indicates whether the device is a HID multitouch device, rather than e.g. SPI or I2C
    public var isHIDDevice: Bool {
        guard let MTDeviceIsMTHIDDevice else {
            log.warn("Failed to load MTDeviceIsMTHIDDevice")
            return true
        }
        return MTDeviceIsMTHIDDevice(deviceRef)
    }

    /// Indicates whether the device supports Force Touch
    public var supportsForce: Bool {
        guard let MTDeviceSupportsForce else {
            log.warn("Failed to load MTDeviceSupportsForce")
            return false
        }
        return MTDeviceSupportsForce(deviceRef)
    }

    /// Indicates whether the device supports haptic actuation
    public var supportsActuation: Bool {
        guard let MTDeviceSupportsActuation else {
            log.warn("Failed to load MTDeviceSupportsActuation")
            return false
        }
        return MTDeviceSupportsActuation(deviceRef)
    }

    /// Controls whether system haptic actuations are enabled for this device
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

    /// Indicates whether the device driver is ready and fully initialized
    public var isDriverReady: Bool {
        guard let MTDeviceDriverIsReady else {
            log.warn("Failed to load MTDeviceDriverIsReady")
            return false
        }
        return MTDeviceDriverIsReady(deviceRef)
    }

    /// Indicates whether the device supports power control (turning on/off)
    public var supportsPowerControl: Bool {
        guard let MTDevicePowerControlSupported else {
            log.warn("Failed to load MTDevicePowerControlSupported")
            return false
        }
        return MTDevicePowerControlSupported(deviceRef)
    }

    // MARK: - Device Information

    /// The IOKit service identifier for this device
    public var service: io_service_t? {
        guard let MTDeviceGetService else {
            log.warn("Failed to load MTDeviceGetService")
            return nil
        }
        return MTDeviceGetService(deviceRef)
    }

    /// Surface dimensions in hundredths of a millimeter (0.01mm units, or 10 micrometers)
    /// - To convert to millimeters: divide by 100
    /// - To convert to centimeters: divide by 1000
    /// - Example: width=12480 means 124.8mm or 12.48cm
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

    /// The sensor grid dimensions in rows and columns
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

    /// The device family identifier (used to determine device type/model)
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

    /// The unique device identifier
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

    /// The device's firmware version
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

    /// The driver type identifier for this device
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

    /// The transport method (likely maps to methods such as USB, Bluetooth, built-in etc.)
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

    /// The device serial number
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

    /// Thanks  to https://github.com/KrishKrosh/OpenMultitouchSupport
    public var name: String {
        switch familyID {
        case 98, 99, 100:
            // Built-in trackpad (older models)
            return "MacBook Trackpad"

        case 101:
            // Retina MacBook Pro trackpad
            return "MacBook Trackpad"

        case 102:
            // Retina MacBook with Force Touch trackpad (2015)
            return "MacBook Trackpad"

        case 103:
            // Retina MacBook Pro 13" with Force Touch trackpad (2015)
            return "MacBook Trackpad"

        case 104:
            // MacBook trackpad variant
            return "MacBook Trackpad"

        case 105:
            // MacBook with Touch Bar
            return "Touch Bar"

        case 108:
            // M1 Macbook Pro Trackpad
            return "MacBook Trackpad"

        case 109:
            // M4 Macbook Pro Trackpad
            return "MacBook Trackpad"

        case 112, 113:
            // Magic Mouse & Magic Mouse 2/3
            return "Magic Mouse"

        case 128, 129, 130:
            // Magic Trackpad, Magic Trackpad 2, Magic Trackpad 3
            return "Magic Trackpad"

        default:
            // Touch Bar is very wide and narrow (>1000 width, <100 height)
            if let surfaceDimensions = sensorSurfaceDimensions,
               surfaceDimensions.width > 1000, surfaceDimensions.height < 100 {
                return "Unknown Touch Bar (familyID: \(familyID))"
            }

            return "Unknown Device (familyID: \(familyID))"
        }
    }

    // MARK: - Force Touch & Click Control

    /// Controls whether system Force Touch responses are enabled for this device
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

    /// Indicates whether the device supports silent clicking (haptic feedback without mechanical click)
    public var supportsSilentClick: Bool {
        guard let MTDeviceSupportsSilentClick else {
            log.warn("Failed to load MTDeviceSupportsSilentClick")
            return false
        }

        var supported = false
        return MTDeviceSupportsSilentClick(deviceRef, &supported) == noErr && supported
    }

    // MARK: - Power Control

    /// Controls whether the device power is enabled
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
        if let existing = contactState.withLock({ $0.stream }) {
            return existing
        }

        // Use buffering policy that keeps only the newest value to prevent event queue buildup
        let stream = AsyncStream<[MTContact]>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            contactState.withLock { state in
                state.continuation = continuation
            }

            continuation.onTermination = { [weak self] _ in
                self?.contactState.withLock { $0.continuation = nil }
            }
        }

        contactState.withLock { $0.stream = stream }

        guard let MTRegisterContactFrameCallbackWithRefcon else {
            log.warn("Failed to load MTRegisterContactFrameCallbackWithRefcon")
            return stream
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let success = MTRegisterContactFrameCallbackWithRefcon(deviceRef, contactFrameCallback, refcon)

        if success {
            log.debug("Registered contact frame callback")
        } else {
            log.error("Failed to register contact frame callback")
        }

        return stream
    }

    /// Remove contact frame callback
    public func removeContactFrameCallback() {
        let continuation = contactState.withLock { state -> AsyncStream<[MTContact]>.Continuation? in
            guard state.stream != nil else { return nil }
            let c = state.continuation
            state.continuation = nil
            state.stream = nil
            return c
        }
        guard continuation != nil else { return }
        continuation?.finish()

        guard let MTUnregisterContactFrameCallback else {
            log.warn("Failed to load MTUnregisterContactFrameCallback")
            return
        }

        // The framework matches callbacks by function-pointer, so we have to pass the
        // original back. nil leaves it registered and firing into freed memory.
        let callback = unsafeBitCast(contactFrameCallback, to: MTContactCallbackFunction.self)
        MTUnregisterContactFrameCallback(deviceRef, callback)
        log.debug("Unregistered contact frame callback")
    }

    // MARK: - Haptics

    /// The haptic actuator for this device, if available
    public var actuator: SubsurfaceActuator? {
        guard let MTDeviceGetMTActuator else {
            log.warn("Failed to load MTDeviceGetMTActuator")
            return nil
        }

        guard let actuatorRef = MTDeviceGetMTActuator(deviceRef) else {
            return nil
        }

        return SubsurfaceActuator(actuatorRef: actuatorRef)
    }
}

extension SubsurfaceDevice: CustomStringConvertible {
    public var description: String {
        "MultitouchDevice(isRunning: \(isRunning), familyID: \(familyID ?? -1), version: \(version ?? -1))"
    }
}

// MARK: - C Frame Callback

let contactFrameCallback: MTFrameCallbackFunctionWithRefcon = { _, dataPtr, numTouches, _, _, refcon in
    let device = Unmanaged<SubsurfaceDevice>.fromOpaque(refcon).takeUnretainedValue()

    let touches = UnsafeBufferPointer(
        start: dataPtr.assumingMemoryBound(to: MTContact.self),
        count: Int(numTouches)
    )
    let touchesCopy = Array(touches)

    device.contactState.withLock { state in
        _ = state.continuation?.yield(touchesCopy)
    }
}
