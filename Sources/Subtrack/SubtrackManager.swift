//
//  SubtrackManager.swift
//  Subtrack
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation
import Scribe

/// Main entry point for accessing multitouch devices
@Loggable(style: .static)
public enum SubtrackManager {
    public static var isAvailable: Bool {
        guard let MTDeviceIsAvailable else {
            log.warn("Failed to load MTDeviceIsAvailable")
            return false
        }

        return MTDeviceIsAvailable()
    }

    public static var defaultDevice: SubtrackDevice? {
        guard let MTDeviceCreateDefault else {
            log.warn("Failed to load MTDeviceCreateDefault")
            return nil
        }

        guard let deviceRef = MTDeviceCreateDefault() else {
            log.warn("Failed to load create default device with MTDeviceCreateDefault")
            return nil
        }

        return SubtrackDevice(deviceRef: deviceRef)
    }

    public static var allDevices: [SubtrackDevice] {
        guard let MTDeviceCreateList else {
            log.warn("Failed to load MTDeviceCreateList")
            return []
        }

        guard let deviceList = MTDeviceCreateList()?.takeUnretainedValue() else {
            log.warn("Failed to load available devices with MTDeviceCreateList")
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
            devices.append(deviceRef)
        }

        return devices.map { SubtrackDevice(deviceRef: $0) }
    }

    public static func device(fromDeviceID deviceID: UInt64) -> SubtrackDevice? {
        guard let MTDeviceCreateFromDeviceID else {
            log.warn("Failed to load MTDeviceCreateFromDeviceID")
            return nil
        }

        guard let deviceRef = MTDeviceCreateFromDeviceID(deviceID) else {
            return nil
        }

        return SubtrackDevice(deviceRef: deviceRef)
    }

    public static func device(fromService service: io_service_t) -> SubtrackDevice? {
        guard let MTDeviceCreateFromService else {
            log.warn("Failed to load MTDeviceCreateFromService")
            return nil
        }

        guard let deviceRef = MTDeviceCreateFromService(service) else {
            return nil
        }

        return SubtrackDevice(deviceRef: deviceRef)
    }

    public static var currentAbsoluteTime: Double {
        guard let MTAbsoluteTimeGetCurrent else {
            log.warn("Failed to load MTAbsoluteTimeGetCurrent")
            return 0
        }

        return MTAbsoluteTimeGetCurrent()
    }
}
