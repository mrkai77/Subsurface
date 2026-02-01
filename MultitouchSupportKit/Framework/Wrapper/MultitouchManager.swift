//
//  MultitouchManager.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

/// Main entry point for accessing multitouch devices
public final class MultitouchManager {
    public static let shared = MultitouchManager()

    private init() {}

    public var isAvailable: Bool {
        MTDeviceIsAvailable()
    }

    public var defaultDevice: MultitouchDevice? {
        guard let deviceRef = MTDeviceCreateDefault() else {
            return nil
        }
        return MultitouchDevice(deviceRef: deviceRef)
    }

    public var allDevices: [MultitouchDevice] {
        guard let deviceList = MTDeviceCreateList()?.takeUnretainedValue() as? [MTDeviceRef] else {
            return []
        }
        return deviceList.map { MultitouchDevice(deviceRef: $0) }
    }

    public func device(fromDeviceID deviceID: UInt64) -> MultitouchDevice? {
        guard let deviceRef = MTDeviceCreateFromDeviceID(deviceID) else {
            return nil
        }
        return MultitouchDevice(deviceRef: deviceRef)
    }

    public func device(fromService service: io_service_t) -> MultitouchDevice? {
        guard let deviceRef = MTDeviceCreateFromService(service) else {
            return nil
        }
        return MultitouchDevice(deviceRef: deviceRef)
    }

    public var currentAbsoluteTime: Double {
        MTAbsoluteTimeGetCurrent()
    }
}
