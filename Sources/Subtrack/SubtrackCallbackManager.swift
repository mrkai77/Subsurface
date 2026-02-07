//
//  SubtrackCallbackManager.swift
//  Subtrack
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation
import Scribe

@Loggable
final class SubtrackCallbackManager {
    nonisolated(unsafe) static let shared = SubtrackCallbackManager()
    private init() {}

    private var contactHandlers: [UInt: AsyncStream<[MTContact]>.Continuation] = [:]
    private var pathHandlers: [UInt: AsyncStream<(MTContact, Int, Int)>.Continuation] = [:]

    func registerContactFrameCallback(for device: MTDeviceRef) -> AsyncStream<[MTContact]> {
        let deviceKey = key(for: device)

        let stream = AsyncStream<[MTContact]> { continuation in
            contactHandlers[deviceKey] = continuation

            continuation.onTermination = { _ in
                SubtrackCallbackManager.shared.removeContactHandler(key: deviceKey)
            }
        }

        let callback: MTContactCallbackFunction = { device, dataPtr, numTouches, _, _ in
            let deviceKey = SubtrackCallbackManager.shared.key(for: device)
            guard let continuation = SubtrackCallbackManager.shared.contactHandlers[deviceKey] else {
                return 0
            }

            let touches = UnsafeBufferPointer(
                start: dataPtr.assumingMemoryBound(to: MTContact.self),
                count: Int(numTouches)
            )
            continuation.yield(touches.map(\.self))
            return 0
        }

        guard let MTRegisterContactFrameCallback else {
            log.warn("Failed to load MTRegisterContactFrameCallback")
            return stream
        }

        MTRegisterContactFrameCallback(device, callback)
        log.debug("Registered contact frame callback for \(deviceKey)")

        return stream
    }

    func unregisterContactFrameCallback(for device: MTDeviceRef) {
        let deviceKey = key(for: device)

        if let continuation = contactHandlers[deviceKey] {
            continuation.finish()
            removeContactHandler(key: deviceKey)
        }

        guard let MTUnregisterContactFrameCallback else {
            log.warn("Failed to load MTUnregisterContactFrameCallback")
            return
        }

        MTUnregisterContactFrameCallback(device, nil)
        log.debug("Unregistered contact frame callback for \(deviceKey)")
    }

    func registerPathCallback(for device: MTDeviceRef) -> AsyncStream<(MTContact, Int, Int)> {
        let deviceKey = key(for: device)

        let stream = AsyncStream<(MTContact, Int, Int)> { continuation in
            pathHandlers[deviceKey] = continuation

            continuation.onTermination = { _ in
                SubtrackCallbackManager.shared.removePathHandler(key: deviceKey)
            }
        }

        let callback: MTPathCallbackFunction = { device, pathID, state, touchPtr in
            let deviceKey = SubtrackCallbackManager.shared.key(for: device)
            guard let continuation = SubtrackCallbackManager.shared.pathHandlers[deviceKey] else {
                return
            }

            let touch = touchPtr.assumingMemoryBound(to: MTContact.self).pointee
            continuation.yield((touch, pathID, state))
        }

        guard let MTRegisterPathCallback else {
            log.warn("Failed to load MTRegisterPathCallback")
            return stream
        }

        MTRegisterPathCallback(device, callback)
        log.debug("Registered path callback for \(deviceKey)")

        return stream
    }

    func unregisterPathCallback(for device: MTDeviceRef) {
        let deviceKey = key(for: device)
        if let continuation = pathHandlers[deviceKey] {
            continuation.finish()
            removePathHandler(key: deviceKey)
        }

        guard let MTUnregisterPathCallback else {
            log.warn("Failed to load MTUnregisterPathCallback")
            return
        }

        MTUnregisterPathCallback(device, nil)
        log.debug("Unregistered path callback for \(deviceKey)")
    }

    // MARK: Private

    private nonisolated func key(for device: MTDeviceRef) -> UInt {
        UInt(bitPattern: device)
    }

    private func removeContactHandler(key: UInt) {
        contactHandlers.removeValue(forKey: key)
    }

    private func removePathHandler(key: UInt) {
        pathHandlers.removeValue(forKey: key)
    }
}
